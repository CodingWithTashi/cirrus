import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/memories_screen.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// "What Ember remembers" — the screen that makes the coach's memory something
/// a person can inspect and revoke rather than something to be uneasy about.
///
/// One behaviour matters more than the rest: **forgetting is never optimistic.**
/// Telling someone a personal disclosure is gone while it is still stored is
/// the exact failure this screen exists to prevent.
void main() {
  const remembered = CoachMemory(
    id: 'm1',
    text: 'Their sister Maya is getting married in March.',
    kind: MemoryKind.person,
  );

  late _StubCoach coach;

  setUp(() => coach = _StubCoach());

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final c = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        coachRepositoryProvider.overrideWithValue(coach),
      ],
    );
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachMemoriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('shows what Ember remembers, in the user-visible wording', (
    tester,
  ) async {
    coach.stored = [remembered];
    await pump(tester);

    expect(find.text(remembered.text), findsOneWidget);
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Labelled by kind so the list reads as notes, not a database dump.
    expect(find.text(l10n.memoriesKindPerson.toUpperCase()), findsOneWidget);
  });

  testWidgets('an empty store says so plainly', (tester) async {
    await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.memoriesEmpty(l10n.coachName)), findsOneWidget);
  });

  testWidgets('a failed load never reads as "nothing remembered"', (
    tester,
  ) async {
    coach.failure = const NoConnectionException();
    await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.memoriesFailed), findsOneWidget);
    // "We could not look" and "there is nothing" are the same picture and very
    // different facts — and here the reassuring one is the lie.
    expect(find.text(l10n.memoriesEmpty(l10n.coachName)), findsNothing);
  });

  testWidgets('forgetting removes it once the server confirms', (tester) async {
    coach.stored = [remembered];
    final c = await pump(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.memoriesForget));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 400));

    expect(coach.forgotten, ['m1']);
    expect(await c.read(coachMemoriesProvider.future), isEmpty);
    // Drain the confirmation snack and its force-close backstop.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('a refused delete keeps the memory on screen and says so', (
    tester,
  ) async {
    coach.stored = [remembered];
    await pump(tester);
    coach.failure = const NoConnectionException();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.text(l10n.memoriesForget));
    await tester.pumpAndSettle();

    // Still stored server-side, so it must still be visible. Claiming a
    // disclosure was deleted when it was not is the worst outcome here.
    expect(find.text(remembered.text), findsOneWidget);
    expect(find.text(l10n.memoriesForgetFailed), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });
}

class _StubCoach implements CoachRepository {
  List<CoachMemory> stored = const [];
  final forgotten = <String>[];
  Object? failure;

  @override
  Future<List<CoachMemory>> memories() async {
    if (failure != null) throw failure!;
    return stored;
  }

  @override
  Future<void> forgetMemory(String id) async {
    if (failure != null) throw failure!;
    forgotten.add(id);
    stored = stored.where((m) => m.id != id).toList();
  }

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    yield const CoachDone(CoachReply(template: CoachTemplate.generic1));
  }

  @override
  Future<List<CoachMessage>> history() async => const [];
}
