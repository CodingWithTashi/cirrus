// Site-wide constants — the ONE place brand strings, dates and numbers live.
//
// Copy follows docs/07 §2 voice rules: sentence case, contractions, zero
// clinical language, zero shame words. And docs/02 §8's honest-stats rule:
// no number appears on this site unless it is the visitor's own arithmetic
// or carries a citation. See HONEST_STATS below.

export const SITE_TITLE = 'Cirrus';
export const SITE_TAGLINE = 'Quit vaping without going cold turkey';
// "Counts your real puffs" read as automatic counting, which no phone app can do
// (a Reddit reviewer called it out, Sep 2026). The tap is the product; say so.
export const SITE_DESCRIPTION =
  'Free quit vaping app for iPhone and Android. One tap logs a puff, and your daily limit tapers to zero. No cold turkey, no day-one resets, no invented stats.';

export const SITE_OG_IMAGE = '/og.png';
export const SITE_LOCALE = 'en_US';

// The two live listings. Google Play came first; the App Store listing went
// live on Sep 12 2026, so the site has no waitlist and no "coming soon" left.
//
// Read only through `src/lib/store.ts` — never inline either URL anywhere else,
// and never put one in Markdown. Posts link to /download, which puts the
// reader's own store first.

// "Quit Vaping Tracker : Cirrus" — the id is the Android applicationId.
export const PLAY_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.quitvape.last_puff';

// "Quit Vaping Tracker - Cirrus" — id 6806871144, bundle com.quitvape.lastPuff.
// Storefront-neutral on purpose: a /us/ path sends every reader outside the US
// to the wrong storefront first. The bare id is also what the Smart App Banner
// in BaseLayout takes.
export const APP_STORE_ID = '6806871144';
export const APP_STORE_URL = `https://apps.apple.com/app/id${APP_STORE_ID}`;

// Official profiles, emitted as Organization.sameAs. This is how Google ties
// the domain to a known entity rather than treating it as an anonymous site,
// so fill it in the moment the accounts exist. Deliberately empty for now: a
// sameAs pointing at a profile that does not exist is worse than no sameAs.
export const SOCIAL_PROFILES: string[] = [];

// Legal pages now live on this domain (src/pages/privacy.astro, terms.astro).
// They used to be on Firebase Hosting; same copy, moved so the policy sits on
// the apex domain and appears in the sitemap.
export const PRIVACY_URL = '/privacy';
export const TERMS_URL = '/terms';

// The account-deletion instructions (src/pages/delete-account.astro).
//
// Google Play's User Data policy requires a publicly reachable URL that explains
// how to delete an account, and it is submitted in the Data safety form — so
// this path is effectively frozen once the listing declares it. Change the page,
// never the URL. It is linked from the footer and from the privacy policy so a
// person looking for it never has to know the Play console exists.
export const DELETE_ACCOUNT_URL = '/delete-account';

// The address on both legal pages, and the one data-rights requests arrive at.
// Defined once so the two policies can never disagree about where to write.
export const LEGAL_CONTACT_EMAIL = 'support@cirrusquit.com';

// Shown on both legal pages. Bump it whenever either policy changes materially.
//
// 2026-09-03: named Amplitude in the processor list (it ships in the release
// app and the Play Data Safety form has to agree with this page), and added
// the "This website" section — the policy documented the app only, which is a
// gap you cannot have on a site that claims not to track anyone.
//
// 2026-09-06: the deletion section named a button the app does not have
// ("Settings → Delete account"; the live label is "Delete everything"), and it
// did not say that deletion leaves a store subscription running — the one thing
// about deletion that costs a person money if we stay quiet about it. Both
// fixed, and the section now links to /delete-account for the steps.
export const LEGAL_LAST_UPDATED = '2026-09-06';
