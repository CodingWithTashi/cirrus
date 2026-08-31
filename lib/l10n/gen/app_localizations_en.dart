// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline => 'Your last puff is closer\nthan you think.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · made by people who quit';
  }

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDone => 'Done';

  @override
  String get commonSave => 'Save';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNotNow => 'Not now';

  @override
  String get commonMaybeLater => 'Maybe later';

  @override
  String commonDayN(int day) {
    return 'day $day';
  }

  @override
  String get authSignInTitle => 'Let\'s keep your\nplan safe.';

  @override
  String get authSignInSubtitle =>
      'Anonymous by default — you\'ll pick an alias for community.';

  @override
  String get authSignInWithApple => 'Sign in with Apple';

  @override
  String get authSignInWithGoogle => 'Sign in with Google';

  @override
  String get authContinueWithEmail => 'Continue with email';

  @override
  String get authWhyAccountDivider => 'why an account?';

  @override
  String get authWhyAccountCard =>
      'Your streak, plan, and coach memory sync across devices. 🔒 We never sell your data. No ad trackers. Ever.';

  @override
  String get authTerms => 'Terms';

  @override
  String get authPrivacy => 'Privacy';

  @override
  String get authRestorePurchase => 'Restore purchase';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'PASSWORD';

  @override
  String get authShowPassword => 'show';

  @override
  String get authHidePassword => 'hide';

  @override
  String get authPasswordStrengthWeak => 'keep typing…';

  @override
  String get authPasswordStrengthDecent => 'decent password';

  @override
  String get authPasswordStrengthStrong => 'strong password';

  @override
  String get authNoSpamCard =>
      'No spam, no \"we miss you\" emails. Account = backup, that\'s it.';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authAlreadyHaveOne => 'Already have one?';

  @override
  String get authLogIn => 'Log in';

  @override
  String get authLoginTitle => 'Welcome back.';

  @override
  String get authLoginSubtitle => 'Your streak missed you.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNewHere => 'New here?';

  @override
  String get authWrongPassword => 'not that one — try again';

  @override
  String get authForgotTitle => 'Happens to everyone.';

  @override
  String get authForgotSubtitle =>
      'Drop your email — we\'ll send a reset link. Your streak is untouched.';

  @override
  String get authLinkSent => 'Link sent. Check spam if it hides.';

  @override
  String get authResendLink => 'Resend link';

  @override
  String authResendCountdown(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Back to log in';

  @override
  String get authInvalidEmail => 'that doesn\'t look like an email';

  @override
  String get authEmailInUse =>
      'that email already has a journey — log in instead';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint => 'puffs a day — you\'re about to find out';

  @override
  String get obWelcomeTitle => 'How dependent are you, really?';

  @override
  String get obWelcomeSubtitle =>
      '2-minute check-up. Brutally honest results. A plan built for you.';

  @override
  String get obWelcomeCta => 'Start my check-up';

  @override
  String get obResumeTitle => 'Pick up where you left off?';

  @override
  String obResumeBody(int answered, int total) {
    return 'You\'d answered $answered of $total questions. Nothing\'s lost.';
  }

  @override
  String get obResumeCta => 'Carry on';

  @override
  String get obResumeFresh => 'Start fresh';

  @override
  String get obGenderTitle => 'How do you identify?';

  @override
  String get obGenderSubtitle =>
      'Calibrates your plan — nicotine metabolism differs.';

  @override
  String get obGenderWoman => 'Woman';

  @override
  String get obGenderMan => 'Man';

  @override
  String get obGenderNonBinary => 'Non-binary / prefer not to say';

  @override
  String get obGenderPrivacyNote => '🔒 Private. Never shown to the community.';

  @override
  String get obBirthYearTitle => 'What year were you born?';

  @override
  String get obBirthYearSubtitle => 'Your plan adapts to your age.';

  @override
  String get obBirthYearHint => 'Year or age — either one works.';

  @override
  String obBirthYearAge(int age) {
    return 'You\'re $age.';
  }

  @override
  String obBirthYearAgeOffer(int age, int year) {
    return '$age? That\'d be born $year.';
  }

  @override
  String get obBirthYearAgeConfirm => 'That\'s me';

  @override
  String obBirthYearUnderConfirm(int year, int age) {
    return 'Born $year? That makes you $age.';
  }

  @override
  String obBirthYearUnderCta(int age) {
    return 'Yes, I\'m $age';
  }

  @override
  String get obBirthYearFix => 'Let me fix that';

  @override
  String get obBirthYearErrorFuture =>
      'That year hasn\'t happened yet. Want another go?';

  @override
  String get obBirthYearErrorTooOld =>
      'The oldest person ever verified made it to 122. Let\'s try that again.';

  @override
  String get obBirthYearErrorUnknown =>
      'That\'s not a year — and not an age either. One more go.';

  @override
  String get obUnder18Title => 'We can\'t help you here — but this can.';

  @override
  String get obUnder18Subtitle =>
      'Cirrus is built for 18+. These two are free, private, and made for people your age. They work.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Daily texts from people who get it. 500,000+ young people enrolled.';

  @override
  String get obUnder18TiqCta => 'Text DITCHVAPE to 88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Free coaching by text or call, made for teens. No lectures.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'Rooting for you. Come back at 18 if you still need us — you won\'t. 💪';

  @override
  String get obTriedTitle => 'Tried quitting before?';

  @override
  String get obTriedNever => 'Never';

  @override
  String get obTriedNeverSub => 'first rodeo';

  @override
  String get obTriedOnce => 'Once';

  @override
  String get obTriedOnceSub => 'didn\'t stick';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'a few rounds';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'lost count';

  @override
  String get obTriedReaction =>
      'Most people need a few tries. Every one taught your brain something — this time you\'ll have a plan.';

  @override
  String get obFrequencyTitle => 'How often is it in your hand?';

  @override
  String get obFrequencySubtitle => 'No judgment. Just calibration.';

  @override
  String get obFreqDaily => 'DAILY';

  @override
  String get obFreqDailySub => 'Every day, with real breaks in between.';

  @override
  String get obFreqOften => 'OFTEN';

  @override
  String get obFreqOftenSub => 'Most of the day, some sessions.';

  @override
  String get obFreqAlways => 'ALWAYS';

  @override
  String get obFreqAlwaysSub => 'It\'s basically part of my hand.';

  @override
  String get obPuffsTitle => 'Puffs on a normal day?';

  @override
  String get obPuffsBadgeLight => 'Light habit';

  @override
  String get obPuffsBadgeModerate => 'Moderate dependence';

  @override
  String get obPuffsBadgeHeavy => 'Heavy dependence';

  @override
  String get obPuffsBadgeSevere => 'Severe dependence';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ $count cigarettes\' worth of puffs';
  }

  @override
  String get obPuffsNotSure => 'Not sure? Estimate from device life →';

  @override
  String get obPuffsHelperTitle => 'Quick estimate';

  @override
  String get obPuffsHelperBody =>
      'A typical disposable is ~600 puffs. How many do you finish a week?';

  @override
  String obPuffsHelperResult(int count) {
    return 'That\'s about $count puffs a day. We\'ll self-correct in your first week.';
  }

  @override
  String obPuffsHelperDevicesPerWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices / week',
      one: '$count device / week',
    );
    return '$_temp0';
  }

  @override
  String get obStrengthTitle => 'How strong is your usual?';

  @override
  String get obStrength20Sub => '2% · lighter';

  @override
  String get obStrength35Sub => '3.5% · mid';

  @override
  String get obStrength50Sub => '5% · most disposables';

  @override
  String get obStrengthNotSure => 'Not sure';

  @override
  String get obStrengthNotSureSub => 'totally fine';

  @override
  String get obStrengthNote =>
      'Most disposables are 5% — if unsure, that\'s the safe guess.';

  @override
  String get obSpendTitle => 'What\'s it costing you a week?';

  @override
  String get obSpendPerWeek => 'per week';

  @override
  String get obSpendThats => 'that\'s';

  @override
  String obSpendPerYear(String amount) {
    return '$amount a year';
  }

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / month';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / day';
  }

  @override
  String get obSpendYourMath => 'your math, not ours';

  @override
  String obSpendComparisonOne(String item) {
    return 'That\'s $item. Every year.';
  }

  @override
  String obSpendComparisonTwo(String item) {
    return 'That\'s $item — twice over. Every year.';
  }

  @override
  String obSpendComparisonMany(String item, int count) {
    return 'That\'s $item, $count times over. Every year.';
  }

  @override
  String get obSpendItemGymMonth => 'a month at the gym';

  @override
  String get obSpendItemConcertTicket => 'a concert ticket, good seats';

  @override
  String get obSpendItemRunningShoes => 'a proper pair of running shoes';

  @override
  String get obSpendItemDentalCleaning => 'a dental cleaning';

  @override
  String get obSpendItemWinterCoat => 'a winter coat that actually works';

  @override
  String get obSpendItemFestivalTicket => 'a festival ticket, camping and all';

  @override
  String get obSpendItemWeekendAway => 'a weekend away';

  @override
  String get obSpendItemBike => 'a bike worth riding';

  @override
  String get obSpendItemDrivingLessons => 'a full set of driving lessons';

  @override
  String get obSpendItemNewPhone => 'a new phone';

  @override
  String get obSpendItemLaptop => 'a laptop that isn\'t dying';

  @override
  String get obSpendItemEmergencyFund => 'a real emergency fund';

  @override
  String get obSpendItemYogaYear => 'a year of unlimited yoga';

  @override
  String get obSpendItemMonthOfRent => 'a month of rent';

  @override
  String get obSpendItemFamilyHoliday => 'a family holiday';

  @override
  String get obSpendItemUsedCar => 'a car that gets you there';

  @override
  String get obFirstPuffTitle => 'First puff after waking up?';

  @override
  String get obFirstPuffWithin5 => 'Within 5 minutes';

  @override
  String get obFirstPuff5to30 => '5–30 minutes';

  @override
  String get obFirstPuff30to60 => '30–60 minutes';

  @override
  String get obFirstPuffHourPlus => 'An hour or more';

  @override
  String get obFirstPuffScience =>
      'Time-to-first-puff is the strongest single predictor of dependence. 76% of young vapers reach for it within 30 min of waking.';

  @override
  String get obFactLabelScience => 'THE SCIENCE';

  @override
  String get obFactLabelYourNumbers => 'YOUR NUMBERS';

  @override
  String get obFactTried =>
      'Among daily young users, failed quit attempts went from 28% to 53% between 2020 and 2024. The devices got better at their job. That isn\'t you getting weaker — it\'s an arms race nobody asked you to enter.';

  @override
  String obFactStrength(int mg) {
    return 'That\'s ≈$mg mg of nicotine a day. Your numbers, our multiplying. Your vape, meanwhile, has never once suggested a portion size.';
  }

  @override
  String get obFactWorryCravings =>
      'Most cravings peak and pass inside 15–20 minutes. Shorter than waiting for a table. The panic button is built around exactly that window.';

  @override
  String get obFactWorrySocial =>
      'Peer support raises quit success by around 40%. Yes — strangers on the internet. We were surprised too.';

  @override
  String get obWhyTitle => 'Why do you want out?';

  @override
  String get obWhySubtitle =>
      'Pick all that hit. Your coach will use these when it gets hard.';

  @override
  String get obWhyHealth => 'Health';

  @override
  String get obWhyMoney => 'Money';

  @override
  String get obWhyFreedom => 'Freedom';

  @override
  String get obWhyFamily => 'Family';

  @override
  String get obWhyFitness => 'Fitness';

  @override
  String get obWhyAppearance => 'Appearance';

  @override
  String get obWhyCardLabel => 'YOUR WHY';

  @override
  String get obWorriesTitle => 'What worries you most?';

  @override
  String get obWorriesSubtitle => 'Be honest. This is the useful part.';

  @override
  String get obWorryCravings => 'Cravings';

  @override
  String get obWorryStress => 'Stress';

  @override
  String get obWorrySocial => 'Social pressure';

  @override
  String get obWorryFailing => 'Fear of failing';

  @override
  String get obWorryWeight => 'Weight gain';

  @override
  String get obWorryBreaks => 'Losing my breaks';

  @override
  String get obWorriesAiNote =>
      'Your coach trains on exactly these. Craving at 11 p.m.? It already knows your playbook.';

  @override
  String get obMethodFailingNote =>
      'You picked \"fear of failing\" — so this plan bends instead of breaking. A slip adjusts the curve; nothing ever resets.';

  @override
  String get obMethodTitle => 'How do you want to do this?';

  @override
  String get obMethodSubtitle => 'Both work. One honest line each.';

  @override
  String get obMethodTaper => 'Taper down';

  @override
  String get obMethodTaperSub =>
      'Ease off on a daily curve. Gentler withdrawal, takes discipline.';

  @override
  String get obMethodTaperReco => 'Best for 100+ puffs/day — that\'s you';

  @override
  String get obMethodCold => 'Cold turkey';

  @override
  String get obMethodColdSub =>
      'One hard stop. Rough first week, out of the woods faster.';

  @override
  String get obMethodColdReco => 'Doable at your level — your call';

  @override
  String get obPaceTitle => 'Pick your pace.';

  @override
  String obPaceMostChosen(int days) {
    return '$days days — most chosen';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count puffs';
  }

  @override
  String get obPaceCurveLabel => 'your curve';

  @override
  String get obPaceCurveEnd => '0 puffs';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Freedom Day';
  }

  @override
  String get obPaceNote =>
      'Curve redraws live as you tap a pace. Real dates, not \"day n\".';

  @override
  String get obPaceCta => 'Lock my pace';

  @override
  String get obBuildingTitle => 'Building your plan…';

  @override
  String obBuildingStep1(int count) {
    return 'Analyzing $count puffs/day';
  }

  @override
  String get obBuildingStep2 => 'Mapping your triggers';

  @override
  String obBuildingStep3(int days) {
    return 'Calibrating your $days-day curve…';
  }

  @override
  String get obBuildingStep4 => 'Reserving your coach…';

  @override
  String obRevealTitle(int days) {
    return 'Your $days-day breakup plan.';
  }

  @override
  String get obRevealMilestone3 => 'craving peak — we\'ll be loudest here';

  @override
  String get obRevealMilestone7 => 'taste and smell come back';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Freedom Day — $date';
  }

  @override
  String get obRevealSavedLabel => 'saved by Freedom Day';

  @override
  String get obRevealPuffsLabel => 'puffs you won\'t take';

  @override
  String get obRevealProofLabel => 'HONEST PROOF';

  @override
  String get obRevealProof =>
      '24% quit with a structured program vs 19% alone — randomized trial of 2,588 young adults. Not magic. Better odds.';

  @override
  String obRevealComparisonOne(String item) {
    return 'By Freedom Day, that\'s $item.';
  }

  @override
  String obRevealComparisonTwo(String item) {
    return 'By Freedom Day, that\'s $item — twice over.';
  }

  @override
  String obRevealComparisonMany(String item, int count) {
    return 'By Freedom Day, that\'s $item, $count times over.';
  }

  @override
  String get obRevealCta => 'I\'m ready';

  @override
  String get obCommitTitle => 'Make it real.';

  @override
  String get obCommitSubtitle => 'Hold the button. Mean it.';

  @override
  String get obCommitHold => 'Hold to\ncommit';

  @override
  String get obCommitFreedomLabel => '🏆 FREEDOM DAY';

  @override
  String obCommitDaysOut(int days) {
    return '$days days from today. It\'s on the calendar.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 We never sell your data. No ad trackers. Ever.';

  @override
  String get obRatingTitle =>
      'One quitter\'s review helps the next one find us.';

  @override
  String get obRatingSubtitle => '30 seconds. Skippable. No hard feelings.';

  @override
  String get obRatingBetaTester => 'BETA TESTER';

  @override
  String get obRatingQuote1 =>
      '\"The panic button got me through week one. I\'d have caved on day 3 without it.\"';

  @override
  String get obRatingQuote2 =>
      '\"First app that didn\'t talk to me like a doctor or my mom.\"';

  @override
  String get obRatingCta => 'Rate Cirrus';

  @override
  String obCoachNameTitle(String name) {
    return 'We call it $name.';
  }

  @override
  String get obCoachNameSubtitle =>
      'Your coach. Quit two years ago, remembers exactly how it felt, and has already read your plan.';

  @override
  String obCoachNameAsk(String name) {
    return 'We went with $name because it needed one. Nobody remembers a name someone else picked, though — so if you have a better idea, use it. Whatever you\'d actually text at 2am, mid-argument with yourself in the kitchen.';
  }

  @override
  String get obCoachNameFieldLabel => 'Coach\'s name';

  @override
  String get obCoachNameSuggestions => 'Or borrow one:';

  @override
  String obCoachNameKeep(String name) {
    return 'Keep $name';
  }

  @override
  String get obCoachNameCta => 'That\'s the one';

  @override
  String get obCoachNameLater => 'You can change it any time in Settings.';

  @override
  String get obCoachNameErrorEmpty => 'Give them something to be called.';

  @override
  String get obCoachNameErrorLong => 'Keep it to 20 characters or fewer.';

  @override
  String get obCoachNameErrorChars => 'Letters, numbers, spaces and - \' only.';

  @override
  String get obCoachNameErrorRejected => 'Let\'s pick a different one.';

  @override
  String get settingsCoachName => 'Your coach\'s name';

  @override
  String coachRenamed(String name) {
    return 'Alright — $name from now on.';
  }

  @override
  String get obCoachNameSuggestion1 => 'Pip';

  @override
  String get obCoachNameSuggestion2 => 'Fin';

  @override
  String get obCoachNameSuggestion3 => 'Koda';

  @override
  String get obCoachNameSuggestion4 => 'Wren';

  @override
  String obWhyWordsTitle(String name) {
    return 'Tell $name one thing.';
  }

  @override
  String get obWhyWordsSubtitle =>
      'Why now? Not the health-class answer — the real one.';

  @override
  String get obWhyWordsFieldLabel => 'In your own words';

  @override
  String get obWhyWordsHint => 'so I can run with her without stopping';

  @override
  String obWhyWordsNote(String name) {
    return '$name will remember this.';
  }

  @override
  String get obWhyWordsErrorLong => 'Keep it to 200 characters or fewer.';

  @override
  String get obWhyWordsCta => 'That\'s why';

  @override
  String get obWhyWordsSkip => 'Skip this';

  @override
  String get obNotifTitle => 'Backup, exactly when you cave.';

  @override
  String get obNotifSubtitle =>
      'Not spam. One nudge before your danger hours, one when you hit a milestone.';

  @override
  String get obNotifPreviewTime => 'Fri 9:54 PM';

  @override
  String get obNotifPreviewBody =>
      'heads up — Friday nights are your spike. Plan\'s ready 💪';

  @override
  String get obNotifBullet1 => 'Danger-hour heads-up (you set the hours)';

  @override
  String get obNotifBullet2 => 'Streak + milestone celebrations';

  @override
  String get obNotifBullet3 => 'Buddy SOS pings — nothing else';

  @override
  String get obNotifCta => 'Turn on backup';

  @override
  String get paywallTitle => 'Your plan is ready.';

  @override
  String get paywallSubtitle => 'Try everything free for 3 days.';

  @override
  String get paywallFeatCoach => 'AI coach, unlimited';

  @override
  String get paywallFeatPanic => 'Panic Button + buddy ping';

  @override
  String get paywallFeatPlan => 'Adaptive quit plan';

  @override
  String get paywallFeatForecasts => 'Craving forecasts';

  @override
  String get paywallFeatCommunity => 'Community';

  @override
  String get paywallFeatReports => 'Weekly reports';

  @override
  String get paywallYearly => 'YEARLY';

  @override
  String get paywallYearlyBadge => 'BEST VALUE';

  @override
  String get paywallYearlySub => '\$0.77/week · SAVE 74%';

  @override
  String get paywallMonthly => 'MONTHLY';

  @override
  String get paywallWeekly => 'WEEKLY';

  @override
  String get paywallWeeklySub => 'Founding price — locked forever';

  @override
  String get paywallTrialReminder =>
      '🔔 We\'ll remind you before your trial ends';

  @override
  String get paywallCancelAnytime => 'Cancel anytime';

  @override
  String get paywallAnchor => 'Less than one disposable a week';

  @override
  String get paywallCta => 'Start my free 3 days';

  @override
  String get paywallFreeLink => 'Continue with Free plan →';

  @override
  String get freePlanTitle => 'Free gets you moving.';

  @override
  String get freePlanSubtitle => 'Yours forever. No countdown, no nagging.';

  @override
  String get freePlanFeat1 => 'Puff log + streaks';

  @override
  String get freePlanFeat2 => 'Money-saved ticker';

  @override
  String get freePlanFeat3 => '5 coach messages a day';

  @override
  String get freePlanFeat4 => '1 Panic Button session a day';

  @override
  String get freePlanFeat5 => 'Community (read + react)';

  @override
  String get freePlanUpgradeNote =>
      'Upgrade any time — your streak and history come with you.';

  @override
  String get freePlanCta => 'Start with Free';

  @override
  String get winbackBadge => 'ONE-TIME FOUNDING OFFER';

  @override
  String get winbackTitle => 'Okay — first month on us. Almost.';

  @override
  String get winbackSubtitle =>
      'You built the plan. Try the full toolkit for a month before deciding.';

  @override
  String get winbackFirstMonth => 'first month';

  @override
  String winbackNote(String price) {
    return 'Then $price/mo. Cancel anytime. Shown once, never again.';
  }

  @override
  String get winbackCta => 'Claim founding month';

  @override
  String get winbackDecline => 'No thanks, Free is fine';

  @override
  String get day1Title => 'Day 1. Let\'s go.';

  @override
  String get day1Subtitle =>
      'Three setup moves. Two minutes. Then the app does its job.';

  @override
  String get day1Task1 => 'Log your first puff';

  @override
  String get day1Task1Done => 'done — honesty from puff one';

  @override
  String get day1Task1Sub => 'one honest tap on the big button';

  @override
  String get day1Task2 => 'Meet your coach';

  @override
  String get day1Task2Sub => '30-sec hello. It already knows your triggers.';

  @override
  String get day1Task3 => 'Set your danger hours';

  @override
  String get day1Task3Sub => 'when do you cave? we\'ll show up early';

  @override
  String get day1Skip => 'Skip setup for now';

  @override
  String get day1TourLogTitle => 'This is the whole app.';

  @override
  String get day1TourLogBody =>
      'Every puff, tapped here. Honest counts are the only thing that makes the plan real — go on, log one now.';

  @override
  String get day1TourCoachTitle => 'Say anything.';

  @override
  String day1TourCoachBody(String name) {
    return '$name has already read your plan — your numbers, your triggers, the hours you struggle. Type a hello and see.';
  }

  @override
  String get day1TourHoursTitle => 'When do you cave?';

  @override
  String get day1TourHoursBody =>
      'Pick the window you struggle in. We show up ten minutes before it, on your phone, without you asking.';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Freedom Day: $date · $days days out · plan armed';
  }

  @override
  String get day1CtaCoach => 'Meet your coach';

  @override
  String get day1CtaHome => 'Go to Today';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Day $day of $total';
  }

  @override
  String get homeTitle => 'Today';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count days',
      one: '🔥 $count day',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'puffs today';

  @override
  String homeOfLimit(int limit) {
    return 'of $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return '$count left on today\'s line. You\'re ahead of your curve.';
  }

  @override
  String homeLeftTight(int count) {
    return '$count left on today\'s line. Tight — you\'ve got this.';
  }

  @override
  String homeVsDay1(String percent) {
    return '$percent vs day 1';
  }

  @override
  String get homeSavedSoFar => 'saved so far';

  @override
  String get homeCravingsBeaten => 'cravings beaten';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return 'Rough $weekday? I noticed.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'Your $hour spike is due — want a plan?';
  }

  @override
  String get homeLogPuff => 'LOG PUFF';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => 'No puffs today?';

  @override
  String get homeVapeFreeCta => 'Confirm vape-free day ✓';

  @override
  String get homeVapeFreeDone =>
      'Vape-free day locked in. That\'s the whole game. 🔥';

  @override
  String homeLoggedSnackCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Logged $count puffs',
      one: 'Logged 1 puff',
    );
    return '$_temp0';
  }

  @override
  String get homeOverLimitTitle => 'Over today\'s line';

  @override
  String get homeOverLimitBody =>
      'Breathe — tomorrow\'s line adjusts. No shame.';

  @override
  String get homeOverLimitBreathe => 'Breathe 60s';

  @override
  String get homeOverLimitCoach => 'Talk to coach';

  @override
  String get homeOverLimitFooter =>
      'Keep logging honestly — the data is the whole game.';

  @override
  String get homeTokenUsedNote =>
      'Repair token used — your streak survives. Flame dims today, not out.';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Stats';

  @override
  String get navCommunity => 'Community';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'PANIC MODE · $step OF 3';
  }

  @override
  String get panicBreatheNote =>
      'this feeling peaks and passes — most cravings die in 15 min';

  @override
  String get panicBreatheIn => 'In…';

  @override
  String get panicBreatheHold => 'Hold…';

  @override
  String get panicBreatheOut => 'Out…';

  @override
  String get panicBreathePattern => 'In 4 · Hold 7 · Out 8';

  @override
  String panicCravingTimer(String time) {
    return 'craving timer · $time · peaks ~15 min';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'craving timer · $time · you\'re past the worst spike';
  }

  @override
  String get panicSkipToWhy => 'Skip to my why →';

  @override
  String get panicWhyTitle => 'Remember why you started.';

  @override
  String get panicYouSaid => 'YOU SAID';

  @override
  String panicWhyLine(String why, String amount) {
    return 'You\'re doing this for your $why and the $amount/year you\'re taking back.';
  }

  @override
  String get panicIntensityQuestion => 'How bad is it right now?';

  @override
  String get panicIntensityLow => 'meh';

  @override
  String get panicIntensityHigh => 'screaming';

  @override
  String get panicStillCraving => 'Still craving — next';

  @override
  String get panicItPassed => 'It passed 🎉 I\'m good';

  @override
  String get panicLoopTitle => 'Break the loop.';

  @override
  String get panicLoopSubtitle =>
      'Your hands and brain need a job for 60 seconds. Pick one.';

  @override
  String get panicLoopGame => '60-second game';

  @override
  String get panicLoopGameSub =>
      'occupies the exact itch — thumbs busy, brain busy';

  @override
  String get panicLoopSos => 'Ask the community';

  @override
  String get panicLoopSosSub => 'post an SOS — it pins to the top for an hour';

  @override
  String get panicLoopCoach => 'Talk to coach';

  @override
  String panicLoopCoachSub(String hour) {
    return 'it knows this is your $hour stress pattern';
  }

  @override
  String get panicLoopCoachLocked => 'you\'ve used today\'s free AI session';

  @override
  String get gameTitle => 'Tap every spark';

  @override
  String get gameSubtitle => '60 seconds. Thumbs busy, brain busy.';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get survivedPlusOne => '+1 craving beaten';

  @override
  String get survivedLine1 => 'That one had nothing on you.';

  @override
  String get survivedLine2 => 'The wave broke. You didn\'t.';

  @override
  String get survivedLine3 => '15 minutes of brave. Banked forever.';

  @override
  String get survivedLine4 => 'Your brain just learned who\'s boss.';

  @override
  String get survivedLine5 => 'Craving 0 — you 1. Again.';

  @override
  String get survivedLine6 => 'Still free. Still going.';

  @override
  String get survivedLine7 => 'That itch just paid your future self.';

  @override
  String get survivedLine8 => 'Cold-blooded. In the best way.';

  @override
  String get survivedTotalLabel => 'cravings survived total';

  @override
  String get survivedShare => 'Share the W ↗';

  @override
  String get survivedBack => 'Back to today';

  @override
  String get survivedShareCopied => 'Stat card copied — paste it anywhere.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● knows your plan · day $day';
  }

  @override
  String get coachChipCraving => 'I\'m craving';

  @override
  String get coachChipRoughDay => 'Rough day';

  @override
  String get coachChipSlipped => 'I slipped';

  @override
  String get coachChipProgress => 'Show my progress';

  @override
  String get coachInputHint => 'Message your coach…';

  @override
  String coachTyping(String name) {
    return '$name is typing…';
  }

  @override
  String coachTimeYesterday(String time) {
    return 'Yesterday · $time';
  }

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count free messages left today',
      one: '$count free message left today',
    );
    return '$_temp0';
  }

  @override
  String get coachCapReached =>
      'That\'s my 5 free messages for today — I\'ll be back at midnight. Want me around 24/7? That\'s what Premium is.';

  @override
  String get coachConnectionLost =>
      'Signal dropped mid-thought 😅 I\'m still right here — say that again once you\'re back online?';

  @override
  String get coachBackendRejected =>
      'Okay, that\'s on our end — the server didn\'t recognise this app, so I never got your message. Not your connection, not you. We\'re on it.';

  @override
  String get errorOfflineBanner =>
      'offline — logs still count, we\'ll sync later';

  @override
  String get errorOfflineTitle => 'No wifi, no worries';

  @override
  String get errorOfflineBody =>
      'You\'re offline right now. Nothing\'s lost — reconnect and we\'ll pick up right where you left off.';

  @override
  String get errorGenericTitle => 'Well, that glitched';

  @override
  String get errorGenericBody =>
      'That one\'s on us, not you. Give it another shot in a sec.';

  @override
  String get errorRejectedTitle => 'This build got bounced';

  @override
  String get errorRejectedBody =>
      'Your connection is fine — our end just didn\'t recognise this app. Nothing you can fix, and nothing you logged is lost.';

  @override
  String get errorRetry => 'Run it back';

  @override
  String get errorGotIt => 'Got it';

  @override
  String get errorFeedTitle => 'The feed ghosted us';

  @override
  String get errorFeedBody =>
      'Couldn\'t reach the community. Check your signal and run it back.';

  @override
  String get errorRouteTitle => 'This page doesn\'t exist';

  @override
  String get errorRouteBody =>
      'Whatever you were looking for, it\'s not here. Let\'s get you back on track.';

  @override
  String get errorRouteCta => 'Take me home';

  @override
  String get errorBackstage =>
      'something glitched backstage — you\'re all good to keep going';

  @override
  String get coachWeekCardLabel => 'YOUR WEEK';

  @override
  String coachWeekCardCaption(String day) {
    return 'trending down — $day was the hard one';
  }

  @override
  String coachGreeting(String name, int puffs, String method, String date) {
    return 'Hey. I\'m $name — I quit two years ago and I remember exactly how it felt. I\'ve read your plan: $puffs a day, $method, Freedom Day $date. No lectures from me, ever. What\'s going on right now?';
  }

  @override
  String get coachReplyCraving1 =>
      'That wave is brutal, I know. 15 minutes and it breaks — that\'s not a pep talk, it\'s biology. Cold water on your wrists, and stay with me. What set it off?';

  @override
  String coachReplyCraving2(int count) {
    return 'Okay. Breathe with me for one round — in 4, hold 7, out 8. Cravings usually die in 15–20 minutes. You\'ve already beaten $count of them. This one\'s no different.';
  }

  @override
  String get coachReplyCraving3 =>
      'Heard. Don\'t argue with the craving, just outlast it. Walk one block or hit the 60-second game. It peaks and dies — 15 minutes, tops.';

  @override
  String coachReplyRough1(int percent) {
    return 'Fair. Rough days are when the old habit shouts loudest. Deal: 10-min walk before the next one. If you still want it after, log it honestly — you\'re still $percent% under your old baseline.';
  }

  @override
  String get coachReplyRough2 =>
      'That sounds heavy. You don\'t have to fix today, just get through it — and you\'re allowed to do that without nicotine. I\'m here either way.';

  @override
  String coachReplySlip1(int count) {
    return 'A slip is data, not defeat. What set it off — stress, people, boredom? The plan already bent to catch you. Your $count days still count.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Zero shame here. Most people who quit for good slipped on the way. Log it honestly, find the trigger, move on. Your record is still yours: $amount saved, longest streak intact.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Look at the actual numbers: day $day, $saved back in your pocket, $cravings cravings beaten. Day 1 you couldn\'t have done today. That\'s real.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today puffs today against a line of $limit. Two weeks ago that number would\'ve been double. You\'re actually doing this.';
  }

  @override
  String get coachReplyGeneric1 =>
      'I hear you. Say more — what\'s underneath that?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Makes sense. For what it\'s worth, you\'re on day $day and still here. That counts for a lot.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Got it. One honest question: is this a nicotine thing right now, or a life thing wearing nicotine\'s jacket?';

  @override
  String get coachReplyGeneric4 =>
      'Okay. Small moves win this. What\'s one thing you can do in the next 10 minutes that isn\'t vaping?';

  @override
  String coachReplyParty(int count) {
    return 'Party playbook: hold a cold drink all night, text me or your buddy when the first vape comes out, and pre-load your exit line. You\'ve survived $count cravings — a party is just several in a row.';
  }

  @override
  String coachSafetyNote(String name) {
    return '$name is a support tool, not a doctor. In crisis? Call or text 988 (US & Canada), any time.';
  }

  @override
  String get planTitle => 'Your plan';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days days';
  }

  @override
  String get planMethodTaper => 'Taper';

  @override
  String get planMethodCold => 'Cold turkey';

  @override
  String planTodayMarker(int limit) {
    return 'today · $limit/day';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'COMING UP';

  @override
  String planHalfwayTitle(int day) {
    return 'Day $day — halfway';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'line drops to $limit/day';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Day $day — cravings fade';
  }

  @override
  String get planCravingsFadeSub => 'most report easier mornings';

  @override
  String planFreedomTitle(int day) {
    return 'Day $day — Freedom Day';
  }

  @override
  String get planAdjustCta => 'Adjust my plan';

  @override
  String get planAdjustNote =>
      'pace + method editable · no reset, no lost history';

  @override
  String get planAdaptiveLabel => 'TONIGHT\'S ADJUSTMENT';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'You came in under your line three days running, so today\'s target drops to $limit. Momentum, not punishment.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'You\'re holding the line. Today\'s target stays at $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'The last two days ran over, so today\'s target bends to $limit. A line you can actually hold beats a line you can\'t.';
  }

  @override
  String get planAdaptiveStretched => 'Freedom Day moved back a day to match.';

  @override
  String get planAdjustSheetTitle => 'Adjust your plan';

  @override
  String get planAdjustSheetNote =>
      'Curve regenerates from today with your real numbers. History stays. Freedom Day moves honestly.';

  @override
  String get planAdjustApply => 'Apply — reflow my curve';

  @override
  String planAdjusted(String date) {
    return 'Plan reflowed. New Freedom Day: $date';
  }

  @override
  String get statsTitle => 'Stats';

  @override
  String get statsRangeDay => 'Day';

  @override
  String get statsRangeWeek => 'Week';

  @override
  String get statsRangeMonth => 'Month';

  @override
  String get statsPuffsThisWeek => 'PUFFS THIS WEEK';

  @override
  String get statsPuffsToday => 'PUFFS TODAY · BY HOUR';

  @override
  String get statsPuffsThisMonth => 'PUFFS · LAST 30 DAYS';

  @override
  String statsVsLast(String percent) {
    return '$percent vs last';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return '$day was the difficult day — $reason. You recovered next morning.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return '$day was the difficult day. You recovered next morning.';
  }

  @override
  String get statsTriggerHours => 'TRIGGER HOURS';

  @override
  String statsDangerWindow(String range) {
    return '$range is your danger window · nudges armed there';
  }

  @override
  String get statsNicotinePerDay => 'NICOTINE / DAY';

  @override
  String statsNicotineValue(int mg) {
    return '${mg}mg ↓';
  }

  @override
  String get statsLongestGap => 'longest gap';

  @override
  String get statsBestDay => 'best day (puffs)';

  @override
  String get statsCravingsBeaten => 'cravings beaten';

  @override
  String get statsEmptyTitle => 'Charts show up tomorrow.';

  @override
  String get statsEmptyBody =>
      'One day of logs = one dot. Keep logging — the picture draws itself.';

  @override
  String statsEditDayTitle(String date) {
    return 'Edit $date';
  }

  @override
  String get statsEditDayNote =>
      'History is yours. Streak and money recompute from here forward.';

  @override
  String get statsEditHint => 'long-press any bar to fix a day';

  @override
  String get communityTitle => 'Community';

  @override
  String communityYouAre(String alias) {
    return 'you\'re $alias';
  }

  @override
  String get communityFilterAll => 'All';

  @override
  String get communityTagWin => '🏆 Win';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Day 1';

  @override
  String get communityTagMilestone => 'Milestone';

  @override
  String get communityTagVent => 'Vent';

  @override
  String get communityIGotYou => 'I got you 💬';

  @override
  String communityRepliedCount(int count) {
    return '$count already replied';
  }

  @override
  String get communityReport => 'Report';

  @override
  String get communityMute => 'Mute';

  @override
  String get communityBlock => 'Block user';

  @override
  String get communityReported =>
      'Reported. We review within 24h — 3 reports auto-hide a post.';

  @override
  String get communityBlocked => 'Blocked. You won\'t see each other anymore.';

  @override
  String get communityMuted => 'Muted. You won\'t see their posts anymore.';

  @override
  String get communityAutoFlagged =>
      'Held for review — brand names and sourcing aren\'t allowed here.';

  @override
  String get communityComposerTitle => 'New post';

  @override
  String get communityComposerPost => 'Post';

  @override
  String communityPostingAs(String alias, int day) {
    return 'posting as $alias · day $day · always anonymous';
  }

  @override
  String get communityComposerHint => 'What\'s happening in your quit?';

  @override
  String get communityTagIt => 'TAG IT';

  @override
  String get communityKindnessNote =>
      'Be kind — everyone here is mid-fight. No brand names, no where-to-buy.';

  @override
  String get communityTagRequired =>
      'Pick a tag — it routes your post to the right people.';

  @override
  String communitySosBanner(int count) {
    return '🛡️ $count people had your back';
  }

  @override
  String get communityAddVoice => 'Add your voice…';

  @override
  String communityDayTag(int day) {
    return 'day $day';
  }

  @override
  String get communityEmptyTitle => 'No posts yet — say hi.';

  @override
  String get communityEmptyBody =>
      'Your Day 1 post is the one someone on Day 0 needs to read.';

  @override
  String get communityPosted =>
      'Posted. A quick safety check runs before others can see it.';

  @override
  String get buddyLinkCopied =>
      'Link copied — quitting hits different with backup.';

  @override
  String get moneyTitle => 'Money back';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'saved since $date · $perDay rolling in daily';
  }

  @override
  String get moneyBuysLabel => 'WHAT IT ALREADY BUYS';

  @override
  String moneyToGo(String amount, int days) {
    return '$amount to go · ~$days days at your pace';
  }

  @override
  String moneyToGoShort(String amount) {
    return '$amount to go';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'the one from onboarding · $amount to go';
  }

  @override
  String get moneySetGoal => 'Set a goal';

  @override
  String get moneySetGoalSub => 'name it, price it, watch the bar fill';

  @override
  String get moneyGoalSheetTitle => 'New savings goal';

  @override
  String get moneyGoalNameHint => 'Name it — \"PS5\", \"Lisbon\", \"drum kit\"';

  @override
  String get moneyGoalPriceHint => 'Price';

  @override
  String get moneyGoalCreate => 'Start the bar';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'Math is yours: $weekly/week × 52 = $yearly/year. No invented numbers.';
  }

  @override
  String get moneyGoalDone => 'Goal funded. Confetti earned. 🎉';

  @override
  String get seedGoalKicks => 'New kicks';

  @override
  String get seedGoalTokyo => 'Tokyo flight';

  @override
  String get healthTitle => 'Your body, healing';

  @override
  String healthAnchor(String ago) {
    return 'Based on your last logged puff · $ago ago';
  }

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — you are here';
  }

  @override
  String get healthM20min => '20 minutes';

  @override
  String get healthM20minBody =>
      'Heart rate and blood pressure drop back to normal.';

  @override
  String get healthM8h => '8 hours';

  @override
  String get healthM8hBody => 'Oxygen levels normalize as nicotine fades.';

  @override
  String get healthM12h => '12 hours';

  @override
  String get healthM12hBody => 'Carbon monoxide in your blood drops to normal.';

  @override
  String get healthM24h => '24 hours';

  @override
  String get healthM24hBody =>
      'Nicotine is dropping fast. Cravings get loud — that\'s the exit door.';

  @override
  String get healthM48h => '48 hours';

  @override
  String get healthM48hBody =>
      'Nerve endings start regrowing. Taste and smell sharpen.';

  @override
  String get healthM72h => '72 hours';

  @override
  String get healthM72hBody =>
      'Nicotine is ~gone. Cravings peak — Panic Button lives for this.';

  @override
  String get healthM1w => '1 week';

  @override
  String get healthM1wBody =>
      'Taste and smell noticeably sharper. Breathing feels easier.';

  @override
  String get healthM2w => '2 weeks';

  @override
  String get healthM2wBody =>
      'Circulation improves. Lung function begins to climb.';

  @override
  String get healthM1m => '1 month';

  @override
  String get healthM1mBody => 'Coughing and shortness of breath ease off.';

  @override
  String get healthM3m => '3 months';

  @override
  String get healthM3mBody =>
      'Lung capacity keeps climbing. The gym feels different.';

  @override
  String get healthM6m => '6 months';

  @override
  String get healthM6mBody =>
      'Stress baseline drops — you handle bad days without it.';

  @override
  String get healthM1y => '1 year';

  @override
  String get healthM1yBody =>
      'Your risk profile looks like someone who never vaped daily.';

  @override
  String get healthUnlockNote =>
      'Each unlock fires a small celebration + optional share card.';

  @override
  String get healthSourceNote =>
      'Based on smoking-cessation research — vaping evidence is still emerging.';

  @override
  String get milestonesTitle => 'Milestones';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned of $total earned';
  }

  @override
  String milestonesNext(String name) {
    return 'Next: $name';
  }

  @override
  String milestonesNextProgress(int day, int target) {
    return 'day $day of $target · two more sunrises';
  }

  @override
  String get milestonesNotLeaderboard =>
      'Badges are yours, not a leaderboard. Nobody else\'s grid to compare.';

  @override
  String get mFirstLog => 'First log';

  @override
  String get mFirstCraving => 'First craving beaten';

  @override
  String get mSpark => '3-day spark';

  @override
  String get mWeekFlame => '7-day flame';

  @override
  String get mHundredSaved => '\$100 saved';

  @override
  String get mCleanWeekend => 'Clean weekend';

  @override
  String get mHelpedSos => 'Helped an SOS';

  @override
  String get mTwoWeekFlame => 'Two-week flame';

  @override
  String get mHalfNicotine => 'Half nicotine';

  @override
  String get mMoodWeek => 'Mood-week streak';

  @override
  String get mTenCravings => '10 cravings beaten';

  @override
  String get mQuarterCurve => 'Quarter of the curve';

  @override
  String get mInferno => '30-day inferno';

  @override
  String get mFreedomDay => 'Freedom Day';

  @override
  String get mFirstPost => 'First post';

  @override
  String get mFiveHundredSaved => '\$500 saved';

  @override
  String get mComeback => 'Comeback';

  @override
  String get moodTitle => 'How\'s today feeling?';

  @override
  String get moodSubtitle => '10 seconds. It matters more than you\'d think.';

  @override
  String get moodRough => 'rough';

  @override
  String get moodMeh => 'meh';

  @override
  String get moodOkay => 'okay';

  @override
  String get moodGood => 'good';

  @override
  String get moodGreat => 'great';

  @override
  String get moodNoteHint =>
      'One line, optional — \"work party tonight, nervous\"';

  @override
  String get moodUnlockTitle => '🔓 Mood ↔ craving link';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total check-ins';
  }

  @override
  String moodUnlockNote(int count) {
    return '$count more and your report shows how mood drives your cravings.';
  }

  @override
  String get moodCta => 'Check in';

  @override
  String get moodSaved => 'Noted. Data beats vibes. 🙌';

  @override
  String get insightLinkTitle => 'Weekly report';

  @override
  String insightTitle(int week, String range) {
    return 'Week $week report · $range';
  }

  @override
  String get insightWinLabel => 'Your win';

  @override
  String get insightWatchoutLabel => 'Watch out';

  @override
  String get insightWeekChartLabel => 'PUFFS, LAST 7 DAYS';

  @override
  String get insightCravingsChartLabel => 'CRAVINGS SURVIVED, LAST 7 DAYS';

  @override
  String get insightHoursChartLabel => 'PUFFS BY HOUR, LAST 14 DAYS';

  @override
  String get insightPendingTitle => 'No report yet';

  @override
  String insightPendingBody(String name) {
    return '$name writes one every Sunday from the week you actually logged — your hours, your moods, your wins. Nothing to show until there\'s a week to read.';
  }

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index OF $total';
  }

  @override
  String get slipTitle => 'A slip is data, not defeat.';

  @override
  String slipSubtitle(int days) {
    return 'You logged puffs after $days clean days. That\'s information — it tells us exactly where the plan needs armor.';
  }

  @override
  String get slipWhatHappened => 'WHAT WAS GOING ON?';

  @override
  String get slipTriggerParty => 'Party';

  @override
  String get slipTriggerStress => 'Stress';

  @override
  String get slipTriggerBoredom => 'Boredom';

  @override
  String get slipTriggerDrinking => 'Drinking';

  @override
  String get slipTriggerFriends => 'Friends had one';

  @override
  String get slipTriggerJustHappened => 'Just happened';

  @override
  String get slipNoBannedWords =>
      'No banned words here, ever. Most people who quit for good slipped on the way. The log stays honest, the plan adapts.';

  @override
  String get slipAdjustCta => 'Adjust my plan';

  @override
  String get slipAdjustTitle => 'Here\'s the adjustment.';

  @override
  String get slipCurveLabel => 'YOUR CURVE — GENTLY REFLOWN';

  @override
  String get slipTheBump => 'the slip bump';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Freedom Day: $date (+$days days)';
  }

  @override
  String get slipCurveNote =>
      'Two extra days, same destination. Party nights get a pre-armed nudge + game shortcut.';

  @override
  String slipStreakSurvives(int days) {
    return 'Your $days days still count.';
  }

  @override
  String get slipFlameDims =>
      'The flame dims, it doesn\'t die. One clean day brings it back to full blaze.';

  @override
  String get slipBackOnCurve => 'Back on the curve';

  @override
  String get slipTalkFirst => 'Talk it through with coach first';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'quitting since $date · $method · day $day';
  }

  @override
  String get profileCountdownLabel => '🏆 FREEDOM DAY COUNTDOWN';

  @override
  String profileDaysTo(String date) {
    return 'days to $date';
  }

  @override
  String get profileLifetimeSaved => 'lifetime saved';

  @override
  String get profilePuffsNotTaken => 'puffs not taken';

  @override
  String get profileBadgesEarned => 'badges earned';

  @override
  String get profileSettings => '⚙️ Settings';

  @override
  String get profileEditAlias => 'Pick your alias';

  @override
  String get profileEditAvatar => 'Pick your avatar';

  @override
  String get profileAliasHint => 'anonymous — this is all anyone sees';

  @override
  String memoriesTitle(String name) {
    return 'What $name remembers';
  }

  @override
  String memoriesIntro(String name) {
    return 'What $name knows about you: your setup and live numbers from the app, plus the things you\'ve told it in chat — those you can make it forget, any time.';
  }

  @override
  String memoriesEmpty(String name) {
    return 'Nothing here yet. This part fills up as you tell $name things about your life in chat.';
  }

  @override
  String memoriesSectionKnows(String name) {
    return 'What $name always knows';
  }

  @override
  String memoriesSectionTold(String name) {
    return 'Things you\'ve told $name';
  }

  @override
  String get memoriesFactPlan => 'Plan';

  @override
  String memoriesFactPlanValue(String method, int days) {
    return '$method · $days days';
  }

  @override
  String get memoriesFactStarted => 'Started';

  @override
  String get memoriesFactBaseline => 'Baseline';

  @override
  String memoriesFactBaselineValue(int count) {
    return '$count puffs a day';
  }

  @override
  String get memoriesFactWhy => 'Your why';

  @override
  String get memoriesFactWorries => 'Worried about';

  @override
  String get memoriesFactWhyWords => 'In your words';

  @override
  String get memoriesFactFirstPuff => 'First puff after waking';

  @override
  String get memoriesFactFrequency => 'How often';

  @override
  String get memoriesFactDay => 'Where you are';

  @override
  String memoriesFactDayValue(int day, int total) {
    return 'Day $day of $total';
  }

  @override
  String get memoriesFactToday => 'Today';

  @override
  String memoriesFactTodayValue(int puffs, int limit) {
    return '$puffs of $limit puffs';
  }

  @override
  String get memoriesFactStreak => 'Streak';

  @override
  String get memoriesFactSaved => 'Money saved';

  @override
  String get memoriesFailed => 'Couldn\'t load these right now.';

  @override
  String get memoriesForget => 'Forget this';

  @override
  String memoriesForgotten(String name) {
    return 'Forgotten. $name won\'t bring it up again.';
  }

  @override
  String get memoriesForgetFailed =>
      'That didn\'t go through — it\'s still remembered.';

  @override
  String get memoriesKindPerson => 'Someone in your life';

  @override
  String get memoriesKindTrigger => 'A trigger';

  @override
  String get memoriesKindMotivation => 'Why you\'re doing this';

  @override
  String get memoriesKindMilestone => 'Something you\'re working toward';

  @override
  String get memoriesKindPreference => 'How you like to be talked to';

  @override
  String get memoriesKindContext => 'About you';

  @override
  String settingsMemories(String name) {
    return 'What $name remembers';
  }

  @override
  String get moderationTitle => 'Review queue';

  @override
  String get moderationEmpty => 'Nothing waiting. Every flag is reviewed.';

  @override
  String get moderationFailed => 'Couldn\'t open the queue.';

  @override
  String get moderationRetry => 'Try again';

  @override
  String get moderationShowReviewed => 'Show reviewed';

  @override
  String moderationPendingCount(int count) {
    return '$count waiting';
  }

  @override
  String get moderationSubjectGone =>
      'The post is gone; only the flag is left.';

  @override
  String get moderationAllow => 'Allow';

  @override
  String get moderationBlock => 'Block';

  @override
  String get moderationDismiss => 'Looks fine';

  @override
  String get moderationResolveFailed =>
      'That didn\'t go through. The post is unchanged.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSubscription => 'Manage subscription';

  @override
  String get settingsSubscriptionValue => 'Premium · yearly';

  @override
  String get settingsSubscriptionFree => 'Free plan';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDangerHours => 'Danger hours';

  @override
  String settingsDangerHoursEdit(String range) {
    return '$range · edit ›';
  }

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyNote =>
      'We never sell your data. No ad trackers. Ever.';

  @override
  String get settingsDeleteEverything => 'Delete everything';

  @override
  String get settingsDeleteConfirmTitle => 'Delete everything?';

  @override
  String get settingsDeleteConfirmBody =>
      'Your plan, logs, streak, and community posts — gone for good. This is the one button we can\'t undo.';

  @override
  String get settingsDeleteConfirmCta => 'Yes, delete it all';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSystem => 'Match system';

  @override
  String get settingsAppearanceMidnight => 'Midnight';

  @override
  String get settingsAppearanceDaylight => 'Daylight';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'Match system';

  @override
  String get settingsSignOut => 'Sign out';

  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';

  @override
  String get settingsSignOutConfirmBody =>
      'Your data stays on your account. The streak keeps burning.';

  @override
  String get settingsDangerHoursTitle => 'Danger hours';

  @override
  String get settingsDangerHoursNote =>
      'We nudge you 10 minutes before your window opens. Max 3 pushes a day, quiet hours respected.';

  @override
  String settingsQuietHours(String range) {
    return 'Quiet hours: $range';
  }

  @override
  String get trialEndingPushTime => 'now';

  @override
  String get trialEndingPush =>
      'your trial ends tomorrow — as promised, here\'s the heads-up. No surprise charges.';

  @override
  String get trialEndingTitle => 'Trial ends tomorrow.';

  @override
  String get trialEndingBody =>
      'We said we\'d remind you, so: here it is. Keep Premium, or drop to Free — your streak, plan, and history stay either way.';

  @override
  String get trialEndingStatsLabel => 'YOUR 3 DAYS SO FAR';

  @override
  String get trialEndingVsDay1 => 'puffs vs day 1';

  @override
  String get trialEndingCravings => 'cravings beaten';

  @override
  String get trialEndingSaved => 'saved';

  @override
  String trialEndingKeep(String price) {
    return 'Keep Premium — $price/yr';
  }

  @override
  String get trialEndingSwitchFree => 'Switch to Free (keeps your data)';

  @override
  String get frameMapTitle => 'All 52 design frames';

  @override
  String get frameMapOpen => 'Browse all 52 screens →';

  @override
  String get frameMapNote =>
      'Every frame from the four handoffs, one tap away. Rows load the demo journey or quiz answers as needed.';

  @override
  String get frameMapEdgeNote =>
      'These states go live with the backend — an in-memory app has no offline or server errors to show honestly.';

  @override
  String get seedPostWin30 =>
      'FREEDOM DAY. 30 days, zero puffs the last week. The panic button carried me through weekends. If you\'re on day 2 and dying — it genuinely gets easier around day 8.';

  @override
  String get seedPostSos =>
      'outside the gas station. wallet in hand. someone talk me out of this';

  @override
  String get seedPostDay1 =>
      'threw mine in the lake. probably bad for the lake. day 1 starts now';

  @override
  String get seedPostVent =>
      'coworker blows mango clouds at his desk ALL DAY and I\'m supposed to just… focus? venting so I don\'t cave';

  @override
  String get seedPostMilestone =>
      'two weeks. took the stairs to floor 4 today and didn\'t sound like a haunted accordion. small wins';

  @override
  String get seedPostWinParty =>
      'made it through a whole party without borrowing anyone\'s vape. hands survived by holding a lime seltzer like a weirdo';

  @override
  String get seedReplyWalk =>
      'walk. just walk one block. the wallet stays heavy, you stay free. i did this exact thing tuesday';

  @override
  String get seedReplyScience =>
      'day 4 is the worst one, it\'s science. you\'re at the peak RIGHT NOW. 15 minutes and this dies';

  @override
  String get seedReplyGatorade =>
      'buy a gatorade instead. ceremonial purchase. works weirdly well';

  @override
  String get seedReplyUpdate =>
      'update: bought the gatorade. walking home. thank you, i mean it 💙';

  @override
  String get dangerReminderTitle => 'Your danger hour is coming up';

  @override
  String get dangerReminderBody =>
      'This is usually when it hits. You\'ve got a plan — and 15 minutes beats it.';

  @override
  String get communityLoading => 'Pulling in the feed…';

  @override
  String memoriesLoading(String name) {
    return 'Checking what $name kept…';
  }

  @override
  String get coachLoadingThread => 'Catching up on your chat…';

  @override
  String get moderationLoading => 'Loading the queue…';

  @override
  String get authWorking => 'One sec…';
}
