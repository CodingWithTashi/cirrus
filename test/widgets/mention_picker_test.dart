import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/app/last_puff_app.dart';
import 'package:last_puff/app/router/app_router.dart';
import 'package:last_puff/data/stores/providers.dart';
import 'package:last_puff/features/community/mention_picker.dart';

import '../helpers.dart';

/// Tagging somebody in a reply.
///
/// The server side of mentions shipped, was tested and was deployed months
/// before anybody could reach it: a user had to type `@quietfox42` exactly,
/// by hand, from memory. This is the half that makes it a feature.
///
/// Everything it offers comes from the thread already in memory. There is no
/// global alias→uid index and there must not be one — `_randomAlias()` mints
/// from 5,760 combinations client-side with no uniqueness check, so an alias
/// identifies a voice in a conversation and not a person.
void main() {
  /// `flutter test` substitutes a square-glyph fallback font; overflow here
  /// says nothing about the device (see `screen_layout_test`).
  void ignoreFontWidthOverflow() {
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exception.toString().contains('overflowed')) return;
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
  }

  /// The seeded SOS thread: `@slowturtle9` asking, then the demo persona
  /// (`@quietfox42`), `@nightbee14`, `@owlish7` and `@slowturtle9` again.
  Future<ProviderContainer> openThread(WidgetTester tester) async {
    ignoreFontWidthOverflow();
    final container = ProviderContainer(overrides: fastBackendOverrides());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LastPuffApp(),
      ),
    );
    container.read(quitStoreProvider.notifier).seedDemoJourney();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.communityPost('seed-sos'));
    await tester.pumpAndSettle();
    return container;
  }

  /// What the strip is offering right now, in order.
  List<String> offered(WidgetTester tester) => tester
      .widgetList<MentionStrip>(find.byType(MentionStrip))
      .expand((strip) => strip.targets)
      .map((target) => target.alias)
      .toList();

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
  }

  testWidgets('typing @ offers the thread, and never the reader', (
    tester,
  ) async {
    await openThread(tester);
    expect(find.byType(MentionStrip), findsNothing);

    await type(tester, '@');

    // The author first — they speak before every reply, which is what makes
    // the first-claimant rule mean what it says — then the voices in order.
    // `@slowturtle9` replied again at the end and still appears once.
    // `@quietfox42` is the reader, and mentioning yourself is not a
    // notification, so the server would drop it.
    expect(offered(tester), ['@slowturtle9', '@nightbee14', '@owlish7']);
  });

  testWidgets('it filters as they keep typing, and closes on no match', (
    tester,
  ) async {
    await openThread(tester);

    await type(tester, '@ni');
    expect(offered(tester), ['@nightbee14']);

    // An empty strip is worse than no strip: it takes height from the thread
    // to say nothing.
    await type(tester, '@zzz');
    expect(find.byType(MentionStrip), findsNothing);
  });

  testWidgets('a space closes it — an alias never spans one', (tester) async {
    await openThread(tester);

    await type(tester, '@');
    expect(find.byType(MentionStrip), findsOneWidget);

    await type(tester, '@ ');
    expect(find.byType(MentionStrip), findsNothing);
  });

  testWidgets('never opens inside an email address', (tester) async {
    await openThread(tester);
    await type(tester, 'reach me@example');
    expect(find.byType(MentionStrip), findsNothing);
  });

  testWidgets('selecting inserts the plain alias and closes the strip', (
    tester,
  ) async {
    await openThread(tester);
    await type(tester, 'that helped @ni');

    await tester.tap(
      find.descendant(
        of: find.byType(MentionStrip),
        matching: find.text('@nightbee14'),
      ),
    );
    // Settle rather than pump: `PressScale`'s release bounce is a delayed
    // future, and the strip it lives in is gone by the time it fires.
    await tester.pumpAndSettle();

    // Plain text and a trailing space — no ids, no markup, no parallel
    // `mentions: []` on the reply. The server resolves from the words, and a
    // second representation would be a second thing to keep in step.
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'that helped @nightbee14 ');
    expect(
      field.controller!.selection.baseOffset,
      'that helped @nightbee14 '.length,
    );
    expect(find.byType(MentionStrip), findsNothing);
  });

  testWidgets('it does not open past the number of tags the server honours', (
    tester,
  ) async {
    // A sixth tag is parsed and silently dropped, so offering one would be a
    // control that does nothing — which this app does not ship.
    await openThread(tester);
    await type(
      tester,
      '@aliasone1 @aliastwo2 @aliasthree3 @aliasfour4 @aliasfive5 @ni',
    );
    expect(find.byType(MentionStrip), findsNothing);
  });

  testWidgets('the strip gives way in a viewport too short to seat it', (
    tester,
  ) async {
    // The strip is a fixed-height tail on the thread's `Column`, and a
    // fixed-height tail overflows the moment the viewport shrinks past it —
    // an overflow stripe painted across the composer. The composer is what
    // matters here, so the strip is what goes.
    //
    // Caught on the emulator, not here: it takes about 175dp of body, a
    // third of the shortest phone `screen_layout_test` covers, and the app
    // is portrait-locked so a phone cannot reach it. Split-screen on a
    // tablet can.
    await openThread(tester);
    await type(tester, '@');
    expect(find.byType(MentionStrip), findsOneWidget);

    await tester.binding.setSurfaceSize(const Size(400, 170));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pump();
    expect(find.byType(MentionStrip), findsNothing);

    // …and comes back the moment there is room again.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pump();
    expect(find.byType(MentionStrip), findsOneWidget);
  });

  testWidgets('a reply that is only a tag will not send', (tester) async {
    final container = await openThread(tester);
    int replies() => container
        .read(communityStoreProvider)
        .posts
        .firstWhere((p) => p.id == 'seed-sos')
        .replies
        .length;
    final before = replies();

    await type(tester, '@nightbee14');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(
      replies(),
      before,
      reason: 'an address is not a message — the arrow is dimmed, not dead',
    );

    // One word is all it takes.
    await type(tester, '@nightbee14 yes');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pump();
    expect(replies(), before + 1);

    await tester.pump(const Duration(seconds: 5));
  });
}
