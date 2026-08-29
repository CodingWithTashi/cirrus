import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/data/stores/coach_store.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/domain/models/enums.dart';
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
  Future<CoachReply> requestReply({
    String? text,
    CoachChip? chip,
    required bool capped,
  }) async => reply;
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
