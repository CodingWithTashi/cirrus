// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline => 'Dein letzter Zug ist näher,\nals du denkst.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · gebaut von Leuten, die aufgehört haben';
  }

  @override
  String get commonContinue => 'Weiter';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonNotNow => 'Jetzt nicht';

  @override
  String get commonMaybeLater => 'Vielleicht später';

  @override
  String commonDayN(int day) {
    return 'Tag $day';
  }

  @override
  String get authSignInTitle => 'Bringen wir deinen\nPlan in Sicherheit.';

  @override
  String get authSignInSubtitle =>
      'Standardmäßig anonym — für die Community wählst du einen Alias.';

  @override
  String get authSignInWithApple => 'Mit Apple anmelden';

  @override
  String get authSignInWithGoogle => 'Mit Google anmelden';

  @override
  String get authContinueWithEmail => 'Mit E-Mail fortfahren';

  @override
  String get authWhyAccountDivider => 'warum ein Konto?';

  @override
  String get authWhyAccountCard =>
      'Deine Serie, dein Plan und das Gedächtnis deines Coaches syncen über Geräte. 🔒 Wir verkaufen nie deine Daten. Keine Werbe-Tracker. Niemals.';

  @override
  String get authTerms => 'AGB';

  @override
  String get authPrivacy => 'Datenschutz';

  @override
  String get authRestorePurchase => 'Kauf wiederherstellen';

  @override
  String get authRegisterTitle => 'Erstell dein Konto';

  @override
  String get authEmailLabel => 'E-MAIL';

  @override
  String get authPasswordLabel => 'PASSWORT';

  @override
  String get authShowPassword => 'zeigen';

  @override
  String get authHidePassword => 'verbergen';

  @override
  String get authPasswordStrengthWeak => 'tipp weiter…';

  @override
  String get authPasswordStrengthDecent => 'solides Passwort';

  @override
  String get authPasswordStrengthStrong => 'starkes Passwort';

  @override
  String get authNoSpamCard =>
      'Kein Spam, keine „Wir vermissen dich“-Mails. Konto = Backup, mehr nicht.';

  @override
  String get authCreateAccount => 'Konto erstellen';

  @override
  String get authAlreadyHaveOne => 'Schon eins?';

  @override
  String get authLogIn => 'Anmelden';

  @override
  String get authLoginTitle => 'Willkommen zurück.';

  @override
  String get authLoginSubtitle => 'Deine Serie hat dich vermisst.';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authNewHere => 'Neu hier?';

  @override
  String get authWrongPassword => 'das war\'s nicht — nochmal';

  @override
  String get authForgotTitle => 'Passiert jedem.';

  @override
  String get authForgotSubtitle =>
      'Gib deine E-Mail an — wir schicken einen Reset-Link. Deine Serie bleibt unberührt.';

  @override
  String get authLinkSent =>
      'Link gesendet. Schau in den Spam, falls er sich versteckt.';

  @override
  String get authResendLink => 'Link erneut senden';

  @override
  String authResendCountdown(int seconds) {
    return 'Erneut senden in ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Zurück zur Anmeldung';

  @override
  String get authInvalidEmail => 'das sieht nicht nach einer E-Mail aus';

  @override
  String get authEmailInUse =>
      'diese E-Mail hat schon eine Reise — melde dich an';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint => 'Züge am Tag — gleich weißt du es';

  @override
  String get obWelcomeTitle => 'Wie abhängig bist du wirklich?';

  @override
  String get obWelcomeSubtitle =>
      '2-Minuten-Check-up. Brutal ehrliche Ergebnisse. Ein Plan nur für dich.';

  @override
  String get obWelcomeCta => 'Check-up starten';

  @override
  String get obResumeTitle => 'Da weitermachen, wo du aufgehört hast?';

  @override
  String obResumeBody(int answered, int total) {
    return 'Du hattest $answered von $total Fragen beantwortet. Nichts ist weg.';
  }

  @override
  String get obResumeCta => 'Weitermachen';

  @override
  String get obResumeFresh => 'Neu anfangen';

  @override
  String get obGenderTitle => 'Wie identifizierst du dich?';

  @override
  String get obGenderSubtitle =>
      'Kalibriert deinen Plan — der Nikotinstoffwechsel unterscheidet sich.';

  @override
  String get obGenderWoman => 'Frau';

  @override
  String get obGenderMan => 'Mann';

  @override
  String get obGenderNonBinary => 'Nicht-binär / sag ich nicht';

  @override
  String get obGenderPrivacyNote =>
      '🔒 Privat. Wird der Community nie gezeigt.';

  @override
  String get obBirthYearTitle => 'In welchem Jahr bist du geboren?';

  @override
  String get obBirthYearSubtitle => 'Dein Plan passt sich deinem Alter an.';

  @override
  String get obBirthYearHint => 'Jahr oder Alter — beides geht.';

  @override
  String obBirthYearAge(int age) {
    return 'Du bist $age.';
  }

  @override
  String obBirthYearAgeOffer(int age, int year) {
    return '$age? Das wäre Jahrgang $year.';
  }

  @override
  String get obBirthYearAgeConfirm => 'Das bin ich';

  @override
  String obBirthYearUnderConfirm(int year, int age) {
    return 'Geboren $year? Dann bist du $age.';
  }

  @override
  String obBirthYearUnderCta(int age) {
    return 'Ja, ich bin $age';
  }

  @override
  String get obBirthYearFix => 'Lass mich das korrigieren';

  @override
  String get obBirthYearErrorFuture =>
      'Dieses Jahr ist noch nicht da. Nochmal?';

  @override
  String get obBirthYearErrorTooOld =>
      'Der älteste je bestätigte Mensch wurde 122. Versuchen wir es nochmal.';

  @override
  String get obBirthYearErrorUnknown =>
      'Das ist kein Jahr — und auch kein Alter. Noch ein Versuch.';

  @override
  String get obUnder18Title =>
      'Hier können wir dir nicht helfen — aber das hier kann es.';

  @override
  String get obUnder18Subtitle =>
      'Cirrus ist ab 18. Diese zwei sind kostenlos, privat und für dein Alter gemacht. Sie funktionieren.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Tägliche Nachrichten von Leuten, die es verstehen. Über 500.000 junge Menschen dabei.';

  @override
  String get obUnder18TiqCta => 'Texte DITCHVAPE an 88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Kostenloses Coaching per Text oder Anruf, gemacht für Teens. Keine Vorträge.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'Wir drücken die Daumen. Komm mit 18 wieder, falls du uns noch brauchst — wirst du nicht. 💪';

  @override
  String get obTriedTitle => 'Schon mal versucht aufzuhören?';

  @override
  String get obTriedNever => 'Nie';

  @override
  String get obTriedNeverSub => 'erstes Mal';

  @override
  String get obTriedOnce => 'Einmal';

  @override
  String get obTriedOnceSub => 'hat nicht gehalten';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'ein paar Runden';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'zählen aufgegeben';

  @override
  String get obTriedReaction =>
      'Die meisten brauchen mehrere Anläufe. Jeder hat deinem Gehirn etwas beigebracht — diesmal hast du einen Plan.';

  @override
  String get obFrequencyTitle => 'Wie oft ist es in deiner Hand?';

  @override
  String get obFrequencySubtitle => 'Kein Urteil. Nur Kalibrierung.';

  @override
  String get obFreqDaily => 'TÄGLICH';

  @override
  String get obFreqDailySub => 'Jeden Tag, mit echten Pausen dazwischen.';

  @override
  String get obFreqOften => 'OFT';

  @override
  String get obFreqOftenSub => 'Fast den ganzen Tag, in Sessions.';

  @override
  String get obFreqAlways => 'IMMER';

  @override
  String get obFreqAlwaysSub => 'Praktisch ein Teil meiner Hand.';

  @override
  String get obPuffsTitle => 'Züge an einem normalen Tag?';

  @override
  String get obPuffsBadgeLight => 'Leichte Gewohnheit';

  @override
  String get obPuffsBadgeModerate => 'Mittlere Abhängigkeit';

  @override
  String get obPuffsBadgeHeavy => 'Starke Abhängigkeit';

  @override
  String get obPuffsBadgeSevere => 'Schwere Abhängigkeit';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ $count Zigaretten in Zügen';
  }

  @override
  String get obPuffsNotSure => 'Unsicher? Über das Gerät schätzen →';

  @override
  String get obPuffsHelperTitle => 'Schnelle Schätzung';

  @override
  String get obPuffsHelperBody =>
      'Eine typische Einweg-Vape hat ~600 Züge. Wie viele verbrauchst du pro Woche?';

  @override
  String obPuffsHelperResult(int count) {
    return 'Das sind etwa $count Züge am Tag. In deiner ersten Woche korrigieren wir automatisch nach.';
  }

  @override
  String obPuffsHelperDevicesPerWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Geräte / Woche',
      one: '$count Gerät / Woche',
    );
    return '$_temp0';
  }

  @override
  String get obStrengthTitle => 'Wie stark ist deine übliche?';

  @override
  String get obStrength20Sub => '2% · leichter';

  @override
  String get obStrength35Sub => '3,5% · mittel';

  @override
  String get obStrength50Sub => '5% · die meisten Einwegs';

  @override
  String get obStrengthNotSure => 'Weiß nicht';

  @override
  String get obStrengthNotSureSub => 'völlig okay';

  @override
  String get obStrengthNote =>
      'Die meisten Einwegs haben 5% — im Zweifel ist das die sichere Annahme.';

  @override
  String get obSpendTitle => 'Was kostet es dich pro Woche?';

  @override
  String get obSpendPerWeek => 'pro Woche';

  @override
  String get obSpendThats => 'das macht';

  @override
  String obSpendPerYear(String amount) {
    return '$amount im Jahr';
  }

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / Monat';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / Tag';
  }

  @override
  String get obSpendYourMath => 'deine Rechnung, nicht unsere';

  @override
  String obSpendComparisonOne(String item) {
    return 'Das ist $item. Jedes Jahr.';
  }

  @override
  String obSpendComparisonTwo(String item) {
    return 'Das ist $item, zweimal. Jedes Jahr.';
  }

  @override
  String obSpendComparisonMany(String item, int count) {
    return 'Das ist $item, $count-mal. Jedes Jahr.';
  }

  @override
  String get obSpendItemGymMonth => 'einen Monat im Fitnessstudio';

  @override
  String get obSpendItemConcertTicket => 'ein Konzertticket, gute Plätze';

  @override
  String get obSpendItemRunningShoes => 'ein ordentliches Paar Laufschuhe';

  @override
  String get obSpendItemDentalCleaning => 'eine Zahnreinigung';

  @override
  String get obSpendItemWinterCoat => 'einen Wintermantel, der wirklich wärmt';

  @override
  String get obSpendItemFestivalTicket =>
      'ein Festivalticket, Camping inklusive';

  @override
  String get obSpendItemWeekendAway => 'ein Wochenende weg';

  @override
  String get obSpendItemBike => 'ein Fahrrad, das Spaß macht';

  @override
  String get obSpendItemDrivingLessons => 'einen kompletten Fahrkurs';

  @override
  String get obSpendItemNewPhone => 'ein neues Handy';

  @override
  String get obSpendItemLaptop => 'einen Laptop, der nicht stirbt';

  @override
  String get obSpendItemEmergencyFund => 'einen echten Notgroschen';

  @override
  String get obSpendItemYogaYear => 'ein Jahr unbegrenztes Yoga';

  @override
  String get obSpendItemMonthOfRent => 'eine Monatsmiete';

  @override
  String get obSpendItemFamilyHoliday => 'einen Familienurlaub';

  @override
  String get obSpendItemUsedCar => 'ein Auto, das dich hinbringt';

  @override
  String get obFirstPuffTitle => 'Erster Zug nach dem Aufwachen?';

  @override
  String get obFirstPuffWithin5 => 'Innerhalb von 5 Minuten';

  @override
  String get obFirstPuff5to30 => '5–30 Minuten';

  @override
  String get obFirstPuff30to60 => '30–60 Minuten';

  @override
  String get obFirstPuffHourPlus => 'Eine Stunde oder mehr';

  @override
  String get obFirstPuffScience =>
      'Die Zeit bis zum ersten Zug ist der stärkste Einzelprädiktor für Abhängigkeit. 76% der jungen Vaper greifen innerhalb von 30 Min. nach dem Aufwachen zu.';

  @override
  String get obFactLabelScience => 'DIE WISSENSCHAFT';

  @override
  String get obFactLabelYourNumbers => 'DEINE ZAHLEN';

  @override
  String get obFactTried =>
      'Bei täglich Dampfenden stiegen gescheiterte Aufhörversuche zwischen 2020 und 2024 von 28% auf 53%. Die Geräte sind besser in ihrem Job geworden. Nicht du wirst schwächer — das ist ein Wettrüsten, zu dem dich niemand angemeldet hat.';

  @override
  String obFactStrength(int mg) {
    return 'Das sind ≈$mg mg Nikotin am Tag. Deine Zahlen, unsere Rechnung. Deine Vape hat übrigens noch nie eine Portionsgröße vorgeschlagen.';
  }

  @override
  String get obFactWorryCravings =>
      'Die meisten Cravings steigen und vergehen in 15–20 Minuten. Kürzer als Warten auf einen Tisch. Der Panikknopf ist genau für dieses Fenster gebaut.';

  @override
  String get obFactWorrySocial =>
      'Unterstützung durch andere erhöht die Erfolgsquote um rund 40%. Ja — Fremde im Internet. Uns hat es auch überrascht.';

  @override
  String get obWhyTitle => 'Warum willst du raus?';

  @override
  String get obWhySubtitle =>
      'Wähl alles, was trifft. Dein Coach nutzt es, wenn es hart wird.';

  @override
  String get obWhyHealth => 'Gesundheit';

  @override
  String get obWhyMoney => 'Geld';

  @override
  String get obWhyFreedom => 'Freiheit';

  @override
  String get obWhyFamily => 'Familie';

  @override
  String get obWhyFitness => 'Fitness';

  @override
  String get obWhyAppearance => 'Haut & Aussehen';

  @override
  String get obWhyCardLabel => 'DEIN WARUM';

  @override
  String get obWorriesTitle => 'Was macht dir am meisten Sorgen?';

  @override
  String get obWorriesSubtitle => 'Sei ehrlich. Das ist der nützliche Teil.';

  @override
  String get obWorryCravings => 'Cravings';

  @override
  String get obWorryStress => 'Stress';

  @override
  String get obWorrySocial => 'Gruppendruck';

  @override
  String get obWorryFailing => 'Angst zu scheitern';

  @override
  String get obWorryWeight => 'Zunehmen';

  @override
  String get obWorryBreaks => 'Meine Pausen verlieren';

  @override
  String get obWorriesAiNote =>
      'Dein Coach trainiert genau darauf. Craving um 23 Uhr? Er kennt dein Playbook schon.';

  @override
  String get obMethodFailingNote =>
      'Du hast „Angst zu scheitern“ gewählt — dieser Plan biegt sich deshalb, statt zu brechen. Ein Ausrutscher passt die Kurve an; nichts wird je zurückgesetzt.';

  @override
  String get obMethodTitle => 'Wie willst du es angehen?';

  @override
  String get obMethodSubtitle => 'Beides funktioniert. Je eine ehrliche Zeile.';

  @override
  String get obMethodTaper => 'Schrittweise runter';

  @override
  String get obMethodTaperSub =>
      'Täglich entlang einer Kurve reduzieren. Sanfterer Entzug, braucht Disziplin.';

  @override
  String get obMethodTaperReco => 'Ideal ab 100+ Zügen/Tag — also du';

  @override
  String get obMethodCold => 'Schlusspunkt';

  @override
  String get obMethodColdSub =>
      'Ein harter Stopp. Raue erste Woche, dafür schneller durch.';

  @override
  String get obMethodColdReco => 'Machbar auf deinem Level — deine Wahl';

  @override
  String get obPaceTitle => 'Wähl dein Tempo.';

  @override
  String obPaceMostChosen(int days) {
    return '$days Tage — am häufigsten gewählt';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count Züge';
  }

  @override
  String get obPaceCurveLabel => 'deine Kurve';

  @override
  String get obPaceCurveEnd => '0 Züge';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Freiheitstag';
  }

  @override
  String get obPaceNote =>
      'Die Kurve zeichnet sich live neu, wenn du ein Tempo antippst. Echte Daten, kein „Tag n“.';

  @override
  String get obPaceCta => 'Tempo festlegen';

  @override
  String get obBuildingTitle => 'Dein Plan entsteht…';

  @override
  String obBuildingStep1(int count) {
    return 'Analysiere $count Züge/Tag';
  }

  @override
  String get obBuildingStep2 => 'Kartiere deine Trigger';

  @override
  String obBuildingStep3(int days) {
    return 'Kalibriere deine $days-Tage-Kurve…';
  }

  @override
  String get obBuildingStep4 => 'Reserviere deinen Coach…';

  @override
  String obRevealTitle(int days) {
    return 'Dein $days-Tage-Trennungsplan.';
  }

  @override
  String get obRevealMilestone3 => 'Craving-Hoch — hier sind wir am lautesten';

  @override
  String get obRevealMilestone7 => 'Geschmack und Geruch kommen zurück';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Freiheitstag — $date';
  }

  @override
  String get obRevealSavedLabel => 'gespart bis zum Freiheitstag';

  @override
  String get obRevealPuffsLabel => 'Züge, die du nicht nimmst';

  @override
  String get obRevealProofLabel => 'EHRLICHER BEWEIS';

  @override
  String get obRevealProof =>
      '24% schaffen es mit strukturiertem Programm vs. 19% allein — randomisierte Studie mit 2.588 jungen Erwachsenen. Keine Magie. Bessere Chancen.';

  @override
  String obRevealComparisonOne(String item) {
    return 'Bis zum Freiheitstag ist das $item.';
  }

  @override
  String obRevealComparisonTwo(String item) {
    return 'Bis zum Freiheitstag ist das $item, zweimal.';
  }

  @override
  String obRevealComparisonMany(String item, int count) {
    return 'Bis zum Freiheitstag ist das $item, $count-mal.';
  }

  @override
  String get obRevealCta => 'Ich bin bereit';

  @override
  String get obCommitTitle => 'Mach es real.';

  @override
  String get obCommitSubtitle => 'Halte den Button. Mein es ernst.';

  @override
  String get obCommitHold => 'Halten zum\nVersprechen';

  @override
  String get obCommitFreedomLabel => '🏆 FREIHEITSTAG';

  @override
  String obCommitDaysOut(int days) {
    return '$days Tage ab heute. Steht im Kalender.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 Wir verkaufen nie deine Daten. Keine Tracker. Niemals.';

  @override
  String get obRatingTitle =>
      'Die Bewertung eines Ex-Vapers hilft dem nächsten, uns zu finden.';

  @override
  String get obRatingSubtitle => '30 Sekunden. Überspringbar. Kein Groll.';

  @override
  String get obRatingBetaTester => 'BETA-TESTER';

  @override
  String get obRatingQuote1 =>
      '„Der Panik-Button hat mich durch Woche eins getragen. Ohne ihn wäre ich an Tag 3 eingeknickt.“';

  @override
  String get obRatingQuote2 =>
      '„Die erste App, die nicht mit mir redet wie ein Arzt oder meine Mutter.“';

  @override
  String get obRatingCta => 'Cirrus bewerten';

  @override
  String obCoachNameTitle(String name) {
    return 'Wir nennen es $name.';
  }

  @override
  String get obCoachNameSubtitle =>
      'Dein Coach. Hat vor zwei Jahren aufgehört, weiß noch genau, wie es sich anfühlt, und hat deinen Plan schon gelesen.';

  @override
  String obCoachNameAsk(String name) {
    return 'Wir haben $name gewählt, weil es einen Namen brauchte. Aber niemand merkt sich einen Namen, den jemand anderes ausgesucht hat — wenn dir also ein besserer einfällt, nimm ihn. Den, den du um 2 Uhr nachts wirklich schreiben würdest, mitten in der Diskussion mit dir selbst in der Küche.';
  }

  @override
  String get obCoachNameFieldLabel => 'Name des Coachs';

  @override
  String get obCoachNameSuggestions => 'Oder nimm einen davon:';

  @override
  String obCoachNameKeep(String name) {
    return '$name behalten';
  }

  @override
  String get obCoachNameCta => 'Der ist es';

  @override
  String get obCoachNameLater =>
      'Du kannst das jederzeit in den Einstellungen ändern.';

  @override
  String get obCoachNameErrorEmpty => 'Gib ihm einen Namen.';

  @override
  String get obCoachNameErrorLong => 'Höchstens 20 Zeichen.';

  @override
  String get obCoachNameErrorChars =>
      'Nur Buchstaben, Zahlen, Leerzeichen und - \'.';

  @override
  String get obCoachNameErrorRejected => 'Nimm lieber einen anderen.';

  @override
  String get settingsCoachName => 'Der Name deines Coachs';

  @override
  String coachRenamed(String name) {
    return 'Alles klar — ab jetzt $name.';
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
    return 'Erzähl $name eine Sache.';
  }

  @override
  String get obWhyWordsSubtitle =>
      'Warum jetzt? Nicht die Broschüren-Antwort — die echte.';

  @override
  String get obWhyWordsFieldLabel => 'In deinen eigenen Worten';

  @override
  String get obWhyWordsHint =>
      'damit ich mit ihr laufen kann, ohne stehen zu bleiben';

  @override
  String obWhyWordsNote(String name) {
    return '$name wird sich daran erinnern.';
  }

  @override
  String get obWhyWordsErrorLong => 'Bleib bei höchstens 200 Zeichen.';

  @override
  String get obWhyWordsCta => 'Darum geht es';

  @override
  String get obWhyWordsSkip => 'Überspringen';

  @override
  String get obNotifTitle => 'Rückendeckung, genau wenn du einknickst.';

  @override
  String get obNotifSubtitle =>
      'Kein Spam. Ein Stups vor deinen Gefahrenstunden, einer bei jedem Meilenstein.';

  @override
  String get obNotifPreviewTime => 'Fr 21:54';

  @override
  String get obNotifPreviewBody =>
      'Achtung — Freitagabend ist dein Hoch. Der Plan steht 💪';

  @override
  String get obNotifBullet1 => 'Gefahrenstunden-Warnung (du setzt die Zeiten)';

  @override
  String get obNotifBullet2 => 'Serien- und Meilenstein-Feiern';

  @override
  String get obNotifBullet3 => 'SOS-Pings deines Buddys — sonst nichts';

  @override
  String get obNotifCta => 'Rückendeckung aktivieren';

  @override
  String get paywallTitle => 'Dein Plan steht.';

  @override
  String get paywallSubtitle => 'Teste alles 3 Tage gratis.';

  @override
  String get paywallFeatCoach => 'KI-Coach, unbegrenzt';

  @override
  String get paywallFeatPanic => 'Panik-Button + Buddy-Ping';

  @override
  String get paywallFeatPlan => 'Adaptiver Plan';

  @override
  String get paywallFeatForecasts => 'Craving-Vorhersagen';

  @override
  String get paywallFeatCommunity => 'Community';

  @override
  String get paywallFeatReports => 'Wochenberichte';

  @override
  String get paywallYearly => 'JÄHRLICH';

  @override
  String get paywallYearlyBadge => 'BESTER DEAL';

  @override
  String get paywallYearlySub => '0,77 \$/Woche · SPARE 74%';

  @override
  String get paywallMonthly => 'MONATLICH';

  @override
  String get paywallWeekly => 'WÖCHENTLICH';

  @override
  String get paywallWeeklySub => 'Gründerpreis — für immer fixiert';

  @override
  String get paywallTrialReminder =>
      '🔔 Wir erinnern dich, bevor dein Test endet';

  @override
  String get paywallCancelAnytime => 'Jederzeit kündbar';

  @override
  String get paywallAnchor => 'Weniger als eine Einweg-Vape pro Woche';

  @override
  String get paywallCta => 'Meine 3 Gratistage starten';

  @override
  String get paywallFreeLink => 'Mit dem Gratis-Plan weitermachen →';

  @override
  String get freePlanTitle => 'Gratis bringt dich ins Rollen.';

  @override
  String get freePlanSubtitle =>
      'Für immer deins. Kein Countdown, kein Genörgel.';

  @override
  String get freePlanFeat1 => 'Zug-Log + Serien';

  @override
  String get freePlanFeat2 => 'Spar-Ticker';

  @override
  String get freePlanFeat3 => '5 Coach-Nachrichten am Tag';

  @override
  String get freePlanFeat4 => '1 Panik-Button-Session am Tag';

  @override
  String get freePlanFeat5 => 'Community (lesen + reagieren)';

  @override
  String get freePlanUpgradeNote =>
      'Upgrade jederzeit — Serie und Verlauf ziehen mit.';

  @override
  String get freePlanCta => 'Mit Gratis starten';

  @override
  String get winbackBadge => 'EINMALIGES GRÜNDER-ANGEBOT';

  @override
  String get winbackTitle => 'Okay — der erste Monat geht auf uns. Fast.';

  @override
  String get winbackSubtitle =>
      'Den Plan hast du gebaut. Teste das volle Toolkit einen Monat, bevor du entscheidest.';

  @override
  String get winbackFirstMonth => 'erster Monat';

  @override
  String winbackNote(String price) {
    return 'Danach $price/Monat. Jederzeit kündbar. Wird einmal gezeigt, nie wieder.';
  }

  @override
  String get winbackCta => 'Gründermonat sichern';

  @override
  String get winbackDecline => 'Nein danke, Gratis reicht mir';

  @override
  String get day1Title => 'Tag 1. Los geht\'s.';

  @override
  String get day1Subtitle =>
      'Drei Setup-Schritte. Zwei Minuten. Danach macht die App ihren Job.';

  @override
  String get day1Task1 => 'Logg deinen ersten Zug';

  @override
  String get day1Task1Done => 'erledigt — ehrlich ab Zug eins';

  @override
  String get day1Task1Sub => 'ein ehrlicher Tipp auf den großen Button';

  @override
  String get day1Task2 => 'Triff deinen Coach';

  @override
  String get day1Task2Sub => '30-Sek-Hallo. Er kennt deine Trigger schon.';

  @override
  String get day1Task3 => 'Setz deine Gefahrenstunden';

  @override
  String get day1Task3Sub => 'wann knickst du ein? wir sind früher da';

  @override
  String get day1Skip => 'Einrichtung vorerst überspringen';

  @override
  String get day1TourLogTitle => 'Das ist die ganze App.';

  @override
  String get day1TourLogBody =>
      'Jeder Zug, hier getippt. Nur ehrliche Zahlen machen den Plan echt — leg jetzt einen an.';

  @override
  String get day1TourCoachTitle => 'Sag irgendwas.';

  @override
  String day1TourCoachBody(String name) {
    return '$name hat deinen Plan schon gelesen — deine Zahlen, deine Auslöser, deine schweren Stunden. Schreib mal Hallo.';
  }

  @override
  String get day1TourHoursTitle => 'Wann wirst du schwach?';

  @override
  String get day1TourHoursBody =>
      'Wähl das Zeitfenster, das dir schwerfällt. Wir melden uns zehn Minuten vorher, ungefragt.';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Freiheitstag: $date · in $days Tagen · Plan scharf';
  }

  @override
  String get day1CtaCoach => 'Coach kennenlernen';

  @override
  String get day1CtaHome => 'Zu Heute';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Tag $day von $total';
  }

  @override
  String get homeTitle => 'Heute';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count Tage',
      one: '🔥 $count Tag',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'Züge heute';

  @override
  String homeOfLimit(int limit) {
    return 'von $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return '$count unter deiner heutigen Linie. Du bist deiner Kurve voraus.';
  }

  @override
  String homeLeftTight(int count) {
    return 'Noch $count auf deiner heutigen Linie. Knapp — du schaffst das.';
  }

  @override
  String homeVsDay1(String percent) {
    return '$percent vs. Tag 1';
  }

  @override
  String get homeSavedSoFar => 'bisher gespart';

  @override
  String get homeCravingsBeaten => 'Cravings besiegt';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return 'Harter $weekday? Hab\'s gesehen.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'Dein $hour-Hoch steht an — Plan gefällig?';
  }

  @override
  String get homeLogPuff => 'ZUG LOGGEN';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => 'Heute keine Züge?';

  @override
  String get homeVapeFreeCta => 'Dampffreien Tag bestätigen ✓';

  @override
  String get homeVapeFreeDone =>
      'Dampffreier Tag gesichert. Das ist das ganze Spiel. 🔥';

  @override
  String homeLoggedSnackCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Züge geloggt',
      one: '1 Zug geloggt',
    );
    return '$_temp0';
  }

  @override
  String get homeOverLimitTitle => 'Über deiner Linie';

  @override
  String get homeOverLimitBody =>
      'Atme — die Linie von morgen passt sich an. Keine Scham.';

  @override
  String get homeOverLimitBreathe => '60s atmen';

  @override
  String get homeOverLimitCoach => 'Mit Coach reden';

  @override
  String get homeOverLimitFooter =>
      'Logg weiter ehrlich — die Daten sind das ganze Spiel.';

  @override
  String get homeTokenUsedNote =>
      'Reparatur-Token eingesetzt — deine Serie überlebt. Die Flamme dimmt heute, sie erlischt nicht.';

  @override
  String get navHome => 'Start';

  @override
  String get navStats => 'Statistik';

  @override
  String get navCommunity => 'Community';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'PANIK-MODUS · $step VON 3';
  }

  @override
  String get panicBreatheNote =>
      'dieses Gefühl peakt und vergeht — die meisten Cravings sterben in 15 Min.';

  @override
  String get panicBreatheIn => 'Ein…';

  @override
  String get panicBreatheHold => 'Halten…';

  @override
  String get panicBreatheOut => 'Aus…';

  @override
  String get panicBreathePattern => 'Ein 4 · Halten 7 · Aus 8';

  @override
  String panicCravingTimer(String time) {
    return 'Craving-Timer · $time · Peak ~15 Min.';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'Craving-Timer · $time · das Schlimmste ist vorbei';
  }

  @override
  String get panicSkipToWhy => 'Zu meinem Warum →';

  @override
  String get panicWhyTitle => 'Erinnere dich, warum du angefangen hast.';

  @override
  String get panicYouSaid => 'DU SAGTEST';

  @override
  String panicWhyLine(String why, String amount) {
    return 'Du machst das für deine $why und die $amount pro Jahr, die du dir zurückholst.';
  }

  @override
  String get panicIntensityQuestion => 'Wie schlimm ist es gerade?';

  @override
  String get panicIntensityLow => 'geht so';

  @override
  String get panicIntensityHigh => 'schreit';

  @override
  String get panicStillCraving => 'Craving hält an — weiter';

  @override
  String get panicItPassed => 'Vorbei 🎉 alles gut';

  @override
  String get panicLoopTitle => 'Durchbrich die Schleife.';

  @override
  String get panicLoopSubtitle =>
      'Deine Hände und dein Kopf brauchen 60 Sekunden einen Job. Wähl einen.';

  @override
  String get panicLoopGame => '60-Sekunden-Spiel';

  @override
  String get panicLoopGameSub =>
      'besetzt genau das Jucken — Daumen beschäftigt, Kopf beschäftigt';

  @override
  String get panicLoopSos => 'Frag die Community';

  @override
  String get panicLoopSosSub =>
      'poste ein SOS — es steht eine Stunde ganz oben';

  @override
  String get panicLoopCoach => 'Mit Coach reden';

  @override
  String panicLoopCoachSub(String hour) {
    return 'er kennt dein $hour-Stressmuster';
  }

  @override
  String get panicLoopCoachLocked =>
      'deine kostenlose KI-Sitzung heute ist aufgebraucht';

  @override
  String get gameTitle => 'Fang jeden Funken';

  @override
  String get gameSubtitle =>
      '60 Sekunden. Daumen beschäftigt, Kopf beschäftigt.';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get survivedPlusOne => '+1 Craving besiegt';

  @override
  String get survivedLine1 => 'Das hatte keine Chance gegen dich.';

  @override
  String get survivedLine2 => 'Die Welle ist gebrochen. Du nicht.';

  @override
  String get survivedLine3 => '15 Minuten Mut. Für immer verbucht.';

  @override
  String get survivedLine4 => 'Dein Gehirn weiß jetzt, wer der Boss ist.';

  @override
  String get survivedLine5 => 'Craving 0 — du 1. Schon wieder.';

  @override
  String get survivedLine6 => 'Immer noch frei. Immer noch dabei.';

  @override
  String get survivedLine7 =>
      'Dieses Jucken hat gerade dein Zukunfts-Ich bezahlt.';

  @override
  String get survivedLine8 => 'Eiskalt. Auf die gute Art.';

  @override
  String get survivedTotalLabel => 'Cravings insgesamt überstanden';

  @override
  String get survivedShare => 'Den Win teilen ↗';

  @override
  String get survivedBack => 'Zurück zu heute';

  @override
  String get survivedShareCopied =>
      'Statistik-Karte kopiert — füg sie ein, wo du willst.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● kennt deinen Plan · Tag $day';
  }

  @override
  String get coachChipCraving => 'Ich habe ein Craving';

  @override
  String get coachChipRoughDay => 'Harter Tag';

  @override
  String get coachChipSlipped => 'Bin ausgerutscht';

  @override
  String get coachChipProgress => 'Zeig meinen Fortschritt';

  @override
  String get coachInputHint => 'Schreib deinem Coach…';

  @override
  String coachTyping(String name) {
    return '$name tippt…';
  }

  @override
  String coachTimeYesterday(String time) {
    return 'Gestern · $time';
  }

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Gratis-Nachrichten heute',
      one: '$count Gratis-Nachricht heute',
    );
    return '$_temp0';
  }

  @override
  String get coachCapReached =>
      'Das waren meine 5 Gratis-Nachrichten für heute — um Mitternacht bin ich zurück. Willst du mich rund um die Uhr? Genau das ist Premium.';

  @override
  String get coachConnectionLost =>
      'Die Verbindung ist mitten im Gedanken abgerissen 😅 Ich bin noch da — sag\'s nochmal, wenn du wieder online bist?';

  @override
  String get coachBackendRejected =>
      'Okay, das liegt an uns — der Server hat die App nicht erkannt, deine Nachricht kam nie an. Nicht deine Verbindung, nicht du. Wir kümmern uns.';

  @override
  String get errorOfflineBanner =>
      'offline — deine Logs zählen, wir syncen später';

  @override
  String get errorOfflineTitle => 'Kein WLAN, kein Stress';

  @override
  String get errorOfflineBody =>
      'Du bist gerade offline. Nichts geht verloren — verbinde dich neu und wir machen genau da weiter.';

  @override
  String get errorGenericTitle => 'Ups, das hat gehakt';

  @override
  String get errorGenericBody =>
      'Liegt an uns, nicht an dir. Probier\'s gleich nochmal.';

  @override
  String get errorRejectedTitle => 'Dieser Build wurde abgelehnt';

  @override
  String get errorRejectedBody =>
      'Deine Verbindung ist okay — unsere Seite hat die App nur nicht erkannt. Kannst du nicht beheben, und nichts Protokolliertes geht verloren.';

  @override
  String get errorRetry => 'Nochmal';

  @override
  String get errorGotIt => 'Alles klar';

  @override
  String get errorFeedTitle => 'Der Feed lässt uns hängen';

  @override
  String get errorFeedBody =>
      'Die Community war nicht erreichbar. Check dein Netz und probier\'s nochmal.';

  @override
  String get errorRouteTitle => 'Diese Seite gibt\'s nicht';

  @override
  String get errorRouteBody =>
      'Was du gesucht hast, ist nicht hier. Zurück zum Wesentlichen.';

  @override
  String get errorRouteCta => 'Bring mich nach Hause';

  @override
  String get errorBackstage =>
      'hinter den Kulissen hat was gehakt — du kannst ganz normal weitermachen';

  @override
  String get coachWeekCardLabel => 'DEINE WOCHE';

  @override
  String coachWeekCardCaption(String day) {
    return 'Abwärtstrend — $day war der harte Tag';
  }

  @override
  String coachGreeting(String name, int puffs, String method, String date) {
    return 'Hey. Ich bin $name — ich hab vor zwei Jahren aufgehört und weiß noch genau, wie es sich anfühlt. Deinen Plan hab ich gelesen: $puffs am Tag, $method, Freiheitstag am $date. Vorträge gibt\'s von mir nie. Was ist gerade los?';
  }

  @override
  String get coachReplyCraving1 =>
      'Diese Welle ist brutal, ich weiß. In 15 Minuten bricht sie — das ist kein Zuspruch, das ist Biologie. Kaltes Wasser auf die Handgelenke, und bleib bei mir. Was hat sie ausgelöst?';

  @override
  String coachReplyCraving2(int count) {
    return 'Okay. Atme eine Runde mit mir — ein 4, halten 7, aus 8. Cravings sterben meist in 15–20 Minuten. Du hast schon $count besiegt. Das hier ist keins anders.';
  }

  @override
  String get coachReplyCraving3 =>
      'Verstanden. Diskutier nicht mit dem Craving, überdauere es. Geh einen Block oder starte das 60-Sekunden-Spiel. Es peakt und stirbt — maximal 15 Minuten.';

  @override
  String coachReplyRough1(int percent) {
    return 'Fair. An harten Tagen schreit die alte Gewohnheit am lautesten. Deal: 10 Min. Spaziergang vor dem nächsten. Wenn du ihn danach noch willst, logg ihn ehrlich — du liegst immer noch $percent% unter deiner Basis.';
  }

  @override
  String get coachReplyRough2 =>
      'Klingt schwer. Du musst heute nichts reparieren, nur durchkommen — und das geht ohne Nikotin. Ich bin so oder so hier.';

  @override
  String coachReplySlip1(int count) {
    return 'Ein Ausrutscher ist Information, keine Niederlage. Was war der Auslöser — Stress, Leute, Langeweile? Der Plan hat sich schon gebogen, um dich aufzufangen. Deine $count Tage zählen weiter.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Null Scham hier. Die meisten, die es endgültig schaffen, sind unterwegs ausgerutscht. Ehrlich loggen, Auslöser finden, weiter. Deine Bilanz bleibt deine: $amount gespart, längste Serie intakt.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Schau auf die echten Zahlen: Tag $day, $saved zurück in deiner Tasche, $cravings Cravings besiegt. Das Tag-1-Du hätte heute nicht geschafft. Das ist real.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today Züge heute gegen eine Linie von $limit. Vor zwei Wochen wäre die Zahl doppelt so hoch gewesen. Du ziehst das wirklich durch.';
  }

  @override
  String get coachReplyGeneric1 =>
      'Ich hör dich. Erzähl mehr — was steckt darunter?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Macht Sinn. Falls es hilft: Du bist an Tag $day und immer noch hier. Das zählt eine Menge.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Verstanden. Eine ehrliche Frage: Ist das gerade ein Nikotin-Ding, oder das Leben in Nikotins Jacke?';

  @override
  String get coachReplyGeneric4 =>
      'Okay. Kleine Züge gewinnen das hier. Was kannst du in den nächsten 10 Minuten tun, das kein Vapen ist?';

  @override
  String coachReplyParty(int count) {
    return 'Party-Playbook: den ganzen Abend ein kaltes Getränk in der Hand, schreib mir oder deinem Buddy, sobald die erste Vape rauskommt, und leg dir deinen Abgangssatz zurecht. Du hast $count Cravings überstanden — eine Party sind nur mehrere hintereinander.';
  }

  @override
  String coachSafetyNote(String name) {
    return '$name ist ein Unterstützungstool, kein Arzt. In einer Krise? Ruf die 988 an oder texte ihr (USA & Kanada), jederzeit.';
  }

  @override
  String get planTitle => 'Dein Plan';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days Tage';
  }

  @override
  String get planMethodTaper => 'Reduktion';

  @override
  String get planMethodCold => 'Schlusspunkt';

  @override
  String planTodayMarker(int limit) {
    return 'heute · $limit/Tag';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'STEHT AN';

  @override
  String planHalfwayTitle(int day) {
    return 'Tag $day — Halbzeit';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'Linie fällt auf $limit/Tag';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Tag $day — Cravings verblassen';
  }

  @override
  String get planCravingsFadeSub => 'die meisten berichten leichtere Morgen';

  @override
  String planFreedomTitle(int day) {
    return 'Tag $day — Freiheitstag';
  }

  @override
  String get planAdjustCta => 'Plan anpassen';

  @override
  String get planAdjustNote =>
      'Tempo + Methode änderbar · kein Reset, kein verlorener Verlauf';

  @override
  String get planAdaptiveLabel => 'ANPASSUNG VON HEUTE NACHT';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'Du liegst drei Tage in Folge unter deiner Linie, also sinkt das heutige Ziel auf $limit. Schwung, keine Strafe.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'Du hältst die Linie. Das heutige Ziel bleibt bei $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'Die letzten zwei Tage lagen darüber, also biegt sich das heutige Ziel auf $limit. Eine Linie, die du halten kannst, schlägt eine, die du nicht halten kannst.';
  }

  @override
  String get planAdaptiveStretched =>
      'Der Freiheitstag rückt einen Tag nach hinten.';

  @override
  String get planAdjustSheetTitle => 'Pass deinen Plan an';

  @override
  String get planAdjustSheetNote =>
      'Die Kurve regeneriert ab heute mit deinen echten Zahlen. Der Verlauf bleibt. Der Freiheitstag verschiebt sich ehrlich.';

  @override
  String get planAdjustApply => 'Anwenden — Kurve neu berechnen';

  @override
  String planAdjusted(String date) {
    return 'Plan neu berechnet. Neuer Freiheitstag: $date';
  }

  @override
  String get statsTitle => 'Statistik';

  @override
  String get statsRangeDay => 'Tag';

  @override
  String get statsRangeWeek => 'Woche';

  @override
  String get statsRangeMonth => 'Monat';

  @override
  String get statsPuffsThisWeek => 'ZÜGE DIESE WOCHE';

  @override
  String get statsPuffsToday => 'ZÜGE HEUTE · PRO STUNDE';

  @override
  String get statsPuffsThisMonth => 'ZÜGE · LETZTE 30 TAGE';

  @override
  String statsVsLast(String percent) {
    return '$percent vs. Vorperiode';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return '$day war der schwere Tag — $reason. Am Morgen danach warst du zurück.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return '$day war der schwere Tag. Am Morgen danach warst du zurück.';
  }

  @override
  String get statsTriggerHours => 'TRIGGER-STUNDEN';

  @override
  String statsDangerWindow(String range) {
    return '$range ist dein Gefahrenfenster · Stupser dort scharf';
  }

  @override
  String get statsNicotinePerDay => 'NIKOTIN / TAG';

  @override
  String statsNicotineValue(int mg) {
    return '${mg}mg ↓';
  }

  @override
  String get statsLongestGap => 'längste Pause';

  @override
  String get statsBestDay => 'bester Tag (Züge)';

  @override
  String get statsCravingsBeaten => 'Cravings besiegt';

  @override
  String get statsEmptyTitle => 'Diagramme gibt\'s ab morgen.';

  @override
  String get statsEmptyBody =>
      'Ein Tag Daten = ein Punkt. Logg weiter — das Bild malt sich selbst.';

  @override
  String statsEditDayTitle(String date) {
    return '$date bearbeiten';
  }

  @override
  String get statsEditDayNote =>
      'Der Verlauf gehört dir. Serie und Geld rechnen ab hier neu.';

  @override
  String get statsEditHint =>
      'Balken lange drücken, um einen Tag zu korrigieren';

  @override
  String get communityTitle => 'Community';

  @override
  String communityYouAre(String alias) {
    return 'du bist $alias';
  }

  @override
  String get communityFilterAll => 'Alle';

  @override
  String get communityTagWin => '🏆 Win';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Tag 1';

  @override
  String get communityTagMilestone => 'Meilenstein';

  @override
  String get communityTagVent => 'Dampf ablassen';

  @override
  String get communityIGotYou => 'Bin da 💬';

  @override
  String communityRepliedCount(int count) {
    return '$count haben schon geantwortet';
  }

  @override
  String get communityReport => 'Melden';

  @override
  String get communityMute => 'Stummschalten';

  @override
  String get communityBlock => 'Blockieren';

  @override
  String get communityReported =>
      'Gemeldet. Wir prüfen binnen 24h — 3 Meldungen verbergen den Post.';

  @override
  String get communityBlocked => 'Blockiert. Ihr seht euch nicht mehr.';

  @override
  String get communityMuted =>
      'Stummgeschaltet. Du siehst ihre Posts nicht mehr.';

  @override
  String get communityAutoFlagged =>
      'Zur Prüfung zurückgehalten — Markennamen und Bezugsquellen sind hier tabu.';

  @override
  String get communityComposerTitle => 'Neuer Post';

  @override
  String get communityComposerPost => 'Posten';

  @override
  String communityPostingAs(String alias, int day) {
    return 'gepostet als $alias · Tag $day · immer anonym';
  }

  @override
  String get communityComposerHint => 'Was passiert in deinem Quit?';

  @override
  String get communityTagIt => 'TAGGE ES';

  @override
  String get communityKindnessNote =>
      'Sei nett — hier kämpft gerade jeder. Keine Markennamen, keine Bezugsquellen.';

  @override
  String get communityTagRequired =>
      'Wähl einen Tag — er bringt deinen Post zu den richtigen Leuten.';

  @override
  String communitySosBanner(int count) {
    return '🛡️ $count Leute waren für dich da';
  }

  @override
  String get communityAddVoice => 'Gib deine Stimme dazu…';

  @override
  String communityDayTag(int day) {
    return 'Tag $day';
  }

  @override
  String get communityEmptyTitle => 'Noch keine Posts — sag Hallo.';

  @override
  String get communityEmptyBody =>
      'Dein Tag-1-Post ist genau der, den jemand an Tag 0 lesen muss.';

  @override
  String get communityPosted =>
      'Gepostet. Ein kurzer Sicherheitscheck läuft, bevor andere es sehen.';

  @override
  String get buddyLinkCopied =>
      'Link kopiert — Aufhören mit Rückendeckung fühlt sich anders an.';

  @override
  String get moneyTitle => 'Geld zurück';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'gespart seit $date · $perDay kommen täglich rein';
  }

  @override
  String get moneyBuysLabel => 'WAS ES SCHON KAUFT';

  @override
  String moneyToGo(String amount, int days) {
    return 'noch $amount · ~$days Tage in deinem Tempo';
  }

  @override
  String moneyToGoShort(String amount) {
    return 'noch $amount';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'das aus deinem Check-up · noch $amount';
  }

  @override
  String get moneySetGoal => 'Ziel anlegen';

  @override
  String get moneySetGoalSub =>
      'benennen, bepreisen, Balken beim Füllen zusehen';

  @override
  String get moneyGoalSheetTitle => 'Neues Sparziel';

  @override
  String get moneyGoalNameHint => 'Benenn es — „PS5“, „Lissabon“, „Schlagzeug“';

  @override
  String get moneyGoalPriceHint => 'Preis';

  @override
  String get moneyGoalCreate => 'Balken starten';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'Die Rechnung gehört dir: $weekly/Woche × 52 = $yearly/Jahr. Nichts erfunden.';
  }

  @override
  String get moneyGoalDone => 'Ziel finanziert. Konfetti verdient. 🎉';

  @override
  String get seedGoalKicks => 'Neue Sneaker';

  @override
  String get seedGoalTokyo => 'Flug nach Tokio';

  @override
  String get healthTitle => 'Dein Körper heilt';

  @override
  String healthAnchor(String ago) {
    return 'Basierend auf deinem letzten geloggten Zug · vor $ago';
  }

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — du bist hier';
  }

  @override
  String get healthM20min => '20 Minuten';

  @override
  String get healthM20minBody => 'Puls und Blutdruck fallen zurück auf Normal.';

  @override
  String get healthM8h => '8 Stunden';

  @override
  String get healthM8hBody =>
      'Der Sauerstoff normalisiert sich, während das Nikotin sinkt.';

  @override
  String get healthM12h => '12 Stunden';

  @override
  String get healthM12hBody =>
      'Das Kohlenmonoxid in deinem Blut sinkt auf Normalniveau.';

  @override
  String get healthM24h => '24 Stunden';

  @override
  String get healthM24hBody =>
      'Nikotin fällt schnell. Die Cravings werden laut — das ist die Ausgangstür.';

  @override
  String get healthM48h => '48 Stunden';

  @override
  String get healthM48hBody =>
      'Nervenenden wachsen nach. Geschmack und Geruch schärfen sich.';

  @override
  String get healthM72h => '72 Stunden';

  @override
  String get healthM72hBody =>
      'Nikotin ist ~weg. Craving-Peak — genau dafür lebt der Panik-Button.';

  @override
  String get healthM1w => '1 Woche';

  @override
  String get healthM1wBody =>
      'Geschmack und Geruch merklich schärfer. Atmen fühlt sich leichter an.';

  @override
  String get healthM2w => '2 Wochen';

  @override
  String get healthM2wBody =>
      'Die Durchblutung verbessert sich. Die Lungenfunktion beginnt zu klettern.';

  @override
  String get healthM1m => '1 Monat';

  @override
  String get healthM1mBody => 'Husten und Kurzatmigkeit lassen nach.';

  @override
  String get healthM3m => '3 Monate';

  @override
  String get healthM3mBody =>
      'Die Lungenkapazität klettert weiter. Das Gym fühlt sich anders an.';

  @override
  String get healthM6m => '6 Monate';

  @override
  String get healthM6mBody =>
      'Dein Stress-Grundpegel sinkt — schlechte Tage gehen auch ohne.';

  @override
  String get healthM1y => '1 Jahr';

  @override
  String get healthM1yBody =>
      'Dein Risikoprofil sieht aus wie das von jemandem, der nie täglich gedampft hat.';

  @override
  String get healthUnlockNote =>
      'Jede Freischaltung feuert eine kleine Feier + optionale Share-Karte.';

  @override
  String get healthSourceNote =>
      'Basiert auf Rauchstopp-Forschung — die Evidenz zum Dampfen entsteht noch.';

  @override
  String get milestonesTitle => 'Meilensteine';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned von $total verdient';
  }

  @override
  String milestonesNext(String name) {
    return 'Als Nächstes: $name';
  }

  @override
  String milestonesNextProgress(int day, int target) {
    return 'Tag $day von $target · noch zwei Sonnenaufgänge';
  }

  @override
  String get milestonesNotLeaderboard =>
      'Die Abzeichen gehören dir, kein Ranking. Kein fremdes Raster zum Vergleichen.';

  @override
  String get mFirstLog => 'Erster Log';

  @override
  String get mFirstCraving => 'Erstes Craving besiegt';

  @override
  String get mSpark => '3-Tage-Funke';

  @override
  String get mWeekFlame => '7-Tage-Flamme';

  @override
  String get mHundredSaved => '100 \$ gespart';

  @override
  String get mCleanWeekend => 'Cleanes Wochenende';

  @override
  String get mHelpedSos => 'Bei einem SOS geholfen';

  @override
  String get mTwoWeekFlame => 'Zwei-Wochen-Flamme';

  @override
  String get mHalfNicotine => 'Halbes Nikotin';

  @override
  String get mMoodWeek => 'Stimmungs-Woche';

  @override
  String get mTenCravings => '10 Cravings besiegt';

  @override
  String get mQuarterCurve => 'Viertel der Kurve';

  @override
  String get mInferno => '30-Tage-Inferno';

  @override
  String get mFreedomDay => 'Freiheitstag';

  @override
  String get mFirstPost => 'Erster Post';

  @override
  String get mFiveHundredSaved => '500 \$ gespart';

  @override
  String get mComeback => 'Comeback';

  @override
  String get moodTitle => 'Wie fühlt sich heute an?';

  @override
  String get moodSubtitle => '10 Sekunden. Zählt mehr, als du denkst.';

  @override
  String get moodRough => 'rau';

  @override
  String get moodMeh => 'meh';

  @override
  String get moodOkay => 'okay';

  @override
  String get moodGood => 'gut';

  @override
  String get moodGreat => 'super';

  @override
  String get moodNoteHint =>
      'Eine Zeile, optional — „Firmenfeier heute, nervös“';

  @override
  String get moodUnlockTitle => '🔓 Stimmung ↔ Craving-Link';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total Check-ins';
  }

  @override
  String moodUnlockNote(int count) {
    return 'Noch $count, und dein Bericht zeigt, wie Stimmung deine Cravings treibt.';
  }

  @override
  String get moodCta => 'Einchecken';

  @override
  String get moodSaved => 'Notiert. Daten schlagen Bauchgefühl. 🙌';

  @override
  String get insightLinkTitle => 'Wochenbericht';

  @override
  String insightTitle(int week, String range) {
    return 'Bericht Woche $week · $range';
  }

  @override
  String get insightWinLabel => 'Dein Erfolg';

  @override
  String get insightWatchoutLabel => 'Achtung';

  @override
  String get insightWeekChartLabel => 'ZÜGE, LETZTE 7 TAGE';

  @override
  String get insightCravingsChartLabel =>
      'ÜBERSTANDENE VERLANGEN, LETZTE 7 TAGE';

  @override
  String get insightHoursChartLabel => 'ZÜGE NACH STUNDE, LETZTE 14 TAGE';

  @override
  String get insightPendingTitle => 'Noch kein Bericht';

  @override
  String insightPendingBody(String name) {
    return '$name schreibt jeden Sonntag einen — aus der Woche, die du wirklich protokolliert hast: deine Stunden, deine Stimmungen, deine Erfolge. Bis es eine Woche zu lesen gibt, gibt es nichts zu zeigen.';
  }

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index VON $total';
  }

  @override
  String get slipTitle => 'Ein Ausrutscher ist Information, keine Niederlage.';

  @override
  String slipSubtitle(int days) {
    return 'Du hast nach $days cleanen Tagen Züge geloggt. Das ist Information — sie zeigt genau, wo der Plan Panzerung braucht.';
  }

  @override
  String get slipWhatHappened => 'WAS WAR LOS?';

  @override
  String get slipTriggerParty => 'Party';

  @override
  String get slipTriggerStress => 'Stress';

  @override
  String get slipTriggerBoredom => 'Langeweile';

  @override
  String get slipTriggerDrinking => 'Alkohol';

  @override
  String get slipTriggerFriends => 'Freunde hatten eine';

  @override
  String get slipTriggerJustHappened => 'Ist einfach passiert';

  @override
  String get slipNoBannedWords =>
      'Hier gibt es nie verbotene Wörter. Die meisten, die es endgültig schaffen, sind unterwegs ausgerutscht. Das Log bleibt ehrlich, der Plan passt sich an.';

  @override
  String get slipAdjustCta => 'Plan anpassen';

  @override
  String get slipAdjustTitle => 'Hier ist die Anpassung.';

  @override
  String get slipCurveLabel => 'DEINE KURVE — SANFT NEU BERECHNET';

  @override
  String get slipTheBump => 'die Ausrutscher-Beule';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Freiheitstag: $date (+$days Tage)';
  }

  @override
  String get slipCurveNote =>
      'Zwei Extra-Tage, gleiches Ziel. Partynächte bekommen einen vorgeplanten Stups + Spiel-Shortcut.';

  @override
  String slipStreakSurvives(int days) {
    return 'Deine $days Tage zählen weiter.';
  }

  @override
  String get slipFlameDims =>
      'Die Flamme dimmt, sie stirbt nicht. Ein cleaner Tag bringt sie zurück auf volle Kraft.';

  @override
  String get slipBackOnCurve => 'Zurück auf die Kurve';

  @override
  String get slipTalkFirst => 'Erst mit dem Coach durchsprechen';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'am Aufhören seit $date · $method · Tag $day';
  }

  @override
  String get profileCountdownLabel => '🏆 FREIHEITSTAG-COUNTDOWN';

  @override
  String profileDaysTo(String date) {
    return 'Tage bis zum $date';
  }

  @override
  String get profileLifetimeSaved => 'insgesamt gespart';

  @override
  String get profilePuffsNotTaken => 'Züge nicht genommen';

  @override
  String get profileBadgesEarned => 'Abzeichen verdient';

  @override
  String get profileSettings => '⚙️ Einstellungen';

  @override
  String get profileEditAlias => 'Wähl deinen Alias';

  @override
  String get profileEditAvatar => 'Wähl deinen Avatar';

  @override
  String get profileAliasHint => 'anonym — mehr sieht niemand';

  @override
  String memoriesTitle(String name) {
    return 'Woran $name sich erinnert';
  }

  @override
  String memoriesIntro(String name) {
    return 'Was $name über dich weiß: dein Setup und deine Live-Zahlen aus der App, plus die Dinge, die du im Chat erzählt hast — die kannst du jederzeit vergessen lassen.';
  }

  @override
  String memoriesEmpty(String name) {
    return 'Hier ist noch nichts. Dieser Teil füllt sich, wenn du $name im Chat aus deinem Leben erzählst.';
  }

  @override
  String memoriesSectionKnows(String name) {
    return 'Was $name immer weiß';
  }

  @override
  String memoriesSectionTold(String name) {
    return 'Was du $name erzählt hast';
  }

  @override
  String get memoriesFactPlan => 'Plan';

  @override
  String memoriesFactPlanValue(String method, int days) {
    return '$method · $days Tage';
  }

  @override
  String get memoriesFactStarted => 'Start';

  @override
  String get memoriesFactBaseline => 'Ausgangswert';

  @override
  String memoriesFactBaselineValue(int count) {
    return '$count Züge pro Tag';
  }

  @override
  String get memoriesFactWhy => 'Dein Warum';

  @override
  String get memoriesFactWorries => 'Deine Sorgen';

  @override
  String get memoriesFactWhyWords => 'In deinen Worten';

  @override
  String get memoriesFactFirstPuff => 'Erster Zug nach dem Aufwachen';

  @override
  String get memoriesFactFrequency => 'Wie oft';

  @override
  String get memoriesFactDay => 'Wo du stehst';

  @override
  String memoriesFactDayValue(int day, int total) {
    return 'Tag $day von $total';
  }

  @override
  String get memoriesFactToday => 'Heute';

  @override
  String memoriesFactTodayValue(int puffs, int limit) {
    return '$puffs von $limit Zügen';
  }

  @override
  String get memoriesFactStreak => 'Serie';

  @override
  String get memoriesFactSaved => 'Gespartes Geld';

  @override
  String get memoriesFailed => 'Konnte gerade nicht geladen werden.';

  @override
  String get memoriesForget => 'Das vergessen';

  @override
  String memoriesForgotten(String name) {
    return 'Vergessen. $name bringt es nicht wieder auf.';
  }

  @override
  String get memoriesForgetFailed =>
      'Das ging nicht durch — es ist noch gespeichert.';

  @override
  String get memoriesKindPerson => 'Jemand in deinem Leben';

  @override
  String get memoriesKindTrigger => 'Ein Auslöser';

  @override
  String get memoriesKindMotivation => 'Warum du das machst';

  @override
  String get memoriesKindMilestone => 'Worauf du hinarbeitest';

  @override
  String get memoriesKindPreference => 'Wie du angesprochen werden willst';

  @override
  String get memoriesKindContext => 'Über dich';

  @override
  String settingsMemories(String name) {
    return 'Woran $name sich erinnert';
  }

  @override
  String get moderationTitle => 'Prüfliste';

  @override
  String get moderationEmpty => 'Nichts offen. Alle Meldungen sind geprüft.';

  @override
  String get moderationFailed => 'Die Liste ließ sich nicht öffnen.';

  @override
  String get moderationRetry => 'Erneut versuchen';

  @override
  String get moderationShowReviewed => 'Geprüfte anzeigen';

  @override
  String moderationPendingCount(int count) {
    return '$count offen';
  }

  @override
  String get moderationSubjectGone =>
      'Der Beitrag ist weg; nur die Meldung ist geblieben.';

  @override
  String get moderationAllow => 'Freigeben';

  @override
  String get moderationBlock => 'Sperren';

  @override
  String get moderationDismiss => 'Alles in Ordnung';

  @override
  String get moderationResolveFailed =>
      'Das ging nicht durch. Der Beitrag ist unverändert.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsAccount => 'Konto';

  @override
  String get settingsSubscription => 'Abo verwalten';

  @override
  String get settingsSubscriptionValue => 'Premium · jährlich';

  @override
  String get settingsSubscriptionFree => 'Gratis-Plan';

  @override
  String get settingsNotifications => 'Mitteilungen';

  @override
  String get settingsDangerHours => 'Gefahrenstunden';

  @override
  String settingsDangerHoursEdit(String range) {
    return '$range · ändern ›';
  }

  @override
  String get settingsPrivacy => 'Datenschutz';

  @override
  String get settingsPrivacyNote =>
      'Wir verkaufen nie deine Daten. Keine Tracker. Niemals.';

  @override
  String get settingsDeleteEverything => 'Alles löschen';

  @override
  String get settingsDeleteConfirmTitle => 'Alles löschen?';

  @override
  String get settingsDeleteConfirmBody =>
      'Dein Plan, Logs, Serie und Posts — endgültig weg. Das ist der eine Button, den wir nicht rückgängig machen können.';

  @override
  String get settingsDeleteConfirmCta => 'Ja, alles löschen';

  @override
  String get settingsAppearance => 'Erscheinungsbild';

  @override
  String get settingsAppearanceSystem => 'Wie das System';

  @override
  String get settingsAppearanceMidnight => 'Midnight';

  @override
  String get settingsAppearanceDaylight => 'Daylight';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get settingsLanguageSystem => 'Wie das System';

  @override
  String get settingsSignOut => 'Abmelden';

  @override
  String get settingsSignOutConfirmTitle => 'Abmelden?';

  @override
  String get settingsSignOutConfirmBody =>
      'Deine Daten bleiben auf deinem Konto. Die Serie brennt weiter.';

  @override
  String get settingsDangerHoursTitle => 'Gefahrenstunden';

  @override
  String get settingsDangerHoursNote =>
      'Wir stupsen dich 10 Minuten, bevor dein Fenster öffnet. Max. 3 Pushes am Tag, Ruhezeiten respektiert.';

  @override
  String settingsQuietHours(String range) {
    return 'Ruhezeiten: $range';
  }

  @override
  String get trialEndingPushTime => 'jetzt';

  @override
  String get trialEndingPush =>
      'dein Test endet morgen — wie versprochen, hier die Erinnerung. Keine Überraschungsabbuchung.';

  @override
  String get trialEndingTitle => 'Der Test endet morgen.';

  @override
  String get trialEndingBody =>
      'Wir haben gesagt, wir erinnern dich, also: hier ist sie. Behalte Premium oder wechsle zu Gratis — Serie, Plan und Verlauf bleiben so oder so.';

  @override
  String get trialEndingStatsLabel => 'DEINE 3 TAGE BISHER';

  @override
  String get trialEndingVsDay1 => 'Züge vs. Tag 1';

  @override
  String get trialEndingCravings => 'Cravings besiegt';

  @override
  String get trialEndingSaved => 'gespart';

  @override
  String trialEndingKeep(String price) {
    return 'Premium behalten — $price/Jahr';
  }

  @override
  String get trialEndingSwitchFree => 'Zu Gratis wechseln (Daten bleiben)';

  @override
  String get frameMapTitle => 'Alle 52 Design-Frames';

  @override
  String get frameMapOpen => 'Alle 52 Screens ansehen →';

  @override
  String get frameMapNote =>
      'Jeder Frame aus den vier Handoffs, einen Tipp entfernt. Zeilen laden bei Bedarf die Demo-Reise oder Quiz-Antworten.';

  @override
  String get frameMapEdgeNote =>
      'Diese Zustände gehen mit dem Backend live — eine In-Memory-App hat ehrlicherweise kein Offline und keine Serverfehler.';

  @override
  String get seedPostWin30 =>
      'FREIHEITSTAG. 30 Tage, null Züge in der letzten Woche. Der Panik-Button hat mich durch die Wochenenden getragen. Wenn du an Tag 2 bist und stirbst — ab Tag 8 wird es wirklich leichter.';

  @override
  String get seedPostSos =>
      'vor der Tankstelle. Geldbeutel in der Hand. redet es mir bitte jemand aus';

  @override
  String get seedPostDay1 =>
      'hab meine in den See geworfen. wahrscheinlich schlecht für den See. Tag 1 beginnt jetzt';

  @override
  String get seedPostVent =>
      'mein Kollege bläst DEN GANZEN TAG Mango-Wolken an seinem Platz und ich soll mich… konzentrieren? ich lasse Dampf ab, damit ich nicht einknicke';

  @override
  String get seedPostMilestone =>
      'zwei Wochen. heute die Treppe bis in den 4. Stock genommen, ohne wie ein verfluchtes Akkordeon zu klingen. kleine Siege';

  @override
  String get seedPostWinParty =>
      'eine ganze Party überstanden, ohne irgendwem die Vape abzuschwatzen. meine Hände haben überlebt, weil sie wie ein Freak eine Limetten-Schorle hielten';

  @override
  String get seedReplyWalk =>
      'geh. nur einen Block. der Geldbeutel bleibt voll, du bleibst frei. hab genau das am Dienstag gemacht';

  @override
  String get seedReplyScience =>
      'Tag 4 ist der schlimmste, das ist Wissenschaft. du bist GENAU JETZT am Peak. 15 Minuten und das Ding stirbt';

  @override
  String get seedReplyGatorade =>
      'kauf dir stattdessen ein Gatorade. zeremonieller Kauf. funktioniert seltsam gut';

  @override
  String get seedReplyUpdate =>
      'Update: Gatorade gekauft. laufe nach Hause. danke, ehrlich 💙';

  @override
  String get dangerReminderTitle => 'Deine kritische Stunde kommt';

  @override
  String get dangerReminderBody =>
      'Genau jetzt wird es meist hart. Du hast einen Plan — 15 Minuten reichen.';

  @override
  String get communityLoading => 'Feed wird geladen…';

  @override
  String memoriesLoading(String name) {
    return 'Mal sehen, was $name behalten hat…';
  }

  @override
  String get coachLoadingThread => 'Wir holen euren Chat…';

  @override
  String get moderationLoading => 'Warteschlange wird geladen…';

  @override
  String get authWorking => 'Einen Moment…';
}
