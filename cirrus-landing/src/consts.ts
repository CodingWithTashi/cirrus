// Site-wide constants. The ONE place the brand strings live — every page, the
// RSS feed and the JSON-LD read from here.
//
// Copy follows docs/07 §2 voice rules: sentence case, contractions, zero
// clinical language, zero shame words — and the honest-stats rule, so nothing
// here claims a number the product can't back up.

export const SITE_TITLE = 'Cirrus';
export const SITE_TAGLINE = 'Your last puff is closer than you think';
export const SITE_DESCRIPTION =
  'Cirrus builds a taper plan from your real numbers, not a generic countdown. Honest math, a coach in your pocket, and people who get it.';

// Open Graph / Twitter card image, 1200x630.
export const SITE_OG_IMAGE = '/og.png';

export const SITE_LOCALE = 'en_US';

// Pre-launch: the store listing doesn't exist yet, so the hero CTA can't point
// at it. Set this to the App Store URL at launch and the button switches from
// the waitlist to the real thing.
export const APP_STORE_URL = '';
