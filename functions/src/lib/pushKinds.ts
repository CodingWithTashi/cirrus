/**
 * What kinds of push exist, and how each one behaves.
 *
 * Every send goes through this table. The point is that adding a new kind —
 * a personal nudge, a promotional campaign — is one row here plus its copy,
 * never a new send path with its own half-remembered rules about preferences
 * and quiet hours. `lib/push.ts` reads nothing else to decide how to deliver.
 *
 * ## The channel ids are permanent
 *
 * An Android notification channel's IMPORTANCE is fixed when the channel is
 * created. `createNotificationChannel` on an id that already exists updates
 * its name and description and nothing else, by design — the user owns that
 * setting once they have seen it. So a channel cannot be made quieter later,
 * and an id that has shipped can never be reused for a different behaviour.
 *
 * That is why quiet hours need a SECOND channel rather than a flag. From
 * Android 8 the channel decides sound, vibration and heads-up, and the
 * per-message priority FCM will happily accept is ignored outright. Each
 * category therefore ships as a pair — the normal one and its quiet twin —
 * grouped so system settings shows them nested under one heading instead of
 * as four unrelated rows.
 *
 * iOS needs none of this: `interruption-level: passive` is a per-message
 * field there, so the quiet channel id is simply unused on that platform.
 */

/** Every push this app can send. `system` and `promo` are reserved. */
export type PushKind =
  | 'communityReply'
  | 'communityMention'
  | 'sosReply'
  | 'insightReady'
  | 'system'
  | 'promo';

/**
 * Keys under `users/{uid}.pushPrefs`.
 *
 * `all` is the master switch, mirrored from the app's own `notificationsOn`.
 * Before it existed, turning notifications off cancelled the locally
 * scheduled reminders and told the server nothing at all, so every server
 * push kept arriving — the one setting a user reaches for when an app is
 * bothering them did not stop the half of it coming from us.
 */
export type PushPrefKey =
  | 'all'
  | 'communityReply'
  | 'communityMention'
  | 'insightReady'
  | 'promo';

export interface KindSpec {
  /**
   * Which preference silences this kind, beyond the `all` master. Null for
   * kinds a user cannot turn off individually.
   */
  readonly prefKey: PushPrefKey | null;
  /** Android channel when delivered normally. */
  readonly channelId: string;
  /** Android channel when delivered inside the recipient's quiet hours. */
  readonly quietChannelId: string;
  /** Whether repeat sends collapse into one thread notification. */
  readonly collapses: boolean;
  /** Whether quiet hours may downgrade this to a silent delivery. */
  readonly respectsQuietHours: boolean;
  /** Whether this spends from the recipient's daily interpersonal budget. */
  readonly countsAgainstBudget: boolean;
}

export const CHANNEL_COMMUNITY = 'community_replies';
export const CHANNEL_COMMUNITY_QUIET = 'community_replies_quiet';
export const CHANNEL_INSIGHTS = 'insights';
export const CHANNEL_INSIGHTS_QUIET = 'insights_quiet';

/**
 * The channel every push landed in before there were categories, named in the
 * app manifest as `default_notification_channel_id`.
 *
 * Kept forever. It is the fallback for any message that names no channel, and
 * deleting a channel discards whatever the user configured on it.
 */
export const CHANNEL_DEFAULT = 'messages';

const COMMUNITY: Pick<
  KindSpec,
  'channelId' | 'quietChannelId' | 'countsAgainstBudget'
> = {
  channelId: CHANNEL_COMMUNITY,
  quietChannelId: CHANNEL_COMMUNITY_QUIET,
  countsAgainstBudget: true,
};

export const PUSH_KINDS: Record<PushKind, KindSpec> = {
  /** Somebody replied to an ordinary post of yours. */
  communityReply: {
    ...COMMUNITY,
    prefKey: 'communityReply',
    collapses: true,
    respectsQuietHours: true,
  },

  /**
   * Somebody tagged you. Never collapsed: a mention is addressed to one
   * person, and folding it into "3 new replies" loses the only fact that
   * made it worth sending.
   */
  communityMention: {
    ...COMMUNITY,
    prefKey: 'communityMention',
    collapses: false,
    respectsQuietHours: true,
  },

  /**
   * Somebody answered your SOS.
   *
   * The one kind that neither collapses nor goes quiet, and the reasoning is
   * the same for both: this is docs/03 §7's "someone else pulls you out", and
   * the hour it matters most is the hour quiet hours would silence it. It
   * also does not collapse, because the whole content of the message is *how
   * many people came* — an author told that one person replied, who is never
   * told about the two who followed, has been failed at the one moment this
   * feature exists for.
   */
  sosReply: {
    ...COMMUNITY,
    prefKey: 'communityReply',
    collapses: false,
    respectsQuietHours: false,
    countsAgainstBudget: false,
  },

  /** The weekly report finished generating. */
  insightReady: {
    prefKey: 'insightReady',
    channelId: CHANNEL_INSIGHTS,
    quietChannelId: CHANNEL_INSIGHTS_QUIET,
    collapses: false,
    respectsQuietHours: true,
    countsAgainstBudget: false,
  },

  /** Reserved: account and service messages. No sender yet. */
  system: {
    prefKey: null,
    channelId: CHANNEL_DEFAULT,
    quietChannelId: CHANNEL_DEFAULT,
    collapses: false,
    respectsQuietHours: true,
    countsAgainstBudget: false,
  },

  /** Reserved: campaigns. Opt-out by default, unlike everything above. */
  promo: {
    prefKey: 'promo',
    channelId: CHANNEL_DEFAULT,
    quietChannelId: CHANNEL_DEFAULT,
    collapses: false,
    respectsQuietHours: true,
    countsAgainstBudget: false,
  },
};

export function specFor(kind: PushKind): KindSpec {
  return PUSH_KINDS[kind];
}

/**
 * Whether [prefs] permit [kind].
 *
 * An ABSENT preference means enabled. That is what lets this ship without a
 * migration — nobody has a `pushPrefs` map yet, and defaulting the other way
 * would silence every existing user the moment this deploys. `promo` is the
 * exception and must be opted into explicitly.
 */
export function allowedByPrefs(
  kind: PushKind,
  prefs: Readonly<Record<string, unknown>> | undefined,
): boolean {
  if (prefs?.['all'] === false) return false;
  const spec = specFor(kind);
  if (spec.prefKey === null) return true;
  const value = prefs?.[spec.prefKey];
  if (spec.prefKey === 'promo') return value === true;
  return value !== false;
}
