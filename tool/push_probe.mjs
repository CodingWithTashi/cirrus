/**
 * Sends a real push to a real device, without deploying anything.
 *
 * The gap this closes: FCM has no emulator. `npm run test:integration` proves
 * the trigger decides to send and with what arguments, and stops exactly
 * there — it cannot show what Android actually draws, whether the tag really
 * replaces the shade line instead of stacking, which channel a quiet-hours
 * message lands in, or where a tap goes from the terminated state. Those are
 * the parts of this feature that only a phone can answer.
 *
 * So this builds the same message `lib/push.ts` builds and hands it to
 * production FCM with the admin key. Nothing is deployed and no production
 * code path runs: the only thing shared with users is Google's delivery.
 *
 * Usage, from the repo root:
 *
 *   node tool/push_probe.mjs --token <fcm-token> reply
 *   node tool/push_probe.mjs --token <fcm-token> burst
 *   node tool/push_probe.mjs --token <fcm-token> mention
 *   node tool/push_probe.mjs --token <fcm-token> quiet
 *
 * The token is printed by the app at launch (`push: token …`), or read from
 * Firestore under `users/{uid}/devices`.
 */
import {createHash} from 'node:crypto';
import {readFileSync, readdirSync} from 'node:fs';
import {join} from 'node:path';
import {createRequire} from 'node:module';

// Resolved through `functions/`, which is where firebase-admin is installed.
// The repo root has no `node_modules` and does not want one for a dev script;
// ESM resolution walks up from the SCRIPT's directory, not the cwd, so a
// bare import here would fail however it was invoked.
const require = createRequire(new URL('../functions/package.json', import.meta.url));
const {initializeApp, cert} = require('firebase-admin/app');
const {getMessaging} = require('firebase-admin/messaging');

const KEY_DIR = 'functions';
const POST_ID = 'probe-post-1';

function serviceAccount() {
  const name = readdirSync(KEY_DIR).find(
    (f) => f.startsWith('alastpuff-') && f.includes('adminsdk') && f.endsWith('.json'),
  );
  if (!name) {
    throw new Error(
      'No admin key in functions/. It is gitignored; it has to be there to send.',
    );
  }
  return JSON.parse(readFileSync(join(KEY_DIR, name), 'utf8'));
}

/**
 * The same shape as `buildMessage` in `functions/src/lib/push.ts`.
 *
 * Kept deliberately hand-written rather than imported: the point of this
 * script is to check what a phone does with a payload, so a copy that can
 * drift is more useful than one that cannot — if the two disagree, the
 * on-device result is the one that tells you.
 */
function message(token, {title, body, kind, tag, route, quiet = false}) {
  const channel = kind === 'insightReady' ? 'insights' : 'community_replies';
  return {
    token,
    notification: {title, body},
    data: {kind, ...(route ? {route} : {})},
    android: {
      ...(tag ? {collapseKey: tag} : {}),
      notification: {
        channelId: quiet ? `${channel}_quiet` : channel,
        priority: quiet ? 'low' : 'default',
        ...(tag ? {tag} : {}),
      },
    },
    apns: {
      ...(tag ? {headers: {'apns-collapse-id': tag.slice(0, 64)}} : {}),
      payload: {
        aps: {
          ...(tag ? {threadId: tag} : {}),
          ...(quiet ? {'interruption-level': 'passive'} : {}),
        },
      },
    },
  };
}

const THREAD_TAG = `thread:${POST_ID}`;
const ROUTE = `/community/post/${POST_ID}`;

const SCENARIOS = {
  /** One reply on your post: the plain case. */
  reply: [
    {
      title: 'Someone replied',
      body: 'Go see what they said.',
      kind: 'communityReply',
      tag: THREAD_TAG,
      route: ROUTE,
    },
  ],

  /**
   * A busy thread. Five sends carrying the same tag must leave ONE line in
   * the shade whose text advances — that is the half of collapse the server
   * cannot do by itself.
   */
  burst: [2, 5, 9, 14, 20].map((count) => ({
    title: 'Your post is getting replies',
    body: `${count} new replies.`,
    kind: 'communityReply',
    tag: THREAD_TAG,
    route: ROUTE,
  })),

  /** A mention: its own line, never folded into the thread's count. */
  mention: [
    {
      title: 'Someone tagged you',
      body: 'You were mentioned in a reply.',
      kind: 'communityMention',
      tag: 'mention:probe-reply-1',
      route: ROUTE,
    },
  ],

  /** Quiet hours: the low-importance twin channel, no sound. */
  quiet: [
    {
      title: 'Someone replied',
      body: 'Go see what they said.',
      kind: 'communityReply',
      tag: THREAD_TAG,
      route: ROUTE,
      quiet: true,
    },
  ],

  /** A route the app's allow-list refuses: it must open and go nowhere. */
  badroute: [
    {
      title: 'Probe',
      body: 'This route is not allow-listed.',
      kind: 'system',
      route: '/settings/secret',
    },
  ],
};

/**
 * Files an inbox row the way the deployed `recordNotification` does.
 *
 * Same collection, same fields, same tag-as-document-id. It exists so the
 * CLIENT half of the inbox — the Firestore listener, the store, the badge and
 * the screen — can be exercised on a device without deploying the server
 * change first.
 */
async function seedInbox(uid, spec) {
  const {getFirestore} = require('firebase-admin/firestore');
  const db = getFirestore();
  const id = spec.tag
    ? spec.tag.replace(/\//g, '_')
    : db.collection('scratch').doc().id;
  await db
    .collection('users')
    .doc(uid)
    .collection('notifications')
    .doc(id)
    .set(
      {
        kind: spec.kind,
        title: spec.title,
        body: spec.body,
        ...(spec.route ? {route: spec.route} : {}),
        createdAtMs: Date.now(),
        readAtMs: null,
      },
      {merge: true},
    );
  console.log(`inbox row users/${uid}/notifications/${id}`);
}

/** The uid behind an account email, so the probe needs no extra index. */
async function uidFor(email) {
  const {getAuth} = require('firebase-admin/auth');
  return (await getAuth().getUserByEmail(email)).uid;
}

async function main() {
  const args = process.argv.slice(2);
  const tokenIndex = args.indexOf('--token');
  const token = tokenIndex >= 0 ? args[tokenIndex + 1] : process.env.FCM_TOKEN;
  const scenario = args.find((a) => SCENARIOS[a]) ?? 'reply';

  if (!token) {
    console.error('Pass --token <fcm-token>, or set FCM_TOKEN.');
    process.exit(1);
  }

  initializeApp({credential: cert(serviceAccount())});
  const messaging = getMessaging();

  const emailIndex = args.indexOf('--email');
  const email = emailIndex >= 0 ? args[emailIndex + 1] : process.env.LP_EMAIL;
  const uid = email ? await uidFor(email) : null;

  if (args.includes('--inbox-only')) {
    for (const spec of SCENARIOS[scenario]) await seedInbox(uid, spec);
    return;
  }

  for (const [i, spec] of SCENARIOS[scenario].entries()) {
    if (uid) await seedInbox(uid, spec);
    const id = await messaging.send(message(token, spec));
    console.log(`sent ${scenario}[${i}] ${spec.body} -> ${id}`);
    // A beat between sends, so the shade has time to redraw and a human
    // watching can see a replacement happen rather than a final state.
    if (i < SCENARIOS[scenario].length - 1) {
      await new Promise((r) => setTimeout(r, 2500));
    }
  }
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
