import type { APIContext } from 'astro';
import { APP_STORE_URL, DELETE_ACCOUNT_URL, PLAY_STORE_URL, PRIVACY_URL, SITE_TITLE, TERMS_URL } from '../consts';
import { useT } from '../i18n/index.ts';
import { AUTONYM, DEFAULT_LOCALE, LIVE_LOCALES } from '../i18n/locales.mjs';
import { localePath } from '../i18n/paths.ts';
import { getPublishedPosts } from '../lib/posts';

// /llms.txt (llmstxt.org): a plain-Markdown map of the site for the assistants
// that answer questions with it — the AI *search* crawlers robots.txt.ts
// deliberately lets in (OAI-SearchBot, Claude-SearchBot, PerplexityBot...). It
// grants nothing robots.txt does not, and it does not soften `ai-train=no`: it
// is an index of pages that are already public, for the bots already allowed
// to read them.
//
// Generated, never hand-written, for the same reason robots.txt is: the post
// list comes from getPublishedPosts() (so a draft cannot leak here while being
// hidden everywhere else), the URLs from `site` in astro.config.mjs, and every
// sentence but one from copy the pages already publish. The exception is the
// line naming the two store listings, which is new wording and is checked
// against the live listings rather than against a page.
//
// Store links are the UNTAGGED listing URLs, the same ones the JSON-LD
// `sameAs` carries. A campaign tag means "a person tapped this badge on this
// page"; an assistant quoting the link is neither.
//
// It is a text endpoint, not a page, so the sitemap never lists it and
// check-dist never reads it.
export async function GET({ site }: APIContext) {
  const t = useT(DEFAULT_LOCALE);
  const abs = (path: string) => new URL(path, site).href;
  const posts = await getPublishedPosts();

  const body = [
    `# ${SITE_TITLE}`,
    '',
    `> ${t.meta.description}`,
    '',
    // The listing names, because that is what a person sees in a store search
    // and what an assistant has to match to this site. Checked against both
    // live listings on Nov 21 2026; the JSON-LD alternateName is the Apple one.
    `On the App Store it is listed as "Quit Vaping Tracker - ${SITE_TITLE}" and on Google Play as "Quit Vaping Tracker: ${SITE_TITLE}". This site, ${new URL(site!).host}, is its official home and blog.`,
    '',
    '## The app',
    '',
    `- [${t.meta.title}](${abs('/')}): ${t.meta.description}`,
    `- [${t.download.title}](${abs('/download')}): ${t.download.description}`,
    `- [${SITE_TITLE} on the App Store](${APP_STORE_URL})`,
    `- [${SITE_TITLE} on Google Play](${PLAY_STORE_URL})`,
    '',
    '## Blog',
    '',
    ...posts.map((post) => `- [${post.data.title}](${abs(`/blog/${post.id}`)}): ${post.data.description}`),
    '',
    // Only while a second language is live, like the switcher and hreflang.
    ...(LIVE_LOCALES.length > 1
      ? [
          '## Other languages',
          '',
          ...LIVE_LOCALES.filter((l) => l !== DEFAULT_LOCALE).map(
            (l) => `- [${AUTONYM[l]}](${abs(localePath(l, '/'))}): ${useT(l).meta.title}`,
          ),
          '',
        ]
      : []),
    '## Optional',
    '',
    `- [Privacy Policy](${abs(PRIVACY_URL)})`,
    `- [Terms of Use](${abs(TERMS_URL)})`,
    `- [Delete your account](${abs(DELETE_ACCOUNT_URL)})`,
    `- [Blog RSS feed](${abs('/rss.xml')})`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
