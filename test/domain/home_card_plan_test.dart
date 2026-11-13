import 'package:flutter_test/flutter_test.dart';
import 'package:last_puff/domain/logic/home_card_plan.dart';

/// Home is the screen people open most, and the one they leave when it asks too
/// much of them. Everything that stacks below the numbers is either something
/// that needs the person TODAY (a slip, the evening mood, yesterday's missing
/// answer, the day's vape-free confirmation, the daily program) or something
/// that can wait (finish setup, the cigarettes question, the widget offer, the
/// coach nudge). The optional ones now take turns: at most one, and none while
/// something needs the person — so the calm moments are where the extras show.
void main() {
  HomeCardPlan plan({
    bool actionUp = false,
    bool offerUp = false,
    bool setupDue = false,
    bool smokingDue = false,
    bool widgetUp = false,
    bool nudgeDue = false,
  }) => HomeCardPlan.decide(
    actionUp: actionUp,
    offerUp: offerUp,
    setupDue: setupDue,
    smokingDue: smokingDue,
    widgetUp: widgetUp,
    nudgeDue: nudgeDue,
  );

  List<String> shown(HomeCardPlan p) => [
    if (p.setup) 'setup',
    if (p.smoking) 'smoking',
    if (p.widget) 'widget',
    if (p.nudge) 'nudge',
  ];

  test('nothing due, nothing shown', () {
    expect(shown(plan()), isEmpty);
  });

  test('one optional card on its own is shown', () {
    expect(shown(plan(setupDue: true)), ['setup']);
    expect(shown(plan(smokingDue: true)), ['smoking']);
    expect(shown(plan(widgetUp: true)), ['widget']);
    expect(shown(plan(nudgeDue: true)), ['nudge']);
  });

  test('when everything is due, exactly one shows: setup, then the '
      'cigarettes question, then the widget, then the nudge', () {
    const all = (
      setupDue: true,
      smokingDue: true,
      widgetUp: true,
      nudgeDue: true,
    );
    expect(
      shown(plan(setupDue: all.setupDue, smokingDue: all.smokingDue,
          widgetUp: all.widgetUp, nudgeDue: all.nudgeDue)),
      ['setup'],
    );
    expect(
      shown(plan(smokingDue: true, widgetUp: true, nudgeDue: true)),
      ['smoking'],
    );
    expect(shown(plan(widgetUp: true, nudgeDue: true)), ['widget']);
  });

  test('none while something needs the person today', () {
    expect(
      shown(plan(actionUp: true, setupDue: true, smokingDue: true,
          widgetUp: true, nudgeDue: true)),
      isEmpty,
    );
  });

  test('none beside the offer, which was counted the moment the splash '
      'decided it and so is never the one to give way', () {
    expect(
      shown(plan(offerUp: true, setupDue: true, smokingDue: true,
          widgetUp: true, nudgeDue: true)),
      isEmpty,
    );
  });

  test('the offer and an action card are not this rule\'s business', () {
    // They are inputs, never outputs: the plan only ever hides the optional ones.
    final p = plan(actionUp: true, offerUp: true);
    expect(shown(p), isEmpty);
  });
}
