/**
 * Proves, against DEPLOYED functions, who a reply actually notifies.
 *
 * The gap this closes: `npm run test:integration` runs the trigger in-process
 * against the emulator with `sendLocalized` mocked, so it shows what the code
 * decides. It cannot show what the deployed build decides — and the emulator
 * does not enforce the indexes production does, which is exactly how the
 * community feed once returned PERMISSION_DENIED in production while the
 * rules suite stayed green.
 *
 * So this writes a real thread into production Firestore, lets the real
 * `moderateReply` trigger fire, and reads the in-app inbox rows the real
 * `notifyReply` wrote. `users/{uid}/notifications` is the right thing to read:
 * `sendToUser` files it BEFORE the token check, so the row lands whether or
 * not anybody has a device registered. Nothing here needs a phone.
 *
 * **The probe post is never `live`.** The feed rule is
 * `resource.data.status == 'live'`, so no real user can read it, while the
 * trigger — which keys off the reply document, not the post's status — runs
 * exactly as it does for anybody. Everything is deleted again in a `finally`.
 *
 * Usage, from the repo root:
 *
 *   node tool/mention_probe.mjs            # the whole table
 *   node tool/mention_probe.mjs tagged     # one scenario
 *
 * Each scenario costs one moderation model call, because that is the path.
 */
import {readFileSync, readdirSync} from 'node:fs';
import {join} from 'node:path';
import {createRequire} from 'node:module';

// Resolved through `functions/`, which is where firebase-admin is installed.
// The repo root has no `node_modules` and does not want one for a dev script.
const require = createRequire(new URL('../functions/package.json', import.meta.url));
const {initializeApp, cert} = require('firebase-admin/app');
const {getFirestore, FieldValue, Timestamp} = require('firebase-admin/firestore');

const KEY_DIR = 'functions';

function serviceAccount() {
  const name = readdirSync(KEY_DIR).find(
    (f) => f.startsWith('alastpuff-') && f.includes('adminsdk') && f.endsWith('.json'),
  );
  if (!name) {
    throw new Error(
      'No admin key in functions/. It is gitignored; it has to be there.',
    );
  }
  return JSON.parse(readFileSync(join(KEY_DIR, name), 'utf8'));
}

initializeApp({credential: cert(serviceAccount())});
const db = getFirestore();

const RUN = Date.now().toString(36);
const POST = `probe-mentions-${RUN}`;
const A = `probe-author-${RUN}`; // the post's author
const B = `probe-moth-${RUN}`; // a helper already in the thread
const C = `probe-otter-${RUN}`; // the one who writes the reply under test

// `replyAuthors` is a TOP-LEVEL collection keyed by the reply id alone, so
// these have to carry the run: a bare `rB` is global, and cleanup deletes by
// id. Real reply ids are 20-character Firestore auto-ids, so nothing of a
// user's can collide with these — but two overlapping probe runs would.
const RB = `rB-${RUN}`;
const RC = `rC-${RUN}`;

const ALIAS_A = '@quietfox42';
const ALIAS_B = '@brightmoth17';
const ALIAS_C = '@calmotter9';

/**
 * The worked example, exactly as `docs/13` row 111a states it.
 *
 * `want` is uid → the push kind that uid must receive, and nothing else may
 * receive anything. An empty entry means "hears nothing at all".
 */
const SCENARIOS = {
  nobody: {
    tag: 'win',
    text: 'this thread got me through last night',
    want: {[A]: 'communityReply'},
  },
  tagged: {
    tag: 'win',
    text: `${ALIAS_B} how did week 2 go`,
    want: {[B]: 'communityMention'},
  },
  author: {
    tag: 'win',
    text: `${ALIAS_A} congrats, that is a real milestone`,
    want: {[A]: 'communityMention'},
  },
  both: {
    tag: 'win',
    text: `${ALIAS_A} ${ALIAS_B} both of you got me through it`,
    want: {[A]: 'communityMention', [B]: 'communityMention'},
  },
  sos: {
    tag: 'sos',
    text: `${ALIAS_B} agreed, walk it off`,
    want: {[B]: 'communityMention', [A]: 'sosReply'},
  },
};

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/** Waits for `field` to appear on `ref`, which is how the trigger reports. */
async function waitFor(ref, field, label, timeoutMs = 90_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const snap = await ref.get();
    if (snap.exists && snap.get(field) !== undefined) return snap;
    await sleep(1500);
  }
  throw new Error(`timed out waiting for ${field} on ${label}`);
}

/** Every inbox row belonging to this run, as uid → [kind]. */
async function inboxes() {
  const out = {};
  for (const uid of [A, B, C]) {
    const rows = await db.collection(`users/${uid}/notifications`).get();
    if (!rows.empty) out[uid] = rows.docs.map((d) => `${d.get('kind')} (${d.id})`);
  }
  return out;
}

async function clearInboxes() {
  for (const uid of [A, B, C]) {
    const rows = await db.collection(`users/${uid}/notifications`).get();
    await Promise.all(rows.docs.map((d) => d.ref.delete()));
    await db.doc(`users/${uid}/notifThreads/${POST}`).delete().catch(() => {});
  }
}

/**
 * Seeds the thread: a post nobody can read, its author, and one live reply by
 * B so that there is somebody other than the author to tag.
 *
 * B's reply is written with `notifiedAt` already set. Creating it fires the
 * trigger like any other reply, and without that marker it would announce
 * itself to A and pollute the very inbox this is reading.
 */
async function seed(tag) {
  await db.doc(`posts/${POST}`).set({
    alias: ALIAS_A,
    text: 'probe thread — not live, not readable by anyone',
    status: 'probe', // deliberately not 'live': the feed rule refuses it
    tag,
    createdAt: FieldValue.serverTimestamp(),
  });
  await db.doc(`postAuthors/${POST}`).set({uid: A});

  const rb = db.doc(`posts/${POST}/replies/${RB}`);
  await db.doc(`replyAuthors/${RB}`).set({uid: B, postId: POST});
  await rb.set({
    alias: ALIAS_B,
    text: 'I am here, you are not doing this alone',
    status: 'live',
    createdAt: Timestamp.fromMillis(Date.now() - 60_000),
    notifiedAt: FieldValue.serverTimestamp(),
  });

  const seeded = await waitFor(rb, 'moderatedAt', 'B’s seeded reply');
  if (seeded.get('status') !== 'live') {
    throw new Error(
      `seeded reply landed as ${seeded.get('status')}, so a tag on ${ALIAS_B} ` +
        'could not resolve. Re-run.',
    );
  }
  // Only B's reply has run; anything it filed is not what we are measuring.
  await clearInboxes();
}

async function run(name) {
  const scenario = SCENARIOS[name];
  const rc = db.doc(`posts/${POST}/replies/${RC}`);
  await db.doc(`replyAuthors/${RC}`).set({uid: C, postId: POST});
  await rc.set({
    alias: ALIAS_C,
    text: scenario.text,
    status: 'pending',
    createdAt: Timestamp.fromMillis(Date.now()),
  });

  const done = await waitFor(rc, 'notifiedAt', 'the reply under test');
  if (done.get('status') !== 'live') {
    throw new Error(`reply landed as ${done.get('status')}, not live`);
  }

  const got = await inboxes();
  const kindsOf = (uid) =>
    (got[uid] ?? []).map((row) => row.split(' ')[0]).sort();

  const label = (uid) => (uid === A ? 'A/author' : uid === B ? 'B' : 'C');
  const problems = [];
  for (const uid of [A, B, C]) {
    const want = scenario.want[uid] ? [scenario.want[uid]] : [];
    const have = kindsOf(uid);
    if (JSON.stringify(want) !== JSON.stringify(have)) {
      problems.push(
        `  ${label(uid)}: wanted [${want}] but got [${have}]`,
      );
    }
  }

  const verdict = problems.length === 0 ? 'PASS' : 'FAIL';
  console.log(`${verdict}  ${name.padEnd(7)} "${scenario.text}"`);
  for (const uid of [A, B, C]) {
    for (const row of got[uid] ?? []) console.log(`         ${label(uid)} <- ${row}`);
  }
  if (problems.length) console.log(problems.join('\n'));

  await rc.delete();
  await db.doc(`replyAuthors/${RC}`).delete();
  await clearInboxes();
  return problems.length === 0;
}

async function cleanup() {
  const replies = await db.collection(`posts/${POST}/replies`).get();
  await Promise.all(replies.docs.map((d) => d.ref.delete()));
  await db.doc(`posts/${POST}`).delete();
  await db.doc(`postAuthors/${POST}`).delete();
  for (const id of [RB, RC]) {
    await db.doc(`replyAuthors/${id}`).delete().catch(() => {});
  }
  for (const uid of [A, B, C]) {
    await db.recursiveDelete(db.doc(`users/${uid}`));
  }
  // A held or flagged probe reply files a founder-review row; it is ours.
  for (const id of [RB, RC]) {
    await db.doc(`moderation/${id}`).delete().catch(() => {});
  }
}

const only = process.argv[2];
const names = only ? [only] : Object.keys(SCENARIOS);
let ok = true;
try {
  for (const name of names) {
    // Each scenario needs its own thread: the tag differs, and B's seeded
    // reply has to be the only other voice in it.
    await seed(SCENARIOS[name].tag);
    ok = (await run(name)) && ok;
    const replies = await db.collection(`posts/${POST}/replies`).get();
    await Promise.all(replies.docs.map((d) => d.ref.delete()));
  }
} finally {
  await cleanup();
  console.log('cleaned up');
}
console.log(ok ? '\nALL SCENARIOS PASS' : '\nSOME SCENARIOS FAILED');
process.exit(ok ? 0 : 1);
