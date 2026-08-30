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
                // Frame 3 note: "digits roll in (odometer)".
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
        const Spacer(),
        NumericKeypad(
          onDigit: vm.typeBirthDigit,
          onBackspace: vm.backspaceBirth,
        ),
        const SizedBox(height: 14),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
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
        const Spacer(),
        LpButton(
          l10n.commonContinue,
          onTap: state.canContinue ? vm.next : null,
        ),
      ],
    );
  }
}
