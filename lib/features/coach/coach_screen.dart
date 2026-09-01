import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../domain/date_key.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_format.dart';
import '../../core/widgets/lp_card.dart';
import '../../core/widgets/lp_charts.dart';
import '../../core/widgets/lp_states.dart';
import '../../core/widgets/press_scale.dart';
import '../../data/stores/day1_tour_store.dart';
import '../../data/stores/providers.dart';
import '../day1/day1_spotlight.dart';
import '../../domain/logic/day_window.dart';
import '../../domain/models/journey_state.dart';
import '../../domain/models/models.dart';

/// Frame 36 — Ember's chat. Cites the user's own data, never generic advice.
class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key, this.panicIntensity});

  /// 1–10 when the panic flow routed here, else null. See the coach route.
  final int? panicIntensity;

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  final _input = TextEditingController();
  final _inputFocus = FocusNode();
  final _scroll = ScrollController();

  /// Rides on the next message only: the craving that opened this screen is
  /// context for what the user is about to say, not a permanent mode.
  int? _panicIntensity;

  @override
  void initState() {
    super.initState();
    _inputFocus.addListener(_onInputFocus);
    _panicIntensity = widget.panicIntensity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Pull the stored transcript first; the greeting is what you get when
      // there is genuinely nothing to continue. Seeding unconditionally is why
      // reopening the app used to look like meeting Ember for the first time.
      ref.read(coachStoreProvider.notifier).restoreHistory();
    });
  }

  @override
  void didUpdateWidget(CoachScreen old) {
    super.didUpdateWidget(old);
    final next = widget.panicIntensity;
    if (next != null && next != old.panicIntensity) _panicIntensity = next;
  }

  /// The spotlight measures its target ONCE, when the step starts. Tapping
  /// the field opens the keyboard and the composer slides up above it, so
  /// the send arrow ends up outside the hole the barrier left — and the
  /// barrier ate the tap (QA L4: the in-app arrow was dead on step two, the
  /// IME key worked). Focus is the moment the lesson's real action begins:
  /// the highlight comes down, the tour's locks stay.
  void _onInputFocus() {
    if (!_inputFocus.hasFocus) return;
    if (ref.read(day1TourStepProvider) == Day1TourStep.meetCoach) {
      Day1Spotlight.dismissOverlay();
    }
  }

  @override
  void dispose() {
    _inputFocus
      ..removeListener(_onInputFocus)
      ..dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: LpMotion.normal,
          curve: LpMotion.ease,
        );
      }
    });
  }

  String _chipLabel(BuildContext context, int index) =>
      switch (CoachChip.values[index]) {
        CoachChip.craving => context.l10n.coachChipCraving,
        CoachChip.roughDay => context.l10n.coachChipRoughDay,
        CoachChip.slipped => context.l10n.coachChipSlipped,
        CoachChip.progress => context.l10n.coachChipProgress,
      };

  /// A divider renders when the calendar day turns or the thread went quiet
  /// for a while. Un-stamped messages (legacy turns, the seeded greeting)
  /// never force one — they group with whatever came before.
  static bool _needsSeparator(DateTime? prev, DateTime? cur) {
    if (cur == null) return false;
    if (prev == null) return true;
    if (LpDate.dayStart(prev) != LpDate.dayStart(cur)) return true;
    return cur.difference(prev) > const Duration(minutes: 15);
  }

  /// Local wall-clock label: "3:07 PM" today, "Yesterday · 9:12 PM", then
  /// "Sat, Aug 15 · 9:12 PM". Always the device's own timezone — the server's
  /// clock never reaches this screen.
  ///
  /// [now] comes from the watched minute clock, never `DateTime.now()` in
  /// build: this tab lives in the keep-alive IndexedStack, so a raw read
  /// would freeze "today" at whenever the tab was first built and label last
  /// night's messages as today's after midnight — the same frozen-clock bug
  /// PostCard had.
  String _timeLabel(BuildContext context, DateTime t, DateTime now, String locale) {
    final today = LpDate.dayStart(now);
    final day = LpDate.dayStart(t);
    final time = LpFormat.clockTime(t, locale);
    if (day == today) return time;
    if (day == LpDate.addDays(today, -1)) {
      return context.l10n.coachTimeYesterday(time);
    }
    return '${LpFormat.weekdayShortDate(t, locale)} · $time';
  }

  String _resolve(BuildContext context, CoachMessage m, String coachName) {
    // A model-authored reply is already prose in the user's language (the
    // server pins it from the caller's locale), so it renders verbatim. The
    // template is the fallback for deterministic replies and for anything the
    // backend could not answer.
    final spoken = m.text;
    if (spoken != null && spoken.isNotEmpty) return spoken;

    final l10n = context.l10n;
    final locale = context.localeTag;
    num n(String k) => (m.args[k] as num?) ?? 0;
    int i(String k) => n(k).toInt();
    String money(String k) => LpFormat.money(n(k), locale);

    return switch (m.template!) {
      CoachTemplate.greeting => l10n.coachGreeting(
        coachName,
        i('puffs'),
        m.args['method'] == 'coldTurkey'
            ? l10n.planMethodCold
            : l10n.planMethodTaper,
        LpFormat.shortDate(LpDate.fromYmdInt(i('freedomYmd')), locale),
      ),
      CoachTemplate.craving1 => l10n.coachReplyCraving1,
      CoachTemplate.craving2 => l10n.coachReplyCraving2(i('count')),
      CoachTemplate.craving3 => l10n.coachReplyCraving3,
      CoachTemplate.rough1 => l10n.coachReplyRough1(i('percent')),
      CoachTemplate.rough2 => l10n.coachReplyRough2,
      CoachTemplate.slip1 => l10n.coachReplySlip1(i('streak')),
      CoachTemplate.slip2 => l10n.coachReplySlip2(money('saved')),
      CoachTemplate.progress1 => l10n.coachReplyProgress1(
        i('day'),
        money('saved'),
        i('count'),
      ),
      CoachTemplate.progress2 => l10n.coachReplyProgress2(
        i('today'),
        i('limit'),
      ),
      CoachTemplate.generic1 => l10n.coachReplyGeneric1,
      CoachTemplate.generic2 => l10n.coachReplyGeneric2(i('day')),
      CoachTemplate.generic3 => l10n.coachReplyGeneric3,
      CoachTemplate.generic4 => l10n.coachReplyGeneric4,
      CoachTemplate.party => l10n.coachReplyParty(i('count')),
      CoachTemplate.capReached => l10n.coachCapReached,
      CoachTemplate.connectionLost => l10n.coachConnectionLost,
      CoachTemplate.backendRejected => l10n.coachBackendRejected,
    };
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final locale = context.localeTag;
    final coach = ref.watch(coachStoreProvider);
    final coachName = ref.watch(coachNameProvider) ?? l10n.coachName;
    final store = ref.read(coachStoreProvider.notifier);
    final snap = ref.watch(todayProvider);
    final journey = ref.watch(quitStoreProvider);
    // Watched so the separators re-derive "today"/"yesterday" as time passes
    // in this keep-alive tab.
    final now = ref.watch(minuteClockProvider);
    // The counter shows only what the server has actually told us it is
    // enforcing. Before that it shows nothing — a number nobody stands behind
    // is worse than no number.
    final freeLeft = coach.messagesLeft ?? 0;
    final showCounter = store.showsAllowance;

    // Day-1 step two used to complete from a listener here, which counted
    // the seeded greeting — an ember message that appears without a word
    // being typed — and ticked "Meet your coach" on arrival. Completion now
    // rides the send future in [_finishTourStepAfter], where "the user sent
    // something and Ember answered it" is a fact rather than an inference.
    ref.listen(coachStoreProvider, (previous, next) => _scrollToEnd());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: lp.oxygenSoft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: lp.oxygen.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'AI',
                      style: LpType.displaySmall(lp.oxygenText, size: 15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // The resolved name, never `l10n.coachName` (the
                          // brand default): this header was the one surface
                          // still showing "Ember" to a user who had renamed
                          // their coach — on the very screen where every
                          // bubble already used the chosen name.
                          coachName,
                          style: LpType.emphasis(lp.textPrimary),
                        ),
                        Text(
                          l10n.coachStatus(snap?.dayNumber ?? 1),
                          style: LpType.caption11(lp.voltText),
                        ),
                      ],
                    ),
                  ),
                  if (showCounter)
                    Text(
                      l10n.coachFreeCounter(freeLeft.clamp(0, 5)),
                      style: LpType.caption11(lp.textSecondary),
                    ),
                ],
              ),
            ),
            // Thread.
            Expanded(
              child: coach.isRestoring && coach.messages.isEmpty
                  // Restoring the transcript is a different wait from Ember
                  // thinking, and saying which one it is costs nothing.
                  ? LpLoadingState(label: l10n.coachLoadingThread)
                  : ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      children: [
                        for (final (i, m) in coach.messages.indexed) ...[
                          // Day/time separators make the thread honest about
                          // when things were said — restored history used to
                          // render last night's messages indistinguishable
                          // from this morning's.
                          if (_needsSeparator(
                            i == 0 ? null : coach.messages[i - 1].sentAt,
                            m.sentAt,
                          ))
                            _TimeDivider(
                              label: _timeLabel(context, m.sentAt!, now, locale),
                            ),
                          _Bubble(
                            isUser: m.role == CoachRole.user,
                            text: m.role == CoachRole.user
                                ? (m.text ??
                                      _chipLabel(context, m.chipEcho ?? 0))
                                : _resolve(context, m, coachName),
                          ),
                          if (m.showWeekCard && journey != null) ...[
                            const SizedBox(height: 12),
                            _WeekCard(
                              journey: journey,
                              now: ref.watch(nowProvider)(),
                              locale: locale,
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                        if (coach.isTyping) _TypingBubble(coachName: coachName),
                      ],
                    ),
            ),
            // Quick chips.
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final chip in CoachChip.values) ...[
                    PressScale(
                      // Frame 36: chips prefill the composer — the user
                      // stays in control of the send.
                      onTap: () {
                        _input.text = _chipLabel(context, chip.index);
                        _input.selection = TextSelection.collapsed(
                          offset: _input.text.length,
                        );
                        setState(() {});
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: lp.surface,
                          borderRadius: BorderRadius.circular(LpDimens.rChip),
                          border: Border.all(color: lp.border, width: 1.5),
                        ),
                        child: Text(
                          _chipLabel(context, chip.index),
                          style: LpType.body13(
                            chip == CoachChip.craving
                                ? lp.voltText
                                : lp.textPrimary,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Input row.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: Day1Spotlight(
                step: Day1TourStep.meetCoach,
                title: l10n.day1TourCoachTitle,
                // The user's own name for their coach — this is the step that
                // introduces it, and a hardcoded "Ember" here told everyone
                // who renamed theirs that the rename didn't take.
                description: l10n.day1TourCoachBody(coachName),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
                  decoration: BoxDecoration(
                    color: lp.surface,
                    borderRadius: BorderRadius.circular(LpDimens.rChip),
                    border: Border.all(color: lp.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          focusNode: _inputFocus,
                          style: LpType.body14(lp.textPrimary),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: l10n.coachInputHint,
                            hintStyle: LpType.body14(lp.textFaint),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      PressScale(
                        onTap: _send,
                        child: Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: lp.volt,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: lp.onVolt,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 6),
              child: Text(
                l10n.coachSafetyNote(coachName),
                textAlign: TextAlign.center,
                style: LpType.micro(lp.textFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    final panic = _panicIntensity;
    setState(() => _panicIntensity = null);
    final store = ref.read(coachStoreProvider.notifier);
    // A prefilled chip sent unedited keeps its protocol routing in every
    // locale (the keyword matcher is a demo-only English heuristic).
    final chipIndex = CoachChip.values.indexWhere(
      (chip) => _chipLabel(context, chip.index) == text,
    );
    final sent = chipIndex == -1
        ? store.send(text, panicIntensity: panic)
        : store.sendChip(CoachChip.values[chipIndex], panicIntensity: panic);
    if (ref.read(day1TourStepProvider) == Day1TourStep.meetCoach) {
      // The lesson's tap happened; the highlight comes down so the reply is
      // watched on a normal screen, not through the barrier's 88% wash. The
      // tour's locks stay until the reply completes the step.
      Day1Spotlight.dismissOverlay();
      unawaited(_finishTourStepAfter(sent));
    } else {
      unawaited(sent);
    }
  }

  /// Day-1 step two ends on a reply that ACTUALLY ANSWERED THE USER.
  ///
  /// Anchored on the send future, not on watching messages arrive: the future
  /// completes only once the whole reply has streamed in (or failed), so this
  /// cannot fire on the seeded greeting, on a restored transcript, or halfway
  /// through a sentence — every one of which is a box ticked for someone who
  /// never heard back from Ember, the exact class of claim the walkthrough
  /// exists to remove. The failure templates the client mints for a dead wire
  /// don't count either.
  ///
  /// The pause before returning to the checklist is so the user sees Ember
  /// answer — yanking the screen away on the reply's last byte reads as the
  /// app interrupting the conversation it just asked them to start. The full
  /// reply keeps: the transcript is stored, and the coach tab stays one tap
  /// away for the rest of their quit.
  Future<void> _finishTourStepAfter(Future<void> sent) async {
    await sent;
    if (!mounted) return;
    final messages = ref.read(coachStoreProvider).messages;
    if (messages.isEmpty) return;
    final last = messages.last;
    if (last.role != CoachRole.ember) return;
    if (last.template == CoachTemplate.greeting ||
        last.template == CoachTemplate.connectionLost ||
        last.template == CoachTemplate.backendRejected) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    if (ref.read(day1TourStepProvider) != Day1TourStep.meetCoach) return;
    ref.read(day1TourProvider.notifier).complete(Day1TourStep.meetCoach);
  }
}

/// Centered "3:07 PM" / "Yesterday · 9:12 PM" pill between message groups.
class _TimeDivider extends StatelessWidget {
  const _TimeDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Center(
        child: Text(label, style: LpType.caption11(lp.textFaint)),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.isUser, required this.text});

  final bool isUser;
  final String text;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: isUser ? lp.voltSoft : lp.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
          ),
          border: Border.all(
            color: isUser ? lp.volt.withValues(alpha: 0.4) : lp.border,
            width: 1.5,
          ),
        ),
        child: Text(text, style: LpType.body14(lp.textPrimary)),
      ),
    );
  }
}

/// Ember's flame pulses while "typing" (docs/04 §8).
class _TypingBubble extends StatefulWidget {
  const _TypingBubble({required this.coachName});

  /// Passed in rather than read here: this is a plain StatefulWidget, and the
  /// screen reader label is the one place the name must not silently fall back.
  final String coachName;

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final label = context.l10n.coachTyping(widget.coachName);
    return Align(
      alignment: Alignment.centerLeft,
      // One spoken label; the visible copy below is excluded so screen
      // readers don't hear it twice.
      child: Semantics(
        label: label,
        liveRegion: true,
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: lp.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(18),
            ),
            border: Border.all(color: lp.border, width: 1.5),
          ),
          // The pulsing flame is the docs/04 §8 indicator; the words are for
          // everyone who is not using a screen reader — the field test showed
          // a lone emoji does not read as "the coach is typing".
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.35, end: 1.0).animate(_pulse),
                child: Text(
                  '🔥',
                  style: TextStyle(fontSize: 14, color: lp.ember),
                ),
              ),
              const SizedBox(width: 8),
              FadeTransition(
                opacity: Tween(begin: 0.55, end: 1.0).animate(_pulse),
                child: Text(label, style: LpType.caption(lp.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline "YOUR WEEK" stat card rendered in-thread.
///
/// The same calendar window as Stats (QA M1: both used to window over the
/// last seven LOGGED days and named a "hard day" from last week). Hidden
/// until two days have puffs at all — one point is not a trend, and a day-1
/// account was being told "trending down — Monday was the hard one" from a
/// single bar (QA M2).
class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.journey,
    required this.now,
    required this.locale,
  });

  final JourneyState journey;
  final DateTime now;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final week = DayWindow.trailing(journey, now, 7);
    if (week.where((l) => l.puffs > 0).length < 2) {
      return const SizedBox.shrink();
    }
    var hardest = 0;
    for (var i = 0; i < week.length; i++) {
      if (week[i].puffs > week[hardest].puffs) hardest = i;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.82,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: lp.surfaceSubtle,
          borderRadius: BorderRadius.circular(LpDimens.rInput),
          border: Border.all(color: lp.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(
              l10n.coachWeekCardLabel,
              padding: const EdgeInsets.only(bottom: 8),
            ),
            BarChart(
              values: [for (final log in week) log.puffs],
              height: 44,
              gap: 5,
              radius: 4,
              highlight: {hardest},
              positive: {week.length - 1},
            ),
            const SizedBox(height: 8),
            Text(
              l10n.coachWeekCardCaption(
                LpFormat.weekday(week[hardest].date, locale),
              ),
              style: LpType.caption11(lp.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
