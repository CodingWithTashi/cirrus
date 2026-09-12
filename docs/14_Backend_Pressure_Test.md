# 14 — Backend Pressure Test (Sep 12 2026)

Adversarial pass over the Cloud Functions, one function at a time. Each entry:
what broke, and what was done. Live log — updated as the pass continues.

**Suite counts:** `npm run verify` 313 · `test:rules` 50 · `test:integration`
17 files / **373** (was 15 / 321) · `flutter test` **1785** (was 1781).

---

## Function 0 — the deploy gate itself

**B-01 — A dead test blocked every deploy.**
`revenuecat.test.ts` pinned fixtures to absolute dates (`IN_A_WEEK` = Sep 9
2026) but exercised `fetchSubscriber`, which reads the real clock — so it passed
for seven days and went red on Sep 9, blocking `firebase deploy`. Fixed by
pinning the clock (`vi.useFakeTimers({toFake: ['Date']})`); production code was
correct throughout.

---

## Function 1 — `setCoachName`

Had **zero tests**. Now 17.

**B-02 — The prompt-injection gate was open.**
The handler is documented as the first line of defence for the one name that
reaches the model, but enforced only length + denylist — so `Ember\nSYSTEM:ok`,
`Ember": "evil`, a null byte, an RTL override and a zero-width joiner were all
stored verbatim and interpolated twice into the system prompt. Fixed by
enforcing the client's character rules server-side (`hasAllowedShape`).

**B-03 — Nobody outside a Latin script could name their coach.**
`skeleton()` folds to `[a-z0-9]`, and an empty fold meant "refuse" — so 雲,
Ольга, Σοφία, أمل, ゆき, 미나 and every other non-Latin name was rejected with
the deliberately vague "Pick a different name." Fixed: an empty fold now
refuses only when the name has no letter or digit at all.

**B-04 — One keystroke defeated the impersonation guard.**
NFKD folds compatibility forms but not confusables, and the fold *deletes* what
it cannot map — so `аdmin` (Cyrillic а) became `dmin` and passed, as did
`сirrus` and `Cirruѕ`. Fixed with a Cyrillic/Greek confusables map applied
alongside the leet map.

**B-05 — The server refused names the app had accepted.**
`requireText` counts UTF-16 code units while the client counts code points, so
an 11-letter name in Adlam, CJK Ext-B or pasted styled text was 22 "characters"
to the server and refused. Fixed: length is counted in code points, matching
the client and the user.

**B-06 — The model was told a different name than the screen showed.**
The client normalizes (collapse whitespace, capitalize first letter); the
server only trimmed, so `wren` stayed lowercase and `A    B` kept four spaces.
Fixed by mirroring `CoachName.normalize` server-side.

---

## Function 2 — `coachMemories` / `forgetCoachMemory`

`forgetCoachMemory` had **zero tests**. Now 11 across both.

**B-07 — Up to 100 memories a user could never see or delete.**
The store's ceiling is 200 but the list returned 100, on the one screen that
exists to audit what the AI has stored. Worse, eviction drops by `lastUsedAt`
while the list sorts by `createdAt`, so an old memory in constant use was never
evicted *and* never shown. Fixed: the list now returns the full store cap.

**B-08 — A malformed memory id returned a 500 instead of a refusal.**
Firestore reserves `.`, `..` and `__like_this__`, and its SDK *throws* for them,
so the callable leaked an unhandled error and the client saw `internal` for what
was a bad argument. Fixed: all reserved shapes now refuse as `invalid-argument`,
the same as the slash already did.

---

## Function 3 — `createPost`

Already had 30 tests (anonymity, caps, concurrency, tiers, SOS, idempotency) and
they hold up — the transactional claim and the `lastKey` retry are correct under
concurrent sends. The gap was the two fields nobody treated as input. Now 37.

**B-09 — Anything at all could be somebody's avatar, on every post they wrote.**
`sanitizeEmoji` kept the first two code points of any string, so `ab`, `<s`, `99`
and two right-to-left overrides all became avatars rendered to every reader —
while the alias beside it has had an ASCII allowlist all along. Fixed: only
`Extended_Pictographic` survives, otherwise the default.

**B-10 — A post could claim any day number.**
`dayN` was `typeof x === 'number' ? x : 0`, so `-5`, `3.7` and `1e15` were stored
and rendered as "Day N" beside everyone else's honest count; `NaN`/`Infinity`
are numbers too and Firestore stores both as null. Fixed: clamped to a whole
0–9999, non-numbers to 0.

---

## Function 4 — `createReply` (and the two client-side bugs)

**B-11 — The server counted characters differently from every composer.**
`requireText` counted UTF-16 code units while Flutter's `maxLength` counts
grapheme clusters, so a full 500-character post containing emoji is 750 units
and was refused — landing in `_syncPost`'s generic catch as a Retry button that
re-sends identical text forever. Fixed: `countChars` uses `Intl.Segmenter`, the
same segmentation the client uses, plus a wire backstop.

**B-12 — Five of six client-supplied document ids went into a Firestore path
unguarded.** Only `forgetCoachMemory` checked, and only for a slash;
`createReply`'s postId, `reportPost`'s, `reportReply`'s pair and
`moderationQueue`'s flagId checked nothing, so a reserved id became an
unhandled throw and a 500. Fixed with one shared `requireDocId`.

**B-13 — The reply composer had no maximum at all.**
The post composer's `maxLength` was the only length limit in the app, so a
three-sentence reply — the length of a real answer to someone in crisis — was
accepted, rendered as sent, refused by the callable and dropped. Fixed:
`PostQuality.maxPostChars`/`maxReplyChars` are now the single source, pinned
against the TypeScript handlers by the existing parity test.

**B-14 — A refused reply stayed in the thread looking sent, forever.**
`addReply` called `.ignore()` on every outcome, so it could not tell a dropped
connection from a final refusal — and a reply the server rejected (a slur, or
over-length) sat in its author's own thread while nobody else could ever see
it. Fixed: a refusal removes the reply and tells the user; a wire failure still
keeps it, which is the local-first stance.

---

## Functions 5 & 6 — `rcWebhook` / `refreshEntitlement` — NO BUGS FOUND

The highest-blast-radius pair in the codebase, and the best built. 35 existing
tests already covered ordering, TRANSFER, duplicate suppression, sandbox
gating, grace periods, early renewal and "never write free on a failure". Every
adversarial case tried came back correct. Nothing was changed; 4 tests were
added for security properties the comments *claimed* but nothing pinned:

- an **unset** webhook token closes the endpoint rather than accepting
  `Authorization: Bearer ` — the failure mode is a mis-bound deploy, not an
  attacker, and it has happened once already (docs/10, Sep 2)
- a malformed or overlong `app_user_id` is skipped, not a 500 that RevenueCat
  then retries forever
- a TRANSFER with one unusable side still mirrors the other
- an array `event` (which types as `object`) and a non-string `app_user_id`
  are refused before any write

---

## Function 7 — `deleteUserData`

**B-15 — Full erasure left the departed account's uid on every post it had
reacted to or reported.** `posts/{id}/reactors/{uid}` and
`posts/{id}/reporters/{uid}` are keyed by the reader's uid and live under
`posts`, so neither `recursiveDelete(users/{uid})` nor the two anonymize passes
ever reached them — a durable record of what that person read and how they felt
about it, surviving the one operation whose whole promise is that nothing does.
Fixed: reactions are deleted outright (there are no words to keep, and
`onReaction` decrements the count), reports lose the identity but **keep the
count**, since undoing a real reader's flag would un-hide reported content.

Two supporting changes were needed. `reporters` rows carried no `uid` FIELD —
only the document id — and a collection-group filter on `documentId()` needs a
full resource path, so they were unreachable by query; the field is now written
by `reportPost`/`reportReply`. And `firestore.indexes.json` gained the
`reporters.uid` COLLECTION_GROUP override, without which the query throws
FAILED_PRECONDITION **in production only** — the emulator does not enforce
indexes. (`reactors.uid` already had one, for the app's own reactions query.)

Verified by disabling the fix and confirming all three new tests go red.

**B-16 — The erasure sweeps loaded the whole result set into memory.**
Found auditing B-15's own fix. `anonymizePosts` was bounded in practice (three
posts a day), but REPLIES and REACTIONS are uncapped, so an unlimited `.get()`
materialised a heavy reader's entire history inside a 512MiB function. All four
sweeps now run through one paged `sweepDelete` whose termination is structural
— the matched document is always deleted, so each pass shrinks the result — and
each page commits alone, so an interrupted erasure resumes rather than
restarting. Pinned by a 251-reaction case that fails against a single-page
sweep.

**B-17 — Two sanitizers scanned an unbounded client string.**
`alias` and `avatarEmoji` never pass through `requireText`, so they arrive as
raw text on a callable whose body may be megabytes — and both ran an allowlist
regex (or `Array.from`) across the whole value. Both now read a 256-character
window, far wider than any legitimate value and free on a hostile one.

---

## Function 8 — `aiCoachChat`

The handler itself is sound: quota is claimed before the model is ever called,
both the model failure and an empty reply refund it, all five background tasks
swallow their own errors so a delivered reply cannot become one, and the
`COACH_FOLLOWUPS` kill switch reads `=== 'false'` the right way round. No bug
found in it. The bug was one layer down, in the allowance it depends on.

**B-18 — Any client could reset every daily allowance in the product by
declaring a different timezone.** The day key is derived from the timezone the
CLIENT sends on each request, and `normalizeTimeZone` accepts any real IANA
zone — so "today" is a 26-hour range the caller picks. Because a usage row
remembers exactly ONE day, flipping reset the counter in *both* directions:

```
east #4 (should refuse)  key=2026-09-13 -> refused (used 3)
switch to west           key=2026-09-12 -> ALLOWED (used 1)   <- reset
switch BACK to east      key=2026-09-13 -> ALLOWED (used 1)   <- reset AGAIN
```

Not twice the allowance — unbounded, against the coach cap (where one claimed
message can cost several model calls), the daily post cap, the SOS cap and the
panic counter. Fixed with `windowFor`: the window only ever moves FORWARD, so
an earlier key keeps the stored window and a real midnight anywhere still
resets. The SOS *cooldown* had already been hardened against exactly this
("a caller could have flipped it on demand"); the counters had not.

`refundCoachMessage` deliberately keeps its strict key compare — it is not
client-callable, and widening it would re-open the free message that
"ignores a refund aimed at a day that is no longer current" exists to refuse.
That test caught the over-reach, and the reasoning is now recorded in both.

---

## Cross-cutting — `replyCount` (B-19)

**B-19 — The feed downloaded every live reply in the app to render a number.**
`fetchPosts` limited posts to 50 and then ran `collectionGroup('replies')
.where('status','==','live')` with **no limit**, while `PostCard` used the
result only for `replies.isNotEmpty` and `replies.length`. Bodies are needed
only on the thread screen, which `fetchPost` already loads correctly. Replying
is uncapped and free by design, so the cost grew with replies TIMES readers:

| live replies | feed opens/day | reads/day | $/month | payload/open |
|---:|---:|---:|---:|---:|
| 1,000 | 500 | 500K | $9 | 0.2 MB |
| 10,000 | 2,000 | 20M | $360 | 2.0 MB |
| 45,000 | 5,000 | 225M | **$4,050** | 9.0 MB |
| 150,000 | 15,000 | 2.25B | **$40,500** | 30 MB |

It would have overtaken the PRD's $0.25/user/mo AI guardrail well before launch
traffic and approached the whole $44K MRR target after it.

Fixed by denormalising `posts/{id}.replyCount`, the same shape `onReaction`
already maintains for `reactions`. Four design choices are load-bearing:

- **A trigger owns it.** Four paths move a reply in or out of `live`
  (`moderateReply`, `reportReply`'s auto-hide, `resolveModeration`,
  `remoderateHeld`); incrementing at each is four places to remember and a
  fifth to forget. `onReplyStatus` sees all of them.
- **It recounts rather than increments.** Triggers are at-least-once, so an
  increment would double on re-delivery and stay wrong forever. `count()` is one
  aggregation read (billed per 1000 index entries), is idempotent, and
  self-heals drift — including posts written before the field existed. This is
  deliberately unlike `onReaction`, which needs per-emoji counts no single
  aggregation can produce.
- **It skips writes that cannot matter.** Only a change in live-ness recounts,
  so `deleteUserData` anonymizing a departing account's replies costs nothing.
- **The client field is nullable.** `Post.replyTotal` falls back to the loaded
  replies, so the fake backend, the seed fixtures and every existing test keep
  working untouched, and the optimistic reply moves the count and its rollback
  takes it back.

`npm run backfill:replyCounts` (idempotent, `--dry-run` supported) fills the
field for existing posts whose threads have gone quiet, since self-healing only
reaches a post somebody still replies to.

---

## The 15 remaining functions — multi-agent pass (Sep 12 2026)

210 agents: one deep reader per remaining Cloud Function, then every finding
put to three refutation lenses (correctness, reachability, already-covered) with
a majority-refute kill. 57 confirmed, 8 refuted by the panel, 7 dropped as
already-tested. **All 16 HIGH findings fixed below** (B-20…B-31); 2 critical and
39 medium/low remain open.

**B-20 — Reactions were impossible on the real backend.** The feed drew one pill
per key already on the post and `createPost` wrote `{}`, so a real post offered
nothing to tap and `setReaction` was never called by anything. It only looked
alive because the demo fixtures ship with counts. Fixed: the feed renders the
PALETTE, and `createPost` seeds it at zero.

**B-21 — `emoji` was unvalidated client text rendered on every reader's feed.**
A reactor document is written client-direct, so it is the one piece of text a
reader puts on somebody else's post without passing `createPost`, the prefilter,
the classifier or the slur check — and the key set was unbounded, so cycling
values grew the post document toward the 1MiB ceiling.

**B-22 — An emoji containing a dot took the community tab down for everyone.**
`update()` parses a string key as a dot-separated field path, so `a.b` wrote
`reactions: {a: {b: 1}}`; every client then threw casting to `Map<String,int>`,
the feed failed whole, and neither the server (deltas, no recount) nor the
author (`allow update: if false`) could heal it. Fixed by a closed palette
enforced in THREE places (`firestore.rules`, `onReaction`, the Dart client,
three-way parity test) plus `FieldPath` instead of interpolation.

**B-23 — Quiet hours never reached the server.** `setQuietHours` was the only
push-affecting setter without `_syncPushPrefs()`, so local reminders honoured
the new window while `users/{uid}.pushPrefs` kept the old one — 23–8 by default,
since a user who never touched a toggle has no map at all. A night worker was
silenced correctly by every local reminder and buzzed awake by every community
reply. The test concealed it by calling another setter straight after.

**B-24 — Unconfirmed days counted as flawless zero-puff days** in `taperRecalc`
and `weeklyInsight`. Those rows are minted routinely (`InitialJourney`, a mood
check-in, a survived craving), so silence scored as perfection: a brand-new user
could be advised a day-2 limit of 0, and the Insight report praised days nobody
logged. Every other aggregate in the codebase already filters `isConfirmed`.

**B-25 — `adviseTomorrow` overrode the curve off ONE partial day, with no
floor.** docs/03 §3.3's hard rule ("limit never < the fixed 3-day floor sequence
until its time") had no implementation. Fixed: a 3-day minimum sample, and a
floor of 4 before the endgame — itself capped by the curve, since "never above
curve" outranks it when a small baseline puts the curve underneath.

**B-26 — Every weekly report was pushed inside quiet hours, by construction.**
It fanned out on `recalcHourUtc`, which marks local 01:00 — right for
`taperRecalc`, which writes a number nobody is awake to read, and wrong for the
one cron that ends in a notification. Fixed: local 09:00–11:00.

**B-27 — Every weekly report was generated in English.** `insightPrompt` carried
no language directive and the recipient's locale was never passed, in an app
shipping five languages that records `users/{uid}.locale` for exactly this — and
the push deliberately uses the report's own headline as its copy, on the stated
grounds that it is "generated in the user's own language".

**B-28 — The report run had no deadline and no resume.** Ordering is by
`__name__`, so being killed mid-page always lost the same lexicographic tail,
every week, permanently. Fixed: three local hours, a deliberate deadline that
logs, and `generateFor` skipping anyone already holding this week's report
(checked before the journey read, so a later pass costs one read).

**B-29 — A post the founder cleared was re-hidden by ONE further report.**
`reportCount` is lifetime and the auto-hide tests `>= 3`, so a post that had
ever been hidden sat at 3 while live; after one review cycle the effective
threshold was permanently one. Fixed: the counter clears with the decision, and
the `reporters` subcollection deliberately does NOT — that dedupe is what makes
the reset safe, so hiding it again takes three genuinely new readers.

**B-30 — A reply the model blocked and the founder allowed published in
silence.** The notification was gated on `wasPending`, and a blocked reply is
`blocked`. So the one case where a human overrules the model in the user's
favour never told the SOS author that somebody had answered.

**B-31 — Untrusted post text went unfenced into the classifier.** The one model
call whose input is adversarial by definition, against the cheapest model, with
the output contract published in the system prompt — and a successful bypass
writes NO queue row, so it leaves exactly the trace of a clean post. Fixed by
fencing the prompt and delimiting the turn (tag outside the fence, so a forged
`Tag:` line is distinguishable). **`npm run eval:moderation` 66/66 on
gemini-3.5-flash-lite**, including three new injection cases — the suite had
none.

**B-32 — The free tier's panic session was counted but never granted.** docs/04
§7 specifies "5 coach msgs/day + 1 panic session/day"; `panicUsage` was
incremented, returned to the client and read by nothing, so every panic turn
spent an ordinary coach message. Somebody at 9/10 intensity who had used their
five was told to come back tomorrow — on the screen that had just offered them
Ember. Fixed with its own counter and allowance, falling THROUGH to the ordinary
one when spent rather than refusing. **The number (1 message) is the spec read
literally and is a `defineInt` param — if a session should buy more than one
exchange, that is the single line to change.**

---

## The six mediums worth fixing (Sep 12 2026)

**B-33 — The push gate failed OPEN on consent and on quiet hours.** A read
failure on `users/{uid}` — a document four other writers touch, so contention is
ordinary — returned `allowed: true, quiet: false`, i.e. maximum permission. The
push went to somebody who had switched that category off, loudly, inside their
declared quiet hours. The old reasoning ("a push is a courtesy") is right for
the BUDGET and wrong for the other two: consent is not a courtesy, and a
wrongly-SILENT push still arrives while a wrongly-LOUD one wakes someone at 3am.
Both fail closed now; the inbox row is written independently, so nothing durable
is lost.

**B-34 — `remoderateHeld` could silently overturn the founder.** The
`status === 'pending'` guard runs BEFORE `classify` (a 1–3s model call) and the
write after it had no re-check. A decision landing in that window was
overwritten: the founder blocks a post, the sweeper's `allow` republishes it,
sets the author's mirror live and stamps the row `reviewedBy: 'remoderate'` over
their name — so it leaves the queue and they never learn. Fixed with a
compare-and-set; a person's verdict outranks the sweeper's, always.

**B-35 — "Forget this" was offered for a sentence nothing could forget.**
`profile.whyWords` is printed into every coach turn by the user card, AND seeded
into the vector store, so the memories screen rendered it twice: once as a
permanent fact, once with a Forget button that said "Forgotten. Ember won't
bring it up again" and changed nothing. Fixed on the screen — the card is the
copy that stays, being deterministic, free, and what the "anchor to their why"
protocol reads.

**B-36 — Testimonials are no longer filtered by locale at all.** (Founder
decision, Sep 12 2026.) The audit found that the cross-language fallback served
the English rows to every non-English user — a French reader got English
sentences under a French "AVIS RÉEL" badge. Removing the fallback fixed that but
left four of five languages with no quotes, since no translated rows exist.

The founder's call is to show whatever the collection holds, to everyone: the
quotes are real beta-tester reviews, there are only ever a handful, and showing
them is worth more than matching them to the reader's language. `poolFor(lang)`
is now `livePool()` — `status == 'live'` and nothing else. This also retires the
case-sensitivity bug on the way past (`normalizeLocale` does not lowercase, so
`PT-BR` matched no rows and fell through to English).

`locale` stays on the documents and `sourceLocale`/`translationOf` stay in the
schema, so per-language selection can come back the day there are rows to
select from.

**B-38 — The D3 prefetch fired seven times per onboarding, not once.** Seven
empty `case` arms fell through into `worries: _prefetchRatingStep()`, so six
calls went out before `why` or `worries` were answered — the two heaviest
tailoring signals — and since the responses race, an early untailored answer
could land last and overwrite the tailored one. Fixed, plus a sequence guard so
only the newest issue may write.

Each of the six is pinned by a test verified to go RED without its fix.

---

## Closed as not-a-bug

**The D3 testimonial quotes are real.** (Founder, Sep 12 2026.) The multi-agent
pass raised this twice at CRITICAL: `payoff_steps.dart:513` hardcodes `★★★★★`
and `:529` the "REAL REVIEW" badge, no `rating` field exists on the wire type,
the domain type or either production row, and both live rows carry a
self-referential `consentRef` ("shipping in app_en.arb as obRatingQuote1")
pointing at ARB keys deleted on Sep 3 — which docs/08 §S6-2 and docs/10 §1947
had called "five-star reviews no human ever said".

They are real beta-tester reviews. The ARB strings were where those quotes
originally shipped, and moving them into the `testimonials` collection is what
`S6-2` was struck through for. Nothing to fix; the screen stands.

Worth knowing for the next row rather than for these two: the five stars are
drawn by the widget, not stored per quote, so a future testimonial from someone
who rated four would still render five. If that case ever arises, a `rating`
field on the row is the fix.

Recorded here because an automated audit will flag it again otherwise — it did,
with three independent verifiers, and they were all reasoning from the code
alone.

---

## Accepted risks — reviewed, deliberately not changed

**A-01 — `refreshEntitlement` is unthrottled.** (Founder decision, Sep 12 2026.)
Each call costs ~2 RevenueCat round-trips against a per-project quota shared
with `rcWebhook`, so a signed-in client in a loop could exhaust it and the
failure would land on the webhook — 500, retry, paying customers unmirrored.
The caller gains nothing by lying (the callable takes no tier from anyone), and
throttling would add a Firestore read to the post-purchase path, which is the
one moment that must stay fast. Accepted as-is. If it ever needs closing, the
shape is a ~10s per-uid cooldown on `usage.ts`'s transactional claim, skipped
on the first call after a purchase.

---

## Open findings — not fixed, need a product decision

**F-03 — Going over baseline is free.**
`MoneyEngine.savedOn` clamps at 0, so a 400-puff day against a 200 baseline
contributes exactly the same as a disciplined 200 — the lifetime total does not
move. Defensible (money saved cannot be un-saved), but it drifts above reality
for anyone who regularly exceeds baseline.

**F-04 — A perfect day nobody confirmed is worth $0.**
`isConfirmed` is `puffs > 0 || vapeFreeConfirmed`, so vaping 199 times pays
more than vaping zero unless the user ticks a box. Home asks the next morning,
but only about *yesterday* — a good weekend away from the app is unclaimable.
