import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_router.dart';
import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/utils/program_copy.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../data/stores/providers.dart';
import '../../../domain/analytics/lp_events.dart';
import '../../../domain/date_key.dart';
import '../../../domain/logic/quit_program.dart';
import '../../../domain/models/journey_state.dart';
import '../../../domain/models/models.dart';
import '../../help/smoking_rule_card.dart';
import '../../panic/breath_pacer.dart';
import '../../panic/breath_ring.dart';

/// Where a message's pointer goes (docs/15 §4.1), or null when it has none or
/// the pointer is the card's own button. `ProgramLink` is data on the message;
/// this is the one place it becomes a route.
String? programLinkRoute(ProgramLink link) => switch (link) {
  ProgramLink.none || ProgramLink.stress => null,
  ProgramLink.money => Routes.money,
  ProgramLink.health => Routes.health,
  ProgramLink.help => Routes.helpFrom('program'),
  ProgramLink.community => Routes.community,
};

/// The daily program's card on Home (docs/15 stage B), directly under the ring.
///
/// One message a day, one question ("How is today going?" — the app's existing
/// mood check-in), the written reply to the answer, a check-up now and then, and
/// four buttons for the moments the program exists for: a craving, stress, a
/// slip, and "something else".
///
/// **It has no answer that hides it.** It is the day's message, not a prompt, so
/// it is not a `Dismissible` and nothing a person taps removes it. It is held
/// back only while the Day-1 tour runs — a cold-turkey account first sees it
/// after the tour, on its own quit day — and on a day with nothing to say.
///
/// On a card day the evening mood prompt steps aside ([shows] is what Home asks):
/// the card's question IS the check-in, so there is one a day.
class ProgramCard extends ConsumerStatefulWidget {
  const ProgramCard({super.key, required this.now});

  /// The clock Home runs on, so the card and the screen agree on the hour.
  final DateTime now;

  /// Whether the card has anything to show at [now]: a message today, or a
  /// check-up in its window (or one answered today, whose thanks is still up).
  /// Home reads this to stand its own evening mood prompt down.
  static bool shows(JourneyState journey, DateTime now, {required int checkinHour}) =>
      QuitProgram.messageToShow(journey.plan, now, checkinHour: checkinHour) !=
          null ||
      checkupFor(journey, now) != null;

  /// The in-card check-up for [now]: the one due, else one answered today.
  static CheckupKind? checkupFor(JourneyState journey, DateTime now) {
    final due = QuitProgram.checkupDue(journey, now);
    if (due != null && due.inProgramCard) return due;
    final answered = journey.checkups[LpDate.dayStart(now)];
    if (answered == null) return null;
    for (final kind in CheckupKind.values) {
      if (kind.inProgramCard && answered.containsKey(kind)) return kind;
    }
    return null;
  }

  @override
  ConsumerState<ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends ConsumerState<ProgramCard> {
  String? _shownKey;
  String? _repliedKey;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    final checkinHour = ref.watch(settingsStoreProvider).checkinHour;
    if (journey == null) return const SizedBox.shrink();
    final now = widget.now;
    final message = QuitProgram.messageToShow(
      journey.plan,
      now,
      checkinHour: checkinHour,
    );
    final checkup = ProgramCard.checkupFor(journey, now);
    if (message == null && checkup == null) return const SizedBox.shrink();

    final planDay = journey.plan.dayNumber(now);
    final today = journey.logFor(now);
    final mood = today?.mood;
    final programDay = QuitProgram.dayOf(journey.plan, now);
    final track = QuitProgram.trackOn(journey, now);
    final why = journey.profile.whyWords?.trim();
    final hasWhy = why != null && why.isNotEmpty;
    final reply = mood == null
        ? null
        : QuitProgram.replyFor(mood, track, seed: planDay, hasWhy: hasWhy);

    _report(programDay, message, mood, track);

    final link = message?.link ?? ProgramLink.none;
    final linkRoute = programLinkRoute(link);

    return LpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            // The day follows Home's own rule: counted until Freedom Day, then
            // not at all, because Home stops counting there.
            planDay <= journey.plan.totalDays
                ? l10n.programCardTitle(planDay)
                : l10n.programCardTitlePast,
            style: LpType.caption11(
              lp.emberText,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 1.2),
          ),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message.text(l10n), style: LpType.body14(lp.textPrimary)),
            if (linkRoute != null) ...[
              const SizedBox(height: 10),
              _chip(
                label: _linkLabel(l10n, link),
                onTap: () => context.push(linkRoute),
              ),
            ],
          ],
          const SizedBox(height: 14),
          Text(
            l10n.programQuestion,
            style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in Mood.values)
                _chip(
                  label: _moodLabel(l10n, m),
                  selected: mood == m,
                  onTap: () =>
                      ref.read(quitStoreProvider.notifier).checkInMood(m),
                ),
            ],
          ),
          if (reply != null) ...[
            const SizedBox(height: 12),
            Text(
              reply.text(l10n, why: hasWhy ? why : null),
              style: LpType.body14(lp.textSecondary),
            ),
          ],
          // After the reply, never before: the question is for somebody who has
          // just been heard.
          if (mood != null && checkup != null) ...[
            const SizedBox(height: 14),
            ProgramCheckup(kind: checkup, now: now, source: 'program'),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                label: l10n.programBtnCraving,
                onTap: () {
                  ref.read(analyticsProvider).programHelp('craving');
                  context.push(Routes.panic);
                },
              ),
              _chip(
                label: l10n.programBtnStress,
                onTap: () {
                  ref.read(analyticsProvider).programHelp('stress');
                  _showStress(planDay);
                },
              ),
              _chip(
                label: l10n.programBtnSlipped,
                onTap: () {
                  ref.read(analyticsProvider).programHelp('slipped');
                  _showSlipped(planDay, journey.profile.smoking);
                },
              ),
              _chip(
                label: l10n.programBtnMore,
                onTap: () {
                  ref.read(analyticsProvider).programHelp('more');
                  _showMore(planDay);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Once per day and slot, and once per mood, per visit — a rebuild from an
  /// answer must not report the card again.
  void _report(
    int? programDay,
    ProgramMessage? message,
    Mood? mood,
    ProgramTrack track,
  ) {
    final slot = message == null ? 'checkup' : message.slot.name;
    final shown = '$programDay/$slot';
    if (_shownKey != shown && programDay != null) {
      _shownKey = shown;
      final analytics = ref.read(analyticsProvider);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => analytics.programShown(day: programDay, slot: slot),
      );
    }
    if (mood != null) {
      final replied = '$programDay/${mood.name}/${track.name}';
      if (_repliedKey != replied) {
        _repliedKey = replied;
        final analytics = ref.read(analyticsProvider);
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => analytics.programReply(mood: mood.name, track: track.name),
        );
      }
    }
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) => LpChip(
    label: label,
    selected: selected,
    fontSize: 14,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    onTap: onTap,
  );

  String _moodLabel(AppLocalizations l10n, Mood m) => switch (m) {
    Mood.rough => l10n.moodRough,
    Mood.meh => l10n.moodMeh,
    Mood.okay => l10n.moodOkay,
    Mood.good => l10n.moodGood,
    Mood.great => l10n.moodGreat,
  };

  String _linkLabel(AppLocalizations l10n, ProgramLink link) => switch (link) {
    ProgramLink.help => l10n.helpTitle,
    ProgramLink.money => l10n.moneyTitle,
    ProgramLink.health => l10n.healthTitle,
    ProgramLink.community => l10n.navCommunity,
    ProgramLink.none || ProgramLink.stress => '',
  };

  void _showStress(int seed) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _StressSheet(seed: seed),
  );

  void _showSlipped(int seed, SmokingHistory? smoking) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => _SlippedSheet(
          seed: seed,
          smoking: smoking,
          onNewPlan: () {
            Navigator.of(sheetContext).pop();
            context.push(Routes.planNew);
          },
          onCoach: () {
            Navigator.of(sheetContext).pop();
            context.go(Routes.coach);
          },
          onHelp: () {
            Navigator.of(sheetContext).pop();
            context.push(Routes.helpFrom('program'));
          },
        ),
      );

  void _showMore(int seed) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _MoreSheet(
      seed: seed,
      onHelp: () {
        Navigator.of(sheetContext).pop();
        context.push(Routes.helpFrom('program'));
      },
    ),
  );
}

/// One check-up question, or — once answered today — a thanks and whatever the
/// answer calls for (docs/15 QP-B7). Shared by the daily card (the nicotine and
/// 30-day questions) and [Program90Card].
///
/// Nothing here gives advice. Cigarettes brings up the one rule and More help;
/// patch or gum gets a pointer to a pharmacist. No dose, no brand, no claim.
class ProgramCheckup extends ConsumerWidget {
  const ProgramCheckup({
    super.key,
    required this.kind,
    required this.now,
    required this.source,
  });

  final CheckupKind kind;
  final DateTime now;
  final String source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    if (journey == null) return const SizedBox.shrink();
    final given = journey.checkups[LpDate.dayStart(now)]?[kind];

    if (given != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.programCheckupThanks, style: LpType.body14(lp.textSecondary)),
          if (given == CheckupAnswer.cigarettes) ...[
            const SizedBox(height: 10),
            // They have just said they are smoking: the one rule, with both
            // lines, and the way to people who can help with it.
            SmokingRuleCard(answer: SmokingHistory.current, source: source),
          ],
          if (given == CheckupAnswer.patchGum) ...[
            const SizedBox(height: 8),
            Text(
              l10n.programCheckupPatchNote,
              style: LpType.body13(lp.textSecondary),
            ),
          ],
        ],
      );
    }

    final question = kind == CheckupKind.nicotine
        ? l10n.programCheckupNicotineQ
        : l10n.programCheckupVapedQ;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: LpType.body13(lp.textPrimary, weight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final answer in kind.answers)
              LpChip(
                label: _label(l10n, answer),
                selected: false,
                fontSize: 14,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                onTap: () =>
                    ref.read(quitStoreProvider.notifier).recordCheckup(kind, answer),
              ),
          ],
        ),
      ],
    );
  }

  String _label(AppLocalizations l10n, CheckupAnswer a) => switch (a) {
    CheckupAnswer.noOther => l10n.programCheckupNone,
    CheckupAnswer.cigarettes => l10n.programCheckupCigarettes,
    CheckupAnswer.pouches => l10n.programCheckupPouches,
    CheckupAnswer.patchGum => l10n.programCheckupPatchGum,
    CheckupAnswer.vaped => l10n.programCheckupYes,
    CheckupAnswer.notVaped => l10n.programCheckupNone,
  };
}

/// The 90-day question's own small card (docs/15 QP-B7). The program has ended
/// by then, so it cannot ride in the daily card; it is open from day 90 to 104
/// and gone once answered or once the window closes.
class Program90Card extends ConsumerWidget {
  const Program90Card({super.key, required this.now});

  final DateTime now;

  /// Whether the card shows: the question is due, or was answered today.
  static bool shows(JourneyState journey, DateTime now) =>
      QuitProgram.checkupDue(journey, now) == CheckupKind.vaped90 ||
      (journey.checkups[LpDate.dayStart(now)]?.containsKey(CheckupKind.vaped90) ??
          false);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final journey = ref.watch(quitStoreProvider);
    if (journey == null || !shows(journey, now)) return const SizedBox.shrink();
    return LpCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.programCheckup90Title,
            style: LpType.caption11(
              lp.emberText,
              weight: FontWeight.w700,
            ).copyWith(letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          ProgramCheckup(
            kind: CheckupKind.vaped90,
            now: now,
            source: 'program',
          ),
        ],
      ),
    );
  }
}

/// A sheet's frame: the same padding and title the other sheets use.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: LpType.titleSm(lp.textPrimary)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// A minute to breathe, and one thing to try. The ring is the craving flow's
/// own widget, paced a little gentler than its 4-7-8 — in for four, out for six
/// — because this is not an emergency and the reply that sends people here says
/// exactly that.
class _StressSheet extends StatefulWidget {
  const _StressSheet({required this.seed});

  final int seed;

  @override
  State<_StressSheet> createState() => _StressSheetState();
}

class _StressSheetState extends State<_StressSheet>
    with SingleTickerProviderStateMixin {
  static const _pacer = BreathPacer(inhale: 4, hold: 0, exhale: 6);
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _pacer.cycle,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return _SheetFrame(
      title: l10n.programStressTitle,
      children: [
        Text(l10n.programStressBody, style: LpType.body14(lp.textSecondary)),
        const SizedBox(height: 16),
        Center(
          child: BreathRing(animation: _controller, pacer: _pacer, size: 150),
        ),
        const SizedBox(height: 16),
        Text(
          QuitProgram.tipFor(ProgramTipKind.stress, widget.seed).text(l10n),
          style: LpType.body14(lp.textPrimary),
        ),
        const SizedBox(height: 16),
        LpButton(l10n.commonDone, onTap: () => Navigator.of(context).pop()),
      ],
    );
  }
}

/// After a slip: no shame, one idea, and the three doors — a new plan (which
/// keeps everything already lived), the coach, and More help. It moves nothing
/// by itself; the slip screen is where a date is decided.
class _SlippedSheet extends StatelessWidget {
  const _SlippedSheet({
    required this.seed,
    required this.smoking,
    required this.onNewPlan,
    required this.onCoach,
    required this.onHelp,
  });

  final int seed;
  final SmokingHistory? smoking;
  final VoidCallback onNewPlan;
  final VoidCallback onCoach;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    // The rule card carries its own More help door, so the sheet offers a second
    // one only when the card is absent (a Pixel 8 showed it twice).
    final showsRule = smoking != null && smoking != SmokingHistory.never;
    return _SheetFrame(
      title: l10n.programSlippedTitle,
      children: [
        Text(
          QuitProgram.tipFor(ProgramTipKind.slipped, seed).text(l10n),
          style: LpType.body14(lp.textPrimary),
        ),
        if (showsRule) ...[
          const SizedBox(height: 14),
          SmokingRuleCard(answer: smoking!, source: 'program'),
        ],
        const SizedBox(height: 18),
        LpButton(l10n.planNewCta, onTap: onNewPlan),
        const SizedBox(height: 4),
        LpTextButton(l10n.programSlippedCoach, onTap: onCoach),
        if (!showsRule) LpTextButton(l10n.helpTitle, onTap: onHelp),
      ],
    );
  }
}

/// Another idea, and the door to More help.
class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.seed, required this.onHelp});

  final int seed;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    return _SheetFrame(
      title: l10n.programMoreTitle,
      children: [
        Text(
          QuitProgram.tipFor(ProgramTipKind.more, seed).text(l10n),
          style: LpType.body14(lp.textPrimary),
        ),
        const SizedBox(height: 18),
        LpTextButton(l10n.helpTitle, onTap: onHelp),
      ],
    );
  }
}
