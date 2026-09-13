// The only place that builds a store URL.
//
// Every CTA on this site routes through here, so nothing else ever writes a
// store href by hand. That is the whole point: a blog post once hard-coded a
// play.google.com link before the listing was public, and it sat there dead
// because nothing could tell it the store was still closed.

import { APP_STORE_URL, PLAY_STORE_URL } from '../consts';

/**
 * The page that always exists and always puts the reader's own store first.
 *
 * Markdown cannot read the store URLs, so posts link here rather than at a
 * store directly. The Android app claims this path through App Links, so on a
 * phone that already has Cirrus the link opens the app instead.
 */
export const DOWNLOAD_URL = '/download';

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
 * The App Store link, deliberately untagged.
 *
 * Apple only attributes a campaign token (`ct`) sent together with the provider
 * token (`pt`) from App Store Connect, and the privacy policy tells readers that
 * only Play links carry a tag. Tag this and that sentence has to change with it.
 */
export function appStoreUrl(): string {
  return APP_STORE_URL;
}
