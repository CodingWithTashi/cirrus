import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../data/stores/day1_tour_store.dart';
import '../../../data/stores/providers.dart';
import '../../../data/stores/widget_prompt_store.dart';
import '../../../domain/logic/widget_prompt_policy.dart';

/// The one-time offer of the home-screen widget (docs/15 QP-C2).
///
/// A taper user who has been logging by hand for a couple of days is offered
/// the thing that makes it quicker: the widget's `+` logs a puff without
/// opening the app. Android opens the system's own "add widget" dialog from one
/// tap; an iPhone gets three steps, since no app can add a widget there.
///
/// **It says logging is quicker and never that it helps anybody quit.** The
/// only evidence on widgets is that one raised how many days a diary was filled
/// in (22 people); nothing links a widget to quitting.
///
/// **Shown once means seen once.** The flag is written when the card is on
/// screen, not when it is built — the day-3 offer card counted 114 impressions
/// from 26 people for want of that, because Home lays out the rows just past
/// its bottom edge before anyone scrolls. Once it is up it stays up for the
/// visit (`WidgetPromptState.visible`), because writing the flag makes the
/// policy false from the very next frame. A restart without an answer does not
/// bring it back: that is the plan taken at its word.
///
/// Outside Home's one-card chain on purpose, like the offer card and the
/// cigarettes question: the chain's slot belongs to the person's own day (a
/// slip, the evening mood, their risky hour), and an optional convenience must
/// neither take that slot nor be what hides them. It is not a [Dismissible] —
/// it leaves by being answered — and it stands down while the Day-1 tour runs
/// and while a slip is waiting.
///
/// Empty when there is nothing to offer. The app-lifecycle listener that notices
/// the widget arriving is NOT here, on purpose: Home is a lazily built list, so
/// a card that collapsed after "Add" and was scrolled away is disposed, and a
/// listener living in it would die before the person got back from the
/// launcher. It lives in `HomeScreen`'s State (docs/10 §54.4).
class WidgetPromptCard extends ConsumerStatefulWidget {
  const WidgetPromptCard({super.key, required this.now});

  /// The clock Home runs on, so the policy and the screen agree on today.
  final DateTime now;

  @override
  ConsumerState<WidgetPromptCard> createState() => _WidgetPromptCardState();
}

class _WidgetPromptCardState extends ConsumerState<WidgetPromptCard> {
  /// Whether anything on this card's tab and route may be seen right now.
  ///
  /// Home stays mounted, laid out and with a size under the other tabs and
  /// under any route pushed over it, so a scroll offset alone says "visible"
  /// there. `TickerMode` is switched off for exactly those cases (go_router
  /// wraps an inactive branch in it, and an `Overlay` does for a covered
  /// route), and it is a dependency, so [didChangeDependencies] runs the moment
  /// Home is looked at again.
  bool _ticking = true;

  /// The list this card scrolls in, listened to until the card has been seen.
  ScrollPosition? _position;

  /// Whether the card is on Home waiting to be seen (offered, not yet up).
  bool _waiting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ticking = TickerMode.valuesOf(context).enabled;
    final nowLookedAt = ticking && !_ticking;
    _ticking = ticking;
    final position = Scrollable.maybeOf(context)?.position;
    if (!identical(position, _position)) {
      _position?.removeListener(_showIfSeen);
      _position = position?..addListener(_showIfSeen);
    }
    // Back on this tab, or the covering route popped: a card that was waiting
    // can be seen now, and nothing else would ask.
    if (nowLookedAt) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIfSeen());
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_showIfSeen);
    super.dispose();
  }

  /// Puts the offer up once its middle is inside the viewport — the same test
  /// `_OfferCard` applies to an impression. A card with no scroll position
  /// above it (a test, a short list) is on screen by definition.
  void _showIfSeen() {
    if (!mounted || !_waiting || !_ticking) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = _position;
    if (viewport != null && position != null) {
      final centred = viewport.getOffsetToReveal(box, 0.5).offset;
      if ((position.pixels - centred).abs() > position.viewportDimension / 2) {
        return;
      }
    }
    _position?.removeListener(_showIfSeen);
    ref.read(widgetPromptProvider.notifier).show();
  }

  @override
  Widget build(BuildContext context) {
    final journey = ref.watch(quitStoreProvider);
    final settings = ref.watch(settingsStoreProvider);
    final prompt = ref.watch(widgetPromptProvider);
    final tourLocked = ref.watch(day1TourLockedProvider);

    // Held until settings have hydrated: on the defaults "never shown" is a
    // guess, and a cold start where this ran first would put up a card the
    // stored flag says was already seen.
    final offered =
        journey != null &&
        settings.hydrated &&
        WidgetPromptPolicy.shouldShow(
          journey: journey,
          now: widget.now,
          installed: prompt.installed,
          alreadyShown: settings.widgetPromptShown,
          tourRunning: tourLocked,
          way: prompt.way,
        );
    final way = prompt.way;
    // The latch holds the card up across the policy turning false, but never
    // over the Day-1 tour: every other card on Home stands down for it, and a
    // row tapped on the checklist can start it on any day.
    final up = prompt.visible && way != null && !tourLocked;
    _waiting = offered && !prompt.visible;
    if (!offered && !up) return const SizedBox.shrink();

    if (_waiting) {
      // Deferred a frame: `build` stays free of side effects, and the card has
      // no size to measure until it has been laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIfSeen());
    }
    return _Offer(
      way: way ?? WidgetAddWay.pinDialog,
      onAccept: () => unawaited(ref.read(widgetPromptProvider.notifier).accept()),
      onDecline: () => ref.read(widgetPromptProvider.notifier).decline(),
    );
  }
}

class _Offer extends StatelessWidget {
  const _Offer({
    required this.way,
    required this.onAccept,
    required this.onDecline,
  });

  final WidgetAddWay way;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final steps = way == WidgetAddWay.walkthrough
        ? [
            l10n.widgetPromptStep1,
            l10n.widgetPromptStep2,
            l10n.widgetPromptStep3,
          ]
        : const <String>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LpCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: lp.voltSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: lp.volt.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.widgets_rounded, size: 18, color: lp.voltText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.widgetPromptTitle,
                    style: LpType.body14(
                      lp.textPrimary,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.widgetPromptBody,
              style: LpType.caption(lp.textSecondary),
            ),
            if (steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 20,
                        child: Text(
                          '${i + 1}',
                          style: LpType.caption(
                            lp.voltText,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          steps[i],
                          style: LpType.caption(lp.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: LpButton(
                    way == WidgetAddWay.pinDialog
                        ? l10n.widgetPromptAdd
                        : l10n.widgetPromptGotIt,
                    onTap: onAccept,
                    height: 44,
                    fontSize: 15,
                    glow: false,
                  ),
                ),
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: l10n.commonNotNow,
                  child: PressScale(
                    onTap: onDecline,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      child: Text(
                        l10n.commonNotNow,
                        style: LpType.body13(
                          lp.textSecondary,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
