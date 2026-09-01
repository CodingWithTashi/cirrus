import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/lp_dimens.dart';
import '../../../core/utils/l10n_ext.dart';
import '../../../core/widgets/lp_misc.dart';
import '../../../data/stores/providers.dart';

/// Quick-log burst: consecutive taps within [PuffBurst.window] form one
/// burst. The ring's rolling number shows the running total live, the snack
/// shows the burst total, and its Undo takes back the whole burst. A pause
/// longer than the window starts a fresh burst.
///
/// **One tap is one puff. Always.** This used to ramp the per-tap increment
/// (+1, +1, +1, +2, +2, +3, +3, +5…) so "I had ~30" was a dozen taps. The
/// Aug 31 2026 QA pass found what that does in the field: 18 taps at the
/// cadence of a stressed user hammering the button mid-craving logged 68
/// puffs, and a 5-tap burst logged 7 — while the store fired exactly once per
/// pointer-up (pinned by `test/widgets/log_puff_tap_test.dart`). An inflated
/// count poisons the limit, the streak, the money and every number the coach
/// quotes, so the ramp is gone: a burst still groups taps for the snack and
/// its Undo, but every tap counts what it is. "I had ~30" is a press-and-hold
/// ([HoldToLog]), which ticks one puff at a time on a clock the user can see.
///
/// State is the burst's running total (what the snack and Undo need); shared
/// through one provider so the Home CTA and the tab-bar quick-log extend the
/// same burst instead of racing each other.
class PuffBurst extends Notifier<int> {
  static const window = Duration(milliseconds: 1200);

  DateTime? _lastTap;

  @override
  int build() => 0;

  /// Registers one tap and returns how many puffs it logs — always exactly
  /// one. [at] mirrors `logPuff({at})` — tests drive the window with it;
  /// views omit it.
  int tap({DateTime? at}) {
    final now = at ?? DateTime.now();
    final last = _lastTap;
    if (last == null || now.difference(last) > window) state = 0;
    _lastTap = now;
    state += 1;
    return 1;
  }

  /// After an undo the next tap must not continue the reversed burst.
  void reset() {
    _lastTap = null;
    state = 0;
  }
}

final puffBurstProvider = NotifierProvider<PuffBurst, int>(PuffBurst.new);

/// One quick-log step — the shared unit behind a tap AND a hold-repeat tick:
/// registers a burst tap and logs its increment. Returns the burst's running
/// total (what the undo snack shows).
int quickLogStep(WidgetRef ref) {
  final increment = ref.read(puffBurstProvider.notifier).tap();
  ref.read(quitStoreProvider.notifier).logPuff(count: increment);
  return ref.read(puffBurstProvider);
}

/// Auto-repeat driver for press-and-hold logging: ticks immediately on
/// [start], then every [interval] until [stop]. Each tick is one burst tap —
/// one puff — so the count the ring shows while held is the count logged; a
/// ~2s hold reaches ~11 puffs, a ~5s hold ~30. Owners must call [stop] from
/// `dispose`; a timer outliving its screen would keep logging into a
/// torn-down tree.
class HoldToLog {
  static const interval = Duration(milliseconds: 180);

  Timer? _timer;

  bool get held => _timer != null;

  void start(VoidCallback tick) {
    stop();
    tick();
    _timer = Timer.periodic(interval, (_) => tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// "Logged N puffs. Undo?" — 5-second undo snackbar after every log
/// (docs/03 §2), showing the current burst's total; Undo reverses all of it.
///
/// [aboveCta] lifts the snack clear of the Home thumb zone — above the LOG
/// PUFF hero button and left of the SOS float, so neither control is ever
/// blocked by its own confirmation. Callers on screens without that bottom
/// CTA leave it false and get the default bottom placement.
void showLogUndoSnack(
  BuildContext context,
  WidgetRef ref, {
  int count = 1,
  bool aboveCta = false,
}) {
  final l10n = context.l10n;
  showLpSnack(
    context,
    l10n.homeLoggedSnackCount(count),
    actionLabel: l10n.commonUndo,
    duration: const Duration(seconds: 5),
    margin: aboveCta
        // Bottom clears the CTA zone (8 top pad + hero height + 12 bottom
        // pad + a 6px gap); right clears the 54px SOS float at right: 16.
        ? const EdgeInsets.fromLTRB(16, 0, 86, LpDimens.ctaHeightHero + 26)
        : null,
    onAction: () {
      ref.read(quitStoreProvider.notifier).undoPuffs(count);
      ref.read(puffBurstProvider.notifier).reset();
    },
  );
}
