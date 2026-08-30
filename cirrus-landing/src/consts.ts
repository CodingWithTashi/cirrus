// Site-wide constants — the ONE place brand strings, dates and numbers live.
//
// Copy follows docs/07 §2 voice rules: sentence case, contractions, zero
// clinical language, zero shame words. And docs/02 §8's honest-stats rule:
// no number appears on this site unless it is the visitor's own arithmetic
// or carries a citation. See HONEST_STATS below.

export const SITE_TITLE = 'Cirrus';
export const SITE_TAGLINE = 'Quit vaping without going cold turkey';
export const SITE_DESCRIPTION =
  'Cirrus counts your real puffs and walks the number down slowly enough that your brain keeps up. A taper that bends when you slip — and no invented stats.';

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

// Store link is empty until the Play listing exists; the hero CTA stays the
// waitlist until then and switches itself when this is filled in.
export const PLAY_STORE_URL = '';

// Legal pages currently live on Firebase Hosting, not this domain.
export const PRIVACY_URL = 'https://alastpuff.web.app/privacy';
export const TERMS_URL = 'https://alastpuff.web.app/terms';
