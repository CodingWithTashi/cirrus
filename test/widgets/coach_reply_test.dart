import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/models.dart';
import 'package:last_puff/domain/repositories/repositories.dart';
import 'package:last_puff/features/coach/coach_screen.dart';
import 'package:last_puff/app/theme/lp_theme.dart';
import 'package:last_puff/l10n/gen/app_localizations.dart';

import '../helpers.dart';

/// A coach backend that answers with the model's own prose, the way
/// `aiCoachChat` does once the client is wired to it.
class _SpeakingCoach implements CoachRepository {
  _SpeakingCoach(this.reply);

  final CoachReply reply;

  @override
  Stream<CoachEvent> streamReply({
    String? text,
    CoachChip? chip,
    required bool capped,
    int? panicIntensity,
  }) async* {
    final spoken = reply.text;
    if (spoken != null) yield CoachChunk(spoken);
    yield CoachDone(reply);
  }

  @override
  Future<List<CoachMessage>> history() async => const [];

  // This stub predates the memory layer and does not exercise it.
  @override
  Future<List<CoachMemory>> memories() async => const [];

  @override
  Future<void> seedMemories() async {}

  @override
  Future<void> forgetMemory(String id) async {}
}

void main() {
  /// The bug this guards: `CoachReplyCodec` used to drop the `text` field, so
  /// a real Gemini reply arrived and was rendered as the canned `generic1`
  /// template. Every word Ember said was discarded, silently, and the thread
  /// still looked plausible — which is why it survived a design review.
  const spoken =
      'That 10pm wave is brutal, I know. Fifteen minutes and it breaks.';

  ProviderContainer containerWith(CoachReply reply) {
    final container = ProviderContainer(
      overrides: [
        ...fastBackendOverrides(),
        coachRepositoryProvider.overrideWithValue(_SpeakingCoach(reply)),
      ],
    );
    addTearDown(container.dispose);
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    return container;
  }

  test('the model reply reaches the message, not just the envelope', () async {
    final container = containerWith(
      const CoachReply(
        template: CoachTemplate.generic1,
        args: {'day': 12},
        text: spoken,
      ),
    );

    await container.read(coachStoreProvider.notifier).send('rough night');

    expect(container.read(coachStoreProvider).messages.last.text, spoken);
  });

  testWidgets('the coach screen renders Ember\'s words verbatim', (
    tester,
  ) async {
    final container = containerWith(
      const CoachReply(
        template: CoachTemplate.generic1,
        args: {'day': 12},
        text: spoken,
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await container.read(coachStoreProvider.notifier).send('rough night');
    await tester.pumpAndSettle();

    expect(find.text(spoken), findsOneWidget);
  });

  testWidgets('a renamed coach is renamed EVERYWHERE on the chat screen', (
    tester,
  ) async {
    // The bug this guards: every bubble, the greeting and the safety note
    // interpolated the chosen name, while the header — the biggest text on
    // the screen — still rendered the ARB default. A user who named their
    // coach John read "Ember" at the top of a conversation signed john.
    //
    // Stored lowercase on purpose: names saved before `CoachName.normalize`
    // capitalized are already on synced journeys, and the provider is what
    // makes them render capitalized without a re-save.
    final container = containerWith(
      const CoachReply(template: CoachTemplate.generic1, args: {'day': 12}),
    );
    await container.read(quitStoreProvider.notifier).reserveCoachName('john');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The header renders the bare name as its own Text; the greeting and
    // safety note carry it inside sentences.
    expect(find.text('John'), findsOneWidget, reason: 'header not renamed');
    expect(find.textContaining('John'), findsWidgets);
    expect(
      find.textContaining('Ember'),
      findsNothing,
      reason: 'the brand default leaked past the rename',
    );
  });

  testWidgets('a template-only reply still localizes through the template', (
    tester,
  ) async {
    // capReached and connectionLost carry no text on purpose — the server
    // owns those and the view must keep localizing them.
    final container = containerWith(
      const CoachReply(template: CoachTemplate.connectionLost),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: LpTheme.midnight(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CoachScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await container.read(coachStoreProvider.notifier).send('hello');
    await tester.pumpAndSettle();

    final messages = container.read(coachStoreProvider).messages;
    expect(messages.last.template, CoachTemplate.connectionLost);
    expect(messages.last.text, isNull);
    // Rendered from ARB, not left blank and not showing a raw enum name.
    expect(find.textContaining('Signal dropped mid-thought'), findsOneWidget);
  });
}
