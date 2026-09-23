// The only place that builds a store URL.
//
// Every CTA on this site routes through here, so nothing else ever writes a
// store href by hand. That is the whole point: a blog post once hard-coded a
// play.google.com link before the listing was public, and it sat there dead
// because nothing could tell it the store was still closed.

import { APP_STORE_URL, PLAY_STORE_URL } from '../consts';
import { DEFAULT_LOCALE } from '../i18n/locales.mjs';

/**
 * The page that always exists and always puts the reader's own store first.
 *
 * Markdown cannot read the store URLs, so posts link here rather than at a
 * store directly. The Android app claims this path through App Links, so on a
 * phone that already has Cirrus the link opens the app instead.
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
 * Prefer [playUrl] / [appStoreUrl] for a link whose platform you already know.
 * /get is for links that have to survive being read on a phone you cannot see.
 */
export const GET_URL = '/get';

/** The three answers `/get` can reach from a User-Agent. */
export type Platform = 'android' | 'ios' | 'other';

/**
 * A Play link tagged so Play Console's acquisition report can attribute the
 * install to the page it came from — no SDK, no advertising ID, no third party.
 *
 * Play expects `referrer` to be one URL-encoded query string, hence the single
 * encodeURIComponent over the whole thing. The format has to be right from the
 * first tagged link: installs attributed wrongly cannot be re-attributed later.
 *
 * @param campaign where the tap happened — `hero`, `closing`, `blog-<slug>`
 */
export function playUrl(campaign: string): string {
  const referrer = new URLSearchParams({
    utm_source: 'cirrusquit.com',
    utm_medium: 'web',
    utm_campaign: campaign,
  }).toString();
  const sep = PLAY_STORE_URL.includes('?') ? '&' : '?';
  return `${PLAY_STORE_URL}${sep}referrer=${encodeURIComponent(referrer)}`;
}

/**
 * The campaign name for a tap on a page in `lang`.
 *
 * English names are EXACTLY what they were before the site had a second
 * language — `hero`, `closing`, `blog-<slug>` — because installs already
 * attributed to them cannot be re-attributed. Every other locale gets its code
 * as a prefix: `es-hero`, `fr-blog-<slug>-end`.
 *
 * A prefix rather than a suffix, for three reasons: it is one mechanical rule
 * at one position; Play Console's acquisition report then sorts by language;
 * and it cannot collide with an English campaign, since none starts with a
 * locale code. The longest today is 48 characters with its prefix, inside the
 * 80 that /get's allow-list accepts (see CAMPAIGN_RE in platform.ts).
 *
 * FROZEN AT THE FIRST TAGGED INSTALL, like the referrer format above.
 */
export function campaignFor(lang: string, base: string): string {
  return lang === DEFAULT_LOCALE ? base : `${lang}-${base}`;
}

/**
 * The App Store link, deliberately untagged.
 *
 * Apple only attributes a campaign token (`ct`) sent together with the provider
 * token (`pt`) from App Store Connect, and the privacy policy tells readers that
 * only Play links carry a tag. Tag this and that sentence has to change with it.
 */
export function appStoreUrl(): string {
  return APP_STORE_URL;
}

/**
 * The store URL for one platform, or `null` when there is no store to send
 * that platform to.
 *
 * Both listings are live, so only `other` answers null today. The null stays in
 * the signature because it is what the `/get` redirector branches on: "send
 * them to a store" versus "send them to [DOWNLOAD_URL]". A fallback baked in
 * here would make a desktop visitor look to it like a successful redirect.
 *
 * @param platform what the User-Agent said the visitor is holding
 * @param campaign where the tap happened — `get`, `blog-<slug>`, `qr-card`
 */
export function storeUrlFor(platform: Platform, campaign: string): string | null {
  if (platform === 'android') return playUrl(campaign);
  if (platform === 'ios') return appStoreUrl();
  return null;
}
