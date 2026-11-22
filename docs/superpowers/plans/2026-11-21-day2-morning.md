# Day 2 and 3 Mornings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every plan gets a morning notification on plan days 2 and 3. Every reminder tap reports which slot, plan day and message brought the person back. Both are proven on a Pixel and an iPhone.

**Architecture:** `CheckinReminderPlanner` (pure domain) adds a plain morning on plan days 2–3 whenever the program has no morning that day. `ReminderCoordinator` arms it beside the evenings, with a 60-minute guard against the other reminders it arms. A new `ReminderTap` value travels in the notification payload and comes back on the tap stream, so `reminder_opened` gains `slot`, `plan_day` and `message`.

**Tech Stack:** Flutter, Riverpod 3, flutter_local_notifications, gen-l10n ARB (6 locales), flutter_test, integration_test.

**Spec:** `docs/superpowers/specs/2026-11-21-day2-morning-design.md`

## Global Constraints

- **Never `git commit` or `git push`.** The founder commits (global CLAUDE.md). The "Commit" step of each task is replaced by "leave the change unstaged and list the files".
- **Never run `dart format` on a directory, and never on an existing file.** HEAD is not formatter-clean (memory: *never dart-format a directory*). Hand-format new code to match its neighbours.
- **Edit ARBs only through a JSON round-trip**, writing to a temp path and then `os.replace`. Run `flutter gen-l10n` afterwards. Never edit `lib/l10n/gen/**`.
- **Ids are permanent:**
  - danger: 1000–1023
  - trial: 2000
  - milestones: 3000+
  - evenings: 4000–4006
  - program mornings: 5000–5002
  - **plain mornings: 5102, 5103** (`5100 + planDay`)
- **Never `cancelAll()` from the check-in path.**
- **Fire times are calendar arithmetic:** `DateTime(y, m, d + i, hour)`, never `Duration(days:)`.
- **An armed notification never claims a status.** Not vape-free, not "you haven't opened today".
- **On a zero line, no copy may say to log a puff.**
- **Numbers come from `journey.limitOn(at)`.** None are invented.
- **Translations** use the spoken, informal register of the store screenshots (`~/Downloads/store/ios-6.3/<code>/`) and the CLAUDE.md Localization rules:
  - German says *vapen*, never *dampfen*;
  - Italian addresses the reader without gender;
  - no interpolated word takes an article or possessive.
- **Gates before done:** `flutter analyze` clean; full `flutter test` green, reporting any failure by name.

## Review Focus

1. **Upgrading with old notifications armed.** A notification armed by 1.0.36 carries a bare `checkin` payload. Tapped after the upgrade, it must still route to Home and report `{'kind': 'checkin'}`. Owned by Task 1 (decode) and Task 2 (route).
2. **A payload field this build cannot read** (a future message name, or a non-numeric plan day). Keep the kind and drop only the unreadable field, never the whole tap. Owned by Task 1.
3. **A plan started again with history behind it.** Old confirmed days can give it a detected morning danger hour, so the guard must drop the plain morning rather than double-buzz. Owned by Task 3.
4. **Quiet hours that move or cover the morning.** If quiet hours end at 10, the morning fires at 10:00. If 9–11 are all quiet, there is none. Owned by Task 3.
5. **A taper whose plan-day-2 line is already 0** (a low baseline or a short plan). The zero copy must never say "log". Owned by Task 5.

---

### Task 1: `ReminderTap`, the payload codec

**Files:**
- Create: `lib/domain/logic/reminder_tap.dart`
- Test: `test/domain/reminder_tap_test.dart`

**Interfaces:**
- Consumes: `ReminderKind` (`reminder_planner.dart`); `ProgramSlot`, `ProgramMessage` (`quit_program.dart`).
- Produces:
  ```dart
  class ReminderTap {
    const ReminderTap(this.kind, {this.slot, this.planDay, this.message});
    final ReminderKind kind;
    final ProgramSlot? slot;
    final int? planDay;
    final ProgramMessage? message;
    String encode();                       // bare kind.name when all extras null
    static ReminderTap? decode(String? payload);
  }
  ```
  Wire format: `kind|slot|planDay|message` (empty field = absent), or bare `kind`. `==`/`hashCode` by all four fields.

- [ ] **Step 1: Write the failing tests** in `test/domain/reminder_tap_test.dart`:
  ```dart
  test('a tap with everything round-trips', () {
    const tap = ReminderTap(ReminderKind.program,
        slot: ProgramSlot.morning, planDay: 2, message: ProgramMessage.d1am);
    expect(tap.encode(), 'program|morning|2|d1am');
    expect(ReminderTap.decode(tap.encode()), tap);
  });
  test('a plain morning has no message field', () {
    const tap = ReminderTap(ReminderKind.checkin, slot: ProgramSlot.morning, planDay: 3);
    expect(tap.encode(), 'checkin|morning|3|');
    expect(ReminderTap.decode('checkin|morning|3|'), tap);
  });
  test('a bare kind is what danger, trial and milestone still carry', () {
    expect(const ReminderTap(ReminderKind.danger).encode(), 'danger');
  });
  test('a 1.0.36 payload, armed before the upgrade, still decodes', () {
    expect(ReminderTap.decode('checkin'), const ReminderTap(ReminderKind.checkin));
  });
  test('an unreadable field is dropped, the kind is kept', () {
    expect(ReminderTap.decode('program|dusk|two|d99pm'),
        const ReminderTap(ReminderKind.program));
  });
  test('an unknown kind, empty or null is no tap', () {
    expect(ReminderTap.decode('nudge|morning|2|'), isNull);
    expect(ReminderTap.decode(''), isNull);
    expect(ReminderTap.decode(null), isNull);
  });
  ```
- [ ] **Step 2: Run, and see it fail.** `flutter test test/domain/reminder_tap_test.dart`. Expected: compile failure, because `reminder_tap.dart` does not exist.
- [ ] **Step 3: Implement `ReminderTap`** in `lib/domain/logic/reminder_tap.dart`. Pure Dart, no Flutter import. Decode by `split('|')`; look each enum up by `.name`, and `int.tryParse` the plan day.
- [ ] **Step 4: Run, and see it pass.** Same command. Expected: all 6 pass.
- [ ] **Step 5: Leave unstaged.** Files: the two above.

### Task 2: Taps carry a `ReminderTap` end to end

**Files:**
- Modify:
  - `lib/data/api/firebase/reminder_scheduler.dart`:
    - `ReminderSink.scheduleOnce` replaces `required ReminderKind kind` with `required ReminderTap tap`;
    - `opened` becomes `Stream<ReminderTap>`;
    - `_report` uses `ReminderTap.decode`;
    - `oneShotDetails(tap.kind, body)`;
    - `payload: tap.encode()`.
  - `lib/data/stores/reminder_coordinator.dart`:
    - `opened` becomes `Stream<ReminderTap>`;
    - the trial and milestone `scheduleOnce` calls pass `ReminderTap(ReminderKind.trial)` / `ReminderTap(ReminderKind.milestone)`;
    - the check-in calls pass `checkin.tap` (Task 3 defines it; until then pass `ReminderTap(checkin.kind)`).
  - `lib/app/last_puff_app.dart`:
    - `_ReminderSyncState._taps` is a `StreamSubscription<ReminderTap>`;
    - `_pending` holds a `ReminderTap`;
    - routing switches on `tap.kind`;
    - analytics calls `reminderOpened(tap.kind.name, slot: tap.slot?.name, planDay: tap.planDay, message: tap.message?.name)`.
  - `lib/domain/analytics/lp_events.dart`: `void reminderOpened(String kind, {String? slot, int? planDay, String? message})`. It tracks only the non-null props, under keys `kind`, `slot`, `plan_day`, `message`, and the doc comment names all four and where they come from.
  - **Fakes:**
    - `test/data/reminder_coordinator_test.dart` `_FakeSink`;
    - `test/data/reminder_time_test.dart` `_RecordingSink`;
    - `test/widgets/reminder_tap_test.dart` `_TapSink` (a `StreamController<ReminderTap>`);
    - `integration_test/k_retention_test.dart` and `integration_test/m_reminder_tap_test.dart`, which call `scheduleOnce(..., tap: ReminderTap(ReminderKind.checkin))` and listen for `ReminderTap`.
- Test: `test/widgets/reminder_tap_test.dart`

**Interfaces:**
- Consumes: Task 1's `ReminderTap`.
- Produces: `ReminderSink.scheduleOnce(OneShotReminder, {required ReminderTap tap, required String title, required String body}) → Future<bool>`; `ReminderSink.opened → Stream<ReminderTap>`; `ReminderCoordinator.opened → Stream<ReminderTap>`.

- [ ] **Step 1: Write the failing widget tests** in `reminder_tap_test.dart`, following the file's existing `open()` helper and the `taps.add(...)` pattern:
  - `'a morning tap lands on Home and says which morning it was'`. Add `ReminderTap(ReminderKind.checkin, slot: ProgramSlot.morning, planDay: 2)`, then pump. Expect `Routes.home` and `analytics.propsOfAll('reminder_opened') == [{'kind': 'checkin', 'slot': 'morning', 'plan_day': 2}]`.
  - `'a program morning reports its message'`. `ReminderTap(ReminderKind.program, slot: ProgramSlot.morning, planDay: 2, message: ProgramMessage.d1am)` → props include `'message': 'd1am'`.
  - `'a bare check-in from before the upgrade still lands and reports its kind'`. `ReminderTap.decode('checkin')!` → Home, props `[{'kind': 'checkin'}]`.
- [ ] **Step 2: Run, and see it fail.** `flutter test test/widgets/reminder_tap_test.dart`. Expected: compile errors, because `_TapSink`/`opened` are still `ReminderKind`.
- [ ] **Step 3: Make the signature changes** listed under Files, including every fake. The existing tests' `taps.add(ReminderKind.x)` become `taps.add(const ReminderTap(ReminderKind.x))`.
- [ ] **Step 4: Run these, and see them pass:**
  - `flutter test test/widgets/reminder_tap_test.dart test/data/reminder_coordinator_test.dart test/data/reminder_time_test.dart test/data/reminder_details_test.dart`
  - `flutter analyze`

  Expected: all pass; analyze clean, including `integration_test/`.
- [ ] **Step 5: Leave unstaged.** List the files.

### Task 3: The planner arms a plain morning on plan days 2 and 3

**Files:**
- Modify: `lib/domain/logic/reminder_planner.dart`
- Test: `test/domain/checkin_reminder_planner_test.dart`

**Interfaces:**
- Consumes: Task 1's `ReminderTap`.
- Produces:
  - `CheckinReminder` gains `final ProgramSlot slot` (constructor param `this.slot = ProgramSlot.evening`) and `ReminderTap get tap => ReminderTap(kind, slot: slot, planDay: planDay, message: message)`.
  - `CheckinReminderPlanner`:
    - `static const int planMorningFirstId = 5100;`
    - `static const Set<int> planMorningDays = {2, 3};`
    - `static List<int> get planMorningIds => [5102, 5103];`
    - `static const Duration busyMargin = Duration(minutes: 60);`
    - `plan(...)` gains `Iterable<DateTime> busy = const []`.
  - Program mornings are now built with `slot: ProgramSlot.morning`.

**Rule:** for each day in the window, a plain morning `CheckinReminder` is added with id `planMorningFirstId + planDay`, at `DateTime(y, m, d, amHour)`, `limit: journey.limitOn(at)`, `slot: morning` and `message: null` when **all** of these hold:
- `planMorningDays.contains(planDay)`;
- `planDay <= totalDays`;
- the program has no morning that day;
- `amHour != null`;
- `at.isAfter(now)`;
- no instant in `busy` is within `busyMargin` of `at`, inclusive.

`enabled == false` and a quiet evening hour already return `[]` and keep doing so.

- [ ] **Step 1: Write the failing tests** (the file's `plan()` helper gains `Iterable<DateTime> busy = const []`):
  ```dart
  final eve = DateTime(2026, 9, 14, 21); // plan day 1, after the evening
  List<CheckinReminder> mornings(List<CheckinReminder> all) =>
      all.where((c) => c.slot == ProgramSlot.morning).toList();

  test('a taper gets 09:00 on plan days 2 and 3, and no other morning', () {
    final m = mornings(plan(journeyOnDay(1, now: eve), now: eve));
    expect(m.map((c) => (c.reminder.id, c.reminder.at, c.planDay)), [
      (5102, DateTime(2026, 9, 15, 9), 2),
      (5103, DateTime(2026, 9, 16, 9), 3),
    ]);
    expect(m.every((c) => c.message == null && c.kind == ReminderKind.checkin), isTrue);
  });
  test('cold turkey keeps only its program mornings — exactly one each day', () {
    final j = journeyOnDay(1, now: eve);
    final ct = j.copyWith(plan: j.plan.copyWith(method: QuitMethod.coldTurkey));
    final m = mornings(plan(ct, now: eve));
    expect(m.map((c) => c.reminder.id), [5001, 5002]);
    expect(m.map((c) => c.message), [ProgramMessage.d1am, ProgramMessage.d2am]);
  });
  test('the limit is the journey own answer', () { /* each m: c.limit == j.limitOn(c.reminder.at) */ });
  test('quiet hours ending at 10 move it to 10:00', () { /* quietEnd: 10 → at.hour == 10 */ });
  test('quiet hours covering 9-11 mean no plain morning, evenings still go', () {
    /* quietStart: 8, quietEnd: 12, hour: 20 → mornings empty, evenings non-empty */ });
  test('switched off means none', () { /* enabled: false → [] */ });
  test('a nudge within the hour drops that morning only', () {
    final m = mornings(plan(journeyOnDay(1, now: eve), now: eve,
        busy: [DateTime(2026, 9, 15, 8, 50)]));
    expect(m.map((c) => c.reminder.id), [5103]);
  });
  test('a busy instant just over the hour away does not', () {
    /* busy: [DateTime(2026, 9, 15, 7, 59)] → [5102, 5103] */ });
  test('day 2 already under way: only day 3 is left', () {
    final am = DateTime(2026, 9, 15, 9, 30); // plan day 2, past 09:00
    expect(mornings(plan(journeyOnDay(2, now: am), now: am)).map((c) => c.reminder.id), [5103]);
  });
  test('a two-day plan gets no morning past its end', () {
    /* journeyOnDay(1, now: eve, totalDays: 2) → ids [5102] */ });
  test('a plan started again gets them on its own day 2 and 3', () {
    final j = journeyOnDay(1, now: eve);
    final again = j.copyWith(plan: j.plan.copyWith(planNumber: 2));
    expect(mornings(plan(again, now: eve)).map((c) => c.reminder.id), [5102, 5103]);
  });
  test('the tap says which morning it was', () {
    final c = mornings(plan(journeyOnDay(1, now: eve), now: eve)).first;
    expect(c.tap.encode(), 'checkin|morning|2|');
  });
  test('a mid-plan day arms no plain morning', () {
    /* journeyOnDay(5, now: eve) → mornings empty */ });
  ```
- [ ] **Step 2: Run, and see it fail.** `flutter test test/domain/checkin_reminder_planner_test.dart`. Expected: compile error, because `slot`, `busy` and `tap` are undefined.
- [ ] **Step 3: Implement the rule** in `CheckinReminderPlanner.plan`. Update the class doc comment: the rules list gains the plain morning, its guard and its ids, citing docs/10 §59.
- [ ] **Step 4: Run, and see it pass.** Run `flutter test test/domain/checkin_reminder_planner_test.dart test/domain/quit_program_test.dart`. Expected: all pass, and the existing cases stay unchanged.
- [ ] **Step 5: Leave unstaged.**

### Task 4: The coordinator arms the mornings, guards them, and reports `day2_morning`

**Files:**
- Modify:
  - `lib/data/stores/reminder_coordinator.dart`:
    - `_syncDangerHours` keeps `List<ReminderSlot> _dangerSlots`, assigned before its fingerprint early-return;
    - `_syncMilestone` returns `Future<DateTime?>`, the instant it armed in this call, or null;
    - `_syncCheckins` gains `required Iterable<DateTime> busy` and `void Function()? onDay2MorningArmed`. It cancels `ids + morningIds + planMorningIds` before scheduling, and schedules with `tap: checkin.tap`.
    - `sync` gains `void Function()? onDay2MorningArmed`.
  - `lib/domain/analytics/lp_events.dart`: `LpUserProps.day2Morning = 'day2_morning'`, added to `all`.
  - `lib/app/last_puff_app.dart`: `onDay2MorningArmed: () => ref.read(analyticsProfileProvider).report({LpUserProps.day2Morning: 'armed'})`.
- Test: `test/data/reminder_coordinator_test.dart`, `test/widgets/analytics_profile_test.dart`

**Interfaces:**
- Consumes: Task 3's `CheckinReminderPlanner.plan(..., busy:)`, `planMorningIds`, `CheckinReminder.tap`; Task 2's `scheduleOnce(..., tap:)`.
- Produces: `ReminderCoordinator.sync(..., void Function()? onDay2MorningArmed)`. It is called once per sync in which a `slot == morning && planDay == 2` reminder was armed (`scheduleOnce` returned true).

**`busy`** is built in `sync` as:
- every danger slot on each of the 7 window days: `DateTime(y, m, d + i, slot.hour, slot.minute)`;
- the milestone instant armed in this sync;
- `settings.armedMilestoneAt` when non-null.

- [ ] **Step 1: Write the failing tests** in `reminder_coordinator_test.dart`. Use the file's `_FakeSink`, extended to record `(OneShotReminder, ReminderTap)` pairs and cancelled ids.
  - `'a day-1 taper is armed 5102 and 5103 with morning taps'`: sync with `journeyOnDay(1, now: eve)` and settings `hydrated: true`. Assert ids `{5102, 5103}` in `scheduledOnce`, with taps encoding `checkin|morning|2|` and `checkin|morning|3|`.
  - `'every sync cancels the plain-morning ids too'`: after a second sync with a changed journey, `cancelled` contains 5102 and 5103, and never a `cancelAll`.
  - `'the 08:50 first-puff fallback drops the plain morning'`: journey `profile.firstPuff = FirstPuffWindow.hourPlus`, no confirmed days. Assert 5102 and 5103 are both absent; the danger slot is 08:50 daily.
  - `'a celebration armed for 09:00 drops that morning'`: settings `armedMilestoneAt: DateTime(2026, 9, 15, 9)` → 5102 absent, 5103 present.
  - `'a plan started again with morning history drops the plain morning'`: a day-1 plan (`planNumber: 2`) whose journey holds three confirmed earlier days with puffs in the 09:00 bucket. The detected danger slot is 08:50, so 5102 and 5103 are both absent.
  - `'day2 armed is reported once per sync that arms it'`: a callback counter is 1 after the first sync. A refused `scheduleOnce` (sink returns false) reports 0.
- [ ] **Step 2: Write the failing profile test** in `analytics_profile_test.dart`, `'the day-2 morning is reported once it is armed'`. Boot a day-1 taper on the fake backend with a `ReminderCoordinator` over a fake sink (the `reminder_tap_test` override pattern). Expect `merged(analytics)[LpUserProps.day2Morning] == 'armed'`. Also extend the "names fit Firebase" test, which covers `all`.
- [ ] **Step 3: Run, and see them fail.** `flutter test test/data/reminder_coordinator_test.dart test/widgets/analytics_profile_test.dart`. Expected: compile errors or failures on the new cases.
- [ ] **Step 4: Implement** per Files.
- [ ] **Step 5: Run, and see them pass.** Same command, plus `flutter test test/widgets/reminder_tap_test.dart`.
- [ ] **Step 6: Leave unstaged.**

### Task 5: The words — the morning title on every morning, the two bodies, and the three promises

**Files:**
- Create: `lib/app/reminder_copy.dart`, holding `({String title, String body}) checkinCopy(AppLocalizations l10n, CheckinReminder c)` and `({String title, String body}) programCopy(AppLocalizations l10n, CheckinReminder c)`. These move out of `last_puff_app.dart` (`_checkinCopy`, `_programCopy`, `_dayTitle`) so the tests and the device suite use the production words.
- Modify:
  - `lib/l10n/app_{en,es,fr,de,it,pt}.arb` (JSON round-trip only);
  - `lib/app/last_puff_app.dart` (calls the moved functions).
- Test: `test/copy_honesty_test.dart`, `test/l10n_parity_test.dart` (no change expected, must pass), new `test/reminder_copy_test.dart`.

**Interfaces:**
- Consumes: Task 3's `CheckinReminder.slot`.
- Produces: ARB keys `morningNotifTitle` (`{day}` int), `morningNotifTitlePast`, `morningNotifBody` (`{limit}` plural), `morningNotifBodyZero`.

**English copy (fixed):**
- `morningNotifTitle`: `Day {day}`
- `morningNotifTitlePast`: `Good morning`
- `morningNotifBody`: `{limit, plural, =1{Today's line is 1 puff. Log each one as it happens, the first one too.} other{Today's line is {limit} puffs. Log each one as it happens, the first one too.}}`
- `morningNotifBodyZero`: `A zero line today. If a craving hits, open Cirrus and give it sixty seconds.`
- `obNotifBullet3`: `A morning on your plan's first days, and the first three mornings from your date. Nothing else — no marketing, ever`
- `settingsCheckinBody`: `One message an evening about your plan, a morning on its first days, and the first three mornings from your date. It stops by itself after a week without you opening Cirrus.`
- `pushAskDayOneBody`: `A morning and an evening check-in with your limit, a heads-up before your danger hours, and a word when you hit a milestone.`

The other five locales follow the register in Global Constraints and keep each locale's existing word for "check-in" and "line"/"limit" as it appears in that ARB today.

- [ ] **Step 1: Write the failing tests.**
  - In `copy_honesty_test.dart`, extend the "three mornings" test. Add a map `firstDays` holding each locale's exact phrase for "your plan's first days" as chosen in Step 3 (en: `"first days"`). Assert it in `obNotifBullet3`, `settingsCheckinBody` and `pushAskDayOneBody`. Assert `pushAskDayOneBody` also contains each locale's word for morning (en `morning`, es `mañana`, fr `matin`, de `morgen`, it `mattin`, pt `manhã`).
  - New `test/reminder_copy_test.dart`:
    - `'no morning title says evening'`: for each locale, `morningNotifTitle` and `morningNotifTitlePast` contain none of `evening, noche, soir, abend, sera, noite`.
    - `'the zero morning never says log'`: `morningNotifBodyZero` contains none of `log, registr, enregistr, eintrag, tragen, segna, regist`.
    - `'a program morning wears the morning title'`: `programCopy(l10n, c)` for `ProgramMessage.d1am` at planDay 2 → title == `l10n.morningNotifTitle(2)`. For an evening program message → `l10n.checkinNotifTitle(n)`. Load each locale with `lookupAppLocalizations(Locale(code))`.
    - `'a plain morning on a zero line gets the zero body'`: `checkinCopy(l10n, c)` with `slot: morning, limit: 0` → body == `l10n.morningNotifBodyZero`; `limit: 9` → `l10n.morningNotifBody(9)`. An evening keeps `checkinNotifBody`/`checkinNotifBodyZero`.
    - `'past Freedom Day a morning has no number and no evening'`: `planDay: 31, totalDays: 30, slot: morning` → title == `l10n.morningNotifTitlePast`.
- [ ] **Step 2: Run, and see them fail.** `flutter test test/copy_honesty_test.dart test/reminder_copy_test.dart`. Expected: failures (keys missing, old promise wording).
- [ ] **Step 3: Write the copy** in all six ARBs through a Python JSON round-trip (temp file + `os.replace`), with matching `@` metadata for the placeholders. Read each locale's screenshots first. Then run `flutter gen-l10n`.
- [ ] **Step 4: Move and wire the copy** into `lib/app/reminder_copy.dart`:
  - morning slot → `morningNotifTitle(day)`, or `morningNotifTitlePast` when `planDay > totalDays`;
  - plain morning body → `limit == 0 ? morningNotifBodyZero : morningNotifBody(limit)`;
  - evenings are unchanged.
- [ ] **Step 5: Run, and see them pass.**
  - `flutter test test/copy_honesty_test.dart test/reminder_copy_test.dart test/l10n_parity_test.dart test/coach_name_test.dart test/program_copy_resolver_test.dart`
  - `flutter analyze`

  Expected: all pass.
- [ ] **Step 6: Run the full suite.** `flutter test > <scratchpad>/full_test_morning.txt 2>&1`, then `tail -3`. Expected: `All tests passed!`. Report any failure by name.
- [ ] **Step 7: Leave unstaged.**

### Task 6: Proven on the devices

**Files:**
- Modify: `integration_test/k_retention_test.dart` (a new case after the check-in case); `integration_test/README.md` (the row names the morning case).

**Interfaces:**
- Consumes: everything above; the suite's `signedIn`, `marker`, `scheduler` and `analytics`.

- [ ] **Step 1: Write the device case** `'a plan-day-2 morning that fires is a real notification, and its tap lands on Home with its slot'`:
  - Build the morning through the **real planner**: `final j = e2e.container.read(quitStoreProvider)!; final day1 = j.copyWith(plan: j.plan.copyWith(method: QuitMethod.taper, startDate: LpDate.dayStart(DateTime.now())));`, then `CheckinReminderPlanner.plan(journey: day1, now: DateTime.now(), hour: 20, quietStartHour: 23, quietEndHour: 8, enabled: true)`. Take the first `slot == morning` (plan day 2, tomorrow at 09:00).
  - Arm it through `scheduler.scheduleOnce(OneShotReminder(id: 5199, at: DateTime.now().add(const Duration(seconds: 70))), tap: m.tap, title: checkinCopy(e2e.l10n, m).title, body: checkinCopy(e2e.l10n, m).body)`. Use id 5199 so no re-sync cancels it.
  - Print `marker('morning-armed …')`. Wait up to 6 min for `Routes.home`.
  - Expect `analytics.propsOfAll('reminder_opened').last == {'kind': 'checkin', 'slot': 'morning', 'plan_day': 2}`.
- [ ] **Step 2: Pixel 8.**
  - Set up: `adb uninstall com.quitvape.last_puff`, Do Not Disturb off, `adb shell dumpsys deviceidle disable`, phone on power.
  - Run `flutter test integration_test/k_retention_test.dart -d <pixel> --dart-define=LP_BACKEND=fake`. Drive the shade on the markers:
    - `adb shell cmd statusbar expand-notifications`;
    - `adb shell uiautomator dump`, then find the "Day 2" row and tap its bounds with `adb shell input tap x y`.
  - Expected: every case passes. A `dumpsys notification` taken at the marker shows channel `evening_checkins`, the title `Day 2`, and the day-2 line.
- [ ] **Step 3: iPhone.** Run `flutter test integration_test/k_retention_test.dart --name 'the second notification ask reads the OS, and its yes reaches the OS|plan-day-2 morning' -d <iphone> --dart-define=LP_BACKEND=fake` (one invocation that includes the permission-asking first case: a grant does not survive into a later `--plain-name` run, because every `flutter test integration_test` uninstalls the app, and iOS shows no Notifications switch for an app that never asked; the whole file also works). The OS permission sheet and the banner tap are hand steps, on `E2E-MARKER: os-dialog` and `E2E-MARKER: morning-armed`; ask the founder for them. Expected: pass.
- [ ] **Step 4: Real-time acceptance on the Pixel, overnight.**
  - Evening: a debug build, never a sideloaded `--release`, which cannot pass App Check. **A plain `LP_BACKEND=fake` build arms nothing** (`reminderCoordinatorProvider` is `null` on the fake backend; found on the Pixel Nov 21), so build a scratch APK with that one provider line wired to `ReminderCoordinator(ReminderScheduler())`, and restore the file byte-identical straight after. Make a fresh taper account through onboarding with notifications allowed, confirm the alarms in `adb shell dumpsys alarm`, then leave the app.
  - At 09:01 next day: `adb shell dumpsys notification --noredact | grep -A3 "Day 2"` shows the morning with that account's line. Screenshot it with `adb exec-out screencap -p`.
  - Then tap it and confirm Home.
  - Record the evidence path in docs/10 §59.
- [ ] **Step 5: Leave unstaged.**

### Task 7: Docs

**Files:**
- Modify:
  - `docs/10_Build_Log.md`: new §59, covering:
    - the finding (with the §1 table);
    - what was built, and the two narrowings and why;
    - the known cold-turkey 08:50/09:00 double;
    - the `pushAskBody` "only your own posts" issue for the founder;
    - device evidence paths;
    - gates.
  - `docs/13_Feature_Map.md`: a row for the plan's first mornings (what, how to test by hand), plus a changelog line.
  - `docs/08_Sprint_Tracker.md`: a readout task dated 2 and 4 weeks after the release ships. It holds the §4.6 recipe: tap rate over `day2_morning = armed`, return sessions that *included* a morning tap, and D1/D7/D14 by method against the 1.0.28 baseline (taper 67%, cold turkey 36%), real-user filter applied. It states that retention needs ~150 per arm.
  - `CLAUDE.md`: the daily-message gotcha names ids 5102/5103, the 60-minute guard, the morning title rule ("a 09:00 notification never wears an evening title"), and that `obNotifBullet3`/`settingsCheckinBody`/`pushAskDayOneBody` must name every morning kind sent.
- [ ] **Step 1: Write the four edits.**
- [ ] **Step 2: Check the docs against the code.** `grep -n "5102\|day2_morning" CLAUDE.md docs/10_Build_Log.md docs/08_Sprint_Tracker.md` shows each new fact once in each place it belongs.
- [ ] **Step 3: Leave everything unstaged**, and give the founder the full file list for the commit.
