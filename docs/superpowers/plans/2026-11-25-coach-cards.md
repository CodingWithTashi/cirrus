# Coach Cards (A2UI) and the Exercise Registry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ember's replies carry a tappable card that opens a craving exercise in one tap and returns to the chat; Ember knows what the person has used during cravings and what they just did; and a new exercise plugs in with one registry row per side.

**Architecture:** One exercise registry (pure Dart, mirrored in TypeScript, parity-tested) is the only list of exercises. The server decides which cards a reply carries with deterministic code and sends them as a small typed `ui` block list in the existing `aiCoachChat` envelope. The app turns those blocks into A2UI and renders them with `a2ui_flutter` against a catalog of its own widgets, confined to one folder.

**Tech Stack:** Flutter 3.50, Riverpod 3, go_router 18, `material_ui`, `a2ui_flutter` 0.5.0 + `a2ui_core` 0.9.0 (pinned exactly), gen-l10n ARB (6 locales); TypeScript Cloud Functions 2nd gen (CommonJS, Node 22), vitest, the Firestore emulator.

**Spec:** this file. Sections "Context" to "Contracts" are the design; the tasks argue from them.

**To start in a new conversation, say:** *"Read `CLAUDE.md` and `docs/superpowers/plans/2026-11-25-coach-cards.md`, then run Stage 0."* Stage 0 is ONE agent, in order. After it, the four lanes in "Lanes and order" run in parallel.

**Research behind it** (Nov 25 2026, not in the repo): the `a2ui_flutter` notes and the 8-test spike lived in a temporary session folder. Everything the tasks need from them is restated in "What was checked before planning".

---

## Context

**Why.** Ember tells people to "breathe with me" or try a "60-sec game", but a reply is plain text: acting on it means leaving the chat, going Home and stepping through the panic flow. Ember also knows almost nothing about cravings: the user card carries one total, while `users/{uid}/cravings` is written by `panicSession` and read by nothing but `eraseHistory`. And each exercise is wired by hand (the loop screen, `GameCatalog`, the server's `PANIC_GAMES`), so every new one costs edits in several places.

**What prompted it.** The founder asked (Nov 25 2026) for the coach to route people into exercises by their choice, to know and track their progress, and for a structure that takes more exercises without rework, built on `a2ui_flutter`.

**Outcome.**

| Moment | Today | After this plan |
|---|---|---|
| "I'm craving" in the chat | Words. Acting on them means leaving the chat. | Up to three cards under the reply. One tap opens the exercise; Back returns to the chat. |
| Mid-craving (arrived from the panic flow) | 20 words. The craving was already reported abandoned when the chat opened. | The same words and exactly one card. The SAME craving continues: its clock and its strength carry over. |
| After the exercise | "It passed" ends on Home. Ember knows nothing happened. | It ends back in the chat. Ember is told what they did. |
| What Ember knows about cravings | One total. | When the last one was, what they had open, whether their own re-rating dropped, which tools they have used. |
| Ember has no messages left, or the model is down | A sentence. | The sentence and a card: the exercise still works. |
| Adding an exercise | Hand edits in three places. | One registry row per side, one catalog entry, its screen. |

**Honest limits.**
- A2UI is a rendering layer. It does not raise retention by itself, and nothing here is measured yet.
- With typed blocks on the wire and one block type, A2UI does little work in this release. It is here because the founder chose it and because it is the rail for richer, server-composed and interactive surfaces later. The package is pre-1.0: every minor release 0.1 to 0.5 was breaking, five in 19 days.
- Cards are Premium only (below). With 2 active paid plans on Nov 21 2026, almost nobody will see one until the audience is widened.

## Founder decisions (Nov 25 2026)

1. **Coach cards are Premium only.** Free accounts keep today's text-only replies. No teaser and no new paywall door. The audience is ONE server param (`COACH_UI_AUDIENCE`: `premium` | `all` | `off`), so it widens without an app release.
2. **Exercises the founder is building** (may change; this plan does not build them, it builds what they plug into):

   | Exercise | Shape | Plugs in as |
   |---|---|---|
   | Burst | Hold-to-run 20 s timer, three isometric holds | a screen inside `ExerciseScaffold` |
   | Breathe | 4-4-6 orb, six cycles, press and release, a sync % | replaces the body of the `breathing` entry |
   | Surf | 90 s wave, one input ("I feel it change") | a screen inside `ExerciseScaffold` |
   | Blocks | Three lanes, tap the target colour | an arena game through `GameCatalog`, as today |
   | Plan + Grow | Trigger + response chips = a saved if-then card with "Use now"; a plant that grows at 1 / 3 / 6 / 10 cravings beaten | "Use now" calls `ExerciseCatalog.launch`; the plant reads `cravingsSurvivedTotal`, which every exit in this plan feeds through one path |

## Amendments (founder, Nov 25 2026, after Stage 0 and lanes X and S1–S3)

These supersede the text they name. Where a task still says "13 fixtures", read 14.

- **A1 — the menu keeps the SOS card.** Policy step 5 skips the kind `recent[0]` already covers, so a subscriber whose latest tool is Tiles or Blocks gets that game, breathing and SOS, not two games and nobody to ask. One new fixture, `craving_chip_recent_tiles`. (K6, lane 0 + `planBlocks` in lane S.)
- **A2 — "It passed" said in the chat counts the craving.** `PanicViewModel` gains `bool surviveParked({ExerciseId? exercise, ExerciseSource? source})`: when a PARKED, unresolved craving exists it is counted exactly as `survive` counts one (one `craving_outcome{survived: true}`, one `PanicRepository.survived`, `cravingsSurvivedTotal` +1) and the call answers true; with nothing parked it does nothing and answers false. In U4 the `panicItPassed` chip calls it with the run's exercise and `ExerciseSource.coach` before it prefills the composer; `coachAfterStill` only prefills. (Lane X adds the method; U4 uses it. Supersedes U4's "tapping one fills the composer and sends nothing" for the first chip: it still sends nothing, but it counts.)
- **A3 — coming back from a survived craving does not reopen the shop.** "Back to the chat" lands on `/coach` with no `?panic=`, which today clears `_panicArrivedAt` and with it the cap's no-selling window. U3 keeps that window alive across the return, pinned by a test: the cap's upgrade button stays hidden until the window that was running before the exercise has closed. (Lane U, `coach_screen.dart`.)
- **Lane S** continues into S4 and prepares S5 (steps 1–2); S5 step 3 still waits for the founder's yes.
- **A4 — two card lines are for everyone, and the eval grades them.** "right now is one of their danger hours" and "last puff: …" go on every non-panic turn, whatever the tier or app; only the craving log sits behind the card audience. Eval scenario `25-danger-hour` was added so the danger-hour line is graded. The craving lines may add up to the measured worst case (five tools on record) rather than S4's "at most 560"; the 2,000-character card guard is the limit and is not raised.
- **A5 — eval attempt 1 missed the bar (Nov 25); attempt 2 changes three things first.** On the premium model the reply to `24-just-did` said "42 cravings" against the card's 41, so the just-did line now ends `…and marked the craving as passed (already counted in "cravings survived" above)`, which supersedes that line in S4's "Exact card text". `24-just-did` gains the craving-count check that 23 and 25 share. `01-craving-2am` joins the cases that must not get worse. The bar, both attempts' readings and the transcripts are in `docs/superpowers/evidence/2026-11-25-coach-cards/eval/`.
- **Evals and the production cap.** Attempt 1 ran on the production `GEMINI_API_KEY` and the project hit its monthly spending cap mid-run (429s from about 19:44 EST). Evals should run on a key or project of their own; until one exists, no roll starts without the founder saying the cap has room. Deploy 2 (S4–S5) stays undeployed until attempt 2 meets the bar; Deploy 1 (S1–S3) can be cut from the `deploy1-functions-*` snapshot.

## What was checked before planning

- **Package** (its own source, the pub.dev API): `a2ui_flutter` 0.5.0, publisher `labs.flutter.dev`, released Nov 23 2026; `genui` is discontinued in its favour. No network code. It imports `package:flutter/material.dart` and force-depends on the native `video_player` plugin.
- **Spike** (8 of 8 widget tests, outside the repo, `flutter test` only): a custom catalog renders under `material_ui`'s `MaterialApp.router` + a `ThemeExtension` + `MaterialUiCompatibilityBridge`; a tap reaches go_router; strict validation refuses an extra property, an unknown enum value and an unknown component.
- **Not proven (task U1 is the gate):** the real app building with `video_player` on Android and on iOS, its size cost, anything on a device.
- **The code today:**
  - `functions/` is CommonJS; nothing ESM-only can be imported.
  - `panicSession.ts` writes a craving doc only for `outcome: 'survived'`, with `startedAt` stamped when the outcome is reported. `intensity` is the untouched default 7 unless the slider moved; `game` is set when the arena opens, before any round.
  - The panic flow's coach door is `context.go` (`panic_screens.dart:826`), which disposes the flow, whose `dispose` calls `abandon()` (`:303`).
  - The arena calls `ensureStarted()` (`game_arena_screen.dart:124`) and never `abandon()` (`:154`).
  - Breathing is not launchable alone: `_BreatheStep` is private and reads `panicProvider`. `BreathRing` and `BreathPacer` are provider-free.
  - `SurvivedScreen._leave` always ends `context.go(Routes.home)` (`panic_screens.dart:922`).
  - Every path under `/panic` already inherits the journey gate and the forced-update deferral (`app_router.dart:135, 218`).
  - `CoachRepository.streamReply` has two implementers in `lib/` and several test stubs; `PanicRepository` has two in `lib/` and `_StubPanic` in `test/widgets/panic_session_test.dart`.
  - `coachEval.ts:485` builds ONE card for all scenarios; a scenario cannot add card lines.
  - `BasicComponents.column` in `a2ui_flutter` is a `LayoutBuilder` (`layout.dart:160`), which throws under an intrinsic-height walk.
  - No test enforces any "only file X imports package Y" rule; copy `test/review_ask_placement_test.dart:55-66`.
  - Source-grep tests that constrain this work: `LpReview.request(` may appear only in `lib/features/panic/panic_screens.dart` (**do not move `SurvivedScreen`**); `panic_screens.dart` must not contain `paywallFrom`; `game_arena_screen.dart` must contain it exactly once (`test/widgets/panic_session_test.dart:195-245`).

## The design in one page

```
 app                                                       server (functions/)
 ─────────────────────────────────────────────             ───────────────────────────────────
 Exercises (domain registry)   ◄── parity test ──►         EXERCISES (domain/exercises.ts)
        │                                                          │
 ExerciseCatalog  (icon, strings, route, screen)           planBlocks()  deterministic policy
        │  launch(context, id, source)                             │
        ▼                                                          ▼
 arena / ExerciseScaffold ── ExerciseRun ─► exerciseRuns   envelope.ui = {v:1, blocks:[…]}
        ▲                                        │                 │
        │ tap                                    │ justDid         │
 CoachSurfaceView ◄─ A2UI built locally ◄─ CoachMessage.blocks ◄───┘
 (a2ui_flutter, one folder)                      └──► aiCoachChat ──► user card: craving lines
```

1. **The registry is the scalability seam.** `Exercises` (Dart) and `EXERCISES` (TypeScript) hold the same rows. The catalog's launcher enum, the capability list, the server policy, `panicSession`'s validation and the analytics values all derive from them.
2. **One way to open an exercise:** `ExerciseCatalog.launch(context, id, source: …)`. It clamps a locked exercise to a free one of the same kind, reports `exercise_opened`, and pushes the entry's route. The coach card and the founder's "Use now" both call it.
3. **One way to finish one.** The arena and `ExerciseScaffold` share two exits: **"It passed"** (the Survived screen; the craving is counted once through `PanicViewModel.survive`, the path every craving already takes) and **back** (nothing counted). Either files an `ExerciseRun`.
4. **A craving handed to the coach continues.** The panic flow *parks* its session before opening the coach. A card tapped inside the 20-minute craving window *joins* it: same clock, same strength. Whoever joined or opened a session parks it again on the way out. A parked craving is reported not survived only when the next one starts.
5. **The server decides, deterministically.** `planBlocks` picks cards from the chip, the craving context, the tier, the client's capability list and the craving digest. No model call is involved.
6. **Typed blocks on the wire, A2UI inside the app.** The reply carries `ui: {v: 1, blocks: [{t: 'launcher', exercise: 'orbs'}]}`. `lib/features/coach/surface/` converts blocks to A2UI v1.0 messages and renders them. Why not A2UI on the wire: every installed build keeps its own strict validator for ever, so a server writing A2UI would have to satisfy all of them while the package changes weekly; and strict validation drops a whole surface for one unknown value, where a block list drops one card. The door stays open: a later `v` can add a pass-through field for server-authored A2UI.
7. **The app owns everything drawn.** A block carries an id and nothing else. Labels come from ARB, colours from `context.lp`, routes from the catalog.
8. **Capability negotiation is a list.** The app sends `ui: {v: 1, exercises: [every id this build knows], craving: bool}`. The server intersects it with its own registry and its own tier read. No `ui` in the request (an older build, or the Day-1 walkthrough's coach step) means no cards.
9. **Only the newest Ember reply shows its cards**, like follow-up chips. One live surface, one processor for the thread, nothing stale in the scrollback, nothing persisted to history.
10. **Context is stored facts in words.** Three to five labelled lines, no counts, no rating the person did not give, none on a panic turn.

### How to add an exercise (the whole checklist; a test fails until each line is done)

1. Build its screen inside `ExerciseScaffold` (or, for an arena game, its engine + field + `GameCatalog` entry as today).
2. `lib/domain/logic/exercises/exercise.dart`: one `ExerciseId` value and one `ExerciseSpec` row.
3. `functions/src/domain/exercises.ts`: the same row and its entry in `EXERCISE_LABELS` (typecheck fails without it).
4. `lib/features/exercises/exercise_catalog.dart`: one `ExerciseEntry`.
5. Title and subtitle strings in six ARB files.
6. `flutter test test/domain/exercises_test.dart test/features/exercise_catalog_test.dart` and, in `functions/`, `npx vitest run test/exercises.test.ts`.

Nothing in the coach screen, the coach store, `aiCoachChat`, the prompt or the wire changes. Deploy functions before the app release that carries the new id.

## Contracts (frozen by Stage 0; lanes build against these and may not change them)

**K1 — `lib/domain/logic/exercises/exercise.dart`** (pure Dart)

```dart
/// `.name` is a wire value (callable payloads, craving docs, analytics, routes). Never rename one.
enum ExerciseId { breathing, orbs, tiles, blocks, sos }
enum ExerciseKind { calm, focus, people }
enum ExerciseSource { panic, coach, plan, home }

class ExerciseSpec {
  const ExerciseSpec(this.id, this.kind, {this.premium = false, this.game});
  final ExerciseId id; final ExerciseKind kind; final bool premium; final GameId? game;
}

abstract final class Exercises {
  static const List<ExerciseSpec> all;                    // order below; all.first is free
  static ExerciseSpec of(ExerciseId id);
  static ExerciseId? parse(Object? name);                  // unknown or non-string → null
  static ExerciseSource? parseSource(Object? name);
  static ExerciseId? forGame(GameId game);
  static ExerciseId resolveFor(ExerciseId id, {required bool premium});
      // premium or free exercise → id; else first free of the same kind; else all.first
}

class ExerciseRun {
  const ExerciseRun({required this.id, required this.source, required this.seconds,
                     required this.completed, required this.passed, this.score});
  final ExerciseId id; final ExerciseSource source; final int seconds;
  final bool completed;   // ran long enough to count as done
  final bool passed;      // ended on "It passed"
  final int? score;
}

abstract final class CravingWindow {                       // docs/03 §7: most cravings pass in 15–20 min
  static const Duration duration = Duration(minutes: 20);
  static bool covers(DateTime? since, DateTime now);       // since != null && now - since < duration
}
```
Rows, in order: `breathing` calm free · `orbs` focus free game · `tiles` focus premium game · `blocks` focus premium game · `sos` people free.

**K2 — `functions/src/domain/exercises.ts`**

```ts
export const EXERCISE_KINDS = ['calm', 'focus', 'people'] as const;
export const EXERCISE_SOURCES = ['panic', 'coach', 'plan', 'home'] as const;
export const EXERCISES = [
  {id: 'breathing', kind: 'calm', premium: false, game: false},
  {id: 'orbs', kind: 'focus', premium: false, game: true},
  {id: 'tiles', kind: 'focus', premium: true, game: true},
  {id: 'blocks', kind: 'focus', premium: true, game: true},
  {id: 'sos', kind: 'people', premium: false, game: false},
] as const;
export type ExerciseId = (typeof EXERCISES)[number]['id'];
export type ExerciseKind = (typeof EXERCISE_KINDS)[number];
export type ExerciseSource = (typeof EXERCISE_SOURCES)[number];
export const EXERCISE_IDS: readonly ExerciseId[];
export function exerciseById(id: unknown): (typeof EXERCISES)[number] | null;
/** How the user card names each one. Typed exhaustively: a new id fails typecheck until it has a label. */
export const EXERCISE_LABELS: Record<ExerciseId, string>;
   // breathing 'the breathing exercise' · orbs 'the Orbs game' · tiles 'the Tiles game'
   // blocks 'the Blocks game' · sos 'an SOS post to the community'
```
One row per line in exactly that key order: the Dart parity test reads the file with a regex.

**K3 — Wire** (every addition optional; an old app and an old server ignore them)

```
request  ui:      { v: 1, exercises: string[], craving: boolean }     // ≤ 32 ids
request  justDid: { exercise: string, seconds: number, completed: boolean, passed: boolean }
reply    ui:      { v: 1, blocks: Block[] }                           // omitted when empty, ≤ 4 blocks
Block =  { t: 'launcher', exercise: string }
```
A client skips a block whose `t` or `exercise` it does not know and keeps the rest.

**K4 — Dart coach types** — new `lib/domain/models/coach_ui.dart`

```dart
sealed class CoachBlock { const CoachBlock(); }
final class CoachLauncherBlock extends CoachBlock {         // == and hashCode by exercise
  const CoachLauncherBlock(this.exercise);
  final ExerciseId exercise;
}
class CoachUiCaps {
  const CoachUiCaps({required this.exercises, this.craving = false});
  static const int version = 1;
  final List<String> exercises; final bool craving;
  Map<String, Object?> toJson();                            // {'v': 1, 'exercises': [...], 'craving': craving}
}
class CoachTurnExtras {
  const CoachTurnExtras({this.ui, this.justDid});
  final CoachUiCaps? ui; final ExerciseRun? justDid;
  Map<String, Object?> toJson();                            // only the keys that are set
}
```
- `CoachReply.blocks` and `CoachMessage.blocks` (the `ember` constructor): `final List<CoachBlock> blocks;`, default `const []`.
- `CoachRepository.streamReply({String? text, CoachChip? chip, required bool capped, int? panicIntensity, CoachTurnExtras? extras})`.
- `PanicRepository.survived({int? intensity, int? intensityAfter, GameId? game, ExerciseId? exercise, ExerciseSource? source})` — `intensity` becomes optional.

**K5 — `lib/data/stores/exercise_runs.dart`**

```dart
class ExerciseRuns extends Notifier<ExerciseRun?> {
  void report(ExerciseRun run);                             // state = run; fires exercise_finished; stamps the time
  ExerciseRun? takeRecent({required ExerciseSource source, required DateTime now});
      // the stored run when its source matches and it was reported inside CravingWindow.duration; clears it
  ExerciseRun? peekRecent({required ExerciseSource source, required DateTime now});   // same, without clearing
}
final exerciseRunsProvider = NotifierProvider<ExerciseRuns, ExerciseRun?>(ExerciseRuns.new);
```

**K6 — Fixtures** — `functions/test/fixtures/coach_ui/<name>.json`, each `{"input": PlanInput, "blocks": Block[]}`. Vitest pins `planBlocks(input)` to `blocks`; Dart feeds every `blocks` through the codec and the real A2UI processor, and pins the fake backend to the same files.

```ts
interface PlanInput {
  audience: 'off' | 'premium' | 'all';
  tier: 'free' | 'trial' | 'premium';
  chip: 'craving' | 'roughDay' | 'slipped' | 'progress' | null;
  panicIntensity: number | null;
  caps: { exercises: string[]; craving: boolean } | null;
  recentTools: string[];              // from the craving digest, most recent first; [] when none
}
```

| File | Input (unstated fields: audience `premium`, tier `premium`, chip `null`, panic `null`, caps all five + `craving: false`, no tools) | `blocks` (launchers) |
|---|---|---|
| `panic_default` | panic 8 | `breathing` |
| `panic_recent` | panic 8, tools `[orbs]` | `orbs` |
| `craving_followup` | caps `craving: true`, tools `[orbs, breathing]` | `orbs` |
| `craving_chip` | chip `craving` | `breathing`, `orbs`, `sos` |
| `craving_chip_recent` | chip `craving`, tools `[orbs, breathing]` | `orbs`, `breathing`, `sos` |
| `craving_chip_recent_tiles` (added by amendment A1) | chip `craving`, tools `[tiles]` | `tiles`, `breathing`, `sos` |
| `trial_tier` | tier `trial`, chip `craving` | `breathing`, `orbs`, `sos` |
| `free_tier` | tier `free`, chip `craving` | none |
| `audience_all_free` | audience `all`, tier `free`, chip `craving`, tools `[tiles]` | `breathing`, `orbs`, `sos` |
| `audience_off` | audience `off`, chip `craving` | none |
| `old_client` | caps `null`, chip `craving` | none |
| `narrow_client` | caps exercises `[orbs]`, chip `craving` | `orbs` |
| `other_chip` | chip `progress` | none |
| `free_text` | (all defaults) | none |

**The policy the table encodes** (`planBlocks`):
1. `available` = registry rows whose id the client advertised, minus premium rows when `tier === 'free'`. Registry order.
2. Nothing when `audience === 'off'`, when `caps === null`, when `available` is empty, or when `audience === 'premium' && tier === 'free'`.
3. `recent` = `recentTools` filtered to `available`.
4. **Craving context** (`panicIntensity !== null || caps.craving`): exactly one launcher — `recent[0]`, else the first `calm` row in `available`, else `available[0]`.
5. **Else `chip === 'craving'`:** `recent[0]` (if any), then the first available row of each kind in `EXERCISE_KINDS` order, **skipping the kind `recent[0]` already covers** (amendment A1), at most three.
6. Otherwise nothing.

**K7 — Events** (snake_case; enum values by `.name`; booleans as `'true'`/`'false'`)

| Event | Props |
|---|---|
| `coach_ui_shown` | `launchers` (int), `panic` (bool), `plan_day` (int) |
| `coach_ui_dropped` | none |
| `exercise_opened` | `exercise`, `source` |
| `exercise_finished` | `exercise`, `source`, `completed` (bool), `passed` (bool), `seconds` (int) |

`craving_outcome` gains optional `exercise` and `source`.

**K8 — Server param** — `COACH_UI_AUDIENCE`, `defineString`, default `'premium'`, read through `coachUiAudience(raw: string): 'off' | 'premium' | 'all'`: trimmed and lower-cased, exactly `off` → off, exactly `all` → all, **anything else including the empty string → premium**.

**K9 — Routes (added by X1) and strings (added by 0.4)**

- `Routes.exerciseBase = '/panic/exercise'`; `Routes.exerciseFor(ExerciseId id, ExerciseSource source)` → `/panic/exercise/<id>?src=<source>`; `Routes.gameFor(GameId id, {ExerciseSource? source})` appends `&src=<source>` when given; the Survived route reads `src`.
- New ARB keys (English; the other five follow `CLAUDE.md` "Localization" and the store screenshots' informal register):
  - `exerciseBreathingTitle`: "Breathe with me"
  - `exerciseGameSub`: "{seconds} seconds · thumbs busy, brain busy" (`seconds`: int)
  - `survivedBackChat`: "Back to the chat"
  - `coachAfterStill`: "Still strong"
- Reused keys: `gameNameOrbs`, `gameNameTiles`, `gameNameBlocks`, `panicBreathePattern`, `panicBreatheIn`, `panicBreatheHold`, `panicBreatheOut`, `panicBreatheInstruction`, `panicLoopSos`, `panicLoopSosSub`, `panicItPassed`, `gameIntensityNow`.

## Lanes and order

| Lane | Owns (nobody else edits these) | Tasks |
|---|---|---|
| **0 Contracts** | `lib/domain/**`, `lib/data/dto/coach_codec.dart`, `lib/data/stores/exercise_runs.dart`, the six ARB files + `lib/l10n/gen/**`, `test/analytics_test.dart`, `test/data/dto_roundtrip_test.dart`, the signature line of every `CoachRepository` / `PanicRepository` implementer, one constant in `coach_screen.dart`, `functions/src/domain/exercises.ts`, the fixtures | 0.1 – 0.5 |
| **X Exercises (app)** | `lib/features/exercises/**`, `lib/features/panic/**`, `lib/app/router/app_router.dart`, `lib/data/repositories/firebase_panic_repository.dart`, the panic and arena tests | X1 – X5 |
| **U Coach surface (app)** | `pubspec.yaml`, `ios/**` (the first SPM build rewrites it), `lib/features/coach/**`, `lib/data/stores/coach_store.dart`, `lib/data/stores/providers.dart`, `lib/data/repositories/*coach*`, `lib/data/api/coach_api.dart`, `lib/data/api/fake/fake_coach_*`, the coach tests | U1 – U5 |
| **S Server** | everything under `functions/` except `src/domain/exercises.ts` and the fixtures | S1 – S5 |
| **P Proof and docs** | `integration_test/**`, `docs/**`, `CLAUDE.md` | P1 – P4 |

```
0.1 → 0.2 → 0.3 → 0.4 → 0.5
                          ├─ X1 → X2 → X3 → X4 → X5
                          ├─ U1 (go/no-go gate) → U2 (needs X1) → U3 → U4 → U5
                          ├─ S1 → S2 → S3 → S4 → S5
                          └─ P1 (after U5 and X5) → P2 (after the founder deploys S1–S3) → P3 → P4
```

**Release shape.** The app ships ONCE with lanes 0, X and U. The server goes out in two deploys the founder makes: S1–S3 (cards), then S4–S5 (craving lines in the card, after the eval rolls). Functions before the app.

## Global Constraints

Every task inherits these. Read `CLAUDE.md` in full first.

- **Never `git commit`, `git push` or `firebase deploy`.** The founder does all three. A task's last step is "leave the change unstaged and list the files". No Claude attribution anywhere in git.
- **Never run `dart format` on a directory or an existing file.** Hand-format new code like its neighbours.
- **ARB files change only through a JSON round trip** to a temp path, then `os.replace`; six locales (en, de, es, fr, it, pt); then `flutter gen-l10n`. `lib/l10n/gen/**` is committed and never hand-edited.
- **Zero hardcoded UI strings, no raw hex, no emoji in drawn chrome.** `context.l10n`, `context.lp`, `Icons.*`.
- **App code imports `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`.**
- **Pin exactly** `a2ui_flutter: 0.5.0`, `a2ui_core: 0.9.0`, `json_schema_builder: 0.1.7` (no caret). **Only `lib/features/coach/surface/` may import them.**
- **A block carries an id and nothing else.** Never a route, a URL, a number, a label or a colour.
- **No invented numbers.** A card line never states a count, and never a rating the person did not enter.
- **Nothing is sold mid-craving, and nobody lands on a lock.** This plan adds no paywall door. `lib/features/exercises/` and `lib/features/coach/surface/` never contain `paywall`.
- **`EMBER_SYSTEM_PROMPT`, `PANIC_MODE_ADDENDUM` and `buildCoachInstruction` do not change.** Only card text does, and only through five side-by-side eval rolls.
- **A param that switches something is read fail-safe:** an unset param is the empty string.
- **Never write a server-owned field onto `journeys/{uid}`.**
- **Any new model field goes in its codec and `test/data/dto_roundtrip_test.dart`.** Anything that exists on both sides gets a parity test.
- **Leave first, then mutate.** Never use `ref` in `dispose()`: capture the notifier in `initState`. Never write a provider's `state` from `dispose()`: do it in the gesture handler, or `scheduleMicrotask` on the captured notifier.
- **A hand-built page passes `name: state.path` and `key: state.pageKey`.**
- **No `IntrinsicHeight`/`IntrinsicWidth` above a coach surface, and no `LayoutBuilder` inside one.**
- **Tests that pump the app use `fastBackendOverrides()`**; a different override goes through `extra:`. A free account passes `premium: false`.
- **Gates before a task is done:** `flutter analyze` clean and the named tests green. At a lane's end: full `flutter test`; in `functions/`, `npm run verify`. Report any failure by name with its output.
- **The plan closes only after its device runs (P1, P2).** Widget tests alone do not close it.

## Review Focus

The inputs most likely to reach a real person that no single task's happy path exercises. Each is pinned by a test in the task named.

1. **Arrives from the panic flow at 8/10 and taps the game card.** Expected: the same craving continues — clock, strength, one `begin()`. (X2)
2. **Second and third message of a craving chat.** Expected: one next step each time, never a three-card menu again. (S1 `craving_followup`, U3)
3. **A reply during the Day-1 walkthrough's coach step.** The walkthrough leaves for the checklist 2.5 s after the reply. Expected: no card at all. (U3)
4. **An older app against the new server, and the new app against an older server.** Expected: both threads exactly as today. (S2, U3)
5. **A lapsed subscriber whose server mirror still says premium is sent a Tiles card.** Expected: the card names and opens the free game of the same kind, never a lock. (X1)
6. **A craving from outside the flow reports a strength nobody gave.** Expected: no strength is sent, stored or shown; Ember never says "you rated it 7". (X3, S4)
7. **The A2UI package refuses or throws on a surface.** Expected: the text reply stands, nothing else renders, no error bubble, one `coach_ui_dropped`. (U2)

---

# STAGE 0 — CONTRACTS (one agent, in order)

### Task 0.1: The exercise registry on both sides, pinned to each other

**Files:**
- Create: `lib/domain/logic/exercises/exercise.dart`, `test/domain/exercises_test.dart`
- Create: `functions/src/domain/exercises.ts`, `functions/test/exercises.test.ts`
- Modify: `lib/features/coach/coach_screen.dart` — one change only: the private `_cravingWindow` constant (`:67`) goes, and `_inCraving` becomes `CravingWindow.covers(_panicArrivedAt, now)`. Done here so no lane has to share that file.

**Interfaces:** Produces K1 and K2 exactly.

- [ ] **Step 1: Write the failing Dart tests** in `test/domain/exercises_test.dart`:
  - `'the first exercise is free, and ids are unique'`: `Exercises.all.first.premium` is false; `Exercises.all.map((s) => s.id).toSet().length == ExerciseId.values.length`.
  - `'parse reads a name and nothing else'`: `parse('orbs') == ExerciseId.orbs`; `parse('nope')`, `parse(7)`, `parse(null)` are null. Same three for `parseSource`.
  - `'a locked exercise resolves to a free one of its kind'`: `resolveFor(ExerciseId.tiles, premium: false) == ExerciseId.orbs`; `resolveFor(ExerciseId.tiles, premium: true) == ExerciseId.tiles`; `resolveFor(ExerciseId.breathing, premium: false) == ExerciseId.breathing`.
  - `'every arena game is an exercise'`: for each `GameId g`, `Exercises.of(Exercises.forGame(g)!).game == g`.
  - `'the craving window is twenty minutes'`: `covers(null, now)` false; `covers(now - 19min59s, now)` true; `covers(now - 20min, now)` false.
  - `'the server registry holds the same rows'`: read `functions/src/domain/exercises.ts`; every match of `RegExp(r"\{id: '(\w+)', kind: '(\w+)', premium: (true|false), game: (true|false)\}")` as a tuple equals `[for (final s in Exercises.all) (s.id.name, s.kind.name, s.premium, s.game != null)]`; `EXERCISE_KINDS` and `EXERCISE_SOURCES` (read like `REACTION_EMOJI` in `test/domain/post_quality_test.dart:237-249`) equal the Dart enum names in order.
- [ ] **Step 2:** `flutter test test/domain/exercises_test.dart` → FAIL (file not found).
- [ ] **Step 3:** Write K1. `Exercises.all` is a `const` list in the row order above.
- [ ] **Step 4: Write `functions/test/exercises.test.ts`:** `EXERCISE_IDS` equals `['breathing','orbs','tiles','blocks','sos']`; `EXERCISES[0].premium === false`; `exerciseById('orbs')?.kind === 'focus'`; `exerciseById('nope')`, `exerciseById(7)`, `exerciseById(null)` are null; every id has a non-empty `EXERCISE_LABELS` entry.
- [ ] **Step 5:** Write K2. Run `npx vitest run test/exercises.test.ts` (in `functions/`) and `flutter test test/domain/exercises_test.dart` → PASS.
- [ ] **Step 6:** Make the `coach_screen.dart` change. `flutter test test/widgets/panic_session_test.dart test/widgets/premium_gate_test.dart` → PASS (the cap door's 20-minute rule is unchanged).
- [ ] **Step 7:** `flutter analyze` and `npm run typecheck` clean. List the files.

### Task 0.2: The wire types — blocks on the reply, extras on the request, the run store

**Files:**
- Create: `lib/domain/models/coach_ui.dart`, `lib/data/stores/exercise_runs.dart`, `test/data/exercise_runs_test.dart`
- Modify: `lib/domain/models/models.dart` (`CoachReply`, `CoachMessage.ember`), `lib/domain/repositories/repositories.dart` (`CoachRepository.streamReply`, `PanicRepository.survived`), `lib/data/dto/coach_codec.dart`, `test/data/dto_roundtrip_test.dart`
- Modify (signature line only): every class found by `grep -rn "implements CoachRepository\|implements PanicRepository" lib test integration_test`

**Interfaces:** Produces K3 (the Dart half), K4, K5.

- [ ] **Step 1: Failing codec tests** in the `CoachReplyCodec` group of `test/data/dto_roundtrip_test.dart`:
  - `"a reply's cards survive the round trip"`: `CoachReply(template: generic1, blocks: [CoachLauncherBlock(ExerciseId.orbs), CoachLauncherBlock(ExerciseId.sos)])` encodes with `'ui': {'v': 1, 'blocks': [{'t': 'launcher', 'exercise': 'orbs'}, {'t': 'launcher', 'exercise': 'sos'}]}` and decodes equal.
  - `'a backend that sends no cards decodes to none'`: no `ui` key → `blocks` empty, and `encode` writes no `ui` key.
  - `'a card this build cannot draw is skipped, the rest kept'`: `'ui': {'v': 9, 'blocks': [{'t': 'hologram'}, {'t': 'launcher', 'exercise': 'teleport'}, 7, null, {'t': 'launcher', 'exercise': 'orbs'}]}` → `[CoachLauncherBlock(ExerciseId.orbs)]`.
  - `'a malformed ui is no cards, never an error'`: `'ui': 'x'`, `'ui': []`, `'ui': {'blocks': 'x'}` → empty.
  - `'at most four cards'`: six launcher blocks → the first four.
- [ ] **Step 2: Failing extras and run-store tests** in `test/data/exercise_runs_test.dart`:
  - `CoachTurnExtras().toJson()` is `{}`; with `ui: CoachUiCaps(exercises: ['orbs'], craving: true)` it is `{'ui': {'v': 1, 'exercises': ['orbs'], 'craving': true}}`; with `justDid: ExerciseRun(id: orbs, source: coach, seconds: 61, completed: true, passed: false)` it is `{'justDid': {'exercise': 'orbs', 'seconds': 61, 'completed': true, 'passed': false}}`.
  - `'a run is handed over once'`: `report(run)` at `now`; `peekRecent(source: coach, now: now + 5min)` returns it twice; `takeRecent(...)` returns it once, then null.
  - `'a run from somewhere else, or an old one, is not handed over'`: source `panic` → null for `coach`; `now + 20min` → null.
  - `'reporting a run fires exercise_finished'` (uses `RecordingAnalytics`; the event method lands in Task 0.3, so write this assertion there).
- [ ] **Step 3:** Run both → FAIL.
- [ ] **Step 4:** Implement. The codec decodes tolerantly as the tests state. `ExerciseRuns` reads the clock from `nowProvider` and analytics from `analyticsProvider`. Add `CoachTurnExtras? extras` and the new `survived` parameters to every implementer's signature; bodies ignore them for now (lanes X and U wire them).
- [ ] **Step 5:** `flutter test test/data/dto_roundtrip_test.dart test/data/exercise_runs_test.dart` → PASS; `flutter analyze` clean (it is what finds an implementer that was missed). List the files.

### Task 0.3: The events

**Files:** Modify `lib/domain/analytics/lp_events.dart`, `test/analytics_test.dart`, `test/data/exercise_runs_test.dart`

**Interfaces:** Produces, on `extension LpEvents`:
```dart
void coachUiShown({required int launchers, required bool panic, required int planDay});
void coachUiDropped();
void exerciseOpened(ExerciseId exercise, ExerciseSource source);
void exerciseFinished(ExerciseRun run);
void cravingSurvived({required bool survived, GameId? game, int rounds = 0, int? intensity,
                      int? intensityAfter, ExerciseId? exercise, ExerciseSource? source});
```

- [ ] **Step 1:** In `test/analytics_test.dart`, add the four new calls to the cascade in `'every event fires under its docs/02 §7 name'` and their names to the expected list, in order; assert `propsOf('exercise_finished') == {'exercise': 'orbs', 'source': 'coach', 'completed': 'true', 'passed': 'false', 'seconds': 61}` and `propsOf('coach_ui_shown') == {'launchers': 3, 'panic': 'false', 'plan_day': 12}`. Add the `exercise_finished` assertion to the run-store test.
- [ ] **Step 2:** Run → FAIL. Implement K7. Run → PASS, including `'names and keys are snake_case and within Firebase limits'`.
- [ ] **Step 3:** `flutter analyze` clean. List the files.

### Task 0.4: The four strings, in six languages

**Files:** Modify `lib/l10n/app_{en,de,es,fr,it,pt}.arb`; regenerate `lib/l10n/gen/**`

- [ ] **Step 1:** Add the four K9 keys to all six files through a JSON round trip (temp file, `os.replace`). `exerciseGameSub` declares `seconds` as `int` in `app_en.arb`.
- [ ] **Step 2:** `flutter gen-l10n`.
- [ ] **Step 3:** `flutter test test/l10n_parity_test.dart test/copy_honesty_test.dart test/brand_name_test.dart` → PASS. List the files.

### Task 0.5: The fixtures

**Files:** Create `functions/test/fixtures/coach_ui/*.json` (the 13 files of K6) and `README.md` beside them; create `test/fixtures/coach_ui_fixtures_test.dart`

- [ ] **Step 1: Write the failing Dart test:** the folder holds exactly the 13 names in K6; each file decodes to a map with `input` and `blocks`; every block is `{'t': 'launcher', 'exercise': <an ExerciseId name>}`; no file has more than four blocks; `CoachReplyCodec.decode({'template': 'generic1', 'ui': {'v': 1, 'blocks': blocks}}).blocks.length == blocks.length`.
- [ ] **Step 2:** Run → FAIL. Write the 13 files exactly as the K6 table says, every `input` carrying all six `PlanInput` fields.
- [ ] **Step 3:** Run → PASS. Full `flutter test` and, in `functions/`, `npm run verify` → green. **Stage 0 is done; the lanes may start.**

---

# LANE X — THE EXERCISE PLATFORM (app)

### Task X1: `ExerciseCatalog`, the one launch call, and the card

**Files:**
- Create: `lib/features/exercises/exercise_catalog.dart`, `lib/features/exercises/exercise_launcher_card.dart`, `test/features/exercise_catalog_test.dart`, `test/widgets/exercise_launcher_card_test.dart`
- Modify: `lib/app/router/app_router.dart` (the `Routes` members of K9), `lib/features/panic/games/game_catalog.dart` (`GameEntry.premium`)

**Interfaces:**
- Consumes: K1, K7, K9; `isPremiumProvider`, `analyticsProvider`.
- Produces:
  ```dart
  class ExerciseEntry {
    const ExerciseEntry({required this.id, required this.icon, required this.title,
                         required this.subtitle, required this.route, this.screen});
    final ExerciseId id; final IconData icon;
    final String Function(AppLocalizations l10n) title;
    final String Function(AppLocalizations l10n) subtitle;
    final String Function(ExerciseSource source) route;
    final Widget Function(ExerciseSource source)? screen;   // set for scaffold-hosted exercises (X4)
  }
  abstract final class ExerciseCatalog {
    static const List<ExerciseEntry> entries;                // registry order
    static ExerciseEntry of(ExerciseId id);
    static void launch(BuildContext context, ExerciseId id, {required ExerciseSource source});
  }
  class ExerciseLauncherCard extends ConsumerWidget {
    const ExerciseLauncherCard({super.key, required this.id, required this.source});
  }
  ```
- Entries: `breathing` — `Icons.air_rounded`, `exerciseBreathingTitle`, `panicBreathePattern`, `Routes.exerciseFor`; `orbs` / `tiles` / `blocks` — `Icons.bubble_chart_rounded` / `Icons.grid_view_rounded` / `Icons.view_column_rounded`, `gameName…`, `exerciseGameSub(GameSession.roundSeconds)`, `Routes.gameFor(game, source: source)`; `sos` — `Icons.sos_rounded`, `panicLoopSos`, `panicLoopSosSub`, `'${Routes.compose}?tag=${PostTag.sos.name}'`.

- [ ] **Step 1: Failing catalog tests:**
  - `'every exercise has exactly one entry, in registry order'`: `[for (final e in ExerciseCatalog.entries) e.id] == [for (final s in Exercises.all) s.id]`.
  - `'every entry has words in every language'`: for each of `AppLocalizations.supportedLocales` (through `lookupAppLocalizations`), each entry's `title` and `subtitle` are non-empty.
  - `'routes are the catalog's, and sit where the gates already are'`: `of(breathing).route(ExerciseSource.coach) == '/panic/exercise/breathing?src=coach'`; `of(orbs).route(ExerciseSource.coach) == '/panic/game?g=orbs&src=coach'`; `of(sos).route(ExerciseSource.coach) == '/community/compose?tag=sos'`; the first two start with `Routes.panic`.
  - `'a game is premium because its exercise is'`: for every `GameCatalog.entries` e, `e.premium == Exercises.of(Exercises.forGame(e.id)!).premium`.
- [ ] **Step 2: Failing card tests** (pump `LastPuffApp` with a seeded journey, as `test/app/material_ui_test.dart` does):
  - `'the card says what it opens'`: `ExerciseLauncherCard(id: orbs, source: coach)` shows `gameNameOrbs`.
  - `'a locked exercise is shown and opened as the free one of its kind'` (`premium: false`): a card for `tiles` shows `gameNameOrbs`, not `gameNameTiles`; a tap lands on the arena playing Orbs; `analytics.propsOf('exercise_opened') == {'exercise': 'orbs', 'source': 'coach'}`; no route in the stack starts with `Routes.paywall`.
  - `'a subscriber gets what the card names'` (default premium): the same card shows and opens Tiles.
  - `'the folder sells nothing'`: no file under `lib/features/exercises/` contains `paywall`.
- [ ] **Step 3:** Run → FAIL. Implement. `launch` reads `ProviderScope.containerOf(context, listen: false)`, resolves with `Exercises.resolveFor`, reports, then `context.push`. The card is the look of the loop screen's `option` (`panic_screens.dart:690-730`): `LpCard`, a tinted icon tile, title, subtitle, chevron, inside `PressScale`, with `Semantics(button: true)`. `GameEntry.premium` becomes a getter over `Exercises`.
- [ ] **Step 4:** `flutter test test/features/exercise_catalog_test.dart test/widgets/exercise_launcher_card_test.dart test/widgets/game_arena_test.dart test/widgets/premium_gate_test.dart` → PASS. `flutter analyze` clean. List the files.

### Task X2: A craving handed to the coach continues, and every session closes

**Files:** Modify `lib/features/panic/panic_screens.dart` (`PanicViewModel`, the coach door at `:826`), `lib/features/panic/game_arena_screen.dart`, `test/widgets/panic_session_test.dart`, `test/widgets/game_arena_test.dart`

**Interfaces:**
- Produces, on `PanicViewModel`:
  ```dart
  void park();              // the caller is leaving but the craving is not over. No-op when idle or resolved.
  bool ensureStarted();     // true: the caller now owns the session (joined a parked one inside
                            // CravingWindow, or opened a new one). false: a mounted flow owns it.
  void start();             // the FLOW's entry: always a new, flow-owned craving; first reports a
                            // parked, unresolved one as not survived.
  void abandon();           // no-op while parked.
  ```
- The coach door becomes `vm.park(); context.go(…)`.
- Rule for owners (the arena here, `ExerciseScaffold` in X4): `initState` post-frame `_owns = _session.ensureStarted()`; `dispose` → `if (_owns) _session.park()`.
- `park()` and `abandon()` touch plain fields only, never `state`: they run from `dispose`, where a provider write throws.

- [ ] **Step 1: Failing tests** (`_StubPanic` counts `begin()` calls; `RecordingAnalytics`):
  - `'the coach door parks the craving, it does not abandon it'`: flow at step 2, strength set to 8, tap the coach option → zero `craving_outcome` events; `panicProvider` still has `intensity == 8` and its `startedAt`.
  - `'a card inside the window joins the same craving'`: then push `Routes.gameFor(GameId.orbs, source: ExerciseSource.coach)` → `begin` count still 1; `startedAt` unchanged; "It passed" reports ONE `craving_outcome` with `survived: 'true'` and `intensity: 8`.
  - `'leaving the arena parks it again'`: join, pop the arena → zero `craving_outcome`; a second arena push still shows `begin` count 1.
  - `'after the window, a card opens a new craving and the old one is closed'`: park, advance the clock 21 minutes, push the arena → `begin` count 2; exactly one `craving_outcome` with `survived: 'false'` for the old one.
  - `'a new SOS press is a new craving'`: park, open `/panic` → `begin` count 2, clock at zero, one `survived: 'false'`.
  - `'an arena opened with no flow beneath closes behind itself'`: push the arena cold, pop → the session is parked, and the next `start()` reports it once.
  - `'inside the flow the arena owns nothing'`: the existing chevron case still reports abandon exactly once, from the flow.
- [ ] **Step 2:** Run → FAIL. Implement. The view model tracks `_flowOwned` and `DateTime? _parkedAt`; all reset in `_reset()`.
- [ ] **Step 3:** `flutter test test/widgets/panic_session_test.dart test/widgets/game_arena_test.dart test/widgets/screen_view_test.dart` → PASS; `flutter analyze` clean. List the files, and note for P3: `craving_outcome{survived: false}` no longer fires when the coach door is taken.

### Task X3: A strength nobody gave is never reported

**Files:** Modify `lib/features/panic/panic_screens.dart`, `lib/features/panic/game_arena_screen.dart`, `lib/data/repositories/firebase_panic_repository.dart`; tests in `test/widgets/panic_session_test.dart`, `test/widgets/game_arena_test.dart`

**Interfaces:** `PanicViewModel` gains `int? get ratedIntensity` — `state.intensity` once the why step has been reached (`state.step >= 1`), else null. `survive` and `abandon` report `ratedIntensity`; the arena's `GameOutcome.intensityBefore` reads it.

- [ ] **Step 1: Failing tests:**
  - `'a craving that never saw the slider reports no strength'`: arena opened cold, "It passed" → `_StubPanic` received `intensity: null`; `craving_outcome` has no `intensity` key; the Survived screen shows no "you said" line.
  - `'a craving from the flow reports the strength on the slider'`: reach step 1, leave the slider at its default, "It passed" → `intensity: 7` (the slider was on screen; unchanged behaviour).
  - `'the payload omits a strength nobody gave'`: `FirebasePanicRepository.survived` builds a map with no `intensity` key when it is null (assert through an injected `LpFunctions` double, or extract the payload builder as a static and test that).
- [ ] **Step 2:** Run → FAIL. Implement. Run → PASS. `flutter analyze` clean. List the files.

### Task X4: `ExerciseScaffold`, and breathing as an exercise of its own

**Files:**
- Create: `lib/features/exercises/exercise_scaffold.dart`, `lib/features/exercises/breathing_exercise.dart`, `test/widgets/exercise_scaffold_test.dart`
- Modify: `lib/app/router/app_router.dart` (one route), `lib/features/exercises/exercise_catalog.dart` (`breathing.screen`)

**Interfaces:**
- Consumes: X2's ownership rule, `exerciseRunsProvider`, `IntensityRow` (`lib/features/panic/games/intensity_row.dart`), `BreathRing`, `BreathPacer`.
- Produces:
  ```dart
  class ExerciseScaffold extends ConsumerStatefulWidget {
    const ExerciseScaffold({super.key, required this.id, required this.source,
                            required this.body, this.completedAfter = const Duration(seconds: 57)});
    final ExerciseId id; final ExerciseSource source; final Widget body; final Duration completedAfter;
  }
  class BreathingExercise extends StatefulWidget { const BreathingExercise({super.key}); }
  ```
  Route: `GoRoute(path: '${Routes.exerciseBase}/:id')`, a `CustomTransitionPage(key: state.pageKey, name: state.path, …)` whose child is `ExerciseScaffold(id, source, body: ExerciseCatalog.of(id).screen!(source))`; an unknown id or an entry with no `screen` builds `RouteNotFoundScreen`.
- The scaffold draws: `BackChevron` (pop), the entry's title, `body`, `IntensityRow(label: l10n.gameIntensityNow, …)`, `LpTextButton(l10n.panicItPassed, …)`.
- "It passed": `context.pushReplacement('${Routes.survived}?src=${source.name}')`, then `survive(intensityAfter:, exercise: id, source: source)`, then `report(ExerciseRun(passed: true, …))`. Back: pop; a run not yet filed is filed from `dispose` with `passed: false`, through `scheduleMicrotask` on the notifier captured in `initState` (a provider write inside `dispose` throws). `completed` is `elapsed >= completedAfter` (57 s is three 4-7-8 breaths). Elapsed time reads `nowProvider`.

- [ ] **Step 1: Failing tests** (pump the app, push `Routes.exerciseFor(ExerciseId.breathing, ExerciseSource.coach)`):
  - `'breathing opens on its own'`: `BreathRing` is on screen with `panicBreatheInstruction`; `analytics.screens` contains `'/panic/exercise/:id'` and nothing with a `?`.
  - `'back leaves, counts nothing, and files the run'`: pop → previous screen; `cravingsSurvivedTotal` unchanged; `exercise_finished` is `{exercise: breathing, source: coach, completed: 'false', passed: 'false', seconds: 0}`; the session is parked.
  - `'it passed counts the craving once and files the run'`: advance the injected clock 60 s, set the row to 3, tap "It passed" → the Survived screen; `cravingsSurvivedTotal` +1; one `craving_outcome` with `survived: 'true'`, `exercise: 'breathing'`, `source: 'coach'` and the after-rating 3 (under the key `cravingSurvived` already uses for it); `exercise_finished` has `completed: 'true'`, `passed: 'true'`, `seconds: 60`.
  - `'an id with no screen is the not-found page'`: `/panic/exercise/orbs` and `/panic/exercise/nope` build `RouteNotFoundScreen`.
  - `'the scaffold lays out under a tight viewport'`: add `ExerciseScaffold(id: breathing, source: coach, body: BreathingExercise())` to the screen list in `test/widgets/screen_layout_test.dart`.
- [ ] **Step 2:** Run → FAIL. Implement. `BreathingExercise` is a ring on a repeating controller with the phase label under it (`_BreatheStep` at `panic_screens.dart:383-531` is the model; do not edit it).
- [ ] **Step 3:** Run the new tests plus `test/widgets/screen_layout_test.dart test/widgets/screen_view_test.dart test/widgets/breathe_ring_test.dart` → PASS. `flutter analyze` clean. List the files.

### Task X5: The craving report says what was used, and Survived goes back to where it began

**Files:** Modify `lib/features/panic/game_arena_screen.dart`, `lib/features/panic/panic_screens.dart` (`survive`, `SurvivedScreen`), `lib/data/repositories/firebase_panic_repository.dart`, `lib/app/router/app_router.dart` (the arena and Survived page builders read `src`); tests in `test/widgets/game_arena_test.dart`, `test/widgets/panic_session_test.dart`

**Interfaces:**
- `GameArenaScreen({super.key, this.initial, this.random, this.source = ExerciseSource.panic})`; `SurvivedScreen({super.key, this.game, this.source = ExerciseSource.panic})`.
- `survive({int? intensityAfter, ExerciseId? exercise, ExerciseSource? source})`: the arena passes `Exercises.forGame(game)` and its `source`; the flow's own two "It passed" buttons pass `source: ExerciseSource.panic` and no exercise.
- `FirebasePanicRepository.survived` adds `'exercise': ?exercise?.name, 'source': ?source?.name`.
- The arena files an `ExerciseRun` when it is left: `seconds: _run.sessionSeconds`, `completed: _run.roundsDone >= 1`, `score`, `passed`. From `_itPassed` it is filed directly; from `dispose`, through `scheduleMicrotask` on the captured notifier, as in X4.

- [ ] **Step 1: Failing tests:**
  - `'the report names the exercise and where it began'`: arena from the coach, "It passed" → `_StubPanic` received `exercise: ExerciseId.orbs`, `source: ExerciseSource.coach`, `game: GameId.orbs`.
  - `'a craving that began in the chat ends back in the chat'`: on Survived, the button reads `survivedBackChat`; tapping it lands on `/coach`.
  - `'a craving from the flow still ends on Home'`: unchanged copy (`survivedBack`) and destination.
  - `'the arena files its run'`: one finished round then back → `exercise_finished` with `exercise: 'orbs'`, `completed: 'true'`, `passed: 'false'`.
  - The push ask and the rating card on Survived behave as before: `test/widgets/survived_review_ask_test.dart` and `test/widgets/push_ask_test.dart` stay green untouched.
- [ ] **Step 2:** Run → FAIL. Implement. Run → PASS, plus `flutter test test/widgets test/review_ask_placement_test.dart`. `flutter analyze` clean. **Lane X done:** full `flutter test`. List the files.

---

# LANE U — THE COACH SURFACE (app)

### Task U1: The dependency, its seam, and the go/no-go build

**Files:** Modify `pubspec.yaml`, `pubspec.lock`; create `test/app/a2ui_seam_test.dart`, `docs/superpowers/evidence/2026-11-25-coach-cards/README.md`

- [ ] **Step 1: Measure before.** Before adding the dependency: `flutter build apk --release --target-platform android-arm64 --analyze-size`. Record the total in the evidence README. (This APK is for size only; it cannot pass App Check.)
- [ ] **Step 2: Failing seam test** (mechanism of `test/review_ask_placement_test.dart:55-66`):
  - `'a2ui stays in one folder'`: every `.dart` file under `lib/` containing `package:a2ui_` or `package:json_schema_builder` has a path starting `lib/features/coach/surface/`.
  - `'the a2ui packages are pinned exactly'`: `pubspec.yaml` matches `a2ui_flutter: 0.5.0`, `a2ui_core: 0.9.0` and `json_schema_builder: 0.1.7`, none preceded by `^`.
- [ ] **Step 3:** Add the three dependencies; `flutter pub get`. Run the seam test → PASS.
- [ ] **Step 4: Build both platforms.** Android: the Step 1 command. iOS: `flutter build ios --simulator --no-codesign -d <simulator id>` (a device id is mandatory with the watch companion; the first SPM resolution can take 20 minutes). Then `git status ios` and list what the build rewrote.
- [ ] **Step 5: The gate.** Record both results and the size difference. **If either platform fails to build, stop the lane and report to the founder with the log.** If both build, report the size number and continue; the founder may still veto on size.
- [ ] **Step 6:** Full `flutter test` → green (nothing imports the packages yet). List the files.

### Task U2: Blocks to A2UI, the catalog, and one processor for the thread

**Files:**
- Create: `lib/features/coach/surface/coach_catalog.dart`, `lib/features/coach/surface/coach_surface.dart`, `test/widgets/coach_surface_test.dart`

**Interfaces:**
- Consumes: K4, `ExerciseLauncherCard` (X1), the fixtures.
- Produces (in `coach_surface.dart`; this file exports no a2ui type):
  ```dart
  class CoachSurfaceController {
    CoachSurfaceController({required void Function(int launchers) onShown,
                            required void Function() onDropped});
    void show(String messageId, List<CoachBlock> blocks);   // replaces what was shown; no-op for the same id
    void clear();
    void dispose();
  }
  class CoachSurfaceView extends StatelessWidget {
    const CoachSurfaceView({super.key, required this.controller, required this.source});
    final CoachSurfaceController controller; final ExerciseSource source;
  }
  ```
- `coach_catalog.dart`: `CatalogImplementation coachCatalog()` — id `https://cirrusquit.com/a2ui/coach/v1/catalog.json`, `protocolVersion: A2uiProtocolVersion.v1_0`, two components, each `additionalProperties: false`: `CoachStack {children}` (a plain `Column`, 8 px between children, **not** `BasicComponents.column`) and `ExerciseLauncher {exercise: enum of every ExerciseId name}` (builds `ExerciseLauncherCard`); and `List<Map<String, Object?>> coachUiMessages(String surfaceId, List<CoachBlock> blocks)` — one v1.0 `createSurface` with root `CoachStack` and children `c0…cN`.
- The controller owns one `MessageProcessor<ComponentImplementation>(catalogs: [coachCatalog()], validationConfig: ValidationConfig.strict)` for its lifetime. `show` deletes the previous surface, processes the new messages inside `try … on A2uiError`, and subscribes to the surface's `onError`; a refusal or an error clears the view and calls `onDropped` once. The view is 82% of the screen width, like the week card (`coach_screen.dart:847`).

- [ ] **Step 1: Failing tests** (a `material_ui` `MaterialApp` with the app's theme, the bridge and `lpLocalizationsDelegates`, inside a `ProviderScope` with `fastBackendOverrides()`):
  - `'every fixture the server can send draws its cards'`: for each K6 file with blocks, `show('m1', decoded blocks)` then pump → one `ExerciseLauncherCard` per block, in order; `tester.takeException()` is null; `onShown` called once with the count.
  - `'the same message is shown once'`: `show('m1', …)` twice → `onShown` once.
  - `'a newer reply replaces the older one's cards'`: `show('m1', [breathing])`, `show('m2', [orbs])` → only the Orbs card.
  - `'no blocks is nothing at all'`: `show('m3', [])` → zero cards, zero size, neither callback.
  - `'a surface the package refuses leaves nothing behind'`: feed the processor a hand-written message with `"exercise": "teleport"` through a `@visibleForTesting` `showRaw` → nothing renders, `takeException()` null, `onDropped` once.
  - `'cards sit under an intrinsic-height parent without throwing'`: the view inside `IntrinsicHeight` → no exception (the reason `CoachStack` is not a `LayoutBuilder`).
  - `'disposing leaves no timers'`: dispose the controller inside the test body; the test ends clean.
  - `'the catalog is small and ours'`: `coachCatalog().toJson()` names exactly `CoachStack` and `ExerciseLauncher`; `jsonEncode` of it is under 3,000 characters.
- [ ] **Step 2:** Run → FAIL. Implement. Run → PASS, plus `test/app/a2ui_seam_test.dart`. `flutter analyze` clean. List the files.

### Task U3: The newest reply shows its cards, and the app says what it can draw

**Files:** Modify `lib/data/stores/coach_store.dart`, `lib/data/repositories/firebase_coach_repository.dart`, `lib/data/repositories/api_coach_repository.dart`, `lib/features/coach/coach_screen.dart`; create `test/widgets/coach_cards_test.dart`; extend `test/data/coach_streaming_test.dart`

**Interfaces:**
- `CoachStore.send(String text, {int? panicIntensity, bool craving = false})` and `sendChip(CoachChip chip, {int? panicIntensity, bool craving = false})`.
- The store builds `CoachTurnExtras(ui: CoachUiCaps(exercises: [for (final s in Exercises.all) s.id.name], craving: craving))`, with `ui: null` while `ref.read(day1TourStepProvider) != null`. It copies `done.blocks` onto the Ember message.
- Both repositories spread `extras?.toJson()` into the request. `ApiCoachRepository` also forwards `panicIntensity` (it drops it today, `api_coach_repository.dart:24-28`).
- The screen: one `CoachSurfaceController` created in `initState`, disposed in `dispose`; `ref.listen(coachStoreProvider, …)` calls `show(newest.id, newest.blocks)` when the last message is Ember's and `clear()` otherwise; under that last bubble, `CoachSurfaceView(controller, source: ExerciseSource.coach)`. `craving` is a NEW `_cravingContext(now)`: `_inCraving(now)`, or `CravingWindow.covers(_cravingChipAt, now)` where `_cravingChipAt` is stamped AFTER the craving chip's own send (so that turn still gets the menu). **`_inCraving` itself does not change**: it decides whether the cap's upgrade button shows, and that rule stays as it is. `onShown` fires `coach_ui_shown` with `panic: _cravingContext(now)` and the plan day; `onDropped` fires `coach_ui_dropped`.

- [ ] **Step 1: Failing store tests** (a scripted repository that records `extras`):
  - `'the app says which exercises it can open'`: any send → `extras.ui.exercises` equals the five names; `craving` false.
  - `'no cards are asked for during the Day-1 coach step'`: with the tour on `meetCoach`, `extras.ui` is null.
  - `"a reply's cards land on its message"`: a `CoachDone` whose reply has two blocks → the last message's `blocks` equal them.
  - `'the wire carries the extras'`: the map `FirebaseCoachRepository` hands `LpFunctions` contains `ui` (extract the payload builder as a static to assert it).
- [ ] **Step 2: Failing widget tests** (`coachRepositoryProvider` overridden through `extra:` with a repository that answers a given reply):
  - `'a card under the reply opens the exercise, and back returns to the chat'`: reply with `[breathing, orbs, sos]` → three cards under the bubble; tap the breathing card → `BreathRing`; back → the thread and its cards; `exercise_opened` is `{exercise: breathing, source: coach}`; `coach_ui_shown` is `{launchers: 3, panic: 'false', plan_day: <the seeded day>}`.
  - `'only the newest reply keeps its cards'`: send again, the next reply has none → zero cards on screen.
  - `'a reply with no cards is today's thread'`: no `ui` → no `CoachSurfaceView` content, the four static chips, no `coach_ui_shown`.
  - `'after the craving chip, the next message says it is still a craving'`: send the craving chip (its `extras.ui.craving` is false), then a typed message → `craving` true; 21 minutes later → false.
  - `'arriving from the panic flow says so from the first message'`: `CoachScreen(panicIntensity: 8)` → the first send has `craving: true`.
  - `'a restored thread has no cards'`: history only → none.
  - `'the Day-1 coach step draws no card even if one arrives'`: tour on `meetCoach`, a reply with blocks → none drawn.
- [ ] **Step 3:** Run → FAIL. Implement. Run → PASS, plus `flutter test test/widgets/coach_reply_test.dart test/widgets/coach_retry_test.dart test/widgets/coach_week_card_test.dart test/widgets/day1_tour_send_test.dart test/widgets/panic_session_test.dart test/widgets/screen_layout_test.dart`. `flutter analyze` clean. List the files.

### Task U4: Ember is told what they just did

**Files:** Modify `lib/data/stores/coach_store.dart`, `lib/features/coach/coach_screen.dart`; extend `test/widgets/coach_cards_test.dart`, `test/data/coach_streaming_test.dart`

**Interfaces:** The store adds `justDid: ref.read(exerciseRunsProvider.notifier).takeRecent(source: ExerciseSource.coach, now: now)` to the extras of the next send (once). While `peekRecent` returns a run with `passed == false`, the chip row leads with two chips that prefill the composer: `panicItPassed` and `coachAfterStill`.

- [ ] **Step 1: Failing tests:**
  - `'the next message carries what they just did, once'`: report a coach run, send → `extras.justDid` is that run; send again → null.
  - `'a run from the panic flow is not the chat's to report'`: source `panic` → null.
  - `'back from an exercise, two replies lead the chips'`: after a coach run with `passed: false`, the row's first two chips are `panicItPassed` and `coachAfterStill`; tapping one fills the composer and sends nothing.
  - `'a craving already marked passed asks nothing more'`: `passed: true` → the ordinary chips; the next send still carries `justDid`.
- [ ] **Step 2:** Run → FAIL. Implement. Run → PASS. `flutter analyze` clean. List the files.

### Task U5: The fake backend answers with the server's own cards

**Files:** Create `lib/data/api/fake/fake_coach_ui.dart`; modify `lib/data/api/fake/fake_coach_api.dart`; create `test/data/fake_coach_ui_test.dart`

**Interfaces:** `fake_coach_ui.dart` holds `const Map<String, List<Map<String, String>>> fakeCoachUi` — the `blocks` of the K6 fixtures `panic_default` and `craving_chip` copied as const data — and `List<Map<String, String>> fakeBlocksFor({required Map<String, dynamic> request, required String? tier})`: nothing without `request['ui']` or when `tier` is neither `premium` nor `trial`; `panic_default` when `panicIntensity` is set or `ui.craving` is true; `craving_chip` for the craving chip; nothing otherwise; always filtered to the advertised ids. `FakeCoachApi` reads the tier from `FakeServer.entitlementForSession()` and adds `'ui': {'v': 1, 'blocks': …}` when the list is not empty.

- [ ] **Step 1: Failing tests:**
  - `'the fake's cards are the server's'`: each const entry equals the `blocks` of its fixture file, read from `functions/test/fixtures/coach_ui/`.
  - `'a subscriber who taps the craving chip gets the menu'` (through `FakeCoachApi` with the seeded premium account): the reply decodes to `[breathing, orbs, sos]`.
  - `'a free account gets none'` (`premium: false`), `'an app that advertises nothing gets none'`, `'a craving in progress gets one'`.
  - `'the fake never offers what was not advertised'`: `ui.exercises == ['orbs']` + craving chip → the `narrow_client` fixture's blocks.
- [ ] **Step 2:** Run → FAIL. Implement. Run → PASS. **Lane U done:** full `flutter test`; `flutter analyze` clean. List the files.

---

# LANE S — THE SERVER

Run from `functions/`. The emulator suites need Java (`CLAUDE.md` "Testing" has the `JAVA_HOME` lines for Windows; on macOS use Android Studio's bundled `jbr` the same way).

### Task S1: `coachUi.ts` — what the app can draw, who may see it, which cards

**Files:** Create `src/ai/coachUi.ts`, `test/coachUi.test.ts`; modify `src/config.ts` (K8)

**Interfaces:**
```ts
export interface UiCapabilities { readonly exercises: readonly ExerciseId[]; readonly craving: boolean }
export type Block = {readonly t: 'launcher'; readonly exercise: ExerciseId};
export interface PlanInput {
  readonly audience: 'off' | 'premium' | 'all'; readonly tier: SubscriptionTier;
  readonly chip: CoachChip | null; readonly panicIntensity: number | null;
  readonly caps: UiCapabilities | null; readonly recentTools: readonly ExerciseId[];
}
export function parseUiCapabilities(raw: unknown): UiCapabilities | null;
export function coachUiAudience(raw: string): 'off' | 'premium' | 'all';
export function planBlocks(input: PlanInput): Block[];
export function uiEnvelope(blocks: readonly Block[]): {ui: {v: 1; blocks: readonly Block[]}} | Record<string, never>;
```

- [ ] **Step 1: Failing tests:**
  - `'every fixture'`: for each file in `test/fixtures/coach_ui/` (read with `readFileSync(resolve(__dirname, 'fixtures/coach_ui', name))`), `planBlocks(input)` deep-equals `blocks`. The test fails if the folder holds fewer than 13 files.
  - `parseUiCapabilities`: `undefined`, `null`, `'x'`, `[]`, `{exercises: 'x'}`, `{v: 1}` → null; `{v: 1, exercises: ['orbs', 'teleport', 7, 'orbs'], craving: 'yes'}` → `{exercises: ['orbs'], craving: false}`; `craving: true` → true; 40 ids → the first 32 known ones; a newer `v` with a valid list is still read.
  - `coachUiAudience`: `''`, `'premium'`, `'true'`, `'nonsense'` → `'premium'`; `'off'`, `' OFF '` → `'off'`; `'all'`, `'All'` → `'all'`.
  - `uiEnvelope([])` is `{}`; with one block it is `{ui: {v: 1, blocks: [...]}}`.
  - `'never more than one card in a craving, never more than three otherwise'`: property check over every combination of tier × audience × chip × panic (null, 8) × `craving` × three capability lists.
- [ ] **Step 2:** `npx vitest run test/coachUi.test.ts` → FAIL. Implement the six-step policy of K6. Run → PASS. `npm run typecheck && npm run lint` clean. List the files.

### Task S2: `aiCoachChat` attaches the cards

**Files:** Modify `src/handlers/aiCoachChat.ts`; extend `test/integration/aiCoachChat.test.ts`

**Interfaces:** `CoachReplyEnvelope` gains `ui?: {v: 1; blocks: readonly Block[]}`. The handler reads `parseUiCapabilities(data['ui'])` and `coachUiAudience(COACH_UI_AUDIENCE.value())` once, computes `planBlocks(...)` (with `recentTools: []` until S4), and spreads `uiEnvelope(blocks)` into the final envelope on BOTH the streaming and the unary path, and into the `capReached` and `connectionLost` envelopes (`:181`, `:317`, `:331`). Not into the no-journey `greeting`. Logs `coach.ui` with `{blocks: n, craving: boolean}` through `safeMeta`.

- [ ] **Step 1: Failing integration tests** (stub `COACH_UI_AUDIENCE` with `vi.spyOn(..., 'value')`, as the file does for the allowances):
  - `'a subscriber who taps the craving chip gets the menu'`: premium, `chip: 'craving'`, `ui` = all five → `envelope.ui` equals the `craving_chip` fixture's blocks.
  - `'a craving in progress gets one card'`: `panicIntensity: 8` → the `panic_default` blocks; `generate` was called once (no extra model call), and the follow-up suggester was not.
  - `'the same on a call that does not stream'`.
  - `'an app that says nothing about cards gets the old envelope'`: no `ui` in the request → the envelope's keys are exactly `template`, `args`, `showWeekCard`, `text`, `messagesLeft`, `tier` (plus `followUps` on a streamed turn that produced some).
  - `'a free account gets none'`; `'audience off gets none'`; `'audience all gives a free account only free exercises'`.
  - `'out of messages, the card still comes'`: claim past the cap with `chip: 'craving'` → `template: 'capReached'` and one or more blocks; `generate` not called.
  - `'the model is down, the card still comes'`: `generate` rejects with `ModelUnavailableError` → `connectionLost` with blocks.
  - `'a malformed ui never fails the turn'`: `ui: 'x'` → a normal reply, no `ui`.
- [ ] **Step 2:** `npm run test:integration` → the new cases FAIL. Implement. Run → PASS. `npm run verify` green. List the files.

### Task S3: `panicSession` validates against the registry

**Files:** Modify `src/handlers/panicSession.ts`, `test/panicSession.test.ts`, `test/integration/callables.test.ts`

**Interfaces:** `PANIC_GAMES` is `EXERCISES.filter((e) => e.game).map((e) => e.id)`. `cravingFields` also returns `exercise: ExerciseId | null` (`exerciseById`) and `source: ExerciseSource | null` (`asEnum` over `EXERCISE_SOURCES`). The write goes through `cravingsCol(uid)`.

- [ ] **Step 1: Failing tests:** `PANIC_GAMES` as a set equals `{orbs, tiles, blocks}` (the existing order pin at `test/panicSession.test.ts:42-43` becomes a set check); `cravingFields({exercise: 'breathing', source: 'coach'})` keeps both; `{exercise: 'teleport', source: 'email'}` → both null; a call with no `intensity` stores `intensity: null`; the integration case asserts the stored doc carries `exercise` and `source`.
- [ ] **Step 2:** Run → FAIL. Implement. `npm run verify` and `npm run test:integration` → PASS. **Deploy 1 is ready** (S1–S3): tell the founder; add `COACH_UI_AUDIENCE=premium` to `functions/.env.alastpuff` in the same change. List the files.

### Task S4: The craving digest, and five lines Ember can stand behind

**Files:** Create `src/ai/cravingDigest.ts`, `test/cravingDigest.test.ts`; modify `src/ai/memoryCard.ts`, `test/memoryCard.test.ts`, `src/handlers/aiCoachChat.ts`, `test/integration/aiCoachChat.test.ts`

**Interfaces:**
```ts
export interface CravingDoc { readonly startedAt: Date; readonly intensity: number | null;
  readonly intensityAfter: number | null; readonly exercise: string | null; readonly game: string | null }
export interface CravingDigest {
  readonly latest: {readonly dayKey: string; readonly weekday: string; readonly hour: number;
                    readonly tool: ExerciseId | null; readonly ratedLower: boolean} | null;
  readonly tools: readonly ExerciseId[];           // distinct, most recent first
}
export function digestCravings(docs: readonly CravingDoc[], timeZone: string): CravingDigest;
export function cravingLines(digest: CravingDigest): string[];
export interface JustDid { readonly exercise: ExerciseId; readonly seconds: number;
                           readonly completed: boolean; readonly passed: boolean }
export function parseJustDid(raw: unknown): JustDid | null;     // seconds clamped to 0..3600
export function justDidLine(j: JustDid): string;
// memoryCard.ts
export function buildMemoryCard(raw: unknown, now: Date, timeZone: string,
  extras?: {readonly cravings?: CravingDigest | null; readonly justDid?: JustDid | null}): MemoryCard;
```
Exact card text (a tool is `exercise ?? game`, named through `EXERCISE_LABELS`; `ratedLower` is true only when both ratings exist and `intensityAfter < intensity`):
```
craving log (cravings they marked as passed; a list, not a day count or the streak): latest on 2026-11-24 (Tuesday), about 21:00 their time
during that one they had open: the Orbs game · their own re-rating afterwards was lower
tools they have opened during a craving, most recent first: the Orbs game, the breathing exercise
right now is one of their danger hours
last puff: 2026-11-24 (Tuesday), about 21:00 their time
just before this message, in the app: they used the breathing exercise for about a minute and marked the craving as passed
```
- Lines 1–3 only when there is at least one craving doc; line 2 only when the latest has a tool, and its second clause only when `ratedLower`; line 3 only with two or more distinct tools.
- Line 4 only when the current local hour is in `dangerHours(window14)`. Line 5 only when `lastPuffAt` is set.
- Line 6 only with `justDid`: under 45 s "for less than a minute", 45–90 s "for about a minute", longer "for a few minutes"; the last clause only when `passed`.
- **None of the six on a panic turn** (`panicIntensity !== null`): the handler passes no extras to the card then. The digest still feeds `planBlocks` as `recentTools`.
- The handler reads `cravingsCol(uid).orderBy('startedAt', 'desc').limit(12)` only when `caps !== null` and the audience admits the tier, beside the journey read, inside `try/catch` that logs `coach.cravings_failed` and continues with no digest.

- [ ] **Step 1: Failing unit tests:**
  - Each line's presence rule above, one case each, asserting the exact strings.
  - `'no craving line carries a count'`: for ten digests of 1 to 12 docs, take lines 1–3 and 6, delete every `\d{4}-\d{2}-\d{2}` and every `\d{1,2}:00`, and assert no digit remains.
  - `digestCravings` orders by `startedAt`, skips unknown tool ids, and reads `game` when `exercise` is absent.
  - `parseJustDid` refuses unknown exercises and non-numbers, and clamps `seconds`.
  - `'the six lines are short'`: with every line present they add at most 560 characters to the card. If the existing 2,000-character guard (`memoryCard.test.ts:381-388`) then fails, **stop and report the measured length**; do not raise the guard.
- [ ] **Step 2: Failing integration tests:** a premium turn with three seeded craving docs → the system instruction passed to `generate` contains `craving log (` ; the same turn with `panicIntensity: 8` does not, and its block is the most recent tool; a free turn makes no `cravings` read; a `cravings` read that throws still answers.
- [ ] **Step 3:** Run → FAIL. Implement. `npm run verify` and `npm run test:integration` → PASS. **Do not deploy: S5 gates this.** List the files.

### Task S5: The eval sees the new lines, five rolls each way

**Files:** Modify `tools/evalFixtures.ts`, `tools/coachEval.ts`; create `docs/superpowers/evidence/2026-11-25-coach-cards/eval/`

**Interfaces:** `evalFixtures.ts` gains `evalCravings(): CravingDoc[]` (three docs: Orbs with a lower re-rating, breathing, Orbs) and `evalJustDid(): JustDid`. `Scenario` gains `justDid?: boolean`. `coachEval.ts` builds the card with the digest for every non-panic scenario and without it for panic ones (`:485` becomes per-scenario).

- [ ] **Step 1:** Add two scenarios: `23-what-helps` (input "what's actually helped me when it hits?"; must name the Orbs game; must not match a count of cravings or a rating out of ten) and `24-just-did` (`justDid: true`, input "ok I did it"; must acknowledge the breathing; must not claim a number). Keep 01–22 untouched, including their judge text.
- [ ] **Step 2: Write the pass bar in the evidence folder BEFORE running:** over five rolls, per model, the new card may not fail any of cases 04, 05, 15, 20, 21, 22 more often than the old card does; no reply states a craving count, a "before" rating, or a day other than the card's; cases 23 and 24 pass at least four of five.
- [ ] **Step 3: Ask the founder to go ahead** (about $0.15 a run, ten runs). Then follow `CLAUDE.md` "`npm run eval:coach` is one roll…": `git archive HEAD` for the old tree into a scratch copy, five full rolls of old and new side by side in separate working directories, checking each run for 429/503 so an infrastructure error is not counted as an answer.
- [ ] **Step 4:** Compare per-case failure counts. **Read every failing reply on 04, 05, 15, 20, 21, 22 and every reply to 23 and 24.** Save the JSON outputs and a one-page reading in the evidence folder. If the bar is missed, change the card wording, never a case's judge text, and re-roll.
- [ ] **Step 5:** `npm run verify` green. **Deploy 2 is ready** (S4–S5): hand the founder the reading. List the files.

---

# LANE P — PROOF AND DOCS

### Task P1: On a phone, on the fake backend

**Files:** Create `integration_test/u_coach_cards_test.dart`; add its row to `integration_test/README.md`

- [ ] **Step 1: Write the suite** (pattern: `integration_test/h_panic_games_test.dart`; the demo account `maya@quitmail.com` is a subscriber on the fake):
  - `'a card opens breathing and back returns to the chat'`: sign in, Coach tab, tap the craving chip, send → three cards hit-testable (`tester.binding.hitTest` at each centre); tap breathing → the ring; system back → the thread.
  - `'a game from the chat ends back in the chat'`: tap the Orbs card → a real round → "It passed" → Survived says `survivedBackChat` → the coach tab; `cravingsSurvivedTotal` rose by one.
  - `'a craving handed over continues'`: Home SOS → skip to the loop → note `e2e.container.read(panicProvider).startedAt` → the coach option → send a message → ONE card → tap it → `startedAt` is the value noted.
  - `'a free account sees none'`: an account with no subscription, set up the way `integration_test/i_monetisation_test.dart` does; say the craving chip → no card.
  - Print `E2E-MARKER: shot <name>` before each screenshot point and wait 2.5 s.
- [ ] **Step 2: Run on the Pixel:** `flutter test integration_test/u_coach_cards_test.dart -d <pixel> --dart-define=LP_BACKEND=fake`. Save the result line and screenshots under `docs/superpowers/evidence/2026-11-25-coach-cards/`.
- [ ] **Step 3: Run on an iPhone simulator** the same way. If the simulator build is blocked (the watchOS runtime, an Xcode licence), say exactly what blocked it and stop; do not download a runtime without asking.
- [ ] **Step 4:** Re-run `integration_test/h_panic_games_test.dart`, `j_craving_and_quiet_hours_test.dart`, `i_monetisation_test.dart`, `d_social_test.dart`, `g_day1_tour_test.dart` on the Pixel: lanes X and U touched what they cover. Report each by name.

### Task P2: On a phone, against the real backend (after the founder deploys S1–S3)

- [ ] **Step 1:** Needs an account whose `users/{uid}.entitlement` mirror is premium: the founder's own or a sandbox purchase. **Never write the mirror by hand.**
- [ ] **Step 2:** `flutter run -d <device> --dart-define=LP_BACKEND=firebase --dart-define-from-file=.dart_defines.json` (debug build; a sideloaded release build cannot pass App Check). Tap the craving chip → cards; open one; return.
- [ ] **Step 3:** `firebase functions:log --only aiCoachChat` shows `coach.ui` with `blocks: 3`. With a free account: the same turn logs `blocks: 0` and the thread is unchanged. Save both to the evidence folder.

### Task P3: The docs

**Files:** Modify `CLAUDE.md`, `docs/08_Sprint_Tracker.md`, `docs/10_Build_Log.md` (a new dated section), `docs/11_AI_Flow.md`, `docs/13_Feature_Map.md`

- [ ] **Step 1: `CLAUDE.md`:** in Architecture, a paragraph each for the exercise registry (the six-line "add an exercise" checklist, `entries.first` free) and coach cards (blocks on the wire, a2ui in one folder, pinned, newest reply only, audience param). In Gotchas: the park/join rule and who owns a session; "a strength nobody gave is never reported"; `craving_outcome{survived: false}` no longer fires at the coach door; `BasicComponents.column` is a `LayoutBuilder`; upgrading a2ui is its own task. Update the server barrel count if a callable was added (none is).
- [ ] **Step 2:** docs/11: the read path gains the cravings read and `planBlocks`; cost per turn is unchanged (no model call); one extra Firestore query on turns that can show cards. docs/13: rows for coach cards, the standalone breathing exercise, "Back to the chat", and how to test each by hand; the audience in "what free gets". docs/08 and docs/10: status and the dated history, citing the evidence folder.

### Task P4: What's New (when the founder bumps the version)

- [ ] **Step 1:** `test/whats_new_catalog_test.dart` fails until `WhatsNewCatalog` has an entry for the new version: three ARB keys `whatsNew<version>Item1..3`, six locales, ≤ 80 characters each, no health or quitting promise. Do this only once the version in `pubspec.yaml` has changed.

---

## Verification (end to end)

| What | Command | Passing looks like |
|---|---|---|
| App, static | `flutter analyze` | no issues |
| App, all tests | `flutter test` | all green; report failures by name |
| The contract | `flutter test test/domain/exercises_test.dart test/fixtures/coach_ui_fixtures_test.dart test/data/fake_coach_ui_test.dart test/widgets/coach_surface_test.dart` and `npx vitest run test/exercises.test.ts test/coachUi.test.ts` | the same 13 fixtures pass on both sides |
| Server gate | `cd functions && npm run verify` | typecheck, lint, vitest green |
| Server, emulator | `npm run test:integration` and `npm run test:rules` (needs Java) | green |
| Eval | S5's five-roll protocol | the written bar is met, failing replies read |
| Device, fake | P1 | four cases pass on the Pixel and the simulator; screenshots saved |
| Device, real | P2 | cards for a subscriber, none for a free account, `coach.ui` in the log |

## Founder to-dos

1. Read U1's build result and size number; say go or stop.
2. Commit as lanes land; deploy **S1–S3** with `COACH_UI_AUDIENCE=premium`; then release the app.
3. A premium account for P2.
4. Say yes to the S5 eval spend; read its one-page result; deploy **S4–S5**.
5. Later, when wanted: set `COACH_UI_AUDIENCE=all` to show cards to everyone (free accounts are offered free exercises only).

## Not in this plan (and why)

- **The founder's exercises** (Burst, Breathe, Surf, the new Blocks, Plan + Grow). This plan builds the registry, scaffold and launch call they use.
- **Cards the model picks, and progress cards in the chat.** A second model call per turn, and a client-drawn number beside server-written prose can disagree. The week card stays as it is.
- **Server-authored A2UI on the wire.** The door is a later `v` and a pass-through field, once the package settles or a surface needs data binding.
- **A card when the phone is offline**, **a session-free "practice" launch**, **cards restored with history**, **a paywall door for free accounts**.
- **The panic loop screen drawn from the registry.** Its three options and their copy stay hand-written for now.

## Known, and left alone

- `panicSession` counts two sessions per survived craving (`begin` and the outcome call).
- A parked craving that is never followed by another one in the same app session reports no `craving_outcome` at all.
- A strength left at the slider's default 7 inside the flow is still reported as given, because the slider was on screen.
