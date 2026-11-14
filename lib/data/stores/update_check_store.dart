import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:upgrader/upgrader.dart';

import '../../domain/logic/release_notes.dart';
import '../../domain/logic/update_prompt_policy.dart';
import '../../domain/repositories/repositories.dart';
import 'providers.dart';

/// What the launch-time update check found (docs/10 §55).
class UpdateCheckState {
  const UpdateCheckState({
    this.settled = false,
    this.kind = UpdateKind.none,
    this.storeVersion,
    this.storeNotes,
    this.remoteNotes = RemoteReleaseNotes.empty,
    this.offered = false,
  });

  /// The check has answered — or given up, which answers [UpdateKind.none].
  /// What's New waits for this, so it never opens a moment before an update
  /// prompt that outranks it.
  final bool settled;

  final UpdateKind kind;

  /// The store's latest version, for the chip. Null when the store could not
  /// be read (and under `UPDATE_FORCE_DEBUG` without a store answer).
  final String? storeVersion;

  /// The store's own release notes, the fallback when Remote Config's do not
  /// describe [storeVersion].
  final String? storeNotes;

  final RemoteReleaseNotes remoteNotes;

  /// The optional prompt was put on screen this launch. It is offered once
  /// per launch; upgrader's three-day clock decides the next one.
  final bool offered;

  bool get forced => kind == UpdateKind.forced;

  /// Whether the optional prompt could still open this launch — undecided,
  /// or decided and not yet shown. What's New yields to it.
  bool get promptWaiting =>
      !settled || (kind == UpdateKind.optional && !offered);

  /// The bullets for a reader of [languageCode].
  List<String> notesFor(String languageCode) => UpdateNotes.resolve(
    remote: remoteNotes,
    storeVersion: storeVersion,
    storeNotes: storeNotes,
    languageCode: languageCode,
  );

  UpdateCheckState copyWith({bool? offered}) => UpdateCheckState(
    settled: settled,
    kind: kind,
    storeVersion: storeVersion,
    storeNotes: storeNotes,
    remoteNotes: remoteNotes,
    offered: offered ?? this.offered,
  );
}

/// Asks the store and Remote Config once, as the app starts, and turns the
/// answers into an [UpdateKind] through [UpdatePromptPolicy.decide].
///
/// Started by the router on the first navigation, in the background: nothing
/// waits for it, and the splash never does. Each half fails open on its own —
/// Remote Config answers no force when it cannot fetch, and a store that does
/// not answer within [storeTimeout] counts as unreadable. Not re-asked on
/// resume (`checkOnResume: false`): Google Play answers with its whole
/// listing page, and Cirrus comes to the front many times a day.
class UpdateCheckStore extends Notifier<UpdateCheckState> {
  /// upgrader puts no timeout on the store lookup; this is the one.
  static const storeTimeout = Duration(seconds: 10);

  /// Which [build] an answer belongs to. A counter, not a `disposed` flag: a
  /// rebuild runs `onDispose` but keeps this instance, so a flag set there
  /// would stay set and drop every later answer (the `invalidateSelf` gotcha).
  int _generation = 0;

  @override
  UpdateCheckState build() {
    final generation = ++_generation;
    ref.onDispose(() {
      if (_generation == generation) _generation++;
    });
    final upgrader = ref.watch(upgraderProvider);
    final debugForce = ref.watch(updateForceDebugProvider);
    // Nothing to ask (the fake backend, every widget test): answered, quietly.
    if (upgrader == null && !debugForce) {
      return const UpdateCheckState(settled: true);
    }
    unawaited(
      _run(generation, upgrader, ref.watch(remoteFlagsRepositoryProvider)),
    );
    return const UpdateCheckState();
  }

  Future<void> _run(
    int generation,
    Upgrader? upgrader,
    RemoteFlagsRepository flags,
  ) async {
    final answers = await Future.wait<Object>([
      _fetchFlags(flags),
      if (upgrader != null) _askStore(upgrader),
    ]);
    if (generation != _generation) return;
    final remote = answers[0] as RemoteFlags;
    final storeRead = answers.length > 1 && answers[1] == true;
    final storeVersion = storeRead ? upgrader!.currentAppStoreVersion : null;
    final kind = UpdatePromptPolicy.decide(
      installedVersion: upgrader?.currentInstalledVersion,
      storeVersion: storeVersion,
      forceFlag: remote.forceUpdate,
      tooSoon: upgrader != null && storeRead && upgrader.isTooSoon(),
      debugOptional: upgrader?.state.debugDisplayOnce ?? false,
      debugForce: ref.read(updateForceDebugProvider),
    );
    state = UpdateCheckState(
      settled: true,
      kind: kind,
      storeVersion: storeVersion,
      storeNotes: storeRead ? upgrader!.releaseNotes : null,
      remoteNotes: RemoteReleaseNotes.parse(remote.releaseNotes),
    );
  }

  static Future<RemoteFlags> _fetchFlags(RemoteFlagsRepository flags) async {
    try {
      return await flags.fetch();
    } on Object {
      // The contract says it never throws; fail open if it ever does.
      return RemoteFlags.none;
    }
  }

  static Future<bool> _askStore(Upgrader upgrader) async {
    try {
      await upgrader.initialize().timeout(storeTimeout);
      return upgrader.currentAppStoreVersion != null;
    } on Object catch (error) {
      debugPrint('update check: store not read, nothing offered — $error');
      return false;
    }
  }

  /// The optional prompt is on screen. Starts upgrader's three-day clock —
  /// the same moment its stock dialog starts it — so any way out of the sheet
  /// (Not now, a swipe, even Update without updating) is quiet for three days.
  void markOffered() {
    if (state.offered) return;
    state = state.copyWith(offered: true);
    ref.read(upgraderProvider)?.saveLastAlerted().ignore();
  }
}

final updateCheckProvider =
    NotifierProvider<UpdateCheckStore, UpdateCheckState>(UpdateCheckStore.new);

/// Whether the forced screen should be standing right now, as far as the
/// verdict and the store sheet go — the router adds the surface. A bool, so
/// the router's refresh fires only when it flips: when the verdict lands, and
/// when a store sheet opens or closes while an update is forced. Never on a
/// purchase when nothing is forced — a refresh mid-purchase is the gotcha
/// that once left people on a paywall they had already paid past.
final forcedUpdateArmedProvider = Provider<bool>(
  (ref) =>
      ref.watch(updateCheckProvider).forced &&
      ref.watch(storeSheetsOpenProvider) == 0,
);

/// The modals that opened in this visit — one stretch in the foreground,
/// cleared when the app is hidden (`_ServerStateSync`).
///
/// In memory on purpose: "one modal a visit" is about what somebody has just
/// been shown, and nothing about it should outlive the process.
class VisitModals extends Notifier<Set<AppModal>> {
  @override
  Set<AppModal> build() => const {};

  void opened(AppModal modal) {
    if (state.contains(modal)) return;
    state = {...state, modal};
  }

  /// Whether [modal] may open now, given this visit and [waiting].
  bool mayOpen(AppModal modal, {Set<AppModal> waiting = const {}}) =>
      UpdatePromptPolicy.mayOpen(
        modal,
        shownThisVisit: state,
        waiting: waiting,
      );

  void newVisit() {
    if (state.isNotEmpty) state = const {};
  }
}

final visitModalsProvider = NotifierProvider<VisitModals, Set<AppModal>>(
  VisitModals.new,
);
