import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `firestore.indexes.json` is a shippability gate, so it gets a test.
///
/// The trap it exists for is that a **`fieldOverride` REPLACES Firestore's
/// automatic single-field indexes for that field** rather than adding to them.
/// Declaring one scope to gain a collection-group query silently DELETES every
/// index you did not list — including the ordinary collection-scoped ones the
/// app was relying on and nobody thought to write down.
///
/// That is exactly what happened to the notification inbox. The override on
/// `notifications.createdAtMs` was added so `pruneOldNotifications` could run a
/// collection-group sweep, and it listed only ASCENDING. The app reads the
/// inbox newest-first, so its query needed COLLECTION+DESCENDING — which the
/// override had just removed. Every inbox read in production answered
/// `FAILED_PRECONDITION: The query requires a COLLECTION_DESC index`.
///
/// It was invisible from every direction. `NotificationsStore` treats a stream
/// error as an empty inbox on purpose ("an inbox that cannot load is an empty
/// inbox, not an error screen"), so the screen rendered its honest empty state
/// and the bell showed no badge — for every user, with the rules, the send path
/// and the cron all green, and nothing logged anywhere. The emulator does not
/// enforce single-field indexes either, so `npm run test:rules` and
/// `test:integration` both passed.
///
/// So: every field this project overrides is listed here with the query that
/// needs each scope, and adding a scope is never additive.
void main() {
  final root = Directory.current.path;
  final config =
      jsonDecode(File('$root/firestore.indexes.json').readAsStringSync())
          as Map<String, dynamic>;
  final overrides =
      (config['fieldOverrides'] as List).cast<Map<String, dynamic>>();

  Set<String> configsFor(String collection, String field) {
    final match = overrides.singleWhere(
      (o) => o['collectionGroup'] == collection && o['fieldPath'] == field,
      orElse: () => throw StateError(
        'No fieldOverride for $collection.$field. If it was removed on '
        'purpose, remove its case here too — but read this file first: an '
        'override is not additive, and neither is deleting one.',
      ),
    );
    return {
      for (final index in (match['indexes'] as List).cast<Map<String, dynamic>>())
        '${index['queryScope']}:${index['order']}',
    };
  }

  group('fieldOverrides cover every scope the code queries', () {
    test('notifications.createdAtMs', () {
      final scopes = configsFor('notifications', 'createdAtMs');

      // FirebaseNotificationsRepository.watch() — the in-app inbox and the
      // unread badge. This is the one the override deleted.
      expect(
        scopes,
        contains('COLLECTION:DESCENDING'),
        reason: 'The app reads the inbox newest-first. Without this the '
            'inbox is empty and the bell never badges, silently.',
      );
      // pruneOldNotifications — the 30-day sweep, oldest-first.
      expect(scopes, contains('COLLECTION_GROUP:ASCENDING'));
    });

    test('notifThreads.lastReplyAtMs', () {
      // pruneStaleThreads only, and only ascending.
      expect(
        configsFor('notifThreads', 'lastReplyAtMs'),
        contains('COLLECTION_GROUP:ASCENDING'),
      );
    });

    test('devices.lastSeenAt', () {
      // pruneStaleDevices only, and only ascending.
      expect(
        configsFor('devices', 'lastSeenAt'),
        contains('COLLECTION_GROUP:ASCENDING'),
      );
    });

    test('replies.status', () {
      // FirebaseCommunityRepository.fetchPosts() loads a whole feed's replies
      // in one collection-group query. Equality only — the ordering is done
      // in memory by `_ordered`, which is what keeps this single-field.
      final scopes = configsFor('replies', 'status');
      expect(scopes, contains('COLLECTION_GROUP:ASCENDING'));
      expect(scopes, contains('COLLECTION:ASCENDING'));
    });

    test('reactors.uid', () {
      // "Which posts did I react to?", one query instead of one read per post.
      expect(
        configsFor('reactors', 'uid'),
        contains('COLLECTION_GROUP:ASCENDING'),
      );
    });
  });

  test('the inbox query still orders the way the index says it does', () {
    // The pairing is the whole point: this test is what turns "somebody
    // flipped the sort order" into a red test rather than an empty screen.
    final source = File(
      '$root/lib/data/repositories/firebase_notifications_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("orderBy('createdAtMs', descending: true)"),
      reason: 'If the inbox no longer reads newest-first, update the '
          'notifications.createdAtMs override to match — a fieldOverride '
          'lists every scope the field is queried with, and only those.',
    );
  });

  test('every override declares at least one scope', () {
    // An override with an empty `indexes` array is how you turn indexing OFF
    // for a field. Nothing here wants that, and it would read as a formatting
    // accident rather than the outage it is.
    for (final override in overrides) {
      expect(
        override['indexes'],
        isA<List<dynamic>>().having((l) => l.length, 'length', greaterThan(0)),
        reason: 'Empty indexes on ${override['collectionGroup']}.'
            '${override['fieldPath']} disables indexing for that field.',
      );
    }
  });
}
