import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import 'providers.dart';

class NotificationsState {
  const NotificationsState({this.items = const [], this.loading = true});

  final List<AppNotification> items;
  final bool loading;

  /// What the badge shows. Zero renders nothing at all rather than a `0`.
  int get unread => items.where((n) => n.isUnread).length;

  NotificationsState copyWith({
    List<AppNotification>? items,
    bool? loading,
  }) => NotificationsState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
  );
}

/// The in-app inbox.
///
/// Read-only from the client: the rows are the server's record of what it told
/// this account. The one thing the app may change is whether a row has been
/// read, and even that goes back through `syncUserContext` rather than a
/// direct write, because `users/{uid}` is server-owned.
///
/// Marking read is optimistic. The badge has to drop the instant somebody
/// opens the screen — waiting for a round trip to decide whether a number goes
/// away is the wrong trade for a courtesy surface, and a failed write costs a
/// badge that comes back on the next launch.
class NotificationsStore extends Notifier<NotificationsState> {
  StreamSubscription<List<AppNotification>>? _sub;

  @override
  NotificationsState build() {
    // Plain fields survive `invalidateSelf`, and this notifier is rebuilt on
    // sign-in; a stale subscription would keep the last account's inbox on
    // screen. Cancel first, always.
    _sub?.cancel();
    _sub = null;

    final repo = ref.watch(notificationsRepositoryProvider);
    _sub = repo.watch().listen(
      (items) => state = NotificationsState(items: items, loading: false),
      // An inbox that cannot load is an empty inbox, not an error screen.
      // Nothing here is load-bearing enough to interrupt somebody over.
      onError: (Object _) => state = state.copyWith(loading: false),
    );
    ref.onDispose(() {
      _sub?.cancel();
      _sub = null;
    });
    return const NotificationsState();
  }

  /// Marks everything currently unread as read, locally and on the server.
  void markAllRead() {
    final unread = [for (final n in state.items) if (n.isUnread) n.id];
    if (unread.isEmpty) return;
    _apply(unread);
  }

  /// Marks one row read — what opening it from the list does.
  void markRead(String id) {
    final target = state.items.where((n) => n.id == id).firstOrNull;
    if (target == null || !target.isUnread) return;
    _apply([id]);
  }

  void _apply(List<String> ids) {
    final now = ref.read(nowProvider)();
    state = state.copyWith(
      items: [
        for (final n in state.items)
          ids.contains(n.id) ? n.copyWith(readAt: now) : n,
      ],
    );
    ref
        .read(userContextRepositoryProvider)
        .sync(readNotifications: ids)
        .ignore();
  }
}
