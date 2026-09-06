import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// Notification preferences have to reach the SERVER, because the server is
/// what sends.
///
/// Turning notifications off used to cancel the locally scheduled reminders
/// and tell the backend nothing at all — so every server push kept arriving,
/// on an app the user had just told to be quiet. The master switch was the
/// one control somebody reaches for when an app is bothering them, and it
/// only worked on half the problem.
void main() {
  ProviderContainer open(_RecordingContext context) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        userContextRepositoryProvider.overrideWithValue(context),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the master switch reaches the server', () async {
    final context = _RecordingContext();
    final container = open(context);
    container.read(settingsStoreProvider.notifier).setNotifications(false);

    expect(context.prefs.last['all'], isFalse);
  });

  test('each category reaches the server on its own key', () async {
    final context = _RecordingContext();
    final container = open(context);
    final store = container.read(settingsStoreProvider.notifier);

    store.setPushReplies(false);
    expect(context.prefs.last['communityReply'], isFalse);
    store.setPushMentions(false);
    expect(context.prefs.last['communityMention'], isFalse);
    store.setPushWeekly(false);
    expect(context.prefs.last['insightReady'], isFalse);
  });

  test('every send carries the whole picture, not just what changed', () {
    // The server stores what it is given. A partial map would leave the two
    // sides disagreeing about anything not mentioned.
    final context = _RecordingContext();
    final container = open(context);
    container.read(settingsStoreProvider.notifier).setPushReplies(false);

    expect(context.prefs.last.keys, containsAll(<String>[
      'all',
      'communityReply',
      'communityMention',
      'insightReady',
      'quietStart',
      'quietEnd',
    ]));
  });

  test('the quiet window travels with the preferences', () {
    final context = _RecordingContext();
    final container = open(context);
    final store = container.read(settingsStoreProvider.notifier);
    store.setQuietHours(22, 7);
    store.setPushReplies(true);

    expect(context.prefs.last['quietStart'], 22);
    expect(context.prefs.last['quietEnd'], 7);
  });

  test('signing out forgets them, so a shared phone does not inherit', () {
    // Device-scoped storage with no uid in the key — the same shape that
    // produced the milestone-ledger bug.
    final context = _RecordingContext();
    final container = open(context);
    final store = container.read(settingsStoreProvider.notifier);
    store.setPushReplies(false);
    store.setPushMentions(false);
    expect(container.read(settingsStoreProvider).pushRepliesOn, isFalse);

    store.resetMilestoneLedger();

    expect(container.read(settingsStoreProvider).pushRepliesOn, isTrue);
    expect(container.read(settingsStoreProvider).pushMentionsOn, isTrue);
    expect(container.read(settingsStoreProvider).pushWeeklyOn, isTrue);
  });

  test('the defaults are on, so nothing needs a migration', () {
    final container = open(_RecordingContext());
    final settings = container.read(settingsStoreProvider);

    expect(settings.pushRepliesOn, isTrue);
    expect(settings.pushMentionsOn, isTrue);
    expect(settings.pushWeeklyOn, isTrue);
  });
}

class _RecordingContext implements UserContextRepository {
  final prefs = <Map<String, Object?>>[];

  @override
  Future<void> sync({
    String? fcmToken,
    Map<String, Object?>? pushPrefs,
    List<String>? readThreads,
    List<String>? readNotifications,
  }) async {
    if (pushPrefs != null) prefs.add(pushPrefs);
  }

  @override
  Future<void> unregister() async {}
}
