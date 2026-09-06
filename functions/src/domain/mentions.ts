/**
 * Working out who an `@alias` in a reply was aimed at.
 *
 * ## Why this is thread-scoped and not a lookup table
 *
 * There is no trustworthy global `alias -> uid` index to build one from, and
 * there cannot be while aliases work the way they do. `_randomAlias()` mints
 * them ON THE CLIENT from 8 adjectives x 8 animals x 90 numbers — 5,760
 * possibilities, from a plain `Random()`, with no uniqueness check anywhere.
 * By the birthday bound two users share an alias at around ninety accounts.
 * They are stored in the client-owned journey document, and the server has
 * never verified that a caller owns the alias it posts under.
 *
 * So an alias does not identify a person. What it does do, reliably, is
 * identify a VOICE IN A CONVERSATION — which is the only sense in which
 * anybody types one. Matching against the handful of people already in the
 * thread is therefore both cheaper than a global index and closer to what the
 * writer meant.
 *
 * ## First claimant wins
 *
 * Two participants in one thread can still collide, and once mentions notify
 * people that collision becomes something worth causing on purpose: reply
 * under your target's alias and every mention of them in that thread goes
 * ambiguous. Dropping ambiguous mentions would hand the attacker exactly what
 * they wanted, so ambiguity resolves to whoever used the alias here FIRST.
 * The post's author precedes every reply, and replies are ordered by their
 * creation. A latecomer cannot displace an incumbent, and the worst an
 * impersonator achieves is failing to be notified themselves.
 */

/**
 * Mentions honoured per reply.
 *
 * A cap because each one costs a lookup, and because a reply naming fifteen
 * people is not a conversation.
 */
export const MAX_MENTIONS = 5;

/**
 * `@quietfox42`, the shape `_randomAlias()` produces.
 *
 * Anchored, bounded on both parts, and matched with a plain `exec` loop
 * rather than assembled from stored text. An alias is untrusted input, so it
 * is never allowed to BECOME a pattern — a stored alias of `(a+)+$` compiled
 * into a regex is a denial of service in a function with no timeout to spare,
 * and a stored alias of `a` used with `includes` matches nearly every reply
 * ever written.
 */
const MENTION = /@[A-Za-z]{3,24}\d{1,3}/g;

/** Somebody who has already spoken in a thread, oldest first. */
export interface ThreadParticipant {
  readonly alias: string;
  readonly uid: string;
}

/** Aliases named in [text], deduped case-insensitively and capped. */
export function parseMentions(text: string): string[] {
  const seen = new Set<string>();
  const found: string[] = [];
  // `matchAll` over a fresh pattern: a module-level /g regex carries
  // `lastIndex` between calls, which makes every second call skip the start
  // of its input.
  for (const match of text.matchAll(new RegExp(MENTION))) {
    const alias = match[0];
    const key = alias.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    found.push(alias);
    if (found.length === MAX_MENTIONS) break;
  }
  return found;
}

/**
 * The uids [text]'s mentions resolve to, excluding [authorUid] themselves.
 *
 * [participants] must be ordered oldest first — that ordering is what makes
 * the collision rule "first claimant wins" rather than "whoever we happened
 * to read last".
 */
export function resolveMentions(
  text: string,
  participants: readonly ThreadParticipant[],
  authorUid: string,
): string[] {
  const byAlias = new Map<string, string>();
  for (const p of participants) {
    const key = p.alias.toLowerCase();
    // First writer wins; a later participant claiming the same alias is
    // ignored rather than allowed to make it ambiguous.
    if (!byAlias.has(key)) byAlias.set(key, p.uid);
  }

  const uids = new Set<string>();
  for (const alias of parseMentions(text)) {
    const uid = byAlias.get(alias.toLowerCase());
    // Mentioning yourself is not a notification. Nor is mentioning somebody
    // who has not spoken in this thread — we have no way to know who they
    // are, and guessing would mean pushing to a stranger with a similar name.
    if (uid !== undefined && uid !== authorUid) uids.add(uid);
  }
  return [...uids];
}
