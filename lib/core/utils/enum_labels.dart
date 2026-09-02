import 'package:flutter/widgets.dart';

import '../../domain/logic/games/game_id.dart';
import '../../domain/logic/spend_comparisons.dart';
import '../../domain/models/enums.dart';
import 'l10n_ext.dart';

/// The panic games as the arena names them; the unit is the countable thing
/// each score is.
extension GameIdLabel on GameId {
  String get emoji => switch (this) {
    GameId.tiles => '🎹',
    GameId.blocks => '🧱',
    GameId.orbs => '🔮',
  };

  String label(BuildContext context) => switch (this) {
    GameId.tiles => context.l10n.gameNameTiles,
    GameId.blocks => context.l10n.gameNameBlocks,
    GameId.orbs => context.l10n.gameNameOrbs,
  };

  String hint(BuildContext context) => switch (this) {
    GameId.tiles => context.l10n.gameHintTiles,
    GameId.blocks => context.l10n.gameHintBlocks,
    GameId.orbs => context.l10n.gameHintOrbs,
  };

  String unit(BuildContext context, int count) => switch (this) {
    GameId.tiles => context.l10n.gameUnitTiles(count),
    GameId.blocks => context.l10n.gameUnitBlocks(count),
    GameId.orbs => context.l10n.gameUnitOrbs(count),
  };
}

/// Localized display names for domain enums, shared by every feature.
extension WhyChipLabel on WhyChip {
  String label(BuildContext context) => switch (this) {
    WhyChip.health => context.l10n.obWhyHealth,
    WhyChip.money => context.l10n.obWhyMoney,
    WhyChip.freedom => context.l10n.obWhyFreedom,
    WhyChip.family => context.l10n.obWhyFamily,
    WhyChip.fitness => context.l10n.obWhyFitness,
    WhyChip.appearance => context.l10n.obWhyAppearance,
  };
}

extension WorryChipLabel on WorryChip {
  String label(BuildContext context) => switch (this) {
    WorryChip.cravings => context.l10n.obWorryCravings,
    WorryChip.stress => context.l10n.obWorryStress,
    WorryChip.social => context.l10n.obWorrySocial,
    WorryChip.failing => context.l10n.obWorryFailing,
    WorryChip.weight => context.l10n.obWorryWeight,
    WorryChip.breaks => context.l10n.obWorryBreaks,
  };
}

extension SlipTriggerLabel on SlipTrigger {
  String label(BuildContext context) => switch (this) {
    SlipTrigger.party => context.l10n.slipTriggerParty,
    SlipTrigger.stress => context.l10n.slipTriggerStress,
    SlipTrigger.boredom => context.l10n.slipTriggerBoredom,
    SlipTrigger.drinking => context.l10n.slipTriggerDrinking,
    SlipTrigger.friends => context.l10n.slipTriggerFriends,
    SlipTrigger.justHappened => context.l10n.slipTriggerJustHappened,
  };
}

extension QuitMethodLabel on QuitMethod {
  String label(BuildContext context) => switch (this) {
    QuitMethod.taper => context.l10n.planMethodTaper,
    QuitMethod.coldTurkey => context.l10n.planMethodCold,
  };
}

extension PostTagLabel on PostTag {
  String label(BuildContext context) => switch (this) {
    PostTag.win => context.l10n.communityTagWin,
    PostTag.sos => context.l10n.communityTagSos,
    PostTag.day1 => context.l10n.communityTagDay1,
    PostTag.milestone => context.l10n.communityTagMilestone,
    PostTag.vent => context.l10n.communityTagVent,
  };
}

/// The comparison catalogue's nouns. An exhaustive switch, so adding a
/// [SpendItem] does not compile until it has been localized — the same
/// guarantee [WhyChipLabel] gives.
extension SpendItemLabel on SpendItem {
  String label(BuildContext context) => switch (this) {
    SpendItem.gymMonth => context.l10n.obSpendItemGymMonth,
    SpendItem.concertTicket => context.l10n.obSpendItemConcertTicket,
    SpendItem.runningShoes => context.l10n.obSpendItemRunningShoes,
    SpendItem.dentalCleaning => context.l10n.obSpendItemDentalCleaning,
    SpendItem.winterCoat => context.l10n.obSpendItemWinterCoat,
    SpendItem.festivalTicket => context.l10n.obSpendItemFestivalTicket,
    SpendItem.weekendAway => context.l10n.obSpendItemWeekendAway,
    SpendItem.bike => context.l10n.obSpendItemBike,
    SpendItem.drivingLessons => context.l10n.obSpendItemDrivingLessons,
    SpendItem.newPhone => context.l10n.obSpendItemNewPhone,
    SpendItem.laptop => context.l10n.obSpendItemLaptop,
    SpendItem.emergencyFund => context.l10n.obSpendItemEmergencyFund,
    SpendItem.yogaYear => context.l10n.obSpendItemYogaYear,
    SpendItem.monthOfRent => context.l10n.obSpendItemMonthOfRent,
    SpendItem.familyHoliday => context.l10n.obSpendItemFamilyHoliday,
    SpendItem.usedCar => context.l10n.obSpendItemUsedCar,
  };
}
