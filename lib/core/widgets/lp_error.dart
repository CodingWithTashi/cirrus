import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/lp_colors.dart';
import '../../app/theme/lp_typography.dart';
import '../../data/network/connectivity.dart';
import '../../domain/repositories/repositories.dart';
import '../utils/l10n_ext.dart';
import 'lp_buttons.dart';

/// Friendly (title, body) copy for a caught error — offline gets its own
/// voice, a refused app gets its own, and everything else gets the kind
/// generic one. Views use this instead of inventing per-screen phrasing.
///
/// [BackendRejectedException] is deliberately NOT folded into the offline copy.
/// Telling someone to check their connection when the connection is fine sends
/// them to reboot a router over a problem only we can fix, and it is exactly
/// how a rotated App Check secret stayed invisible for days.
({String title, String body}) lpErrorCopy(BuildContext context, Object error) {
  final l10n = context.l10n;
  return switch (error) {
    NoConnectionException() => (
      title: l10n.errorOfflineTitle,
      body: l10n.errorOfflineBody,
    ),
    BackendRejectedException() => (
      title: l10n.errorRejectedTitle,
      body: l10n.errorRejectedBody,
    ),
    _ => (title: l10n.errorGenericTitle, body: l10n.errorGenericBody),
  };
}

/// Content-area failure state: emoji + kind copy + optional "run it back".
/// Used wherever a screen's data failed to load (feed, unknown routes…).
class LpErrorState extends StatelessWidget {
  const LpErrorState({
    super.key,
    required this.emoji,
    required this.title,
    required this.body,
    this.retryLabel,
    this.onRetry,
  });

  final String emoji;
  final String title;
  final String body;
  final String? retryLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final lp = context.lp;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: LpType.emphasis(lp.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: LpType.body13(lp.textSecondary),
            ),
            if (retryLabel != null && onRetry != null) ...[
              const SizedBox(height: 18),
              LpButton(
                retryLabel!,
                style: LpButtonStyle.surface,
                height: 44,
                fontSize: 15,
                onTap: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blocking-failure dialog for an action the user explicitly asked for
/// (log in, start plan…). Same visual language as the settings dialogs.
Future<void> showLpErrorDialog(
  BuildContext context, {
  required Object error,
  VoidCallback? onRetry,
}) {
  final copy = lpErrorCopy(context, error);
  final l10n = context.l10n;
  final lp = context.lp;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(copy.title),
      content: Text(copy.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.errorGotIt, style: LpType.body14(lp.textSecondary)),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onRetry();
            },
            child: Text(
              l10n.errorRetry,
              style: LpType.body14(lp.voltText, weight: FontWeight.w600),
            ),
          ),
      ],
    ),
  );
}

/// App-level offline strip. Overlaid above every screen (MaterialApp.builder)
/// so it never fights a screen's own layout; slides away the moment the
/// connection is back. Purely informative — the app keeps working local-first.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = ref.watch(connectivityProvider);
    final lp = context.lp;
    return IgnorePointer(
      child: AnimatedSlide(
        offset: online ? const Offset(0, -1.2) : Offset.zero,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: lp.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: lp.caution.withValues(alpha: 0.55),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off_rounded, size: 14, color: lp.cautionText),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.errorOfflineBanner,
                      overflow: TextOverflow.ellipsis,
                      style: LpType.caption(lp.cautionText),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
