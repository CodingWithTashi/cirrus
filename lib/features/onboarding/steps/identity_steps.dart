import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_colors.dart';
import '../../../app/theme/lp_dimens.dart';
import '../../../app/theme/lp_typography.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_buttons.dart';
import '../../../core/widgets/lp_card.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../core/widgets/numeric_keypad.dart';
import '../../../core/widgets/press_scale.dart';
import '../../../domain/models/models.dart';
import '../onboarding_view_model.dart';
import '../tailoring.dart';
import 'step_fact.dart';
import 'step_body.dart';

/// A2 — gender, with the privacy promise pinned under the options.
class GenderStep extends ConsumerWidget {
  const GenderStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    Widget option(Gender g, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OptionCard(
        selected: state.gender == g,
        onTap: () => vm.selectGender(g),
        title: label,
      ),
    );

    return StepBody(
      title: l10n.obGenderTitle,
      subtitle: l10n.obGenderSubtitle,
      children: [
        option(Gender.woman, l10n.obGenderWoman),
        option(Gender.man, l10n.obGenderMan),
        option(Gender.nonBinary, l10n.obGenderNonBinary),
        const Spacer(),
        LpNoteCard(l10n.obGenderPrivacyNote),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}

/// A3 — birth year on the big keypad; digits roll in, caret blinks.
class BirthYearStep extends ConsumerWidget {
  const BirthYearStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);
    final entry = state.birthEntry;
    final age = entry.age ?? 0;
    final year = entry.year ?? 0;

    // Plenty of people answer "what year were you born?" with their age. The
    // caption names whatever we understood — including "we didn't" — so the
    // CTA is never dark with nothing on screen to explain it.
    final (caption, tone, adoptable) = switch (entry.kind) {
      BirthEntryKind.empty ||
      BirthEntryKind.typing => (l10n.obBirthYearHint, lp.textSecondary, false),
      BirthEntryKind.ageOffer ||
      BirthEntryKind.ageOnly => (
        l10n.obBirthYearAgeOffer(age, year),
        lp.textPrimary,
        true,
      ),
      BirthEntryKind.year => (l10n.obBirthYearAge(age), lp.textSecondary, false),
      BirthEntryKind.underAge => (
        l10n.obBirthYearUnderConfirm(year, age),
        lp.cautionText,
        false,
      ),
      BirthEntryKind.future => (
        l10n.obBirthYearErrorFuture,
        lp.cautionText,
        false,
      ),
      BirthEntryKind.tooOld => (
        l10n.obBirthYearErrorTooOld,
        lp.cautionText,
        false,
      ),
      BirthEntryKind.impossible => (
        l10n.obBirthYearErrorUnknown,
        lp.cautionText,
        false,
      ),
    };

    return StepBody(
      title: l10n.obBirthYearTitle,
      subtitle: l10n.obBirthYearSubtitle,
      children: [
        const Spacer(),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (state.birthYearInput.isEmpty)
                Text(' ', style: LpType.numberHero(lp.textPrimary, size: 76))
              else
                // Frame 3 note: "digits roll in (odometer)". Adopting an age
                // rewrites the buffer, so the odometer replays 28 -> 1998 and
                // the user watches us understand them.
                for (final (i, char) in state.birthYearInput.split('').indexed)
                  _RollInDigit(
                    key: ValueKey('$i$char'),
                    char: char,
                    style: LpType.numberHero(lp.textPrimary, size: 76).copyWith(
                      shadows: [
                        Shadow(
                          color: lp.volt.withValues(alpha: 0.3),
                          blurRadius: 36,
                        ),
                      ],
                    ),
                  ),
              const SizedBox(width: 6),
              const BlinkingCaret(height: 56),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Fixed height so the keypad never moves under the caption, and a
        // cross-fade rather than a resize: this whole column lives inside
        // StepScrollView's IntrinsicHeight, and an animating intrinsic height
        // there is what took the Health screen down for every user past day 1.
        SizedBox(
          height: 74,
          child: AnimatedSwitcher(
            duration: LpMotion.fast,
            switchInCurve: LpMotion.ease,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.25),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: Column(
              key: ValueKey('${entry.kind}$caption'),
              children: [
                Text(
                  caption,
                  textAlign: TextAlign.center,
                  style: LpType.body14(tone, weight: FontWeight.w600),
                ),
                if (adoptable) ...[
                  const SizedBox(height: 10),
                  _AdoptChip(
                    label: l10n.obBirthYearAgeConfirm,
                    onTap: vm.adoptAgeEntry,
                  ),
                ],
              ],
            ),
          ),
        ),
        const Spacer(),
        NumericKeypad(
          onDigit: vm.typeBirthDigit,
          onBackspace: vm.backspaceBirth,
        ),
        const SizedBox(height: 14),
        if (entry.kind == BirthEntryKind.underAge) ...[
          // The gate ends the session with no way back, so it costs a
          // deliberate "Yes, I'm 15" rather than one mistyped digit.
          LpButton(l10n.obBirthYearUnderCta(age), onTap: vm.next),
          const SizedBox(height: 6),
          LpTextButton(l10n.obBirthYearFix, onTap: vm.clearBirthYear),
        ] else
          LpButton(
            l10n.commonContinue,
            onTap: state.canContinue ? vm.next : null,
          ),
      ],
    );
  }
}

/// "That's me" — takes the offered age-to-year substitution.
class _AdoptChip extends StatelessWidget {
  const _AdoptChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: lp.surfaceInset,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: lp.voltFocus, width: 1.5),
        ),
        child: Text(
          label,
          style: LpType.displaySmall(lp.voltText, size: 14),
        ),
      ),
    );
  }
}

/// One digit sliding up into place (odometer roll, frame 3).
class _RollInDigit extends StatelessWidget {
  const _RollInDigit({super.key, required this.char, required this.style});

  final String char;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: LpMotion.fast,
      curve: LpMotion.ease,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - t)),
          child: child,
        ),
      ),
      child: Text(char, style: style),
    );
  }
}

/// A3b — under-18 gate. Warm, zero scare-copy, no back-door into the funnel.
class Under18Step extends ConsumerWidget {
  const Under18Step({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;

    // Frame 4: the resource buttons open the resource.
    //
    // They used to copy a string to the clipboard and claim "Link copied",
    // which is the least useful possible outcome for the one screen we show
    // somebody under 18: we have just told them we will not coach them, so
    // handing them a string to paste somewhere themselves is where most of
    // them stop. Falls back to the clipboard only if nothing can handle the
    // link — a dead button here is worse than a copied one.
    Widget resource(
      String title,
      String body,
      String cta, {
      bool volt = false,
      required String copyText,
      required Uri target,
    }) => LpCard(
      radius: LpDimens.rCard,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: LpType.emphasis(lp.textPrimary)),
          const SizedBox(height: 6),
          Text(body, style: LpType.body13(lp.textSecondary)),
          const SizedBox(height: 12),
          PressScale(
            onTap: () async {
              var opened = false;
              try {
                opened = await launchUrl(
                  target,
                  mode: LaunchMode.externalApplication,
                );
              } on Object {
                opened = false;
              }
              if (opened || !context.mounted) return;
              await Clipboard.setData(ClipboardData(text: copyText));
              if (context.mounted) {
                showLpSnack(context, context.l10n.buddyLinkCopied);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: lp.surfaceInset,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: volt ? lp.voltFocus : lp.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                cta,
                style: LpType.displaySmall(
                  volt ? lp.voltText : lp.textPrimary,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return StepBody(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: lp.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: lp.border, width: 1.5),
          ),
          child: const Text('🤝', style: TextStyle(fontSize: 28)),
        ),
        Text(
          l10n.obUnder18Title,
          textAlign: TextAlign.center,
          style: LpType.title(lp.textPrimary),
        ),
        const SizedBox(height: 12),
        Text(
          l10n.obUnder18Subtitle,
          textAlign: TextAlign.center,
          style: LpType.body14(lp.textSecondary),
        ),
        const SizedBox(height: 30),
        resource(
          l10n.obUnder18TiqTitle,
          l10n.obUnder18TiqBody,
          l10n.obUnder18TiqCta,
          volt: true,
          copyText: 'DITCHVAPE → 88709',
          // Opens the messaging app with the shortcode and body prefilled;
          // sending is still the reader's decision.
          target: Uri.parse('sms:88709?body=DITCHVAPE'),
        ),
        const SizedBox(height: 12),
        resource(
          l10n.obUnder18MlmqTitle,
          l10n.obUnder18MlmqBody,
          l10n.obUnder18MlmqCta,
          copyText: 'https://mylifemyquit.org',
          target: Uri.parse('https://mylifemyquit.org'),
        ),
        const Spacer(),
        Text(
          l10n.obUnder18Footer,
          textAlign: TextAlign.center,
          style: LpType.body13(lp.textSecondary),
        ),
        const SizedBox(height: 12),
        // Frame 4: no back-door into the funnel — the app exits gracefully.
        // (A pushed preview — the Frame Map — pops back instead of exiting.)
        LpTextButton(
          l10n.commonClose,
          onTap: () {
            final nav = Navigator.of(context);
            nav.canPop() ? nav.pop() : SystemNavigator.pop();
          },
        ),
      ],
    );
  }
}

/// A4 — quit attempts 2×2 grid + honest reframe banner.
class TriedStep extends ConsumerWidget {
  const TriedStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lp = context.lp;
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final vm = ref.read(onboardingProvider.notifier);

    Widget cell(QuitAttempts a, String big, String small) {
      final selected = state.attempts == a;
      return OptionCard(
        selected: selected,
        onTap: () => vm.selectAttempts(a),
        title: big,
        trailingCheck: false,
        child: Column(
          children: [
            Text(
              big,
              style: LpType.heading(
                selected ? lp.voltText : lp.textPrimary,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(small, style: LpType.caption(lp.textSecondary)),
          ],
        ),
      );
    }

    return StepBody(
      title: l10n.obTriedTitle,
      children: [
        Row(
          children: [
            Expanded(
              child: cell(
                QuitAttempts.never,
                l10n.obTriedNever,
                l10n.obTriedNeverSub,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cell(
                QuitAttempts.once,
                l10n.obTriedOnce,
                l10n.obTriedOnceSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: cell(
                QuitAttempts.twoToFive,
                l10n.obTried2to5,
                l10n.obTried2to5Sub,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: cell(
                QuitAttempts.moreThanFive,
                l10n.obTried5plus,
                l10n.obTried5plusSub,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Frame 5 note: "reaction banner slides up 250ms after any select".
        AnimatedSlide(
          duration: const Duration(milliseconds: 250),
          curve: LpMotion.ease,
          offset: state.attempts != null && state.attempts != QuitAttempts.never
              ? Offset.zero
              : const Offset(0, 0.25),
          child: AnimatedOpacity(
            duration: LpMotion.fast,
            opacity:
                state.attempts != null && state.attempts != QuitAttempts.never
                ? 1
                : 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lp.emberSoft,
                borderRadius: BorderRadius.circular(LpDimens.rCard),
                border: Border.all(
                  color: lp.ember.withValues(alpha: 0.35),
                  width: 1.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.obTriedReaction,
                      style: LpType.body14(lp.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StepFact(text: ObTailoring.fact(context, ObStep.tried, state)?.$1),
        const Spacer(),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}
