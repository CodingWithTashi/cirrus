import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_selectables.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:last_puff/features/settings/quiet_hours_band.dart';

import 'harness.dart';

/// The two Sep 6 2026 fixes that only a device can fully prove (docs/10 §28).
///
/// The craving that leaked into the next one was an app-lifetime notifier
/// reset from the wrong place; the widget suite pins the model, but the
/// takeover's real route push, its back gesture and its disposal are what
/// carried the bug. The quiet-hours rail is a horizontal drag inside a modal
/// sheet that also owns a vertical drag (dismiss) and a scroll view — the
/// gesture arena is a device question.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<E2E> signedIn(WidgetTester tester) async {
    final e2e = await E2E.boot(tester);
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.tapText(e2e.l10n.authContinueWithEmail);
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(quitStoreProvider), isNotNull,
        reason: 'sign-in failed; on screen: ${e2e.texts()}');
    return e2e;
  }

  testWidgets('a craving closed with back does not leak into the next one', (
    tester,
  ) async {
    // The 607:31 timer: a takeover closed the night before handed its clock,
    // its step and its intensity to the next morning's craving.
    final e2e = await signedIn(tester);
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));
    final firstStart = e2e.container.read(panicProvider).startedAt;
    expect(firstStart, isNotNull,
        reason: 'opening the takeover opens a craving');

    final vm = e2e.container.read(panicProvider.notifier)
      ..previewStep(2)
      ..setIntensity(9);
    await e2e.settle();
    expect(e2e.showing(e2e.l10n.panicLoopGame), isTrue,
        reason: 'on screen: ${e2e.texts()}');
    await e2e.waitFor(const Duration(seconds: 2));
    expect(vm.elapsed.inSeconds, greaterThanOrEqualTo(2));

    // The back gesture.
    e2e.container.read(routerProvider).pop();
    await e2e.waitFor(const Duration(seconds: 3));
    expect(e2e.container.read(routerProvider).state.uri.path, Routes.home);

    // The next craving. Its clock is compared with the first craving's own
    // start rather than against a fixed number of seconds: the harness's
    // waits and settles between the tap and this read are device-paced.
    final reopenedAt = DateTime.now();
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));
    final session = e2e.container.read(panicProvider);
    expect(session.step, 0,
        reason: 'the breathing ring, not the loop screen; on screen: '
            '${e2e.texts()}');
    expect(session.intensity, 7);
    expect(session.startedAt, isNotNull);
    expect(session.startedAt!.isAfter(firstStart!), isTrue,
        reason: 'a fresh clock, not the last craving\'s');
    expect(
      session.startedAt!.isAfter(
        reopenedAt.subtract(const Duration(seconds: 1)),
      ),
      isTrue,
      reason: 'the clock started when the takeover reopened',
    );
    expect(e2e.showing(e2e.l10n.panicLoopGame), isFalse);

    e2e.container.read(routerProvider).pop();
    await e2e.settle();
  });

  testWidgets('the quiet-hours rail drags inside the real sheet, re-answers '
      'the chips, and saves both', (tester) async {
    final e2e = await signedIn(tester);
    await e2e.tapText(e2e.l10n.navStats);
    await e2e.settle();
    // The heatmap card opens the editor (`SectionLabel` upper-cases).
    await e2e.tapText(e2e.l10n.statsTriggerHours.toUpperCase());
    await e2e.waitFor(const Duration(seconds: 1));
    expect(e2e.showing(e2e.l10n.settingsDangerHoursTitle), isTrue,
        reason: 'on screen: ${e2e.texts()}');

    // 11 PM first: the hour the new window is about to swallow.
    await e2e.tap(find.widgetWithText(LpChip, '11 PM'), why: '11 PM chip');
    await e2e.settle();
    expect(
      e2e.showing(e2e.l10n.settingsDangerHoursNudge('10:50 PM')),
      isTrue,
    );

    // The start knob sits at cell 11 of the noon-to-noon rail (11 PM). Two
    // cells left is 9 PM — a real horizontal drag through the sheet's own
    // dismiss-drag and scroll view.
    final rail = tester.getRect(find.byType(QuietHoursBand));
    final cell = rail.width / QuietTrack.cells;
    await tester.dragFrom(
      Offset(rail.left + 11 * cell, rail.top + QuietHoursBand.height / 2),
      Offset(-2 * cell, 0),
    );
    await e2e.settle();

    expect(
      e2e.showing(e2e.l10n.settingsQuietHours('9 PM – 8 AM')),
      isTrue,
      reason: 'the window did not move; on screen: ${e2e.texts()}',
    );
    expect(e2e.showing(e2e.l10n.settingsDangerHoursNudge('8:50 PM')), isTrue,
        reason: 'the selection did not step to 9 PM');
    expect(find.widgetWithText(LpChip, '11 PM').evaluate(), isEmpty,
        reason: '11 PM would fire inside the window and must leave the grid');
    expect(find.widgetWithText(LpChip, '10 PM').evaluate(), isEmpty);
    expect(e2e.showing(e2e.l10n.settingsDangerHoursTitle), isTrue,
        reason: 'the horizontal drag must not have dismissed the sheet');

    await e2e.scrollTo(find.text(e2e.l10n.commonSave));
    await e2e.tapText(e2e.l10n.commonSave);
    await e2e.settle();
    final settings = e2e.container.read(settingsStoreProvider);
    expect(settings.quietStartHour, 21);
    expect(settings.quietEndHour, 8);
    expect(settings.dangerStartHour, 21);
    expect(settings.dangerHoursCustom, isTrue);
  });
}
