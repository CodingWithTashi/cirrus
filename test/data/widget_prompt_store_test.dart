import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/api/widget_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/data/stores/settings_store.dart';
import 'package:last_puff/data/stores/widget_prompt_store.dart';
import 'package:last_puff/domain/logic/widget_prompt_policy.dart';

import '../helpers.dart';

/// docs/15 QP-C2: the view model behind the one-time home-screen widget card.
///
/// It owns what the card needs and a pure policy cannot: what this device can
/// do (read once from the launcher), whether the card is up THIS visit, and
/// whether a request is waiting to be confirmed. The system dialog has no
/// callback, so "installed" is only ever learned by asking again on resume.
void main() {
  late MemoryWidgetStore widgets;
  late RecordingAnalytics analytics;

  /// An Android launcher that can add a widget, with none placed.
  MemoryWidgetStore android() => MemoryWidgetStore()
    ..pinSupported = true
    ..installed = 0;

  ProviderContainer open({
    MemoryWidgetStore? store,
    SettingsStore Function()? settings,
  }) {
    widgets = store ?? android();
    analytics = RecordingAnalytics();
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(analytics: analytics),
        widgetStoreProvider.overrideWithValue(widgets),
        if (settings != null) settingsStoreProvider.overrideWith(settings),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  WidgetPromptStore prompt(ProviderContainer c) =>
      c.read(widgetPromptProvider.notifier);
  WidgetPromptState state(ProviderContainer c) => c.read(widgetPromptProvider);

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('what the device can do', () {
    test('an Android launcher that can add a widget: the system dialog', () async {
      final c = open();
      await prompt(c).probe();

      expect(state(c).way, WidgetAddWay.pinDialog);
      expect(state(c).installed, 0);
    });

    test('a launcher that cannot add one: no way, so no card', () async {
      final c = open(store: MemoryWidgetStore()..installed = 0);
      await prompt(c).probe();

      expect(state(c).way, isNull);
    });

    test('an iPhone: the walkthrough, though the plugin cannot pin there', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final c = open(store: MemoryWidgetStore()..installed = 0);
      await prompt(c).probe();

      expect(state(c).way, WidgetAddWay.walkthrough);
    });

    test('a device with no widget host reads as unknown, never as zero', () async {
      // Desktop and the fake backend: nothing to count.
      final c = open(store: MemoryWidgetStore());
      await prompt(c).probe();

      expect(state(c).installed, isNull);
    });
  });

  group('showing it', () {
    test('marks it shown, puts it up, and reports it once', () async {
      final c = open();
      await prompt(c).probe();

      prompt(c).show();
      prompt(c).show(); // every Home rebuild before the flag lands says so again

      expect(state(c).visible, isTrue);
      expect(c.read(settingsStoreProvider).widgetPromptShown, isTrue);
      expect(analytics.propsOfAll('widget_prompt_shown'), [
        {'way': 'pinDialog'},
      ]);
    });

    test('with no way to add one it shows nothing and marks nothing', () async {
      final c = open(store: MemoryWidgetStore()..installed = 0);
      await prompt(c).probe();

      prompt(c).show();

      expect(state(c).visible, isFalse);
      expect(c.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));
    });

    test('before settings have hydrated, it waits: no card, no write', () async {
      // The defaults are not the person's choices, and an automatic writer
      // that acts on them persists the default over the stored value. A
      // cold start where this ran first would also mark "shown" for a card
      // the stored flag says was already seen.
      final cold = _ColdSettings();
      final c = open(settings: () => cold);
      await prompt(c).probe();

      prompt(c).show();

      expect(state(c).visible, isFalse);
      expect(c.read(settingsStoreProvider).widgetPromptShown, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_shown')));

      cold.hydrateNow();
      prompt(c).show();

      expect(state(c).visible, isTrue);
      expect(c.read(settingsStoreProvider).widgetPromptShown, isTrue);
    });
  });

  group('adding it on Android', () {
    test('accepting opens the system dialog once and takes the card down', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();

      await prompt(c).accept();

      expect(widgets.pinRequests, 1);
      expect(state(c).visible, isFalse);
      expect(analytics.propsOfAll('widget_prompt_accepted'), [
        {'way': 'pinDialog'},
      ]);
      // The dialog has no callback: nothing is known to be installed yet.
      expect(analytics.names, isNot(contains('widget_installed')));
    });

    test('the widget is found on resume, reported once, and never twice', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();
      await prompt(c).accept();

      widgets.placeWidget(); // the person confirms in the launcher's dialog
      await prompt(c).resume();
      await prompt(c).resume();
      await prompt(c).resume();

      expect(analytics.names.where((n) => n == 'widget_installed'), hasLength(1));
      expect(state(c).installed, 1);
    });

    test('a dialog that was cancelled reports nothing installed', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();
      await prompt(c).accept();

      await prompt(c).resume(); // back from the dialog, nothing was added

      expect(analytics.names, isNot(contains('widget_installed')));
      expect(state(c).installed, 0);
    });

    test('a request the launcher refuses is not an acceptance', () async {
      final c = open(store: _RefusingStore());
      await prompt(c).probe();
      prompt(c).show();

      await prompt(c).accept();

      // No dialog opened, so the card goes rather than keep a dead button, and
      // nothing is reported as accepted.
      expect(state(c).visible, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_accepted')));
    });

    test('a widget added some other way is not credited to the card', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();

      widgets.placeWidget(); // from the launcher's own picker, card untouched
      await prompt(c).resume();

      expect(analytics.names, isNot(contains('widget_installed')));
      expect(state(c).installed, 1);
    });
  });

  group('adding it on an iPhone', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);

    test('"Got it" asks nothing of the OS, and the widget is found on resume', () async {
      final c = open(store: MemoryWidgetStore()..installed = 0);
      await prompt(c).probe();
      prompt(c).show();

      await prompt(c).accept();

      expect(widgets.pinRequests, 0);
      expect(state(c).visible, isFalse);
      expect(analytics.propsOfAll('widget_prompt_accepted'), [
        {'way': 'walkthrough'},
      ]);

      widgets.placeWidget();
      await prompt(c).resume();
      expect(analytics.names.where((n) => n == 'widget_installed'), hasLength(1));
    });
  });

  group('declining', () {
    test('takes the card down and reports no acceptance', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();

      prompt(c).decline();

      expect(state(c).visible, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_accepted')));
      // And a widget placed later is nobody's doing but the person's.
      widgets.placeWidget();
      await prompt(c).resume();
      expect(analytics.names, isNot(contains('widget_installed')));
    });
  });

  group('a widget that is already there', () {
    test('takes a card that is up back down on the next read', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();

      widgets.placeWidget();
      await prompt(c).resume();

      expect(state(c).visible, isFalse);
    });
  });

  group('a tap that lands twice', () {
    test('asks the launcher once and reports one acceptance', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();

      // The button is still on screen until the dialog has been requested, so
      // a double tap arrives before the first call has returned.
      await Future.wait([prompt(c).accept(), prompt(c).accept()]);

      expect(widgets.pinRequests, 1);
      expect(analytics.propsOfAll('widget_prompt_accepted'), hasLength(1));
    });
  });

  group('a call still in flight when the account goes', () {
    test('does not write into the next account\'s state', () async {
      final gate = _GatedStore();
      final c = open(store: gate);
      final journey = c.read(quitStoreProvider.notifier);
      await journey.logIn(email: 'maya@quitmail.com', password: 'secret1');
      await prompt(c).probe();
      prompt(c).show();

      final answering = prompt(c).accept(); // waiting on the launcher
      await Future<void>.delayed(Duration.zero);
      journey.signOut(); // invalidates the store; the next account builds a new one
      expect(state(c).requested, isFalse);

      gate.release();
      await answering;

      // The old account's request must not arm the new account's install check.
      expect(state(c).requested, isFalse);
      expect(state(c).visible, isFalse);
      expect(analytics.names, isNot(contains('widget_prompt_accepted')));
    });

    test('a container gone before the first read lands throws nothing', () async {
      final errors = <Object>[];
      await runZonedGuarded(() async {
        final c = ProviderContainer(
          overrides: [
            ...fastBackendOverrides(),
            widgetStoreProvider.overrideWithValue(android()),
          ],
        );
        c.read(widgetPromptProvider); // starts the first read
        c.dispose(); // before its microtask has run
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    });
  });

  group('asking the launcher again on resume', () {
    test('is skipped once the offer has been made and nothing is waiting', () async {
      final c = open();
      await prompt(c).probe();
      prompt(c).show();
      prompt(c).decline();
      final before = widgets.reads;

      await prompt(c).resume();
      await prompt(c).resume();

      expect(widgets.reads, before);
    });

    test('still keeps the count fresh before the offer has been made', () async {
      // A widget added by hand in the meantime must not leave a stale zero
      // behind: the offer would then be made to somebody who already has it.
      final c = open();
      await prompt(c).probe();
      widgets.placeWidget();

      await prompt(c).resume();

      expect(state(c).installed, 1);
    });

    test('and is skipped on a device with no way to add one', () async {
      final c = open(store: MemoryWidgetStore()..installed = 0);
      await prompt(c).probe();
      final before = widgets.reads;

      await prompt(c).resume();

      expect(widgets.reads, before);
    });
  });

  test('forgetting an offer that was never made changes nothing', () async {
    // A second whole-blob write on every sign-out, for a flag that is already
    // false, buys nothing.
    final c = open();
    final before = c.read(settingsStoreProvider);

    c.read(settingsStoreProvider.notifier).resetWidgetPrompt();

    expect(identical(c.read(settingsStoreProvider), before), isTrue);
  });

  test('signing out forgets all of it, so the next account starts clean', () async {
    final c = open();
    final journey = c.read(quitStoreProvider.notifier);
    await journey.logIn(email: 'maya@quitmail.com', password: 'secret1');
    await prompt(c).probe();
    prompt(c).show();
    expect(state(c).visible, isTrue);

    journey.signOut();

    // Still latched, the card would reach the next person's Home without the
    // policy ever being asked.
    expect(state(c).visible, isFalse);
    expect(state(c).requested, isFalse);
    expect(c.read(settingsStoreProvider).widgetPromptShown, isFalse);
  });

  test('deleting the account forgets all of it too', () async {
    final c = open();
    final journey = c.read(quitStoreProvider.notifier);
    await journey.logIn(email: 'maya@quitmail.com', password: 'secret1');
    await prompt(c).probe();
    prompt(c).show();
    expect(state(c).visible, isTrue);

    await journey.deleteAccount();

    expect(state(c).visible, isFalse);
    expect(c.read(settingsStoreProvider).widgetPromptShown, isFalse);
  });
}

/// A launcher whose answer to "add the widget" waits until the test lets it go.
class _GatedStore extends MemoryWidgetStore {
  _GatedStore() {
    pinSupported = true;
    installed = 0;
  }

  final Completer<void> _open = Completer<void>();

  void release() => _open.complete();

  @override
  Future<bool> requestPin() async {
    await _open.future;
    return super.requestPin();
  }
}

/// A launcher that says it can add a widget and then fails the request.
class _RefusingStore extends MemoryWidgetStore {
  _RefusingStore() {
    pinSupported = true;
    installed = 0;
  }

  @override
  Future<bool> requestPin() async => false;
}

/// Settings as they are on a cold start before SharedPreferences has answered.
class _ColdSettings extends SettingsStore {
  _ColdSettings() : super(restore: false);

  @override
  SettingsState build() => const SettingsState(hydrated: false);

  void hydrateNow() => state = state.copyWith(hydrated: true);
}
