// Riverpod 3 retries every failing provider by default (ten times, backing
// off to 6.4s, ~45s in all) and reports the whole time as `AsyncLoading`.
// Every surface in this app that can fail is built on the opposite contract:
// the first failure is the answer — `AsyncError` reaches `LpErrorState` and
// its "Try again" (docs/CLAUDE.md "Error handling"), never a spinner that
// sits for most of a minute and then fails anyway. Each retry is also a
// pending `Timer`, which fails every widget test that meets one.
//
// So the app's failing-capable async providers opt out with `lpNoRetry`, and
// this file pins it by driving the REAL providers against a backend that is
// down — the same way `test/widgets/error_handling_test.dart` drives screens.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';

import '../helpers.dart';

/// A moderation backend that is unreachable.
class _DownModeration implements ModerationRepository {
  @override
  Future<bool> isModerator() => Future.error(const NoConnectionException());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownServerState implements ServerStateRepository {
  @override
  Future<WeeklyInsight?> latestInsight() =>
      Future.error(const NoConnectionException());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownCoach implements CoachRepository {
  @override
  Future<List<CoachMemory>> memories() =>
      Future.error(const NoConnectionException());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _DownAuth implements AuthRepository, SignInMethodSource {
  @override
  Future<AccountProvider?> signInProvider() =>
      Future.error(const NoConnectionException());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Where an async provider is built without `retry: lpNoRetry`, as
/// `path:line` — the rule `CLAUDE.md` states, read off the source because a
/// new provider that forgets it fails no other test.
///
/// Whole-line comments are skipped; the argument list is read to its balanced
/// closing parenthesis, so a `retry:` belonging to the NEXT provider cannot
/// satisfy this one.
List<String> missingNoRetry(String source, String path) {
  final construction = RegExp(
    r'\b(FutureProvider|StreamProvider|AsyncNotifierProvider|'
    r'StreamNotifierProvider)\b(\.autoDispose|\.family)*(<[^(]*>)?\(',
  );
  final missing = <String>[];
  for (final m in construction.allMatches(source)) {
    final lineStart = source.lastIndexOf('\n', m.start) + 1;
    if (source.substring(lineStart, m.start).trimLeft().startsWith('//')) {
      continue;
    }
    var depth = 1;
    var i = m.end;
    while (i < source.length && depth > 0) {
      final c = source[i++];
      if (c == '(') depth++;
      if (c == ')') depth--;
    }
    if (!source.substring(m.end, i).contains('retry: lpNoRetry')) {
      final line = '\n'.allMatches(source.substring(0, m.start)).length + 1;
      missing.add('$path:$line');
    }
  }
  return missing;
}

void main() {
  group('every async provider says it does not retry', () {
    test('the scanner flags a provider with no retry, and only that one', () {
      const source = '''
final a = FutureProvider<int>((ref) async => 1, retry: lpNoRetry);
// final c = FutureProvider<int>((ref) async => 3);
final b = FutureProvider.autoDispose<List<int>>((ref) async => []);
final d = FutureProvider<int>((ref) async => 4, retry: lpNoRetry);
''';
      // `b` is on line 3; `d`'s `retry:` must not rescue it, and the commented
      // provider on line 2 is not code.
      expect(missingNoRetry(source, 'x.dart'), ['x.dart:3']);
    });

    test('the scanner reads a multi-line argument list to its own close', () {
      const source = '''
final a = FutureProvider<String?>((ref) async {
  try {
    return (await load()).version;
  } on Object {
    return null;
  }
}, retry: lpNoRetry);
''';
      expect(missingNoRetry(source, 'x.dart'), isEmpty);
    });

    test('every FutureProvider/StreamProvider/AsyncNotifierProvider in lib', () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart') && !f.path.contains('/gen/'));
      final missing = <String>[];
      var found = 0;
      for (final file in files) {
        final source = file.readAsStringSync();
        found += RegExp(
          r'\b(FutureProvider|StreamProvider|AsyncNotifierProvider|'
          r'StreamNotifierProvider)\b',
        ).allMatches(source).length;
        missing.addAll(missingNoRetry(source, file.path));
      }
      expect(found, greaterThan(0), reason: 'the scan found nothing to check');
      expect(
        missing,
        isEmpty,
        reason:
            'Riverpod 3 retries a failing provider ten times and reports '
            'AsyncLoading meanwhile; pass `retry: lpNoRetry` (providers.dart)',
      );
    });
  });

  // One row per failing-capable provider that has a repository behind it.
  // (`offerings`, `reviewRoute`, `installedVersion` and `appVersion` swallow
  // their own failures into null/none, so there is nothing for them to retry.)
  final cases =
      <String, ({Override down, ProviderListenable<AsyncValue<Object?>> p})>{
        'isModeratorProvider': (
          down: moderationRepositoryProvider.overrideWithValue(
            _DownModeration(),
          ),
          p: isModeratorProvider,
        ),
        'weeklyInsightProvider': (
          down: serverStateRepositoryProvider.overrideWithValue(
            _DownServerState(),
          ),
          p: weeklyInsightProvider,
        ),
        'coachMemoriesProvider': (
          down: coachRepositoryProvider.overrideWithValue(_DownCoach()),
          p: coachMemoriesProvider,
        ),
        'accountProviderProvider': (
          down: authRepositoryProvider.overrideWithValue(_DownAuth()),
          p: accountProviderProvider,
        ),
      };

  for (final entry in cases.entries) {
    test(
      '${entry.key}: the first failure is the answer, not a retry',
      () async {
        final container = ProviderContainer(
          overrides: [...fastBackendOverrides(), entry.value.down],
        );
        addTearDown(container.dispose);
        // autoDispose providers need a listener to stay alive across the await.
        container.listen(entry.value.p, (_, _) {}, fireImmediately: true);

        // Let the failing future and its microtasks land — nowhere near the
        // 200ms the first retry would wait.
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final state = container.read(entry.value.p);
        expect(state, isA<AsyncError<Object?>>());
        expect(state.isLoading, isFalse, reason: 'a retry reads as loading');
        expect(state.error, isA<NoConnectionException>());
      },
    );
  }
}
