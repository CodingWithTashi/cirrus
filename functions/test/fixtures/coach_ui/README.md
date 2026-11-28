# Coach-card fixtures

Eighteen files, each `{"input": PlanInput, "blocks": Block[]}`. They are the
contract between the server's card policy and the app (K6 in
`docs/superpowers/plans/2026-11-25-coach-cards.md`, plus the four added on
Nov 28 2026 for a card named by the reply, docs/10 §62), and both sides are
pinned to the same files:

- **Server:** `planBlocks(input)` must deep-equal `blocks` for every file
  (`test/coachUi.test.ts`).
- **App:** every `blocks` goes through `CoachReplyCodec` and the real card
  renderer, and the fake backend's cards are copies of two of these files
  (`test/fixtures/coach_ui_fixtures_test.dart` at the repo root, and the
  suites the app lanes add beside it).

Only `*.json` files in this folder are fixtures. The Dart suite fails if the
set of names changes, so adding or removing one is a change on both sides.

## The shapes

```ts
interface PlanInput {
  audience: 'off' | 'premium' | 'all';      // COACH_UI_AUDIENCE, already parsed
  tier: 'free' | 'trial' | 'premium';       // the server's own read of the tier
  chip: 'craving' | 'roughDay' | 'slipped' | 'progress' | null;
  panicIntensity: number | null;            // set when the turn came from the panic flow
  caps: {exercises: string[]; craving: boolean} | null;   // what the app said it can draw; null = said nothing
  recentTools: string[];                    // from the craving digest, most recent first
  suggested: string[];                      // what the follow-up call said the reply was about, best first
}
type Block = {t: 'launcher'; exercise: string};   // an id and nothing else
```

Every `input` carries all seven fields, so a file never depends on a default.

`suggested` is the one input a model produces: the follow-up call that
already writes Ember's chips also names the exercises the reply was about
(`followUpPrompt` in `src/ai/prompts.ts`). In these files it is a plain list
like any other. The app never sees it.

## The files

Unstated fields are: audience `premium`, tier `premium`, chip `null`,
panicIntensity `null`, caps all five exercises with `craving: false`, no
tools, nothing suggested.

| File | What differs | Cards |
|---|---|---|
| `panic_default` | panicIntensity 8 | `breathing` |
| `panic_recent` | panicIntensity 8, tools `[orbs]` | `orbs` |
| `craving_followup` | caps `craving: true`, tools `[orbs, breathing]` | `orbs` |
| `craving_suggested` | caps `craving: true`, tools `[breathing]`, suggested `[orbs]` | `orbs` |
| `craving_chip` | chip `craving` | `breathing`, `orbs`, `sos` |
| `craving_chip_recent` | chip `craving`, tools `[orbs, breathing]` | `orbs`, `breathing`, `sos` |
| `craving_chip_recent_tiles` | chip `craving`, tools `[tiles]` | `tiles`, `breathing`, `sos` |
| `trial_tier` | tier `trial`, chip `craving` | `breathing`, `orbs`, `sos` |
| `free_tier` | tier `free`, chip `craving` | none |
| `audience_all_free` | audience `all`, tier `free`, chip `craving`, tools `[tiles]` | `breathing`, `orbs`, `sos` |
| `audience_off` | audience `off`, chip `craving` | none |
| `old_client` | caps `null`, chip `craving` | none |
| `narrow_client` | caps exercises `[orbs]`, chip `craving` | `orbs` |
| `other_chip` | chip `progress` | none |
| `free_text` | nothing | none |
| `suggested_one` | suggested `[breathing]` | `breathing` |
| `suggested_several` | suggested `[orbs, tiles, sos, breathing]` | `breathing`, `orbs`, `sos` |
| `suggested_locked` | audience `all`, tier `free`, suggested `[tiles]` | `orbs` |

## The policy they encode

1. `available` is the registry rows whose id the app advertised, minus premium
   rows when the tier is `free`, in registry order.
2. No cards when the audience is `off`, when `caps` is `null`, when
   `available` is empty, or when the audience is `premium` and the tier is
   `free`.
3. `recent` is `recentTools` filtered to `available`.
4. `named` is `suggested`, in the order given: an id that is not in
   `available` becomes the first available row of its kind, or is dropped
   when there is none; one per kind; at most three. An id the registry does
   not hold is ignored.
5. In a craving (`panicIntensity` set, or `caps.craving`): exactly one card,
   `named[0]`, else `recent[0]`, else the first `calm` row in `available`,
   else `available[0]`.
6. Otherwise, on the `craving` chip: `recent[0]` if there is one, then the
   first available row of each kind in `EXERCISE_KINDS` order, **skipping the
   kind `recent[0]` already covers**, at most three. The skip is what keeps
   the SOS card when the latest tool is a second game (`tiles`, `blocks`):
   without it the menu is that game, breathing and Orbs, and nobody to ask
   (founder decision, Nov 25 2026; `craving_chip_recent_tiles` pins it).
   `suggested` does not change this menu.
7. Otherwise `named`, laid out in registry order (calm first, like the
   menu): the exercise the reply was about, or no cards when it was about
   none (founder decision, Nov 28 2026; `suggested_one` is the exchange that
   prompted it). The model says which exercises; the order is never its.

Change a fixture only together with the policy, and never to make one side
pass.
