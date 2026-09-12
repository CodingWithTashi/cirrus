// Site-wide constants — the ONE place brand strings, dates and numbers live.
//
// Copy follows docs/07 §2 voice rules: sentence case, contractions, zero
// clinical language, zero shame words. And docs/02 §8's honest-stats rule:
// no number appears on this site unless it is the visitor's own arithmetic
// or carries a citation. See HONEST_STATS below.

export const SITE_TITLE = 'Cirrus';
export const SITE_TAGLINE = 'Quit vaping without going cold turkey';
export const SITE_DESCRIPTION =
  'The quit vaping app that counts your real puffs and tapers them down to zero. No cold turkey, no day-one resets, and not a single invented statistic.';

export const SITE_OG_IMAGE = '/og.png';
export const SITE_LOCALE = 'en_US';

// docs/08 §1 LOCKED TARGETS: "Android at launch; iOS fast-follow" — there is no
// Mac, so iOS cannot be built or submitted yet. iPhone users are precisely the
// audience the waitlist exists to hold, so the FAQ says Android-first plainly.
//
// No launch DATE appears anywhere on this site, deliberately: the founder's call.
// The page says "Coming soon" and nothing more. Do not reintroduce one.
export const LAUNCH_PLATFORM = 'Android';

// Real signups already collected, per the founder. docs/07 §8 forbids faking
// social proof, so this must stay truthful — bump it, don't inflate it.
export const WAITLIST_COUNT = 103;

// The live Play listing: "Cirrus - Vaping Quit Tracker", Kharag Edition.
//
// Read only through `src/lib/store.ts` — never inline this URL anywhere else,
// and never put it in Markdown. Posts link to /download, which is the one page
// that stays correct whether or not the store is open.
//
// The home hero deliberately still shows the waitlist rather than a store
// button: roughly half of blog traffic is on iPhone, iOS is months away, and
// dropping that capture on the day Android ships is the most expensive
// available mistake. /download offers both.
//
// Annotated `string` rather than left as a literal type: `STORE_LIVE` compares
// it against '', and TypeScript would otherwise narrow this to its own value
// and call that comparison dead code. The guard has to keep compiling in both
// states, because emptying this is the documented way to take the store link
// back down.
export const PLAY_STORE_URL: string =
  'https://play.google.com/store/apps/details?id=com.quitvape.last_puff';

// The live iOS listing. App Store Connect assigns the app id when the RECORD is
// created, not when the app is approved — so this URL is already correct and
// already permanent. It simply 404s until the first version is released
// (verified 404 on 2026-09-12, with 1.0.17 build 18 in Waiting for Review).
//
// Written out in full rather than left empty the way PLAY_STORE_URL once was,
// because the two unknowns are different: back then we did not know the URL,
// and here we do not know the DATE. Approval can land overnight, so the person
// flipping the switch should not also have to go and find this string.
export const APP_STORE_URL: string = 'https://apps.apple.com/app/id6806871144';

// THE ONE WORD THAT SHIPS iOS. Flip to `true` when App Review approves and the
// version is actually released — "Ready for Sale", not "Pending Developer
// Release", because the URL above stays a 404 until the release is out.
//
// Everything iOS keys off this: /get stops sending iPhones to the waitlist and
// starts sending them to the App Store, /download grows a second button, and
// the blog CTA stops saying iPhone isn't built yet. Nothing else has to change.
//
// It is a boolean rather than the empty-string trick PLAY_STORE_URL uses
// because a URL that exists but is not open yet cannot be represented by
// absence — and a store button that 404s is worse than an honest "not yet":
// it reads as a broken app rather than a pending one.
//
// Annotated `boolean` for exactly the reason PLAY_STORE_URL is annotated
// `string`, and the consequence here is worse. Left bare, TypeScript narrows
// this to the literal type `false`, every `IOS_LIVE ?` in store.ts becomes a
// constant, and the App Store branches compile as dead code — so flipping the
// word would change nothing until somebody noticed why. The declaration has to
// keep meaning "a boolean that is currently false", not "the value false".
export const IOS_STORE_LIVE: boolean = false;

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
export const LEGAL_LAST_UPDATED = '2026-09-07';
