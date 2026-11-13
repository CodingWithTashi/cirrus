import '../../domain/logic/quit_program.dart';
import '../../l10n/gen/app_localizations.dart';

/// The words for the daily program's ids (docs/15 stage B).
///
/// Resolved here, in one place, so the Home card and the notification say the
/// same thing and so a new id is a compile error until its copy exists — the
/// way `CoachTemplate` resolves coach replies. `program_copy_resolver_test`
/// checks every id against the entry of its own name in all six locales.
extension ProgramMessageCopy on ProgramMessage {
  String text(AppLocalizations l10n) => switch (this) {
    ProgramMessage.pre7 => l10n.programMsgPre7,
    ProgramMessage.pre6 => l10n.programMsgPre6,
    ProgramMessage.pre5 => l10n.programMsgPre5,
    ProgramMessage.pre4 => l10n.programMsgPre4,
    ProgramMessage.pre3 => l10n.programMsgPre3,
    ProgramMessage.pre2 => l10n.programMsgPre2,
    ProgramMessage.pre1 => l10n.programMsgPre1,
    ProgramMessage.q0am => l10n.programMsgQ0am,
    ProgramMessage.q0pm => l10n.programMsgQ0pm,
    ProgramMessage.d1am => l10n.programMsgD1am,
    ProgramMessage.d1pm => l10n.programMsgD1pm,
    ProgramMessage.d2am => l10n.programMsgD2am,
    ProgramMessage.d2pm => l10n.programMsgD2pm,
    ProgramMessage.d3 => l10n.programMsgD3,
    ProgramMessage.d4 => l10n.programMsgD4,
    ProgramMessage.d5 => l10n.programMsgD5,
    ProgramMessage.d6 => l10n.programMsgD6,
    ProgramMessage.d7 => l10n.programMsgD7,
    ProgramMessage.d8 => l10n.programMsgD8,
    ProgramMessage.d9 => l10n.programMsgD9,
    ProgramMessage.d10 => l10n.programMsgD10,
    ProgramMessage.d11 => l10n.programMsgD11,
    ProgramMessage.d12 => l10n.programMsgD12,
    ProgramMessage.d13 => l10n.programMsgD13,
    ProgramMessage.d14 => l10n.programMsgD14,
    ProgramMessage.d16 => l10n.programMsgD16,
    ProgramMessage.d18 => l10n.programMsgD18,
    ProgramMessage.d21 => l10n.programMsgD21,
    ProgramMessage.d23 => l10n.programMsgD23,
    ProgramMessage.d25 => l10n.programMsgD25,
    ProgramMessage.d28 => l10n.programMsgD28,
    ProgramMessage.d30 => l10n.programMsgD30,
    ProgramMessage.d32 => l10n.programMsgD32,
    ProgramMessage.d35 => l10n.programMsgD35,
    ProgramMessage.d37 => l10n.programMsgD37,
    ProgramMessage.d39 => l10n.programMsgD39,
    ProgramMessage.d42 => l10n.programMsgD42,
    ProgramMessage.d44 => l10n.programMsgD44,
    ProgramMessage.d46 => l10n.programMsgD46,
    ProgramMessage.d49 => l10n.programMsgD49,
    ProgramMessage.d51 => l10n.programMsgD51,
    ProgramMessage.d53 => l10n.programMsgD53,
    ProgramMessage.d56 => l10n.programMsgD56,
  };
}

extension ProgramReplyCopy on ProgramReply {
  /// [why] is the person's own words, for the replies that quote them; a reply
  /// that needs it is never chosen when they gave none (`QuitProgram.replyFor`).
  String text(AppLocalizations l10n, {String? why}) => switch (this) {
    ProgramReply.breathe => l10n.programReplyBreathe,
    ProgramReply.waitTen => l10n.programReplyWaitTen,
    ProgramReply.changeRoom => l10n.programReplyChangeRoom,
    ProgramReply.tellSomeone => l10n.programReplyTellSomeone,
    ProgramReply.okayHold => l10n.programReplyOkayHold,
    ProgramReply.okayOne => l10n.programReplyOkayOne,
    ProgramReply.okayShort => l10n.programReplyOkayShort,
    ProgramReply.praiseWhy1 => l10n.programReplyPraiseWhy1(why ?? ''),
    ProgramReply.praiseWhy2 => l10n.programReplyPraiseWhy2(why ?? ''),
    ProgramReply.praise3 => l10n.programReplyPraise3,
    ProgramReply.praise4 => l10n.programReplyPraise4,
    ProgramReply.slipData => l10n.programReplySlipData,
    ProgramReply.slipToday => l10n.programReplySlipToday,
    ProgramReply.slipPlan => l10n.programReplySlipPlan,
  };
}

extension ProgramTipCopy on ProgramTip {
  String text(AppLocalizations l10n) => switch (this) {
    ProgramTip.stress1 => l10n.programTipStress1,
    ProgramTip.stress2 => l10n.programTipStress2,
    ProgramTip.stress3 => l10n.programTipStress3,
    ProgramTip.stress4 => l10n.programTipStress4,
    ProgramTip.stress5 => l10n.programTipStress5,
    ProgramTip.slip1 => l10n.programTipSlip1,
    ProgramTip.slip2 => l10n.programTipSlip2,
    ProgramTip.slip3 => l10n.programTipSlip3,
    ProgramTip.slip4 => l10n.programTipSlip4,
    ProgramTip.more1 => l10n.programTipMore1,
    ProgramTip.more2 => l10n.programTipMore2,
    ProgramTip.more3 => l10n.programTipMore3,
    ProgramTip.more4 => l10n.programTipMore4,
    ProgramTip.more5 => l10n.programTipMore5,
    ProgramTip.more6 => l10n.programTipMore6,
    ProgramTip.more7 => l10n.programTipMore7,
    ProgramTip.more8 => l10n.programTipMore8,
    ProgramTip.more9 => l10n.programTipMore9,
    ProgramTip.more10 => l10n.programTipMore10,
    ProgramTip.more11 => l10n.programTipMore11,
    ProgramTip.more12 => l10n.programTipMore12,
  };
}
