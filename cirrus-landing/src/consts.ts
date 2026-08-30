// Site-wide constants. The ONE place the brand strings live — every page,
// the RSS feed and the JSON-LD read from here, so changing a name or tagline
// is a one-line edit.

export const SITE_TITLE = 'Cirrus';
export const SITE_TAGLINE = 'Quit vaping, one day at a time';
export const SITE_DESCRIPTION =
  'Cirrus helps you quit vaping with a taper plan built around your habits — real numbers, no guesswork.';

// Open Graph / Twitter card image. Deliberately empty: a tag pointing at a
// missing file is worse than no tag, because scrapers cache the 404. Drop a
// 1200x630 PNG at public/og.png and set this to '/og.png' to switch cards on.
export const SITE_OG_IMAGE = '';

export const SITE_LOCALE = 'en_US';
