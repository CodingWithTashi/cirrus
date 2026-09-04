import 'package:flutter/material.dart';

import '../../../core/utils/enum_labels.dart';
import '../../../core/widgets/lp_selectables.dart';
import '../../../domain/logic/games/game_id.dart';
import 'game_catalog.dart';

/// The arena's pills: one per game, the one on screen selected, a dot on
/// any game with no best yet and a padlock on any this reader cannot play.
///
/// A locked pill stays visible and stays tappable. Hiding the two Premium
/// games would make the cleanest screen and sell nothing — nobody upgrades
/// for a feature they have never seen exist — and disabling the pill would
/// answer the tap with silence. The arena answers it with the lock card.
class GameSwitcher extends StatelessWidget {
  const GameSwitcher({
    super.key,
    required this.entries,
    required this.selected,
    required this.fresh,
    required this.premium,
    required this.onChanged,
  });

  final List<GameEntry> entries;
  final GameId selected;

  /// Games with no best recorded.
  final Set<GameId> fresh;

  /// Whether this reader may play the Premium games.
  final bool premium;
  final ValueChanged<GameId> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedPills(
    labels: [for (final e in entries) e.id.label(context)],
    selectedIndex: entries.indexWhere((e) => e.id == selected),
    badges: {
      for (var i = 0; i < entries.length; i++)
        if (fresh.contains(entries[i].id)) i,
    },
    locked: {
      if (!premium)
        for (var i = 0; i < entries.length; i++)
          if (entries[i].premium) i,
    },
    onChanged: (i) => onChanged(entries[i].id),
  );
}
