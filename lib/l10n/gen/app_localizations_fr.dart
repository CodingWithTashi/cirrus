// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline =>
      'Ta dernière taffe est plus proche\nque tu ne le crois.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · fait par des gens qui ont arrêté';
  }

  @override
  String get commonContinue => 'Continuer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonUndo => 'Annuler';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonNotNow => 'Pas maintenant';

  @override
  String get commonMaybeLater => 'Plus tard';

  @override
  String commonDayN(int day) {
    return 'jour $day';
  }

  @override
  String get authSignInTitle => 'On met ton plan\nen sécurité.';

  @override
  String get authSignInSubtitle =>
      'Anonyme par défaut — tu choisiras un alias pour la communauté.';

  @override
  String get authSignInWithApple => 'Se connecter avec Apple';

  @override
  String get authSignInWithGoogle => 'Se connecter avec Google';

  @override
  String get authContinueWithEmail => 'Continuer avec un e-mail';

  @override
  String get authWhyAccountDivider => 'pourquoi un compte ?';

  @override
  String get authWhyAccountCard =>
      'Ta série, ton plan et la mémoire de ton coach se synchronisent entre appareils. 🔒 On ne vend jamais tes données. Zéro traqueur pub. Jamais.';

  @override
  String get authTerms => 'Conditions';

  @override
  String get authPrivacy => 'Confidentialité';

  @override
  String get authRestorePurchase => 'Restaurer l\'achat';

  @override
  String get authRegisterTitle => 'Crée ton compte';

  @override
  String get authEmailLabel => 'E-MAIL';

  @override
  String get authPasswordLabel => 'MOT DE PASSE';

  @override
  String get authShowPassword => 'voir';

  @override
  String get authHidePassword => 'masquer';

  @override
  String get authPasswordStrengthWeak => 'continue…';

  @override
  String get authPasswordStrengthDecent => 'mot de passe correct';

  @override
  String get authPasswordStrengthStrong => 'mot de passe costaud';

  @override
  String get authNoSpamCard =>
      'Pas de spam, pas de mails « tu nous manques ». Le compte = ta sauvegarde, c\'est tout.';

  @override
  String get authCreateAccount => 'Créer le compte';

  @override
  String get authAlreadyHaveOne => 'Tu en as déjà un ?';

  @override
  String get authLogIn => 'Se connecter';

  @override
  String get authLoginTitle => 'Re-bonjour.';

  @override
  String get authLoginSubtitle => 'Ta série t\'attendait.';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authNewHere => 'Nouveau ici ?';

  @override
  String get authWrongPassword => 'pas celui-là — réessaie';

  @override
  String get authForgotTitle => 'Ça arrive à tout le monde.';

  @override
  String get authForgotSubtitle =>
      'Laisse ton e-mail — on t\'envoie un lien. Ta série reste intacte.';

  @override
  String get authLinkSent =>
      'Lien envoyé. Regarde dans les spams s\'il se cache.';

  @override
  String get authResendLink => 'Renvoyer le lien';

  @override
  String authResendCountdown(int seconds) {
    return 'Renvoyer dans ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Retour à la connexion';

  @override
  String get authInvalidEmail => 'ça ne ressemble pas à un e-mail';

  @override
  String get authEmailInUse => 'cet e-mail a déjà un parcours — connecte-toi';

  @override
  String get authPasswordTooShort =>
      'le mot de passe doit faire au moins 6 caractères — encore quelques-uns et c\'est bon';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint => 'taffes par jour — tu vas le découvrir';

  @override
  String get obWelcomeTitle => 'T\'es dépendant à quel point, vraiment ?';

  @override
  String get obWelcomeSubtitle =>
      'Check-up de 2 minutes. Résultats brutalement honnêtes. Un plan fait pour toi.';

  @override
  String get obWelcomeCta => 'Lancer mon check-up';

  @override
  String get obResumeTitle => 'On reprend où tu t\'es arrêté ?';

  @override
  String obResumeBody(int answered, int total) {
    return 'Tu avais répondu à $answered questions sur $total. Rien n\'est perdu.';
  }

  @override
  String get obResumeCta => 'Reprendre';

  @override
  String get obResumeFresh => 'Repartir de zéro';

  @override
  String get obGenderTitle => 'Comment tu t\'identifies ?';

  @override
  String get obGenderSubtitle =>
      'Ça calibre ton plan — le métabolisme de la nicotine varie.';

  @override
  String get obGenderWoman => 'Femme';

  @override
  String get obGenderMan => 'Homme';

  @override
  String get obGenderNonBinary => 'Non-binaire / préfère ne pas dire';

  @override
  String get obGenderPrivacyNote => '🔒 Privé. Jamais montré à la communauté.';

  @override
  String get obBirthYearTitle => 'Tu es né·e en quelle année ?';

  @override
  String get obBirthYearSubtitle => 'Ton plan s\'adapte à ton âge.';

  @override
  String get obBirthYearHint => 'Année ou âge — les deux marchent.';

  @override
  String obBirthYearAge(int age) {
    return 'Tu as $age ans.';
  }

  @override
  String obBirthYearAgeOffer(int age, int year) {
    return '$age ? Ça ferait une naissance en $year.';
  }

  @override
  String get obBirthYearAgeConfirm => 'C\'est moi';

  @override
  String obBirthYearUnderConfirm(int year, int age) {
    return 'Né en $year ? Ça fait $age ans.';
  }

  @override
  String obBirthYearUnderCta(int age) {
    return 'Oui, j\'ai $age ans';
  }

  @override
  String get obBirthYearFix => 'Laisse-moi corriger';

  @override
  String get obBirthYearErrorFuture =>
      'Cette année n\'est pas encore arrivée. On réessaie ?';

  @override
  String get obBirthYearErrorTooOld =>
      'La personne la plus âgée jamais vérifiée a atteint 122 ans. On recommence.';

  @override
  String get obBirthYearErrorUnknown =>
      'Ce n\'est ni une année ni un âge. Encore une fois.';

  @override
  String get obUnder18Title => 'On ne peut pas t\'aider ici — mais ça, oui.';

  @override
  String get obUnder18Subtitle =>
      'Cirrus est réservé aux 18+. Ces deux options sont gratuites, privées et faites pour ton âge. Elles marchent.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Des textos quotidiens de gens qui comprennent. Plus de 500 000 jeunes inscrits.';

  @override
  String get obUnder18TiqCta => 'Envoie DITCHVAPE au 88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Coaching gratuit par texto ou appel, pensé pour les ados. Sans leçons de morale.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'On croit en toi. Reviens à 18 ans si tu as encore besoin de nous — ce ne sera pas le cas. 💪';

  @override
  String get obTriedTitle => 'Déjà essayé d\'arrêter ?';

  @override
  String get obTriedNever => 'Jamais';

  @override
  String get obTriedNeverSub => 'première fois';

  @override
  String get obTriedOnce => 'Une fois';

  @override
  String get obTriedOnceSub => 'pas tenu';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'quelques rounds';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'j\'ai perdu le compte';

  @override
  String get obTriedReaction =>
      'La plupart des gens ont besoin de plusieurs essais. Chacun a appris quelque chose à ton cerveau — cette fois tu auras un plan.';

  @override
  String get obFrequencyTitle => 'Il est dans ta main à quelle fréquence ?';

  @override
  String get obFrequencySubtitle => 'Aucun jugement. Juste du calibrage.';

  @override
  String get obFreqDaily => 'CHAQUE JOUR';

  @override
  String get obFreqDailySub => 'Tous les jours, avec de vraies pauses entre.';

  @override
  String get obFreqOften => 'SOUVENT';

  @override
  String get obFreqOftenSub => 'Presque toute la journée, par sessions.';

  @override
  String get obFreqAlways => 'TOUJOURS';

  @override
  String get obFreqAlwaysSub => 'C\'est quasiment une extension de ma main.';

  @override
  String get obPuffsTitle => 'Des taffes, un jour normal ?';

  @override
  String get obPuffsBadgeLight => 'Habitude légère';

  @override
  String get obPuffsBadgeModerate => 'Dépendance modérée';

  @override
  String get obPuffsBadgeHeavy => 'Dépendance forte';

  @override
  String get obPuffsBadgeSevere => 'Dépendance sévère';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ $count cigarettes en taffes';
  }

  @override
  String get obPuffsNotSure => 'Pas sûr ? Estime via l\'appareil →';

  @override
  String get obPuffsHelperTitle => 'Estimation rapide';

  @override
  String get obPuffsHelperBody =>
      'Une puff jetable classique ≈ 600 taffes. Tu en finis combien par semaine ?';

  @override
  String obPuffsHelperResult(int count) {
    return 'Ça fait environ $count taffes par jour. On s\'auto-corrige pendant ta première semaine.';
  }

  @override
  String obPuffsHelperDevicesPerWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appareils / semaine',
      one: '$count appareil / semaine',
    );
    return '$_temp0';
  }

  @override
  String get obStrengthTitle => 'Ton dosage habituel ?';

  @override
  String get obStrength20Sub => '2% · léger';

  @override
  String get obStrength35Sub => '3,5% · moyen';

  @override
  String get obStrength50Sub => '5% · la plupart des jetables';

  @override
  String get obStrengthNotSure => 'Je ne sais pas';

  @override
  String get obStrengthNotSureSub => 'aucun souci';

  @override
  String get obStrengthNote =>
      'La plupart des jetables sont à 5% — dans le doute, c\'est le bon pari.';

  @override
  String get obSpendTitle => 'Ça te coûte combien par semaine ?';

  @override
  String get obSpendPerWeek => 'par semaine';

  @override
  String get obSpendThats => 'soit';

  @override
  String obSpendPerYear(String amount) {
    return '$amount par an';
  }

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / mois';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / jour';
  }

  @override
  String get obSpendYourMath => 'tes chiffres, pas les nôtres';

  @override
  String obSpendComparisonOne(String item) {
    return 'C\'est $item. Chaque année.';
  }

  @override
  String obSpendComparisonTwo(String item) {
    return 'C\'est $item, deux fois. Chaque année.';
  }

  @override
  String obSpendComparisonMany(String item, int count) {
    return 'C\'est $item, $count fois. Chaque année.';
  }

  @override
  String get obSpendItemGymMonth => 'un mois de salle de sport';

  @override
  String get obSpendItemConcertTicket => 'une place de concert, bien placée';

  @override
  String get obSpendItemRunningShoes =>
      'une vraie paire de chaussures de course';

  @override
  String get obSpendItemDentalCleaning => 'un détartrage chez le dentiste';

  @override
  String get obSpendItemWinterCoat => 'un manteau d\'hiver qui tient vraiment';

  @override
  String get obSpendItemFestivalTicket => 'un pass festival, camping compris';

  @override
  String get obSpendItemWeekendAway => 'un week-end ailleurs';

  @override
  String get obSpendItemBike => 'un vélo qui donne envie';

  @override
  String get obSpendItemDrivingLessons => 'un forfait complet d\'auto-école';

  @override
  String get obSpendItemNewPhone => 'un téléphone neuf';

  @override
  String get obSpendItemLaptop => 'un ordi portable qui ne rend pas l\'âme';

  @override
  String get obSpendItemEmergencyFund => 'une vraie épargne de secours';

  @override
  String get obSpendItemYogaYear => 'un an de yoga illimité';

  @override
  String get obSpendItemMonthOfRent => 'un mois de loyer';

  @override
  String get obSpendItemFamilyHoliday => 'des vacances en famille';

  @override
  String get obSpendItemUsedCar => 'une voiture qui roule';

  @override
  String get obFirstPuffTitle => 'Première taffe après le réveil ?';

  @override
  String get obFirstPuffWithin5 => 'Dans les 5 minutes';

  @override
  String get obFirstPuff5to30 => '5–30 minutes';

  @override
  String get obFirstPuff30to60 => '30–60 minutes';

  @override
  String get obFirstPuffHourPlus => 'Une heure ou plus';

  @override
  String get obFirstPuffScience =>
      'Le délai avant la première taffe est le meilleur prédicteur de dépendance. 76% des jeunes vapoteurs la prennent dans les 30 min après le réveil.';

  @override
  String get obFactLabelScience => 'LA SCIENCE';

  @override
  String get obFactLabelYourNumbers => 'TES CHIFFRES';

  @override
  String get obFactTried =>
      'Chez les jeunes vapoteurs quotidiens, les tentatives ratées sont passées de 28% à 53% entre 2020 et 2024. Les appareils sont devenus meilleurs à leur métier. Ce n\'est pas toi qui faiblis : c\'est une course à l\'armement où personne ne t\'a inscrit.';

  @override
  String obFactStrength(int mg) {
    return 'Ça fait ≈$mg mg de nicotine par jour. Tes chiffres, nos multiplications. Ta vape, elle, n\'a jamais proposé une dose raisonnable.';
  }

  @override
  String get obFactWorryCravings =>
      'La plupart des envies montent et redescendent en 15–20 minutes. Moins qu\'une attente au resto. Le bouton panique est construit pour exactement cette fenêtre.';

  @override
  String get obFactWorrySocial =>
      'Le soutien par les pairs augmente les chances d\'arrêter d\'environ 40%. Oui : des inconnus sur internet. Nous aussi, ça nous a surpris.';

  @override
  String get obWhyTitle => 'Pourquoi tu veux sortir de là ?';

  @override
  String get obWhySubtitle =>
      'Coche tout ce qui te parle. Ton coach s\'en servira quand ce sera dur.';

  @override
  String get obWhyHealth => 'Santé';

  @override
  String get obWhyMoney => 'Argent';

  @override
  String get obWhyFreedom => 'Liberté';

  @override
  String get obWhyFamily => 'Famille';

  @override
  String get obWhyFitness => 'Sport';

  @override
  String get obWhyAppearance => 'Peau & apparence';

  @override
  String get obWhyCardLabel => 'TON POURQUOI';

  @override
  String get obWorriesTitle => 'Qu\'est-ce qui t\'inquiète le plus ?';

  @override
  String get obWorriesSubtitle => 'Sois honnête. C\'est la partie utile.';

  @override
  String get obWorryCravings => 'Les cravings';

  @override
  String get obWorryStress => 'Le stress';

  @override
  String get obWorrySocial => 'La pression sociale';

  @override
  String get obWorryFailing => 'La peur d\'échouer';

  @override
  String get obWorryWeight => 'Prendre du poids';

  @override
  String get obWorryBreaks => 'Perdre mes pauses';

  @override
  String get obWorriesAiNote =>
      'Ton coach s\'entraîne exactement là-dessus. Craving à 23h ? Il connaît déjà ton plan de match.';

  @override
  String get obMethodFailingNote =>
      'Tu as coché « peur d\'échouer » — ce plan plie donc au lieu de casser. Un écart ajuste la courbe ; rien ne repart jamais de zéro.';

  @override
  String get obMethodTitle => 'Tu veux t\'y prendre comment ?';

  @override
  String get obMethodSubtitle => 'Les deux marchent. Une ligne honnête chacun.';

  @override
  String get obMethodTaper => 'Réduction progressive';

  @override
  String get obMethodTaperSub =>
      'Tu descends sur une courbe quotidienne. Sevrage plus doux, demande de la discipline.';

  @override
  String get obMethodTaperReco => 'Idéal à 100+ taffes/jour — c\'est toi';

  @override
  String get obMethodCold => 'Arrêt net';

  @override
  String get obMethodColdSub =>
      'Un stop total. Première semaine rude, sorti du tunnel plus vite.';

  @override
  String get obMethodColdReco => 'Faisable à ton niveau — à toi de voir';

  @override
  String get obPaceTitle => 'Choisis ton rythme.';

  @override
  String obPaceMostChosen(int days) {
    return '$days jours — le plus choisi';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count taffes';
  }

  @override
  String get obPaceCurveLabel => 'ta courbe';

  @override
  String get obPaceCurveEnd => '0 taffe';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Jour de liberté';
  }

  @override
  String get obPaceNote =>
      'La courbe se redessine en direct quand tu changes de rythme. Des vraies dates, pas « jour n ».';

  @override
  String get obPaceCta => 'Verrouiller mon rythme';

  @override
  String get obBuildingTitle => 'Construction de ton plan…';

  @override
  String obBuildingStep1(int count) {
    return 'Analyse de $count taffes/jour';
  }

  @override
  String get obBuildingStep2 => 'Cartographie de tes déclencheurs';

  @override
  String obBuildingStep3(int days) {
    return 'Calibrage de ta courbe de $days jours…';
  }

  @override
  String get obBuildingStep4 => 'Réservation de ton coach…';

  @override
  String obRevealTitle(int days) {
    return 'Ton plan de rupture en $days jours.';
  }

  @override
  String get obRevealMilestone3 => 'pic de cravings — on sera au max ici';

  @override
  String get obRevealMilestone7 => 'le goût et l\'odorat reviennent';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Jour de liberté — $date';
  }

  @override
  String get obRevealSavedLabel => 'économisés d\'ici le Jour de liberté';

  @override
  String get obRevealPuffsLabel => 'taffes que tu ne prendras pas';

  @override
  String get obRevealProofLabel => 'PREUVE HONNÊTE';

  @override
  String get obRevealProof =>
      '24% arrêtent avec un programme structuré vs 19% seuls — essai randomisé sur 2 588 jeunes adultes. Pas de magie. De meilleures chances.';

  @override
  String obRevealComparisonOne(String item) {
    return 'D\'ici le Jour de la Liberté, c\'est $item.';
  }

  @override
  String obRevealComparisonTwo(String item) {
    return 'D\'ici le Jour de la Liberté, c\'est $item, deux fois.';
  }

  @override
  String obRevealComparisonMany(String item, int count) {
    return 'D\'ici le Jour de la Liberté, c\'est $item, $count fois.';
  }

  @override
  String get obRevealCta => 'Je suis prêt·e';

  @override
  String get obCommitTitle => 'Rends-le réel.';

  @override
  String get obCommitSubtitle => 'Maintiens le bouton. Pense-le vraiment.';

  @override
  String get obCommitHold => 'Maintiens pour\nt\'engager';

  @override
  String get obCommitFreedomLabel => '🏆 JOUR DE LIBERTÉ';

  @override
  String obCommitDaysOut(int days) {
    return 'Dans $days jours. C\'est dans le calendrier.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 On ne vend jamais tes données. Zéro traqueur. Jamais.';

  @override
  String get obRatingTitle =>
      'L\'avis d\'un ancien vapoteur aide le suivant à nous trouver.';

  @override
  String get obRatingSubtitle => '30 secondes. Passable. Sans rancune.';

  @override
  String get obRatingBetaTester => 'BÊTA-TESTEUR';

  @override
  String get obRatingQuote1 =>
      '« Le bouton panique m\'a fait passer la première semaine. J\'aurais craqué au jour 3 sans lui. »';

  @override
  String get obRatingQuote2 =>
      '« La première appli qui ne me parle pas comme un médecin ou ma mère. »';

  @override
  String get obRatingCta => 'Noter Cirrus';

  @override
  String get obCoachNameTitle => 'Voici ton coach.';

  @override
  String get obCoachNameSubtitle =>
      'Ton coach. A arrêté il y a deux ans, se souvient exactement de la sensation, et a déjà lu ton plan.';

  @override
  String obCoachNameAsk(String name) {
    return 'On l\'appelle $name. N\'importe quel autre nom fait l\'affaire — choisis celui que tu écrirais vraiment à 2 h du matin.';
  }

  @override
  String get obCoachNameFieldLabel => 'Nom du coach';

  @override
  String get obCoachNameSuggestions => 'Ou emprunte-en un :';

  @override
  String obCoachNameKeep(String name) {
    return 'Garder $name';
  }

  @override
  String get obCoachNameCta => 'C\'est celui-là';

  @override
  String get obCoachNameLater =>
      'Tu peux le changer à tout moment dans les Réglages.';

  @override
  String get obCoachNameErrorEmpty => 'Donne-lui un nom.';

  @override
  String get obCoachNameErrorLong => '20 caractères maximum.';

  @override
  String get obCoachNameErrorChars =>
      'Lettres, chiffres, espaces et - \' uniquement.';

  @override
  String get obCoachNameErrorRejected => 'Choisis-en un autre.';

  @override
  String get settingsCoachName => 'Le nom de ton coach';

  @override
  String coachRenamed(String name) {
    return 'C\'est noté — $name, désormais.';
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
    return 'Dis une chose à $name.';
  }

  @override
  String get obWhyWordsSubtitle =>
      'Pourquoi maintenant ? Pas la réponse de brochure — la vraie.';

  @override
  String get obWhyWordsFieldLabel => 'Avec tes mots';

  @override
  String get obWhyWordsHintHealth =>
      'pour arrêter de siffler comme une bouilloire dans les escaliers';

  @override
  String get obWhyWordsHintMoney =>
      'Je veux récupérer mon argent. Et mes matins.';

  @override
  String get obWhyWordsHintFreedom =>
      'parce que j\'en ai fini avec la course à la station-service à 23 h';

  @override
  String get obWhyWordsHintFamily =>
      'mon enfant l\'a trouvé dans ma veste. Plus jamais.';

  @override
  String get obWhyWordsHintFitness =>
      'pour pouvoir courir avec elle sans m\'arrêter';

  @override
  String get obWhyWordsHintAppearance =>
      'je veux retrouver la version reposée de mon visage';

  @override
  String obWhyWordsNote(String name) {
    return '$name s\'en souviendra.';
  }

  @override
  String get obWhyWordsErrorLong => 'Reste sous les 200 caractères.';

  @override
  String get obWhyWordsCta => 'C\'est pour ça';

  @override
  String get obWhyWordsSkip => 'Passer';

  @override
  String get obNotifTitle => 'Du renfort, pile quand tu craques.';

  @override
  String get obNotifSubtitle =>
      'Pas de spam. Un rappel avant tes heures à risque, un autre à chaque étape franchie.';

  @override
  String get obNotifPreviewTime => 'Ven 21:54';

  @override
  String get obNotifPreviewBody =>
      'attention — le vendredi soir, c\'est ton pic. Le plan est prêt 💪';

  @override
  String get obNotifBullet1 => 'Alerte heures à risque (tu choisis les heures)';

  @override
  String get obNotifBullet2 => 'Célébrations de séries + étapes';

  @override
  String get obNotifBullet3 => 'Rien d\'autre — jamais de marketing';

  @override
  String get obNotifCta => 'Activer le renfort';

  @override
  String get paywallTitle => 'Ton plan est prêt.';

  @override
  String get paywallTitleUpgrade => 'Va plus loin avec Premium.';

  @override
  String get paywallSubtitle => 'Essaie tout gratuitement pendant 7 jours.';

  @override
  String get paywallFeatCoach =>
      'Coach IA illimité qui se souvient de ton pourquoi';

  @override
  String get paywallFeatPanic => 'Bouton panique : tue l\'envie en 60 secondes';

  @override
  String get paywallFeatPlan => 'Un plan qui s\'adapte quand tu craques';

  @override
  String get paywallFeatForecasts =>
      'Prévisions d\'envies pour tes heures à risque';

  @override
  String get paywallFeatCommunity => 'Une communauté qui répond à ton SOS';

  @override
  String get paywallFeatReports => 'Bilan hebdo avec tes propres chiffres';

  @override
  String get paywallYearly => 'ANNUEL';

  @override
  String get paywallYearlyBadge => 'MEILLEUR PRIX';

  @override
  String get paywallYearlySub => '0,77 \$/sem · -74%';

  @override
  String get paywallMonthly => 'MENSUEL';

  @override
  String get paywallWeekly => 'HEBDO';

  @override
  String get paywallWeeklySub => 'Prix fondateur — bloqué à vie';

  @override
  String get paywallTrialReminder =>
      '🔔 On te prévient avant la fin de ton essai';

  @override
  String get paywallCancelAnytime => 'Annulable à tout moment';

  @override
  String get paywallAnchor => 'Moins cher qu\'une puff par semaine';

  @override
  String get paywallCta => 'Commencer ma semaine gratuite';

  @override
  String get paywallFreeLink => 'Continuer avec le plan Gratuit →';

  @override
  String get paywallTimelineToday => 'Aujourd\'hui';

  @override
  String paywallTimelineDay(int n) {
    return 'Jour $n';
  }

  @override
  String get paywallTimelineTodayBody => 'Tout est débloqué';

  @override
  String get paywallTimelineRemindBody => 'On te prévient';

  @override
  String get paywallTimelineNoRemindBody =>
      'Dernier jour pour annuler gratuitement';

  @override
  String paywallTimelineChargeBody(String price) {
    return 'Premier prélèvement : $price. Annule avant, tu ne paies rien.';
  }

  @override
  String paywallPerYear(String price) {
    return '$price/an';
  }

  @override
  String paywallPerMonth(String price) {
    return '$price/mois';
  }

  @override
  String paywallPerWeek(String price) {
    return '$price/sem';
  }

  @override
  String paywallDisclosureTrial(
    String price,
    String period,
    int days,
    String store,
  ) {
    return '$price par $period après ton essai gratuit de $days jours. Renouvellement automatique jusqu\'à annulation — annule à tout moment dans tes abonnements $store.';
  }

  @override
  String paywallDisclosure(String price, String period, String store) {
    return '$price par $period. Renouvellement automatique jusqu\'à annulation — annule à tout moment dans tes abonnements $store.';
  }

  @override
  String get paywallPeriodWeek => 'semaine';

  @override
  String get paywallPeriodMonth => 'mois';

  @override
  String get paywallPeriodYear => 'an';

  @override
  String get paywallStoreApple => 'App Store';

  @override
  String get paywallStoreGoogle => 'Google Play';

  @override
  String paywallYearlySubLive(String perWeek, int percent) {
    return '$perWeek/semaine · ÉCONOMISE $percent%';
  }

  @override
  String paywallYearlySubPerWeek(String perWeek) {
    return '$perWeek/semaine';
  }

  @override
  String paywallCtaTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Commencer mes $days jours gratuits',
      one: 'Commencer ma journée gratuite',
    );
    return '$_temp0';
  }

  @override
  String get paywallCtaSubscribe => 'Commencer Premium';

  @override
  String paywallSubtitleTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Essaie tout gratuitement pendant $days jours.',
      one: 'Essaie tout gratuitement pendant un jour.',
    );
    return '$_temp0';
  }

  @override
  String get paywallSubtitleNoTrial => 'Tout débloqué, dès aujourd\'hui.';

  @override
  String get paywallRestore => 'Restaurer les achats';

  @override
  String get paywallRestored => 'Content de te revoir — Premium est activé.';

  @override
  String get paywallRestoreNothing =>
      'Rien à restaurer sur ce compte de boutique pour l\'instant.';

  @override
  String get paywallPurchasePending =>
      'Ton paiement est en attente. Premium s\'activera dès que la boutique l\'aura confirmé.';

  @override
  String get paywallPricesUnavailable =>
      'Les prix en direct ne se chargent pas pour le moment — la boutique affiche le prix exact avant confirmation.';

  @override
  String get premiumLockTitle => 'Premium';

  @override
  String get premiumLockCta => 'Voir Premium';

  @override
  String get premiumPitchInsight =>
      'Ton rapport hebdo, écrit à partir de tes propres chiffres.';

  @override
  String get premiumPitchForecast =>
      'Des prévisions d\'envie pour les heures où tu craques d\'habitude.';

  @override
  String get premiumPitchHistory =>
      'Tout ton historique, pas seulement les 7 derniers jours.';

  @override
  String get premiumFreeHistoryNote =>
      'Le plan Gratuit montre tes 7 derniers jours.';

  @override
  String get premiumPitchCompose =>
      'Publier fait partie de Premium. Lire et réagir restent gratuits — et un SOS aussi.';

  @override
  String get premiumPitchPlan =>
      'Un plan qui s\'adapte quand tu craques — l\'ajustement du soir, chaque soir.';

  @override
  String get premiumPitchHealth =>
      'La chronologie complète, de deux semaines à un an.';

  @override
  String get premiumPitchCoach =>
      'Ember à toute heure — 100 messages par jour au lieu de 5.';

  @override
  String get freePlanTitle => 'Le Gratuit te met en route.';

  @override
  String get freePlanSubtitle =>
      'À toi pour toujours. Pas de compte à rebours, pas de harcèlement.';

  @override
  String get freePlanFeat1 => 'Journal de taffes + séries';

  @override
  String get freePlanFeat2 => 'Compteur d\'économies';

  @override
  String get freePlanFeat3 => '5 messages de coach par jour';

  @override
  String get freePlanFeat4 => '1 session Bouton panique par jour';

  @override
  String get freePlanFeat5 => 'Communauté (lire + réagir)';

  @override
  String get freePlanUpgradeNote =>
      'Passe à Premium quand tu veux — ta série et ton historique te suivent.';

  @override
  String get freePlanCta => 'Commencer en Gratuit';

  @override
  String get winbackBadge => 'OFFRE FONDATEUR · UNE SEULE FOIS';

  @override
  String get winbackTitle => 'OK — le premier mois offert. Presque.';

  @override
  String get winbackSubtitle =>
      'Tu as construit le plan. Essaie la boîte à outils complète un mois avant de décider.';

  @override
  String get winbackFirstMonth => 'le premier mois';

  @override
  String winbackNote(String price) {
    return 'Puis $price/mois. Annulable à tout moment. Affiché une fois, plus jamais.';
  }

  @override
  String get winbackCta => 'Prendre le mois fondateur';

  @override
  String get winbackDecline => 'Non merci, le Gratuit me va';

  @override
  String get day1Title => 'Jour 1. C\'est parti.';

  @override
  String get day1Subtitle =>
      'Trois réglages. Deux minutes. Ensuite l\'appli fait son boulot.';

  @override
  String get day1Task1 => 'Enregistre ta première taffe';

  @override
  String get day1Task1Done => 'fait — honnête dès la première';

  @override
  String get day1Task1Sub => 'un appui honnête sur le grand bouton';

  @override
  String get day1Task2 => 'Rencontre ton coach';

  @override
  String get day1Task2Sub =>
      'Un salut de 30 sec. Il connaît déjà tes déclencheurs.';

  @override
  String get day1Task3 => 'Règle tes heures à risque';

  @override
  String get day1Task3Sub => 'tu craques quand ? on arrivera en avance';

  @override
  String get day1Skip => 'Passer la configuration pour l\'instant';

  @override
  String get day1TourLogTitle => 'C\'est toute l\'appli.';

  @override
  String get day1TourLogBody =>
      'Chaque bouffée, ici. Seul un compte honnête rend le plan réel — vas-y, enregistres-en une.';

  @override
  String get day1TourCoachTitle => 'Dis-lui n\'importe quoi.';

  @override
  String day1TourCoachBody(String name) {
    return '$name a déjà lu ton plan — tes chiffres, tes déclencheurs, tes heures difficiles. Écris un bonjour, tu verras.';
  }

  @override
  String get day1TourHoursTitle => 'Tu craques quand ?';

  @override
  String get day1TourHoursBody =>
      'Choisis l\'heure où ça frappe d\'habitude. On arrive dix minutes avant, sur ton téléphone, sans que tu demandes.';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Jour de liberté : $date · dans $days jours · plan armé';
  }

  @override
  String get day1CtaCoach => 'Rencontrer mon coach';

  @override
  String get day1CtaHome => 'Aller à Aujourd\'hui';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Jour $day sur $total';
  }

  @override
  String homeGreetingFreedomDay(String date) {
    return '$date · Jour de la Liberté 🏆';
  }

  @override
  String homeGreetingMaintenance(String date, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours après le Jour de la Liberté',
      one: '1 jour après le Jour de la Liberté',
    );
    return '$date · $_temp0';
  }

  @override
  String get homeFreedomDayTitle =>
      'Jour de la Liberté. C\'est toi qui as choisi cette date.';

  @override
  String get homeFreedomDayBody =>
      'Le plan se termine aujourd\'hui et la ligne reste à zéro désormais. Chaque journée sans vape que tu confirmes maintenant, c\'est de l\'entretien — même flamme, même série.';

  @override
  String get homeTitle => 'Aujourd\'hui';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count jours',
      one: '🔥 $count jour',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'taffes aujourd\'hui';

  @override
  String homeOfLimit(int limit) {
    return 'sur $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return '$count de marge sur ta ligne du jour. Tu es en avance sur ta courbe.';
  }

  @override
  String homeLeftTight(int count) {
    return '$count restantes sur ta ligne du jour. Serré — tu gères.';
  }

  @override
  String homeVsDay1(String percent) {
    return '$percent vs jour 1';
  }

  @override
  String get homeSavedSoFar => 'économisés';

  @override
  String get homeCravingsBeaten => 'cravings vaincus';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return '$weekday difficile ? J\'ai vu.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'Ton pic de $hour approche — un plan ?';
  }

  @override
  String get homeLogPuff => 'TAFFE +1';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => 'Zéro taffe aujourd\'hui ?';

  @override
  String get homeVapeFreeCta => 'Confirmer le jour sans vape ✓';

  @override
  String get homeVapeFreeDone =>
      'Jour sans vape validé. C\'est tout le jeu. 🔥';

  @override
  String get homeYesterdayTitle => 'Hier, journée sans vape ?';

  @override
  String homeYesterdayBody(String date) {
    return 'Rien d\'enregistré pour le $date. Toi seul le sais, alors on demande au lieu de deviner.';
  }

  @override
  String get homeYesterdayYes => 'Sans vape ✓';

  @override
  String get homeYesterdayNo => 'J\'ai vapoté';

  @override
  String get homeYesterdayDone =>
      'Hier est enregistré. Ta série connaît la vérité. 🔥';

  @override
  String homeLoggedSnackCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taffes enregistrées',
      one: '1 taffe enregistrée',
    );
    return '$_temp0';
  }

  @override
  String get homeOverLimitTitle => 'Au-dessus de ta ligne';

  @override
  String get homeOverLimitBody =>
      'Respire — la ligne de demain s\'ajuste. Zéro honte.';

  @override
  String get homeOverLimitBreathe => 'Respirer 60s';

  @override
  String get homeOverLimitCoach => 'Parler au coach';

  @override
  String get homeOverLimitFooter =>
      'Continue d\'enregistrer honnêtement — les données, c\'est tout le jeu.';

  @override
  String get homeTokenUsedNote =>
      'Jeton de réparation utilisé — ta série survit. La flamme faiblit aujourd\'hui, elle ne meurt pas.';

  @override
  String get navHome => 'Accueil';

  @override
  String get navStats => 'Stats';

  @override
  String get navCommunity => 'Commu';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'MODE PANIQUE · $step SUR 3';
  }

  @override
  String get panicBreatheNote =>
      'cette sensation monte puis passe — la plupart des cravings meurent en 15 min';

  @override
  String get panicBreatheInstruction => 'Respire avec le cercle.';

  @override
  String get panicBreatheIn => 'Inspire';

  @override
  String get panicBreatheHold => 'Retiens';

  @override
  String get panicBreatheOut => 'Expire';

  @override
  String get panicBreathePattern => 'Inspire 4 · Retiens 7 · Expire 8';

  @override
  String panicCravingTimer(String time) {
    return 'chrono du craving · $time · pic ~15 min';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'chrono du craving · $time · le pire est passé';
  }

  @override
  String get panicSkipToWhy => 'Aller à mon pourquoi →';

  @override
  String get panicWhyTitle => 'Rappelle-toi pourquoi tu as commencé.';

  @override
  String get panicYouSaid => 'TU AS DIT';

  @override
  String panicWhyLine(String why, String amount) {
    return 'Tu fais ça pour ta $why et les $amount par an que tu récupères.';
  }

  @override
  String get panicIntensityQuestion => 'C\'est fort comment, là ?';

  @override
  String get panicIntensityLow => 'bof';

  @override
  String get panicIntensityHigh => 'ça hurle';

  @override
  String get panicStillCraving => 'Toujours en craving — suite';

  @override
  String get panicItPassed => 'C\'est passé 🎉 ça va';

  @override
  String get panicLoopTitle => 'Casse la boucle.';

  @override
  String get panicLoopSubtitle =>
      'Tes mains et ton cerveau ont besoin d\'un job pendant 60 secondes. Choisis.';

  @override
  String get panicLoopGame => 'Joue une minute';

  @override
  String get panicLoopGameSub =>
      'Tuiles, Blocs ou Orbes — pouces occupés, cerveau occupé';

  @override
  String get panicLoopSos => 'Demande à la communauté';

  @override
  String get panicLoopSosSub =>
      'publie un SOS — épinglé en haut pendant une heure';

  @override
  String get panicLoopCoach => 'Parler au coach';

  @override
  String panicLoopCoachSub(String hour) {
    return 'il sait que c\'est ton pattern de stress de $hour';
  }

  @override
  String get panicLoopCoachLocked =>
      'tu as utilisé ta session IA gratuite du jour';

  @override
  String get gameTitle => 'Ne laisse pas de place au craving.';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get gameNewBest => 'nouveau record';

  @override
  String get gameAnotherRound => 'Toujours envie — 60 secondes de plus';

  @override
  String get gameWhy =>
      'Un craving, c\'est surtout une image dans ta tête. Occupe cet espace quelques minutes et elle a moins de place pour grandir.';

  @override
  String get gameNameTiles => 'Tuiles';

  @override
  String get gameNameBlocks => 'Blocs';

  @override
  String get gameNameOrbs => 'Orbes';

  @override
  String get gameHintTiles => 'Tape la tuile du bas dans sa colonne.';

  @override
  String get gameHintBlocks =>
      'Glisse pour déplacer · tape pour tourner · balaie vers le bas pour lâcher';

  @override
  String get gameHintOrbs =>
      'Quelques orbes brillent. Garde-les à l\'œil pendant qu\'ils bougent, puis tape dessus.';

  @override
  String orbsCue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Retiens ces $count',
      one: 'Retiens celui-ci',
    );
    return '$_temp0';
  }

  @override
  String get orbsCueSub =>
      'Ils deviennent gris dans un instant — garde-les à l\'œil';

  @override
  String get orbsTrack => 'Garde-les à l\'œil';

  @override
  String get orbsTrackSub => 'L\'anneau arrive';

  @override
  String orbsPick(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tape les $count que tu as suivis',
      one: 'Tape celui que tu as suivi',
    );
    return '$_temp0';
  }

  @override
  String orbsProgress(int found, int count) {
    return '$found sur $count';
  }

  @override
  String orbsPerfect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Les $count — parfait',
      one: 'Trouvé — parfait',
    );
    return '$_temp0';
  }

  @override
  String get orbsRevealSub => 'C\'étaient ceux-là';

  @override
  String gameUnitTiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tuiles',
      one: '1 tuile',
    );
    return '$_temp0';
  }

  @override
  String gameUnitBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes',
      one: '1 ligne',
    );
    return '$_temp0';
  }

  @override
  String gameUnitOrbs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count orbes',
      one: '1 orbe',
    );
    return '$_temp0';
  }

  @override
  String gameMinutesDone(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes faites.',
      one: '60 secondes faites.',
    );
    return '$_temp0';
  }

  @override
  String get gameDoseDone => 'Trois minutes — la dose complète.';

  @override
  String get gameResearchNote =>
      'Dans une étude d\'une semaine, trois minutes d\'un jeu visuel ont réduit les cravings d\'environ un cinquième.';

  @override
  String get gameIntensityNow => 'C\'est comment, maintenant ?';

  @override
  String get gameCapLine => 'Cinq minutes de ton attention. Choisis la suite.';

  @override
  String get gameCapTryElse => 'Essayer autre chose';

  @override
  String get gamePaused => 'En pause';

  @override
  String get gamePausedTap => 'Tape pour continuer';

  @override
  String get survivedPlusOne => '+1 craving vaincu';

  @override
  String get survivedLine1 => 'Celui-là n\'avait aucune chance contre toi.';

  @override
  String get survivedLine2 => 'La vague s\'est brisée. Pas toi.';

  @override
  String get survivedLine3 => '15 minutes de courage. Encaissées à vie.';

  @override
  String get survivedLine4 => 'Ton cerveau vient d\'apprendre qui commande.';

  @override
  String get survivedLine5 => 'Craving 0 — toi 1. Encore.';

  @override
  String get survivedLine6 => 'Toujours libre. Toujours en route.';

  @override
  String get survivedLine7 => 'Cette envie vient de payer ton futur toi.';

  @override
  String get survivedLine8 => 'Sang-froid. Dans le bon sens.';

  @override
  String get survivedTotalLabel => 'cravings survécus au total';

  @override
  String get survivedGameNewBest => 'NOUVEAU RECORD';

  @override
  String survivedGameBest(int best) {
    return 'record $best';
  }

  @override
  String survivedIntensityDrop(int before, int after) {
    return 'Tu disais $before/10 — maintenant $after/10.';
  }

  @override
  String get survivedShare => 'Partager la win ↗';

  @override
  String get survivedBack => 'Retour à aujourd\'hui';

  @override
  String get survivedShareCopied => 'Carte copiée — colle-la où tu veux.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● connaît ton plan · jour $day';
  }

  @override
  String get coachChipCraving => 'J\'ai un craving';

  @override
  String get coachChipRoughDay => 'Journée dure';

  @override
  String get coachChipSlipped => 'J\'ai craqué';

  @override
  String get coachChipProgress => 'Montre mes progrès';

  @override
  String get coachInputHint => 'Écris à ton coach…';

  @override
  String coachTyping(String name) {
    return '$name écrit…';
  }

  @override
  String coachTimeYesterday(String time) {
    return 'Hier · $time';
  }

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages gratuits aujourd\'hui',
      one: '$count message gratuit aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get coachCapReached =>
      'C\'étaient mes 5 messages gratuits du jour — je reviens à minuit. Tu me veux 24h/24 ? C\'est ça, Premium.';

  @override
  String get coachConnectionLost =>
      'La connexion a lâché en pleine phrase 😅 Je suis toujours là — redis-moi ça quand tu repasses en ligne ?';

  @override
  String get coachBackendRejected =>
      'Ok, ça vient de chez nous — le serveur n\'a pas reconnu l\'appli, donc ton message ne m\'est jamais parvenu. Ni ta connexion, ni toi. On s\'en occupe.';

  @override
  String get errorOfflineBanner =>
      'hors ligne — tes logs comptent, on synchronise après';

  @override
  String get errorOfflineTitle => 'Pas de wifi, pas de panique';

  @override
  String get errorOfflineBody =>
      'Tu es hors ligne. Rien n\'est perdu — reconnecte-toi et on reprend exactement où tu en étais.';

  @override
  String get errorGenericTitle => 'Bon, ça a buggé';

  @override
  String get errorGenericBody =>
      'C\'est nous, pas toi. Réessaie dans un instant.';

  @override
  String get errorPurchaseNotAllowedTitle =>
      'Les achats sont désactivés sur cet appareil';

  @override
  String get errorPurchaseNotAllowedBody =>
      'Cet appareil ou ce compte ne peut pas acheter d\'abonnement pour le moment — généralement un contrôle parental ou une restriction de la boutique. Rien n\'a été débité.';

  @override
  String get errorStoreTitle => 'La boutique n\'a pas répondu';

  @override
  String get errorStoreBody =>
      'Google Play ou l\'App Store a eu un raté. Rien n\'a été débité — réessaie dans une minute.';

  @override
  String get errorReceiptOwnedTitle =>
      'Cet abonnement appartient à un autre compte';

  @override
  String get errorReceiptOwnedBody =>
      'L\'abonnement de ce compte de boutique est lié à une autre connexion Cirrus. Connecte-toi avec celle-ci, ou restaure depuis ce compte.';

  @override
  String get errorRejectedTitle => 'Cette version a été refusée';

  @override
  String get errorRejectedBody =>
      'Ta connexion va bien — c\'est notre côté qui n\'a pas reconnu l\'appli. Rien à faire de ton côté, et rien n\'est perdu.';

  @override
  String get errorRetry => 'On retente';

  @override
  String get errorGotIt => 'Compris';

  @override
  String get errorFeedTitle => 'Le feed nous a ghostés';

  @override
  String get errorFeedBody =>
      'Impossible de joindre la communauté. Vérifie ta connexion et retente.';

  @override
  String get errorRouteTitle => 'Cette page n\'existe pas';

  @override
  String get errorRouteBody =>
      'Ce que tu cherchais n\'est pas ici. On te ramène en lieu sûr.';

  @override
  String get errorRouteCta => 'Ramène-moi à l\'accueil';

  @override
  String get errorBackstage =>
      'petit bug en coulisses — tu peux continuer tranquille';

  @override
  String get coachWeekCardLabel => 'TA SEMAINE';

  @override
  String coachWeekCardCaption(String day) {
    return 'en baisse — $day a été le plus dur';
  }

  @override
  String coachGreeting(String name, int puffs, String method, String date) {
    return 'Salut. Moi c\'est $name — j\'ai arrêté il y a deux ans et je me souviens exactement de la sensation. J\'ai lu ton plan : $puffs par jour, $method, Jour de liberté le $date. Aucune leçon de morale de ma part, jamais. Qu\'est-ce qui se passe, là ?';
  }

  @override
  String get coachReplyCraving1 =>
      'Cette vague est brutale, je sais. 15 minutes et elle se brise — c\'est pas un discours, c\'est de la biologie. Eau froide sur les poignets, et reste avec moi. C\'est parti d\'où ?';

  @override
  String coachReplyCraving2(int count) {
    return 'OK. Respire avec moi un cycle — inspire 4, retiens 7, expire 8. Les cravings meurent en 15–20 minutes. Tu en as déjà vaincu $count. Celui-là n\'est pas différent.';
  }

  @override
  String get coachReplyCraving3 =>
      'Compris. Ne discute pas avec le craving, survis-lui. Marche un pâté de maisons ou lance le jeu de 60 secondes. Ça monte et ça meurt — 15 minutes max.';

  @override
  String coachReplyRough1(int percent) {
    return 'Normal. Les jours durs, la vieille habitude crie plus fort. Deal : 10 min de marche avant la prochaine. Si tu la veux encore après, enregistre-la honnêtement — tu es toujours à $percent% sous ta base.';
  }

  @override
  String get coachReplyRough2 =>
      'Ça a l\'air lourd. Tu n\'as pas à réparer aujourd\'hui, juste à le traverser — et tu peux le faire sans nicotine. Je suis là quoi qu\'il arrive.';

  @override
  String coachReplySlip1(int count) {
    return 'Un écart, c\'est de la donnée, pas une défaite. C\'est parti de quoi — stress, gens, ennui ? Le plan s\'est déjà plié pour te rattraper. Tes $count jours comptent toujours.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Zéro honte ici. La plupart de ceux qui arrêtent pour de bon ont craqué en chemin. Enregistre honnêtement, trouve le déclencheur, avance. Ton dossier reste à toi : $amount économisés, ta meilleure série intacte.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Regarde les vrais chiffres : jour $day, $saved de retour dans ta poche, $cravings cravings vaincus. Le toi du jour 1 n\'aurait pas pu faire aujourd\'hui. C\'est réel.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today taffes aujourd\'hui contre une ligne à $limit. Chacune que tu évites est dans le journal, et c\'est le journal qui infléchit la courbe. Tu le fais vraiment.';
  }

  @override
  String get coachReplyGeneric1 =>
      'Je t\'écoute. Dis-m\'en plus — il y a quoi dessous ?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Ça se tient. Pour ce que ça vaut : tu es au jour $day et toujours là. Ça compte beaucoup.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Reçu. Une question honnête : c\'est une affaire de nicotine, ou la vie qui a mis la veste de la nicotine ?';

  @override
  String get coachReplyGeneric4 =>
      'OK. Ça se gagne par petits mouvements. Tu peux faire quoi dans les 10 prochaines minutes qui n\'est pas vapoter ?';

  @override
  String coachReplyParty(int count) {
    return 'Plan soirée : un verre froid en main toute la nuit, tu m\'écris ou tu textes ton binôme dès que la première puff sort, et prépare ta phrase de sortie. Tu as survécu à $count cravings — une soirée, c\'est juste plusieurs d\'affilée.';
  }

  @override
  String coachSafetyNote(String name) {
    return '$name est un outil de soutien, pas un médecin. En crise ? Appelle ou texte le 988 (É.-U. & Canada), à toute heure.';
  }

  @override
  String get planTitle => 'Ton plan';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days jours';
  }

  @override
  String get planMethodTaper => 'Réduction';

  @override
  String get planMethodCold => 'Arrêt net';

  @override
  String planTodayMarker(int limit) {
    return 'aujourd\'hui · $limit/jour';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'À VENIR';

  @override
  String planHalfwayTitle(int day) {
    return 'Jour $day — mi-parcours';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'la ligne descend à $limit/jour';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Jour $day — les cravings s\'estompent';
  }

  @override
  String get planCravingsFadeSub => 'la plupart notent des matins plus faciles';

  @override
  String planFreedomTitle(int day) {
    return 'Jour $day — Jour de liberté';
  }

  @override
  String get planAdjustCta => 'Ajuster mon plan';

  @override
  String get planAdjustNote =>
      'rythme + méthode modifiables · pas de reset, pas d\'historique perdu';

  @override
  String get planAdaptiveLabel => 'AJUSTEMENT DE CETTE NUIT';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'Tu es sous ta ligne depuis trois jours, alors l\'objectif du jour descend à $limit. De l\'élan, pas une punition.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'Tu tiens la ligne. L\'objectif du jour reste à $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'Les deux derniers jours ont débordé, alors l\'objectif du jour passe à $limit. Une ligne que tu peux tenir vaut mieux qu\'une ligne impossible.';
  }

  @override
  String get planAdaptiveStretched =>
      'Le Jour de la Liberté recule d\'un jour pour suivre.';

  @override
  String get planAdjustSheetTitle => 'Ajuste ton plan';

  @override
  String get planAdjustSheetNote =>
      'La courbe se régénère depuis aujourd\'hui avec tes vrais chiffres. L\'historique reste. Le Jour de liberté bouge honnêtement.';

  @override
  String get planAdjustApply => 'Appliquer — recalculer ma courbe';

  @override
  String planAdjusted(String date) {
    return 'Plan recalculé. Nouveau Jour de liberté : $date';
  }

  @override
  String get statsTitle => 'Stats';

  @override
  String get statsRangeDay => 'Jour';

  @override
  String get statsRangeWeek => 'Semaine';

  @override
  String get statsRangeMonth => 'Mois';

  @override
  String get statsPuffsThisWeek => 'TAFFES CETTE SEMAINE';

  @override
  String get statsPuffsToday => 'TAFFES AUJOURD\'HUI · PAR HEURE';

  @override
  String get statsPuffsThisMonth => 'TAFFES · 30 DERNIERS JOURS';

  @override
  String statsVsLast(String percent) {
    return '$percent vs précédent';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return '$day a été le jour difficile — $reason. Tu t\'es repris·e dès le matin.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return '$day a été le jour difficile. Tu t\'es repris·e dès le matin.';
  }

  @override
  String get statsWindowNoPuffs =>
      'aucune bouffée enregistrée sur cette période';

  @override
  String get statsTriggerHours => 'HEURES DÉCLENCHEURS';

  @override
  String statsDangerWindow(String range) {
    return '$range est ta fenêtre à risque · alertes armées';
  }

  @override
  String get statsNicotinePerDay => 'NICOTINE / JOUR';

  @override
  String statsNicotineValue(int mg) {
    return '${mg}mg ↓';
  }

  @override
  String get statsLongestGap => 'plus longue pause';

  @override
  String get statsBestDay => 'meilleur jour (taffes)';

  @override
  String get statsCravingsBeaten => 'cravings vaincus';

  @override
  String get statsEmptyTitle => 'Les graphiques arrivent demain.';

  @override
  String get statsEmptyBody =>
      'Un jour de données = un point. Continue — le dessin se fait tout seul.';

  @override
  String statsEditDayTitle(String date) {
    return 'Modifier $date';
  }

  @override
  String get statsEditDayNote =>
      'L\'historique est à toi. Série et argent se recalculent à partir d\'ici.';

  @override
  String get statsEditHint => 'appui long sur une barre pour corriger un jour';

  @override
  String get communityTitle => 'Communauté';

  @override
  String communityYouAre(String alias) {
    return 'tu es $alias';
  }

  @override
  String get communityFilterAll => 'Tout';

  @override
  String get communityTagWin => '🏆 Win';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Jour 1';

  @override
  String get communityTagMilestone => 'Étape';

  @override
  String get communityTagVent => 'Coup de gueule';

  @override
  String get communityIGotYou => 'Je suis là 💬';

  @override
  String communityRepliedCount(int count) {
    return '$count ont déjà répondu';
  }

  @override
  String get communityReport => 'Signaler';

  @override
  String get communityMute => 'Masquer';

  @override
  String get communityBlock => 'Bloquer';

  @override
  String get communityReported =>
      'Signalé. On vérifie sous 24h — 3 signalements masquent le post.';

  @override
  String get communityBlocked => 'Bloqué. Vous ne vous verrez plus.';

  @override
  String get communityMuted => 'Masqué. Tu ne verras plus ses posts.';

  @override
  String get communityComposerTitle => 'Nouveau post';

  @override
  String get communityComposerPost => 'Publier';

  @override
  String communityPostingAs(String alias, int day) {
    return 'publié en tant que $alias · jour $day · toujours anonyme';
  }

  @override
  String get communityComposerHint => 'Il se passe quoi dans ton sevrage ?';

  @override
  String get communityTagIt => 'TAGUE-LE';

  @override
  String get communityKindnessNote =>
      'Sois sympa — tout le monde ici est en plein combat. Pas de marques, pas de bons plans d\'achat.';

  @override
  String get communityRuleSlur =>
      'Impossible de publier ça — les insultes et la haine n\'ont pas leur place ici.';

  @override
  String get communityRuleSourcing =>
      'Pas de « où acheter » ni de ventes ici. Modifie et réessaie.';

  @override
  String get communityDailyCapReached =>
      'Ça fait 3 posts aujourd\'hui — le compteur repart à minuit.';

  @override
  String get communityTagRequired =>
      'Choisis un tag — il route ton post vers les bonnes personnes.';

  @override
  String communitySosBanner(int count) {
    return '🛡️ $count personnes t\'ont soutenu';
  }

  @override
  String get communityAddVoice => 'Ajoute ta voix…';

  @override
  String communityDayTag(int day) {
    return 'jour $day';
  }

  @override
  String get communityEmptyTitle => 'Pas encore de posts — dis bonjour.';

  @override
  String get communityEmptyBody =>
      'Ton post du Jour 1, c\'est celui que quelqu\'un au Jour 0 a besoin de lire.';

  @override
  String get communityPosted =>
      'Publié. Une rapide vérification passe avant que les autres le voient.';

  @override
  String get communityStatusHeld =>
      'En cours de vérification — pour l\'instant, toi seul peux le voir';

  @override
  String get communityStatusBlocked =>
      'Non publié — il n\'a pas respecté les règles de la communauté';

  @override
  String get communityStatusPosting => 'Publication…';

  @override
  String get communityStatusFailed => 'Non envoyé — touche pour réessayer';

  @override
  String get communityStatusCapped =>
      'Non publié — ça fait 3 aujourd\'hui. Le compteur repart à minuit.';

  @override
  String get buddyLinkCopied =>
      'Lien copié — arrêter avec du renfort, ça change tout.';

  @override
  String get moneyTitle => 'Argent récupéré';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'économisés depuis le $date · $perDay qui rentrent chaque jour';
  }

  @override
  String get moneyBuysLabel => 'CE QUE ÇA PAIE DÉJÀ';

  @override
  String moneyToGo(String amount, int days) {
    return 'encore $amount · ~$days jours à ton rythme';
  }

  @override
  String moneyToGoShort(String amount) {
    return 'encore $amount';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'celui de ton inscription · encore $amount';
  }

  @override
  String get moneySetGoal => 'Crée un objectif';

  @override
  String get moneySetGoalSub =>
      'nomme-le, chiffre-le, regarde la barre se remplir';

  @override
  String get moneyGoalSheetTitle => 'Nouvel objectif d\'épargne';

  @override
  String get moneyGoalNameHint =>
      'Nomme-le — « PS5 », « Lisbonne », « batterie »';

  @override
  String get moneyGoalPriceHint => 'Prix';

  @override
  String get moneyGoalCreate => 'Lancer la barre';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'Le calcul est à toi : $weekly/semaine × 52 = $yearly/an. Aucun chiffre inventé.';
  }

  @override
  String get moneyGoalDone => 'Objectif financé. Confettis mérités. 🎉';

  @override
  String get seedGoalKicks => 'Nouvelles baskets';

  @override
  String get seedGoalTokyo => 'Vol pour Tokyo';

  @override
  String get healthTitle => 'Ton corps guérit';

  @override
  String healthAnchor(String ago) {
    return 'Basé sur ta dernière taffe enregistrée · il y a $ago';
  }

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — tu es ici';
  }

  @override
  String get healthM20min => '20 minutes';

  @override
  String get healthM20minBody =>
      'Le pouls et la tension redescendent à la normale.';

  @override
  String get healthM8h => '8 heures';

  @override
  String get healthM8hBody =>
      'L\'oxygène se normalise pendant que la nicotine baisse.';

  @override
  String get healthM12h => '12 heures';

  @override
  String get healthM12hBody =>
      'Le monoxyde de carbone dans ton sang revient à la normale.';

  @override
  String get healthM24h => '24 heures';

  @override
  String get healthM24hBody =>
      'La nicotine chute vite. Les cravings crient — c\'est la porte de sortie.';

  @override
  String get healthM48h => '48 heures';

  @override
  String get healthM48hBody =>
      'Les terminaisons nerveuses repoussent. Goût et odorat s\'affûtent.';

  @override
  String get healthM72h => '72 heures';

  @override
  String get healthM72hBody =>
      'La nicotine a quasi disparu. Pic de cravings — le Bouton panique vit pour ça.';

  @override
  String get healthM1w => '1 semaine';

  @override
  String get healthM1wBody =>
      'Goût et odorat nettement plus fins. Respirer devient plus facile.';

  @override
  String get healthM2w => '2 semaines';

  @override
  String get healthM2wBody =>
      'La circulation s\'améliore. La fonction pulmonaire commence à grimper.';

  @override
  String get healthM1m => '1 mois';

  @override
  String get healthM1mBody => 'La toux et l\'essoufflement se calment.';

  @override
  String get healthM3m => '3 mois';

  @override
  String get healthM3mBody =>
      'La capacité pulmonaire continue de grimper. La salle a un autre goût.';

  @override
  String get healthM6m => '6 mois';

  @override
  String get healthM6mBody =>
      'Ton niveau de stress de base descend — tu gères les mauvais jours sans.';

  @override
  String get healthM1y => '1 an';

  @override
  String get healthM1yBody =>
      'Ton profil de risque ressemble à quelqu\'un qui n\'a jamais vapoté au quotidien.';

  @override
  String get healthUnlockNote =>
      'Chaque déblocage déclenche une petite célébration + une carte à partager.';

  @override
  String get healthSourceNote =>
      'Basé sur la recherche sur l\'arrêt du tabac — les preuves sur la vape émergent encore.';

  @override
  String get milestonesTitle => 'Étapes';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned sur $total gagnées';
  }

  @override
  String milestonesNext(String name) {
    return 'Prochaine : $name';
  }

  @override
  String milestonesNextProgress(int day, int target, num remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'encore $remaining levers de soleil',
      one: 'encore un lever de soleil',
    );
    return 'jour $day sur $target · $_temp0';
  }

  @override
  String get milestonesNotLeaderboard =>
      'Les badges sont à toi, pas un classement. Aucune grille d\'autrui à comparer.';

  @override
  String get mFirstLog => 'Première taffe loggée';

  @override
  String get mFirstCraving => 'Premier craving vaincu';

  @override
  String get mSpark => 'Étincelle de 3 jours';

  @override
  String get mWeekFlame => 'Flamme de 7 jours';

  @override
  String get mHundredSaved => '100 \$ économisés';

  @override
  String get mCleanWeekend => 'Week-end clean';

  @override
  String get mHelpedSos => 'A aidé un SOS';

  @override
  String get mTwoWeekFlame => 'Flamme de deux semaines';

  @override
  String get mHalfNicotine => 'Nicotine divisée par deux';

  @override
  String get mMoodWeek => 'Semaine d\'humeur';

  @override
  String get mTenCravings => '10 cravings vaincus';

  @override
  String get mQuarterCurve => 'Quart de courbe';

  @override
  String get mInferno => 'Inferno 30 jours';

  @override
  String get mFreedomDay => 'Jour de liberté';

  @override
  String get mFirstPost => 'Premier post';

  @override
  String get mFiveHundredSaved => '500 \$ économisés';

  @override
  String get mComeback => 'Comeback';

  @override
  String get moodTitle => 'C\'est comment, aujourd\'hui ?';

  @override
  String get moodSubtitle => '10 secondes. Ça compte plus que tu ne crois.';

  @override
  String get moodRough => 'rude';

  @override
  String get moodMeh => 'bof';

  @override
  String get moodOkay => 'ça va';

  @override
  String get moodGood => 'bien';

  @override
  String get moodGreat => 'super';

  @override
  String get moodNoteHint =>
      'Une ligne, optionnelle — « soirée boulot ce soir, stressé »';

  @override
  String get moodUnlockTitle => '🔓 Lien humeur ↔ craving';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total check-ins';
  }

  @override
  String moodUnlockNote(int count) {
    return 'Encore $count et ton rapport montrera comment ton humeur pilote tes cravings.';
  }

  @override
  String get moodCta => 'Check-in';

  @override
  String get moodSaved => 'Noté. Les données battent les impressions. 🙌';

  @override
  String get insightLinkTitle => 'Rapport hebdo';

  @override
  String insightTitle(int week, String range) {
    return 'Rapport semaine $week · $range';
  }

  @override
  String get insightWinLabel => 'Ta victoire';

  @override
  String get insightWatchoutLabel => 'À surveiller';

  @override
  String get insightWeekChartLabel => 'BOUFFÉES, 7 DERNIERS JOURS';

  @override
  String get insightCravingsChartLabel => 'ENVIES SURMONTÉES, 7 DERNIERS JOURS';

  @override
  String get insightHoursChartLabel => 'BOUFFÉES PAR HEURE, 14 DERNIERS JOURS';

  @override
  String get insightPendingTitle => 'Pas encore de bilan';

  @override
  String insightPendingBody(String name) {
    return '$name en écrit un chaque dimanche à partir de la semaine que tu as vraiment enregistrée : tes heures, tes humeurs, tes victoires. Rien à montrer tant qu\'il n\'y a pas une semaine à lire.';
  }

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index SUR $total';
  }

  @override
  String get slipTitle => 'Un écart, c\'est de la donnée, pas une défaite.';

  @override
  String slipSubtitle(int days) {
    return 'Tu as loggé des taffes après $days jours clean. C\'est de l\'info — ça nous dit exactement où blinder le plan.';
  }

  @override
  String get slipWhatHappened => 'IL SE PASSAIT QUOI ?';

  @override
  String get slipTriggerParty => 'Soirée';

  @override
  String get slipTriggerStress => 'Stress';

  @override
  String get slipTriggerBoredom => 'Ennui';

  @override
  String get slipTriggerDrinking => 'Alcool';

  @override
  String get slipTriggerFriends => 'Des potes en avaient';

  @override
  String get slipTriggerJustHappened => 'C\'est juste arrivé';

  @override
  String get slipNoBannedWords =>
      'Aucun mot interdit ici, jamais. La plupart de ceux qui arrêtent pour de bon ont craqué en route. Le journal reste honnête, le plan s\'adapte.';

  @override
  String get slipAdjustCta => 'Ajuster mon plan';

  @override
  String get slipAdjustTitle => 'Voilà l\'ajustement.';

  @override
  String get slipCurveLabel => 'TA COURBE — DOUCEMENT RECALCULÉE';

  @override
  String get slipTheBump => 'la bosse de l\'écart';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Jour de liberté : $date (+$days jours)';
  }

  @override
  String get slipCurveNote => 'Deux jours de plus, même destination.';

  @override
  String slipStreakSurvives(int days) {
    return 'Tes $days jours comptent toujours.';
  }

  @override
  String get slipFlameDims =>
      'La flamme faiblit, elle ne meurt pas. Un jour clean la ramène à pleine puissance.';

  @override
  String get slipBackOnCurve => 'Retour sur la courbe';

  @override
  String get slipTalkFirst => 'En parler d\'abord au coach';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'en sevrage depuis le $date · $method · jour $day';
  }

  @override
  String get profileCountdownLabel => '🏆 COMPTE À REBOURS DU JOUR DE LIBERTÉ';

  @override
  String profileDaysTo(String date) {
    return 'jours avant le $date';
  }

  @override
  String get profileLifetimeSaved => 'économies totales';

  @override
  String get profilePuffsNotTaken => 'taffes évitées';

  @override
  String get profileBadgesEarned => 'badges gagnés';

  @override
  String get profileSettings => '⚙️ Réglages';

  @override
  String get profileEditAlias => 'Choisis ton alias';

  @override
  String get profileEditAvatar => 'Choisis ton avatar';

  @override
  String get profileAliasHint => 'anonyme — c\'est tout ce qu\'on voit de toi';

  @override
  String memoriesTitle(String name) {
    return 'Ce que $name retient';
  }

  @override
  String memoriesIntro(String name) {
    return 'Ce que $name sait de toi : ta configuration et tes chiffres en direct de l\'app, plus ce que tu as confié dans le chat — ça, tu peux le faire oublier quand tu veux.';
  }

  @override
  String memoriesEmpty(String name) {
    return 'Rien ici pour l\'instant. Cette partie se remplit quand tu racontes à $name des choses de ta vie dans le chat.';
  }

  @override
  String memoriesSectionKnows(String name) {
    return 'Ce que $name sait toujours';
  }

  @override
  String memoriesSectionTold(String name) {
    return 'Ce que tu as confié à $name';
  }

  @override
  String get memoriesFactPlan => 'Plan';

  @override
  String memoriesFactPlanValue(String method, int days) {
    return '$method · $days jours';
  }

  @override
  String get memoriesFactStarted => 'Début';

  @override
  String get memoriesFactBaseline => 'Point de départ';

  @override
  String memoriesFactBaselineValue(int count) {
    return '$count taffes par jour';
  }

  @override
  String get memoriesFactWhy => 'Ton pourquoi';

  @override
  String get memoriesFactWorries => 'Tes craintes';

  @override
  String get memoriesFactWhyWords => 'Avec tes mots';

  @override
  String get memoriesFactFirstPuff => 'Première taffe au réveil';

  @override
  String get memoriesFactFrequency => 'À quelle fréquence';

  @override
  String get memoriesFactDay => 'Où tu en es';

  @override
  String memoriesFactDayValue(int day, int total) {
    return 'Jour $day sur $total';
  }

  @override
  String memoriesFactDayMaintenance(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Plan terminé · $count jours après le Jour de la Liberté',
      one: 'Plan terminé · 1 jour après le Jour de la Liberté',
    );
    return '$_temp0';
  }

  @override
  String get memoriesFactToday => 'Aujourd\'hui';

  @override
  String memoriesFactTodayValue(int puffs, int limit) {
    return '$puffs sur $limit taffes';
  }

  @override
  String get memoriesFactStreak => 'Série';

  @override
  String get memoriesFactSaved => 'Économies';

  @override
  String get memoriesFailed => 'Impossible de charger pour le moment.';

  @override
  String get memoriesForget => 'Oublier ça';

  @override
  String memoriesForgotten(String name) {
    return 'Oublié. $name n\'en reparlera pas.';
  }

  @override
  String get memoriesForgetFailed =>
      'Ça n\'a pas été appliqué — c\'est toujours en mémoire.';

  @override
  String get memoriesKindPerson => 'Quelqu\'un de ta vie';

  @override
  String get memoriesKindTrigger => 'Un déclencheur';

  @override
  String get memoriesKindMotivation => 'Pourquoi tu fais ça';

  @override
  String get memoriesKindMilestone => 'Ce que tu vises';

  @override
  String get memoriesKindPreference => 'Comment te parler';

  @override
  String get memoriesKindContext => 'À propos de toi';

  @override
  String settingsMemories(String name) {
    return 'Ce que $name retient';
  }

  @override
  String get moderationTitle => 'File de modération';

  @override
  String get moderationEmpty =>
      'Rien en attente. Tous les signalements sont traités.';

  @override
  String get moderationFailed => 'Impossible d\'ouvrir la file.';

  @override
  String get moderationRetry => 'Réessayer';

  @override
  String get moderationShowReviewed => 'Voir les traités';

  @override
  String moderationPendingCount(int count) {
    return '$count en attente';
  }

  @override
  String get moderationSubjectGone =>
      'Le post n\'existe plus ; il ne reste que le signalement.';

  @override
  String get moderationAllow => 'Autoriser';

  @override
  String get moderationBlock => 'Bloquer';

  @override
  String get moderationDismiss => 'Rien à signaler';

  @override
  String get moderationResolveFailed =>
      'Ça n\'a pas été appliqué. Le post est inchangé.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsAccount => 'Compte';

  @override
  String get settingsSubscription => 'Gérer l\'abonnement';

  @override
  String get settingsSubscriptionValue => 'Premium · annuel';

  @override
  String get settingsSubscriptionFree => 'Plan Gratuit';

  @override
  String get settingsSubscriptionYearly => 'Premium · annuel';

  @override
  String get settingsSubscriptionMonthly => 'Premium · mensuel';

  @override
  String get settingsSubscriptionWeekly => 'Premium · hebdomadaire';

  @override
  String get settingsSubscriptionPremium => 'Premium';

  @override
  String settingsSubscriptionTrial(String date) {
    return 'Essai · se termine le $date';
  }

  @override
  String settingsSubscriptionEnds(String date) {
    return 'Premium · se termine le $date';
  }

  @override
  String get settingsManageUnavailable =>
      'Gère cet abonnement depuis le compte de boutique qui l\'a acheté.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsDangerHours => 'Heures à risque';

  @override
  String settingsDangerHoursEdit(String range) {
    return '$range · modifier ›';
  }

  @override
  String get settingsPrivacy => 'Confidentialité';

  @override
  String get settingsPrivacyNote =>
      'On ne vend jamais tes données. Zéro traqueur. Jamais.';

  @override
  String get settingsDeleteEverything => 'Tout supprimer';

  @override
  String get settingsDeleteConfirmTitle => 'Tout supprimer ?';

  @override
  String get settingsDeleteConfirmBody =>
      'Ton plan, tes taffes, ta série et tes posts — partis pour de bon. C\'est le seul bouton qu\'on ne peut pas annuler.';

  @override
  String get settingsDeleteConfirmCta => 'Oui, tout supprimer';

  @override
  String get settingsAppearance => 'Apparence';

  @override
  String get settingsAppearanceSystem => 'Comme le système';

  @override
  String get settingsAppearanceMidnight => 'Midnight';

  @override
  String get settingsAppearanceDaylight => 'Daylight';

  @override
  String get settingsLanguage => 'Langue';

  @override
  String get settingsLanguageSystem => 'Comme le système';

  @override
  String get settingsSignOut => 'Se déconnecter';

  @override
  String get settingsSignOutConfirmTitle => 'Se déconnecter ?';

  @override
  String get settingsSignOutConfirmBody =>
      'Tes données restent sur ton compte. La série continue de brûler.';

  @override
  String get settingsDangerHoursTitle =>
      'À quelle heure les envies frappent-elles le plus fort ?';

  @override
  String get settingsDangerHoursNote =>
      'Choisis l\'heure où ça commence d\'habitude. On te prévient 10 minutes avant — une notif par jour, pas plus.';

  @override
  String settingsDangerHoursNudge(String time) {
    return 'Une notif à $time, tous les jours.';
  }

  @override
  String get settingsDangerHoursNotifOff =>
      'Les notifications sont désactivées : rien ne partira tant que tu ne les actives pas.';

  @override
  String settingsQuietHours(String range) {
    return 'Jamais entre $range — heures calmes.';
  }

  @override
  String get trialEndingPushTime => 'maintenant';

  @override
  String get trialEndingPush =>
      'ton essai se termine demain — comme promis, voilà le rappel. Aucun prélèvement surprise.';

  @override
  String get trialEndingTitle => 'L\'essai se termine demain.';

  @override
  String get trialEndingBody =>
      'On avait dit qu\'on te préviendrait, alors : voilà. Garde Premium, ou passe en Gratuit — ta série, ton plan et ton historique restent quoi qu\'il arrive.';

  @override
  String get trialEndingStatsLabel => 'TA SEMAINE JUSQU\'ICI';

  @override
  String get trialEndingVsDay1 => 'taffes vs jour 1';

  @override
  String get trialEndingCravings => 'cravings vaincus';

  @override
  String get trialEndingSaved => 'économisés';

  @override
  String get trialEndingKeep => 'Garder Premium';

  @override
  String get trialEndingSwitchFree => 'Passer en Gratuit (tes données restent)';

  @override
  String trialEndsOn(String date) {
    return 'Ton essai se termine le $date.';
  }

  @override
  String get trialEndingNotifTitle => 'Ton essai se termine demain';

  @override
  String get frameMapTitle => 'Les 52 écrans du design';

  @override
  String get frameMapOpen => 'Parcourir les 52 écrans →';

  @override
  String get frameMapNote =>
      'Chaque écran des quatre handoffs, à un tap. Les lignes chargent le parcours démo ou les réponses du quiz si besoin.';

  @override
  String get frameMapEdgeNote =>
      'Ces états s\'activeront avec le backend — une app en mémoire n\'a ni hors-ligne ni erreurs serveur à montrer honnêtement.';

  @override
  String get seedPostWin30 =>
      'JOUR DE LIBERTÉ. 30 jours, zéro taffe la dernière semaine. Le bouton panique m\'a porté tous les week-ends. Si tu es au jour 2 et que tu meurs — ça devient vraiment plus facile vers le jour 8.';

  @override
  String get seedPostSos =>
      'devant la station-service. portefeuille en main. que quelqu\'un me raisonne';

  @override
  String get seedPostDay1 =>
      'j\'ai jeté la mienne dans le lac. sûrement pas top pour le lac. le jour 1 commence maintenant';

  @override
  String get seedPostVent =>
      'mon collègue souffle des nuages mangue à son bureau TOUTE LA JOURNÉE et je suis censé… me concentrer ? je vide mon sac pour ne pas craquer';

  @override
  String get seedPostMilestone =>
      'deux semaines. j\'ai pris l\'escalier jusqu\'au 4e aujourd\'hui sans sonner comme un accordéon hanté. petites victoires';

  @override
  String get seedPostWinParty =>
      'toute une soirée sans emprunter la puff de personne. mes mains ont survécu en tenant une eau pétillante citron vert comme un ovni';

  @override
  String get seedReplyWalk =>
      'marche. juste un pâté de maisons. le portefeuille reste plein, toi tu restes libre. j\'ai fait exactement ça mardi';

  @override
  String get seedReplyScience =>
      'le jour 4 est le pire, c\'est de la science. tu es au pic LÀ MAINTENANT. 15 minutes et ça meurt';

  @override
  String get seedReplyGatorade =>
      'achète un soda à la place. achat cérémoniel. ça marche bizarrement bien';

  @override
  String get seedReplyUpdate =>
      'update : soda acheté. je rentre à pied. merci, sincèrement 💙';

  @override
  String get dangerReminderTitle => 'Ton heure à risque approche';

  @override
  String get dangerReminderBody =>
      'C\'est souvent maintenant que ça frappe. Tu as un plan, et 15 minutes suffisent.';

  @override
  String get communityLoading => 'On charge le fil…';

  @override
  String memoriesLoading(String name) {
    return 'On regarde ce que $name a retenu…';
  }

  @override
  String get coachLoadingThread => 'On récupère votre conversation…';

  @override
  String get moderationLoading => 'Chargement de la file…';

  @override
  String get authWorking => 'Une seconde…';

  @override
  String get slipCurveNoteParty =>
      'Deux jours de plus, même destination. Avant la prochaine soirée, règle une heure à risque pour que le rappel arrive avant.';

  @override
  String get slipCurveNoteStress =>
      'Deux jours de plus, même destination. Quand le stress monte, la respiration de 60 secondes du bouton panique est faite pour cette minute-là.';

  @override
  String get slipCurveNoteBoredom =>
      'Deux jours de plus, même destination. Pour les minutes creuses, le jeu du mode panique est à un geste.';

  @override
  String get slipCurveNoteDrinking =>
      'Deux jours de plus, même destination. Règle une heure à risque avant ton prochain verre — le rappel arrive avant le premier.';

  @override
  String get slipCurveNoteFriends =>
      'Deux jours de plus, même destination. La prochaine fois, écris à ton coach avant de les voir, pas après.';

  @override
  String get slipCurveNoteJustHappened =>
      'Deux jours de plus, même destination. Ça arrive. Le journal reste honnête, et demain est une journée propre.';
}
