import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/date_key.dart';
import 'package:last_puff/domain/models/journey_state.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/features/home/home_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// Home must not be overwhelming. People leave a screen that asks too much of
/// them, and on an ordinary day-3 afternoon it used to stack the offer, "finish
/// setup", the cigarettes question, the widget offer and the coach nudge under
/// two numbers (`HomeCardPlan`, Nov 13 2026).
///
/// What is pinned here is the promise, not the layout: of the optional cards,
/// **at most one is ever on screen, none beside the offer, and none beside
/// something that needs the person today.**
void main() {
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  // Mid-afternoon: before the evening mood prompt (18:00) and the vape-free
  // confirmation (20:00), so nothing "needs" the person by the clock.
  final now = DateTime(2026, 11, 13, 14, 30);

  /// A day-3 taper that qualifies for every optional card at once: setup not
  /// done, cigarettes never asked, enough puffs for the widget offer.
  JourneyState everythingDue() {
    final base = journeyOnDay(3, now: now);
    return base.copyWith(
      profile: UserProfile(
        alias: base.profile.alias,
        avatarEmoji: base.profile.avatarEmoji,
        smoking: null,
      ),
      day1TasksDone: const {},
    );
  }

  MemoryWidgetStore android() => MemoryWidgetStore()
    ..pinSupported = true
    ..installed = 0;

  Future<ProviderContainer> pumpHome(
    WidgetTester tester,
    JourneyState journey, {
    bool offer = false,
  }) async {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    tester.view.physicalSize = const Size(393, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(now: now, premium: !offer),
        widgetStoreProvider.overrideWithValue(android()),
      ],
    );
    addTearDown(container.dispose);
    if (offer) {
      container
          .read(settingsStoreProvider.notifier)
          .markLaunchPaywallShown(LpDate.dayKey(now));
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).replaceForTest(journey);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    return container;
  }

  /// Which optional cards are on screen.
  List<String> optional() => [
    if (find.text(l10n.homeFinishSetup(0)).evaluate().isNotEmpty) 'setup',
    if (find.text(l10n.obSmokingTitle).evaluate().isNotEmpty) 'smoking',
    if (find.text(l10n.widgetPromptTitle).evaluate().isNotEmpty) 'widget',
  ];

  bool offerShowing() =>
      find.text(l10n.homeOfferTitle(3)).evaluate().isNotEmpty;

  testWidgets('beside the offer there is nothing else optional', (tester) async {
    final container = await pumpHome(tester, everythingDue(), offer: true);

    expect(offerShowing(), isTrue, reason: 'the offer was counted: it shows');
    expect(optional(), isEmpty);
    // And the widget offer was held back, not burned: nobody saw it, so the
    // one chance it has is still there (a card that was due but not allowed used
    // to be marked shown while drawing nothing).
    expect(container.read(settingsStoreProvider).widgetPromptShown, isFalse);
  });

  testWidgets('without the offer they take turns: setup, then the cigarettes '
      'question, then the widget — one at a time', (tester) async {
    final container = await pumpHome(tester, everythingDue());

    // 1. Everything is due; only setup is shown.
    expect(optional(), ['setup']);

    // 2. Setup finished: the safety question takes the slot.
    final store = container.read(quitStoreProvider.notifier);
    for (final task in [0, 1, 2]) {
      store.completeDay1Task(task);
    }
    await tester.pumpAndSettle();
    expect(optional(), ['smoking']);

    // 3. Answered: the convenience is offered, alone.
    await tester.tap(find.text(l10n.obSmokingNever));
    // Past PressScale's 120ms release timer, then settled.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(optional(), ['widget']);

    // 4. Declined: none of the three is left, and nothing replaced it.
    await tester.tap(find.text(l10n.commonNotNow));
    // Past PressScale's 120ms release timer, then settled.
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pumpAndSettle();
    expect(optional(), isEmpty);
  });

  testWidgets('and none while something needs the person today', (tester) async {
    // A slip waiting to be resolved is the clearest "needs you now".
    final slipping = everythingDue().copyWith(pendingSlipCleanDays: () => 2);
    final container = await pumpHome(tester, slipping);

    expect(find.text(l10n.slipTitle), findsOneWidget);
    expect(optional(), isEmpty);

    // Resolved: the first optional card comes back — held back, not lost.
    container.read(quitStoreProvider.notifier).replaceForTest(
      slipping.copyWith(pendingSlipCleanDays: () => null),
    );
    await tester.pumpAndSettle();
    expect(optional(), ['setup']);
  });

  testWidgets('a card held back is not spent: the widget offer is still '
      'there when Home is calm', (tester) async {
    final slipping = everythingDue()
        .copyWith(
          profile: UserProfile(
            alias: 'x',
            avatarEmoji: '🦊',
            smoking: SmokingHistory.never,
          ),
          day1TasksDone: const {0, 1, 2},
        )
        .copyWith(pendingSlipCleanDays: () => 2);
    final container = await pumpHome(tester, slipping);

    // Held back behind the slip: never seen, so never marked shown.
    expect(optional(), isEmpty);
    expect(
      container.read(settingsStoreProvider).widgetPromptShown,
      isFalse,
    );

    container.read(quitStoreProvider.notifier).replaceForTest(
      slipping.copyWith(pendingSlipCleanDays: () => null),
    );
    await tester.pumpAndSettle();
    expect(optional(), ['widget']);
  });
}
