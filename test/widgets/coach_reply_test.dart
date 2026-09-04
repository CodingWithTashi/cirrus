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

  group("Ember's follow-ups replace the four openers", () {
    // The chips were four frozen strings — "I'm craving", "Rough day", "I
    // slipped", "Show my progress" — rendered identically on every turn
    // forever. Right for a cold open and useless as a reply: once Ember has
    // answered a specific thing, the useful next tap follows THAT.
    const suggestions = ['what if it doesnt', 'give me one thing', 'i caved'];

    Future<AppLocalizations> pumpCoach(
      WidgetTester tester,
      ProviderContainer container,
    ) async {
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
      return AppLocalizations.delegate.load(const Locale('en'));
    }

    testWidgets('a fresh thread still opens with the four static chips', (
      tester,
    ) async {
      // Nobody has said anything yet, so there is nothing to follow up on.
      // This is the case the static four were always right for.
      final container = containerWith(
        const CoachReply(template: CoachTemplate.generic1, text: spoken),
      );
      final l10n = await pumpCoach(tester, container);

      expect(find.text(l10n.coachChipCraving), findsOneWidget);
      expect(find.text(l10n.coachChipRoughDay), findsOneWidget);
      expect(find.text(l10n.coachChipSlipped), findsOneWidget);
      expect(find.text(l10n.coachChipProgress), findsOneWidget);
    });

    testWidgets('a reply with suggestions swaps the row for them', (
      tester,
    ) async {
      final container = containerWith(
        const CoachReply(
          template: CoachTemplate.generic1,
          text: spoken,
          followUps: suggestions,
        ),
      );
      final l10n = await pumpCoach(tester, container);

      await container.read(coachStoreProvider.notifier).send('rough night');
      await tester.pumpAndSettle();

      for (final suggestion in suggestions) {
        expect(find.text(suggestion), findsOneWidget, reason: suggestion);
      }
      // Swapped, not appended: eight chips in a one-line scroller means the
      // useful ones are off screen.
      expect(find.text(l10n.coachChipCraving), findsNothing);
      expect(find.text(l10n.coachChipProgress), findsNothing);
    });

    testWidgets('a reply without them keeps the openers', (tester) async {
      // The permanent state of an older backend, a restored transcript, a
      // capped turn and every mid-craving reply.
      final container = containerWith(
        const CoachReply(template: CoachTemplate.generic1, text: spoken),
      );
      final l10n = await pumpCoach(tester, container);

      await container.read(coachStoreProvider.notifier).send('rough night');
      await tester.pumpAndSettle();

      expect(find.text(l10n.coachChipCraving), findsOneWidget);
    });

    testWidgets('tapping one prefills the composer, and does not send it', (
      tester,
    ) async {
      // Frame 36, unchanged: a chip fills the box and the user still presses
      // send. Putting words in somebody's mouth about their own quit and
      // then posting them is not a shortcut, it is a lie.
      final container = containerWith(
        const CoachReply(
          template: CoachTemplate.generic1,
          text: spoken,
          followUps: suggestions,
        ),
      );
      await pumpCoach(tester, container);
      await container.read(coachStoreProvider.notifier).send('rough night');
      await tester.pumpAndSettle();

      final before = container.read(coachStoreProvider).messages.length;
      await tester.tap(find.text(suggestions.first));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        suggestions.first,
      );
      expect(container.read(coachStoreProvider).messages.length, before);
    });

    testWidgets('a suggestion is sent as free text, never as a protocol chip', (
      tester,
    ) async {
      // The trap this closes: the static chips used to be recovered by
      // comparing the typed text back against each localized label, so a
      // suggestion that happened to READ like one would have been filed as
      // `chip: craving` — routing a follow-up down the protocol path in a
      // language where the coincidence is likelier than it looks.
      final craving = (await AppLocalizations.delegate.load(const Locale('en')))
          .coachChipCraving;

      // The model suggests the exact words of a static chip. Delivered the
      // real way — through the repository — so this exercises the path a
      // production reply takes, not a hand-placed message.
      final speaking = ProviderContainer(
        overrides: [
          ...fastBackendOverrides(),
          coachRepositoryProvider.overrideWithValue(
            _SpeakingCoach(
              CoachReply(
                template: CoachTemplate.generic1,
                text: spoken,
                followUps: [craving],
              ),
            ),
          ),
        ],
      );
      addTearDown(speaking.dispose);
      speaking.read(quitStoreProvider.notifier).seedDemoJourney();
      await pumpCoach(tester, speaking);
      await speaking.read(coachStoreProvider.notifier).send('rough night');
      await tester.pumpAndSettle();

      await tester.tap(find.text(craving));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      // A user message with TEXT on it, not a chip echo.
      final sent = speaking
          .read(coachStoreProvider)
          .messages
          .where((m) => m.role == CoachRole.user)
          .last;
      expect(sent.text, craving);
      expect(sent.chipEcho, isNull);
    });

    testWidgets('a static chip sent unedited keeps its protocol routing', (
      tester,
    ) async {
      // The other half: the four openers must still route as chips in every
      // locale, because the fake backend's keyword matcher is English-only.
      final container = containerWith(
        const CoachReply(template: CoachTemplate.generic1, text: spoken),
      );
      final l10n = await pumpCoach(tester, container);

      await tester.tap(find.text(l10n.coachChipSlipped));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      final sent = container
          .read(coachStoreProvider)
          .messages
          .where((m) => m.role == CoachRole.user)
          .last;
      expect(sent.chipEcho, CoachChip.slipped.index);
      expect(sent.text, isNull);
    });
  });
}
