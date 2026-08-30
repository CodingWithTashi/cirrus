import type { APIContext } from 'astro';

// robots.txt is generated here rather than dropped in public/ so the Sitemap
// line always carries the real origin from astro.config.mjs.
//
// This file used to be *overwritten at the edge*: Cloudflare's AI Crawl Control
// "Managed robots.txt" prepended its own block ahead of ours. That is now off
// (dashboard -> AI Crawl Control -> Signals), so what is below is exactly what
// crawlers see — reviewable in git, no surprise injection.
//
// Two layers, and they do different jobs:
//   - This file is the POLITE layer. Well-behaved crawlers honour it.
//   - Actual enforcement lives in AI Crawl Control -> Security, which blocks by
//     verified bot signature, not User-Agent. Editing this file does not
//     unblock anything there, and vice versa. Keep the two in agreement.

// Content-Signal declares intent for crawlers that read it:
//   search=yes     index us and link to us
//   ai-train=no    do not train or fine-tune models on this content
//   use=reference  you may cite us in an answer
const CONTENT_SIGNAL = 'search=yes,ai-train=no,use=reference';

// Bulk training crawlers. Mirrors what AI Crawl Control blocks at the edge, so
// the polite signal and the enforcement say the same thing.
//
// Deliberately NOT in this list: the "AI Search" and "AI Assistant" crawlers
// (OAI-SearchBot, Claude-SearchBot, PerplexityBot, ChatGPT-User, DuckAssistBot,
// Applebot...). Those fetch a page to answer someone's question right now and
// cite the source — that is distribution, not extraction, and it is how a
// pre-launch app gets found.
const TRAINING_CRAWLERS = [
  'Amazonbot',
  'Applebot-Extended',
  'Bytespider',
  'CCBot',
  'ClaudeBot',
  'CloudflareBrowserRenderingCrawler',
  'GPTBot',
  'meta-externalagent',
  // 'Google-Extended' — deliberately allowed. Unlike the others this single
  // token governs BOTH Gemini grounding and Google model training; there is no
  // way to permit one without the other. Allowing it is a considered trade:
  // Gemini can cite the blog, at the cost of an exception to ai-train=no.
  // Add the string back to this list to reverse it.
];

export function GET({ site }: APIContext) {
  const body = [
    'User-agent: *',
    `Content-Signal: ${CONTENT_SIGNAL}`,
    'Allow: /',
    '',
    ...TRAINING_CRAWLERS.flatMap((ua) => [`User-agent: ${ua}`, 'Disallow: /', '']),
    `Sitemap: ${new URL('sitemap-index.xml', site)}`,
    '',
  ].join('\n');

  return new Response(body, {
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}
