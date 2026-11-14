import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/update_prompt_policy.dart';

/// The update prompt's rules, each one a line (docs/10 §55).
///
/// Force comes from Remote Config and nowhere else, and only ever means
/// something when the store really has a newer version. Every failure — no
/// flag, no store answer, an unparseable version — fails OPEN: the app is
/// never locked by something it could not read.
void main() {
  group('AppVersion', () {
    test('compares dotted versions by number, not by text', () {
      expect(AppVersion.compare('1.0.33', '1.0.32'), greaterThan(0));
      expect(AppVersion.compare('1.0.10', '1.0.9'), greaterThan(0));
      expect(AppVersion.compare('1.1.0', '1.0.99'), greaterThan(0));
      expect(AppVersion.compare('2.0.0', '10.0.0'), lessThan(0));
      expect(AppVersion.compare('1.0.32', '1.0.32'), 0);
    });

    test('a build number or a missing part does not change the version', () {
      expect(AppVersion.compare('1.0.32+32', '1.0.32'), 0);
      expect(AppVersion.compare('1.0', '1.0.0'), 0);
      expect(AppVersion.compare(' 1.0.32 ', '1.0.32'), 0);
    });

    test('anything unreadable compares as unknown, never as older', () {
      expect(AppVersion.compare(null, '1.0.32'), isNull);
      expect(AppVersion.compare('1.0.32', ''), isNull);
      expect(AppVersion.compare('Varies with device', '1.0.32'), isNull);
      expect(AppVersion.compare('1.x.3', '1.0.32'), isNull);
      expect(AppVersion.isNewer('Varies with device', '1.0.32'), isFalse);
    });
  });

  group('decide', () {
    UpdateKind decide({
      String? installed = '1.0.32',
      String? store = '1.0.33',
      bool force = false,
      bool tooSoon = false,
      bool debugOptional = false,
      bool debugForce = false,
    }) => UpdatePromptPolicy.decide(
      installedVersion: installed,
      storeVersion: store,
      forceFlag: force,
      tooSoon: tooSoon,
      debugOptional: debugOptional,
      debugForce: debugForce,
    );

    test('a newer store version is offered', () {
      expect(decide(), UpdateKind.optional);
    });

    test('the same or an older store version offers nothing', () {
      expect(decide(store: '1.0.32'), UpdateKind.none);
      expect(decide(store: '1.0.31'), UpdateKind.none);
    });

    test('forced = the flag AND a newer store version', () {
      expect(decide(force: true), UpdateKind.forced);
    });

    test('the flag left on with nothing newer shows nothing at all', () {
      expect(decide(force: true, store: '1.0.32'), UpdateKind.none);
      expect(decide(force: true, store: '1.0.30'), UpdateKind.none);
    });

    test('fail open: a store that could not be read never forces', () {
      expect(decide(force: true, store: null), UpdateKind.none);
      expect(decide(force: true, store: 'Varies with device'), UpdateKind.none);
      expect(decide(force: true, installed: null), UpdateKind.none);
    });

    test('"Not now" keeps the optional prompt quiet, never the forced one', () {
      expect(decide(tooSoon: true), UpdateKind.none);
      expect(decide(tooSoon: true, force: true), UpdateKind.forced);
    });

    test('UPGRADER_DEBUG offers the prompt whatever the store says', () {
      expect(decide(debugOptional: true, store: null), UpdateKind.optional);
      expect(decide(debugOptional: true, store: '1.0.32'), UpdateKind.optional);
      expect(decide(debugOptional: true, tooSoon: true), UpdateKind.optional);
    });

    test('UPDATE_FORCE_DEBUG forces without a flag or a store answer', () {
      expect(decide(debugForce: true, store: null), UpdateKind.forced);
      expect(decide(debugForce: true, store: '1.0.32'), UpdateKind.forced);
    });
  });

  group('where the forced screen may stand', () {
    bool may(UpdateSurface s, {bool sheet = false}) =>
        UpdatePromptPolicy.forcedMayShow(surface: s, storeSheetOpen: sheet);

    test('anywhere once the splash has decided — sign-in and the quiz too', () {
      for (final s in [
        UpdateSurface.home,
        UpdateSurface.auth,
        UpdateSurface.onboarding,
        UpdateSurface.dayOne,
        UpdateSurface.paywall,
        UpdateSurface.other,
      ]) {
        expect(may(s), isTrue, reason: s.name);
      }
    });

    test('never over the splash, a craving or the Survived screen', () {
      expect(may(UpdateSurface.splash), isFalse);
      expect(may(UpdateSurface.panic), isFalse);
      expect(may(UpdateSurface.survived), isFalse);
    });

    test('never while a store sheet is open', () {
      expect(may(UpdateSurface.paywall, sheet: true), isFalse);
      expect(may(UpdateSurface.home, sheet: true), isFalse);
    });
  });

  group('where the optional prompt and What\'s New may open', () {
    bool may(UpdateSurface s, {bool onTop = true, bool tour = false}) =>
        UpdatePromptPolicy.promptMayShow(
          surface: s,
          onTop: onTop,
          tourRunning: tour,
        );

    test('only over the signed-in Home', () {
      expect(may(UpdateSurface.home), isTrue);
      for (final s in UpdateSurface.values.where(
        (s) => s != UpdateSurface.home,
      )) {
        expect(may(s), isFalse, reason: s.name);
      }
    });

    test('not when Home is covered, or during the Day-1 tour', () {
      expect(may(UpdateSurface.home, onTop: false), isFalse);
      expect(may(UpdateSurface.home, tour: true), isFalse);
    });
  });

  group('one modal a visit, in order', () {
    bool may(
      AppModal m, {
      Set<AppModal> shown = const {},
      Set<AppModal> waiting = const {},
    }) => UpdatePromptPolicy.mayOpen(m, shownThisVisit: shown, waiting: waiting);

    test('the priority is forced > update > what\'s new > push ask > rating', () {
      expect(AppModal.values, [
        AppModal.forcedUpdate,
        AppModal.updatePrompt,
        AppModal.whatsNew,
        AppModal.pushAsk,
        AppModal.ratingAsk,
      ]);
    });

    test('anything opens on a quiet visit', () {
      for (final m in AppModal.values) {
        expect(may(m), isTrue, reason: m.name);
      }
    });

    test('a second modal waits for the next visit', () {
      expect(may(AppModal.whatsNew, shown: {AppModal.updatePrompt}), isFalse);
      expect(may(AppModal.updatePrompt, shown: {AppModal.pushAsk}), isFalse);
      expect(may(AppModal.pushAsk, shown: {AppModal.whatsNew}), isFalse);
      expect(may(AppModal.ratingAsk, shown: {AppModal.whatsNew}), isFalse);
    });

    test('a lower modal yields to a higher one still waiting', () {
      expect(
        may(AppModal.whatsNew, waiting: {AppModal.updatePrompt}),
        isFalse,
      );
      // A lower one waiting never holds a higher one back.
      expect(may(AppModal.updatePrompt, waiting: {AppModal.whatsNew}), isTrue);
    });

    test('the forced screen ignores the visit — it is not optional', () {
      expect(
        may(
          AppModal.forcedUpdate,
          shown: {AppModal.whatsNew, AppModal.pushAsk},
        ),
        isTrue,
      );
    });
  });

  group('What\'s New', () {
    bool due({
      String? installed = '1.0.32',
      String? seen,
      bool hasNotes = true,
      bool hydrated = true,
    }) => UpdatePromptPolicy.whatsNewDue(
      installedVersion: installed,
      lastSeenVersion: seen,
      hasNotes: hasNotes,
      hydrated: hydrated,
    );

    test('once per version: a fresh install and an update both see it', () {
      expect(due(seen: null), isTrue);
      expect(due(seen: '1.0.31'), isTrue);
      expect(due(seen: '1.0.32'), isFalse);
    });

    test('not before settings have answered — the default reads as unseen', () {
      expect(due(hydrated: false), isFalse);
    });

    test('not without an installed version or a catalog entry', () {
      expect(due(installed: null), isFalse);
      expect(due(hasNotes: false), isFalse);
    });
  });
}
