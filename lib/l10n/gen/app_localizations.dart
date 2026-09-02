import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pt'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Cirrus'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Your last puff is closer\nthan you think.'**
  String get appTagline;

  /// No description provided for @appVersionFooter.
  ///
  /// In en, this message translates to:
  /// **'Cirrus {version} · made by people who quit'**
  String appVersionFooter(String version);

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get commonNotNow;

  /// No description provided for @commonMaybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get commonMaybeLater;

  /// No description provided for @commonDayN.
  ///
  /// In en, this message translates to:
  /// **'day {day}'**
  String commonDayN(int day);

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s keep your\nplan safe.'**
  String get authSignInTitle;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Anonymous by default — you\'ll pick an alias for community.'**
  String get authSignInSubtitle;

  /// No description provided for @authSignInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Apple'**
  String get authSignInWithApple;

  /// No description provided for @authSignInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authSignInWithGoogle;

  /// No description provided for @authContinueWithEmail.
  ///
  /// In en, this message translates to:
  /// **'Continue with email'**
  String get authContinueWithEmail;

  /// No description provided for @authWhyAccountDivider.
  ///
  /// In en, this message translates to:
  /// **'why an account?'**
  String get authWhyAccountDivider;

  /// No description provided for @authWhyAccountCard.
  ///
  /// In en, this message translates to:
  /// **'Your streak, plan, and coach memory sync across devices. 🔒 We never sell your data. No ad trackers. Ever.'**
  String get authWhyAccountCard;

  /// No description provided for @authTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get authTerms;

  /// No description provided for @authPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get authPrivacy;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'EMAIL'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'PASSWORD'**
  String get authPasswordLabel;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'show'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'hide'**
  String get authHidePassword;

  /// No description provided for @authPasswordStrengthWeak.
  ///
  /// In en, this message translates to:
  /// **'keep typing…'**
  String get authPasswordStrengthWeak;

  /// No description provided for @authPasswordStrengthDecent.
  ///
  /// In en, this message translates to:
  /// **'decent password'**
  String get authPasswordStrengthDecent;

  /// No description provided for @authPasswordStrengthStrong.
  ///
  /// In en, this message translates to:
  /// **'strong password'**
  String get authPasswordStrengthStrong;

  /// No description provided for @authNoSpamCard.
  ///
  /// In en, this message translates to:
  /// **'No spam, no \"we miss you\" emails. Account = backup, that\'s it.'**
  String get authNoSpamCard;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authAlreadyHaveOne.
  ///
  /// In en, this message translates to:
  /// **'Already have one?'**
  String get authAlreadyHaveOne;

  /// No description provided for @authLogIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get authLogIn;

  /// No description provided for @authLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome back.'**
  String get authLoginTitle;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your streak missed you.'**
  String get authLoginSubtitle;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNewHere.
  ///
  /// In en, this message translates to:
  /// **'New here?'**
  String get authNewHere;

  /// No description provided for @authWrongPassword.
  ///
  /// In en, this message translates to:
  /// **'not that one — try again'**
  String get authWrongPassword;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Happens to everyone.'**
  String get authForgotTitle;

  /// No description provided for @authForgotSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Drop your email — we\'ll send a reset link. Your streak is untouched.'**
  String get authForgotSubtitle;

  /// No description provided for @authLinkSent.
  ///
  /// In en, this message translates to:
  /// **'Link sent. Check spam if it hides.'**
  String get authLinkSent;

  /// No description provided for @authResendLink.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get authResendLink;

  /// No description provided for @authResendCountdown.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String authResendCountdown(int seconds);

  /// No description provided for @authBackToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to log in'**
  String get authBackToLogin;

  /// No description provided for @authInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'that doesn\'t look like an email'**
  String get authInvalidEmail;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'that email already has a journey — log in instead'**
  String get authEmailInUse;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'passwords need at least 6 characters — a few more and you\'re in'**
  String get authPasswordTooShort;

  /// No description provided for @obProgressOf.
  ///
  /// In en, this message translates to:
  /// **'{step}/{total}'**
  String obProgressOf(int step, int total);

  /// No description provided for @obWelcomeCounterHint.
  ///
  /// In en, this message translates to:
  /// **'puffs a day — you\'re about to find out'**
  String get obWelcomeCounterHint;

  /// No description provided for @obWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'How dependent are you, really?'**
  String get obWelcomeTitle;

  /// No description provided for @obWelcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'2-minute check-up. Brutally honest results. A plan built for you.'**
  String get obWelcomeSubtitle;

  /// No description provided for @obWelcomeCta.
  ///
  /// In en, this message translates to:
  /// **'Start my check-up'**
  String get obWelcomeCta;

  /// No description provided for @obResumeTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick up where you left off?'**
  String get obResumeTitle;

  /// No description provided for @obResumeBody.
  ///
  /// In en, this message translates to:
  /// **'You\'d answered {answered} of {total} questions. Nothing\'s lost.'**
  String obResumeBody(int answered, int total);

  /// No description provided for @obResumeCta.
  ///
  /// In en, this message translates to:
  /// **'Carry on'**
  String get obResumeCta;

  /// No description provided for @obResumeFresh.
  ///
  /// In en, this message translates to:
  /// **'Start fresh'**
  String get obResumeFresh;

  /// No description provided for @obGenderTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you identify?'**
  String get obGenderTitle;

  /// No description provided for @obGenderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Calibrates your plan — nicotine metabolism differs.'**
  String get obGenderSubtitle;

  /// No description provided for @obGenderWoman.
  ///
  /// In en, this message translates to:
  /// **'Woman'**
  String get obGenderWoman;

  /// No description provided for @obGenderMan.
  ///
  /// In en, this message translates to:
  /// **'Man'**
  String get obGenderMan;

  /// No description provided for @obGenderNonBinary.
  ///
  /// In en, this message translates to:
  /// **'Non-binary / prefer not to say'**
  String get obGenderNonBinary;

  /// No description provided for @obGenderPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'🔒 Private. Never shown to the community.'**
  String get obGenderPrivacyNote;

  /// No description provided for @obBirthYearTitle.
  ///
  /// In en, this message translates to:
  /// **'What year were you born?'**
  String get obBirthYearTitle;

  /// No description provided for @obBirthYearSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan adapts to your age.'**
  String get obBirthYearSubtitle;

  /// No description provided for @obBirthYearHint.
  ///
  /// In en, this message translates to:
  /// **'Year or age — either one works.'**
  String get obBirthYearHint;

  /// No description provided for @obBirthYearAge.
  ///
  /// In en, this message translates to:
  /// **'You\'re {age}.'**
  String obBirthYearAge(int age);

  /// No description provided for @obBirthYearAgeOffer.
  ///
  /// In en, this message translates to:
  /// **'{age}? That\'d be born {year}.'**
  String obBirthYearAgeOffer(int age, int year);

  /// No description provided for @obBirthYearAgeConfirm.
  ///
  /// In en, this message translates to:
  /// **'That\'s me'**
  String get obBirthYearAgeConfirm;

  /// No description provided for @obBirthYearUnderConfirm.
  ///
  /// In en, this message translates to:
  /// **'Born {year}? That makes you {age}.'**
  String obBirthYearUnderConfirm(int year, int age);

  /// No description provided for @obBirthYearUnderCta.
  ///
  /// In en, this message translates to:
  /// **'Yes, I\'m {age}'**
  String obBirthYearUnderCta(int age);

  /// No description provided for @obBirthYearFix.
  ///
  /// In en, this message translates to:
  /// **'Let me fix that'**
  String get obBirthYearFix;

  /// No description provided for @obBirthYearErrorFuture.
  ///
  /// In en, this message translates to:
  /// **'That year hasn\'t happened yet. Want another go?'**
  String get obBirthYearErrorFuture;

  /// 122 = Jeanne Calment, the oldest verified human lifespan. It is the hard upper bound on the birth-year field; see docs/02 §8.
  ///
  /// In en, this message translates to:
  /// **'The oldest person ever verified made it to 122. Let\'s try that again.'**
  String get obBirthYearErrorTooOld;

  /// No description provided for @obBirthYearErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'That\'s not a year — and not an age either. One more go.'**
  String get obBirthYearErrorUnknown;

  /// No description provided for @obUnder18Title.
  ///
  /// In en, this message translates to:
  /// **'We can\'t help you here — but this can.'**
  String get obUnder18Title;

  /// No description provided for @obUnder18Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Cirrus is built for 18+. These two are free, private, and made for people your age. They work.'**
  String get obUnder18Subtitle;

  /// No description provided for @obUnder18TiqTitle.
  ///
  /// In en, this message translates to:
  /// **'This is Quitting'**
  String get obUnder18TiqTitle;

  /// No description provided for @obUnder18TiqBody.
  ///
  /// In en, this message translates to:
  /// **'Daily texts from people who get it. 500,000+ young people enrolled.'**
  String get obUnder18TiqBody;

  /// No description provided for @obUnder18TiqCta.
  ///
  /// In en, this message translates to:
  /// **'Text DITCHVAPE to 88709'**
  String get obUnder18TiqCta;

  /// No description provided for @obUnder18MlmqTitle.
  ///
  /// In en, this message translates to:
  /// **'My Life, My Quit'**
  String get obUnder18MlmqTitle;

  /// No description provided for @obUnder18MlmqBody.
  ///
  /// In en, this message translates to:
  /// **'Free coaching by text or call, made for teens. No lectures.'**
  String get obUnder18MlmqBody;

  /// No description provided for @obUnder18MlmqCta.
  ///
  /// In en, this message translates to:
  /// **'mylifemyquit.org'**
  String get obUnder18MlmqCta;

  /// No description provided for @obUnder18Footer.
  ///
  /// In en, this message translates to:
  /// **'Rooting for you. Come back at 18 if you still need us — you won\'t. 💪'**
  String get obUnder18Footer;

  /// No description provided for @obTriedTitle.
  ///
  /// In en, this message translates to:
  /// **'Tried quitting before?'**
  String get obTriedTitle;

  /// No description provided for @obTriedNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get obTriedNever;

  /// No description provided for @obTriedNeverSub.
  ///
  /// In en, this message translates to:
  /// **'first rodeo'**
  String get obTriedNeverSub;

  /// No description provided for @obTriedOnce.
  ///
  /// In en, this message translates to:
  /// **'Once'**
  String get obTriedOnce;

  /// No description provided for @obTriedOnceSub.
  ///
  /// In en, this message translates to:
  /// **'didn\'t stick'**
  String get obTriedOnceSub;

  /// No description provided for @obTried2to5.
  ///
  /// In en, this message translates to:
  /// **'2–5'**
  String get obTried2to5;

  /// No description provided for @obTried2to5Sub.
  ///
  /// In en, this message translates to:
  /// **'a few rounds'**
  String get obTried2to5Sub;

  /// No description provided for @obTried5plus.
  ///
  /// In en, this message translates to:
  /// **'5+'**
  String get obTried5plus;

  /// No description provided for @obTried5plusSub.
  ///
  /// In en, this message translates to:
  /// **'lost count'**
  String get obTried5plusSub;

  /// No description provided for @obTriedReaction.
  ///
  /// In en, this message translates to:
  /// **'Most people need a few tries. Every one taught your brain something — this time you\'ll have a plan.'**
  String get obTriedReaction;

  /// No description provided for @obFrequencyTitle.
  ///
  /// In en, this message translates to:
  /// **'How often is it in your hand?'**
  String get obFrequencyTitle;

  /// No description provided for @obFrequencySubtitle.
  ///
  /// In en, this message translates to:
  /// **'No judgment. Just calibration.'**
  String get obFrequencySubtitle;

  /// No description provided for @obFreqDaily.
  ///
  /// In en, this message translates to:
  /// **'DAILY'**
  String get obFreqDaily;

  /// No description provided for @obFreqDailySub.
  ///
  /// In en, this message translates to:
  /// **'Every day, with real breaks in between.'**
  String get obFreqDailySub;

  /// No description provided for @obFreqOften.
  ///
  /// In en, this message translates to:
  /// **'OFTEN'**
  String get obFreqOften;

  /// No description provided for @obFreqOftenSub.
  ///
  /// In en, this message translates to:
  /// **'Most of the day, some sessions.'**
  String get obFreqOftenSub;

  /// No description provided for @obFreqAlways.
  ///
  /// In en, this message translates to:
  /// **'ALWAYS'**
  String get obFreqAlways;

  /// No description provided for @obFreqAlwaysSub.
  ///
  /// In en, this message translates to:
  /// **'It\'s basically part of my hand.'**
  String get obFreqAlwaysSub;

  /// No description provided for @obPuffsTitle.
  ///
  /// In en, this message translates to:
  /// **'Puffs on a normal day?'**
  String get obPuffsTitle;

  /// No description provided for @obPuffsBadgeLight.
  ///
  /// In en, this message translates to:
  /// **'Light habit'**
  String get obPuffsBadgeLight;

  /// No description provided for @obPuffsBadgeModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate dependence'**
  String get obPuffsBadgeModerate;

  /// No description provided for @obPuffsBadgeHeavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy dependence'**
  String get obPuffsBadgeHeavy;

  /// No description provided for @obPuffsBadgeSevere.
  ///
  /// In en, this message translates to:
  /// **'Severe dependence'**
  String get obPuffsBadgeSevere;

  /// No description provided for @obPuffsCigEquiv.
  ///
  /// In en, this message translates to:
  /// **'≈ {count} cigarettes\' worth of puffs'**
  String obPuffsCigEquiv(int count);

  /// No description provided for @obPuffsNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure? Estimate from device life →'**
  String get obPuffsNotSure;

  /// No description provided for @obPuffsHelperTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick estimate'**
  String get obPuffsHelperTitle;

  /// No description provided for @obPuffsHelperBody.
  ///
  /// In en, this message translates to:
  /// **'A typical disposable is ~600 puffs. How many do you finish a week?'**
  String get obPuffsHelperBody;

  /// No description provided for @obPuffsHelperResult.
  ///
  /// In en, this message translates to:
  /// **'That\'s about {count} puffs a day. We\'ll self-correct in your first week.'**
  String obPuffsHelperResult(int count);

  /// No description provided for @obPuffsHelperDevicesPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} device / week} other{{count} devices / week}}'**
  String obPuffsHelperDevicesPerWeek(num count);

  /// No description provided for @obStrengthTitle.
  ///
  /// In en, this message translates to:
  /// **'How strong is your usual?'**
  String get obStrengthTitle;

  /// No description provided for @obStrength20Sub.
  ///
  /// In en, this message translates to:
  /// **'2% · lighter'**
  String get obStrength20Sub;

  /// No description provided for @obStrength35Sub.
  ///
  /// In en, this message translates to:
  /// **'3.5% · mid'**
  String get obStrength35Sub;

  /// No description provided for @obStrength50Sub.
  ///
  /// In en, this message translates to:
  /// **'5% · most disposables'**
  String get obStrength50Sub;

  /// No description provided for @obStrengthNotSure.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get obStrengthNotSure;

  /// No description provided for @obStrengthNotSureSub.
  ///
  /// In en, this message translates to:
  /// **'totally fine'**
  String get obStrengthNotSureSub;

  /// No description provided for @obStrengthNote.
  ///
  /// In en, this message translates to:
  /// **'Most disposables are 5% — if unsure, that\'s the safe guess.'**
  String get obStrengthNote;

  /// No description provided for @obSpendTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s it costing you a week?'**
  String get obSpendTitle;

  /// No description provided for @obSpendPerWeek.
  ///
  /// In en, this message translates to:
  /// **'per week'**
  String get obSpendPerWeek;

  /// No description provided for @obSpendThats.
  ///
  /// In en, this message translates to:
  /// **'that\'s'**
  String get obSpendThats;

  /// No description provided for @obSpendPerYear.
  ///
  /// In en, this message translates to:
  /// **'{amount} a year'**
  String obSpendPerYear(String amount);

  /// No description provided for @obSpendPerMonthChip.
  ///
  /// In en, this message translates to:
  /// **'{amount} / month'**
  String obSpendPerMonthChip(String amount);

  /// No description provided for @obSpendPerDayChip.
  ///
  /// In en, this message translates to:
  /// **'{amount} / day'**
  String obSpendPerDayChip(String amount);

  /// No description provided for @obSpendYourMath.
  ///
  /// In en, this message translates to:
  /// **'your math, not ours'**
  String get obSpendYourMath;

  /// No description provided for @obSpendComparisonOne.
  ///
  /// In en, this message translates to:
  /// **'That\'s {item}. Every year.'**
  String obSpendComparisonOne(String item);

  /// No description provided for @obSpendComparisonTwo.
  ///
  /// In en, this message translates to:
  /// **'That\'s {item} — twice over. Every year.'**
  String obSpendComparisonTwo(String item);

  /// No description provided for @obSpendComparisonMany.
  ///
  /// In en, this message translates to:
  /// **'That\'s {item}, {count} times over. Every year.'**
  String obSpendComparisonMany(String item, int count);

  /// No description provided for @obSpendItemGymMonth.
  ///
  /// In en, this message translates to:
  /// **'a month at the gym'**
  String get obSpendItemGymMonth;

  /// No description provided for @obSpendItemConcertTicket.
  ///
  /// In en, this message translates to:
  /// **'a concert ticket, good seats'**
  String get obSpendItemConcertTicket;

  /// No description provided for @obSpendItemRunningShoes.
  ///
  /// In en, this message translates to:
  /// **'a proper pair of running shoes'**
  String get obSpendItemRunningShoes;

  /// No description provided for @obSpendItemDentalCleaning.
  ///
  /// In en, this message translates to:
  /// **'a dental cleaning'**
  String get obSpendItemDentalCleaning;

  /// No description provided for @obSpendItemWinterCoat.
  ///
  /// In en, this message translates to:
  /// **'a winter coat that actually works'**
  String get obSpendItemWinterCoat;

  /// No description provided for @obSpendItemFestivalTicket.
  ///
  /// In en, this message translates to:
  /// **'a festival ticket, camping and all'**
  String get obSpendItemFestivalTicket;

  /// No description provided for @obSpendItemWeekendAway.
  ///
  /// In en, this message translates to:
  /// **'a weekend away'**
  String get obSpendItemWeekendAway;

  /// No description provided for @obSpendItemBike.
  ///
  /// In en, this message translates to:
  /// **'a bike worth riding'**
  String get obSpendItemBike;

  /// No description provided for @obSpendItemDrivingLessons.
  ///
  /// In en, this message translates to:
  /// **'a full set of driving lessons'**
  String get obSpendItemDrivingLessons;

  /// No description provided for @obSpendItemNewPhone.
  ///
  /// In en, this message translates to:
  /// **'a new phone'**
  String get obSpendItemNewPhone;

  /// No description provided for @obSpendItemLaptop.
  ///
  /// In en, this message translates to:
  /// **'a laptop that isn\'t dying'**
  String get obSpendItemLaptop;

  /// No description provided for @obSpendItemEmergencyFund.
  ///
  /// In en, this message translates to:
  /// **'a real emergency fund'**
  String get obSpendItemEmergencyFund;

  /// No description provided for @obSpendItemYogaYear.
  ///
  /// In en, this message translates to:
  /// **'a year of unlimited yoga'**
  String get obSpendItemYogaYear;

  /// No description provided for @obSpendItemMonthOfRent.
  ///
  /// In en, this message translates to:
  /// **'a month of rent'**
  String get obSpendItemMonthOfRent;

  /// No description provided for @obSpendItemFamilyHoliday.
  ///
  /// In en, this message translates to:
  /// **'a family holiday'**
  String get obSpendItemFamilyHoliday;

  /// No description provided for @obSpendItemUsedCar.
  ///
  /// In en, this message translates to:
  /// **'a car that gets you there'**
  String get obSpendItemUsedCar;

  /// No description provided for @obFirstPuffTitle.
  ///
  /// In en, this message translates to:
  /// **'First puff after waking up?'**
  String get obFirstPuffTitle;

  /// No description provided for @obFirstPuffWithin5.
  ///
  /// In en, this message translates to:
  /// **'Within 5 minutes'**
  String get obFirstPuffWithin5;

  /// No description provided for @obFirstPuff5to30.
  ///
  /// In en, this message translates to:
  /// **'5–30 minutes'**
  String get obFirstPuff5to30;

  /// No description provided for @obFirstPuff30to60.
  ///
  /// In en, this message translates to:
  /// **'30–60 minutes'**
  String get obFirstPuff30to60;

  /// No description provided for @obFirstPuffHourPlus.
  ///
  /// In en, this message translates to:
  /// **'An hour or more'**
  String get obFirstPuffHourPlus;

  /// No description provided for @obFirstPuffScience.
  ///
  /// In en, this message translates to:
  /// **'Time-to-first-puff is the strongest single predictor of dependence. 76% of young vapers reach for it within 30 min of waking.'**
  String get obFirstPuffScience;

  /// No description provided for @obFactLabelScience.
  ///
  /// In en, this message translates to:
  /// **'THE SCIENCE'**
  String get obFactLabelScience;

  /// No description provided for @obFactLabelYourNumbers.
  ///
  /// In en, this message translates to:
  /// **'YOUR NUMBERS'**
  String get obFactLabelYourNumbers;

  /// Source: JAMA Network Open, failed quit attempts among daily young users 28% -> 53%, 2020-2024. On the approved list in docs/02 section 8.
  ///
  /// In en, this message translates to:
  /// **'Among daily young users, failed quit attempts went from 28% to 53% between 2020 and 2024. The devices got better at their job. That isn\'t you getting weaker — it\'s an arms race nobody asked you to enter.'**
  String get obFactTried;

  /// Arithmetic on the user's own puff count and nicotine strength (DependenceEngine.nicotineMg). Always rendered with the approximately sign.
  ///
  /// In en, this message translates to:
  /// **'That\'s ≈{mg} mg of nicotine a day. Your numbers, our multiplying. Your vape, meanwhile, has never once suggested a portion size.'**
  String obFactStrength(int mg);

  /// Source: nicotine craving literature, most cravings pass in 15-20 minutes. On the approved list in docs/02 section 8.
  ///
  /// In en, this message translates to:
  /// **'Most cravings peak and pass inside 15–20 minutes. Shorter than waiting for a table. The panic button is built around exactly that window.'**
  String get obFactWorryCravings;

  /// Source: peer-support cessation literature, roughly 40% uplift. On the approved list in docs/02 section 8.
  ///
  /// In en, this message translates to:
  /// **'Peer support raises quit success by around 40%. Yes — strangers on the internet. We were surprised too.'**
  String get obFactWorrySocial;

  /// No description provided for @obWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Why do you want out?'**
  String get obWhyTitle;

  /// No description provided for @obWhySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick all that hit. Your coach will use these when it gets hard.'**
  String get obWhySubtitle;

  /// No description provided for @obWhyHealth.
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get obWhyHealth;

  /// No description provided for @obWhyMoney.
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get obWhyMoney;

  /// No description provided for @obWhyFreedom.
  ///
  /// In en, this message translates to:
  /// **'Freedom'**
  String get obWhyFreedom;

  /// No description provided for @obWhyFamily.
  ///
  /// In en, this message translates to:
  /// **'Family'**
  String get obWhyFamily;

  /// No description provided for @obWhyFitness.
  ///
  /// In en, this message translates to:
  /// **'Fitness'**
  String get obWhyFitness;

  /// No description provided for @obWhyAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get obWhyAppearance;

  /// No description provided for @obWhyCardLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR WHY'**
  String get obWhyCardLabel;

  /// No description provided for @obWorriesTitle.
  ///
  /// In en, this message translates to:
  /// **'What worries you most?'**
  String get obWorriesTitle;

  /// No description provided for @obWorriesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Be honest. This is the useful part.'**
  String get obWorriesSubtitle;

  /// No description provided for @obWorryCravings.
  ///
  /// In en, this message translates to:
  /// **'Cravings'**
  String get obWorryCravings;

  /// No description provided for @obWorryStress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get obWorryStress;

  /// No description provided for @obWorrySocial.
  ///
  /// In en, this message translates to:
  /// **'Social pressure'**
  String get obWorrySocial;

  /// No description provided for @obWorryFailing.
  ///
  /// In en, this message translates to:
  /// **'Fear of failing'**
  String get obWorryFailing;

  /// No description provided for @obWorryWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight gain'**
  String get obWorryWeight;

  /// No description provided for @obWorryBreaks.
  ///
  /// In en, this message translates to:
  /// **'Losing my breaks'**
  String get obWorryBreaks;

  /// No description provided for @obWorriesAiNote.
  ///
  /// In en, this message translates to:
  /// **'Your coach trains on exactly these. Craving at 11 p.m.? It already knows your playbook.'**
  String get obWorriesAiNote;

  /// No description provided for @obMethodFailingNote.
  ///
  /// In en, this message translates to:
  /// **'You picked \"fear of failing\" — so this plan bends instead of breaking. A slip adjusts the curve; nothing ever resets.'**
  String get obMethodFailingNote;

  /// No description provided for @obMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you want to do this?'**
  String get obMethodTitle;

  /// No description provided for @obMethodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Both work. One honest line each.'**
  String get obMethodSubtitle;

  /// No description provided for @obMethodTaper.
  ///
  /// In en, this message translates to:
  /// **'Taper down'**
  String get obMethodTaper;

  /// No description provided for @obMethodTaperSub.
  ///
  /// In en, this message translates to:
  /// **'Ease off on a daily curve. Gentler withdrawal, takes discipline.'**
  String get obMethodTaperSub;

  /// No description provided for @obMethodTaperReco.
  ///
  /// In en, this message translates to:
  /// **'Best for 100+ puffs/day — that\'s you'**
  String get obMethodTaperReco;

  /// No description provided for @obMethodCold.
  ///
  /// In en, this message translates to:
  /// **'Cold turkey'**
  String get obMethodCold;

  /// No description provided for @obMethodColdSub.
  ///
  /// In en, this message translates to:
  /// **'One hard stop. Rough first week, out of the woods faster.'**
  String get obMethodColdSub;

  /// No description provided for @obMethodColdReco.
  ///
  /// In en, this message translates to:
  /// **'Doable at your level — your call'**
  String get obMethodColdReco;

  /// No description provided for @obPaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick your pace.'**
  String get obPaceTitle;

  /// No description provided for @obPaceMostChosen.
  ///
  /// In en, this message translates to:
  /// **'{days} days — most chosen'**
  String obPaceMostChosen(int days);

  /// No description provided for @obPaceCurveStart.
  ///
  /// In en, this message translates to:
  /// **'{count} puffs'**
  String obPaceCurveStart(int count);

  /// No description provided for @obPaceCurveLabel.
  ///
  /// In en, this message translates to:
  /// **'your curve'**
  String get obPaceCurveLabel;

  /// No description provided for @obPaceCurveEnd.
  ///
  /// In en, this message translates to:
  /// **'0 puffs'**
  String get obPaceCurveEnd;

  /// No description provided for @obPaceFreedomDay.
  ///
  /// In en, this message translates to:
  /// **'{date} · Freedom Day'**
  String obPaceFreedomDay(String date);

  /// No description provided for @obPaceNote.
  ///
  /// In en, this message translates to:
  /// **'Curve redraws live as you tap a pace. Real dates, not \"day n\".'**
  String get obPaceNote;

  /// No description provided for @obPaceCta.
  ///
  /// In en, this message translates to:
  /// **'Lock my pace'**
  String get obPaceCta;

  /// No description provided for @obBuildingTitle.
  ///
  /// In en, this message translates to:
  /// **'Building your plan…'**
  String get obBuildingTitle;

  /// No description provided for @obBuildingStep1.
  ///
  /// In en, this message translates to:
  /// **'Analyzing {count} puffs/day'**
  String obBuildingStep1(int count);

  /// No description provided for @obBuildingStep2.
  ///
  /// In en, this message translates to:
  /// **'Mapping your triggers'**
  String get obBuildingStep2;

  /// No description provided for @obBuildingStep3.
  ///
  /// In en, this message translates to:
  /// **'Calibrating your {days}-day curve…'**
  String obBuildingStep3(int days);

  /// No description provided for @obBuildingStep4.
  ///
  /// In en, this message translates to:
  /// **'Reserving your coach…'**
  String get obBuildingStep4;

  /// No description provided for @obRevealTitle.
  ///
  /// In en, this message translates to:
  /// **'Your {days}-day breakup plan.'**
  String obRevealTitle(int days);

  /// No description provided for @obRevealMilestone3.
  ///
  /// In en, this message translates to:
  /// **'craving peak — we\'ll be loudest here'**
  String get obRevealMilestone3;

  /// No description provided for @obRevealMilestone7.
  ///
  /// In en, this message translates to:
  /// **'taste and smell come back'**
  String get obRevealMilestone7;

  /// No description provided for @obRevealMilestoneFreedom.
  ///
  /// In en, this message translates to:
  /// **'🏆 Freedom Day — {date}'**
  String obRevealMilestoneFreedom(String date);

  /// No description provided for @obRevealSavedLabel.
  ///
  /// In en, this message translates to:
  /// **'saved by Freedom Day'**
  String get obRevealSavedLabel;

  /// No description provided for @obRevealPuffsLabel.
  ///
  /// In en, this message translates to:
  /// **'puffs you won\'t take'**
  String get obRevealPuffsLabel;

  /// No description provided for @obRevealProofLabel.
  ///
  /// In en, this message translates to:
  /// **'HONEST PROOF'**
  String get obRevealProofLabel;

  /// No description provided for @obRevealProof.
  ///
  /// In en, this message translates to:
  /// **'24% quit with a structured program vs 19% alone — randomized trial of 2,588 young adults. Not magic. Better odds.'**
  String get obRevealProof;

  /// No description provided for @obRevealComparisonOne.
  ///
  /// In en, this message translates to:
  /// **'By Freedom Day, that\'s {item}.'**
  String obRevealComparisonOne(String item);

  /// No description provided for @obRevealComparisonTwo.
  ///
  /// In en, this message translates to:
  /// **'By Freedom Day, that\'s {item} — twice over.'**
  String obRevealComparisonTwo(String item);

  /// No description provided for @obRevealComparisonMany.
  ///
  /// In en, this message translates to:
  /// **'By Freedom Day, that\'s {item}, {count} times over.'**
  String obRevealComparisonMany(String item, int count);

  /// No description provided for @obRevealCta.
  ///
  /// In en, this message translates to:
  /// **'I\'m ready'**
  String get obRevealCta;

  /// No description provided for @obCommitTitle.
  ///
  /// In en, this message translates to:
  /// **'Make it real.'**
  String get obCommitTitle;

  /// No description provided for @obCommitSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold the button. Mean it.'**
  String get obCommitSubtitle;

  /// No description provided for @obCommitHold.
  ///
  /// In en, this message translates to:
  /// **'Hold to\ncommit'**
  String get obCommitHold;

  /// No description provided for @obCommitFreedomLabel.
  ///
  /// In en, this message translates to:
  /// **'🏆 FREEDOM DAY'**
  String get obCommitFreedomLabel;

  /// No description provided for @obCommitDaysOut.
  ///
  /// In en, this message translates to:
  /// **'{days} days from today. It\'s on the calendar.'**
  String obCommitDaysOut(int days);

  /// No description provided for @obCommitPrivacy.
  ///
  /// In en, this message translates to:
  /// **'🔒 We never sell your data. No ad trackers. Ever.'**
  String get obCommitPrivacy;

  /// No description provided for @obRatingTitle.
  ///
  /// In en, this message translates to:
  /// **'One quitter\'s review helps the next one find us.'**
  String get obRatingTitle;

  /// No description provided for @obRatingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'30 seconds. Skippable. No hard feelings.'**
  String get obRatingSubtitle;

  /// No description provided for @obRatingBetaTester.
  ///
  /// In en, this message translates to:
  /// **'BETA TESTER'**
  String get obRatingBetaTester;

  /// No description provided for @obRatingQuote1.
  ///
  /// In en, this message translates to:
  /// **'\"The panic button got me through week one. I\'d have caved on day 3 without it.\"'**
  String get obRatingQuote1;

  /// No description provided for @obRatingQuote2.
  ///
  /// In en, this message translates to:
  /// **'\"First app that didn\'t talk to me like a doctor or my mom.\"'**
  String get obRatingQuote2;

  /// No description provided for @obRatingCta.
  ///
  /// In en, this message translates to:
  /// **'Rate Cirrus'**
  String get obRatingCta;

  /// No description provided for @obCoachNameTitle.
  ///
  /// In en, this message translates to:
  /// **'Meet your coach.'**
  String get obCoachNameTitle;

  /// No description provided for @obCoachNameSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your coach. Quit two years ago, remembers exactly how it felt, and has already read your plan.'**
  String get obCoachNameSubtitle;

  /// No description provided for @obCoachNameAsk.
  ///
  /// In en, this message translates to:
  /// **'We call it {name}. It answers to anything — pick the name you\'d text at 2am.'**
  String obCoachNameAsk(String name);

  /// No description provided for @obCoachNameFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Coach\'s name'**
  String get obCoachNameFieldLabel;

  /// No description provided for @obCoachNameSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Or borrow one:'**
  String get obCoachNameSuggestions;

  /// No description provided for @obCoachNameKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep {name}'**
  String obCoachNameKeep(String name);

  /// No description provided for @obCoachNameCta.
  ///
  /// In en, this message translates to:
  /// **'That\'s the one'**
  String get obCoachNameCta;

  /// No description provided for @obCoachNameLater.
  ///
  /// In en, this message translates to:
  /// **'You can change it any time in Settings.'**
  String get obCoachNameLater;

  /// No description provided for @obCoachNameErrorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Give them something to be called.'**
  String get obCoachNameErrorEmpty;

  /// No description provided for @obCoachNameErrorLong.
  ///
  /// In en, this message translates to:
  /// **'Keep it to 20 characters or fewer.'**
  String get obCoachNameErrorLong;

  /// No description provided for @obCoachNameErrorChars.
  ///
  /// In en, this message translates to:
  /// **'Letters, numbers, spaces and - \' only.'**
  String get obCoachNameErrorChars;

  /// No description provided for @obCoachNameErrorRejected.
  ///
  /// In en, this message translates to:
  /// **'Let\'s pick a different one.'**
  String get obCoachNameErrorRejected;

  /// No description provided for @settingsCoachName.
  ///
  /// In en, this message translates to:
  /// **'Your coach\'s name'**
  String get settingsCoachName;

  /// No description provided for @coachRenamed.
  ///
  /// In en, this message translates to:
  /// **'Alright — {name} from now on.'**
  String coachRenamed(String name);

  /// No description provided for @obCoachNameSuggestion1.
  ///
  /// In en, this message translates to:
  /// **'Pip'**
  String get obCoachNameSuggestion1;

  /// No description provided for @obCoachNameSuggestion2.
  ///
  /// In en, this message translates to:
  /// **'Fin'**
  String get obCoachNameSuggestion2;

  /// No description provided for @obCoachNameSuggestion3.
  ///
  /// In en, this message translates to:
  /// **'Koda'**
  String get obCoachNameSuggestion3;

  /// No description provided for @obCoachNameSuggestion4.
  ///
  /// In en, this message translates to:
  /// **'Wren'**
  String get obCoachNameSuggestion4;

  /// No description provided for @obWhyWordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tell {name} one thing.'**
  String obWhyWordsTitle(String name);

  /// No description provided for @obWhyWordsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Why now? Not the health-class answer — the real one.'**
  String get obWhyWordsSubtitle;

  /// No description provided for @obWhyWordsFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'In your own words'**
  String get obWhyWordsFieldLabel;

  /// No description provided for @obWhyWordsHintHealth.
  ///
  /// In en, this message translates to:
  /// **'so I stop sounding like a kettle on the stairs'**
  String get obWhyWordsHintHealth;

  /// No description provided for @obWhyWordsHintMoney.
  ///
  /// In en, this message translates to:
  /// **'I want my money back. And my mornings.'**
  String get obWhyWordsHintMoney;

  /// No description provided for @obWhyWordsHintFreedom.
  ///
  /// In en, this message translates to:
  /// **'because I\'m done with the 11pm gas-station run'**
  String get obWhyWordsHintFreedom;

  /// No description provided for @obWhyWordsHintFamily.
  ///
  /// In en, this message translates to:
  /// **'my kid found it in my jacket. Never again.'**
  String get obWhyWordsHintFamily;

  /// No description provided for @obWhyWordsHintFitness.
  ///
  /// In en, this message translates to:
  /// **'so I can run with her without stopping'**
  String get obWhyWordsHintFitness;

  /// No description provided for @obWhyWordsHintAppearance.
  ///
  /// In en, this message translates to:
  /// **'I want the un-tired version of my face back'**
  String get obWhyWordsHintAppearance;

  /// No description provided for @obWhyWordsNote.
  ///
  /// In en, this message translates to:
  /// **'{name} will remember this.'**
  String obWhyWordsNote(String name);

  /// No description provided for @obWhyWordsErrorLong.
  ///
  /// In en, this message translates to:
  /// **'Keep it to 200 characters or fewer.'**
  String get obWhyWordsErrorLong;

  /// No description provided for @obWhyWordsCta.
  ///
  /// In en, this message translates to:
  /// **'That\'s why'**
  String get obWhyWordsCta;

  /// No description provided for @obWhyWordsSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip this'**
  String get obWhyWordsSkip;

  /// No description provided for @obNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup, exactly when you cave.'**
  String get obNotifTitle;

  /// No description provided for @obNotifSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not spam. One nudge before your danger hours, one when you hit a milestone.'**
  String get obNotifSubtitle;

  /// No description provided for @obNotifPreviewTime.
  ///
  /// In en, this message translates to:
  /// **'Fri 9:54 PM'**
  String get obNotifPreviewTime;

  /// No description provided for @obNotifPreviewBody.
  ///
  /// In en, this message translates to:
  /// **'heads up — Friday nights are your spike. Plan\'s ready 💪'**
  String get obNotifPreviewBody;

  /// No description provided for @obNotifBullet1.
  ///
  /// In en, this message translates to:
  /// **'Danger-hour heads-up (you set the hours)'**
  String get obNotifBullet1;

  /// No description provided for @obNotifBullet2.
  ///
  /// In en, this message translates to:
  /// **'Streak + milestone celebrations'**
  String get obNotifBullet2;

  /// No description provided for @obNotifBullet3.
  ///
  /// In en, this message translates to:
  /// **'Nothing else — no marketing, ever'**
  String get obNotifBullet3;

  /// No description provided for @obNotifCta.
  ///
  /// In en, this message translates to:
  /// **'Turn on backup'**
  String get obNotifCta;

  /// No description provided for @paywallTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan is ready.'**
  String get paywallTitle;

  /// No description provided for @paywallTitleUpgrade.
  ///
  /// In en, this message translates to:
  /// **'Go further with Premium.'**
  String get paywallTitleUpgrade;

  /// No description provided for @paywallFeatCoach.
  ///
  /// In en, this message translates to:
  /// **'Unlimited AI coach that remembers your why'**
  String get paywallFeatCoach;

  /// No description provided for @paywallFeatPanic.
  ///
  /// In en, this message translates to:
  /// **'Panic button: a 60-second craving killer'**
  String get paywallFeatPanic;

  /// No description provided for @paywallFeatPlan.
  ///
  /// In en, this message translates to:
  /// **'A plan that adapts when you slip'**
  String get paywallFeatPlan;

  /// No description provided for @paywallFeatForecasts.
  ///
  /// In en, this message translates to:
  /// **'Craving forecasts for your danger hours'**
  String get paywallFeatForecasts;

  /// No description provided for @paywallFeatCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community that answers your SOS'**
  String get paywallFeatCommunity;

  /// No description provided for @paywallFeatReports.
  ///
  /// In en, this message translates to:
  /// **'Weekly report in your own numbers'**
  String get paywallFeatReports;

  /// No description provided for @paywallYearly.
  ///
  /// In en, this message translates to:
  /// **'YEARLY'**
  String get paywallYearly;

  /// No description provided for @paywallYearlyBadge.
  ///
  /// In en, this message translates to:
  /// **'BEST VALUE'**
  String get paywallYearlyBadge;

  /// No description provided for @paywallMonthly.
  ///
  /// In en, this message translates to:
  /// **'MONTHLY'**
  String get paywallMonthly;

  /// No description provided for @paywallWeekly.
  ///
  /// In en, this message translates to:
  /// **'WEEKLY'**
  String get paywallWeekly;

  /// No description provided for @paywallWeeklySub.
  ///
  /// In en, this message translates to:
  /// **'Founding price — locked forever'**
  String get paywallWeeklySub;

  /// No description provided for @paywallTrialReminder.
  ///
  /// In en, this message translates to:
  /// **'🔔 We\'ll remind you before your trial ends'**
  String get paywallTrialReminder;

  /// No description provided for @paywallCancelAnytime.
  ///
  /// In en, this message translates to:
  /// **'Cancel anytime'**
  String get paywallCancelAnytime;

  /// No description provided for @paywallAnchor.
  ///
  /// In en, this message translates to:
  /// **'Less than one disposable a week'**
  String get paywallAnchor;

  /// No description provided for @paywallCta.
  ///
  /// In en, this message translates to:
  /// **'Start my free week'**
  String get paywallCta;

  /// No description provided for @paywallFreeLink.
  ///
  /// In en, this message translates to:
  /// **'Continue with Free plan →'**
  String get paywallFreeLink;

  /// No description provided for @paywallTimelineToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get paywallTimelineToday;

  /// No description provided for @paywallTimelineDay.
  ///
  /// In en, this message translates to:
  /// **'Day {n}'**
  String paywallTimelineDay(int n);

  /// No description provided for @paywallTimelineTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Everything unlocked'**
  String get paywallTimelineTodayBody;

  /// No description provided for @paywallTimelineRemindBody.
  ///
  /// In en, this message translates to:
  /// **'We remind you'**
  String get paywallTimelineRemindBody;

  /// No description provided for @paywallTimelineNoRemindBody.
  ///
  /// In en, this message translates to:
  /// **'Last day to cancel free'**
  String get paywallTimelineNoRemindBody;

  /// No description provided for @paywallTimelineChargeBody.
  ///
  /// In en, this message translates to:
  /// **'First charge {price}. Cancel before, pay nothing.'**
  String paywallTimelineChargeBody(String price);

  /// No description provided for @paywallPerYear.
  ///
  /// In en, this message translates to:
  /// **'{price}/yr'**
  String paywallPerYear(String price);

  /// No description provided for @paywallPerMonth.
  ///
  /// In en, this message translates to:
  /// **'{price}/mo'**
  String paywallPerMonth(String price);

  /// No description provided for @paywallPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{price}/wk'**
  String paywallPerWeek(String price);

  /// No description provided for @paywallDisclosureTrial.
  ///
  /// In en, this message translates to:
  /// **'{price} per {period} after your {days}-day free trial. Renews automatically until you cancel — cancel anytime in your {store} subscription settings.'**
  String paywallDisclosureTrial(
    String price,
    String period,
    int days,
    String store,
  );

  /// No description provided for @paywallDisclosure.
  ///
  /// In en, this message translates to:
  /// **'{price} per {period}. Renews automatically until you cancel — cancel anytime in your {store} subscription settings.'**
  String paywallDisclosure(String price, String period, String store);

  /// No description provided for @paywallPeriodWeek.
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get paywallPeriodWeek;

  /// No description provided for @paywallPeriodMonth.
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get paywallPeriodMonth;

  /// No description provided for @paywallPeriodYear.
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get paywallPeriodYear;

  /// No description provided for @paywallStoreApple.
  ///
  /// In en, this message translates to:
  /// **'App Store'**
  String get paywallStoreApple;

  /// No description provided for @paywallStoreGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google Play'**
  String get paywallStoreGoogle;

  /// No description provided for @paywallYearlySubLive.
  ///
  /// In en, this message translates to:
  /// **'{perWeek}/week · SAVE {percent}%'**
  String paywallYearlySubLive(String perWeek, int percent);

  /// No description provided for @paywallYearlySubPerWeek.
  ///
  /// In en, this message translates to:
  /// **'{perWeek}/week'**
  String paywallYearlySubPerWeek(String perWeek);

  /// No description provided for @paywallCtaTrial.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Start my free day} other{Start my free {days} days}}'**
  String paywallCtaTrial(int days);

  /// No description provided for @paywallCtaSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Start Premium'**
  String get paywallCtaSubscribe;

  /// No description provided for @paywallSubtitleTrial.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Try everything free for a day.} other{Try everything free for {days} days.}}'**
  String paywallSubtitleTrial(int days);

  /// No description provided for @paywallSubtitleNoTrial.
  ///
  /// In en, this message translates to:
  /// **'Everything unlocked, from today.'**
  String get paywallSubtitleNoTrial;

  /// No description provided for @paywallRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get paywallRestore;

  /// No description provided for @paywallRestored.
  ///
  /// In en, this message translates to:
  /// **'Welcome back — Premium is on.'**
  String get paywallRestored;

  /// No description provided for @paywallRestoreNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore on this store account yet.'**
  String get paywallRestoreNothing;

  /// No description provided for @paywallPurchasePending.
  ///
  /// In en, this message translates to:
  /// **'Your payment is pending. Premium switches on as soon as the store confirms it.'**
  String get paywallPurchasePending;

  /// No description provided for @paywallPricesUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Live prices aren\'t loading right now — the store shows the exact price before you confirm.'**
  String get paywallPricesUnavailable;

  /// No description provided for @premiumLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumLockTitle;

  /// No description provided for @premiumLockCta.
  ///
  /// In en, this message translates to:
  /// **'See Premium'**
  String get premiumLockCta;

  /// No description provided for @premiumPitchInsight.
  ///
  /// In en, this message translates to:
  /// **'Your weekly report, written from your own numbers.'**
  String get premiumPitchInsight;

  /// No description provided for @premiumPitchForecast.
  ///
  /// In en, this message translates to:
  /// **'Craving forecasts for the hours you usually reach for it.'**
  String get premiumPitchForecast;

  /// No description provided for @premiumFreeHistoryNote.
  ///
  /// In en, this message translates to:
  /// **'Free shows your last 7 days.'**
  String get premiumFreeHistoryNote;

  /// No description provided for @premiumPitchCompose.
  ///
  /// In en, this message translates to:
  /// **'Posting is part of Premium. Reading and reacting are always free — and so is an SOS.'**
  String get premiumPitchCompose;

  /// No description provided for @premiumPitchPlan.
  ///
  /// In en, this message translates to:
  /// **'A plan that adapts when you slip — tonight\'s adjustment, every night.'**
  String get premiumPitchPlan;

  /// No description provided for @premiumPitchHealth.
  ///
  /// In en, this message translates to:
  /// **'The full timeline, from two weeks to a year.'**
  String get premiumPitchHealth;

  /// No description provided for @freePlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Free gets you moving.'**
  String get freePlanTitle;

  /// No description provided for @freePlanSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Yours forever. No countdown, no nagging.'**
  String get freePlanSubtitle;

  /// No description provided for @freePlanFeat1.
  ///
  /// In en, this message translates to:
  /// **'Puff log + streaks'**
  String get freePlanFeat1;

  /// No description provided for @freePlanFeat2.
  ///
  /// In en, this message translates to:
  /// **'Money-saved ticker'**
  String get freePlanFeat2;

  /// No description provided for @freePlanFeat3.
  ///
  /// In en, this message translates to:
  /// **'5 coach messages a day'**
  String get freePlanFeat3;

  /// No description provided for @freePlanFeat4.
  ///
  /// In en, this message translates to:
  /// **'1 Panic Button session a day'**
  String get freePlanFeat4;

  /// No description provided for @freePlanFeat5.
  ///
  /// In en, this message translates to:
  /// **'Community (read + react)'**
  String get freePlanFeat5;

  /// No description provided for @freePlanUpgradeNote.
  ///
  /// In en, this message translates to:
  /// **'Upgrade any time — your streak and history come with you.'**
  String get freePlanUpgradeNote;

  /// No description provided for @freePlanCta.
  ///
  /// In en, this message translates to:
  /// **'Start with Free'**
  String get freePlanCta;

  /// No description provided for @winbackBadge.
  ///
  /// In en, this message translates to:
  /// **'ONE-TIME FOUNDING OFFER'**
  String get winbackBadge;

  /// No description provided for @winbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Okay — first month on us. Almost.'**
  String get winbackTitle;

  /// No description provided for @winbackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You built the plan. Try the full toolkit for a month before deciding.'**
  String get winbackSubtitle;

  /// No description provided for @winbackFirstMonth.
  ///
  /// In en, this message translates to:
  /// **'first month'**
  String get winbackFirstMonth;

  /// No description provided for @winbackNote.
  ///
  /// In en, this message translates to:
  /// **'Then {price}/mo. Cancel anytime. Shown once, never again.'**
  String winbackNote(String price);

  /// No description provided for @winbackCta.
  ///
  /// In en, this message translates to:
  /// **'Claim founding month'**
  String get winbackCta;

  /// No description provided for @winbackDecline.
  ///
  /// In en, this message translates to:
  /// **'No thanks, Free is fine'**
  String get winbackDecline;

  /// No description provided for @day1Title.
  ///
  /// In en, this message translates to:
  /// **'Day 1. Let\'s go.'**
  String get day1Title;

  /// No description provided for @day1Subtitle.
  ///
  /// In en, this message translates to:
  /// **'Three setup moves. Two minutes. Then the app does its job.'**
  String get day1Subtitle;

  /// No description provided for @day1Task1.
  ///
  /// In en, this message translates to:
  /// **'Log your first puff'**
  String get day1Task1;

  /// No description provided for @day1Task1Done.
  ///
  /// In en, this message translates to:
  /// **'done — honesty from puff one'**
  String get day1Task1Done;

  /// No description provided for @day1Task1Sub.
  ///
  /// In en, this message translates to:
  /// **'one honest tap on the big button'**
  String get day1Task1Sub;

  /// No description provided for @day1Task2.
  ///
  /// In en, this message translates to:
  /// **'Meet your coach'**
  String get day1Task2;

  /// No description provided for @day1Task2Sub.
  ///
  /// In en, this message translates to:
  /// **'30-sec hello. It already knows your triggers.'**
  String get day1Task2Sub;

  /// No description provided for @day1Task3.
  ///
  /// In en, this message translates to:
  /// **'Set your danger hours'**
  String get day1Task3;

  /// No description provided for @day1Task3Sub.
  ///
  /// In en, this message translates to:
  /// **'when do you cave? we\'ll show up early'**
  String get day1Task3Sub;

  /// No description provided for @day1Skip.
  ///
  /// In en, this message translates to:
  /// **'Skip setup for now'**
  String get day1Skip;

  /// No description provided for @day1TourLogTitle.
  ///
  /// In en, this message translates to:
  /// **'This is the whole app.'**
  String get day1TourLogTitle;

  /// No description provided for @day1TourLogBody.
  ///
  /// In en, this message translates to:
  /// **'Every puff, tapped here. Honest counts are the only thing that makes the plan real — go on, log one now.'**
  String get day1TourLogBody;

  /// No description provided for @day1TourCoachTitle.
  ///
  /// In en, this message translates to:
  /// **'Say anything.'**
  String get day1TourCoachTitle;

  /// No description provided for @day1TourCoachBody.
  ///
  /// In en, this message translates to:
  /// **'{name} has already read your plan — your numbers, your triggers, the hours you struggle. Type a hello and see.'**
  String day1TourCoachBody(String name);

  /// No description provided for @day1TourHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'When do you cave?'**
  String get day1TourHoursTitle;

  /// No description provided for @day1TourHoursBody.
  ///
  /// In en, this message translates to:
  /// **'Pick the hour it usually hits. We show up ten minutes before it, on your phone, without you asking.'**
  String get day1TourHoursBody;

  /// No description provided for @day1FreedomNote.
  ///
  /// In en, this message translates to:
  /// **'Freedom Day: {date} · {days} days out · plan armed'**
  String day1FreedomNote(String date, int days);

  /// No description provided for @day1CtaCoach.
  ///
  /// In en, this message translates to:
  /// **'Meet your coach'**
  String get day1CtaCoach;

  /// No description provided for @day1CtaHome.
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get day1CtaHome;

  /// No description provided for @homeGreetingDate.
  ///
  /// In en, this message translates to:
  /// **'{date} · Day {day} of {total}'**
  String homeGreetingDate(String date, int day, int total);

  /// No description provided for @homeGreetingFreedomDay.
  ///
  /// In en, this message translates to:
  /// **'{date} · Freedom Day 🏆'**
  String homeGreetingFreedomDay(String date);

  /// No description provided for @homeGreetingMaintenance.
  ///
  /// In en, this message translates to:
  /// **'{date} · {count, plural, one{1 day past Freedom Day} other{{count} days past Freedom Day}}'**
  String homeGreetingMaintenance(String date, num count);

  /// No description provided for @homeFreedomDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Freedom Day. You picked this date.'**
  String get homeFreedomDayTitle;

  /// No description provided for @homeFreedomDayBody.
  ///
  /// In en, this message translates to:
  /// **'The plan ends today and the line stays at zero from here. Every vape-free day you confirm now is maintenance — same flame, same streak.'**
  String get homeFreedomDayBody;

  /// No description provided for @homeTitle.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeTitle;

  /// No description provided for @homeStreakChip.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{🔥 {count} day} other{🔥 {count} days}}'**
  String homeStreakChip(num count);

  /// No description provided for @homePuffsToday.
  ///
  /// In en, this message translates to:
  /// **'puffs today'**
  String get homePuffsToday;

  /// No description provided for @homeOfLimit.
  ///
  /// In en, this message translates to:
  /// **'of {limit}'**
  String homeOfLimit(int limit);

  /// No description provided for @homeLeftAhead.
  ///
  /// In en, this message translates to:
  /// **'{count} left on today\'s line. You\'re ahead of your curve.'**
  String homeLeftAhead(int count);

  /// No description provided for @homeLeftTight.
  ///
  /// In en, this message translates to:
  /// **'{count} left on today\'s line. Tight — you\'ve got this.'**
  String homeLeftTight(int count);

  /// No description provided for @homeVsDay1.
  ///
  /// In en, this message translates to:
  /// **'{percent} vs day 1'**
  String homeVsDay1(String percent);

  /// No description provided for @homeSavedSoFar.
  ///
  /// In en, this message translates to:
  /// **'saved so far'**
  String get homeSavedSoFar;

  /// No description provided for @homeCravingsBeaten.
  ///
  /// In en, this message translates to:
  /// **'cravings beaten'**
  String get homeCravingsBeaten;

  /// No description provided for @homeCoachNudgeTitle.
  ///
  /// In en, this message translates to:
  /// **'Rough {weekday}? I noticed.'**
  String homeCoachNudgeTitle(String weekday);

  /// No description provided for @homeCoachNudgeBody.
  ///
  /// In en, this message translates to:
  /// **'Your {hour} spike is due — want a plan?'**
  String homeCoachNudgeBody(String hour);

  /// No description provided for @homeLogPuff.
  ///
  /// In en, this message translates to:
  /// **'LOG PUFF'**
  String get homeLogPuff;

  /// No description provided for @homeSos.
  ///
  /// In en, this message translates to:
  /// **'SOS'**
  String get homeSos;

  /// No description provided for @homeVapeFreeTitle.
  ///
  /// In en, this message translates to:
  /// **'No puffs today?'**
  String get homeVapeFreeTitle;

  /// No description provided for @homeVapeFreeCta.
  ///
  /// In en, this message translates to:
  /// **'Confirm vape-free day ✓'**
  String get homeVapeFreeCta;

  /// No description provided for @homeVapeFreeDone.
  ///
  /// In en, this message translates to:
  /// **'Vape-free day locked in. That\'s the whole game. 🔥'**
  String get homeVapeFreeDone;

  /// No description provided for @homeYesterdayTitle.
  ///
  /// In en, this message translates to:
  /// **'Was yesterday vape-free?'**
  String get homeYesterdayTitle;

  /// No description provided for @homeYesterdayBody.
  ///
  /// In en, this message translates to:
  /// **'No log for {date}. Only you know, so we ask instead of guessing.'**
  String homeYesterdayBody(String date);

  /// No description provided for @homeYesterdayYes.
  ///
  /// In en, this message translates to:
  /// **'Vape-free ✓'**
  String get homeYesterdayYes;

  /// No description provided for @homeYesterdayNo.
  ///
  /// In en, this message translates to:
  /// **'I vaped'**
  String get homeYesterdayNo;

  /// No description provided for @homeYesterdayDone.
  ///
  /// In en, this message translates to:
  /// **'Yesterday locked in. Your streak knows the truth. 🔥'**
  String get homeYesterdayDone;

  /// No description provided for @homeLoggedSnackCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Logged 1 puff} other{Logged {count} puffs}}'**
  String homeLoggedSnackCount(num count);

  /// No description provided for @homeOverLimitTitle.
  ///
  /// In en, this message translates to:
  /// **'Over today\'s line'**
  String get homeOverLimitTitle;

  /// No description provided for @homeOverLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Breathe — tomorrow\'s line adjusts. No shame.'**
  String get homeOverLimitBody;

  /// No description provided for @homeOverLimitBreathe.
  ///
  /// In en, this message translates to:
  /// **'Breathe 60s'**
  String get homeOverLimitBreathe;

  /// No description provided for @homeOverLimitCoach.
  ///
  /// In en, this message translates to:
  /// **'Talk to coach'**
  String get homeOverLimitCoach;

  /// No description provided for @homeOverLimitFooter.
  ///
  /// In en, this message translates to:
  /// **'Keep logging honestly — the data is the whole game.'**
  String get homeOverLimitFooter;

  /// No description provided for @homeTokenUsedNote.
  ///
  /// In en, this message translates to:
  /// **'Repair token used — your streak survives. Flame dims today, not out.'**
  String get homeTokenUsedNote;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get navStats;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navCoach.
  ///
  /// In en, this message translates to:
  /// **'Coach'**
  String get navCoach;

  /// No description provided for @panicStepLabel.
  ///
  /// In en, this message translates to:
  /// **'PANIC MODE · {step} OF 3'**
  String panicStepLabel(int step);

  /// No description provided for @panicBreatheNote.
  ///
  /// In en, this message translates to:
  /// **'this feeling peaks and passes — most cravings die in 15 min'**
  String get panicBreatheNote;

  /// No description provided for @panicBreatheInstruction.
  ///
  /// In en, this message translates to:
  /// **'Breathe with the circle.'**
  String get panicBreatheInstruction;

  /// No description provided for @panicBreatheIn.
  ///
  /// In en, this message translates to:
  /// **'Breathe in'**
  String get panicBreatheIn;

  /// No description provided for @panicBreatheHold.
  ///
  /// In en, this message translates to:
  /// **'Hold'**
  String get panicBreatheHold;

  /// No description provided for @panicBreatheOut.
  ///
  /// In en, this message translates to:
  /// **'Breathe out'**
  String get panicBreatheOut;

  /// No description provided for @panicBreathePattern.
  ///
  /// In en, this message translates to:
  /// **'In 4 · Hold 7 · Out 8'**
  String get panicBreathePattern;

  /// No description provided for @panicCravingTimer.
  ///
  /// In en, this message translates to:
  /// **'craving timer · {time} · peaks ~15 min'**
  String panicCravingTimer(String time);

  /// No description provided for @panicCravingTimerLate.
  ///
  /// In en, this message translates to:
  /// **'craving timer · {time} · you\'re past the worst spike'**
  String panicCravingTimerLate(String time);

  /// No description provided for @panicSkipToWhy.
  ///
  /// In en, this message translates to:
  /// **'Skip to my why →'**
  String get panicSkipToWhy;

  /// No description provided for @panicWhyTitle.
  ///
  /// In en, this message translates to:
  /// **'Remember why you started.'**
  String get panicWhyTitle;

  /// No description provided for @panicYouSaid.
  ///
  /// In en, this message translates to:
  /// **'YOU SAID'**
  String get panicYouSaid;

  /// No description provided for @panicWhyLine.
  ///
  /// In en, this message translates to:
  /// **'You\'re doing this for your {why} and the {amount}/year you\'re taking back.'**
  String panicWhyLine(String why, String amount);

  /// No description provided for @panicIntensityQuestion.
  ///
  /// In en, this message translates to:
  /// **'How bad is it right now?'**
  String get panicIntensityQuestion;

  /// No description provided for @panicIntensityLow.
  ///
  /// In en, this message translates to:
  /// **'meh'**
  String get panicIntensityLow;

  /// No description provided for @panicIntensityHigh.
  ///
  /// In en, this message translates to:
  /// **'screaming'**
  String get panicIntensityHigh;

  /// No description provided for @panicStillCraving.
  ///
  /// In en, this message translates to:
  /// **'Still craving — next'**
  String get panicStillCraving;

  /// No description provided for @panicItPassed.
  ///
  /// In en, this message translates to:
  /// **'It passed 🎉 I\'m good'**
  String get panicItPassed;

  /// No description provided for @panicLoopTitle.
  ///
  /// In en, this message translates to:
  /// **'Break the loop.'**
  String get panicLoopTitle;

  /// No description provided for @panicLoopSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your hands and brain need a job for 60 seconds. Pick one.'**
  String get panicLoopSubtitle;

  /// No description provided for @panicLoopGame.
  ///
  /// In en, this message translates to:
  /// **'Play for a minute'**
  String get panicLoopGame;

  /// No description provided for @panicLoopGameSub.
  ///
  /// In en, this message translates to:
  /// **'Tiles, Blocks or Orbs — thumbs busy, brain busy'**
  String get panicLoopGameSub;

  /// No description provided for @panicLoopSos.
  ///
  /// In en, this message translates to:
  /// **'Ask the community'**
  String get panicLoopSos;

  /// No description provided for @panicLoopSosSub.
  ///
  /// In en, this message translates to:
  /// **'post an SOS — it pins to the top for an hour'**
  String get panicLoopSosSub;

  /// No description provided for @panicLoopCoach.
  ///
  /// In en, this message translates to:
  /// **'Talk to coach'**
  String get panicLoopCoach;

  /// No description provided for @panicLoopCoachSub.
  ///
  /// In en, this message translates to:
  /// **'it knows this is your {hour} stress pattern'**
  String panicLoopCoachSub(String hour);

  /// No description provided for @panicLoopCoachLocked.
  ///
  /// In en, this message translates to:
  /// **'you\'ve used today\'s free AI session'**
  String get panicLoopCoachLocked;

  /// No description provided for @gameTitle.
  ///
  /// In en, this message translates to:
  /// **'Crowd the craving out.'**
  String get gameTitle;

  /// No description provided for @gameTimeLeft.
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String gameTimeLeft(int seconds);

  /// No description provided for @gameNewBest.
  ///
  /// In en, this message translates to:
  /// **'new best'**
  String get gameNewBest;

  /// No description provided for @gameAnotherRound.
  ///
  /// In en, this message translates to:
  /// **'Still craving — 60 more seconds'**
  String get gameAnotherRound;

  /// No description provided for @gameWhy.
  ///
  /// In en, this message translates to:
  /// **'A craving is mostly a picture in your head. Fill the space for a few minutes and it has less room to grow.'**
  String get gameWhy;

  /// No description provided for @gameNameTiles.
  ///
  /// In en, this message translates to:
  /// **'Tiles'**
  String get gameNameTiles;

  /// No description provided for @gameNameBlocks.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get gameNameBlocks;

  /// No description provided for @gameNameOrbs.
  ///
  /// In en, this message translates to:
  /// **'Orbs'**
  String get gameNameOrbs;

  /// No description provided for @gameHintTiles.
  ///
  /// In en, this message translates to:
  /// **'Tap the bottom tile in its lane.'**
  String get gameHintTiles;

  /// No description provided for @gameHintBlocks.
  ///
  /// In en, this message translates to:
  /// **'Drag to move · tap to turn · flick down to drop'**
  String get gameHintBlocks;

  /// No description provided for @gameHintOrbs.
  ///
  /// In en, this message translates to:
  /// **'A few orbs glow. Keep your eyes on them as they move, then tap them.'**
  String get gameHintOrbs;

  /// No description provided for @orbsCue.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Remember this one} other{Remember these {count}}}'**
  String orbsCue(int count);

  /// No description provided for @orbsCueSub.
  ///
  /// In en, this message translates to:
  /// **'They go grey in a moment — keep your eyes on them'**
  String get orbsCueSub;

  /// No description provided for @orbsTrack.
  ///
  /// In en, this message translates to:
  /// **'Keep your eyes on them'**
  String get orbsTrack;

  /// No description provided for @orbsTrackSub.
  ///
  /// In en, this message translates to:
  /// **'The ring is coming'**
  String get orbsTrackSub;

  /// No description provided for @orbsPick.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Tap the one you followed} other{Tap the {count} you followed}}'**
  String orbsPick(int count);

  /// No description provided for @orbsProgress.
  ///
  /// In en, this message translates to:
  /// **'{found} of {count}'**
  String orbsProgress(int found, int count);

  /// No description provided for @orbsPerfect.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Got it — perfect} other{All {count} — perfect}}'**
  String orbsPerfect(int count);

  /// No description provided for @orbsRevealSub.
  ///
  /// In en, this message translates to:
  /// **'These were the ones'**
  String get orbsRevealSub;

  /// No description provided for @gameUnitTiles.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 tile} other{{count} tiles}}'**
  String gameUnitTiles(int count);

  /// No description provided for @gameUnitBlocks.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 line} other{{count} lines}}'**
  String gameUnitBlocks(int count);

  /// No description provided for @gameUnitOrbs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 orb} other{{count} orbs}}'**
  String gameUnitOrbs(int count);

  /// No description provided for @gameMinutesDone.
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{60 seconds done.} other{{minutes} minutes done.}}'**
  String gameMinutesDone(int minutes);

  /// No description provided for @gameDoseDone.
  ///
  /// In en, this message translates to:
  /// **'Three minutes — the full dose.'**
  String get gameDoseDone;

  /// No description provided for @gameResearchNote.
  ///
  /// In en, this message translates to:
  /// **'In a week-long study, three minutes of a visual game cut cravings by about a fifth.'**
  String get gameResearchNote;

  /// No description provided for @gameIntensityNow.
  ///
  /// In en, this message translates to:
  /// **'How bad is it now?'**
  String get gameIntensityNow;

  /// No description provided for @gameCapLine.
  ///
  /// In en, this message translates to:
  /// **'That\'s five minutes of your own attention. Pick what\'s next.'**
  String get gameCapLine;

  /// No description provided for @gameCapTryElse.
  ///
  /// In en, this message translates to:
  /// **'Try another way'**
  String get gameCapTryElse;

  /// No description provided for @gamePaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get gamePaused;

  /// No description provided for @gamePausedTap.
  ///
  /// In en, this message translates to:
  /// **'Tap to keep going'**
  String get gamePausedTap;

  /// No description provided for @survivedPlusOne.
  ///
  /// In en, this message translates to:
  /// **'+1 craving beaten'**
  String get survivedPlusOne;

  /// No description provided for @survivedLine1.
  ///
  /// In en, this message translates to:
  /// **'That one had nothing on you.'**
  String get survivedLine1;

  /// No description provided for @survivedLine2.
  ///
  /// In en, this message translates to:
  /// **'The wave broke. You didn\'t.'**
  String get survivedLine2;

  /// No description provided for @survivedLine3.
  ///
  /// In en, this message translates to:
  /// **'15 minutes of brave. Banked forever.'**
  String get survivedLine3;

  /// No description provided for @survivedLine4.
  ///
  /// In en, this message translates to:
  /// **'Your brain just learned who\'s boss.'**
  String get survivedLine4;

  /// No description provided for @survivedLine5.
  ///
  /// In en, this message translates to:
  /// **'Craving 0 — you 1. Again.'**
  String get survivedLine5;

  /// No description provided for @survivedLine6.
  ///
  /// In en, this message translates to:
  /// **'Still free. Still going.'**
  String get survivedLine6;

  /// No description provided for @survivedLine7.
  ///
  /// In en, this message translates to:
  /// **'That itch just paid your future self.'**
  String get survivedLine7;

  /// No description provided for @survivedLine8.
  ///
  /// In en, this message translates to:
  /// **'Cold-blooded. In the best way.'**
  String get survivedLine8;

  /// No description provided for @survivedTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'cravings survived total'**
  String get survivedTotalLabel;

  /// No description provided for @survivedGameNewBest.
  ///
  /// In en, this message translates to:
  /// **'NEW BEST'**
  String get survivedGameNewBest;

  /// No description provided for @survivedGameBest.
  ///
  /// In en, this message translates to:
  /// **'best {best}'**
  String survivedGameBest(int best);

  /// No description provided for @survivedIntensityDrop.
  ///
  /// In en, this message translates to:
  /// **'You said {before}/10 — now {after}/10.'**
  String survivedIntensityDrop(int before, int after);

  /// No description provided for @survivedShare.
  ///
  /// In en, this message translates to:
  /// **'Share the W ↗'**
  String get survivedShare;

  /// No description provided for @survivedBack.
  ///
  /// In en, this message translates to:
  /// **'Back to today'**
  String get survivedBack;

  /// No description provided for @survivedShareCopied.
  ///
  /// In en, this message translates to:
  /// **'Stat card copied — paste it anywhere.'**
  String get survivedShareCopied;

  /// No description provided for @coachName.
  ///
  /// In en, this message translates to:
  /// **'Ember'**
  String get coachName;

  /// No description provided for @coachStatus.
  ///
  /// In en, this message translates to:
  /// **'● knows your plan · day {day}'**
  String coachStatus(int day);

  /// No description provided for @coachChipCraving.
  ///
  /// In en, this message translates to:
  /// **'I\'m craving'**
  String get coachChipCraving;

  /// No description provided for @coachChipRoughDay.
  ///
  /// In en, this message translates to:
  /// **'Rough day'**
  String get coachChipRoughDay;

  /// No description provided for @coachChipSlipped.
  ///
  /// In en, this message translates to:
  /// **'I slipped'**
  String get coachChipSlipped;

  /// No description provided for @coachChipProgress.
  ///
  /// In en, this message translates to:
  /// **'Show my progress'**
  String get coachChipProgress;

  /// No description provided for @coachInputHint.
  ///
  /// In en, this message translates to:
  /// **'Message your coach…'**
  String get coachInputHint;

  /// No description provided for @coachTyping.
  ///
  /// In en, this message translates to:
  /// **'{name} is typing…'**
  String coachTyping(String name);

  /// No description provided for @coachTimeYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday · {time}'**
  String coachTimeYesterday(String time);

  /// No description provided for @coachFreeCounter.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} free message left today} other{{count} free messages left today}}'**
  String coachFreeCounter(num count);

  /// No description provided for @coachCapReached.
  ///
  /// In en, this message translates to:
  /// **'That\'s my 5 free messages for today — I\'ll be back at midnight. Want me around 24/7? That\'s what Premium is.'**
  String get coachCapReached;

  /// No description provided for @coachConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Signal dropped mid-thought 😅 I\'m still right here — say that again once you\'re back online?'**
  String get coachConnectionLost;

  /// No description provided for @coachBackendRejected.
  ///
  /// In en, this message translates to:
  /// **'Okay, that\'s on our end — the server didn\'t recognise this app, so I never got your message. Not your connection, not you. We\'re on it.'**
  String get coachBackendRejected;

  /// No description provided for @errorOfflineBanner.
  ///
  /// In en, this message translates to:
  /// **'offline — logs still count, we\'ll sync later'**
  String get errorOfflineBanner;

  /// No description provided for @errorOfflineTitle.
  ///
  /// In en, this message translates to:
  /// **'No wifi, no worries'**
  String get errorOfflineTitle;

  /// No description provided for @errorOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline right now. Nothing\'s lost — reconnect and we\'ll pick up right where you left off.'**
  String get errorOfflineBody;

  /// No description provided for @errorGenericTitle.
  ///
  /// In en, this message translates to:
  /// **'Well, that glitched'**
  String get errorGenericTitle;

  /// No description provided for @errorGenericBody.
  ///
  /// In en, this message translates to:
  /// **'That one\'s on us, not you. Give it another shot in a sec.'**
  String get errorGenericBody;

  /// No description provided for @errorPurchaseNotAllowedTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchases are off on this device'**
  String get errorPurchaseNotAllowedTitle;

  /// No description provided for @errorPurchaseNotAllowedBody.
  ///
  /// In en, this message translates to:
  /// **'This device or account can\'t buy subscriptions right now — usually parental controls or a store restriction. Nothing was charged.'**
  String get errorPurchaseNotAllowedBody;

  /// No description provided for @errorStoreTitle.
  ///
  /// In en, this message translates to:
  /// **'The store didn\'t answer'**
  String get errorStoreTitle;

  /// No description provided for @errorStoreBody.
  ///
  /// In en, this message translates to:
  /// **'Google Play or the App Store had a moment. Nothing was charged — try again in a minute.'**
  String get errorStoreBody;

  /// No description provided for @errorReceiptOwnedTitle.
  ///
  /// In en, this message translates to:
  /// **'That subscription belongs to another account'**
  String get errorReceiptOwnedTitle;

  /// No description provided for @errorReceiptOwnedBody.
  ///
  /// In en, this message translates to:
  /// **'This store account\'s subscription is linked to a different Cirrus sign-in. Sign in there, or restore from that account.'**
  String get errorReceiptOwnedBody;

  /// No description provided for @errorRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'This build got bounced'**
  String get errorRejectedTitle;

  /// No description provided for @errorRejectedBody.
  ///
  /// In en, this message translates to:
  /// **'Your connection is fine — our end just didn\'t recognise this app. Nothing you can fix, and nothing you logged is lost.'**
  String get errorRejectedBody;

  /// No description provided for @errorRetry.
  ///
  /// In en, this message translates to:
  /// **'Run it back'**
  String get errorRetry;

  /// No description provided for @errorGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get errorGotIt;

  /// No description provided for @errorFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'The feed ghosted us'**
  String get errorFeedTitle;

  /// No description provided for @errorFeedBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the community. Check your signal and run it back.'**
  String get errorFeedBody;

  /// No description provided for @errorRouteTitle.
  ///
  /// In en, this message translates to:
  /// **'This page doesn\'t exist'**
  String get errorRouteTitle;

  /// No description provided for @errorRouteBody.
  ///
  /// In en, this message translates to:
  /// **'Whatever you were looking for, it\'s not here. Let\'s get you back on track.'**
  String get errorRouteBody;

  /// No description provided for @errorRouteCta.
  ///
  /// In en, this message translates to:
  /// **'Take me home'**
  String get errorRouteCta;

  /// No description provided for @errorBackstage.
  ///
  /// In en, this message translates to:
  /// **'something glitched backstage — you\'re all good to keep going'**
  String get errorBackstage;

  /// No description provided for @coachWeekCardLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR WEEK'**
  String get coachWeekCardLabel;

  /// No description provided for @coachWeekCardCaption.
  ///
  /// In en, this message translates to:
  /// **'trending down — {day} was the hard one'**
  String coachWeekCardCaption(String day);

  /// No description provided for @coachGreeting.
  ///
  /// In en, this message translates to:
  /// **'Hey. I\'m {name} — I quit two years ago and I remember exactly how it felt. I\'ve read your plan: {puffs} a day, {method}, Freedom Day {date}. No lectures from me, ever. What\'s going on right now?'**
  String coachGreeting(String name, int puffs, String method, String date);

  /// No description provided for @coachReplyCraving1.
  ///
  /// In en, this message translates to:
  /// **'That wave is brutal, I know. 15 minutes and it breaks — that\'s not a pep talk, it\'s biology. Cold water on your wrists, and stay with me. What set it off?'**
  String get coachReplyCraving1;

  /// No description provided for @coachReplyCraving2.
  ///
  /// In en, this message translates to:
  /// **'Okay. Breathe with me for one round — in 4, hold 7, out 8. Cravings usually die in 15–20 minutes. You\'ve already beaten {count} of them. This one\'s no different.'**
  String coachReplyCraving2(int count);

  /// No description provided for @coachReplyCraving3.
  ///
  /// In en, this message translates to:
  /// **'Heard. Don\'t argue with the craving, just outlast it. Walk one block or hit the 60-second game. It peaks and dies — 15 minutes, tops.'**
  String get coachReplyCraving3;

  /// No description provided for @coachReplyRough1.
  ///
  /// In en, this message translates to:
  /// **'Fair. Rough days are when the old habit shouts loudest. Deal: 10-min walk before the next one. If you still want it after, log it honestly — you\'re still {percent}% under your old baseline.'**
  String coachReplyRough1(int percent);

  /// No description provided for @coachReplyRough2.
  ///
  /// In en, this message translates to:
  /// **'That sounds heavy. You don\'t have to fix today, just get through it — and you\'re allowed to do that without nicotine. I\'m here either way.'**
  String get coachReplyRough2;

  /// No description provided for @coachReplySlip1.
  ///
  /// In en, this message translates to:
  /// **'A slip is data, not defeat. What set it off — stress, people, boredom? The plan already bent to catch you. Your {count} days still count.'**
  String coachReplySlip1(int count);

  /// No description provided for @coachReplySlip2.
  ///
  /// In en, this message translates to:
  /// **'Zero shame here. Most people who quit for good slipped on the way. Log it honestly, find the trigger, move on. Your record is still yours: {amount} saved, longest streak intact.'**
  String coachReplySlip2(String amount);

  /// No description provided for @coachReplyProgress1.
  ///
  /// In en, this message translates to:
  /// **'Look at the actual numbers: day {day}, {saved} back in your pocket, {cravings} cravings beaten. Day 1 you couldn\'t have done today. That\'s real.'**
  String coachReplyProgress1(int day, String saved, int cravings);

  /// No description provided for @coachReplyProgress2.
  ///
  /// In en, this message translates to:
  /// **'{today} puffs today against a line of {limit}. Every one you skip is in the log now, and the log is what bends the curve. You\'re actually doing this.'**
  String coachReplyProgress2(int today, int limit);

  /// No description provided for @coachReplyGeneric1.
  ///
  /// In en, this message translates to:
  /// **'I hear you. Say more — what\'s underneath that?'**
  String get coachReplyGeneric1;

  /// No description provided for @coachReplyGeneric2.
  ///
  /// In en, this message translates to:
  /// **'Makes sense. For what it\'s worth, you\'re on day {day} and still here. That counts for a lot.'**
  String coachReplyGeneric2(int day);

  /// No description provided for @coachReplyGeneric3.
  ///
  /// In en, this message translates to:
  /// **'Got it. One honest question: is this a nicotine thing right now, or a life thing wearing nicotine\'s jacket?'**
  String get coachReplyGeneric3;

  /// No description provided for @coachReplyGeneric4.
  ///
  /// In en, this message translates to:
  /// **'Okay. Small moves win this. What\'s one thing you can do in the next 10 minutes that isn\'t vaping?'**
  String get coachReplyGeneric4;

  /// No description provided for @coachReplyParty.
  ///
  /// In en, this message translates to:
  /// **'Party playbook: hold a cold drink all night, text me or your buddy when the first vape comes out, and pre-load your exit line. You\'ve survived {count} cravings — a party is just several in a row.'**
  String coachReplyParty(int count);

  /// No description provided for @coachSafetyNote.
  ///
  /// In en, this message translates to:
  /// **'{name} is a support tool, not a doctor. In crisis? Call or text 988 (US & Canada), any time.'**
  String coachSafetyNote(String name);

  /// No description provided for @planTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan'**
  String get planTitle;

  /// No description provided for @planHeaderMeta.
  ///
  /// In en, this message translates to:
  /// **'{method} · {days} days'**
  String planHeaderMeta(String method, int days);

  /// No description provided for @planMethodTaper.
  ///
  /// In en, this message translates to:
  /// **'Taper'**
  String get planMethodTaper;

  /// No description provided for @planMethodCold.
  ///
  /// In en, this message translates to:
  /// **'Cold turkey'**
  String get planMethodCold;

  /// No description provided for @planTodayMarker.
  ///
  /// In en, this message translates to:
  /// **'today · {limit}/day'**
  String planTodayMarker(int limit);

  /// No description provided for @planFreedomMarker.
  ///
  /// In en, this message translates to:
  /// **'{date} · 0'**
  String planFreedomMarker(String date);

  /// No description provided for @planComingUp.
  ///
  /// In en, this message translates to:
  /// **'COMING UP'**
  String get planComingUp;

  /// No description provided for @planHalfwayTitle.
  ///
  /// In en, this message translates to:
  /// **'Day {day} — halfway'**
  String planHalfwayTitle(int day);

  /// No description provided for @planHalfwaySub.
  ///
  /// In en, this message translates to:
  /// **'line drops to {limit}/day'**
  String planHalfwaySub(int limit);

  /// No description provided for @planCravingsFadeTitle.
  ///
  /// In en, this message translates to:
  /// **'Day {day} — cravings fade'**
  String planCravingsFadeTitle(int day);

  /// No description provided for @planCravingsFadeSub.
  ///
  /// In en, this message translates to:
  /// **'most report easier mornings'**
  String get planCravingsFadeSub;

  /// No description provided for @planFreedomTitle.
  ///
  /// In en, this message translates to:
  /// **'Day {day} — Freedom Day'**
  String planFreedomTitle(int day);

  /// No description provided for @planAdjustCta.
  ///
  /// In en, this message translates to:
  /// **'Adjust my plan'**
  String get planAdjustCta;

  /// No description provided for @planAdjustNote.
  ///
  /// In en, this message translates to:
  /// **'pace + method editable · no reset, no lost history'**
  String get planAdjustNote;

  /// No description provided for @planAdaptiveLabel.
  ///
  /// In en, this message translates to:
  /// **'TONIGHT\'S ADJUSTMENT'**
  String get planAdaptiveLabel;

  /// No description provided for @planAdaptiveCrushing.
  ///
  /// In en, this message translates to:
  /// **'You came in under your line three days running, so today\'s target drops to {limit}. Momentum, not punishment.'**
  String planAdaptiveCrushing(int limit);

  /// No description provided for @planAdaptiveOnTrack.
  ///
  /// In en, this message translates to:
  /// **'You\'re holding the line. Today\'s target stays at {limit}.'**
  String planAdaptiveOnTrack(int limit);

  /// No description provided for @planAdaptiveStruggling.
  ///
  /// In en, this message translates to:
  /// **'The last two days ran over, so today\'s target bends to {limit}. A line you can actually hold beats a line you can\'t.'**
  String planAdaptiveStruggling(int limit);

  /// No description provided for @planAdaptiveStretched.
  ///
  /// In en, this message translates to:
  /// **'Freedom Day moved back a day to match.'**
  String get planAdaptiveStretched;

  /// No description provided for @planAdjustSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust your plan'**
  String get planAdjustSheetTitle;

  /// No description provided for @planAdjustSheetNote.
  ///
  /// In en, this message translates to:
  /// **'Curve regenerates from today with your real numbers. History stays. Freedom Day moves honestly.'**
  String get planAdjustSheetNote;

  /// No description provided for @planAdjustApply.
  ///
  /// In en, this message translates to:
  /// **'Apply — reflow my curve'**
  String get planAdjustApply;

  /// No description provided for @planAdjusted.
  ///
  /// In en, this message translates to:
  /// **'Plan reflowed. New Freedom Day: {date}'**
  String planAdjusted(String date);

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statsTitle;

  /// No description provided for @statsRangeDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statsRangeDay;

  /// No description provided for @statsRangeWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statsRangeWeek;

  /// No description provided for @statsRangeMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statsRangeMonth;

  /// No description provided for @statsPuffsThisWeek.
  ///
  /// In en, this message translates to:
  /// **'PUFFS THIS WEEK'**
  String get statsPuffsThisWeek;

  /// No description provided for @statsPuffsToday.
  ///
  /// In en, this message translates to:
  /// **'PUFFS TODAY · BY HOUR'**
  String get statsPuffsToday;

  /// No description provided for @statsPuffsThisMonth.
  ///
  /// In en, this message translates to:
  /// **'PUFFS · LAST 30 DAYS'**
  String get statsPuffsThisMonth;

  /// No description provided for @statsVsLast.
  ///
  /// In en, this message translates to:
  /// **'{percent} vs last'**
  String statsVsLast(String percent);

  /// No description provided for @statsHardDayCaption.
  ///
  /// In en, this message translates to:
  /// **'{day} was the difficult day — {reason}. You recovered next morning.'**
  String statsHardDayCaption(String day, String reason);

  /// No description provided for @statsHardDayCaptionPlain.
  ///
  /// In en, this message translates to:
  /// **'{day} was the difficult day. You recovered next morning.'**
  String statsHardDayCaptionPlain(String day);

  /// No description provided for @statsWindowNoPuffs.
  ///
  /// In en, this message translates to:
  /// **'no puffs logged in this window'**
  String get statsWindowNoPuffs;

  /// No description provided for @statsTriggerHours.
  ///
  /// In en, this message translates to:
  /// **'TRIGGER HOURS'**
  String get statsTriggerHours;

  /// No description provided for @statsDangerWindow.
  ///
  /// In en, this message translates to:
  /// **'{range} is your danger window · nudges armed there'**
  String statsDangerWindow(String range);

  /// No description provided for @statsNicotinePerDay.
  ///
  /// In en, this message translates to:
  /// **'NICOTINE / DAY'**
  String get statsNicotinePerDay;

  /// No description provided for @statsNicotineValue.
  ///
  /// In en, this message translates to:
  /// **'{mg}mg ↓'**
  String statsNicotineValue(int mg);

  /// No description provided for @statsLongestGap.
  ///
  /// In en, this message translates to:
  /// **'longest gap'**
  String get statsLongestGap;

  /// No description provided for @statsBestDay.
  ///
  /// In en, this message translates to:
  /// **'best day (puffs)'**
  String get statsBestDay;

  /// No description provided for @statsCravingsBeaten.
  ///
  /// In en, this message translates to:
  /// **'cravings beaten'**
  String get statsCravingsBeaten;

  /// No description provided for @statsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Charts show up tomorrow.'**
  String get statsEmptyTitle;

  /// No description provided for @statsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'One day of logs = one dot. Keep logging — the picture draws itself.'**
  String get statsEmptyBody;

  /// No description provided for @statsEditDayTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {date}'**
  String statsEditDayTitle(String date);

  /// No description provided for @statsEditDayNote.
  ///
  /// In en, this message translates to:
  /// **'History is yours. Streak and money recompute from here forward.'**
  String get statsEditDayNote;

  /// No description provided for @statsEditHint.
  ///
  /// In en, this message translates to:
  /// **'long-press any bar to fix a day'**
  String get statsEditHint;

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// No description provided for @communityYouAre.
  ///
  /// In en, this message translates to:
  /// **'you\'re {alias}'**
  String communityYouAre(String alias);

  /// No description provided for @communityFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get communityFilterAll;

  /// No description provided for @communityTagWin.
  ///
  /// In en, this message translates to:
  /// **'🏆 Win'**
  String get communityTagWin;

  /// No description provided for @communityTagSos.
  ///
  /// In en, this message translates to:
  /// **'🆘 SOS'**
  String get communityTagSos;

  /// No description provided for @communityTagDay1.
  ///
  /// In en, this message translates to:
  /// **'Day 1'**
  String get communityTagDay1;

  /// No description provided for @communityTagMilestone.
  ///
  /// In en, this message translates to:
  /// **'Milestone'**
  String get communityTagMilestone;

  /// No description provided for @communityTagVent.
  ///
  /// In en, this message translates to:
  /// **'Vent'**
  String get communityTagVent;

  /// No description provided for @communityIGotYou.
  ///
  /// In en, this message translates to:
  /// **'I got you 💬'**
  String get communityIGotYou;

  /// No description provided for @communityRepliedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} already replied'**
  String communityRepliedCount(int count);

  /// No description provided for @communityReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get communityReport;

  /// No description provided for @communityMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get communityMute;

  /// No description provided for @communityBlock.
  ///
  /// In en, this message translates to:
  /// **'Block user'**
  String get communityBlock;

  /// No description provided for @communityReported.
  ///
  /// In en, this message translates to:
  /// **'Reported. We review within 24h — 3 reports auto-hide a post.'**
  String get communityReported;

  /// No description provided for @communityBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked. You won\'t see each other anymore.'**
  String get communityBlocked;

  /// No description provided for @communityMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted. You won\'t see their posts anymore.'**
  String get communityMuted;

  /// No description provided for @communityComposerTitle.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get communityComposerTitle;

  /// No description provided for @communityComposerPost.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get communityComposerPost;

  /// No description provided for @communityPostingAs.
  ///
  /// In en, this message translates to:
  /// **'posting as {alias} · day {day} · always anonymous'**
  String communityPostingAs(String alias, int day);

  /// No description provided for @communityComposerHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening in your quit?'**
  String get communityComposerHint;

  /// No description provided for @communityTagIt.
  ///
  /// In en, this message translates to:
  /// **'TAG IT'**
  String get communityTagIt;

  /// No description provided for @communityKindnessNote.
  ///
  /// In en, this message translates to:
  /// **'Be kind — everyone here is mid-fight. No brand names, no where-to-buy.'**
  String get communityKindnessNote;

  /// No description provided for @communityRuleSlur.
  ///
  /// In en, this message translates to:
  /// **'This can\'t be posted — slurs and hate aren\'t allowed here.'**
  String get communityRuleSlur;

  /// No description provided for @communityRuleSourcing.
  ///
  /// In en, this message translates to:
  /// **'Where-to-buy and for-sale talk isn\'t allowed here. Edit it and try again.'**
  String get communityRuleSourcing;

  /// No description provided for @communityDailyCapReached.
  ///
  /// In en, this message translates to:
  /// **'That\'s 3 posts today — the cap resets at midnight.'**
  String get communityDailyCapReached;

  /// No description provided for @communityTagRequired.
  ///
  /// In en, this message translates to:
  /// **'Pick a tag — it routes your post to the right people.'**
  String get communityTagRequired;

  /// No description provided for @communitySosBanner.
  ///
  /// In en, this message translates to:
  /// **'🛡️ {count} people had your back'**
  String communitySosBanner(int count);

  /// No description provided for @communityAddVoice.
  ///
  /// In en, this message translates to:
  /// **'Add your voice…'**
  String get communityAddVoice;

  /// No description provided for @communityDayTag.
  ///
  /// In en, this message translates to:
  /// **'day {day}'**
  String communityDayTag(int day);

  /// No description provided for @communityEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No posts yet — say hi.'**
  String get communityEmptyTitle;

  /// No description provided for @communityEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Your Day 1 post is the one someone on Day 0 needs to read.'**
  String get communityEmptyBody;

  /// No description provided for @communityPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted. A quick safety check runs before others can see it.'**
  String get communityPosted;

  /// No description provided for @communityStatusHeld.
  ///
  /// In en, this message translates to:
  /// **'In review — only you can see this for now'**
  String get communityStatusHeld;

  /// No description provided for @communityStatusBlocked.
  ///
  /// In en, this message translates to:
  /// **'Not published — it didn\'t clear the community rules'**
  String get communityStatusBlocked;

  /// No description provided for @communityStatusPosting.
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get communityStatusPosting;

  /// No description provided for @communityStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t send — tap to retry'**
  String get communityStatusFailed;

  /// No description provided for @communityStatusCapped.
  ///
  /// In en, this message translates to:
  /// **'Not posted — that\'s 3 today. The cap resets at midnight.'**
  String get communityStatusCapped;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied — quitting hits different with backup.'**
  String get linkCopied;

  /// No description provided for @moneyTitle.
  ///
  /// In en, this message translates to:
  /// **'Money back'**
  String get moneyTitle;

  /// No description provided for @moneySavedSince.
  ///
  /// In en, this message translates to:
  /// **'saved since {date} · {perDay} rolling in daily'**
  String moneySavedSince(String date, String perDay);

  /// No description provided for @moneyBuysLabel.
  ///
  /// In en, this message translates to:
  /// **'WHAT IT ALREADY BUYS'**
  String get moneyBuysLabel;

  /// No description provided for @moneyToGo.
  ///
  /// In en, this message translates to:
  /// **'{amount} to go · ~{days} days at your pace'**
  String moneyToGo(String amount, int days);

  /// No description provided for @moneyToGoShort.
  ///
  /// In en, this message translates to:
  /// **'{amount} to go'**
  String moneyToGoShort(String amount);

  /// No description provided for @moneyFromOnboarding.
  ///
  /// In en, this message translates to:
  /// **'the one from onboarding · {amount} to go'**
  String moneyFromOnboarding(String amount);

  /// No description provided for @moneySetGoal.
  ///
  /// In en, this message translates to:
  /// **'Set a goal'**
  String get moneySetGoal;

  /// No description provided for @moneySetGoalSub.
  ///
  /// In en, this message translates to:
  /// **'name it, price it, watch the bar fill'**
  String get moneySetGoalSub;

  /// No description provided for @moneyGoalSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'New savings goal'**
  String get moneyGoalSheetTitle;

  /// No description provided for @moneyGoalNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name it — \"PS5\", \"Lisbon\", \"drum kit\"'**
  String get moneyGoalNameHint;

  /// No description provided for @moneyGoalPriceHint.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get moneyGoalPriceHint;

  /// No description provided for @moneyGoalCreate.
  ///
  /// In en, this message translates to:
  /// **'Start the bar'**
  String get moneyGoalCreate;

  /// No description provided for @moneyMathNote.
  ///
  /// In en, this message translates to:
  /// **'Math is yours: {weekly}/week × 52 = {yearly}/year. No invented numbers.'**
  String moneyMathNote(String weekly, String yearly);

  /// No description provided for @moneyGoalDone.
  ///
  /// In en, this message translates to:
  /// **'Goal funded. Confetti earned. 🎉'**
  String get moneyGoalDone;

  /// No description provided for @seedGoalKicks.
  ///
  /// In en, this message translates to:
  /// **'New kicks'**
  String get seedGoalKicks;

  /// No description provided for @seedGoalTokyo.
  ///
  /// In en, this message translates to:
  /// **'Tokyo flight'**
  String get seedGoalTokyo;

  /// No description provided for @healthTitle.
  ///
  /// In en, this message translates to:
  /// **'Your body, healing'**
  String get healthTitle;

  /// No description provided for @healthAnchor.
  ///
  /// In en, this message translates to:
  /// **'Based on your last logged puff · {ago} ago'**
  String healthAnchor(String ago);

  /// No description provided for @healthYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'{milestone} — you are here'**
  String healthYouAreHere(String milestone);

  /// No description provided for @healthM20min.
  ///
  /// In en, this message translates to:
  /// **'20 minutes'**
  String get healthM20min;

  /// No description provided for @healthM20minBody.
  ///
  /// In en, this message translates to:
  /// **'Heart rate and blood pressure drop back to normal.'**
  String get healthM20minBody;

  /// No description provided for @healthM8h.
  ///
  /// In en, this message translates to:
  /// **'8 hours'**
  String get healthM8h;

  /// No description provided for @healthM8hBody.
  ///
  /// In en, this message translates to:
  /// **'Oxygen levels normalize as nicotine fades.'**
  String get healthM8hBody;

  /// No description provided for @healthM12h.
  ///
  /// In en, this message translates to:
  /// **'12 hours'**
  String get healthM12h;

  /// No description provided for @healthM12hBody.
  ///
  /// In en, this message translates to:
  /// **'Carbon monoxide in your blood drops to normal.'**
  String get healthM12hBody;

  /// No description provided for @healthM24h.
  ///
  /// In en, this message translates to:
  /// **'24 hours'**
  String get healthM24h;

  /// No description provided for @healthM24hBody.
  ///
  /// In en, this message translates to:
  /// **'Nicotine is dropping fast. Cravings get loud — that\'s the exit door.'**
  String get healthM24hBody;

  /// No description provided for @healthM48h.
  ///
  /// In en, this message translates to:
  /// **'48 hours'**
  String get healthM48h;

  /// No description provided for @healthM48hBody.
  ///
  /// In en, this message translates to:
  /// **'Nerve endings start regrowing. Taste and smell sharpen.'**
  String get healthM48hBody;

  /// No description provided for @healthM72h.
  ///
  /// In en, this message translates to:
  /// **'72 hours'**
  String get healthM72h;

  /// No description provided for @healthM72hBody.
  ///
  /// In en, this message translates to:
  /// **'Nicotine is ~gone. Cravings peak — Panic Button lives for this.'**
  String get healthM72hBody;

  /// No description provided for @healthM1w.
  ///
  /// In en, this message translates to:
  /// **'1 week'**
  String get healthM1w;

  /// No description provided for @healthM1wBody.
  ///
  /// In en, this message translates to:
  /// **'Taste and smell noticeably sharper. Breathing feels easier.'**
  String get healthM1wBody;

  /// No description provided for @healthM2w.
  ///
  /// In en, this message translates to:
  /// **'2 weeks'**
  String get healthM2w;

  /// No description provided for @healthM2wBody.
  ///
  /// In en, this message translates to:
  /// **'Circulation improves. Lung function begins to climb.'**
  String get healthM2wBody;

  /// No description provided for @healthM1m.
  ///
  /// In en, this message translates to:
  /// **'1 month'**
  String get healthM1m;

  /// No description provided for @healthM1mBody.
  ///
  /// In en, this message translates to:
  /// **'Coughing and shortness of breath ease off.'**
  String get healthM1mBody;

  /// No description provided for @healthM3m.
  ///
  /// In en, this message translates to:
  /// **'3 months'**
  String get healthM3m;

  /// No description provided for @healthM3mBody.
  ///
  /// In en, this message translates to:
  /// **'Lung capacity keeps climbing. The gym feels different.'**
  String get healthM3mBody;

  /// No description provided for @healthM6m.
  ///
  /// In en, this message translates to:
  /// **'6 months'**
  String get healthM6m;

  /// No description provided for @healthM6mBody.
  ///
  /// In en, this message translates to:
  /// **'Stress baseline drops — you handle bad days without it.'**
  String get healthM6mBody;

  /// No description provided for @healthM1y.
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get healthM1y;

  /// No description provided for @healthM1yBody.
  ///
  /// In en, this message translates to:
  /// **'Your risk profile looks like someone who never vaped daily.'**
  String get healthM1yBody;

  /// No description provided for @healthUnlockNote.
  ///
  /// In en, this message translates to:
  /// **'Each unlock fires a small celebration + optional share card.'**
  String get healthUnlockNote;

  /// No description provided for @healthSourceNote.
  ///
  /// In en, this message translates to:
  /// **'Based on smoking-cessation research — vaping evidence is still emerging.'**
  String get healthSourceNote;

  /// No description provided for @milestonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestonesTitle;

  /// No description provided for @milestonesEarned.
  ///
  /// In en, this message translates to:
  /// **'{earned} of {total} earned'**
  String milestonesEarned(int earned, int total);

  /// No description provided for @milestonesNext.
  ///
  /// In en, this message translates to:
  /// **'Next: {name}'**
  String milestonesNext(String name);

  /// No description provided for @milestonesNextProgress.
  ///
  /// In en, this message translates to:
  /// **'day {day} of {target} · {remaining, plural, one{one more sunrise} other{{remaining} more sunrises}}'**
  String milestonesNextProgress(int day, int target, num remaining);

  /// No description provided for @milestonesNotLeaderboard.
  ///
  /// In en, this message translates to:
  /// **'Badges are yours, not a leaderboard. Nobody else\'s grid to compare.'**
  String get milestonesNotLeaderboard;

  /// No description provided for @mFirstLog.
  ///
  /// In en, this message translates to:
  /// **'First log'**
  String get mFirstLog;

  /// No description provided for @mFirstCraving.
  ///
  /// In en, this message translates to:
  /// **'First craving beaten'**
  String get mFirstCraving;

  /// No description provided for @mSpark.
  ///
  /// In en, this message translates to:
  /// **'3-day spark'**
  String get mSpark;

  /// No description provided for @mWeekFlame.
  ///
  /// In en, this message translates to:
  /// **'7-day flame'**
  String get mWeekFlame;

  /// No description provided for @mHundredSaved.
  ///
  /// In en, this message translates to:
  /// **'\$100 saved'**
  String get mHundredSaved;

  /// No description provided for @mCleanWeekend.
  ///
  /// In en, this message translates to:
  /// **'Clean weekend'**
  String get mCleanWeekend;

  /// No description provided for @mHelpedSos.
  ///
  /// In en, this message translates to:
  /// **'Helped an SOS'**
  String get mHelpedSos;

  /// No description provided for @mTwoWeekFlame.
  ///
  /// In en, this message translates to:
  /// **'Two-week flame'**
  String get mTwoWeekFlame;

  /// No description provided for @mHalfNicotine.
  ///
  /// In en, this message translates to:
  /// **'Half nicotine'**
  String get mHalfNicotine;

  /// No description provided for @mMoodWeek.
  ///
  /// In en, this message translates to:
  /// **'Mood-week streak'**
  String get mMoodWeek;

  /// No description provided for @mTenCravings.
  ///
  /// In en, this message translates to:
  /// **'10 cravings beaten'**
  String get mTenCravings;

  /// No description provided for @mQuarterCurve.
  ///
  /// In en, this message translates to:
  /// **'Quarter of the curve'**
  String get mQuarterCurve;

  /// No description provided for @mInferno.
  ///
  /// In en, this message translates to:
  /// **'30-day inferno'**
  String get mInferno;

  /// No description provided for @mFreedomDay.
  ///
  /// In en, this message translates to:
  /// **'Freedom Day'**
  String get mFreedomDay;

  /// No description provided for @mFirstPost.
  ///
  /// In en, this message translates to:
  /// **'First post'**
  String get mFirstPost;

  /// No description provided for @mFiveHundredSaved.
  ///
  /// In en, this message translates to:
  /// **'\$500 saved'**
  String get mFiveHundredSaved;

  /// No description provided for @mComeback.
  ///
  /// In en, this message translates to:
  /// **'Comeback'**
  String get mComeback;

  /// No description provided for @moodTitle.
  ///
  /// In en, this message translates to:
  /// **'How\'s today feeling?'**
  String get moodTitle;

  /// No description provided for @moodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'10 seconds. It matters more than you\'d think.'**
  String get moodSubtitle;

  /// No description provided for @moodRough.
  ///
  /// In en, this message translates to:
  /// **'rough'**
  String get moodRough;

  /// No description provided for @moodMeh.
  ///
  /// In en, this message translates to:
  /// **'meh'**
  String get moodMeh;

  /// No description provided for @moodOkay.
  ///
  /// In en, this message translates to:
  /// **'okay'**
  String get moodOkay;

  /// No description provided for @moodGood.
  ///
  /// In en, this message translates to:
  /// **'good'**
  String get moodGood;

  /// No description provided for @moodGreat.
  ///
  /// In en, this message translates to:
  /// **'great'**
  String get moodGreat;

  /// No description provided for @moodNoteHint.
  ///
  /// In en, this message translates to:
  /// **'One line, optional — \"work party tonight, nervous\"'**
  String get moodNoteHint;

  /// No description provided for @moodUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'🔓 Mood ↔ craving link'**
  String get moodUnlockTitle;

  /// No description provided for @moodUnlockProgress.
  ///
  /// In en, this message translates to:
  /// **'{done}/{total} check-ins'**
  String moodUnlockProgress(int done, int total);

  /// No description provided for @moodUnlockNote.
  ///
  /// In en, this message translates to:
  /// **'{count} more and your report shows how mood drives your cravings.'**
  String moodUnlockNote(int count);

  /// No description provided for @moodCta.
  ///
  /// In en, this message translates to:
  /// **'Check in'**
  String get moodCta;

  /// No description provided for @moodSaved.
  ///
  /// In en, this message translates to:
  /// **'Noted. Data beats vibes. 🙌'**
  String get moodSaved;

  /// No description provided for @insightLinkTitle.
  ///
  /// In en, this message translates to:
  /// **'Weekly report'**
  String get insightLinkTitle;

  /// No description provided for @insightTitle.
  ///
  /// In en, this message translates to:
  /// **'Week {week} report · {range}'**
  String insightTitle(int week, String range);

  /// No description provided for @insightWinLabel.
  ///
  /// In en, this message translates to:
  /// **'Your win'**
  String get insightWinLabel;

  /// No description provided for @insightWatchoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Watch out'**
  String get insightWatchoutLabel;

  /// No description provided for @insightWeekChartLabel.
  ///
  /// In en, this message translates to:
  /// **'PUFFS, LAST 7 DAYS'**
  String get insightWeekChartLabel;

  /// No description provided for @insightCravingsChartLabel.
  ///
  /// In en, this message translates to:
  /// **'CRAVINGS SURVIVED, LAST 7 DAYS'**
  String get insightCravingsChartLabel;

  /// No description provided for @insightHoursChartLabel.
  ///
  /// In en, this message translates to:
  /// **'PUFFS BY HOUR, LAST 14 DAYS'**
  String get insightHoursChartLabel;

  /// No description provided for @insightPendingTitle.
  ///
  /// In en, this message translates to:
  /// **'No report yet'**
  String get insightPendingTitle;

  /// No description provided for @insightPendingBody.
  ///
  /// In en, this message translates to:
  /// **'{name} writes one every Sunday from the week you actually logged — your hours, your moods, your wins. Nothing to show until there\'s a week to read.'**
  String insightPendingBody(String name);

  /// No description provided for @insightCounter.
  ///
  /// In en, this message translates to:
  /// **'INSIGHT {index} OF {total}'**
  String insightCounter(int index, int total);

  /// No description provided for @slipTitle.
  ///
  /// In en, this message translates to:
  /// **'A slip is data, not defeat.'**
  String get slipTitle;

  /// No description provided for @slipSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You logged puffs after {days} clean days. That\'s information — it tells us exactly where the plan needs armor.'**
  String slipSubtitle(int days);

  /// No description provided for @slipWhatHappened.
  ///
  /// In en, this message translates to:
  /// **'WHAT WAS GOING ON?'**
  String get slipWhatHappened;

  /// No description provided for @slipTriggerParty.
  ///
  /// In en, this message translates to:
  /// **'Party'**
  String get slipTriggerParty;

  /// No description provided for @slipTriggerStress.
  ///
  /// In en, this message translates to:
  /// **'Stress'**
  String get slipTriggerStress;

  /// No description provided for @slipTriggerBoredom.
  ///
  /// In en, this message translates to:
  /// **'Boredom'**
  String get slipTriggerBoredom;

  /// No description provided for @slipTriggerDrinking.
  ///
  /// In en, this message translates to:
  /// **'Drinking'**
  String get slipTriggerDrinking;

  /// No description provided for @slipTriggerFriends.
  ///
  /// In en, this message translates to:
  /// **'Friends had one'**
  String get slipTriggerFriends;

  /// No description provided for @slipTriggerJustHappened.
  ///
  /// In en, this message translates to:
  /// **'Just happened'**
  String get slipTriggerJustHappened;

  /// No description provided for @slipNoBannedWords.
  ///
  /// In en, this message translates to:
  /// **'No banned words here, ever. Most people who quit for good slipped on the way. The log stays honest, the plan adapts.'**
  String get slipNoBannedWords;

  /// No description provided for @slipAdjustCta.
  ///
  /// In en, this message translates to:
  /// **'Adjust my plan'**
  String get slipAdjustCta;

  /// No description provided for @slipAdjustTitle.
  ///
  /// In en, this message translates to:
  /// **'Here\'s the adjustment.'**
  String get slipAdjustTitle;

  /// No description provided for @slipCurveLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR CURVE — GENTLY REFLOWN'**
  String get slipCurveLabel;

  /// No description provided for @slipTheBump.
  ///
  /// In en, this message translates to:
  /// **'the slip bump'**
  String get slipTheBump;

  /// No description provided for @slipNewFreedom.
  ///
  /// In en, this message translates to:
  /// **'Freedom Day: {date} (+{days} days)'**
  String slipNewFreedom(String date, int days);

  /// No description provided for @slipCurveNote.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination.'**
  String get slipCurveNote;

  /// No description provided for @slipStreakSurvives.
  ///
  /// In en, this message translates to:
  /// **'Your {days} days still count.'**
  String slipStreakSurvives(int days);

  /// No description provided for @slipFlameDims.
  ///
  /// In en, this message translates to:
  /// **'The flame dims, it doesn\'t die. One clean day brings it back to full blaze.'**
  String get slipFlameDims;

  /// No description provided for @slipBackOnCurve.
  ///
  /// In en, this message translates to:
  /// **'Back on the curve'**
  String get slipBackOnCurve;

  /// No description provided for @slipTalkFirst.
  ///
  /// In en, this message translates to:
  /// **'Talk it through with coach first'**
  String get slipTalkFirst;

  /// No description provided for @profileQuittingSince.
  ///
  /// In en, this message translates to:
  /// **'quitting since {date} · {method} · day {day}'**
  String profileQuittingSince(String date, String method, int day);

  /// No description provided for @profileCountdownLabel.
  ///
  /// In en, this message translates to:
  /// **'🏆 FREEDOM DAY COUNTDOWN'**
  String get profileCountdownLabel;

  /// No description provided for @profileDaysTo.
  ///
  /// In en, this message translates to:
  /// **'days to {date}'**
  String profileDaysTo(String date);

  /// No description provided for @profileLifetimeSaved.
  ///
  /// In en, this message translates to:
  /// **'lifetime saved'**
  String get profileLifetimeSaved;

  /// No description provided for @profilePuffsNotTaken.
  ///
  /// In en, this message translates to:
  /// **'puffs not taken'**
  String get profilePuffsNotTaken;

  /// No description provided for @profileBadgesEarned.
  ///
  /// In en, this message translates to:
  /// **'badges earned'**
  String get profileBadgesEarned;

  /// No description provided for @profileSettings.
  ///
  /// In en, this message translates to:
  /// **'⚙️ Settings'**
  String get profileSettings;

  /// No description provided for @profileEditAlias.
  ///
  /// In en, this message translates to:
  /// **'Pick your alias'**
  String get profileEditAlias;

  /// No description provided for @profileEditAvatar.
  ///
  /// In en, this message translates to:
  /// **'Pick your avatar'**
  String get profileEditAvatar;

  /// No description provided for @profileAliasHint.
  ///
  /// In en, this message translates to:
  /// **'anonymous — this is all anyone sees'**
  String get profileAliasHint;

  /// No description provided for @memoriesTitle.
  ///
  /// In en, this message translates to:
  /// **'What {name} remembers'**
  String memoriesTitle(String name);

  /// No description provided for @memoriesIntro.
  ///
  /// In en, this message translates to:
  /// **'What {name} knows about you: your setup and live numbers from the app, plus the things you\'ve told it in chat — those you can make it forget, any time.'**
  String memoriesIntro(String name);

  /// No description provided for @memoriesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet. This part fills up as you tell {name} things about your life in chat.'**
  String memoriesEmpty(String name);

  /// No description provided for @memoriesSectionKnows.
  ///
  /// In en, this message translates to:
  /// **'What {name} always knows'**
  String memoriesSectionKnows(String name);

  /// No description provided for @memoriesSectionTold.
  ///
  /// In en, this message translates to:
  /// **'Things you\'ve told {name}'**
  String memoriesSectionTold(String name);

  /// No description provided for @memoriesFactPlan.
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get memoriesFactPlan;

  /// No description provided for @memoriesFactPlanValue.
  ///
  /// In en, this message translates to:
  /// **'{method} · {days} days'**
  String memoriesFactPlanValue(String method, int days);

  /// No description provided for @memoriesFactStarted.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get memoriesFactStarted;

  /// No description provided for @memoriesFactBaseline.
  ///
  /// In en, this message translates to:
  /// **'Baseline'**
  String get memoriesFactBaseline;

  /// No description provided for @memoriesFactBaselineValue.
  ///
  /// In en, this message translates to:
  /// **'{count} puffs a day'**
  String memoriesFactBaselineValue(int count);

  /// No description provided for @memoriesFactWhy.
  ///
  /// In en, this message translates to:
  /// **'Your why'**
  String get memoriesFactWhy;

  /// No description provided for @memoriesFactWorries.
  ///
  /// In en, this message translates to:
  /// **'Worried about'**
  String get memoriesFactWorries;

  /// No description provided for @memoriesFactWhyWords.
  ///
  /// In en, this message translates to:
  /// **'In your words'**
  String get memoriesFactWhyWords;

  /// No description provided for @memoriesFactFirstPuff.
  ///
  /// In en, this message translates to:
  /// **'First puff after waking'**
  String get memoriesFactFirstPuff;

  /// No description provided for @memoriesFactFrequency.
  ///
  /// In en, this message translates to:
  /// **'How often'**
  String get memoriesFactFrequency;

  /// No description provided for @memoriesFactDay.
  ///
  /// In en, this message translates to:
  /// **'Where you are'**
  String get memoriesFactDay;

  /// No description provided for @memoriesFactDayValue.
  ///
  /// In en, this message translates to:
  /// **'Day {day} of {total}'**
  String memoriesFactDayValue(int day, int total);

  /// No description provided for @memoriesFactDayMaintenance.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Plan complete · 1 day past Freedom Day} other{Plan complete · {count} days past Freedom Day}}'**
  String memoriesFactDayMaintenance(num count);

  /// No description provided for @memoriesFactToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get memoriesFactToday;

  /// No description provided for @memoriesFactTodayValue.
  ///
  /// In en, this message translates to:
  /// **'{puffs} of {limit} puffs'**
  String memoriesFactTodayValue(int puffs, int limit);

  /// No description provided for @memoriesFactStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get memoriesFactStreak;

  /// No description provided for @memoriesFactSaved.
  ///
  /// In en, this message translates to:
  /// **'Money saved'**
  String get memoriesFactSaved;

  /// No description provided for @memoriesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load these right now.'**
  String get memoriesFailed;

  /// No description provided for @memoriesForget.
  ///
  /// In en, this message translates to:
  /// **'Forget this'**
  String get memoriesForget;

  /// No description provided for @memoriesForgotten.
  ///
  /// In en, this message translates to:
  /// **'Forgotten. {name} won\'t bring it up again.'**
  String memoriesForgotten(String name);

  /// No description provided for @memoriesForgetFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through — it\'s still remembered.'**
  String get memoriesForgetFailed;

  /// No description provided for @memoriesKindPerson.
  ///
  /// In en, this message translates to:
  /// **'Someone in your life'**
  String get memoriesKindPerson;

  /// No description provided for @memoriesKindTrigger.
  ///
  /// In en, this message translates to:
  /// **'A trigger'**
  String get memoriesKindTrigger;

  /// No description provided for @memoriesKindMotivation.
  ///
  /// In en, this message translates to:
  /// **'Why you\'re doing this'**
  String get memoriesKindMotivation;

  /// No description provided for @memoriesKindMilestone.
  ///
  /// In en, this message translates to:
  /// **'Something you\'re working toward'**
  String get memoriesKindMilestone;

  /// No description provided for @memoriesKindPreference.
  ///
  /// In en, this message translates to:
  /// **'How you like to be talked to'**
  String get memoriesKindPreference;

  /// No description provided for @memoriesKindContext.
  ///
  /// In en, this message translates to:
  /// **'About you'**
  String get memoriesKindContext;

  /// No description provided for @settingsMemories.
  ///
  /// In en, this message translates to:
  /// **'What {name} remembers'**
  String settingsMemories(String name);

  /// No description provided for @moderationTitle.
  ///
  /// In en, this message translates to:
  /// **'Review queue'**
  String get moderationTitle;

  /// No description provided for @moderationEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing waiting. Every flag is reviewed.'**
  String get moderationEmpty;

  /// No description provided for @moderationFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the queue.'**
  String get moderationFailed;

  /// No description provided for @moderationRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get moderationRetry;

  /// No description provided for @moderationShowReviewed.
  ///
  /// In en, this message translates to:
  /// **'Show reviewed'**
  String get moderationShowReviewed;

  /// No description provided for @moderationPendingCount.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting'**
  String moderationPendingCount(int count);

  /// No description provided for @moderationSubjectGone.
  ///
  /// In en, this message translates to:
  /// **'The post is gone; only the flag is left.'**
  String get moderationSubjectGone;

  /// No description provided for @moderationAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get moderationAllow;

  /// No description provided for @moderationBlock.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get moderationBlock;

  /// No description provided for @moderationDismiss.
  ///
  /// In en, this message translates to:
  /// **'Looks fine'**
  String get moderationDismiss;

  /// No description provided for @moderationResolveFailed.
  ///
  /// In en, this message translates to:
  /// **'That didn\'t go through. The post is unchanged.'**
  String get moderationResolveFailed;

  /// No description provided for @moderationFlaggedAs.
  ///
  /// In en, this message translates to:
  /// **'{action} · {reason}'**
  String moderationFlaggedAs(String action, String reason);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsSubscription.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get settingsSubscription;

  /// No description provided for @settingsSubscriptionFree.
  ///
  /// In en, this message translates to:
  /// **'Free plan'**
  String get settingsSubscriptionFree;

  /// No description provided for @settingsSubscriptionYearly.
  ///
  /// In en, this message translates to:
  /// **'Premium · yearly'**
  String get settingsSubscriptionYearly;

  /// No description provided for @settingsSubscriptionMonthly.
  ///
  /// In en, this message translates to:
  /// **'Premium · monthly'**
  String get settingsSubscriptionMonthly;

  /// No description provided for @settingsSubscriptionWeekly.
  ///
  /// In en, this message translates to:
  /// **'Premium · weekly'**
  String get settingsSubscriptionWeekly;

  /// No description provided for @settingsSubscriptionPremium.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get settingsSubscriptionPremium;

  /// No description provided for @settingsSubscriptionTrial.
  ///
  /// In en, this message translates to:
  /// **'Trial · ends {date}'**
  String settingsSubscriptionTrial(String date);

  /// No description provided for @settingsSubscriptionEnds.
  ///
  /// In en, this message translates to:
  /// **'Premium · ends {date}'**
  String settingsSubscriptionEnds(String date);

  /// No description provided for @settingsManageUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Manage this subscription from the store account that bought it.'**
  String get settingsManageUnavailable;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsDangerHours.
  ///
  /// In en, this message translates to:
  /// **'Danger hours'**
  String get settingsDangerHours;

  /// No description provided for @settingsDangerHoursEdit.
  ///
  /// In en, this message translates to:
  /// **'{range} · edit ›'**
  String settingsDangerHoursEdit(String range);

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We never sell your data. No ad trackers. Ever.'**
  String get settingsPrivacyNote;

  /// No description provided for @settingsDeleteEverything.
  ///
  /// In en, this message translates to:
  /// **'Delete everything'**
  String get settingsDeleteEverything;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete everything?'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your plan, logs, streak, and community posts — gone for good. This is the one button we can\'t undo.'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsDeleteConfirmCta.
  ///
  /// In en, this message translates to:
  /// **'Yes, delete it all'**
  String get settingsDeleteConfirmCta;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsAppearanceSystem.
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get settingsAppearanceSystem;

  /// No description provided for @settingsAppearanceMidnight.
  ///
  /// In en, this message translates to:
  /// **'Midnight'**
  String get settingsAppearanceMidnight;

  /// No description provided for @settingsAppearanceDaylight.
  ///
  /// In en, this message translates to:
  /// **'Daylight'**
  String get settingsAppearanceDaylight;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOut;

  /// No description provided for @settingsSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutConfirmTitle;

  /// No description provided for @settingsSignOutConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Your data stays on your account. The streak keeps burning.'**
  String get settingsSignOutConfirmBody;

  /// No description provided for @settingsDangerHoursTitle.
  ///
  /// In en, this message translates to:
  /// **'When do cravings hit hardest?'**
  String get settingsDangerHoursTitle;

  /// No description provided for @settingsDangerHoursNote.
  ///
  /// In en, this message translates to:
  /// **'Pick the hour it usually starts. We nudge you 10 minutes before it — one push a day, nothing more.'**
  String get settingsDangerHoursNote;

  /// No description provided for @settingsDangerHoursNudge.
  ///
  /// In en, this message translates to:
  /// **'One nudge at {time}, every day.'**
  String settingsDangerHoursNudge(String time);

  /// No description provided for @settingsDangerHoursNotifOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so nothing fires until you turn them on.'**
  String get settingsDangerHoursNotifOff;

  /// No description provided for @settingsQuietHours.
  ///
  /// In en, this message translates to:
  /// **'Never between {range} — quiet hours.'**
  String settingsQuietHours(String range);

  /// No description provided for @trialEndingPushTime.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get trialEndingPushTime;

  /// No description provided for @trialEndingPush.
  ///
  /// In en, this message translates to:
  /// **'your trial ends tomorrow — as promised, here\'s the heads-up. No surprise charges.'**
  String get trialEndingPush;

  /// No description provided for @trialEndingTitle.
  ///
  /// In en, this message translates to:
  /// **'Trial ends tomorrow.'**
  String get trialEndingTitle;

  /// No description provided for @trialEndingBody.
  ///
  /// In en, this message translates to:
  /// **'We said we\'d remind you, so: here it is. Keep Premium, or drop to Free — your streak, plan, and history stay either way.'**
  String get trialEndingBody;

  /// No description provided for @trialEndingStatsLabel.
  ///
  /// In en, this message translates to:
  /// **'YOUR WEEK SO FAR'**
  String get trialEndingStatsLabel;

  /// No description provided for @trialEndingVsDay1.
  ///
  /// In en, this message translates to:
  /// **'puffs vs day 1'**
  String get trialEndingVsDay1;

  /// No description provided for @trialEndingCravings.
  ///
  /// In en, this message translates to:
  /// **'cravings beaten'**
  String get trialEndingCravings;

  /// No description provided for @trialEndingSaved.
  ///
  /// In en, this message translates to:
  /// **'saved'**
  String get trialEndingSaved;

  /// No description provided for @trialEndingKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep Premium'**
  String get trialEndingKeep;

  /// No description provided for @trialEndingSwitchFree.
  ///
  /// In en, this message translates to:
  /// **'Switch to Free (keeps your data)'**
  String get trialEndingSwitchFree;

  /// No description provided for @trialEndsOn.
  ///
  /// In en, this message translates to:
  /// **'Your trial ends {date}.'**
  String trialEndsOn(String date);

  /// No description provided for @trialEndingNotifTitle.
  ///
  /// In en, this message translates to:
  /// **'Your trial ends tomorrow'**
  String get trialEndingNotifTitle;

  /// No description provided for @frameMapTitle.
  ///
  /// In en, this message translates to:
  /// **'All 52 design frames'**
  String get frameMapTitle;

  /// No description provided for @frameMapNote.
  ///
  /// In en, this message translates to:
  /// **'Every frame from the four handoffs, one tap away. Rows load the demo journey or quiz answers as needed.'**
  String get frameMapNote;

  /// No description provided for @frameMapEdgeNote.
  ///
  /// In en, this message translates to:
  /// **'These states go live with the backend — an in-memory app has no offline or server errors to show honestly.'**
  String get frameMapEdgeNote;

  /// No description provided for @seedPostWin30.
  ///
  /// In en, this message translates to:
  /// **'FREEDOM DAY. 30 days, zero puffs the last week. The panic button carried me through weekends. If you\'re on day 2 and dying — it genuinely gets easier around day 8.'**
  String get seedPostWin30;

  /// No description provided for @seedPostSos.
  ///
  /// In en, this message translates to:
  /// **'outside the gas station. wallet in hand. someone talk me out of this'**
  String get seedPostSos;

  /// No description provided for @seedPostDay1.
  ///
  /// In en, this message translates to:
  /// **'threw mine in the lake. probably bad for the lake. day 1 starts now'**
  String get seedPostDay1;

  /// No description provided for @seedPostVent.
  ///
  /// In en, this message translates to:
  /// **'coworker blows mango clouds at his desk ALL DAY and I\'m supposed to just… focus? venting so I don\'t cave'**
  String get seedPostVent;

  /// No description provided for @seedPostMilestone.
  ///
  /// In en, this message translates to:
  /// **'two weeks. took the stairs to floor 4 today and didn\'t sound like a haunted accordion. small wins'**
  String get seedPostMilestone;

  /// No description provided for @seedPostWinParty.
  ///
  /// In en, this message translates to:
  /// **'made it through a whole party without borrowing anyone\'s vape. hands survived by holding a lime seltzer like a weirdo'**
  String get seedPostWinParty;

  /// No description provided for @seedReplyWalk.
  ///
  /// In en, this message translates to:
  /// **'walk. just walk one block. the wallet stays heavy, you stay free. i did this exact thing tuesday'**
  String get seedReplyWalk;

  /// No description provided for @seedReplyScience.
  ///
  /// In en, this message translates to:
  /// **'day 4 is the worst one, it\'s science. you\'re at the peak RIGHT NOW. 15 minutes and this dies'**
  String get seedReplyScience;

  /// No description provided for @seedReplyGatorade.
  ///
  /// In en, this message translates to:
  /// **'buy a gatorade instead. ceremonial purchase. works weirdly well'**
  String get seedReplyGatorade;

  /// No description provided for @seedReplyUpdate.
  ///
  /// In en, this message translates to:
  /// **'update: bought the gatorade. walking home. thank you, i mean it 💙'**
  String get seedReplyUpdate;

  /// Local notification fired 10 min before a predicted danger hour (docs/03 §8).
  ///
  /// In en, this message translates to:
  /// **'Your danger hour is coming up'**
  String get dangerReminderTitle;

  /// Body of the danger-hour reminder. Cites the 15-20 minute craving fact from docs/02 §8 — an approved stat.
  ///
  /// In en, this message translates to:
  /// **'This is usually when it hits. You\'ve got a plan — and 15 minutes beats it.'**
  String get dangerReminderBody;

  /// No description provided for @communityLoading.
  ///
  /// In en, this message translates to:
  /// **'Pulling in the feed…'**
  String get communityLoading;

  /// No description provided for @memoriesLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking what {name} kept…'**
  String memoriesLoading(String name);

  /// No description provided for @coachLoadingThread.
  ///
  /// In en, this message translates to:
  /// **'Catching up on your chat…'**
  String get coachLoadingThread;

  /// No description provided for @moderationLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading the queue…'**
  String get moderationLoading;

  /// No description provided for @slipCurveNoteParty.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. Before the next party, set a danger hour so the reminder lands first.'**
  String get slipCurveNoteParty;

  /// No description provided for @slipCurveNoteStress.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. When stress hits, the panic button\'s 60-second breathe is built for exactly that minute.'**
  String get slipCurveNoteStress;

  /// No description provided for @slipCurveNoteBoredom.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. For the empty minutes, the game inside the panic flow is one tap away.'**
  String get slipCurveNoteBoredom;

  /// No description provided for @slipCurveNoteDrinking.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. Set a danger hour before your next drink — the reminder lands before the first one.'**
  String get slipCurveNoteDrinking;

  /// No description provided for @slipCurveNoteFriends.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. Next time, text your coach before you meet them, not after.'**
  String get slipCurveNoteFriends;

  /// No description provided for @slipCurveNoteJustHappened.
  ///
  /// In en, this message translates to:
  /// **'Two extra days, same destination. It happens. The log stays honest, and tomorrow is a clean day.'**
  String get slipCurveNoteJustHappened;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
