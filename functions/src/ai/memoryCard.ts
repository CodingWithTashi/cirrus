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
import {currentStreak, dangerHours, flameFor, trailingDays} from '../domain/streakEngine';
import {dayNumber, limitFor} from '../domain/taperEngine';
import {totalDays, type Journey} from '../domain/types';

export interface MemoryCard {
  readonly text: string;
  readonly journey: Journey;
  readonly todayKey: string;
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

  const lines = [
    'USER CARD',
    `alias: ${journey.profile.alias} · day ${day} of ${totalDays(plan)} (${plan.method})`,
    `why: ${list(journey.profile.whys)} · fears: ${list(journey.profile.worries)}`,
    `baseline: ${plan.baselinePuffsPerDay} puffs/day · today: ${today?.puffs ?? 0}/${limit} · streak: ${streak}d (${flameFor(streak)}) · tokens: ${journey.repairTokens}`,
    `money saved: ${saved.toFixed(2)} · cravings survived: ${journey.cravingsSurvivedTotal}`,
    `danger hours: ${hours.length > 0 ? hours.map((h) => `${h}:00`).join(', ') : 'not enough data yet'} · local time now: ${localTime}`,
    `last 7 days: ${last7.length > 0 ? last7.map((d) => d.puffs).join(',') : 'no logs yet'}`,
    `recent events: ${recentEvents(journey, todayKey, streak).join('; ') || 'none'}`,
  ];

  return {text: lines.join('\n'), journey, todayKey, streak};
}

function list(values: readonly string[]): string {
  return values.length > 0 ? values.join(', ') : 'not set';
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
