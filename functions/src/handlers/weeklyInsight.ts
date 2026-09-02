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
import {dangerHours, trailingDays} from '../domain/streakEngine';
import type {UserDoc} from '../lib/firestore';

const PAGE_SIZE = 300;

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
    const hourUtc = new Date().getUTCHours();
    let generated = 0;
    let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    for (;;) {
      let query = db
        .collection('users')
        .where('recalcHourUtc', '==', hourUtc)
        .orderBy('__name__')
        .limit(PAGE_SIZE);
      if (cursor) query = query.startAfter(cursor);

      const page = await query.get();
      if (page.empty) break;

      for (const doc of page.docs) {
        const data = doc.data() as UserDoc;
        // The same reading `tierFor` makes, on the document already in hand
        // (no second read per user); `ungated` applies once per run. A lapsed
        // `expiresAt` is free here too — the two crons and the coach must
        // agree on who is premium.
        if (!ungated() && tierOf(data) === 'free') continue;
        const tz = data.tz ?? 'UTC';
        const today = new Date();
        // Only fire on the user's local Sunday.
        const weekday = new Intl.DateTimeFormat('en-US', {
          timeZone: tz, weekday: 'short',
        }).format(today);
        if (weekday !== 'Sun') continue;

        try {
          // The server-owned name, already on the doc we just read — the
          // report must not call itself Ember for someone who renamed it.
          if (await generateFor(doc.id, tz, data.coachName)) generated++;
        } catch (error) {
          log.warn('weeklyInsight.user_failed', {uid: doc.id, error: String(error)});
        }
      }

      cursor = page.docs.at(-1);
      if (page.size < PAGE_SIZE) break;
    }

    log.info('weeklyInsight.done', {hourUtc, generated});
  },
);

async function generateFor(
  uid: string,
  timeZone: string,
  coachName?: string,
): Promise<boolean> {
  const snap = await journeyDoc(uid).get();
  if (!snap.exists) return false;

  const journey = decodeJourney(snap.data());
  const todayKey = dayKeyIn(new Date(), timeZone);
  const weekId = todayKey; // one report per local Sunday
  const week = trailingDays(journey.days, todayKey, 7);
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
      systemInstruction: insightPrompt(journey.profile.alias, coachName),
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
  await sendToUser(uid, {
    title: insight.headline,
    body: insight.win,
    route: '/insight',
  });
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
