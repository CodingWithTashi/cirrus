import 'package:flutter/widgets.dart';

import '../../domain/models/enums.dart';
import 'l10n_ext.dart';

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
