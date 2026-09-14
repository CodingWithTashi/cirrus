/**
 * Takes back the reactions authors left on their own posts (docs/10 §41).
 *
 * Since Sep 13 2026 the app offers an author no reaction pill on their own post,
 * and `firestore.rules` refuses the `reactors/{uid}` write when that uid wrote
 * the post. Reactions written before either still count on the post.
 *
 * Each is removed by deleting its ordinary `posts/{postId}/reactors/{uid}`
 * document — the same path a reader's own "take it back" uses — so the deployed
 * `onReaction` trigger takes the count back off the post. The aggregate stays
 * derived by the trigger; this script never writes a count.
 *
 * Usage, from the repo root:
 *
 *   node tool/reaction_self_backfill.mjs            # dry run: lists them
 *   node tool/reaction_self_backfill.mjs --apply    # deletes them
 *
 * Run it again after the rules deploy: a client still on an older build could
 * have left one in between, and a clean dry run is the proof there are none.
 */
import {readFileSync, readdirSync} from 'node:fs';
import {join} from 'node:path';
import {createRequire} from 'node:module';

// Resolved through `functions/`, where firebase-admin is installed; the repo
// root has no node_modules (same arrangement as tool/push_probe.mjs).
const require = createRequire(new URL('../functions/package.json', import.meta.url));
const {initializeApp, cert} = require('firebase-admin/app');
const {getFirestore, FieldPath} = require('firebase-admin/firestore');

const KEY_DIR = 'functions';

function serviceAccount() {
  const name = readdirSync(KEY_DIR).find(
    (f) => f.startsWith('alastpuff-') && f.includes('adminsdk') && f.endsWith('.json'),
  );
  if (!name) {
    throw new Error('No admin key in functions/. It is gitignored; it has to be there to run.');
  }
  return JSON.parse(readFileSync(join(KEY_DIR, name), 'utf8'));
}

const apply = process.argv.includes('--apply');
initializeApp({credential: cert(serviceAccount())});
const db = getFirestore();

const found = [];
let scanned = 0;
let cursor = null;
for (;;) {
  let page = db.collection('postAuthors').orderBy(FieldPath.documentId()).limit(300);
  if (cursor) page = page.startAfter(cursor);
  const snap = await page.get();
  if (snap.empty) break;
  for (const author of snap.docs) {
    scanned++;
    const uid = author.data().uid;
    if (typeof uid !== 'string' || uid.length === 0) continue;
    const reactor = await db.collection('posts').doc(author.id).collection('reactors').doc(uid).get();
    if (reactor.exists) found.push({postId: author.id, emoji: reactor.data()?.emoji, ref: reactor.ref});
  }
  cursor = snap.docs[snap.docs.length - 1];
}

console.log(`posts scanned: ${scanned}; self-reactions found: ${found.length}`);
for (const f of found) console.log(`  posts/${f.postId} ${f.emoji}`);

if (!apply) {
  if (found.length) console.log('dry run — pass --apply to take them back');
  process.exit(0);
}

for (const f of found) await f.ref.delete();
console.log(`deleted ${found.length}; waiting for onReaction to take the counts back…`);
// The trigger runs asynchronously; show each post's counts once it has.
await new Promise((resolve) => setTimeout(resolve, 8000));
for (const f of found) {
  const post = await db.collection('posts').doc(f.postId).get();
  console.log(`  posts/${f.postId} reactions now ${JSON.stringify(post.data()?.reactions ?? {})}`);
}
process.exit(0);
