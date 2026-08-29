import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/core/widgets/lp_misc.dart';
import 'package:last_puff/data/backend_mode.dart';
import 'package:last_puff/data/network/connectivity.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

/// Shared harness for the on-device end-to-end suites.
///
/// These drive the REAL app — real router, real stores, real platform channels
/// — on a real device. That is the only thing that can prove the pieces work
/// together; the widget suite already pins each piece on its own.
///
/// Two rules shape everything here:
///
/// 1. **Never `pumpAndSettle` blindly.** Several screens animate forever by
///    design (the breathing pacer, the flame, the progress ring), and
///    `pumpAndSettle` on those hangs until the 10-minute timeout rather than
///    failing usefully. [settle] pumps a bounded number of frames instead.
/// 2. **Find by localized text, not by key.** The app is built that way — zero
///    hardcoded UI strings — so the tests read like the screens do, and a
///    string that silently stops being rendered fails a test instead of
///    quietly disappearing.
class E2E {
  E2E(this.tester, this.l10n, this.container);

  final WidgetTester tester;
  final AppLocalizations l10n;
  final ProviderContainer container;

  /// Boots the app the way `main()` does, minus the Firebase init the caller
  /// owns. [online] false pins the connectivity store offline so the airplane
  /// -mode paths can be exercised without touching the device's radio.
  static Future<E2E> boot(
    WidgetTester tester, {
    bool online = true,
    List<Override> overrides = const [],
  }) async {
    final container = ProviderContainer(
      overrides: [
        // Real DNS polling in a test run adds latency and flake for no signal;
        // the connectivity value itself is what the surfaces read.
        connectivityPollIntervalProvider.overrideWithValue(null),
        connectivityProvider.overrideWith(
          () => TestConnectivity(startOnline: online),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    final e2e = E2E(
      tester,
      await AppLocalizations.delegate.load(const Locale('en')),
      container,
    );
    await e2e.settle();
    return e2e;
  }

  BackendMode get backend => container.read(backendModeProvider);

  /// Drops or restores the connection mid-test.
  Future<void> setOnline(bool online) async {
    (container.read(connectivityProvider.notifier) as TestConnectivity)
        .set(online);
    await settle();
  }

  /// Pumps up to [frames] frames at 16ms, stopping early once the tree stops
  /// scheduling work. The bounded form of `pumpAndSettle`.
  Future<void> settle({int frames = 90}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// Pumps real wall-clock time — for anything waiting on a network round-trip
  /// rather than on an animation.
  Future<void> waitFor(Duration d) async {
    final end = DateTime.now().add(d);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// Taps [finder] and settles. Fails with the visible text on screen when the
  /// target is missing, which is far easier to debug on device than "found 0
  /// widgets".
  Future<void> tap(Finder finder, {String? why}) async {
    if (finder.evaluate().isEmpty) {
      fail(
        'Could not tap ${why ?? finder.describeMatch(Plurality.one)}.'
        '\nOn screen: ${texts()}',
      );
    }
    await tester.tap(finder.first, warnIfMissed: false);
    await settle();
  }

  Future<void> tapText(String label) => tap(find.text(label), why: '"$label"');

  /// Taps a [TextSpan] inside a rich text — the "Already have one? **Log in**"
  /// idiom the auth screens use. `find.text` cannot see these: the span is not
  /// its own Text widget, which is exactly how the first run of this suite
  /// failed.
  Future<void> tapSpan(String label) async {
    final range = find.textRange.ofSubstring(label);
    if (range.evaluate().isEmpty) {
      fail('No span "$label".\nOn screen: ${texts()}');
    }
    await tester.tapOnText(range);
    await settle();
  }

  /// Whether [text] is rendered AND hit-testable.
  ///
  /// [showing] is not enough on its own: the offline banner lives in the tree
  /// permanently and is slid off-screen by `AnimatedSlide` when online, so it
  /// matches `find.text` at all times. Anything asserting on visibility rather
  /// than mere presence has to go through here.
  bool visible(String text) => find.text(text).hitTestable().evaluate().isNotEmpty;

  /// Enters [text] into the [LpField] whose label matches — the label is a
  /// sibling Text, not an InputDecoration, so this walks the widget.
  Future<void> enterField(String label, String text) async {
    final field = find.descendant(
      of: find.byWidgetPredicate(
        (w) => w is LpField && w.label.toUpperCase() == label.toUpperCase(),
      ),
      matching: find.byType(TextField),
    );
    if (field.evaluate().isEmpty) {
      fail('No field labelled "$label".\nOn screen: ${texts()}');
    }
    await tester.enterText(field.first, text);
    await settle();
  }

  /// Every string currently rendered — the diagnostic that makes an on-device
  /// failure readable without a screenshot.
  List<String> texts() => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
      .where((s) => s.isNotEmpty)
      .toList();

  bool showing(String text) => find.text(text).evaluate().isNotEmpty;

  /// Pumps until [text] appears, up to [timeout].
  ///
  /// The right primitive for anything transient — snacks in particular, which
  /// auto-dismiss. Asserting after a fixed sleep either races the dismissal or
  /// pads every test with the worst case; this does neither.
  Future<bool> waitForText(
    String text, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      if (find.text(text).evaluate().isNotEmpty) return true;
      await tester.pump(const Duration(milliseconds: 50));
    }
    return false;
  }

  /// Scrolls the nearest scrollable until [finder] is on screen. Several
  /// screens are longer than a phone.
  Future<void> scrollTo(Finder finder) async {
    if (finder.evaluate().isNotEmpty) return;
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) return;
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: scrollable.first,
      maxScrolls: 30,
    );
    await settle();
  }
}

/// Connectivity a test can flip mid-run.
///
/// Booting offline covers the launch paths; flipping it *after* a session
/// exists is what covers the local-first stance — the tap that must still
/// count when the wifi dies halfway through a day.
class TestConnectivity extends ConnectivityStore {
  TestConnectivity({required this.startOnline});

  final bool startOnline;

  @override
  bool build() => startOnline;

  // ignore: use_setters_to_change_properties
  void set(bool online) => state = online;
}
