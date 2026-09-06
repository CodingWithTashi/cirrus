import 'dart:async';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import '../api/fake/fake_server.dart';

/// The inbox on the demo backend.
///
/// Rows come from the same events the real backend generates them from — a
/// reply landing on a post this account wrote — never from a seed. A seeded
/// notification would render to the reader as something that happened to
/// *them*, which is the rule this app breaks hardest when it breaks it at all.
///
/// It exists rather than being stubbed empty because every widget test runs on
/// this backend, and an inbox nothing can put anything into is an inbox
/// nothing can test.
class FakeNotificationsRepository implements NotificationsRepository {
  FakeNotificationsRepository(this._server);

  final FakeServer _server;

  @override
  Stream<List<AppNotification>> watch() async* {
    // Driven by the server's own change signal, never a poll. A periodic timer
    // here leaked into every widget test that pumps the app, and there was
    // nothing to poll for anyway: the store being watched is in memory in this
    // isolate, so it can simply say when it moved.
    //
    // The current contents come first, so a widget that subscribes after the
    // event has already happened still renders it.
    yield _current();
    yield* _server.notificationsChanged.map((_) => _current());
  }

  List<AppNotification> _current() =>
      [for (final row in _server.notificationsForSession()) _decode(row)];

  AppNotification _decode(Map<String, dynamic> data) => AppNotification(
    id: data['id'] as String,
    kind: data['kind'] as String? ?? 'system',
    title: data['title'] as String? ?? '',
    body: data['body'] as String? ?? '',
    route: data['route'] as String?,
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (data['createdAtMs'] as num?)?.toInt() ?? 0,
    ),
    readAt: data['readAtMs'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (data['readAtMs'] as num).toInt(),
          ),
  );
}
