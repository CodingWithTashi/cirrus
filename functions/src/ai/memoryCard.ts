/**
 * Builds the USER CARD (docs/04 §3) that gives Ember the user's real numbers.
 *
 * Two rules this file exists to keep:
 * 1. Specifics beat generalities — Ember quoting "day 12, 134 yesterday" is
 *    the whole differentiator over a generic chatbot.
 * 2. The card is derived from the SAME engines the app renders from, so Ember
 *    can never quote a number the Home screen disagrees with.
 *
 * Budget: ~1.5K input tokens (docs/04 §3). Keep additions cheap.
 */
import {dayKeyIn} from '../domain/dateKey';
import {decodeJourney} from '../domain/journeyCodec';
import {
  currentStreak,
  dangerHours,
  flameFor,
  repairTokens,
  trailingDays,
} from '../domain/streakEngine';
import {dayNumber, limitFor} from '../domain/taperEngine';
import {weekStats, type WeekStat} from '../domain/weekStats';
import {
  totalDays,
  type DayLog,
  type Journey,
  type NicStrength,
} from '../domain/types';

export interface MemoryCard {
  readonly text: string;
  readonly journey: Journey;
  readonly todayKey: string;
  /** 1-based plan day — the same number the Home header renders. */
  readonly day: number;
  readonly streak: number;
}

export function buildMemoryCard(
  raw: unknown,
  now: Date,
  timeZone: string,
): MemoryCard {
  const journey = decodeJourney(raw);
  const todayKey = dayKeyIn(now, timeZone);
  const plan = journey.plan;
  const day = Math.max(1, dayNumber(plan, todayKey));
  const today = journey.days[todayKey];
  const limit = day <= totalDays(plan) ? limitFor(plan, day) : 0;
  const streak = currentStreak(journey.days, todayKey);
  const window14 = trailingDays(journey.days, todayKey, 14);
  const last7 = trailingDays(journey.days, todayKey, 7);

  const costPerPuff =
    plan.baselinePuffsPerDay === 0
      ? 0
      : plan.weeklySpend / (7 * plan.baselinePuffsPerDay);
  // Confirmed days only — `MoneyEngine.lifetimeSaved` applies the same rule
  // as the streak: a day nobody logged or confirmed is unknown, never a
  // saving. The day-1 journey is minted with an unconfirmed 0-puff log, so
  // without this every new account read "$4 saved" before its first puff.
  // And never a day after today (`TodaySnapshot` drops those too): a log
  // stamped by a device clock that was wrong is not money already kept.
  const saved = Object.entries(journey.days)
    .filter(([key, d]) => key <= todayKey && (d.puffs > 0 || d.vapeFreeConfirmed))
    .reduce(
      (acc, [, d]) =>
        acc + Math.max(0, plan.baselinePuffsPerDay - d.puffs) * costPerPuff,
      0,
    );

  const hours = dangerHours(window14);
  const localTime = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(now);
  const weekday = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'long',
  }).format(now);

  const profile = journey.profile;
  const age =
    profile.birthYear === null ? null : now.getFullYear() - profile.birthYear;

  const weeks = weekLines(weekStats(journey.days, plan.startDate, todayKey), day);

  const lines = [
    'USER CARD',
    // The model once congratulated a day-1 user on "making it to day two"
    // because a "good morning" greeting after older messages read like a new
    // day. Date and clock in their zone, stated outright, so the day number
    // never has to be inferred from conversation shape.
    `today's date: ${todayKey} (${weekday}) · their local time: ${localTime}`,
    // The plan day leads and is LABELLED. On day 2 the card also says "week 1
    // of 5", "streak: 1d" and "1 completed day", and the model once fused one
    // of those into "day one" — a bare "day 2" mid-line lost to three other
    // ones (Sep 5 2026). Past the plan it never reads "day 37 of 30": Home
    // says "7 days past Freedom Day" and so does this.
    `${planDayLine(plan, day)} · alias: ${profile.alias}`,
    // "How long have I been at this?" — answerable without arithmetic. The
    // start date is absolute so the model never has to derive a calendar.
    tenureLine(plan, day),
    `why: ${list(profile.whys)} · fears: ${list(profile.worries)}`,
    // The chips above say "health, money". This is what they meant by it, in
    // the one sentence of the whole funnel they wrote themselves — and the
    // single most useful line in the card when it is there.
    `their reason, in their words: ${profile.whyWords ?? 'not given'}`,
    // The rest of the 19-step quiz. These are the answers that change what is
    // worth SAYING rather than what the numbers are: someone on their sixth
    // attempt needs a different opening than someone on their first, and an
    // all-day vaper who reaches for it within five minutes of waking is a
    // different person from a social one.
    `about them: ${describeProfile(profile, age)}`,
    `vaping: ${strengthPhrase(plan.strength)}`,
    `saving toward: ${goalsLine(journey, saved)}`,
    `baseline: ${plan.baselinePuffsPerDay} puffs/day · today: ${today?.puffs ?? 0}/${limit} · streak: ${streak}d (${flameFor(streak)}) · tokens: ${repairTokens(journey.days, todayKey)}`,
    // Whole dollars with the symbol, exactly as Home renders it
    // (`LpFormat.money`, 0 decimals). It was `toFixed(2)` with no symbol, so
    // Ember said "2.74 dollars" beside a Home screen saying "$3" — one number,
    // two renderings, and this file's own rule is that the card may never
    // quote a figure the app disagrees with.
    `money saved: ${wholeDollars(saved)} · cravings survived: ${journey.cravingsSurvivedTotal}`,
    `danger hours: ${hours.length > 0 ? hours.map((h) => `${h}:00`).join(', ') : 'not enough data yet'}`,
    `last 7 days: ${last7.length > 0 ? last7.map((d) => d.puffs).join(',') : 'no logs yet'}`,
    // The whole journey, one line per week, from the same `holds` the flame
    // reads — so "compare my week 2 to my week 5" gets exact numbers instead
    // of a paraphrase of the last seven days.
    ...(weeks.length > 0
      ? ['weekly history (w1 = first week of plan; today not counted):', ...weeks]
      : []),
    `recent events: ${recentEvents(journey, todayKey, streak).join('; ') || 'none'}`,
    `in their own words: ${ownWords(window14) || 'nothing written yet'}`,
  ];

  return {text: lines.join('\n'), journey, todayKey, day, streak};
}

/**
 * The app's money format, on the server: whole dollars, `$` in front,
 * thousands separated — `LpFormat.money(v, locale)` with its default
 * `decimalDigits: 0`. Both round half away from zero for positive amounts
 * (Dart's `num.round()` inside intl, ECMA-402's `halfExpand`), pinned by the
 * 2.5 case in `memoryCard.test.ts` and `test/domain/today_snapshot_test.dart`.
 */
export function wholeDollars(amount: number): string {
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(amount);
}

/** `plan day: 2 of 30 (taper)`, or past the plan the phrasing Home uses. */
function planDayLine(plan: Journey['plan'], day: number): string {
  const total = totalDays(plan);
  if (day > total) {
    const past = day - total;
    return (
      `plan day: ${day} · ${past} day${past === 1 ? '' : 's'} past Freedom Day ` +
      `(${total}-day plan finished, maintenance)`
    );
  }
  return `plan day: ${day} of ${total} (${plan.method})`;
}

function list(values: readonly string[]): string {
  return values.length > 0 ? values.join(', ') : 'not set';
}

/** The onboarding answers, as a sentence rather than a field dump. */
function describeProfile(
  profile: Journey['profile'],
  age: number | null,
): string {
  const parts: string[] = [];
  if (age !== null && age > 0 && age < 120) parts.push(`${age}yo`);
  if (profile.gender !== null) parts.push(profile.gender);
  if (profile.frequency !== null) parts.push(`vapes ${profile.frequency}`);
  if (profile.firstPuff !== null) {
    parts.push(`first puff ${firstPuffPhrase(profile.firstPuff)}`);
  }
  if (profile.attempts !== null) parts.push(attemptsPhrase(profile.attempts));
  return parts.length > 0 ? parts.join(', ') : 'not much said yet';
}

/**
 * What they are actually vaping, as device context.
 *
 * Deliberately NOT milligrams per day. `MG_PER_PUFF` would make that figure
 * trivial to compute, and it is the wrong number to hand this model: docs/04
 * §4's HARD SAFETY RULES forbid dosing guidance of any kind, and a per-day
 * milligram total is a dose whatever we call it. The strength of the pod is a
 * fact about their hardware — it separates someone stepping down from 50mg
 * salts from someone on 20mg, which is a genuinely different withdrawal, and
 * it says nothing about how much they should take.
 *
 * "notSure" passes through as unknown rather than defaulting: the engines
 * treat it as 50mg for arithmetic (docs/03 §2), but stating that back to
 * someone who told us they did not know would be inventing their answer.
 */
function strengthPhrase(strength: NicStrength): string {
  switch (strength) {
    case 'mg20':
      return '20mg pods';
    case 'mg35':
      return '35mg pods';
    case 'mg50':
      return '50mg pods';
    default:
      return 'strength unknown';
  }
}

function firstPuffPhrase(window: string): string {
  switch (window) {
    case 'withinFive':
      return 'within 5 min of waking';
    case 'fiveToThirty':
      return '5-30 min after waking';
    case 'thirtyToSixty':
      return '30-60 min after waking';
    default:
      return 'over an hour after waking';
  }
}

/**
 * Prior attempts, phrased so the coach reads it as history rather than as a
 * score. docs/04's voice rule: never imply someone has failed before.
 */
function attemptsPhrase(attempts: string): string {
  switch (attempts) {
    case 'never':
      return 'first serious try';
    case 'once':
      return 'tried once before';
    case 'twoToFive':
      return 'tried 2-5 times before';
    default:
      return 'tried many times before';
  }
}

/**
 * What the money is FOR. "You're two thirds of the way to the Tokyo flight"
 * lands; "you have saved $312" is a number.
 */
function goalsLine(journey: Journey, saved: number): string {
  if (journey.goals.length === 0) return 'no goal set';
  return journey.goals
    .map((g) => {
      const pct =
        g.price > 0 ? Math.min(100, Math.round((saved / g.price) * 100)) : 0;
      return `${g.name} (${pct}% of ${g.price.toFixed(0)})`;
    })
    .join(', ');
}

/**
 * The user's own mood notes and slip triggers from the trailing window.
 *
 * The single most personal thing in the journey document, and the card used to
 * drop it entirely — Ember could see that a day went badly but not that the
 * user had written "work party tonight, nervous" next to it.
 */
function ownWords(window: readonly DayLog[]): string {
  const notes = window
    .filter((d) => d.moodNote !== null || d.slipTrigger !== null)
    .slice(-3)
    .map((d) => {
      const bits = [d.moodNote, d.slipTrigger === null ? null : `blamed ${d.slipTrigger}`]
        .filter((b): b is string => b !== null)
        .join(' — ');
      return `${d.date}: ${bits}`;
    });
  return notes.join(' | ');
}

/**
 * The short "what just happened" line. This is what lets Ember open with
 * "rough one yesterday" instead of "how can I help?" — worth its tokens.
 */
function recentEvents(journey: Journey, todayKey: string, streak: number): string[] {
  const events: string[] = [];
  const [yesterday] = trailingDays(journey.days, todayKey, 1);
  if (yesterday && yesterday.puffs > yesterday.limit) {
    events.push(`slipped yesterday (+${yesterday.puffs - yesterday.limit} over)`);
  }
  if (yesterday?.repairTokenUsed === true) events.push('used a repair token');
  if (streak > 0 && streak === journey.longestStreak) {
    events.push(`at their longest streak ever (${streak}d)`);
  }
  if (yesterday?.mood != null) events.push(`logged mood "${yesterday.mood}"`);
  return events;
}

/**
 * When they started and where that puts them — the line that makes "how long
 * have I been trying?" answerable with a date rather than a shrug. Past the
 * plan's end it switches to maintenance phrasing: tenure keeps counting, and
 * "week 17" of a finished 30-day plan is an achievement, not an error.
 */
function tenureLine(plan: Journey['plan'], day: number): string {
  const total = totalDays(plan);
  const weekIn = Math.floor((day - 1) / 7) + 1;
  if (day > total) {
    const since = day - total;
    return (
      `started: ${plan.startDate} · week ${weekIn} · finished the ` +
      `${total}-day plan ${since} day${since === 1 ? '' : 's'} ago (maintenance)`
    );
  }
  const weekOf = Math.ceil(total / 7);
  const left = total - day;
  const leftPhrase =
    left === 0 ? 'last day of the plan' : `${left} day${left === 1 ? '' : 's'} left in plan`;
  return `started: ${plan.startDate} · week ${weekIn} of ${weekOf} · ${leftPhrase}`;
}

/**
 * One compact line per week (~15-20 tokens each), capped so a long tenure
 * cannot blow the card's budget: past 12 weeks the card keeps w1 (the
 * baseline anchor every "how far have I come" comparison needs), marks the
 * omission, and carries the latest 10 in full.
 */
function weekLines(stats: readonly WeekStat[], day: number): string[] {
  // A current week with nothing elapsed yet has nothing to say — the card's
  // `today:` line already covers the live day.
  const visible = stats.filter((s) => !(s.current && s.elapsed === 0));
  const lines = visible.map((s) => weekLine(s, day));
  if (lines.length > 12) {
    const omittedFrom = visible[1]!.week;
    const omittedTo = visible[visible.length - 11]!.week;
    return [
      lines[0]!,
      `… (w${omittedFrom}–w${omittedTo} omitted)`,
      ...lines.slice(-10),
    ];
  }
  return lines;
}

function weekLine(s: WeekStat, day: number): string {
  // "1 day so far" beside "day 2 of 30" is how the model came to say "day
  // one": the count is of COMPLETED days and says so, and the current line
  // restates the plan day so the two can never be read as one number.
  const label = s.current
    ? `w${s.week} (current, ${s.elapsed} completed day${s.elapsed === 1 ? '' : 's'}; ` +
      `today is plan day ${day})`
    : `w${s.week}`;
  if (s.logged === 0) return `${label}: no days logged`;
  const parts = [
    `avg ${s.avgPuffs} puffs/day`,
    `${s.onTarget}/${s.elapsed} on target`,
  ];
  if (s.slips > 0) parts.push(`${s.slips} slip${s.slips === 1 ? '' : 's'}`);
  const unlogged = s.elapsed - s.logged;
  if (unlogged > 0) parts.push(`${unlogged} unlogged`);
  if (s.best !== null) parts.push(`best day ${s.best.puffs}`);
  return `${label}: ${parts.join(' · ')}`;
}
