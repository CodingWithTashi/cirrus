import type { APIContext } from 'astro';

// Generated rather than a static public/robots.txt so the Sitemap line always
// carries the real origin from astro.config.mjs — a hardcoded one silently goes
// stale the moment the domain changes.
export function GET({ site }: APIContext) {
  const body = `User-agent: *
Allow: /

Sitemap: ${new URL('sitemap-index.xml', site)}
`;

  return new Response(body, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
