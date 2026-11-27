import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/analytics/analytics.dart';
import 'package:last_puff/domain/logic/exercises/exercise.dart';
import 'package:last_puff/domain/logic/games/games.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/features/coach/surface/coach_surface.dart';
import 'package:last_puff/features/exercises/exercise_launcher_card.dart';
import 'package:last_puff/features/panic/breath_ring.dart';
import 'package:last_puff/features/panic/games/orbs_field.dart';
import 'package:last_puff/features/panic/panic_screens.dart';
import 'package:material_ui/material_ui.dart';

import 'harness.dart';

/// Coach cards on a real device, on the fake backend
/// (docs/superpowers/plans/2026-11-25-coach-cards.md, task P1).
///
/// The widget suite pins each piece. What only a device shows is the pieces
/// together: the cards are drawn by a third-party renderer under a thread
/// that scrolls itself to its end, an exercise is a route pushed over a
/// keep-alive tab, and a craving is parked from one screen's `dispose` and
/// joined from the next one's first frame. Every one of those is a place
/// where a green widget test and a broken phone have already disagreed in
/// this repo.
///
/// ```
/// flutter test integration_test/u_coach_cards_test.dart \
///   -d <device> --dart-define=LP_BACKEND=fake
/// ```
///
/// On the fake backend the demo account is a subscriber and gets cards:
/// three for the craving chip (breathing, Orbs, SOS), one (breathing) on a
/// turn sent from inside a craving. A free account gets none.
///
/// `E2E-MARKER: shot <name>` lines hold the screen for 2.5 s so a driver
/// outside the app can screenshot it (`xcrun simctl io <udid> screenshot`,
/// `adb exec-out screencap`). **On Android the first case also needs the
/// driver to press the system Back key** on `E2E-MARKER: press-back`
/// (`adb shell input keyevent KEYCODE_BACK`): that case is first in the file
/// because the test binding resets the app's lifecycle after every test, and
/// from the second test on the app no longer tells Android it handles Back
/// (docs/10 §55). On iOS the way back is the screen's own chevron, and no
/// driver is needed for anything but the screenshots.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late _Recording analytics;
  late _CountingPanic panic;

  void marker(String text) {
    // ignore: avoid_print
    print('E2E-MARKER: $text');
  }

  /// Holds the screen still so the driver can capture it.
  Future<void> shot(E2E e2e, String name) async {
    marker('shot $name');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  /// The demo subscriber, signed in and on Home.
  ///
  /// Two things are swapped for stand-ins that change nothing a person sees.
  /// Analytics is recorded instead of dropped (it reports from release builds
  /// only), so "counted once" and "no card was refused" can be read. And the
  /// fake backend's craving sessions, which it answers without counting, are
  /// counted here, so "one `begin()`" can be read too.
  Future<E2E> signedIn(WidgetTester tester) async {
    analytics = _Recording();
    panic = _CountingPanic();
    final e2e = await E2E.boot(
      tester,
      overrides: [
        analyticsProvider.overrideWithValue(analytics),
        panicRepositoryProvider.overrideWithValue(panic),
      ],
    );
    await e2e.waitFor(const Duration(seconds: 2));
    await e2e.emailDoor();
    await e2e.tapSpan(e2e.l10n.authLogIn);
    await e2e.enterField(e2e.l10n.authEmailLabel, 'maya@quitmail.com');
    await e2e.enterField(e2e.l10n.authPasswordLabel, 'secret1');
    await e2e.tapText(e2e.l10n.authLogIn);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(
      e2e.container.read(quitStoreProvider),
      isNotNull,
      reason: 'sign-in failed; on screen: ${e2e.texts()}',
    );
    return e2e;
  }

  /// The same person with the subscription lapsed, the way
  /// `i_monetisation_test.dart` makes one: the row goes on the fake server
  /// and the store is re-bound, which is the path a real expiry takes.
  Future<E2E> freeAccount(WidgetTester tester) async {
    final e2e = await signedIn(tester);
    final fake = e2e.container.read(fakeServerProvider)
      ..putEntitlement({
        'tier': 'free',
        'productId': 'yearly_3999',
        'expiresAt': DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
      });
    await e2e.container
        .read(entitlementProvider.notifier)
        .bindSession(fake.ensureSessionId());
    await e2e.settle();
    expect(
      e2e.container.read(isPremiumProvider),
      isFalse,
      reason: 'the account should read as free after the row expired',
    );
    return e2e;
  }

  Uri uri(E2E e2e) => e2e.container.read(routerProvider).state.uri;
  String path(E2E e2e) => uri(e2e).path;
  int survivedTotal(E2E e2e) =>
      e2e.container.read(quitStoreProvider)!.cravingsSurvivedTotal;

  Finder cards() => find.byType(ExerciseLauncherCard);
  Finder card(ExerciseId id) =>
      find.byWidgetPredicate((w) => w is ExerciseLauncherCard && w.id == id);
  List<ExerciseId> shownIds(WidgetTester tester) => [
    for (final card in tester.widgetList<ExerciseLauncherCard>(cards()))
      card.id,
  ];

  // Scoped to the coach screen: the shell keeps every tab alive, and a
  // pushed route may sit on top of it with a text field of its own.
  Finder composer() => find.descendant(
    of: find.byType(CoachScreen),
    matching: find.byType(TextField),
  );
  Finder sendArrow() => find.descendant(
    of: find.byType(CoachScreen),
    matching: find.byIcon(Icons.arrow_upward_rounded),
  );
  Finder thread() => find.descendant(
    of: find.byType(CoachScreen),
    matching: find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    ),
  );

  /// What a touch at the centre of [finder] lands on: whether it reaches
  /// [finder]'s own render object, and what is on top at that point when it
  /// does not. Hit-tested through the binding, the way a real finger is: a
  /// widget can be built, laid out and "visible" to a finder while something
  /// drawn over it, or the edge of a scroll view, takes the touch.
  ({Offset at, bool reaches, String top}) touchAt(
    WidgetTester tester,
    Finder finder,
  ) {
    final box = tester.renderObject<RenderBox>(finder);
    final at = box.localToGlobal(box.size.center(Offset.zero));
    final result = HitTestResult();
    tester.binding.hitTestInView(result, at, tester.view.viewId);
    final reaches = result.path.any((entry) => entry.target == box);
    // The first entry can be a span of text; name the first render object.
    final first = result.path
        .map((entry) => entry.target)
        .whereType<RenderObject>()
        .firstOrNull;
    final top = first == null
        ? 'nothing'
        : '${first.runtimeType} of ${first.debugCreator}';
    return (at: at, reaches: reaches, top: top);
  }

  Future<void> openCoach(E2E e2e) async {
    await e2e.tapText(e2e.l10n.navCoach);
    await e2e.waitFor(const Duration(seconds: 3));
    expect(path(e2e), Routes.coach, reason: 'on screen: ${e2e.texts()}');
  }

  /// Waits for Ember's answer to the message that made the thread longer
  /// than [after], then lets the thread finish scrolling to it.
  Future<void> awaitReply(E2E e2e, {required int after}) async {
    final end = DateTime.now().add(const Duration(seconds: 12));
    var answered = false;
    while (DateTime.now().isBefore(end)) {
      final coach = e2e.container.read(coachStoreProvider);
      if (!coach.isTyping &&
          coach.messages.length >= after + 2 &&
          coach.messages.last.role == CoachRole.ember) {
        answered = true;
        break;
      }
      await e2e.tester.pump(const Duration(milliseconds: 50));
    }
    expect(
      answered,
      isTrue,
      reason: 'no reply arrived; on screen: ${e2e.texts()}',
    );
    await e2e.waitFor(const Duration(milliseconds: 1200));
  }

  /// The craving chip, the way a person uses it: the chip fills the box,
  /// the arrow sends it.
  Future<void> sayCravingChip(E2E e2e) async {
    final before = e2e.container.read(coachStoreProvider).messages.length;
    await e2e.tap(
      find.text(e2e.l10n.coachChipCraving).hitTestable(),
      why: 'the craving chip',
    );
    await e2e.tap(sendArrow(), why: 'send');
    await awaitReply(e2e, after: before);
  }

  /// The words of the newest reply, resolved as the screen resolves them.
  String replyWords(E2E e2e) {
    final m = e2e.container.read(coachStoreProvider).messages.last;
    final spoken = m.text;
    if (spoken != null && spoken.isNotEmpty) return spoken;
    final count = ((m.args['count'] as num?) ?? 0).toInt();
    return switch (m.template) {
      CoachTemplate.craving1 => e2e.l10n.coachReplyCraving1,
      CoachTemplate.craving2 => e2e.l10n.coachReplyCraving2(count),
      CoachTemplate.craving3 => e2e.l10n.coachReplyCraving3,
      final other => fail('the craving chip was answered with $other'),
    };
  }

  /// Taps the card for [id] with a real pointer at its centre.
  Future<void> tapCard(E2E e2e, ExerciseId id) async {
    final target = card(id);
    expect(target, findsOneWidget, reason: 'no $id card: ${e2e.texts()}');
    await e2e.tester.tapAt(touchAt(e2e.tester, target).at);
    await e2e.settle();
    await e2e.waitFor(const Duration(milliseconds: 1500));
  }

  /// Where the newest reply and its cards sit in the thread: every number a
  /// reader needs to say whether the words can be read without scrolling.
  ///
  /// The thread scrolls itself to its end when a reply lands, and the cards
  /// come after the words, so on a short enough thread the cards take the
  /// room and the words go above the top edge.
  _Fold measureFold(E2E e2e, String label) {
    final tester = e2e.tester;
    // Off-stage included, and not required to be there at all. A finder
    // skips a list's children that are wholly outside its viewport, and a
    // list builds only what is near it: words pushed above the thread are an
    // answer to the question this asks, not a broken test.
    final words = find.text(replyWords(e2e), skipOffstage: false);
    final built = words.evaluate().isNotEmpty;
    final threadRect = tester.getRect(thread());
    final reply = built ? tester.getRect(words) : null;
    final cardRects = [
      for (final element in cards().evaluate())
        tester.getRect(find.byElementPredicate((e) => e == element)),
    ];
    bool reachable(Offset point) {
      final box = tester.renderObject<RenderBox>(words);
      final result = HitTestResult();
      tester.binding.hitTestInView(result, point, tester.view.viewId);
      return result.path.any((entry) => entry.target == box);
    }

    final position = tester.widget<ListView>(thread()).controller!.position;
    final ratio = tester.view.devicePixelRatio;
    final fold = _Fold(
      label: label,
      view: tester.view.physicalSize / ratio,
      keyboard: tester.view.viewInsets.bottom / ratio,
      thread: threadRect,
      reply: reply,
      cards: cardRects,
      centre: reply != null && reachable(reply.center),
      firstLine: reply != null && reachable(reply.topLeft + const Offset(3, 3)),
      lastLine:
          reply != null && reachable(reply.bottomLeft + const Offset(3, -3)),
      scrolled: position.pixels,
      scrollable: position.maxScrollExtent,
    );
    marker(fold.toString());
    return fold;
  }

  /// The app as it is laid out right now, painted to a PNG in the app's
  /// temporary folder and announced on an `E2E-MARKER: file <path>` line.
  ///
  /// For a view whose size the test has changed: the device goes on showing
  /// its last real frame, so a screenshot of the device shows nothing of it.
  /// This is the app's own layer tree, drawn by the device's own renderer.
  /// On a simulator the path is on the Mac and the driver can copy it.
  Future<void> capture(E2E e2e, String name) async {
    final tester = e2e.tester;
    await tester.pump();
    final layer = tester.binding.renderViews.first.debugLayer! as OffsetLayer;
    final image = await layer.toImage(Offset.zero & tester.view.physicalSize);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final file = File('${Directory.systemTemp.path}/$name.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    marker('file ${file.path}');
    await e2e.waitFor(const Duration(milliseconds: 2500));
  }

  // FIRST, on purpose: the one case that uses the platform's way back. On
  // Android that is the system Back key, and it reaches Flutter only while
  // the app has a lifecycle state, which only a file's first test has.
  testWidgets('a card opens breathing and back returns to the chat', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    await openCoach(e2e);
    await sayCravingChip(e2e);

    // The menu: one of each kind, in registry order.
    expect(shownIds(tester), [
      ExerciseId.breathing,
      ExerciseId.orbs,
      ExerciseId.sos,
    ], reason: 'on screen: ${e2e.texts()}');
    // Each one where a finger can land on it, without scrolling. Read and
    // photographed before anything is asserted, so a miss leaves evidence.
    final touches = {
      for (final id in shownIds(tester)) id: touchAt(tester, card(id)),
    };
    for (final MapEntry(key: id, value: touch) in touches.entries) {
      marker(
        'card ${id.name} at ${touch.at.dx.round()},${touch.at.dy.round()} '
        'reaches=${touch.reaches} top=${touch.top}',
      );
    }
    await shot(e2e, '01_menu_three_cards');
    for (final MapEntry(key: id, value: touch) in touches.entries) {
      expect(
        touch.reaches,
        isTrue,
        reason:
            'a touch at the centre of the ${id.name} card (${touch.at}) '
            'lands on ${touch.top}, not on the card',
      );
    }
    expect(
      [
        for (final props in analytics.propsOfAll('coach_ui_shown'))
          (props['launchers'], props['panic']),
      ],
      [(3, 'false')],
    );
    expect(analytics.names, isNot(contains('coach_ui_dropped')));

    await tapCard(e2e, ExerciseId.breathing);
    expect(
      find.byType(BreathRing),
      findsOneWidget,
      reason: 'the card did not open the ring; on screen: ${e2e.texts()}',
    );
    expect(path(e2e), '${Routes.exerciseBase}/breathing');
    expect(uri(e2e).queryParameters['src'], ExerciseSource.coach.name);
    expect(analytics.propsOfAll('exercise_opened'), [
      {'exercise': 'breathing', 'source': 'coach'},
    ]);
    await shot(e2e, '02_breathing_from_chat');

    if (defaultTargetPlatform == TargetPlatform.android) {
      // The driver presses the system Back key. Real time and no pump: if
      // Back closed the activity instead of the exercise, the lifecycle says
      // so, and a frame pumped at a backgrounded app stalls the run.
      final seen = <AppLifecycleState>[];
      final listener = AppLifecycleListener(onStateChange: seen.add);
      marker('press-back');
      final end = DateTime.now().add(const Duration(seconds: 30));
      while (DateTime.now().isBefore(end)) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (path(e2e) == Routes.coach) break;
        if (seen.contains(AppLifecycleState.paused)) break;
      }
      listener.dispose();
      marker('lifecycle after Back: ${seen.map((s) => s.name).join(' > ')}');
      expect(
        seen,
        isNot(contains(AppLifecycleState.paused)),
        reason: 'Back closed the app, not the exercise',
      );
      expect(
        path(e2e),
        Routes.coach,
        reason:
            'no Back key arrived in 30 s: the driver presses KEYCODE_BACK '
            'on the "E2E-MARKER: press-back" line',
      );
      await e2e.settle();
    } else {
      // An iPhone has no Back key and this route fades in (no edge swipe):
      // the chevron is the way back.
      await e2e.tap(find.byType(BackChevron).hitTestable(), why: 'the chevron');
    }
    await e2e.waitFor(const Duration(seconds: 1));

    // The thread, and its cards, as they were left.
    expect(path(e2e), Routes.coach);
    expect(find.byType(BreathRing), findsNothing);
    expect(shownIds(tester), [
      ExerciseId.breathing,
      ExerciseId.orbs,
      ExerciseId.sos,
    ]);
    expect(
      e2e.showing(replyWords(e2e)),
      isTrue,
      reason: 'the reply is gone; on screen: ${e2e.texts()}',
    );
    await shot(e2e, '03_back_in_chat');
    // Shown once: coming back is not a second impression. And the visit was
    // filed as one that did not end on "it passed".
    expect(analytics.propsOfAll('coach_ui_shown'), hasLength(1));
    expect(analytics.names, isNot(contains('coach_ui_dropped')));
    expect(
      [
        for (final props in analytics.propsOfAll('exercise_finished'))
          (props['exercise'], props['source'], props['passed']),
      ],
      [('breathing', 'coach', 'false')],
    );
    // Leaving is not an outcome: the craving the exercise opened is parked.
    expect(analytics.names, isNot(contains('craving_outcome')));
  });

  testWidgets('a game from the chat ends back in the chat', (tester) async {
    final e2e = await signedIn(tester);
    final before = survivedTotal(e2e);
    await openCoach(e2e);
    await sayCravingChip(e2e);

    await tapCard(e2e, ExerciseId.orbs);
    expect(
      find.byType(OrbsField),
      findsOneWidget,
      reason: 'the card did not open Orbs; on screen: ${e2e.texts()}',
    );
    expect(path(e2e), Routes.game);
    expect(uri(e2e).queryParameters['g'], GameId.orbs.name);
    expect(uri(e2e).queryParameters['src'], ExerciseSource.coach.name);
    await shot(e2e, '04_orbs_from_chat');

    // A real minute on a real ticker.
    await e2e.waitFor(const Duration(seconds: 61));
    expect(
      e2e.showing(e2e.l10n.gameMinutesDone(1)),
      isTrue,
      reason: 'no check-in after a minute; on screen: ${e2e.texts()}',
    );
    await e2e.tap(
      find.text(e2e.l10n.panicItPassed).hitTestable(),
      why: '"it passed" on the round panel',
    );
    await e2e.waitFor(const Duration(seconds: 2));

    expect(path(e2e), Routes.survived, reason: 'on screen: ${e2e.texts()}');
    expect(e2e.showing(e2e.l10n.survivedPlusOne), isTrue);
    // It began in the chat, so the chat is where it leads back to.
    expect(
      e2e.showing(e2e.l10n.survivedBackChat),
      isTrue,
      reason: 'on screen: ${e2e.texts()}',
    );
    expect(e2e.showing(e2e.l10n.survivedBack), isFalse);
    await shot(e2e, '05_survived_back_to_chat');

    await tester.ensureVisible(find.text(e2e.l10n.survivedBackChat));
    await e2e.settle(frames: 20);
    await e2e.tap(
      find.text(e2e.l10n.survivedBackChat).hitTestable(),
      why: '"Back to the chat"',
    );
    await e2e.waitFor(const Duration(seconds: 2));

    expect(path(e2e), Routes.coach, reason: 'on screen: ${e2e.texts()}');
    expect(uri(e2e).queryParameters['panic'], isNull);
    expect(survivedTotal(e2e), before + 1);
    // The thread they left, cards and all, and nothing asking how it went:
    // they already said.
    expect(shownIds(tester), [
      ExerciseId.breathing,
      ExerciseId.orbs,
      ExerciseId.sos,
    ]);
    expect(e2e.showing(e2e.l10n.coachAfterStill), isFalse);
    await shot(e2e, '06_chat_after_game');

    // One craving, opened once and counted once.
    expect(panic.begins, 1);
    expect(panic.survivals, [
      (
        intensity: null,
        exercise: ExerciseId.orbs,
        source: ExerciseSource.coach,
      ),
    ]);
    expect(
      [
        for (final props in analytics.propsOfAll('craving_outcome'))
          (props['survived'], props['exercise'], props['source']),
      ],
      [('true', 'orbs', 'coach')],
    );
    expect(
      [
        for (final props in analytics.propsOfAll('exercise_finished'))
          (props['exercise'], props['completed'], props['passed']),
      ],
      [('orbs', 'true', 'true')],
    );
    expect(analytics.names, isNot(contains('coach_ui_dropped')));
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('a craving handed over continues', (tester) async {
    final e2e = await signedIn(tester);
    final before = survivedTotal(e2e);

    // Home's SOS, past the breathing, to the list of ways out.
    await e2e.tapText(e2e.l10n.homeSos);
    await e2e.waitFor(const Duration(seconds: 2));
    if (e2e.showing(e2e.l10n.panicSkipToWhy)) {
      await e2e.tapText(e2e.l10n.panicSkipToWhy);
    }
    await e2e.waitFor(const Duration(seconds: 1));
    // 8 out of 10. Through the notifier, which is all the slider's own
    // `onChanged` calls.
    e2e.container.read(panicProvider.notifier).setIntensity(8);
    await e2e.settle(frames: 20);
    if (e2e.showing(e2e.l10n.panicStillCraving)) {
      await e2e.tapText(e2e.l10n.panicStillCraving);
    }
    await e2e.waitFor(const Duration(seconds: 1));
    expect(
      e2e.showing(e2e.l10n.panicLoopTitle),
      isTrue,
      reason: 'not on the loop screen; on screen: ${e2e.texts()}',
    );
    final startedAt = e2e.container.read(panicProvider).startedAt;
    expect(startedAt, isNotNull, reason: 'the takeover opened no craving');
    expect(panic.begins, 1);
    await shot(e2e, '07_loop_before_handover');

    // The coach option. It hands the craving over; it does not end it.
    await tester.ensureVisible(find.text(e2e.l10n.panicLoopCoach));
    await e2e.settle(frames: 20);
    await e2e.tap(
      find.text(e2e.l10n.panicLoopCoach).hitTestable(),
      why: 'the coach option',
    );
    await e2e.waitFor(const Duration(seconds: 3));
    expect(path(e2e), Routes.coach, reason: 'on screen: ${e2e.texts()}');
    expect(uri(e2e).queryParameters['panic'], '8');
    expect(
      analytics.names,
      isNot(contains('craving_outcome')),
      reason: 'the craving was reported over at the moment it was handed on',
    );

    // Say something, with the real keyboard.
    final said = e2e.container.read(coachStoreProvider).messages.length;
    await tester.enterText(composer(), 'this one is strong');
    await e2e.settle();
    await e2e.tap(sendArrow(), why: 'send');
    await awaitReply(e2e, after: said);

    // One next step, never a menu.
    expect(shownIds(tester), [
      ExerciseId.breathing,
    ], reason: 'on screen: ${e2e.texts()}');
    expect(
      [
        for (final props in analytics.propsOfAll('coach_ui_shown'))
          (props['launchers'], props['panic']),
      ],
      [(1, 'true')],
    );
    // Whether the card can be touched with the keyboard still up is
    // recorded, not required: a person can put the keyboard away.
    final keyboard =
        tester.view.viewInsets.bottom / tester.view.devicePixelRatio;
    final withKeyboard = touchAt(tester, card(ExerciseId.breathing));
    marker(
      'handover card: keyboard=${keyboard.round()} '
      'reaches=${withKeyboard.reaches} top=${withKeyboard.top}',
    );
    await shot(e2e, '08_chat_one_card');
    if (!withKeyboard.reaches) {
      FocusManager.instance.primaryFocus?.unfocus();
      await e2e.waitFor(const Duration(seconds: 1));
      await tester.ensureVisible(card(ExerciseId.breathing));
      await e2e.settle(frames: 20);
    }
    expect(
      touchAt(tester, card(ExerciseId.breathing)).reaches,
      isTrue,
      reason: 'the one card cannot be touched even with the keyboard away',
    );

    await tapCard(e2e, ExerciseId.breathing);
    expect(
      find.byType(BreathRing),
      findsOneWidget,
      reason: 'the card did not open the ring; on screen: ${e2e.texts()}',
    );
    // The SAME craving: its clock, its strength, its one server session,
    // and still nothing reported about it.
    final joined = e2e.container.read(panicProvider);
    expect(joined.startedAt, startedAt);
    expect(joined.intensity, 8);
    expect(panic.begins, 1);
    expect(analytics.names, isNot(contains('craving_outcome')));
    await shot(e2e, '09_breathing_same_craving');

    // And it ends as that craving, at the strength it was given.
    await e2e.tap(
      find.text(e2e.l10n.panicItPassed).hitTestable(),
      why: '"it passed" under the ring',
    );
    await e2e.waitFor(const Duration(seconds: 2));
    expect(path(e2e), Routes.survived, reason: 'on screen: ${e2e.texts()}');
    expect(e2e.showing(e2e.l10n.survivedBackChat), isTrue);
    expect(survivedTotal(e2e), before + 1);
    expect(panic.begins, 1);
    expect(panic.survivals, [
      (
        intensity: 8,
        exercise: ExerciseId.breathing,
        source: ExerciseSource.coach,
      ),
    ]);
    expect(
      [
        for (final props in analytics.propsOfAll('craving_outcome'))
          (props['survived'], props['intensity'], props['exercise']),
      ],
      [('true', 8, 'breathing')],
    );
    await shot(e2e, '10_survived_after_handover');
  });

  testWidgets('a free account sees none', (tester) async {
    final e2e = await freeAccount(tester);
    await openCoach(e2e);
    await sayCravingChip(e2e);

    final words = replyWords(e2e);
    marker('free account: cards=${cards().evaluate().length}');
    await shot(e2e, '11_free_account_no_cards');
    // Today's thread exactly: the words, and where a card would be, nothing
    // that takes any room.
    expect(e2e.visible(words), isTrue, reason: 'on screen: ${e2e.texts()}');
    expect(cards(), findsNothing);
    expect(find.byType(CoachSurfaceView), findsOneWidget);
    expect(tester.getSize(find.byType(CoachSurfaceView)).height, 0);
    expect(analytics.names, isNot(contains('coach_ui_shown')));
    expect(analytics.names, isNot(contains('coach_ui_dropped')));
  });

  testWidgets('saying it passed in the chat counts the craving', (
    tester,
  ) async {
    final e2e = await signedIn(tester);
    final before = survivedTotal(e2e);
    await openCoach(e2e);
    await sayCravingChip(e2e);

    await tapCard(e2e, ExerciseId.breathing);
    expect(
      find.byType(BreathRing),
      findsOneWidget,
      reason: 'on screen: ${e2e.texts()}',
    );
    // The chevron on both platforms: Android's Back key is the first case's
    // (it only reaches Flutter in a file's first test).
    await e2e.tap(find.byType(BackChevron).hitTestable(), why: 'the chevron');
    await e2e.waitFor(const Duration(seconds: 1));
    expect(path(e2e), Routes.coach);

    // Back without having said it passed: the question is still open, and
    // its two answers lead the row.
    final itPassed = find.descendant(
      of: find.byType(CoachScreen),
      matching: find.text(e2e.l10n.panicItPassed),
    );
    final stillStrong = find.descendant(
      of: find.byType(CoachScreen),
      matching: find.text(e2e.l10n.coachAfterStill),
    );
    marker(
      'lead chips: itPassed=${itPassed.hitTestable().evaluate().length} '
      'stillStrong=${stillStrong.hitTestable().evaluate().length}',
    );
    await shot(e2e, '12_back_with_lead_chips');
    expect(
      itPassed.hitTestable(),
      findsOneWidget,
      reason: 'on screen: ${e2e.texts()}',
    );
    expect(stillStrong.hitTestable(), findsOneWidget);
    expect(
      tester.getCenter(itPassed).dx,
      lessThan(tester.getCenter(stillStrong).dx),
    );
    expect(survivedTotal(e2e), before);

    final messages = e2e.container.read(coachStoreProvider).messages.length;
    final sent = analytics.propsOfAll('coach_message_sent').length;
    await e2e.tap(itPassed.hitTestable(), why: 'the "It passed" chip');
    await e2e.waitFor(const Duration(seconds: 1));

    // Counted, as the button on the exercise's own screen would count it.
    expect(survivedTotal(e2e), before + 1);
    expect(panic.survivals, [
      (
        intensity: null,
        exercise: ExerciseId.breathing,
        source: ExerciseSource.coach,
      ),
    ]);
    expect(
      [
        for (final props in analytics.propsOfAll('craving_outcome'))
          (props['survived'], props['exercise'], props['source']),
      ],
      [('true', 'breathing', 'coach')],
    );
    // The words are in the box, and nothing was said on their behalf.
    expect(
      tester.widget<TextField>(composer()).controller!.text,
      e2e.l10n.panicItPassed,
    );
    expect(
      e2e.container.read(coachStoreProvider).messages,
      hasLength(messages),
    );
    expect(analytics.propsOfAll('coach_message_sent'), hasLength(sent));
    // No celebration screen: they are where they already were.
    expect(path(e2e), Routes.coach);
    await shot(e2e, '13_it_passed_in_chat');

    // Said again, it is the same craving, already over.
    if (itPassed.hitTestable().evaluate().isNotEmpty) {
      await e2e.tap(itPassed.hitTestable(), why: 'the chip again');
      await e2e.waitFor(const Duration(seconds: 1));
    } else {
      marker('lead chips: the "It passed" chip is gone after one tap');
    }
    expect(survivedTotal(e2e), before + 1);
    expect(panic.survivals, hasLength(1));
    expect(analytics.propsOfAll('craving_outcome'), hasLength(1));
    expect(
      e2e.container.read(coachStoreProvider).messages,
      hasLength(messages),
    );
    expect(panic.begins, 1);
  });

  testWidgets('the reply stays readable above three cards', (tester) async {
    final e2e = await signedIn(tester);
    await openCoach(e2e);
    await sayCravingChip(e2e);
    expect(shownIds(tester), hasLength(3));

    // Measured and photographed first; what it shows is the result either
    // way.
    final fold = measureFold(e2e, 'device');
    await shot(e2e, '14_reply_above_cards');

    expect(
      fold.centre,
      isTrue,
      reason: "the reply's words are off screen above their cards: $fold",
    );
    expect(
      fold.firstLine && fold.lastLine && fold.hiddenAbove == 0,
      isTrue,
      reason: 'part of the reply is above the top edge of the thread: $fold',
    );
    expect(
      fold.cards.first.top,
      greaterThanOrEqualTo(fold.reply!.bottom),
      reason: 'the cards are not under the words: $fold',
    );
  });

  // A probe, last in the file so that nothing depends on it. The devices
  // this suite runs on are tall (an iPhone 17 is 874 points, a Pixel 8 915),
  // and the question the case above asks was raised about a short one. This
  // lays the same screen out in a 360 by 640 view with a 24-point status
  // bar, with the device's real text engine and the app's real fonts. It is
  // NOT a small phone: the view is drawn in the top-left corner of whatever
  // screen it runs on, and nothing else about that device is small.
  testWidgets('the same, laid out in a 360 by 640 view', (tester) async {
    // Signed in at the device's own size: the sign-in form is driven with
    // the real keyboard, whose height would not be scaled with the view.
    final e2e = await signedIn(tester);
    final ratio = tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(360, 640) * ratio;
    tester.view.padding = FakeViewPadding(top: 24 * ratio);
    tester.view.viewPadding = FakeViewPadding(top: 24 * ratio);
    await e2e.settle();

    await openCoach(e2e);
    await sayCravingChip(e2e);
    expect(shownIds(tester), hasLength(3));

    final fold = measureFold(e2e, 'view-360x640');
    final touches = [
      for (final id in shownIds(tester)) touchAt(tester, card(id)).reaches,
    ];
    marker('view-360x640 cards reachable: $touches');
    await capture(e2e, '15_small_view_reply_above_cards');

    expect(
      fold.centre,
      isTrue,
      reason: "the reply's words are off screen above their cards: $fold",
    );
    expect(
      fold.firstLine && fold.lastLine && fold.hiddenAbove == 0,
      isTrue,
      reason: 'part of the reply is above the top edge of the thread: $fold',
    );
    // Founder decision, Nov 25 2026: on a short view the reply's first line
    // stays on screen and the cards run below it, so the last card may rest
    // under the fold (on the Pixel 8 this read [true, true, false] with the
    // reply fully visible). It has to be one ordinary scroll away, never out
    // of reach: this case used to ask for all three without scrolling, which
    // is the layout that pushed the words off the top.
    expect(
      touches.first,
      isTrue,
      reason: 'the first card cannot be touched: $touches',
    );
    final last = card(shownIds(tester).last);
    await tester.ensureVisible(last);
    await e2e.settle();
    final lastReaches = touchAt(tester, last).reaches;
    marker('view-360x640 last card after a scroll: $lastReaches');
    expect(
      lastReaches,
      isTrue,
      reason: 'the last card cannot be reached by scrolling the thread',
    );
  });
}

/// Where a reply and its cards ended up, in logical pixels.
class _Fold {
  const _Fold({
    required this.label,
    required this.view,
    required this.keyboard,
    required this.thread,
    required this.reply,
    required this.cards,
    required this.centre,
    required this.firstLine,
    required this.lastLine,
    required this.scrolled,
    required this.scrollable,
  });

  final String label;

  /// The whole view, and how much of its bottom the keyboard has.
  final Size view;
  final double keyboard;

  /// The thread's viewport: what is outside it is not on screen.
  final Rect thread;

  /// The reply's words (the text, not its bubble). Null when they are not
  /// in the tree: further above the thread than the list keeps built.
  final Rect? reply;
  final List<Rect> cards;

  /// Whether a touch at the middle, the first line and the last line of the
  /// words lands on them.
  final bool centre;
  final bool firstLine;
  final bool lastLine;

  /// How far the thread has scrolled, and how far it can.
  final double scrolled;
  final double scrollable;

  /// How much of the words is above the thread's top edge: all of them when
  /// they are not built.
  double get hiddenAbove {
    final reply = this.reply;
    if (reply == null) return double.infinity;
    return math.min(reply.height, math.max(0, thread.top - reply.top));
  }

  @override
  String toString() {
    String span(Rect r) =>
        '${r.top.round()}..${r.bottom.round()} (${r.height.round()})';
    final reply = this.reply;
    final words = reply == null
        ? 'reply=NOT BUILT (further above the thread than the list keeps)'
        : 'reply=${span(reply)} hiddenAbove=${hiddenAbove.round()}';
    final under = cards.isEmpty
        ? 'cards=0'
        : 'cards=${cards.length} '
              '${cards.first.top.round()}..${cards.last.bottom.round()} '
              '(${(cards.last.bottom - cards.first.top).round()})';
    return 'fold $label: view=${view.width.round()}x${view.height.round()} '
        'keyboard=${keyboard.round()} thread=${span(thread)} $words $under '
        'scrolled=${scrolled.round()}/${scrollable.round()} '
        'centre=$centre firstLine=$firstLine lastLine=$lastLine';
  }
}

class _Recording implements AnalyticsSink {
  final List<AnalyticsEvent> events = [];

  List<String> get names => [for (final e in events) e.name];

  List<Map<String, Object>> propsOfAll(String name) => [
    for (final e in events)
      if (e.name == name) e.props,
  ];

  @override
  void track(AnalyticsEvent event) => events.add(event);

  @override
  void screenViewed(String name) {}

  @override
  void identify(String userId) {}

  @override
  void setUserProperties(Map<String, Object> properties) {}

  @override
  void reset() {}
}

/// The fake backend's craving sessions, counted. It answers what
/// `NoopPanicRepository` answers; it only remembers that it was asked.
class _CountingPanic implements PanicRepository {
  int begins = 0;
  final List<({int? intensity, ExerciseId? exercise, ExerciseSource? source})>
  survivals = [];

  @override
  Future<PanicAvailability> begin() async {
    begins++;
    return PanicAvailability.unknown;
  }

  @override
  Future<void> survived({
    int? intensity,
    int? intensityAfter,
    GameId? game,
    ExerciseId? exercise,
    ExerciseSource? source,
  }) async {
    survivals.add((intensity: intensity, exercise: exercise, source: source));
  }
}
