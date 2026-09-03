// The one place that knows whether the app is downloadable, and the only place
// that builds a store URL.
//
// Every CTA on this site routes through here. That is the whole point: a blog
// post once hard-coded a play.google.com link to a listing that was not public
// yet, and it sat there dead because nothing could tell it the store was still
// closed. A component cannot make that mistake if it cannot write the href.

import { PLAY_STORE_URL } from '../consts';

/** True once the Play listing exists and PLAY_STORE_URL has been filled in. */
export const STORE_LIVE = PLAY_STORE_URL !== '';

/**
 * The page that always exists, whether or not the listing does.
 *
 * Markdown cannot read PLAY_STORE_URL, so posts link here rather than at the
 * store directly — the destination stays correct without editing prose.
 */
export const DOWNLOAD_URL = '/download';

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
