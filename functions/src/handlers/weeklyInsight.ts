/**
 * `weeklyInsight` — Sunday report (docs/04 §5, docs/05 §7).
 *
 * Premium-only: free users see the headline with a blurred body, which is an
 * honest tease rather than a dark pattern (docs/04 §5). Generating for free
 * users anyway and hiding it would be paying for tokens nobody reads.
 *
 * Uses the same hourly/`recalcHourUtc` fan-out as `taperRecalc` so each user
 * gets their report on THEIR Sunday, not UTC's.
 */
import {onSchedule} from 'firebase-functions/v2/scheduler';
import {GEMINI_API_KEY, MODEL_PREMIUM, REGION} from '../config';
import {geminiModel} from '../ai/gemini';
import {insightPrompt} from '../ai/prompts';
import {ModelUnavailableError} from '../ai/model';
import {db, FieldValue, insightDoc, journeyDoc} from '../lib/firestore';
import {log} from '../lib/logger';
import {sendToUser} from '../lib/push';
import {tierOf, ungated} from '../lib/usage';
import {decodeJourney} from '../domain/journeyCodec';
import {dayKeyIn} from '../domain/dateKey';
import {dangerHours, isConfirmed, trailingDays} from '../domain/streakEngine';
import type {UserDoc} from '../lib/firestore';

const PAGE_SIZE = 300;

/**
 * The local hours a report may be generated and pushed in.
 *
 * Awake hours, because this is the one cron whose work ends in a notification.
 * Three of them rather than one so a bucket too big for a single 540s pass is
 * finished by the next — `generateFor` is idempotent per week, so the later
 * passes cost one read each for everyone already done.
 */
const LOCAL_HOURS = [9, 10, 11];

/**
 * Stop generating at this point and leave the rest to the next local hour.
 *
 * Comfortably inside `timeoutSeconds: 540` so the run ends on its own terms —
 * a killed invocation logs nothing, and `retryCount: 0` means nothing follows.
 */
const DEADLINE_MS = 440_000;

export interface Insight {
  headline: string;
  pattern: string;
  win: string;
  watchout: string;
  move: string;
}

export const weeklyInsight = onSchedule(
  {
    region: REGION,
    schedule: 'every 1 hours',
    timeZone: 'UTC',
    secrets: [GEMINI_API_KEY],
    memory: '512MiB',
    timeoutSeconds: 540,
    retryCount: 0, // a missed week is skipped silently (docs/04 §5), not retried
  },
  async () => {
    const startedAt = Date.now();
    const hourUtc = new Date().getUTCHours();
    const run = {generated: 0, skipped: 0, ranOutOfTime: false};

    // `recalcHourUtc` marks the UTC hour of the user's local 01:00 — the right
    // slot for `taperRecalc`, which writes a number nobody is awake to read,
    // and the wrong one for anything ending in a notification. Quiet hours
    // default to 23:00-08:00, so generating AND pushing at 01:00 meant
    // `insightReady` was silenced 100% of the time, by construction:
    // `insights_quiet` at low importance on Android, `interruption-level:
    // passive` and no sound on iOS. A paying subscriber's flagship weekly
    // feature announced itself with a notification they would never see.
    //
    // Three local hours rather than one, swept in sequence. That is also the
    // fix for the tail: a pass cut short at 09:00 is finished by the 10:00 and
    // 11:00 ones, and `generateFor` skips anyone already holding this week's
    // report, so the later passes cost one read each for work already done.
    //
    // Deliberately three SEPARATE queries rather than one `in` filter: each is
    // the same `==` + `orderBy(__name__)` + `startAfter` shape the fan-out has
    // always used in production. An `in` query is merged from sub-queries
    // server-side, and pairing that with a cursor is a behaviour the emulator
    // would not have caught us getting wrong.
    for (const local of LOCAL_HOURS) {
      if (run.ranOutOfTime) break;
      await sweepHour((hourUtc - local + 1 + 24) % 24, startedAt, run);
    }

    // `ranOutOfTime` is the line to alert on: a bucket outgrew one pass. Not
    // data loss while later hours still run, but the signal that the window
    // needs widening or the page needs splitting.
    log.info('weeklyInsight.done', {hourUtc, ...run});
  },
);

/** One local hour's worth of users, paged, mutating [run] as it goes. */
async function sweepHour(
  recalcHourUtc: number,
  startedAt: number,
  run: {generated: number; skipped: number; ranOutOfTime: boolean},
): Promise<void> {
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let query = db
      .collection('users')
      .where('recalcHourUtc', '==', recalcHourUtc)
      .orderBy('__name__')
      .limit(PAGE_SIZE);
    if (cursor) query = query.startAfter(cursor);

    const page = await query.get();
    if (page.empty) return;

    for (const doc of page.docs) {
      // Stop before the platform kills us. A premium user costs a read, a
      // 20s-bounded model call, a write and a push, so 540s buys far fewer
      // than one 300-user page — and being killed mid-page is invisible:
      // ordering is by `__name__`, so the survivors were always the same
      // lexicographically-first uids and the losers always the same tail,
      // every week, permanently. Ending deliberately leaves a log line and
      // leaves the rest to the next hour's pass.
      if (Date.now() - startedAt > DEADLINE_MS) {
        run.ranOutOfTime = true;
        return;
      }
      const data = doc.data() as UserDoc;
      // The same reading `tierFor` makes, on the document already in hand
      // (no second read per user); `ungated` applies once per run. A lapsed
      // `expiresAt` is free here too — the two crons and the coach must
      // agree on who is premium.
      if (!ungated() && tierOf(data) === 'free') continue;
      const tz = data.tz ?? 'UTC';
      // Only fire on the user's local Sunday.
      const weekday = new Intl.DateTimeFormat('en-US', {
        timeZone: tz, weekday: 'short',
      }).format(new Date());
      if (weekday !== 'Sun') continue;

      try {
        // The server-owned name, already on the doc we just read — the
        // report must not call itself Ember for someone who renamed it.
        if (await generateFor(doc.id, tz, data.coachName, data.locale)) {
          run.generated++;
        } else {
          run.skipped++;
        }
      } catch (error) {
        log.warn('weeklyInsight.user_failed', {uid: doc.id, error: String(error)});
      }
    }

    cursor = page.docs.at(-1);
    if (page.size < PAGE_SIZE) return;
  }
}

async function generateFor(
  uid: string,
  timeZone: string,
  coachName?: string,
  locale?: string,
): Promise<boolean> {
  const todayKey = dayKeyIn(new Date(), timeZone);
  const weekId = todayKey; // one report per local Sunday

  // Already written this week — the fan-out runs over three local hours so a
  // bucket that outgrows one pass is finished by the next, and this is what
  // makes those later passes free for everyone already done. Checked BEFORE
  // the journey read, so a repeat costs one read rather than a read plus a
  // premium model call.
  if ((await insightDoc(uid, weekId).get()).exists) return false;

  const snap = await journeyDoc(uid).get();
  if (!snap.exists) return false;

  const journey = decodeJourney(snap.data());
  // Confirmed days only, and filtered BEFORE the signal gate. An unlogged day
  // arrives as `puffs: 0` beside a real limit, and the model — told to report
  // "the week's best moment with real numbers" — writes exactly what it sees:
  // a flawless day the user never had. `weekStats` already filters the same
  // data for the same reason ("a week summary reports what is known"). Before
  // the gate too, so somebody who opened the app three times to check a mood
  // no longer clears "enough signal to say anything true" on three days they
  // never recorded.
  const week = trailingDays(journey.days, todayKey, 7).filter(isConfirmed);
  if (week.length < 3) return false; // not enough signal to say anything true

  const payload = {
    days: week.map((d) => ({
      date: d.date, puffs: d.puffs, limit: d.limit,
      mood: d.mood, cravingsSurvived: d.cravingsSurvived,
    })),
    dangerHours: dangerHours(trailingDays(journey.days, todayKey, 14)),
    baseline: journey.plan.baselinePuffsPerDay,
    longestStreak: journey.longestStreak,
  };

  const model = geminiModel(GEMINI_API_KEY.value());
  let insight: Insight | null = null;
  try {
    const result = await model.generate({
      model: MODEL_PREMIUM.value(),
      systemInstruction: insightPrompt(journey.profile.alias, coachName, locale),
      turns: [{role: 'user', text: JSON.stringify(payload)}],
      // Must hold thoughts + the ~150-token JSON: the premium model cannot
      // stop thinking and spends thought tokens inside this cap (see
      // ai/gemini.ts, proven on the coach path where 500 cut every reply
      // mid-word). 400 would truncate the JSON the same way.
      maxOutputTokens: 1500,
      temperature: 0.6,
      json: true,
    });
    insight = parseInsight(result.text);
  } catch (error) {
    if (!(error instanceof ModelUnavailableError)) throw error;
  }

  // docs/04 §5: on a second parse/availability failure, skip the week
  // silently rather than shipping half a report.
  if (!insight) return false;

  await insightDoc(uid, weekId).set({
    ...insight,
    weekId,
    createdAt: FieldValue.serverTimestamp(),
  });

  // A report the user never learns about is a report nobody reads. This is one
  // of the few things worth a push: it happened on the server, on a schedule,
  // and the device had no way to know.
  // The report is generated in the user's own language, so its own headline
  // is better push copy than anything a lookup table could hold.
  await sendToUser(
    uid,
    {title: insight.headline, body: insight.win, route: '/insight'},
    // Naming the kind is what subjects this to the same preference check,
    // quiet hours and channel as everything else. It used to call straight
    // through with no kind at all, which is precisely why the gate lives in
    // `sendToUser` rather than in the localized wrapper this never used.
    {kind: 'insightReady', tag: `insight:${weekId}`},
  );
  return true;
}

/** Strips code fences before parsing (docs/04 §5's stated fallback chain). */
export function parseInsight(raw: string): Insight | null {
  const cleaned = raw.trim().replace(/^```(?:json)?/i, '').replace(/```$/, '').trim();
  try {
    const parsed: unknown = JSON.parse(cleaned);
    if (parsed === null || typeof parsed !== 'object') return null;
    const o = parsed as Record<string, unknown>;
    const keys = ['headline', 'pattern', 'win', 'watchout', 'move'] as const;
    if (!keys.every((k) => typeof o[k] === 'string')) return null;
    return {
      headline: o['headline'] as string,
      pattern: o['pattern'] as string,
      win: o['win'] as string,
      watchout: o['watchout'] as string,
      move: o['move'] as string,
    };
  } catch {
    return null;
  }
}
