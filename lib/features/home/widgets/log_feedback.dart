import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../data/stores/providers.dart';

/// "Logged. Undo?" — 5-second undo snackbar after every log (docs/03 §2).
void showLogUndoSnack(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  showLpSnack(
    context,
    l10n.homeLoggedSnack,
    actionLabel: l10n.commonUndo,
    duration: const Duration(seconds: 5),
    onAction: () => ref.read(quitStoreProvider.notifier).undoLastPuff(),
  );
}
