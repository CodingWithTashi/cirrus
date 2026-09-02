# CODING AGENTS: READ THIS FIRST

This is a **handoff bundle** from Claude Design (claude.ai/design).

A user mocked up designs in HTML/CSS/JS using an AI design tool, then exported this bundle so a coding agent can implement the designs for real.

## What you should do — IMPORTANT

**Read the design files in `project/` in full, in this order:** `LastPuff Run 1.dc.html` (frames 1–24, onboarding + paywall), `LastPuff Run 2.dc.html` (frames 25–38, auth + core app, Midnight Ember), `LastPuff Run 3.dc.html` (frames 39–52), then `LastPuff Run 2 Light.dc.html` (the Daylight Ember theme). Read each top to bottom — don't skim. Then **follow its imports**: open every file it pulls in (shared components, CSS, scripts) so you understand how the pieces fit together before you start implementing.

Per-frame implementation status, deliberate deviations and past fix rounds are tracked in `../HANDOFF_COMPLETION.md`.

**If anything is ambiguous, ask the user to confirm before you start implementing.** It's much cheaper to clarify scope up front than to build the wrong thing.

## About the design files

The design medium is **HTML/CSS/JS** — these are prototypes, not production code. Your job is to **recreate them pixel-perfectly** in whatever technology makes sense for the target codebase (React, Vue, native, whatever fits). Match the visual output; don't copy the prototype's internal structure unless it happens to fit.

**Don't render these files in a browser or take screenshots unless the user asks you to.** Everything you need — dimensions, colors, layout rules — is spelled out in the source. Read the HTML and CSS directly; a screenshot won't tell you anything they don't.

## Bundle contents

- `README.md` — this file
- `project/` — the Claude Design project files: the four `.dc.html` design files, `support.js`, `ios-frame.jsx`

The project was exported once per run. The four exports' `project/` folders were byte-identical (MD5-verified), so they were collapsed into this one bundle on Sep 2, 2026.
