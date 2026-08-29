import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';
import 'providers.dart';

/// Lifecycle of the queue fetch. Same three states as the community feed, and
/// for the same reason: a failed load has to be visibly failed and retryable,
/// never an empty list that reads as "nothing to review".
enum ModerationStatus { loading, ready, failed }

class ModerationState {
  const ModerationState({
    this.items = const [],
    this.status = ModerationStatus.loading,
    this.includeReviewed = false,
    this.resolving = const {},
  });

  final List<ModerationItem> items;
  final ModerationStatus status;

  /// Whether already-reviewed flags are included — an audit view, off by
  /// default because the daily job is the unreviewed ones.
  final bool includeReviewed;

  /// Post ids with a resolve in flight, so their row can go busy.
  final Set<String> resolving;

  ModerationState copyWith({
    List<ModerationItem>? items,
    ModerationStatus? status,
    bool? includeReviewed,
    Set<String>? resolving,
  }) => ModerationState(
    items: items ?? this.items,
    status: status ?? this.status,
    includeReviewed: includeReviewed ?? this.includeReviewed,
    resolving: resolving ?? this.resolving,
  );
}

/// View model of the founder's review queue.
///
/// Deliberately NOT optimistic, unlike every other store here. A moderation
/// decision is the one place where showing the user a result the server did
/// not accept is dangerous: the founder would tick a report off the list and
/// move on while the post stayed live, and Guideline 1.2's 24-hour commitment
/// would be quietly broken by an offline moment.
class ModerationStore extends AutoDisposeNotifier<ModerationState> {
  bool _disposed = false;

  ModerationRepository get _repo => ref.read(moderationRepositoryProvider);

  @override
  ModerationState build() {
    ref.onDispose(() => _disposed = true);
    // Kicks the fetch without READING OR WRITING `state` — build() has not
    // returned yet, and either one throws. `includeReviewed` is therefore
    // passed as an argument rather than read off the state, which is also
    // what makes the toggle path below a single assignment.
    unawaited(_fetch(includeReviewed: false));
    return const ModerationState();
  }

  /// Retry CTA on the error state.
  Future<void> load() async {
    state = state.copyWith(status: ModerationStatus.loading);
    await _fetch(includeReviewed: state.includeReviewed);
  }

  Future<void> _fetch({required bool includeReviewed}) async {
    try {
      final items = await _repo.queue(includeReviewed: includeReviewed);
      if (_disposed) return;
      state = state.copyWith(items: items, status: ModerationStatus.ready);
    } on Object {
      // Offline, or the claim was revoked between opening Settings and
      // opening the queue — the screen offers a retry either way.
      if (_disposed) return;
      state = state.copyWith(status: ModerationStatus.failed);
    }
  }

  Future<void> setIncludeReviewed({required bool value}) {
    state = state.copyWith(
      includeReviewed: value,
      status: ModerationStatus.loading,
    );
    return _fetch(includeReviewed: value);
  }

  /// Resolves one flag. Returns false when the server refused, so the caller
  /// can surface it — the row stays in the list either way until a reload
  /// proves it gone.
  Future<bool> resolve(String postId, {ModerationResolution? action}) async {
    state = state.copyWith(resolving: {...state.resolving, postId});
    try {
      await _repo.resolve(postId, action: action);
    } on Object {
      if (!_disposed) {
        state = state.copyWith(
          resolving: {...state.resolving}..remove(postId),
        );
      }
      return false;
    }
    if (_disposed) return true;
    state = state.copyWith(
      // Dropped locally rather than re-fetched: the queue is paged and a
      // reload after every decision would re-walk it 50 rows at a time.
      items: [...state.items]..removeWhere((i) => i.postId == postId),
      resolving: {...state.resolving}..remove(postId),
    );
    return true;
  }
}
