# Day 2 and 3 mornings — design

Nov 21 2026. Option B from the day-1→day-2 investigation (docs/10 §58), approved by the founder as "go with B". Not committed; the founder commits.

## 1. Why

The founder's ask: fix the drop between day 1 and day 2 **properly, not nominally** — grounded in research and in Cirrus's own data, keeping only changes that mean something ("only meaningful ones, not assumption"), and proven on a real device (memory: *verify for real, not nominally*).

### What the data says (Amplitude, Nov 21; 99 real people who finished onboarding since Oct 17 and are at least 48 h old)

"Came back" = active 16–48 h after their first active hour (timezone-free; most of the cohort is in Europe).

| | Result | Meaningful? |
|---|---|---|
| Came back | 54% (53/99) | — |
| Taper vs cold turkey | 67% (36/54) vs 36% (16/44) | **yes** (z ≈ 3.0) |
| Never opened a second time | 29/99; cold turkey 41% vs taper 20% | **yes** (z ≈ 2.3) |
| Notifications granted vs refused | 54% vs 45% | **no** (z ≈ 0.8) |
| When returners come back | 55 of 70 within 19 h | yes |
| Granted, got up to 7 evening check-ins, never came back | 16 of the 29 | yes |

92 of the 99 started on 1.0.28, before the cold-turkey day-one fix (1.0.30, docs/10 §52) and the daily program (1.0.36, docs/15 stage B). Only 7 people have started since, so **neither fix has been measured yet**.

### What the code says

- **Cold turkey** gets a 09:00 program message on plan days 1, 2 and 3 (program days 0–2: `q0am`, `d1am`, `d2am`) and an evening message every day to plan day 14.
- **Taper** gets nothing on the mornings of plan days 2 and 3. The program does not start until 7 days before Freedom Day. The danger-hour nudge needs 3 confirmed days, and its onboarding fallback (first-puff hour − 10 min) is 06:50, 06:50 or 07:50 for three of the four answers, inside the default 23→8 quiet hours. It is dropped on purpose (`ReminderPlanner.plan`: moving a craving nudge hours later is worse than none). Only the "more than an hour" answer gets one (08:50). So a taper user's first contact after install is the 20:00 check-in.

### What the research says (full report in this session; key sources checked)

- A plain daily notification makes opening the app in the next hour about **3.5×** more likely (Bell 2023, micro-randomised, N=350, alcohol app; STRONG). New wording did no better than the plain reminder. Long-term use did not change in the small arms.
- Texts that **link to one specific feature**, and texts **tailored to engagement**, raised engagement. Message intensity and personalisation alone did not (Graham 2020, factorial RCT, N=864, smoking cessation; MODERATE–STRONG).
- Day 2 is the most common first return in a cessation programme, and not returning in week 1 predicts never returning (EX, N=70,265; observational, STRONG).
- No study measured return by quit method.
- Early lifts fade, so judge on D7 and D14, not D1.

### The honest framing

This change fills a real gap in the code: a taper user gets no morning touch on plan days 2–3, while cold turkey does. It uses the one mechanism with strong evidence, a notification raising next-hour opens. **It is a hypothesis, not an explanation of the gap we measured**: taper users already come back at 67%, and the group that never came back is mostly cold turkey, measured on the 1.0.28 bug. The measurement half of this change is what will show whether the 1.0.30/1.0.36 cold-turkey fixes and this morning do anything.

## 2. Goals, non-goals, anti-goals

**Goals**
1. Every plan gets a morning touch on plan days 2 and 3. Where the program already has a morning (cold turkey), that is it. Everywhere else (taper) it is a new plain morning.
2. The morning names one action, and its tap lands where that action is.
3. Every reminder tap says which slot, plan day and program message it was, so the readout can compute tap rates and how people came back, by method.
4. Proven on the Pixel 8 and the iPhone with real notifications. A tap lands on Home and reports the new properties.

**Non-goals**
- Moving or re-timing the danger-hour fallback (see §1; the drop is deliberate).
- Tailoring the evening check-in to engagement (see §3).
- Cold turkey starting tomorrow (option C), SMS or email, more than one extra notification a day, any server change.

**Anti-goals** (failure even if it works)
- A notification that claims a status (vape-free, no slip, "you haven't opened today"). It is armed before the day happens (CLAUDE.md, quit program).
- Two buzzes within the same hour on the same morning.
- Breaking the promise the notification-permission screen and Settings make.
- Any morning to someone who turned the daily message off, inside quiet hours, or on a zero line telling them to log a puff.
- Reporting a retention win before D7 data exists for enough people.

## 3. Approaches considered

- **A — Measure only.** Prove 1.0.30/1.0.36 on device and add tap measurement. No behaviour change. Cheapest; a verdict takes 6–8 weeks at ~7 new people a week.
- **B — A plus a day 2–3 morning (picked).** Fills the taper gap with the best-evidenced mechanism and includes A's measurement and device proof. Costs copy in 6 locales and one notification a day on plan days 2–3 for taper users.
- **C — Cold turkey starts tomorrow.** Make the install day a preparation day, as the trialled quit programmes do. Changes the plan, streak, money, widget and server maths. Deferred until A's data shows whether 1.0.30/1.0.36 closed the gap.

**Narrowed after reading the code** (both items were in the B pitch):
- *"Move the dropped morning nudge out of quiet hours"* becomes *"reuse the program's morning slot"*. The danger-hour drop is deliberate and documented. The program's `morningHour` (09:00, or the first open hour before noon) already exists and is what cold turkey gets.
- *"Make the evening differ by whether they opened that day"* is **dropped**. The version that says it ("you haven't been in today") is armed days ahead, and becomes false the moment somebody logs from the widget or the wrist, which never opens the app. That breaks the "an armed message never claims a status" rule. The version that does not say it is mostly already shipped: a non-program evening is skipped once the day is confirmed. What is left is a copy change with no mechanism behind it.

## 4. The design

### 4.1 When a plain morning is armed

In `CheckinReminderPlanner.plan`, for each day in the 7-day window, arm a plain morning at `morningHour(quietStart, quietEnd)` when **all** of these hold:

- the daily-message switch is on (the existing `enabled`; it is one switch for evening, program and mornings);
- `plan.dayNumber(day)` is 2 or 3, and ≤ `plan.totalDays`;
- the program has **no** morning message that day (`QuitProgram.messageFor(..., ProgramSlot.morning) == null`). So cold turkey never gets two;
- `morningHour` is not null, and the fire time is after `now`;
- no other reminder the coordinator arms fires within 60 minutes either side of it: the danger-hour slots (this catches the 08:50 fallback against a 09:00 morning) and an owed milestone celebration (08:00, or when quiet hours end, so exactly 09:00 when they end at 9). The coordinator plans those first and passes their fire times in, and the plain morning is the one that yields. *(Builder check; my call.)*

**Known, left alone:** cold turkey's existing double. "More than an hour" answerers already get the 08:50 danger nudge and the 09:00 program morning on plan days 1–3. Changing that would muddy the 1.0.30/1.0.36 cold-turkey measurement this change exists to read. It is recorded in docs/10.

Applies to any plan, including a plan started again (`planNumber > 1`). Day 2 of a new plan is the same moment.

- **Ids:** `5100 + planDay`, so 5102 and 5103. That is clear of danger (1000–1023), trial (2000), milestones (3000+), evenings (4000–4006) and program mornings (5000–5002).
- **Cancelling:** `_syncCheckins` cancels them with its own ids. Never `cancelAll()`.
- **Fingerprint:** it carries the new slot, so a change re-arms.

### 4.2 What it says

**Title:** a new morning title, `morningNotifTitle(day)` (draft en "Day {day}"). The existing `checkinNotifTitle` reads as an *evening* title in fr ("le point du soir"), de ("Check-in am Abend") and it ("il punto della sera"). `_dayTitle` already puts it on cold turkey's 09:00 program mornings, so production says "evening" at nine in three languages today. The new title goes on **every** morning slot: the plain morning *and* the program mornings (`_programCopy` picks it by slot). This changes the title of cold turkey's mornings only, never their time or body. Past Freedom Day keeps `checkinNotifTitlePast`'s rule (no number). *(Builder check; my call, because a 09:00 notification titled "evening" is wrong copy.)*

The body has two variants:

- **Limit > 0:** `morningNotifBody(limit)`. Draft en: "Today's line is {limit} puffs. Log each one as it happens, the first one too." It names the action (log), the number comes from `limitOn` (no invented numbers), and it claims nothing about the day.
- **Limit 0:** `morningNotifBodyZero`. Draft en: "A zero line today. If a craving hits, open Cirrus and give it sixty seconds." It names the panic flow and never says "log a puff" on a zero line.

The tap routes to Home like `checkin`. Home is where LOG PUFF, or the zero-day confirmation, is pinned. All 6 locales go in through a JSON round-trip, in the spoken register of the store screenshots (memory: translation register). Words must not imply a health or quitting promise (`copy_honesty_test`).

### 4.3 The promise on the permission screen and in Settings

- `obNotifBullet3` currently reads "The first three mornings from your date. Nothing else". For a taper user, "your date" is Freedom Day, so a plan-day-2 morning breaks a promise they agreed to.
- **Change** `obNotifBullet3` and `settingsCheckinBody` in all 6 locales so they name the plan's first mornings too. Draft en bullet: "A morning on your plan's first days, and the first three mornings from your date. Nothing else — no marketing, ever." The wording must never promise *fewer* mornings than are sent. For cold turkey the two sets are the same days.
- **Also change** `pushAskDayOneBody`, the ask shown when the Day-1 checklist is finished. For people who skipped the onboarding ask, it is the first time the phone asks, right before the first plan-day-2 morning. It lists "an evening check-in with your limit, a heads-up before your danger hours, and a word when you hit a milestone", and should name the morning too. *(Builder check; my call.)*
- **Not changed, recorded:** `pushAskBody` (after a first post: "We'll only ping you about your own posts. Never anyone else's"). That sentence is about community pings and is already broader than true, because evenings and danger nudges exist. It predates this change and goes in docs/10 as a known issue for the founder.
- **Update** `copy_honesty_test` to require the new phrase in `obNotifBullet3`, `settingsCheckinBody` and `pushAskDayOneBody`.
- **Existing consenters** (builder's call, stated): the only people on old wording who can reach plan day 2–3 again are those who start a new plan. Settings already describes the switch, so they get the morning.

### 4.4 Measuring it

- **Payload:** `kind`, or `kind|slot|planDay|message` (message empty when none). The decoder takes the first field as the kind and the rest as optional. A bare `kind` (everything armed by 1.0.36 and earlier, which will still fire after the upgrade) decodes exactly as today.
- **Tap stream:** `ReminderSink.opened` carries a small `ReminderTap { kind, slot?, planDay?, message? }`. Routing still switches on `kind`.
- **Event:** `reminder_opened` gains `slot` (morning | evening), `plan_day` and `message` (the `ProgramMessage` name) when known. They are registered in the `lp_events.dart` doc comment. Danger, trial and milestone keep the bare payload.
- **No "scheduled" event.** Sync runs on every change, so one would fire constantly.
- **The denominator is a one-way user property instead.** `day2_morning = armed` is set through `AnalyticsProfile` the first time the coordinator arms the plan-day-2 morning (plain or program). It is never set to anything else, and `forget()` on sign-out already clears it for the next account. `quit_method` + `push_permission` alone would count people who were never sent a morning: the 08:50 answerers, quiet hours covering 9–11, and the switch off. That would make the tap rate read low. *(Builder check; my call.)*

### 4.5 Proving it

- **Unit (planner), test first:**
  - taper day 1 arms 5102 and 5103 at 09:00;
  - cold turkey day 1 arms only the program mornings, exactly one per morning;
  - a quiet-hours end of 10 moves it to 10:00;
  - 9–11 all quiet means none;
  - switch off means none;
  - an 08:50 danger slot drops it, and so does a milestone celebration owed at 09:00;
  - every morning slot (plain and program) gets the morning title;
  - `day2_morning` is reported once, and again after `forget()`;
  - a zero line picks the zero copy;
  - DST-safe fire times;
  - plan day 2 ≤ totalDays.
- **Unit (wire):**
  - the encode/decode round-trip;
  - a bare 1.0.36 payload still decodes;
  - an unknown payload is dropped;
  - the props reach `reminder_opened` (`RecordingAnalytics`).
- **Widget:** a tap of each new payload lands on Home after the splash (the existing `reminder_tap_test` pattern).
- **Copy:**
  - `l10n_parity`;
  - `copy_honesty` with the new consent phrase;
  - the zero variant never says "log".
- **Device:** a new suite (or a case in `k_retention_test`) seeds a day-1 taper journey on the fake backend. It runs the **real planner** for that journey, so the production words, id and payload are used, then shifts only `at` to now + 90 s and arms it through the real `ReminderScheduler`.
  - **Pixel 8:** read the shade over adb (`dumpsys notification` / uiautomator), tap it over adb, assert Home and `reminder_opened{slot: morning, plan_day: 2}`. Do Not Disturb off, `deviceidle` disabled, kept on power (memory: Pixel run notes).
  - **iPhone:** the same suite through the real app delegate (the `m_reminder_tap` pattern). The banner tap is one hand step, announced on an `E2E-MARKER:` line.
- **Real-time acceptance (Pixel):** a fresh taper account on the fake backend, made the evening before, left overnight. At 09:01, `dumpsys notification` shows the plan-day-2 morning with that account's line. This is the only proof that the timing rules hold on a real clock.

### 4.6 Readout (docs/08 task, after release)

- **Mechanism:** at 2 and 4 weeks, the morning tap rate (`reminder_opened` slot=morning, plan_day 2/3, divided by people with `day2_morning = armed`), and the share of day-2 return sessions that *included* a morning tap. Read both by method. A cold-start tap is reported only after the scheduler initialises, which comes after the splash's screen view, so "the first event was the tap" cannot be read.
- **Outcome:** D1, D7 and D14 by method, against the 1.0.28 baseline (taper 67% D1, cold turkey 36%), real-user filter applied.
- **Sample size:** at ~4 taper people a week, detecting a 15-point change in D1 from 67% needs ~150 per arm, i.e. months. **The readout will speak to the mechanism within weeks, and to retention only much later; nobody should call it a win sooner.**

### 4.7 Docs

- docs/10 new §: what was built, and what was narrowed and why.
- docs/13 feature-map row for the morning.
- docs/08 task for the readout.
- CLAUDE.md: the quit-program/check-in paragraph names the new ids and the consent wording rule.

## 5. Left to the builder

- Whether the extra payload fields ride a new small type or a record.
- The exact name of the new ARB keys.
- Test file placement.
- Whether the device case is its own file. A Back-key-free notification case can share `k_retention_test`.
- The final wording in each locale, within §4.2/§4.3's constraints.
