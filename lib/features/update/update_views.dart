import 'dart:math' as math;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_dimens.dart';
import '../../app/theme/lp_typography.dart';
import '../../core/utils/l10n_ext.dart';
import '../../core/utils/lp_links.dart';
import '../../core/utils/whats_new_copy.dart';
import '../../core/widgets/lp_buttons.dart';
import '../../core/widgets/lp_card.dart';
import '../../data/stores/providers.dart';
import '../../data/stores/update_check_store.dart';
import '../../domain/analytics/lp_events.dart';
import '../../domain/logic/update_prompt_policy.dart';

/// The update prompt, the forced update screen and What's New (docs/10 §55).
///
/// Cirrus's own design, not upgrader's stock Cupertino/Material dialog — a
/// deliberate deviation from the shared `flutter-upgrader` skill, because the
/// founder asked for one consistent, professional UI. All three share
/// [UpdateCardBody]: a version chip, a title, a one-line reason, up to three
/// bullets, then the buttons — Update (or Got it) the single primary action.
///
/// Calm on purpose: no countdown, no "you're missing out", no guilt. The
/// forced copy says what is true — this version is no longer supported — and
/// nothing more.

/// Opens the optional update sheet over Home and waits for it to close.
///
/// Counted as shown the moment it opens (upgrader's three-day clock, the
/// visit latch, `update_prompt_shown`), so any way out — Not now, a swipe, a
/// tap outside, even Update without updating — is quiet for three days.
Future<void> showUpdateSheet(BuildContext context, WidgetRef ref) async {
  final check = ref.read(updateCheckProvider);
  final analytics = ref.read(analyticsProvider);
  ref.read(updateCheckProvider.notifier).markOffered();
  ref.read(visitModalsProvider.notifier).opened(AppModal.updatePrompt);
  analytics.updatePromptShown(forced: false);
  final language = Localizations.localeOf(context).languageCode;

  final update = await showModalBottomSheet<bool>(
    context: context,
    // Over the tab bar too: the sheet is about the app, not about Home.
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => _SheetFrame(
      child: UpdateCardBody(
        version: check.storeVersion,
        title: sheet.l10n.updateTitle,
        reason: sheet.l10n.updateReason,
        notes: check.notesFor(language),
        primaryLabel: sheet.l10n.updateCta,
        onPrimary: () => Navigator.of(sheet).pop(true),
        secondaryLabel: sheet.l10n.commonNotNow,
        onSecondary: () => Navigator.of(sheet).pop(false),
      ),
    ),
  );
  if (update == true) {
    analytics.updatePromptUpdate();
    await ref.read(linkOpenerProvider)(
      LpLinks.storeListing(defaultTargetPlatform),
    );
  } else {
    analytics.updatePromptLater();
  }
}

/// Opens What's New for [version] and waits for it to close. Marked seen as
/// it opens: shown once means seen once, however it is closed.
Future<void> showWhatsNewSheet(
  BuildContext context,
  WidgetRef ref,
  String version,
) async {
  ref.read(settingsStoreProvider.notifier).markWhatsNewSeen(version);
  ref.read(visitModalsProvider.notifier).opened(AppModal.whatsNew);
  ref.read(analyticsProvider).whatsNewShown(version);

  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => _SheetFrame(
      child: UpdateCardBody(
        version: version,
        title: sheet.l10n.whatsNewTitle,
        reason: sheet.l10n.whatsNewReason,
        notes: WhatsNewCatalog.notesFor(version, sheet.l10n),
        primaryLabel: sheet.l10n.whatsNewDone,
        onPrimary: () => Navigator.of(sheet).pop(),
      ),
    ),
  );
}

/// A bottom sheet's content area: the theme draws the surface, the rounded
/// top and the handle; this keeps the content clear of the home indicator and
/// lets it scroll when a large text size makes it taller than the screen.
class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            LpDimens.screenPadWide,
            0,
            LpDimens.screenPadWide,
            LpDimens.xl,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Shown instead of the app when Remote Config forces an update and the
/// store has a newer version (`UpdatePromptPolicy.decide`).
///
/// A route the router redirects to, not a dialog: every `go` — the splash's,
/// a notification tap's — passes through the redirect, so nothing navigates
/// past it, and a pushed dialog would be dropped by the first `go`. Back does
/// nothing ([PopScope]); there is no Not now and no close. One button: the
/// store listing. Never during a craving, the Survived screen or a store
/// sheet — the redirect waits for those to close.
class ForcedUpdateScreen extends ConsumerStatefulWidget {
  const ForcedUpdateScreen({super.key});

  @override
  ConsumerState<ForcedUpdateScreen> createState() => _ForcedUpdateScreenState();
}

class _ForcedUpdateScreenState extends ConsumerState<ForcedUpdateScreen> {
  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).updatePromptShown(forced: true);
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final check = ref.watch(updateCheckProvider);
    final language = Localizations.localeOf(context).languageCode;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: lp.background,
        body: SafeArea(
          // Scrolls only when it must: centred on a phone, and scrollable
          // under a large text size on a small one (the `_AuthScrollView`
          // shape: min-height, so the centring survives).
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(LpDimens.screenPadWide),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: LpCard(
                        padding: const EdgeInsets.all(LpDimens.xxl),
                        radius: LpDimens.rBento,
                        child: UpdateCardBody(
                          version: check.storeVersion,
                          title: l10n.updateRequiredTitle,
                          reason: l10n.updateRequiredBody,
                          notes: check.notesFor(language),
                          primaryLabel: l10n.updateCta,
                          onPrimary: () {
                            ref.read(analyticsProvider).updatePromptUpdate();
                            ref
                                .read(linkOpenerProvider)(
                                  LpLinks.storeListing(defaultTargetPlatform),
                                )
                                .ignore();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one layout all three share: version chip, title, reason, bullets,
/// buttons. In reading order, which is also the focus order.
class UpdateCardBody extends StatelessWidget {
  const UpdateCardBody({
    super.key,
    required this.version,
    required this.title,
    required this.reason,
    required this.notes,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  /// The chip's version. Null hides the chip — never a guessed number.
  final String? version;
  final String title;
  final String reason;
  final List<String> notes;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    final l10n = context.l10n;
    final version = this.version;
    // A button that grows with the text size, so a label that wraps at 200%
    // on a narrow phone still fits inside it. 56 at 100%, as everywhere else.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final buttonHeight =
        LpDimens.ctaHeight * (1 + math.max(0, scale - 1) * 0.6);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (version != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              label: l10n.updateVersionLabel(version),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: lp.voltSoft,
                  borderRadius: BorderRadius.circular(LpDimens.rChip),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.system_update_alt_rounded,
                      size: 14,
                      color: lp.voltText,
                    ),
                    const SizedBox(width: 6),
                    Text(version, style: LpType.label(lp.voltText)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: LpDimens.md),
        ],
        Semantics(
          header: true,
          child: Text(title, style: LpType.titleSm(lp.textPrimary)),
        ),
        const SizedBox(height: LpDimens.sm),
        Text(reason, style: LpType.body14(lp.textSecondary)),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: LpDimens.lg),
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: LpDimens.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: lp.volt,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      note,
                      // Store notes are free text; three lines each is plenty
                      // for a bullet and keeps a long one from owning the sheet.
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: LpType.body14(lp.textBody),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: LpDimens.xl),
        Semantics(
          button: true,
          child: LpButton(
            primaryLabel,
            height: buttonHeight,
            onTap: onPrimary,
          ),
        ),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 10),
          Semantics(
            button: true,
            child: LpButton(
              secondaryLabel!,
              style: LpButtonStyle.surface,
              height: buttonHeight,
              onTap: onSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
