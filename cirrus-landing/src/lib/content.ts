/**
 * Everything about the landing page's content that is NOT language: which items
 * exist, in what order, on which tier, at what clock time, linking to which
 * post. The words live in src/i18n/<locale>.ts, keyed by the ids declared here.
 *
 * Splitting it this way is what makes a translation checkable. The dictionary
 * types are `Record<StatId, …>`, `Record<FaqId, …>` and so on, so a locale that
 * drops a timeline step, invents a seventh FAQ, or ships a statistic without a
 * source does not compile — the structure cannot drift, only the words can.
 *
 * Two things still appear twice on the page — once as visible markup, once as
 * structured data — and both render from the same dictionary entry, so the FAQ
 * a person reads and the FAQ Google reads can never disagree. That is the usual
 * way FAQ schema turns into a manual action.
 */

/**
 * The ONLY statistics permitted on this site.
 *
 * docs/02 §8 bans "any uncited number" outright — it names "78% of members quit"
 * as the exact thing not to do, because a direct competitor ships it. Every row
 * is from that spec's approved table and carries its source on screen. Adding a
 * row here is part of the same change that renders it; if there is no honest
 * number for a section, the section says nothing instead.
 *
 * `home` marks the three shown on the home page — the strongest, kept to a
 * three-card rhythm. All five stay available to the blog. They used to be picked
 * by matching the English figure ("76%"), which a French "76 %" would have
 * silently dropped.
 *
 * On the home page each of the three sits under a one-line moment the reader
 * recognises (`home.stats.hooks`, keyed by `HomeStatId`), so the card reads as
 * "this is you, and here is the source" rather than a figure on its own. The
 * hook carries no number: the figure below it is the only claim on the card.
 */
export const STATS = [
  { id: 'abstinence' },
  { id: 'wake30', home: true },
  { id: 'failedAttempts', home: true },
  { id: 'cravingWindow', home: true },
  { id: 'puffsPerCig' },
] as const;
export type StatId = (typeof STATS)[number]['id'];
export type HomeStatId = Extract<(typeof STATS)[number], { home: true }>['id'];

/**
 * FAQ order, and which questions hand off to a post.
 *
 * ONE QUERY, ONE PAGE. Where a blog post owns a question, the answer on the home
 * page is deliberately a two-sentence summary with a link to that post: a full
 * answer in both places puts them in competition for the same search, and Google
 * usually resolves that by ranking neither.
 *
 * `more` is a post SLUG, not an href. The renderer resolves it to the post in
 * the reader's language when that translation is live, and to the English post
 * (flagged hreflang="en") when it is not — so translating a post upgrades these
 * links with no edit here. The link is visible markup only and is NOT part of
 * the FAQPage schema, which carries the plain answer.
 */
export const FAQ_ITEMS = [
  { id: 'taper' },
  // "vape puff counter", "vape hit counter", "vape counter": the product queries
  // Search Console shows this site appearing for (Sep 2026). The honest answer
  // to them is that no phone app can count a vape's puffs by itself.
  { id: 'autoCount' },
  { id: 'puffsPerDay', more: 'how-many-puffs-a-day-is-a-lot' },
  { id: 'disposable', more: 'how-many-puffs-in-a-disposable-vape' },
  { id: 'costPerYear' },
  { id: 'slip' },
  { id: 'withdrawal', more: 'how-long-does-vaping-withdrawal-last' },
  { id: 'benefits' },
  { id: 'methods' },
  { id: 'platforms' },
  { id: 'free' },
  { id: 'puffCount', more: 'how-to-choose-a-puff-counter-app' },
] as const;
export type FaqId = (typeof FAQ_ITEMS)[number]['id'];
export type FaqWithMoreId = Extract<(typeof FAQ_ITEMS)[number], { more: string }>['id'];

/**
 * An example day. The clock times are illustrative and the page says so; every
 * feature named is shipped (docs/13) and every tag is its real tier (docs/13 §4).
 * No figure appears beyond the times and the cited craving window.
 *
 * `at` is 24-hour and formatted per locale at build time, so English keeps its
 * "7:40 am" and everyone else gets the clock they actually use.
 */
export const DAY_STEPS = [
  { id: 'first', at: '07:40' },
  { id: 'lunch', at: '12:30', tone: 'ember' },
  { id: 'headsUp', at: '14:50' },
  { id: 'craving', at: '15:04', tone: 'oxygen' },
  { id: 'passed', at: '15:19', tone: 'ember' },
  { id: 'night', at: '23:40' },
  { id: 'midnight', at: '00:00', pro: true },
] as const;
export type DayStepId = (typeof DAY_STEPS)[number]['id'];

/**
 * Free vs Premium. `true` / `false` render as a tick or a dash; `'text'` means
 * the cell is words, which the dictionary supplies. Every value is a real
 * allowance (docs/13 §4, LpAllowances in the app).
 */
export const COMPARE_ROWS = [
  { id: 'counter', free: true, pro: true },
  { id: 'limit', free: true, pro: true },
  { id: 'streak', free: true, pro: true },
  { id: 'money', free: true, pro: true },
  { id: 'panic', free: 'text', pro: 'text' },
  { id: 'coach', free: 'text', pro: 'text' },
  { id: 'community', free: 'text', pro: 'text' },
  { id: 'timeline', free: 'text', pro: 'text' },
  { id: 'history', free: 'text', pro: 'text' },
  { id: 'adaptive', free: false, pro: true },
  { id: 'insight', free: false, pro: true },
  { id: 'themes', free: false, pro: true },
] as const;
export type CompareRowId = (typeof COMPARE_ROWS)[number]['id'];

/** The screenshot rail, in order. The images are imported where they render. */
export const SCREENS = ['home', 'log', 'plan', 'coach', 'panic', 'community', 'stats'] as const;
export type ScreenId = (typeof SCREENS)[number];

/** The "where it lives" cards, in order. The icons are drawn where they render. */
export const DEVICES = ['iphone', 'android', 'widget', 'watch'] as const;
export type DeviceId = (typeof DEVICES)[number];

/**
 * The founder-locked US prices (docs/08 §1, LpPricing in the app). Real prices,
 * not statistics — and US ones in every locale, because a store shows each
 * reader their own and the page says so.
 */
export const PRICES = { week: '$2.99', month: '$7.99', year: '$39.99' } as const;
