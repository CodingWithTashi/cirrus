// Astro middleware — the DEV stand-in for /get.
//
// `functions/get.ts` serves /get in production, but `functions/` is Cloudflare
// Pages infrastructure and `astro dev` knows nothing about it, so /get used to
// 404 on localhost:4321 while working perfectly once deployed.
//
// THIS CANNOT DO THE REAL THING, and that is the important part. The site is
// `output: 'static'`, so every route is prerendered and Astro deliberately
// hands middleware an EMPTY Headers object — "`Astro.request.headers` is not
// available on prerendered pages", which it warns about. There is no
// User-Agent to read, so there is no platform to detect: this would answer
// /download for an Android phone, an iPhone and a crawler alike.
//
// Silently doing that would be worse than the 404 it replaces. A dev server
// that always answers /download teaches you that /get always answers
// /download, and you would only find out otherwise in production — the exact
// "looks like a decision, is a bug" shape this repo keeps getting bitten by.
// So it redirects (the honest fallback, and the same answer production gives
// anyone it cannot place) and says once, in the terminal, why it did not
// choose a store.
//
// To exercise the real decision, run the real runtime: `npm run preview:edge`.
import { defineMiddleware } from 'astro:middleware';
import { DOWNLOAD_URL } from './lib/store';
import { redirectTo } from './lib/platform';

let warned = false;

export const onRequest = defineMiddleware((context, next) => {
  // Trailing slash tolerated to match the Function, which answers both.
  const path = context.url.pathname.replace(/\/+$/, '') || '/';
  if (path !== '/get') return next();

  if (!warned) {
    warned = true;
    console.warn(
      '\n  /get: dev cannot read the User-Agent (static output has no request headers),\n' +
        `  so it falls back to ${DOWNLOAD_URL}. Run \`npm run preview:edge\` to test the\n` +
        '  real platform redirect against the Cloudflare runtime.\n',
    );
  }

  return redirectTo(DOWNLOAD_URL);
});
