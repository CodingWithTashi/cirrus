// Cloudflare Pages Function → served at /get.
//
// The short link that picks the store for you. Android goes to Play, iPhone
// goes to the App Store once there is one, and everyone else lands on
// /download — so a single URL is safe to print on a card, paste into a bio, or
// read out loud, without knowing what the person is holding when they tap it.
//
// WHY A FUNCTION AND NOT A _redirects RULE. `_redirects` matches on path and
// nothing else, so it can only ever have one destination: until now /get was a
// blanket 301 to /download, which meant every Android visitor — the only ones
// who can actually install the app today — had to read a page and find a button
// before reaching the store they were already heading for. Platform is a
// request HEADER, and only code that sees the request can branch on it.
//
// It also replaces that rule outright rather than sitting beside it. A Function
// does win over a matching `_redirects` rule (verified against
// `wrangler pages dev`, both /get and /get/), but two owners of one path is a
// thing nobody should have to test to understand.
//
// THE DECISION IS NOT IN THIS FILE. It is in src/lib/platform.ts, which the
// Astro dev middleware runs too — so /get behaves the same on localhost:4321 as
// it does at the edge. This file is the Cloudflare half: the handler signature
// and the log line.
//
// Config: none. Everything it needs comes from src/lib/store.ts, which stays
// the only place in this repo that builds a store URL.

import { resolveGet, redirectTo } from '../src/lib/platform';

/**
 * One structured line per redirect, for the Pages Functions log.
 *
 * The same deal as the waitlist's `waitlist_submit`: no script, no cookie, no
 * vendor, nothing to consent to. It answers the two questions a short link
 * exists to answer — how many people tap it, and what are they holding — and
 * the iPhone count is the honest version of the waitlist number, because it
 * counts people who wanted the app badly enough to tap rather than people who
 * were shown a form.
 *
 * `country` is Cloudflare's own geo header and the referer is reduced to a
 * host, so no line here identifies a person.
 */
function logRedirect(request: Request, platform: string, campaign: string, target: string): void {
  let referer = '';
  try {
    const raw = request.headers.get('referer');
    if (raw) referer = new URL(raw).host;
  } catch {
    // A malformed Referer is not worth a branch; an empty host is fine.
  }
  const country = (request as { cf?: { country?: string } }).cf?.country ?? '';
  // The destination host, not the whole tagged URL: the campaign is already its
  // own field, and repeating it makes the line harder to read for no new signal.
  const to = target.startsWith('/') ? target : new URL(target).host;
  console.log(JSON.stringify({ event: 'get_redirect', platform, campaign, to, country, referer }));
}

/**
 * Every method, not just GET.
 *
 * `onRequestGet` alone would leave HEAD to fall through to the static assets
 * and 404 — and HEAD is what link checkers, Slack and half the SEO tools send
 * first. A short link that reports itself dead to the tools people use to check
 * whether links are dead is the one failure this whole path exists to prevent.
 */
export const onRequest: PagesFunction = async ({ request }) => {
  const { platform, campaign, target } = resolveGet(new URL(request.url), request.headers);
  logRedirect(request, platform, campaign, target);
  return redirectTo(target);
};
