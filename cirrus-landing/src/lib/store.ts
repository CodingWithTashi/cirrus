// The one place that knows whether the app is downloadable, and the only place
// that builds a store URL.
//
// Every CTA on this site routes through here. That is the whole point: a blog
// post once hard-coded a play.google.com link to a listing that was not public
// yet, and it sat there dead because nothing could tell it the store was still
// closed. A component cannot make that mistake if it cannot write the href.

import { PLAY_STORE_URL, APP_STORE_URL, IOS_STORE_LIVE } from '../consts';

/** True once the Play listing exists and PLAY_STORE_URL has been filled in. */
export const STORE_LIVE = PLAY_STORE_URL !== '';

/**
 * True once the App Store listing is actually open.
 *
 * Two conditions, not one: the id has been known since the app record was
 * created, so a non-empty APP_STORE_URL proves nothing on its own. The flag is
 * what says a human has seen the version go live.
 */
export const IOS_LIVE = IOS_STORE_LIVE && APP_STORE_URL !== '';

/**
 * The page that always exists, whether or not the listing does.
 *
 * Markdown cannot read PLAY_STORE_URL, so posts link here rather than at the
 * store directly — the destination stays correct without editing prose.
 */
export const DOWNLOAD_URL = '/download';

/**
 * The short link that picks the store for you — served by `functions/get.ts`.
 *
 * This is the one to hand out: a bio, a QR code, a printed card, a reply to
 * someone asking what the app is called. It reads the User-Agent and bounces
 * Android to Play and iPhone to the App Store, and it falls back to
 * [DOWNLOAD_URL] for everyone else, so it is never wrong and never a dead end.
 *
 * Prefer [playUrl] for a link whose platform you already know — a Play button
 * on a page should go straight to Play rather than through a redirect. /get is
 * for links that have to survive being read on a phone you cannot see.
 */
export const GET_URL = '/get';

/** The three answers `/get` can reach from a User-Agent. */
export type Platform = 'android' | 'ios' | 'other';

/**
 * A Play link tagged so the install can be attributed without an SDK.
 *
 * Play Console's acquisition report reads the `utm_*` values, and the app reads
 * the same string back on first launch through the Play Install Referrer — no
 * advertising ID, no MMP, no third party. That referrer is the join key between
 * "someone read a blog post" and "someone started a trial", so the format has to
 * be right from the first tagged link: installs attributed wrongly on day one
 * cannot be re-attributed later.
 *
 * Play expects `referrer` to be one URL-encoded query string, hence the single
 * encodeURIComponent over the whole thing.
 *
 * @param campaign where the tap happened — `hero`, `blog-<slug>`, `desktop-qr`
 * @param content  optional extra detail, e.g. the visitor's calculator numbers
 */
export function playUrl(campaign: string, content?: string): string {
  if (!STORE_LIVE) return DOWNLOAD_URL;

  const params: Record<string, string> = {
    utm_source: 'cirrusquit.com',
    utm_medium: 'web',
    utm_campaign: campaign,
  };
  if (content) params.utm_content = content;

  const referrer = new URLSearchParams(params).toString();
  const sep = PLAY_STORE_URL.includes('?') ? '&' : '?';
  return `${PLAY_STORE_URL}${sep}referrer=${encodeURIComponent(referrer)}`;
}

/**
 * The visitor's own calculator numbers, compacted for `utm_content`.
 *
 * The app uses these to pre-fill the two onboarding questions people abandon on
 * — puffs a day and weekly spend — so someone who did the maths on the web does
 * not have to do it again in the app.
 *
 * Integers only, and clamped: this rides in a URL anyone can edit and share, so
 * it must never be free text and never carry anything that identifies a person.
 * The app treats it as a prefill the user can change, never as a fact.
 */
export function calcContent(puffs: number, spend: number): string {
  const clamp = (n: number, max: number) =>
    Number.isFinite(n) ? Math.min(Math.max(Math.round(n), 0), max) : 0;
  return `p${clamp(puffs, 2000)}s${clamp(spend, 1000)}`;
}

/**
 * The App Store link. Deliberately untagged — see below.
 *
 * The `campaign` is accepted and ignored on purpose, so that every caller can
 * be written the way it will stay written once tagging is possible.
 *
 * WHY NOT TAGGED YET. Apple's equivalent of the Play referrer is a campaign
 * link, and it needs BOTH tokens: `ct` (the campaign) and `pt` (the provider,
 * which identifies the developer account). Apple is explicit that both are
 * required, and a `ct` on its own records nothing at all — which is the worst
 * possible failure here, because the link still works, the installs still
 * arrive, and App Analytics simply shows an empty Campaigns table that reads
 * like nobody came. This repo has been bitten by exactly that shape twice
 * already: a model id that did not exist, and a kill switch compared the wrong
 * way round. Both looked like a decision and were a typo.
 *
 * And `pt` cannot be obtained today even if we wanted it: App Store Connect
 * mints it the first time you create a campaign link, and the Campaigns
 * section only appears once the app has received analytics data — which needs
 * a released app. So the honest state is untagged, and the follow-up is one
 * line in this function the week after launch.
 *
 * Other things established while checking this, so nobody re-checks them:
 * the country-less `/app/id<id>` form is correct (Apple geolocates it to the
 * visitor's own storefront — hardcoding `/us/` would show a German reader US
 * pricing); the slug is cosmetic and Apple rewrites it; `mt=8` is vestigial
 * and Apple's own edge strips it; and `itms-apps://` is not web-safe — an
 * https link already opens the App Store app directly on an iPhone, because
 * iOS resolves apps.apple.com as a universal link.
 */
export function appStoreUrl(campaign: string): string {
  void campaign;
  return IOS_LIVE ? APP_STORE_URL : DOWNLOAD_URL;
}

/**
 * The store URL for one platform, or `null` when that store has nothing to open.
 *
 * The null is the point, and it is why this exists beside [playUrl] rather than
 * inside it. [playUrl] answers a page, so "no store yet" has to become a link
 * somewhere — [DOWNLOAD_URL]. This answers the `/get` redirector, which has to
 * tell "send them to a store" apart from "send them to the page", and a
 * fallback baked in here would make every iPhone in the world look to it like a
 * successful redirect to the App Store.
 *
 * @param platform what the User-Agent said the visitor is holding
 * @param campaign where the tap happened — `get`, `blog-<slug>`, `qr-card`
 */
export function storeUrlFor(platform: Platform, campaign: string): string | null {
  if (platform === 'android') return STORE_LIVE ? playUrl(campaign) : null;
  if (platform === 'ios') return IOS_LIVE ? appStoreUrl(campaign) : null;
  return null;
}
