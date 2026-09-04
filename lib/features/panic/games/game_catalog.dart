import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../domain/logic/games/games.dart';
import 'blocks_field.dart';
import 'game_particles.dart';
import 'orbs_field.dart';
import 'tile_field.dart';

/// What the arena hands a field. Inputs are typed per engine and stay inside
/// the field; [report] is the one way an outcome reaches the arena.
class GameFieldScope {
  const GameFieldScope({
    required this.game,
    required this.frame,
    required this.combo,
    required this.ghostFrom,
    required this.accepting,
    required this.particles,
    required this.report,
  });

  final PanicGame game;
  final Listenable frame;
  final int combo;
  final int ghostFrom;

  /// The arena's sparks; here so tests can read it.
  final ParticleSystem particles;

  /// False between rounds and while paused.
  final bool accepting;

  /// An input resolved: [feedback] drives the haptic, [at] the particles.
  final void Function(GameFeedback feedback, {({double x, double y})? at})
  report;
}

/// One panic game as the arena sees it. Adding a game is an engine, a field
/// and one entry here.
class GameEntry {
  const GameEntry({
    required this.id,
    required this.ghostFrom,
    required this.create,
    required this.field,
    this.sparkOnHit = false,
    this.showsHint = true,
    this.premium = false,
  });

  final GameId id;

  /// Whether a subscription is needed to play it (founder decision Sep 3
  /// 2026, docs/12 §5c). Orbs is free forever and is [entries]`.first`, so a
  /// free account's default game is always a playable one — the lock is only
  /// ever met by deliberately tapping a locked pill, never on arrival.
  final bool premium;

  /// The combo the ghost number appears at.
  final int ghostFrom;

  /// Whether every hit throws sparks (an orb found, not a tile hit twice a
  /// second).
  final bool sparkOnHit;

  /// Whether the arena shows its one-line hint; a game with its own phase
  /// prompts (Orbs) does not need one.
  final bool showsHint;

  /// A fresh engine; tests pass a seeded [math.Random].
  final PanicGame Function(math.Random? random) create;

  final Widget Function(GameFieldScope scope) field;
}

/// The games the arena offers, in switcher order.
///
/// **Orbs is first, and that is load-bearing.** [resolve] falls back to
/// `entries.first`, and [resolveFor] clamps to the first FREE entry, so the
/// arena's default — for a new user, and for anyone whose subscription has
/// lapsed — is a game they can actually play. Nobody meets a lock by opening
/// the arena mid-craving; they meet it only by tapping a locked pill.
abstract final class GameCatalog {
  static const List<GameEntry> entries = [
    GameEntry(
      id: GameId.orbs,
      ghostFrom: 3,
      create: _orbs,
      field: _orbsField,
      sparkOnHit: true,
      showsHint: false,
    ),
    GameEntry(
      id: GameId.tiles,
      ghostFrom: 3,
      create: _tiles,
      field: _tileField,
      premium: true,
    ),
    // A clear is a rarer beat than a tile hit: the ghost shows from two.
    GameEntry(
      id: GameId.blocks,
      ghostFrom: 2,
      create: _blocks,
      field: _blocksField,
      premium: true,
    ),
  ];

  static GameEntry? of(GameId id) =>
      entries.where((e) => e.id == id).firstOrNull;

  /// The entry for [id], or the first game when unknown or null.
  static GameEntry resolve(GameId? id) =>
      (id == null ? null : of(id)) ?? entries.first;

  /// The game to OPEN on for a reader of this tier.
  ///
  /// Clamps to a free game whenever [premium] is false, which covers the two
  /// ways a locked game would otherwise be the landing spot: a stored
  /// `lastGame` from a subscription that has since lapsed, and a `?g=` deep
  /// link. Both would put a purchase decision in front of somebody at 9/10
  /// craving intensity before they had asked for one, which is exactly what
  /// docs/12 §4.2 removed from this flow.
  static GameEntry resolveFor(GameId? id, {required bool premium}) {
    final entry = resolve(id);
    if (premium || !entry.premium) return entry;
    return entries.firstWhere((e) => !e.premium);
  }

  static PanicGame _tiles(math.Random? random) => TileGame(random: random);
  static PanicGame _blocks(math.Random? random) => BlocksGame(random: random);
  static PanicGame _orbs(math.Random? random) => OrbsGame(random: random);

  static Widget _tileField(GameFieldScope scope) => TileField(scope: scope);
  static Widget _blocksField(GameFieldScope scope) => BlocksField(scope: scope);
  static Widget _orbsField(GameFieldScope scope) => OrbsField(scope: scope);
}
