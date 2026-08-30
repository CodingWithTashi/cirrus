// Cloudflare Pages Function → served at POST /api/subscribe.
//
// Deliberately NOT an Astro route. The @astrojs/cloudflare adapter targets
// Workers: it restructures dist/ into client/ + server/ and injects an ASSETS
// binding whose name Pages reserves, which breaks `wrangler pages deploy`.
// A Pages Function sits beside the static build instead, so the whole site
// stays prerendered and only this one path runs server-side.
//
// Why a server hop at all: Listmonk's public subscription API needs no API key,
// but it sends no CORS headers, so the browser cannot post to it directly.
//
// Config comes from wrangler.jsonc `vars` (neither value is a secret):
//   LISTMONK_URL, LISTMONK_LIST_UUID

interface Env {
  LISTMONK_URL?: string;
  LISTMONK_LIST_UUID?: string;
}

const TIMEOUT_MS = 5000;
const JSON_HEADERS = {
  'content-type': 'application/json; charset=utf-8',
  'cache-control': 'no-store',
};

const json = (status: number, body: Record<string, unknown>, extra: Record<string, string> = {}) =>
  new Response(JSON.stringify(body), { status, headers: { ...JSON_HEADERS, ...extra } });

// Deliberately permissive: the only authority on whether an address exists is
// the confirmation email. A clever regex here just rejects real people.
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

const normalizeEmail = (v: unknown): string =>
  typeof v === 'string' ? v.trim().toLowerCase().slice(0, 254) : '';

// Per-IP rate limit. Module scope, so it lives as long as the isolate — good
// enough to blunt a burst, and deliberately not a durable store: a waitlist
// does not warrant the cost or complexity of one.
const HITS = new Map<string, number[]>();
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 8;

function rateLimit(ip: string): { ok: boolean; retryAfterSec: number } {
  const now = Date.now();
  const recent = (HITS.get(ip) ?? []).filter((t) => now - t < WINDOW_MS);
  if (recent.length >= MAX_PER_WINDOW) {
    return { ok: false, retryAfterSec: Math.ceil((WINDOW_MS - (now - recent[0])) / 1000) };
  }
  recent.push(now);
  HITS.set(ip, recent);
  if (HITS.size > 5000) HITS.clear(); // crude cap; the isolate is short-lived anyway
  return { ok: true, retryAfterSec: 0 };
}

async function readBody(request: Request): Promise<Record<string, unknown>> {
  const type = request.headers.get('content-type') ?? '';
  if (type.includes('application/json')) {
    return (await request.json().catch(() => ({}))) as Record<string, unknown>;
  }
  const form = await request.formData().catch(() => new FormData());
  const out: Record<string, unknown> = {};
  for (const [k, v] of form) if (typeof v === 'string') out[k] = v;
  return out;
}

/**
 * Listmonk's public endpoint. Prefers the JSON API (>= 2.2) and falls back to
 * the classic form endpoint on older builds. Double opt-in is decided by the
 * list settings in Listmonk, not here.
 */
async function subscribe(
  env: Env,
  email: string,
): Promise<{ ok: boolean; status?: string; error?: string; detail?: string }> {
  const base = env.LISTMONK_URL?.replace(/\/+$/, '');
  const list = env.LISTMONK_LIST_UUID;
  if (!base || !list) return { ok: false, error: 'not_configured' };

  // The form only asks for an email; Listmonk wants a display name too.
  const name = email.split('@')[0].replace(/[._-]+/g, ' ').trim() || email;

  try {
    const api = await fetch(`${base}/api/public/subscription`, {
      method: 'POST',
      headers: { 'content-type': 'application/json', accept: 'application/json' },
      body: JSON.stringify({ email, name, list_uuids: [list] }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (api.ok) return { ok: true, status: 'pending_confirmation' };
    if (api.status !== 404 && api.status !== 405) {
      const text = await api.text();
      // Already on the list is a success from the visitor's point of view.
      if (/already|exists/i.test(text)) return { ok: true, status: 'already_subscribed' };
      return { ok: false, error: 'provider_error', detail: `listmonk ${api.status}` };
    }

    // Older Listmonk: post exactly like the embeddable HTML form does.
    // `nonce` is Listmonk's own honeypot — it must be present and EMPTY.
    const res = await fetch(`${base}/subscription/form`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ email, name, l: list, nonce: '' }).toString(),
      redirect: 'manual',
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    if (res.ok || (res.status >= 300 && res.status < 400)) {
      return { ok: true, status: 'pending_confirmation' };
    }
    return { ok: false, error: 'provider_error', detail: `listmonk form ${res.status}` };
  } catch (err) {
    return { ok: false, error: 'provider_error', detail: String(err).slice(0, 120) };
  }
}

export const onRequestPost: PagesFunction<Env> = async ({ request, env }) => {
  // 1. Same-origin only. Browsers always send Origin on a cross-origin POST.
  const origin = request.headers.get('origin');
  if (origin && origin !== new URL(request.url).origin) {
    return json(403, { ok: false, error: 'bad_origin' });
  }

  const body = await readBody(request);

  // 2. Honeypot. Bots fill every field they find; a real person never sees this
  //    one. Answer 200 so the bot learns nothing, but never call Listmonk.
  if (typeof body.website === 'string' && body.website.trim() !== '') {
    return json(200, { ok: true, status: 'subscribed' });
  }

  // 3. Validate before spending a network call.
  const email = normalizeEmail(body.email);
  if (!EMAIL_RE.test(email)) return json(400, { ok: false, error: 'invalid_email' });

  // 4. Rate limit per IP.
  const ip =
    request.headers.get('cf-connecting-ip') ?? request.headers.get('x-forwarded-for') ?? 'local';
  const rl = rateLimit(ip);
  if (!rl.ok) {
    return json(429, { ok: false, error: 'rate_limited' }, { 'retry-after': String(rl.retryAfterSec) });
  }

  // 5. Hand off.
  const result = await subscribe(env, email);
  if (!result.ok) {
    console.error('subscribe failed', result.error, result.detail ?? '');
    return json(502, { ok: false, error: result.error ?? 'provider_error' });
  }
  return json(200, { ok: true, status: result.status });
};

// A GET here is someone poking the URL in a browser, not an error worth logging.
export const onRequestGet: PagesFunction<Env> = async () =>
  json(405, { ok: false, error: 'method_not_allowed' });
