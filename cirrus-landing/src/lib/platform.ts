// Who is asking, and where should they be sent — the whole of /get's decision,
// with nothing platform-specific about the server running it.
//
// It lives in src/lib/ rather than inside functions/get.ts so that there is ONE
// implementation and two thin adapters over it: the Cloudflare Pages Function
// that serves /get in production, and the Astro dev middleware that serves it
// on localhost:4321. The alternative was writing this twice, and this repo has
// already paid for that once — two copies of the streak engine drifted, and the
// coach started quoting numbers the Home screen contradicted.
//
// The dev adapter is not a convenience. A path that 404s in `astro dev` and
// works in production is a path nobody can check before deploying it.

import { DOWNLOAD_URL, storeUrlFor, type Platform } from './store';

/** A headers bag — `Request.headers` in both adapters, but typed to the two
 *  methods actually used so this module needs no runtime-specific types. */
export interface HeaderSource {
  get(name: string): string | null;
}

// Where the tap happened, for the Play referrer. Same shape as the waitlist's
// `source` and allow-listed for the same reason: it arrives in a URL anyone can
// edit, and it ends up in both a log line and an outbound URL.
const CAMPAIGN_RE = /^[a-z0-9][a-z0-9-]{0,79}$/;
const DEFAULT_CAMPAIGN = 'get';

/**
 * Crawlers and link unfurlers, checked BEFORE any device test.
 *
 * This ordering is the whole reason the list exists. Googlebot Smartphone
 * identifies itself as a Nexus 5X — "Linux; Android 6.0.1" — so a naive
 * /android/ test hands our primary indexing crawler a redirect to
 * play.google.com, and Google then indexes Play's page as what lives at /get.
 * bingbot is worse: its current variant spoofs Android and its legacy variant
 * spoofs iPhone, so it trips BOTH device tests depending on the day.
 *
 * The unfurlers matter for the opposite reason — /get is the link under the
 * promo card shared into chat apps, and a bot followed to a store unfurls the
 * store's card instead of ours.
 *
 * Every token is matched in its DISCRIMINATING form, because the near-miss is
 * always a real person: `facebookexternalhit` and not `facebook`, which would
 * catch the Facebook in-app browser; `linkedinbot` and not `linkedin`;
 * `whatsapp/` with the slash. And an explicit list rather than /bot/i, which
 * matches CUBOT — a real Android phone brand — and any model containing "Robot".
 */
const BOT_RE =
  /(?:googlebot|google-inspectiontool|googleother|google-extended|storebot-google|bingbot|adidxbot|duckduckbot|baiduspider|yandex(?:bot|images)|slurp|applebot|petalbot|sogou|exabot|ia_archiver|ahrefsbot|semrushbot|mj12bot|dotbot|screaming frog|facebookexternalhit|facebookcatalog|facebot|meta-external(?:agent|fetcher)|twitterbot|linkedinbot|slackbot|slack-imgproxy|discordbot|telegrambot|whatsapp\/|pinterest(?:bot)?\/|redditbot|snapchat|skypeuripreview|vkshare|embedly|iframely|quora link preview|nuzzel|outbrain|w3c_validator|gptbot|oai-searchbot|chatgpt-user|claudebot|claude-web|anthropic-ai|perplexitybot|bytespider|amazonbot|chrome-lighthouse|headlesschrome|curl\/|wget|python-requests|okhttp|go-http-client|axios\/|node-fetch|java\/|libwww-perl|apache-httpclient)/i;

/**
 * The generic tail of the bot check: a UA that embeds a contact URL.
 *
 * No real browser says "+http://" about itself. It catches the polite crawler
 * nobody has heard of yet, which is most of them, and it is why the list above
 * does not have to be exhaustive to be safe.
 */
const BOT_CONTACT_RE = /\+https?:\/\//i;

/**
 * What the visitor is holding, as far as a request can say.
 *
 * ORDER IS LOAD-BEARING, and not in the obvious way. Windows Phone has to be
 * eliminated before either device test, because its UA spoofed BOTH platforms
 * at once to get served mobile pages: Windows Phone 8.1 sent "Windows Phone
 * 8.1; Android 4.0 ... like iPhone OS 7_0_3 Mac OS X". Test Android first and
 * it reads as an Android; test iOS first and it reads as an iPhone; exclude it
 * from only one of them — which is what this did on its first draft — and it
 * silently becomes the other. The platform is dead and the clause is one line,
 * which is the whole argument for keeping it.
 *
 * `Sec-CH-UA-Platform` is an OR, never a requirement. It is a low-entropy
 * client hint sent by default on the first navigation with no Accept-CH round
 * trip, so it costs nothing and it keeps working if Chrome reduces the UA
 * string further — but Safari and Firefox send no hints at all, so requiring it
 * would lose Firefox for Android entirely.
 *
 * TWO DEVICES ARE PROVABLY UNDECIDABLE HERE, and both land in 'other':
 *
 *  - iPad Safari has reported a desktop Mac UA since iPadOS 13, byte-identical
 *    to a real Mac, and Safari sends no client hints — so no header separates
 *    them, on any plan, in any browser.
 *  - Android tablets big enough for Chrome's default desktop mode report
 *    "X11; Linux x86_64" with Sec-CH-UA-Platform: "Linux", identical to Linux
 *    desktop Chrome.
 *
 * Neither is chased with a heuristic, because a wrong guess sends somebody to a
 * store they cannot install from. They fall through to /download, which is
 * exactly why that page has to keep every open store's button on it.
 */
export function platformOf(headers: HeaderSource): Platform | 'bot' {
  const ua = headers.get('user-agent') ?? '';

  // A request with no UA at all is a script, not a person with a phone.
  if (!ua.trim()) return 'bot';
  if (BOT_RE.test(ua) || BOT_CONTACT_RE.test(ua)) return 'bot';

  if (/windows phone/i.test(ua)) return 'other';
  if (/iphone|ipad|ipod/i.test(ua)) return 'ios';

  const chPlatform = headers.get('sec-ch-ua-platform') ?? '';
  if (/android/i.test(ua) || chPlatform === '"Android"') return 'android';

  return 'other';
}

/** `?c=` if it is a plausible campaign slug, otherwise the default. */
export function campaignFrom(url: URL): string {
  const asked = (url.searchParams.get('c') ?? '').trim().toLowerCase();
  return CAMPAIGN_RE.test(asked) ? asked : DEFAULT_CAMPAIGN;
}

/** Everything /get decides, so both adapters agree by construction. */
export function resolveGet(
  url: URL,
  headers: HeaderSource,
): { platform: Platform | 'bot'; campaign: string; target: string } {
  const campaign = campaignFrom(url);
  const platform = platformOf(headers);
  // A bot gets the page, never a store: it is here to render a preview card or
  // to index something, and both of those should be ours.
  const target = (platform === 'bot' ? null : storeUrlFor(platform, campaign)) ?? DOWNLOAD_URL;
  return { platform, campaign, target };
}

/**
 * The redirect itself, identical in dev and in production.
 *
 * 302 AND no-store, and both halves are load-bearing.
 *
 * A 301 is cached by the browser effectively forever. Every iPhone that taps
 * /get before the App Store opens would keep going to /download afterwards —
 * privately, with nothing on the server able to reach it — and would never see
 * the App Store even after it opened. The destination here is a flag away from
 * changing, so it must never be a permanent answer.
 *
 * (The `_redirects` rule this replaced was a 301, which would have made that
 * real. It was never deployed — /get has been a 404 in production — so nothing
 * is cached in the wild today. That is luck, not design.)
 *
 * no-store is the same argument one layer out: this response depends on a
 * request header, so a shared cache keyed only on the URL would serve one
 * visitor's redirect to the next. Vary says the same thing to anything that
 * caches despite being told not to.
 */
export function redirectTo(target: string): Response {
  return new Response(null, {
    status: 302,
    headers: {
      location: target,
      'cache-control': 'private, no-store, max-age=0',
      vary: 'user-agent',
      // /get is a door, not a page. Nothing should try to rank it — /download
      // is the indexable answer to "cirrus download" and carries the copy, the
      // schema and the internal links.
      'x-robots-tag': 'noindex',

      // RESTATED HERE BECAUSE public/_headers CANNOT REACH THIS RESPONSE.
      // Cloudflare is explicit that custom headers in `_headers` are not
      // applied to anything a Pages Function generates, even when the URL
      // matches a rule — so the `/*` block that gives every other URL on this
      // site HSTS and nosniff stops at the one path that is a Function. Left
      // alone, /get would have been the single response on cirrusquit.com
      // served without them, which is the kind of hole nobody finds by looking
      // at the file that is supposed to contain the answer.
      //
      // Referrer-Policy is not only consistency: it is what decides that Play
      // and the App Store are told the visitor came from cirrusquit.com and
      // not which page they were reading when they tapped.
      'strict-transport-security': 'max-age=31536000; includeSubDomains',
      'x-content-type-options': 'nosniff',
      'referrer-policy': 'strict-origin-when-cross-origin',
    },
  });
}
