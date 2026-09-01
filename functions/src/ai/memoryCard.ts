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
  const saved = Object.values(journey.days).reduce(
    (acc, d) => acc + Math.max(0, plan.baselinePuffsPerDay - d.puffs) * costPerPuff,
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

  const weeks = weekLines(weekStats(journey.days, plan.startDate, todayKey));

  const lines = [
    'USER CARD',
    // The model once congratulated a day-1 user on "making it to day two"
    // because a "good morning" greeting after older messages read like a new
    // day. Date and clock in their zone, stated outright, so the day number
    // never has to be inferred from conversation shape.
    `today's date: ${todayKey} (${weekday}) · their local time: ${localTime}`,
    `alias: ${profile.alias} · day ${day} of ${totalDays(plan)} (${plan.method})`,
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
    `money saved: ${saved.toFixed(2)} · cravings survived: ${journey.cravingsSurvivedTotal}`,
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
function weekLines(stats: readonly WeekStat[]): string[] {
  // A current week with nothing elapsed yet has nothing to say — the card's
  // `today:` line already covers the live day.
  const visible = stats.filter((s) => !(s.current && s.elapsed === 0));
  const lines = visible.map(weekLine);
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

function weekLine(s: WeekStat): string {
  const label = s.current
    ? `w${s.week} (current, ${s.elapsed} day${s.elapsed === 1 ? '' : 's'} so far)`
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
