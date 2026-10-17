// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline => 'Il tuo ultimo tiro è più vicino\ndi quanto pensi.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · fatto da gente che ha smesso';
  }

  @override
  String get commonContinue => 'Continua';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonDone => 'Fatto';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonUndo => 'Annulla';

  @override
  String get commonEdit => 'Modifica';

  @override
  String get commonClose => 'Chiudi';

  @override
  String get commonBack => 'Indietro';

  @override
  String get commonNotNow => 'Non ora';

  @override
  String get commonMaybeLater => 'Magari dopo';

  @override
  String commonDayN(int day) {
    return 'giorno $day';
  }

  @override
  String get authSignInTitle => 'Mettiamo al sicuro\nil tuo piano.';

  @override
  String get authSignInSubtitle =>
      'Tutto anonimo di default — per la community ti scegli un alias.';

  @override
  String get authSignInWithApple => 'Accedi con Apple';

  @override
  String get authSignInWithGoogle => 'Accedi con Google';

  @override
  String get authContinueWithEmail => 'Continua con l\'email';

  @override
  String get authWhyAccountDivider => 'perché un account?';

  @override
  String get authWhyAccountCard =>
      'Serie, piano e memoria del coach si sincronizzano su tutti i tuoi dispositivi. 🔒 Non vendiamo i tuoi dati. Niente tracker pubblicitari. Mai.';

  @override
  String get authTerms => 'Termini';

  @override
  String get authPrivacy => 'Privacy';

  @override
  String get legalEula => 'EULA';

  @override
  String get authRegisterTitle => 'Crea il tuo account';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'PASSWORD';

  @override
  String get authShowPassword => 'mostra';

  @override
  String get authHidePassword => 'nascondi';

  @override
  String get authPasswordStrengthWeak => 'continua a scrivere…';

  @override
  String get authPasswordStrengthDecent => 'password discreta';

  @override
  String get authPasswordStrengthStrong => 'password forte';

  @override
  String get authNoSpamCard =>
      'Niente spam, niente email “ci manchi”. Account = backup, fine.';

  @override
  String get authCreateAccount => 'Crea account';

  @override
  String get authAlreadyHaveOne => 'Ne hai già uno?';

  @override
  String get authLogIn => 'Accedi';

  @override
  String get authLoginTitle => 'Rieccoti.';

  @override
  String get authLoginSubtitle => 'La tua serie ha sentito la tua mancanza.';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authNewHere => 'Prima volta qui?';

  @override
  String get authWrongPassword => 'non è quella — riprova';

  @override
  String get authForgotTitle => 'Capita a tutti.';

  @override
  String get authForgotSubtitle =>
      'Lasciaci la tua email — ti mandiamo un link per il reset. La tua serie resta intatta.';

  @override
  String get authLinkSent => 'Link inviato. Se non lo vedi, guarda nello spam.';

  @override
  String get authResendLink => 'Reinvia il link';

  @override
  String authResendCountdown(int seconds) {
    return 'Reinvia tra ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Torna all\'accesso';

  @override
  String get authInvalidEmail => 'questa non sembra un\'email';

  @override
  String get authEmailInUse => 'questa email ha già un percorso — accedi';

  @override
  String get authPasswordTooShort =>
      'la password vuole almeno 6 caratteri — ancora qualcuno e ci sei';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint => 'tiri al giorno — stai per scoprirlo';

  @override
  String get obWelcomeTitle => 'Quanto sei dipendente, davvero?';

  @override
  String get obWelcomeSubtitle =>
      'Check-up di 2 minuti. Risultati brutalmente onesti. Un piano fatto su misura per te.';

  @override
  String get obWelcomeCta => 'Inizia il check-up';

  @override
  String get obWelcomeHaveAccount => 'Hai già un account?';

  @override
  String get obResumeTitle => 'Riprendiamo da dove avevi lasciato?';

  @override
  String obResumeBody(int answered, int total) {
    return 'Avevi risposto a $answered domande su $total. Non si è perso niente.';
  }

  @override
  String get obResumeCta => 'Vai avanti';

  @override
  String get obResumeFresh => 'Ricomincia da zero';

  @override
  String get obGenderTitle => 'Come ti identifichi?';

  @override
  String get obGenderSubtitle =>
      'Serve a calibrare il piano — il metabolismo della nicotina cambia.';

  @override
  String get obGenderWoman => 'Donna';

  @override
  String get obGenderMan => 'Uomo';

  @override
  String get obGenderNonBinary => 'Persona non binaria / preferisco non dirlo';

  @override
  String get obGenderPrivacyNote => '🔒 Privato. La community non lo vede mai.';

  @override
  String get obBirthYearTitle => 'Qual è il tuo anno di nascita?';

  @override
  String get obBirthYearSubtitle => 'Il piano si adatta alla tua età.';

  @override
  String get obBirthYearHint => 'Anno o età — va bene uno dei due.';

  @override
  String obBirthYearAge(int age) {
    return 'Hai $age anni.';
  }

  @override
  String obBirthYearAgeOffer(int age, int year) {
    return '$age anni? Allora l\'anno di nascita è il $year.';
  }

  @override
  String get obBirthYearAgeConfirm => 'Sono io';

  @override
  String obBirthYearUnderConfirm(int year, int age) {
    return 'Anno $year? Quindi hai $age anni.';
  }

  @override
  String obBirthYearUnderCta(int age) {
    return 'Sì, ho $age anni';
  }

  @override
  String get obBirthYearFix => 'Aspetta, correggo';

  @override
  String get obBirthYearErrorFuture =>
      'Quell\'anno non è ancora arrivato. Riprovi?';

  @override
  String get obBirthYearErrorTooOld =>
      'La persona più longeva mai verificata è arrivata a 122 anni. Riproviamo.';

  @override
  String get obBirthYearErrorUnknown =>
      'Non è un anno — e nemmeno un\'età. Ancora un tentativo.';

  @override
  String get obUnder18Title => 'Qui non possiamo aiutarti — ma questi sì.';

  @override
  String get obUnder18Subtitle =>
      'Cirrus è pensata per chi ha 18 anni o più. Questi due servizi sono gratuiti, riservati e fatti per la tua età. E funzionano.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Messaggi ogni giorno da gente che ci è passata. Oltre 500.000 giovani iscritti.';

  @override
  String get obUnder18TiqCta => 'Invia DITCHVAPE via SMS all\'88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Coaching gratuito via SMS o telefono, pensato per adolescenti. Zero prediche.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'Facciamo il tifo per te. Torna a 18 anni se ti serviamo ancora — non ti serviremo. 💪';

  @override
  String get obTriedTitle => 'Hai già provato a smettere?';

  @override
  String get obTriedNever => 'Mai';

  @override
  String get obTriedNeverSub => 'prima volta';

  @override
  String get obTriedOnce => 'Una volta';

  @override
  String get obTriedOnceSub => 'non è durata';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'qualche round';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'ho perso il conto';

  @override
  String get obTriedReaction =>
      'Quasi tutti hanno bisogno di qualche tentativo. Ognuno ha insegnato qualcosa al tuo cervello — stavolta hai un piano.';

  @override
  String get obFrequencyTitle => 'Quanto spesso ce l\'hai in mano?';

  @override
  String get obFrequencySubtitle => 'Zero giudizi. Solo calibrazione.';

  @override
  String get obFreqDaily => 'OGNI GIORNO';

  @override
  String get obFreqDailySub => 'Tutti i giorni, ma con vere pause in mezzo.';

  @override
  String get obFreqOften => 'SPESSO';

  @override
  String get obFreqOftenSub => 'Per gran parte della giornata, a sessioni.';

  @override
  String get obFreqAlways => 'SEMPRE';

  @override
  String get obFreqAlwaysSub => 'Ormai è un pezzo della mia mano.';

  @override
  String get obPuffsTitle => 'Quanti tiri in un giorno normale?';

  @override
  String get obPuffsBadgeLight => 'Abitudine leggera';

  @override
  String get obPuffsBadgeModerate => 'Dipendenza moderata';

  @override
  String get obPuffsBadgeHeavy => 'Dipendenza forte';

  @override
  String get obPuffsBadgeSevere => 'Dipendenza grave';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ i tiri di $count sigarette';
  }

  @override
  String get obPuffsNotSure =>
      'Non lo sai? Stimalo da quanto ti dura la svapo →';

  @override
  String get obPuffsHelperTitle => 'Stima veloce';

  @override
  String get obPuffsHelperBody =>
      'Una usa e getta tipica fa ~600 tiri. Quante ne finisci a settimana?';

  @override
  String obPuffsHelperResult(int count) {
    return 'Fanno circa $count tiri al giorno. Nella prima settimana il numero si corregge da solo.';
  }

  @override
  String obPuffsHelperDevicesPerWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count svapo / settimana',
      one: '$count svapo / settimana',
    );
    return '$_temp0';
  }

  @override
  String get obStrengthTitle => 'Quanto è forte quella che usi di solito?';

  @override
  String get obStrength20Sub => '2% · più leggera';

  @override
  String get obStrength35Sub => '3,5% · media';

  @override
  String get obStrength50Sub => '5% · quasi tutte le usa e getta';

  @override
  String get obStrengthNotSure => 'Non lo so';

  @override
  String get obStrengthNotSureSub => 'nessun problema';

  @override
  String get obStrengthNote =>
      'Quasi tutte le usa e getta sono al 5% — nel dubbio, è la stima più sicura.';

  @override
  String get obSpendTitle => 'Quanto ti costa a settimana?';

  @override
  String get obSpendPerWeek => 'a settimana';

  @override
  String get obSpendThats => 'fanno';

  @override
  String obSpendPerYear(String amount) {
    return '$amount all\'anno';
  }

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / mese';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / giorno';
  }

  @override
  String get obSpendYourMath => 'i conti sono tuoi, non nostri';

  @override
  String obSpendComparisonOne(String item) {
    return 'È $item. Ogni anno.';
  }

  @override
  String obSpendComparisonTwo(String item) {
    return 'È $item — due volte. Ogni anno.';
  }

  @override
  String obSpendComparisonMany(String item, int count) {
    return 'È $item, per $count volte. Ogni anno.';
  }

  @override
  String get obSpendItemGymMonth => 'un mese di palestra';

  @override
  String get obSpendItemConcertTicket =>
      'un biglietto per un concerto, posti buoni';

  @override
  String get obSpendItemRunningShoes => 'un bel paio di scarpe da corsa';

  @override
  String get obSpendItemDentalCleaning => 'una pulizia dei denti';

  @override
  String get obSpendItemWinterCoat =>
      'un cappotto invernale che tiene caldo davvero';

  @override
  String get obSpendItemFestivalTicket =>
      'un biglietto per un festival, campeggio compreso';

  @override
  String get obSpendItemWeekendAway => 'un weekend fuori';

  @override
  String get obSpendItemBike => 'una bici come si deve';

  @override
  String get obSpendItemDrivingLessons =>
      'un corso completo di guide per la patente';

  @override
  String get obSpendItemNewPhone => 'un telefono nuovo';

  @override
  String get obSpendItemLaptop => 'un portatile che non sta morendo';

  @override
  String get obSpendItemEmergencyFund => 'un vero fondo per le emergenze';

  @override
  String get obSpendItemYogaYear => 'un anno di yoga illimitato';

  @override
  String get obSpendItemMonthOfRent => 'un mese di affitto';

  @override
  String get obSpendItemFamilyHoliday => 'una vacanza in famiglia';

  @override
  String get obSpendItemUsedCar => 'una macchina che ti ci porta';

  @override
  String get obFirstPuffTitle => 'Il primo tiro dopo la sveglia?';

  @override
  String get obFirstPuffWithin5 => 'Entro 5 minuti';

  @override
  String get obFirstPuff5to30 => '5–30 minuti';

  @override
  String get obFirstPuff30to60 => '30–60 minuti';

  @override
  String get obFirstPuffHourPlus => 'Un\'ora o più';

  @override
  String get obFirstPuffScience =>
      'Il tempo che passa prima del primo tiro è il singolo indicatore più forte di dipendenza. Il 76% dei giovani che svapano la prende in mano entro 30 min dal risveglio.';

  @override
  String get obFactLabelScience => 'LA SCIENZA';

  @override
  String get obFactLabelYourNumbers => 'I TUOI NUMERI';

  @override
  String get obFactTried =>
      'Tra i giovani che svapano ogni giorno, i tentativi falliti di smettere sono passati dal 28% al 53% tra il 2020 e il 2024. I dispositivi sono diventati più bravi nel loro mestiere. Non sei tu che ti indebolisci — è una corsa agli armamenti a cui nessuno ti ha chiesto di iscriverti.';

  @override
  String obFactStrength(int mg) {
    return 'Sono ≈$mg mg di nicotina al giorno. Numeri tuoi, moltiplicazione nostra. La tua svapo, intanto, non ti ha mai suggerito una porzione.';
  }

  @override
  String get obFactWorryCravings =>
      'Quasi tutte le voglie salgono e passano in 15–20 minuti. Meno dell\'attesa per un tavolo. Il tasto panico è costruito proprio su quella finestra.';

  @override
  String get obFactWorrySocial =>
      'Il sostegno di chi ci sta passando aumenta di circa il 40% le probabilità di smettere. Sì — sconosciuti su internet. Ha sorpreso anche noi.';

  @override
  String get obWhyTitle => 'Perché vuoi uscirne?';

  @override
  String get obWhySubtitle =>
      'Scegli tutti quelli che senti tuoi. Il coach li userà quando si fa dura.';

  @override
  String get obWhyHealth => 'Salute';

  @override
  String get obWhyMoney => 'Soldi';

  @override
  String get obWhyFreedom => 'Libertà';

  @override
  String get obWhyFamily => 'Famiglia';

  @override
  String get obWhyFitness => 'Forma fisica';

  @override
  String get obWhyAppearance => 'Aspetto';

  @override
  String get obWhyCardLabel => 'IL TUO PERCHÉ';

  @override
  String get obWorriesTitle => 'Cosa ti preoccupa di più?';

  @override
  String get obWorriesSubtitle =>
      'Rispondi con onestà. Questa è la parte utile.';

  @override
  String get obWorryCravings => 'Voglie';

  @override
  String get obWorryStress => 'Stress';

  @override
  String get obWorrySocial => 'Pressione degli altri';

  @override
  String get obWorryFailing => 'Paura di fallire';

  @override
  String get obWorryWeight => 'Ingrassare';

  @override
  String get obWorryBreaks => 'Perdere le mie pause';

  @override
  String get obWorriesAiNote =>
      'Il tuo coach si prepara proprio su questi. Voglia alle 23? Conosce già le tue mosse.';

  @override
  String get obMethodFailingNote =>
      'Hai scelto “paura di fallire” — quindi questo piano si piega invece di spezzarsi. Uno scivolone ritocca la curva; niente si azzera mai.';

  @override
  String get obMethodTitle => 'Come vuoi farlo?';

  @override
  String get obMethodSubtitle =>
      'Funzionano entrambi. Una riga onesta per ciascuno.';

  @override
  String get obMethodTaper => 'A scalare';

  @override
  String get obMethodTaperSub =>
      'Cali un po\' ogni giorno seguendo una curva. Astinenza più morbida, ci vuole disciplina.';

  @override
  String get obMethodTaperReco => 'Ideale da 100+ tiri/giorno — cioè tu';

  @override
  String get obMethodCold => 'Di colpo';

  @override
  String get obMethodColdSub =>
      'Uno stop netto. Prima settimana tosta, ma ne esci prima.';

  @override
  String get obMethodColdReco => 'Fattibile al tuo livello — decidi tu';

  @override
  String get obPaceTitle => 'Scegli il tuo ritmo.';

  @override
  String obPaceMostChosen(int days) {
    return '$days giorni — il più scelto';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count tiri';
  }

  @override
  String get obPaceCurveLabel => 'la tua curva';

  @override
  String get obPaceCurveEnd => '0 tiri';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Freedom Day';
  }

  @override
  String get obPaceNote =>
      'La curva si ridisegna in diretta quando tocchi un ritmo. Date vere, non “giorno n”.';

  @override
  String get obPaceCta => 'Blocca il mio ritmo';

  @override
  String get obBuildingTitle => 'Costruiamo il tuo piano…';

  @override
  String obBuildingStep1(int count) {
    return 'Analizziamo $count tiri/giorno';
  }

  @override
  String get obBuildingStep2 => 'Mappiamo i tuoi trigger';

  @override
  String obBuildingStep3(int days) {
    return 'Calibriamo la tua curva di $days giorni…';
  }

  @override
  String get obBuildingStep4 => 'Ti riserviamo il coach…';

  @override
  String obRevealTitle(int days) {
    return 'Il tuo piano di $days giorni per mollarla.';
  }

  @override
  String get obRevealMilestone3 =>
      'picco delle voglie — qui ci facciamo sentire di più';

  @override
  String get obRevealMilestone7 => 'tornano gusto e olfatto';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Freedom Day — $date';
  }

  @override
  String get obRevealSavedLabel => 'risparmiati entro il Freedom Day';

  @override
  String get obRevealPuffsLabel => 'tiri che non farai';

  @override
  String get obRevealProofLabel => 'PROVA ONESTA';

  @override
  String get obRevealProof =>
      'Il 24% smette con un programma strutturato contro il 19% da soli — studio randomizzato su 2.588 giovani adulti. Niente magia. Più probabilità.';

  @override
  String obRevealComparisonOne(String item) {
    return 'Entro il Freedom Day, è $item.';
  }

  @override
  String obRevealComparisonTwo(String item) {
    return 'Entro il Freedom Day, è $item — due volte.';
  }

  @override
  String obRevealComparisonMany(String item, int count) {
    return 'Entro il Freedom Day, è $item, per $count volte.';
  }

  @override
  String get obRevealCta => 'Ci sono';

  @override
  String get obCommitTitle => 'Rendilo reale.';

  @override
  String get obCommitSubtitle => 'Tieni premuto il tasto. Sul serio.';

  @override
  String get obCommitHold => 'Tieni\npremuto';

  @override
  String get obCommitFreedomLabel => '🏆 FREEDOM DAY';

  @override
  String obCommitDaysOut(int days) {
    return '$days giorni da oggi. È segnato in calendario.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 Non vendiamo i tuoi dati. Niente tracker pubblicitari. Mai.';

  @override
  String get reviewAskTitle =>
      'La recensione di chi ha smesso aiuta il prossimo a trovarci.';

  @override
  String get reviewAskSubtitle => '30 secondi. Puoi saltare. Senza rancore.';

  @override
  String get reviewAskCta => 'Valuta Cirrus';

  @override
  String get obCoachNameTitle => 'Ecco il tuo coach.';

  @override
  String get obCoachNameSubtitle =>
      'Il tuo coach. Ha smesso due anni fa, ricorda benissimo com\'era e ha già letto il tuo piano.';

  @override
  String obCoachNameAsk(String name) {
    return 'Per noi si chiama $name. Ma risponde a qualsiasi nome — scegli quello a cui scriveresti alle 2 di notte.';
  }

  @override
  String get obCoachNameFieldLabel => 'Nome del coach';

  @override
  String get obCoachNameSuggestions => 'Oppure prendine uno:';

  @override
  String obCoachNameKeep(String name) {
    return 'Tengo $name';
  }

  @override
  String get obCoachNameCta => 'È questo';

  @override
  String get obCoachNameLater =>
      'Puoi cambiarlo quando vuoi nelle Impostazioni.';

  @override
  String get obCoachNameAiNote =>
      'Il tuo coach è un\'IA. Quello che gli scrivi viene elaborato da Google Gemini per risponderti — mai venduto, mai usato per la pubblicità.';

  @override
  String get obCoachNameErrorEmpty => 'Serve un nome con cui chiamarlo.';

  @override
  String get obCoachNameErrorLong => 'Massimo 20 caratteri.';

  @override
  String get obCoachNameErrorChars => 'Solo lettere, numeri, spazi e - \'.';

  @override
  String get obCoachNameErrorRejected => 'Scegliamone un altro.';

  @override
  String get settingsCoachName => 'Il nome del tuo coach';

  @override
  String coachRenamed(String name) {
    return 'Va bene — da ora in poi $name.';
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
    return 'Una cosa che $name deve sapere.';
  }

  @override
  String get obWhyWordsSubtitle =>
      'Perché adesso? Non la risposta da opuscolo — quella vera.';

  @override
  String get obWhyWordsFieldLabel => 'Con parole tue';

  @override
  String get obWhyWordsHintHealth =>
      'per smettere di fare le scale fischiando come una caffettiera';

  @override
  String get obWhyWordsHintMoney => 'Rivoglio i miei soldi. E le mie mattine.';

  @override
  String get obWhyWordsHintFreedom =>
      'perché basta con le corse al distributore alle 23';

  @override
  String get obWhyWordsHintFamily =>
      'mio figlio l\'ha trovata nella mia giacca. Mai più.';

  @override
  String get obWhyWordsHintFitness => 'per correre con lei senza fermarmi';

  @override
  String get obWhyWordsHintAppearance =>
      'rivoglio la mia faccia nella versione riposata';

  @override
  String obWhyWordsNote(String name) {
    return '$name se lo ricorderà.';
  }

  @override
  String get obWhyWordsErrorLong => 'Massimo 200 caratteri.';

  @override
  String get obWhyWordsCta => 'Ecco perché';

  @override
  String get obWhyWordsSkip => 'Salta';

  @override
  String get obNotifTitle => 'Rinforzi, proprio quando stai per cedere.';

  @override
  String get obNotifSubtitle =>
      'Niente spam. Un promemoria prima dei tuoi orari a rischio, il punto della sera sul tuo piano, e due parole quando raggiungi un traguardo.';

  @override
  String get obNotifPreviewTime => 'ven 21:54';

  @override
  String get obNotifPreviewBody =>
      'occhio — il venerdì sera è il tuo picco. Il piano è pronto 💪';

  @override
  String get obNotifBullet1 =>
      'Avviso prima degli orari a rischio (gli orari li scegli tu)';

  @override
  String get obNotifBullet2 =>
      'Il punto della sera, e una festa a ogni traguardo';

  @override
  String get obNotifBullet3 => 'Nient\'altro — zero marketing, mai';

  @override
  String get obNotifCta => 'Attiva i rinforzi';

  @override
  String get paywallTitleUpgrade => 'Vai più lontano con Premium.';

  @override
  String get paywallRevealLabel => 'IL TUO PIANO';

  @override
  String get paywallFeatCoach =>
      'Coach IA senza limiti che ricorda il tuo perché';

  @override
  String get paywallFeatPanic => 'Tutti e tre i giochi panico, non solo Sfere';

  @override
  String get paywallFeatPlan => 'Un piano che si adatta quando cedi';

  @override
  String get paywallFeatForecasts =>
      'Previsioni delle voglie per i tuoi orari a rischio';

  @override
  String get paywallFeatCommunity => 'Una community che risponde al tuo SOS';

  @override
  String get paywallFeatReports => 'Report settimanale con i tuoi numeri';

  @override
  String get paywallFeatThemes => 'Altri due temi colore, chiari e scuri';

  @override
  String get paywallYearly => 'ANNUALE';

  @override
  String get paywallYearlyBadge => 'PIÙ CONVENIENTE';

  @override
  String get paywallMonthly => 'MENSILE';

  @override
  String get paywallWeekly => 'SETTIMANALE';

  @override
  String get paywallWeeklySub => 'Prezzo fondatori — bloccato per sempre';

  @override
  String get paywallTrialReminder =>
      '🔔 Ti avvisiamo prima che finisca la prova';

  @override
  String get paywallCancelAnytime => 'Disdici quando vuoi';

  @override
  String get paywallAnchor => 'Meno di una usa e getta a settimana';

  @override
  String get paywallCta => 'Inizia la settimana gratis';

  @override
  String get paywallFreeLink => 'Continua con il piano Free →';

  @override
  String get paywallTimelineToday => 'Oggi';

  @override
  String paywallTimelineDay(int n) {
    return 'Giorno $n';
  }

  @override
  String get paywallTimelineTodayBody => 'Tutto sbloccato';

  @override
  String get paywallTimelineRemindBody => 'Ti avvisiamo';

  @override
  String get paywallTimelineNoRemindBody => 'Ultimo giorno per disdire gratis';

  @override
  String paywallTimelineChargeBody(String price) {
    return 'Primo addebito $price. Disdici prima e non paghi nulla.';
  }

  @override
  String paywallPerYear(String price) {
    return '$price/anno';
  }

  @override
  String paywallPerMonth(String price) {
    return '$price/mese';
  }

  @override
  String paywallPerWeek(String price) {
    return '$price/sett.';
  }

  @override
  String paywallDisclosureTrial(
    String price,
    String period,
    int days,
    String store,
  ) {
    return '$price ogni $period dopo la prova gratuita di $days giorni. Si rinnova in automatico finché non disdici — puoi farlo quando vuoi dalle impostazioni abbonamenti di $store.';
  }

  @override
  String paywallDisclosure(String price, String period, String store) {
    return '$price ogni $period. Si rinnova in automatico finché non disdici — puoi farlo quando vuoi dalle impostazioni abbonamenti di $store.';
  }

  @override
  String get paywallPeriodWeek => 'settimana';

  @override
  String get paywallPeriodMonth => 'mese';

  @override
  String get paywallPeriodYear => 'anno';

  @override
  String get paywallStoreApple => 'App Store';

  @override
  String get paywallStoreGoogle => 'Google Play';

  @override
  String paywallYearlySubLive(String perWeek, int percent) {
    return '$perWeek/settimana · RISPARMI IL $percent%';
  }

  @override
  String paywallYearlySubPerWeek(String perWeek) {
    return '$perWeek/settimana';
  }

  @override
  String paywallCtaTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Inizia i $days giorni gratis',
      one: 'Inizia il giorno gratis',
    );
    return '$_temp0';
  }

  @override
  String get paywallCtaSubscribe => 'Attiva Premium';

  @override
  String paywallSubtitleTrial(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Prova tutto gratis per $days giorni.',
      one: 'Prova tutto gratis per un giorno.',
    );
    return '$_temp0';
  }

  @override
  String get paywallSubtitleNoTrial => 'Tutto sbloccato, da oggi.';

  @override
  String get paywallRestore => 'Ripristina acquisti';

  @override
  String get paywallRestored => 'Rieccoti — Premium è attivo.';

  @override
  String get paywallRestoreNothing =>
      'Per ora su questo account dello store non c\'è niente da ripristinare.';

  @override
  String get paywallPurchasePending =>
      'Il pagamento è in sospeso. Premium si attiva appena lo store lo conferma.';

  @override
  String get paywallPricesUnavailable =>
      'I prezzi aggiornati al momento non si caricano — lo store ti mostra il prezzo esatto prima della conferma.';

  @override
  String get premiumWelcomeEyebrow => 'Premium sbloccato';

  @override
  String get premiumWelcomeTitle => 'Ci sei.';

  @override
  String premiumWelcomeTrialBody(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days giorni',
      one: 'Un giorno',
    );
    return '$_temp0 di tutto, offre la casa.';
  }

  @override
  String get premiumWelcomeBody =>
      'Tutto quello che vedi qui sotto è tuo, da questo istante.';

  @override
  String get premiumWelcomeUnlocks => 'Cosa si è appena sbloccato';

  @override
  String premiumWelcomeCharge(String date) {
    return 'Primo addebito: $date.';
  }

  @override
  String get premiumWelcomeReminder => 'Ti avvisiamo il giorno prima.';

  @override
  String get premiumWelcomeCta => 'Andiamo';

  @override
  String get premiumLockTitle => 'Premium';

  @override
  String get premiumLockCta => 'Scopri Premium';

  @override
  String get premiumPitchInsight =>
      'Il tuo report settimanale, scritto con i tuoi numeri.';

  @override
  String get premiumPitchForecast =>
      'Previsioni delle voglie per le ore in cui di solito la prendi in mano.';

  @override
  String premiumFreeHistoryNote(int days) {
    return 'Free mostra i tuoi ultimi $days giorni.';
  }

  @override
  String premiumPitchCompose(int limit) {
    return 'Questo era il tuo post di oggi. Con Premium pubblichi $limit volte al giorno — e un SOS è sempre gratis.';
  }

  @override
  String get premiumPitchPlan =>
      'Un piano che si adatta quando cedi — il ritocco di stanotte, ogni notte.';

  @override
  String premiumPitchHealth(String from) {
    return 'Il resto della tua timeline: da $from fino a un anno.';
  }

  @override
  String premiumPitchNudge(String hour) {
    return 'Sta arrivando un picco alle $hour. Premium prevede i tuoi orari a rischio prima che arrivino.';
  }

  @override
  String get freePlanColFree => 'FREE';

  @override
  String get freePlanColPro => 'PRO';

  @override
  String get freeCompareLog => 'Diario dei tiri + serie';

  @override
  String get freeCompareMoney => 'Contatore dei risparmi';

  @override
  String get freeCompareCoach => 'Messaggi al coach';

  @override
  String get freeCompareGames => 'Giochi panico';

  @override
  String get freeComparePosts => 'Post nella community';

  @override
  String get freeCompareHistory => 'Storico statistiche';

  @override
  String get freeCompareHealth => 'Timeline della salute';

  @override
  String get freeComparePlan => 'Piano che si adatta ogni notte';

  @override
  String get freeCompareForecast => 'Previsioni delle voglie';

  @override
  String get freeCompareReport => 'Report settimanale';

  @override
  String get freeCompareThemes => 'Temi colore';

  @override
  String freeComparePerDay(int n) {
    return '$n/giorno';
  }

  @override
  String freeCompareDays(int days) {
    return '$days giorni';
  }

  @override
  String freeCompareNodes(int n) {
    return '$n tappe';
  }

  @override
  String get freeCompareForever => 'Tutto';

  @override
  String get freeCompareAll => 'Tutti';

  @override
  String freePlanProCta(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Prova Pro gratis per $days giorni',
      one: 'Prova Pro gratis per un giorno',
    );
    return '$_temp0';
  }

  @override
  String get freePlanTitle => 'Hai il piano Free.';

  @override
  String get freePlanSubtitle =>
      'Tuo per sempre. Niente countdown, niente insistenze.';

  @override
  String get freePlanUpgradeNote =>
      'Fai l\'upgrade quando vuoi — serie e storico vengono con te.';

  @override
  String get freePlanCta => 'Inizia con Free';

  @override
  String get winbackBadge => 'OFFERTA FONDATORI, UNA VOLTA SOLA';

  @override
  String get winbackTitle => 'Ok — il primo mese lo offriamo noi. Quasi.';

  @override
  String get winbackSubtitle =>
      'Il piano l\'hai costruito tu. Prova tutti gli strumenti per un mese prima di decidere.';

  @override
  String get winbackFirstMonth => 'primo mese';

  @override
  String winbackNote(String price) {
    return 'Poi $price/mese. Disdici quando vuoi. Lo vedi una volta sola, poi mai più.';
  }

  @override
  String get winbackCta => 'Prendi il mese fondatori';

  @override
  String get winbackDecline => 'No grazie, mi basta Free';

  @override
  String get day1Title => 'Giorno 1. Si parte.';

  @override
  String get day1Subtitle =>
      'Tre mosse per iniziare. Due minuti. Poi l\'app fa il suo lavoro.';

  @override
  String get day1Task1 => 'Segna il tuo primo tiro';

  @override
  String get day1Task1Done => 'fatto — onestà dal primo tiro';

  @override
  String get day1Task1Sub => 'un tap onesto sul tasto grande';

  @override
  String get day1Task2 => 'Conosci il tuo coach';

  @override
  String get day1Task2Sub =>
      'Un ciao di 30 secondi. Conosce già i tuoi trigger.';

  @override
  String get day1Task3 => 'Imposta i tuoi orari a rischio';

  @override
  String get day1Task3Sub => 'quando cedi? noi arriviamo prima';

  @override
  String get day1Skip => 'Per ora salta il setup';

  @override
  String get day1TourBack => 'Torna al setup';

  @override
  String get day1TourLogTitle => 'L\'app è tutta qui.';

  @override
  String get day1TourLogBody =>
      'Ogni tiro, un tap qui. Solo i conti onesti rendono vero il piano — dai, segnane uno adesso.';

  @override
  String get day1TourCoachTitle => 'Scrivi quello che vuoi.';

  @override
  String day1TourCoachBody(String name) {
    return '$name ha già letto il tuo piano — i tuoi numeri, i tuoi trigger, le ore in cui fai fatica. Scrivi un ciao e guarda.';
  }

  @override
  String get day1TourHoursTitle => 'Quando cedi?';

  @override
  String get day1TourHoursBody =>
      'Scegli l\'ora in cui di solito ti prende. Noi arriviamo dieci minuti prima, sul telefono, senza che tu lo chieda.';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Freedom Day: $date · tra $days giorni · piano attivo';
  }

  @override
  String get day1CtaCoach => 'Conosci il tuo coach';

  @override
  String get day1CtaHome => 'Vai a Oggi';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Giorno $day di $total';
  }

  @override
  String homeGreetingFreedomDay(String date) {
    return '$date · Freedom Day 🏆';
  }

  @override
  String homeGreetingMaintenance(String date, num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni dopo il Freedom Day',
      one: '1 giorno dopo il Freedom Day',
    );
    return '$date · $_temp0';
  }

  @override
  String get homeFreedomDayTitle =>
      'Freedom Day. Questa data l\'hai scelta tu.';

  @override
  String get homeFreedomDayBody =>
      'Il piano finisce oggi e da qui il limite resta a zero. Ogni giorno senza svapo che confermi da adesso è mantenimento — stessa fiamma, stessa serie.';

  @override
  String homeOfferTitle(int day) {
    return 'Giorno $day. Ti serve una mano in più?';
  }

  @override
  String get homeOfferBody =>
      'Premium aggiunge tutta la timeline della salute, un mese di statistiche, tutti i giochi panico e più messaggi al coach. Free resta gratis.';

  @override
  String get homeTitle => 'Oggi';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count giorni',
      one: '🔥 $count giorno',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'tiri oggi';

  @override
  String homeOfLimit(int limit) {
    return 'su $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return 'Ancora $count per oggi. Sei avanti sulla tua curva.';
  }

  @override
  String homeLeftTight(int count) {
    return 'Ancora $count per oggi. Margine stretto — ce la fai.';
  }

  @override
  String homeVsDay1(String percent) {
    return '$percent vs giorno 1';
  }

  @override
  String get homeSavedSoFar => 'risparmiati finora';

  @override
  String get savingsInfoLabel => 'Come si contano i risparmi';

  @override
  String get savingsInfoTitle => 'Come si sommano i tuoi risparmi';

  @override
  String get savingsInfoUsualDay => 'La tua giornata tipo';

  @override
  String savingsInfoUsualDayValue(num puffs, String spend) {
    String _temp0 = intl.Intl.pluralLogic(
      puffs,
      locale: localeName,
      other: '$puffs tiri',
      one: '$puffs tiro',
    );
    return '$_temp0 · $spend';
  }

  @override
  String get savingsInfoToday => 'Oggi';

  @override
  String get savingsInfoTodayNotCounted => 'Non ancora contato';

  @override
  String savingsInfoTodayValue(num puffs, String saved) {
    String _temp0 = intl.Intl.pluralLogic(
      puffs,
      locale: localeName,
      other: '$puffs tiri',
      one: '$puffs tiro',
    );
    return '$_temp0 · $saved risparmiati';
  }

  @override
  String get savingsInfoTotal => 'Risparmiati finora';

  @override
  String get savingsInfoWhyNotCounted =>
      'Oggi inizia a contare dal primo tiro che segni, o quando confermi un giorno senza svapo. Fino ad allora non aggiunge niente.';

  @override
  String savingsInfoWhyKept(int usual, String perPuff, num notTaken) {
    String _temp0 = intl.Intl.pluralLogic(
      notTaken,
      locale: localeName,
      other: '$notTaken tiri non fatti',
      one: '$notTaken tiro non fatto',
    );
    return 'Ogni tiro in meno rispetto ai tuoi soliti $usual vale circa $perPuff. Oggi: $_temp0.';
  }

  @override
  String savingsInfoWhyKeptPerTen(int usual, String perTen, num notTaken) {
    String _temp0 = intl.Intl.pluralLogic(
      notTaken,
      locale: localeName,
      other: '$notTaken tiri non fatti',
      one: '$notTaken tiro non fatto',
    );
    return 'Ogni 10 tiri in meno rispetto ai tuoi soliti $usual valgono circa $perTen. Oggi: $_temp0.';
  }

  @override
  String savingsInfoWhyNothingKept(int usual) {
    return 'Oggi sei ai tuoi soliti $usual tiri o sopra, quindi non si aggiunge niente. Domani si riparte da zero.';
  }

  @override
  String get savingsInfoWhyUnpriced =>
      'Nel tuo piano non c\'è una spesa settimanale, quindi per ora non c\'è niente da contare.';

  @override
  String get homeCravingsBeaten => 'voglie battute';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return 'Che $weekday pesante, eh? L\'ho notato.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'Il tuo picco delle $hour sta arrivando — facciamo un piano?';
  }

  @override
  String get homeLogPuff => 'SEGNA UN TIRO';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => 'Zero tiri oggi?';

  @override
  String get homeVapeFreeCta => 'Conferma giorno senza svapo ✓';

  @override
  String get homeVapeFreeDone =>
      'Giorno senza svapo confermato. È tutto qui il gioco. 🔥';

  @override
  String get homeYesterdayTitle => 'Ieri è stato senza svapo?';

  @override
  String homeYesterdayBody(String date) {
    return 'Ieri ($date) il diario è rimasto vuoto. Lo sai solo tu, quindi chiediamo invece di tirare a indovinare.';
  }

  @override
  String get homeYesterdayYes => 'Senza svapo ✓';

  @override
  String get homeYesterdayNo => 'Ho svapato';

  @override
  String get homeYesterdayDone =>
      'Ieri è confermato. La tua serie sa la verità. 🔥';

  @override
  String homeLoggedSnackCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tiri segnati',
      one: '1 tiro segnato',
    );
    return '$_temp0';
  }

  @override
  String get homeOverLimitTitle => 'Oltre il limite di oggi';

  @override
  String get homeOverLimitBody =>
      'Respira — il limite di domani si adatta. Nessuna vergogna.';

  @override
  String get homeOverLimitBreathe => 'Respira 60s';

  @override
  String get homeOverLimitCoach => 'Parla col coach';

  @override
  String get homeOverLimitFooter =>
      'Continua a segnare onestamente — i dati sono tutto il gioco.';

  @override
  String get homeTokenUsedNote =>
      'Gettone di riparazione usato — la tua serie sopravvive. Oggi la fiamma si abbassa, non si spegne.';

  @override
  String get navHome => 'Home';

  @override
  String get navStats => 'Statistiche';

  @override
  String get navCommunity => 'Community';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'MODALITÀ PANICO · $step DI 3';
  }

  @override
  String get panicBreatheNote =>
      'sale e poi passa — quasi tutte le voglie spariscono in 15 min';

  @override
  String get panicBreatheInstruction => 'Respira insieme al cerchio.';

  @override
  String get panicBreatheIn => 'Inspira';

  @override
  String get panicBreatheHold => 'Trattieni';

  @override
  String get panicBreatheOut => 'Espira';

  @override
  String get panicBreathePattern => 'Inspira 4 · Trattieni 7 · Espira 8';

  @override
  String panicCravingTimer(String time) {
    return 'timer voglia · $time · picco ~15 min';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'timer voglia · $time · il picco peggiore è alle spalle';
  }

  @override
  String get panicSkipToWhy => 'Vai al mio perché →';

  @override
  String get panicWhyTitle => 'Ricorda perché hai iniziato.';

  @override
  String get panicYouSaid => 'L\'HAI DETTO TU';

  @override
  String panicWhyLine(String why, String amount) {
    return 'Lo fai per questo: $why. E per i $amount all\'anno che ti riprendi.';
  }

  @override
  String get panicIntensityQuestion => 'Quanto è forte adesso?';

  @override
  String get panicIntensityLow => 'poca roba';

  @override
  String get panicIntensityHigh => 'urla';

  @override
  String get panicStillCraving => 'Ho ancora voglia — avanti';

  @override
  String get panicItPassed => 'È passata 🎉 tutto ok';

  @override
  String get panicLoopTitle => 'Spezza il loop.';

  @override
  String get panicLoopSubtitle =>
      'Mani e testa hanno bisogno di qualcosa da fare per 60 secondi. Scegli.';

  @override
  String get panicLoopGame => 'Gioca un minuto';

  @override
  String get panicLoopGameSub =>
      'Tessere, Blocchi o Sfere — pollici occupati, testa occupata';

  @override
  String get panicLoopSos => 'Chiedi alla community';

  @override
  String get panicLoopSosSub => 'pubblica un SOS — resta in cima per un\'ora';

  @override
  String get panicLoopCoach => 'Parla col coach';

  @override
  String panicLoopCoachSub(String hour) {
    return 'sa che questo è il tuo stress delle $hour';
  }

  @override
  String get panicLoopCoachDaily =>
      'Ember c\'è — questo usa uno dei messaggi di oggi';

  @override
  String get gameTitle => 'Togli spazio alla voglia.';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get gameNewBest => 'nuovo record';

  @override
  String get gameAnotherRound => 'Ho ancora voglia — altri 60 secondi';

  @override
  String get gameWhy =>
      'Una voglia è soprattutto un\'immagine nella testa. Riempi quello spazio per qualche minuto e avrà meno posto per crescere.';

  @override
  String get gameNameTiles => 'Tessere';

  @override
  String get gameNameBlocks => 'Blocchi';

  @override
  String get gameNameOrbs => 'Sfere';

  @override
  String gameLockedTitle(String game) {
    return '$game è un gioco Premium.';
  }

  @override
  String gameLockedBody(String game) {
    return '$game è tuo gratis, sempre — e funziona altrettanto bene.';
  }

  @override
  String gameLockedPlayFree(String game) {
    return 'Gioca a $game';
  }

  @override
  String get gameHintTiles => 'Tocca la tessera più in basso nella sua corsia.';

  @override
  String get gameHintBlocks =>
      'Trascina per spostare · tocca per ruotare · scorri giù per far cadere';

  @override
  String get gameHintOrbs =>
      'Alcune sfere si illuminano. Seguile con gli occhi mentre si muovono, poi toccale.';

  @override
  String orbsCue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ricorda queste $count',
      one: 'Ricorda questa',
    );
    return '$_temp0';
  }

  @override
  String get orbsCueSub =>
      'Tra un attimo diventano grigie — non perderle di vista';

  @override
  String get orbsTrack => 'Non perderle di vista';

  @override
  String get orbsTrackSub => 'Sta arrivando l\'anello';

  @override
  String orbsPick(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tocca le $count che hai seguito',
      one: 'Tocca quella che hai seguito',
    );
    return '$_temp0';
  }

  @override
  String orbsProgress(int found, int count) {
    return '$found su $count';
  }

  @override
  String orbsPerfect(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tutte e $count — perfetto',
      one: 'Presa — perfetto',
    );
    return '$_temp0';
  }

  @override
  String get orbsRevealSub => 'Erano queste';

  @override
  String gameUnitTiles(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tessere',
      one: '1 tessera',
    );
    return '$_temp0';
  }

  @override
  String gameUnitBlocks(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count righe',
      one: '1 riga',
    );
    return '$_temp0';
  }

  @override
  String gameUnitOrbs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count sfere',
      one: '1 sfera',
    );
    return '$_temp0';
  }

  @override
  String gameMinutesDone(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuti fatti.',
      one: '60 secondi fatti.',
    );
    return '$_temp0';
  }

  @override
  String get gameDoseDone => 'Tre minuti — la dose completa.';

  @override
  String get gameResearchNote =>
      'In uno studio durato una settimana, tre minuti di un gioco visivo hanno ridotto le voglie di circa un quinto.';

  @override
  String get gameIntensityNow => 'E adesso, quanto è forte?';

  @override
  String get gameCapLine =>
      'Sono cinque minuti della tua attenzione. Scegli cosa viene dopo.';

  @override
  String get gameCapTryElse => 'Prova un\'altra strada';

  @override
  String get gamePaused => 'In pausa';

  @override
  String get gamePausedTap => 'Tocca per continuare';

  @override
  String get survivedPlusOne => '+1 voglia battuta';

  @override
  String get survivedLine1 => 'Quella non aveva speranze contro di te.';

  @override
  String get survivedLine2 => 'L\'onda si è spezzata. Tu no.';

  @override
  String get survivedLine3 =>
      '15 minuti di coraggio. In cassaforte per sempre.';

  @override
  String get survivedLine4 => 'Il tuo cervello ha appena capito chi comanda.';

  @override
  String get survivedLine5 => 'Voglia 0 — tu 1. Di nuovo.';

  @override
  String get survivedLine6 => 'Ancora in libertà. Ancora in corsa.';

  @override
  String get survivedLine7 => 'Quel prurito ha appena pagato il te di domani.';

  @override
  String get survivedLine8 => 'Sangue freddo. Nel senso migliore.';

  @override
  String get survivedTotalLabel => 'voglie superate in totale';

  @override
  String get survivedGameNewBest => 'NUOVO RECORD';

  @override
  String survivedGameBest(int best) {
    return 'record $best';
  }

  @override
  String survivedIntensityDrop(int before, int after) {
    return 'Avevi detto $before/10 — ora $after/10.';
  }

  @override
  String get survivedShare => 'Condividi la vittoria ↗';

  @override
  String get survivedBack => 'Torna a oggi';

  @override
  String get survivedShareCopied => 'Card copiata — incollala dove vuoi.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● conosce il tuo piano · giorno $day';
  }

  @override
  String get coachChipCraving => 'Ho voglia';

  @override
  String get coachChipRoughDay => 'Giornata no';

  @override
  String get coachChipSlipped => 'Ho ceduto';

  @override
  String get coachChipProgress => 'I miei progressi';

  @override
  String get coachInputHint => 'Scrivi al tuo coach…';

  @override
  String get coachSend => 'Invia';

  @override
  String coachTyping(String name) {
    return '$name sta scrivendo…';
  }

  @override
  String coachTimeYesterday(String time) {
    return 'Ieri · $time';
  }

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ancora $count messaggi gratis oggi',
      one: 'Ancora $count messaggio gratis oggi',
    );
    return '$_temp0';
  }

  @override
  String coachCapReached(int limit) {
    return 'Questi erano i miei $limit messaggi gratis di oggi — torno a mezzanotte. Mi vuoi 24 ore su 24? Premium serve a questo.';
  }

  @override
  String coachCapReachedPremium(int limit) {
    return 'Siamo a $limit messaggi oggi — mi hai usato sul serio, e mi fa piacere. Torno a mezzanotte.';
  }

  @override
  String get coachConnectionLost =>
      'Il segnale è caduto a metà pensiero 😅 Io sono ancora qui — me lo ridici quando torni online?';

  @override
  String get coachBackendRejected =>
      'Ok, colpa nostra — il server non ha riconosciuto l\'app, quindi il tuo messaggio non mi è mai arrivato. Non è la tua connessione, non sei tu. Ci stiamo lavorando.';

  @override
  String get errorOfflineBanner =>
      'offline — i tiri segnati contano lo stesso, sincronizziamo dopo';

  @override
  String get errorOfflineTitle => 'Niente wifi, nessun problema';

  @override
  String get errorOfflineBody =>
      'In questo momento sei offline. Non si perde niente — riconnettiti e ripartiamo da dove avevi lasciato.';

  @override
  String get splashJourneyUnavailableTitle =>
      'Non riusciamo a caricare il tuo percorso';

  @override
  String get splashJourneyUnavailableBody =>
      'La tua sessione è ancora attiva e non si è perso niente. Controlla la connessione e riprova.';

  @override
  String get errorGenericTitle => 'Ops, qualcosa si è inceppato';

  @override
  String get errorGenericBody =>
      'Colpa nostra, non tua. Riprova tra un attimo.';

  @override
  String get errorSignInUnavailableTitle =>
      'L\'accesso con Apple non è andato a buon fine';

  @override
  String get errorSignInUnavailableBody =>
      'Di solito vuol dire che su questo telefono non c\'è un Account Apple collegato. Puoi mettere al sicuro il tuo piano con l\'email.';

  @override
  String get errorPurchaseNotAllowedTitle =>
      'Gli acquisti sono disattivati su questo dispositivo';

  @override
  String get errorPurchaseNotAllowedBody =>
      'Questo dispositivo o account al momento non può acquistare abbonamenti — di solito è il parental control o una restrizione dello store. Non ti è stato addebitato nulla.';

  @override
  String get errorStoreTitle => 'Lo store non ha risposto';

  @override
  String get errorStoreBody =>
      'Google Play o l\'App Store hanno avuto un momento no. Non ti è stato addebitato nulla — riprova tra un minuto.';

  @override
  String get errorReceiptOwnedTitle =>
      'Questo abbonamento è di un altro account';

  @override
  String get errorReceiptOwnedBody =>
      'L\'abbonamento di questo account dello store è collegato a un altro accesso Cirrus. Accedi con quello, oppure ripristina da quell\'account.';

  @override
  String get errorRejectedTitle => 'Questa versione è stata respinta';

  @override
  String get errorRejectedBody =>
      'La tua connessione va bene — siamo noi che non abbiamo riconosciuto l\'app. Non puoi farci niente, e niente di quello che hai segnato è andato perso.';

  @override
  String get errorRetry => 'Riprova';

  @override
  String get errorGotIt => 'Ok, capito';

  @override
  String get errorFeedTitle => 'Il feed ci ha ghostato';

  @override
  String get errorFeedBody =>
      'Non siamo riusciti a raggiungere la community. Controlla il segnale e riprova.';

  @override
  String get errorRouteTitle => 'Questa pagina non esiste';

  @override
  String get errorRouteBody =>
      'Qualunque cosa cercassi, qui non c\'è. Ti riportiamo sulla strada giusta.';

  @override
  String get errorRouteCta => 'Portami alla Home';

  @override
  String get errorBackstage =>
      'qualcosa si è inceppato dietro le quinte — puoi continuare tranquillamente';

  @override
  String get coachWeekCardLabel => 'LA TUA SETTIMANA';

  @override
  String coachWeekCardCaption(String day) {
    return 'in calo — il giorno duro è stato $day';
  }

  @override
  String coachWeekCardCaptionFlat(String day) {
    return 'il giorno duro è stato $day';
  }

  @override
  String coachGreeting(String name, int puffs, String method, String date) {
    return 'Ehi. Sono $name — ho smesso due anni fa e ricordo benissimo com\'era. Ho letto il tuo piano: $puffs al giorno, metodo “$method”, Freedom Day: $date. Da me zero prediche, mai. Che succede adesso?';
  }

  @override
  String get coachReplyCraving1 =>
      'Quell\'onda è brutale, lo so. 15 minuti e si spezza — non è un discorso motivazionale, è biologia. Acqua fredda sui polsi, e resta con me. Cosa l\'ha fatta partire?';

  @override
  String coachReplyCraving2(int count) {
    return 'Ok. Respira con me per un giro — inspira 4, trattieni 7, espira 8. Di solito le voglie si spengono in 15–20 minuti. Ne hai già battute $count. Questa non è diversa.';
  }

  @override
  String get coachReplyCraving3 =>
      'Ricevuto. Non discutere con la voglia, resisti più di lei. Fai il giro dell\'isolato o apri il gioco da 60 secondi. Sale e poi muore — 15 minuti al massimo.';

  @override
  String coachReplyRough1(int percent) {
    return 'Ci sta. Nelle giornate no la vecchia abitudine urla più forte. Patto: 10 minuti a piedi prima del prossimo. Se dopo lo vuoi ancora, segnalo onestamente — sei comunque il $percent% sotto la tua media di prima.';
  }

  @override
  String get coachReplyRough2 =>
      'Sembra pesante. Oggi non devi sistemare niente, solo arrivare in fondo — e puoi farlo anche senza nicotina. Io ci sono comunque.';

  @override
  String coachReplySlip1(int count) {
    return 'Uno scivolone è un dato, non una sconfitta. Cosa l\'ha fatto partire — stress, gente, noia? Il piano si è già piegato per prenderti al volo. I tuoi $count giorni contano ancora.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Qui zero vergogna. Quasi tutti quelli che smettono per davvero sono scivolati lungo la strada. Segnalo onestamente, trova il trigger, vai avanti. Il tuo record resta tuo: $amount risparmiati, serie più lunga intatta.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Guarda i numeri veri: giorno $day, $saved di nuovo in tasca, $cravings voglie battute. Il te del giorno 1 oggi non ce l\'avrebbe fatta. Questo è reale.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today tiri oggi con un limite di $limit. Ogni tiro che salti adesso è nel diario, ed è il diario che piega la curva. Lo stai facendo davvero.';
  }

  @override
  String get coachReplyGeneric1 => 'Ti sento. Dimmi di più — cosa c\'è sotto?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Ha senso. Per quel che vale, sei al giorno $day e sei ancora qui. Conta tanto.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Capito. Una domanda onesta: adesso è una cosa di nicotina, o è una cosa della vita con addosso la giacca della nicotina?';

  @override
  String get coachReplyGeneric4 =>
      'Ok. Qui si vince a piccoli passi. Qual è una cosa che puoi fare nei prossimi 10 minuti che non sia svapare?';

  @override
  String coachReplyParty(int count) {
    return 'Piano festa: tieni in mano una bibita fredda tutta la sera, scrivi a me o a un amico quando spunta la prima svapo, e preparati la frase per sganciarti. Hai superato $count voglie — una festa è solo qualcuna di fila.';
  }

  @override
  String coachSafetyNote(String name) {
    return '$name è uno strumento di supporto basato su IA, non un medico. I tuoi messaggi sono elaborati da Google Gemini. Sei in crisi? Chiama o manda un SMS al 988 (USA e Canada), a qualsiasi ora.';
  }

  @override
  String get planTitle => 'Il tuo piano';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days giorni';
  }

  @override
  String get planMethodTaper => 'A scalare';

  @override
  String get planMethodCold => 'Di colpo';

  @override
  String planTodayMarker(int limit) {
    return 'oggi · $limit/giorno';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'IN ARRIVO';

  @override
  String planHalfwayTitle(int day) {
    return 'Giorno $day — metà strada';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'limite a $limit/giorno';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Giorno $day — le voglie calano';
  }

  @override
  String get planCravingsFadeSub => 'per molti: mattine più facili';

  @override
  String planFreedomTitle(int day) {
    return 'Giorno $day — Freedom Day';
  }

  @override
  String get planAdjustCta => 'Modifica il mio piano';

  @override
  String get planAdjustNote =>
      'ritmo + metodo modificabili · storico sempre salvo';

  @override
  String get planAdaptiveLabel => 'IL RITOCCO DI STANOTTE';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'Hai chiuso sotto il limite per tre giorni di fila, quindi l\'obiettivo di oggi scende a $limit. È slancio, non una punizione.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'Stai tenendo il limite. L\'obiettivo di oggi resta a $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'Gli ultimi due giorni hanno sforato, quindi l\'obiettivo di oggi si piega a $limit. Un limite che riesci a tenere vale più di uno che non riesci.';
  }

  @override
  String get planAdaptiveStretched =>
      'Di conseguenza il Freedom Day slitta di un giorno.';

  @override
  String get planAdjustSheetTitle => 'Modifica il tuo piano';

  @override
  String get planAdjustSheetNote =>
      'La curva si rigenera da oggi con i tuoi numeri reali. Lo storico resta. Il Freedom Day si sposta in modo onesto.';

  @override
  String get planAdjustApply => 'Applica — ricalcola la mia curva';

  @override
  String planAdjusted(String date) {
    return 'Piano ricalcolato. Nuovo Freedom Day: $date';
  }

  @override
  String get statsTitle => 'Statistiche';

  @override
  String get statsRangeDay => 'Giorno';

  @override
  String get statsRangeWeek => 'Settimana';

  @override
  String get statsRangeMonth => 'Mese';

  @override
  String get statsPuffsThisWeek => 'TIRI QUESTA SETTIMANA';

  @override
  String get statsPuffsToday => 'TIRI OGGI · PER ORA';

  @override
  String get statsDayNoPuffs => 'Oggi nessun tiro segnato';

  @override
  String get statsPuffsThisMonth => 'TIRI · ULTIMI 30 GIORNI';

  @override
  String statsVsLast(String percent) {
    return '$percent vs prima';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return 'Il giorno più duro è stato $day — $reason. Il mattino dopo hai ripreso il ritmo.';
  }

  @override
  String statsHardDayNoRecovery(String day) {
    return 'Il giorno più duro è stato $day.';
  }

  @override
  String statsHardDayNoRecoveryReason(String day, String reason) {
    return 'Il giorno più duro è stato $day — $reason.';
  }

  @override
  String get statsHardDayToday => 'Finora oggi è il giorno con più tiri.';

  @override
  String statsHardDayTodayReason(String reason) {
    return 'Finora oggi è il giorno con più tiri — $reason.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return 'Il giorno più duro è stato $day. Il mattino dopo hai ripreso il ritmo.';
  }

  @override
  String get statsWindowNoPuffs => 'nessun tiro segnato in questo periodo';

  @override
  String get statsTriggerHours => 'ORARI A RISCHIO';

  @override
  String statsDangerWindow(String range) {
    return '$range è la tua zona rossa · promemoria attivi';
  }

  @override
  String get statsNicotinePerDay => 'NICOTINA / GIORNO';

  @override
  String statsNicotineValue(int mg) {
    return '$mg mg';
  }

  @override
  String get statsNicotineDown => 'Più bassa dell\'ultimo giorno completo';

  @override
  String get statsNicotineUp => 'Più alta dell\'ultimo giorno completo';

  @override
  String get statsLongestGap => 'pausa più lunga';

  @override
  String get statsBestDay => 'giorno migliore (tiri)';

  @override
  String get statsCravingsBeaten => 'voglie battute';

  @override
  String statsEditDayTitle(String date) {
    return 'Modifica $date';
  }

  @override
  String get statsEditDayNote =>
      'Lo storico è tuo. Serie e risparmi si ricalcolano da qui in avanti.';

  @override
  String get statsEditHint =>
      'tieni premuta una barra per correggere un giorno';

  @override
  String get communityTitle => 'Community';

  @override
  String communityYouAre(String alias) {
    return 'sei $alias';
  }

  @override
  String get communityFilterAll => 'Tutti';

  @override
  String get communityTagWin => '🏆 Vittoria';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Giorno 1';

  @override
  String get communityTagMilestone => 'Traguardo';

  @override
  String get communityTagVent => 'Sfogo';

  @override
  String get communityIGotYou => 'Ci sono io 💬';

  @override
  String communityRepliedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hanno già risposto',
      one: '$count ha già risposto',
    );
    return '$_temp0';
  }

  @override
  String get communityReport => 'Segnala';

  @override
  String get communityPostMenu => 'Opzioni del post';

  @override
  String get communityMute => 'Silenzia';

  @override
  String get communityBlock => 'Blocca utente';

  @override
  String get communityReported =>
      'Segnalato. Controlliamo entro 24h — con 3 segnalazioni un post si nasconde da solo.';

  @override
  String get communityBlocked => 'Blocco attivo. Non vi vedrete più.';

  @override
  String get communityMuted => 'Fatto. Non vedrai più i suoi post.';

  @override
  String get communityComposerTitle => 'Nuovo post';

  @override
  String get communityComposerPost => 'Pubblica';

  @override
  String communityPostingAs(String alias, int day) {
    return 'pubblichi come $alias · giorno $day · sempre in anonimo';
  }

  @override
  String get communityComposerHint => 'Come va con lo smettere? Racconta.';

  @override
  String get communityTagIt => 'METTI UN TAG';

  @override
  String get communityKindnessNote =>
      'Sii gentile — qui stanno tutti lottando. Niente marche, niente “dove si compra”.';

  @override
  String get communityRuleSlur =>
      'Questo non si può pubblicare — insulti e odio qui non sono ammessi.';

  @override
  String get communityRuleSourcing =>
      'Qui non si parla di dove comprare o di cosa è in vendita. Modifica il testo e riprova.';

  @override
  String get communityTooShort =>
      'Ancora qualche parola — quanto basta perché qualcuno possa aiutarti davvero.';

  @override
  String get communityTooRepetitive =>
      'Dillo con parole tue — è così che arrivano le risposte.';

  @override
  String get communitySosStillUp =>
      'Il tuo SOS è ancora in cima al feed. La gente lo sta vedendo.';

  @override
  String communityDailyCapReached(int limit) {
    return 'Siamo a $limit per oggi — il contatore si azzera a mezzanotte.';
  }

  @override
  String get communityTagRequired =>
      'Scegli un tag — porta il tuo post alle persone giuste.';

  @override
  String communitySosBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🛡️ $count persone ti hanno coperto le spalle',
      one: '🛡️ $count persona ti ha coperto le spalle',
    );
    return '$_temp0';
  }

  @override
  String get communityAddVoice => 'Di\' la tua…';

  @override
  String communityMentionTag(String alias) {
    return 'Menziona $alias';
  }

  @override
  String communityDayTag(int day) {
    return 'giorno $day';
  }

  @override
  String get communityEmptyTitle => 'Ancora nessun post — saluta tu.';

  @override
  String get communityEmptyBody =>
      'Il tuo post del Giorno 1 è quello che qualcuno al Giorno 0 ha bisogno di leggere.';

  @override
  String get communityPosted =>
      'Pubblicato. Prima che gli altri lo vedano parte un rapido controllo di sicurezza.';

  @override
  String get communityStatusHeld => 'In revisione — per ora lo vedi solo tu';

  @override
  String get communityStatusBlocked =>
      'Non pubblicato — non rispetta le regole della community';

  @override
  String get communityStatusPosting => 'Pubblicazione…';

  @override
  String get communityStatusFailed => 'Non inviato — tocca per riprovare';

  @override
  String get communityStatusCapped =>
      'Non pubblicato — sono già 3 oggi. Il limite si azzera a mezzanotte.';

  @override
  String get linkCopied =>
      'Link copiato — smettere è un\'altra cosa con qualcuno accanto.';

  @override
  String get moneyTitle => 'Soldi che tornano';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'risparmiati · inizio $date · $perDay in più al giorno';
  }

  @override
  String get moneyBuysLabel => 'COSA CI COMPRI GIÀ';

  @override
  String moneyToGo(String amount, int days) {
    return 'mancano $amount · ~$days giorni al tuo ritmo';
  }

  @override
  String moneyToGoShort(String amount) {
    return 'mancano $amount';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'quello del check-up · mancano $amount';
  }

  @override
  String get moneySetGoal => 'Imposta un obiettivo';

  @override
  String get moneySetGoalSub =>
      'dagli un nome, un prezzo, e guarda la barra riempirsi';

  @override
  String get moneyGoalSheetTitle => 'Nuovo obiettivo di risparmio';

  @override
  String get moneyGoalNameHint =>
      'Dagli un nome — “PS5”, “Lisbona”, “batteria”';

  @override
  String get moneyGoalPriceHint => 'Prezzo';

  @override
  String get moneyGoalCreate => 'Fai partire la barra';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'I conti sono tuoi: $weekly/settimana × 52 = $yearly/anno. Nessun numero inventato.';
  }

  @override
  String get moneyGoalDone => 'Obiettivo raggiunto. Coriandoli meritati. 🎉';

  @override
  String get seedGoalKicks => 'Sneakers nuove';

  @override
  String get seedGoalTokyo => 'Volo per Tokyo';

  @override
  String get healthTitle => 'Il tuo corpo che guarisce';

  @override
  String healthAnchor(String ago) {
    return 'In base al tuo ultimo tiro segnato · $ago fa';
  }

  @override
  String get healthAnchorNone => 'Ancora nessun tiro segnato';

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — sei qui';
  }

  @override
  String get healthM20min => '20 minuti';

  @override
  String get healthM20minBody => 'Battito e pressione tornano alla normalità.';

  @override
  String get healthM8h => '8 ore';

  @override
  String get healthM8hBody =>
      'L\'ossigeno torna a livelli normali mentre la nicotina cala.';

  @override
  String get healthM12h => '12 ore';

  @override
  String get healthM12hBody =>
      'Il monossido di carbonio nel sangue scende a livelli normali.';

  @override
  String get healthM24h => '24 ore';

  @override
  String get healthM24hBody =>
      'La nicotina scende in fretta. Le voglie si fanno sentire forte — quella è la porta d\'uscita.';

  @override
  String get healthM48h => '48 ore';

  @override
  String get healthM48hBody =>
      'Le terminazioni nervose iniziano a ricrescere. Gusto e olfatto si affinano.';

  @override
  String get healthM72h => '72 ore';

  @override
  String get healthM72hBody =>
      'La nicotina è ~sparita. Picco delle voglie — il tasto panico esiste per questo.';

  @override
  String get healthM1w => '1 settimana';

  @override
  String get healthM1wBody =>
      'Gusto e olfatto molto più netti. Respirare viene più facile.';

  @override
  String get healthM2w => '2 settimane';

  @override
  String get healthM2wBody =>
      'La circolazione migliora. La funzione polmonare inizia a salire.';

  @override
  String get healthM1m => '1 mese';

  @override
  String get healthM1mBody => 'Tosse e fiato corto si attenuano.';

  @override
  String get healthM3m => '3 mesi';

  @override
  String get healthM3mBody =>
      'La capacità polmonare continua a salire. In palestra è un\'altra storia.';

  @override
  String get healthM6m => '6 mesi';

  @override
  String get healthM6mBody =>
      'Il tuo livello base di stress scende — le giornate no le reggi anche senza.';

  @override
  String get healthM1y => '1 anno';

  @override
  String get healthM1yBody =>
      'Il tuo profilo di rischio somiglia a quello di chi non ha mai svapato ogni giorno.';

  @override
  String get healthUnlockNote =>
      'Ogni traguardo sbloccato fa partire una piccola festa + una card da condividere, se vuoi.';

  @override
  String get healthSourceNote =>
      'Basato sulla ricerca su chi smette di fumare — sullo svapo le prove stanno ancora arrivando.';

  @override
  String get milestonesTitle => 'Traguardi';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned su $total raggiunti';
  }

  @override
  String milestonesNext(String name) {
    return 'Prossimo: $name';
  }

  @override
  String milestonesNextProgress(int day, int target, num remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: 'ancora $remaining albe',
      one: 'ancora un\'alba',
    );
    return 'giorno $day di $target · $_temp0';
  }

  @override
  String get milestonesNotLeaderboard =>
      'I badge sono tuoi, non una classifica. Nessuna griglia altrui con cui confrontarti.';

  @override
  String get mFirstLog => 'Primo tiro segnato';

  @override
  String get mFirstCraving => 'Prima voglia battuta';

  @override
  String get mSpark => 'Scintilla 3 giorni';

  @override
  String get mWeekFlame => 'Fiamma 7 giorni';

  @override
  String get mHundredSaved => '100 \$ risparmiati';

  @override
  String get mCleanWeekend => 'Weekend pulito';

  @override
  String get mHelpedSos => 'Hai aiutato un SOS';

  @override
  String get mTwoWeekFlame => 'Fiamma 2 settimane';

  @override
  String get mHalfNicotine => 'Nicotina dimezzata';

  @override
  String get mMoodWeek => 'Una settimana di check-in';

  @override
  String get mTenCravings => '10 voglie battute';

  @override
  String get mQuarterCurve => 'Un quarto della curva';

  @override
  String get mInferno => 'Falò 30 giorni';

  @override
  String get mFreedomDay => 'Freedom Day';

  @override
  String get mFirstPost => 'Primo post';

  @override
  String get mFiveHundredSaved => '500 \$ risparmiati';

  @override
  String get mComeback => 'Rimonta';

  @override
  String get moodTitle => 'Come va oggi?';

  @override
  String get moodSubtitle => '10 secondi. Conta più di quanto pensi.';

  @override
  String get moodRough => 'tosta';

  @override
  String get moodMeh => 'così così';

  @override
  String get moodOkay => 'ok';

  @override
  String get moodGood => 'bene';

  @override
  String get moodGreat => 'top';

  @override
  String get moodNoteHint =>
      'Una riga, se ti va — “stasera festa di lavoro, un po\' d\'ansia”';

  @override
  String get moodUnlockTitle => '🔓 Legame umore ↔ voglie';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total check-in';
  }

  @override
  String moodUnlockNote(int count) {
    return 'Ancora $count e il tuo report ti mostra come l\'umore guida le tue voglie.';
  }

  @override
  String get moodCta => 'Fai il check-in';

  @override
  String get moodSaved => 'Segnato. I dati battono le sensazioni. 🙌';

  @override
  String get insightLinkTitle => 'Report settimanale';

  @override
  String insightTitle(int week, String range) {
    return 'Report settimana $week · $range';
  }

  @override
  String get insightWinLabel => 'La tua vittoria';

  @override
  String get insightWatchoutLabel => 'Occhio';

  @override
  String get insightWeekChartLabel => 'TIRI, ULTIMI 7 GIORNI';

  @override
  String get insightCravingsChartLabel => 'VOGLIE SUPERATE, ULTIMI 7 GIORNI';

  @override
  String get insightHoursChartLabel => 'TIRI PER ORA, ULTIMI 14 GIORNI';

  @override
  String get insightPendingTitle => 'Ancora nessun report';

  @override
  String insightPendingBody(String name) {
    return '$name ne scrive uno ogni domenica partendo dalla settimana che hai segnato davvero — i tuoi orari, i tuoi umori, le tue vittorie. Finché non c\'è una settimana da leggere, non c\'è niente da mostrare.';
  }

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index DI $total';
  }

  @override
  String get slipTitle => 'Uno scivolone è un dato, non una sconfitta.';

  @override
  String slipSubtitle(int days) {
    return 'Hai segnato dei tiri dopo $days giorni puliti. È un\'informazione — ci dice esattamente dove il piano ha bisogno di una corazza.';
  }

  @override
  String get slipWhatHappened => 'COSA STAVA SUCCEDENDO?';

  @override
  String get slipTriggerParty => 'Festa';

  @override
  String get slipTriggerStress => 'Stress';

  @override
  String get slipTriggerBoredom => 'Noia';

  @override
  String get slipTriggerDrinking => 'Alcol';

  @override
  String get slipTriggerFriends => 'Gli amici ne avevano una';

  @override
  String get slipTriggerJustHappened => 'È successo e basta';

  @override
  String get slipNoBannedWords =>
      'Qui nessuna parola è vietata, mai. Quasi tutti quelli che smettono per davvero sono scivolati lungo la strada. Il diario resta onesto, il piano si adatta.';

  @override
  String get slipAdjustCta => 'Modifica il mio piano';

  @override
  String get slipAdjustTitle => 'Ecco il ritocco.';

  @override
  String get slipCurveLabel => 'LA TUA CURVA — RICALCOLATA CON DOLCEZZA';

  @override
  String get slipTheBump => 'il dosso dello scivolone';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Freedom Day: $date (+$days giorni)';
  }

  @override
  String get slipCurveNote => 'Due giorni in più, stessa meta.';

  @override
  String slipStreakSurvives(int days) {
    return 'I tuoi $days giorni contano ancora.';
  }

  @override
  String get slipFlameDims =>
      'La fiamma si abbassa, non muore. Basta un giorno pulito per riportarla al massimo.';

  @override
  String get slipBackOnCurve => 'Si torna sulla curva';

  @override
  String get slipTalkFirst => 'Prima ne parlo col coach';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'inizio $date · $method · giorno $day';
  }

  @override
  String get profileCountdownLabel => '🏆 CONTO ALLA ROVESCIA · FREEDOM DAY';

  @override
  String profileDaysTo(String date) {
    return 'giorni che mancano · $date';
  }

  @override
  String get profileLifetimeSaved => 'risparmio totale';

  @override
  String get profilePuffsNotTaken => 'tiri non fatti';

  @override
  String get profileBadgesEarned => 'badge ottenuti';

  @override
  String get profileSettings => 'Impostazioni';

  @override
  String get profileEditAlias => 'Scegli il tuo alias';

  @override
  String get profileEditAvatar => 'Scegli il tuo avatar';

  @override
  String get profileAliasHint =>
      'anonimo — è tutto quello che vedono gli altri';

  @override
  String memoriesTitle(String name) {
    return 'Cosa ricorda $name';
  }

  @override
  String memoriesIntro(String name) {
    return 'Cosa sa di te $name: il tuo setup e i numeri in tempo reale dell\'app, più le cose che hai raccontato in chat — quelle puoi fargliele dimenticare quando vuoi.';
  }

  @override
  String memoriesEmpty(String name) {
    return 'Qui non c\'è ancora niente. Questa parte si riempie man mano che $name scopre cose della tua vita in chat.';
  }

  @override
  String memoriesSectionKnows(String name) {
    return 'Cosa sa sempre $name';
  }

  @override
  String memoriesSectionTold(String name) {
    return 'Cose che $name sa da te';
  }

  @override
  String get memoriesFactPlan => 'Piano';

  @override
  String memoriesFactPlanValue(String method, int days) {
    return '$method · $days giorni';
  }

  @override
  String get memoriesFactStarted => 'Inizio';

  @override
  String get memoriesFactBaseline => 'Punto di partenza';

  @override
  String memoriesFactBaselineValue(int count) {
    return '$count tiri al giorno';
  }

  @override
  String get memoriesFactWhy => 'Il tuo perché';

  @override
  String get memoriesFactWorries => 'Cosa ti preoccupa';

  @override
  String get memoriesFactWhyWords => 'Con parole tue';

  @override
  String get memoriesFactFirstPuff => 'Primo tiro dopo la sveglia';

  @override
  String get memoriesFactFrequency => 'Quanto spesso';

  @override
  String get memoriesFactDay => 'A che punto sei';

  @override
  String memoriesFactDayValue(int day, int total) {
    return 'Giorno $day di $total';
  }

  @override
  String memoriesFactDayMaintenance(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Piano completato · $count giorni dopo il Freedom Day',
      one: 'Piano completato · 1 giorno dopo il Freedom Day',
    );
    return '$_temp0';
  }

  @override
  String get memoriesFactToday => 'Oggi';

  @override
  String memoriesFactTodayValue(int puffs, int limit) {
    return '$puffs tiri su $limit';
  }

  @override
  String get memoriesFactStreak => 'Serie';

  @override
  String get memoriesFactSaved => 'Soldi risparmiati';

  @override
  String get memoriesFailed => 'Al momento non si riesce a caricarli.';

  @override
  String get memoriesForget => 'Dimenticalo';

  @override
  String memoriesForgotten(String name) {
    return 'Dimenticato. $name non tirerà più fuori l\'argomento.';
  }

  @override
  String get memoriesForgetFailed =>
      'Non è andato a buon fine — è ancora in memoria.';

  @override
  String get memoriesKindPerson => 'Una persona della tua vita';

  @override
  String get memoriesKindTrigger => 'Un trigger';

  @override
  String get memoriesKindMotivation => 'Perché lo stai facendo';

  @override
  String get memoriesKindMilestone => 'Qualcosa a cui stai puntando';

  @override
  String get memoriesKindPreference => 'Come vuoi che ti si parli';

  @override
  String get memoriesKindContext => 'Su di te';

  @override
  String settingsMemories(String name) {
    return 'Cosa ricorda $name';
  }

  @override
  String get moderationTitle => 'Coda di revisione';

  @override
  String get moderationEmpty =>
      'Niente in attesa. Tutte le segnalazioni sono state controllate.';

  @override
  String get moderationFailed => 'Non si riesce ad aprire la coda.';

  @override
  String get moderationRetry => 'Riprova';

  @override
  String get moderationShowReviewed => 'Mostra già controllati';

  @override
  String moderationPendingCount(int count) {
    return '$count in attesa';
  }

  @override
  String get moderationSubjectGone =>
      'Il post non c\'è più; resta solo la segnalazione.';

  @override
  String get moderationAllow => 'Approva';

  @override
  String get moderationBlock => 'Blocca';

  @override
  String get moderationDismiss => 'Va bene così';

  @override
  String get moderationResolveFailed =>
      'Non è andato a buon fine. Il post è rimasto com\'era.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsAccount => 'Account';

  @override
  String get settingsSubscription => 'Gestisci abbonamento';

  @override
  String get settingsSubscriptionFree => 'Piano Free';

  @override
  String get settingsSubscriptionYearly => 'Premium · annuale';

  @override
  String get settingsSubscriptionMonthly => 'Premium · mensile';

  @override
  String get settingsSubscriptionWeekly => 'Premium · settimanale';

  @override
  String get settingsSubscriptionPremium => 'Premium';

  @override
  String settingsSubscriptionTrial(String date) {
    return 'Prova · scadenza $date';
  }

  @override
  String settingsSubscriptionEnds(String date) {
    return 'Premium · scadenza $date';
  }

  @override
  String get settingsManageUnavailable =>
      'Gestisci questo abbonamento dall\'account dello store con cui è stato acquistato.';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsDangerHours => 'Orari a rischio';

  @override
  String get settingsCheckin => 'Il punto della sera';

  @override
  String get settingsCheckinOff => 'disattivato · modifica ›';

  @override
  String get settingsCheckinBody =>
      'Una notifica ogni sera con il limite di oggi, per segnare com\'è andata. Se per una settimana non apri Cirrus, si ferma da sola.';

  @override
  String get settingsCheckinToggle => 'Ricordamelo ogni sera';

  @override
  String get settingsCheckinTime => 'Ora';

  @override
  String settingsDangerHoursEdit(String range) {
    return 'ore $range · modifica ›';
  }

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacyNote =>
      'Non vendiamo i tuoi dati. Niente tracker pubblicitari. Mai.';

  @override
  String get settingsWebsite => 'Sito web';

  @override
  String get settingsPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get settingsTermsOfUse => 'Termini di utilizzo';

  @override
  String get settingsEula => 'Contratto di licenza (EULA)';

  @override
  String get settingsSupport => 'Contatta l\'assistenza';

  @override
  String get settingsDeleteEverything => 'Elimina tutto';

  @override
  String get settingsDeleteConfirmTitle => 'Eliminare tutto?';

  @override
  String get settingsDeleteConfirmBody =>
      'Il tuo piano, il diario, la serie e i post nella community — spariti per sempre. Questo è l\'unico tasto che non possiamo annullare.';

  @override
  String get settingsDeleteConfirmCta => 'Sì, elimina tutto';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsAppearanceSystem => 'Come il sistema';

  @override
  String get settingsAppearanceDark => 'Scuro';

  @override
  String get settingsAppearanceLight => 'Chiaro';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeEmber => 'Ember';

  @override
  String get settingsThemeEmberSub => 'Nero profondo e lime. L\'originale.';

  @override
  String get settingsThemeHearth => 'Hearth';

  @override
  String get settingsThemeHearthSub => 'Carbone caldo e ambra.';

  @override
  String get settingsThemeTide => 'Tide';

  @override
  String get settingsThemeTideSub => 'Indaco profondo e verde acqua.';

  @override
  String get settingsThemeLocked => 'Hearth e Tide arrivano con Premium.';

  @override
  String get settingsLanguage => 'Lingua';

  @override
  String get settingsLanguageSystem => 'Come il sistema';

  @override
  String get settingsSignOut => 'Esci';

  @override
  String get settingsSignOutConfirmTitle => 'Uscire?';

  @override
  String get settingsSignOutConfirmBody =>
      'I tuoi dati restano sul tuo account. La serie continua a bruciare.';

  @override
  String get settingsDangerHoursTitle =>
      'Quando ti prendono più forte le voglie?';

  @override
  String get settingsDangerHoursNote =>
      'Scegli l\'ora in cui di solito comincia. Ti avvisiamo 10 minuti prima — una notifica al giorno, non di più.';

  @override
  String settingsDangerHoursNudge(String time) {
    return 'Un promemoria verso le $time, ogni giorno.';
  }

  @override
  String get settingsDangerHoursNotifOff =>
      'Le notifiche sono disattivate, quindi non parte niente finché non le attivi.';

  @override
  String settingsQuietHours(String range) {
    return 'Mai nella fascia $range — ore di silenzio.';
  }

  @override
  String get settingsQuietHoursLabel => 'Ore di silenzio';

  @override
  String get settingsQuietHoursHint =>
      'Trascina le estremità. Niente di quello che inviamo arriva lì dentro.';

  @override
  String settingsQuietHoursLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ore',
      one: '1 ora',
    );
    return '$_temp0';
  }

  @override
  String get settingsQuietHoursStartHandle => 'Inizio delle ore di silenzio';

  @override
  String get settingsQuietHoursEndHandle => 'Fine delle ore di silenzio';

  @override
  String get trialEndingPushTime => 'ora';

  @override
  String get trialEndingPush =>
      'la tua prova finisce domani — come promesso, ecco l\'avviso. Nessun addebito a sorpresa.';

  @override
  String get trialEndingTitle => 'La prova finisce domani.';

  @override
  String get trialEndingBody =>
      'Avevamo detto che ti avremmo avvisato, quindi: eccoci. Tieni Premium o passa a Free — serie, piano e storico restano in ogni caso.';

  @override
  String get trialEndingStatsLabel => 'LA TUA SETTIMANA FINORA';

  @override
  String get trialEndingVsDay1 => 'tiri vs giorno 1';

  @override
  String get trialEndingCravings => 'voglie battute';

  @override
  String get trialEndingSaved => 'risparmiati';

  @override
  String get trialEndingKeep => 'Tengo Premium';

  @override
  String get trialEndingSwitchFree => 'Passo a Free (i dati restano)';

  @override
  String trialEndsOn(String date) {
    return 'Fine della prova: $date.';
  }

  @override
  String get trialEndingNotifTitle => 'La tua prova finisce domani';

  @override
  String get seedPostWin30 =>
      'FREEDOM DAY. 30 giorni, zero tiri nell\'ultima settimana. Il tasto panico mi ha salvato nei weekend. Se sei al giorno 2 e stai morendo — giuro che verso il giorno 8 diventa più facile.';

  @override
  String get seedPostSos =>
      'davanti al tabacchi. soldi in mano. qualcuno mi fermi';

  @override
  String get seedPostDay1 =>
      'ho buttato la mia svapo nel lago. povero lago. il giorno 1 inizia ora';

  @override
  String get seedPostVent =>
      'il mio collega fa nuvole al mango alla scrivania TUTTO IL GIORNO e io dovrei… concentrarmi? mi sfogo qui per non cedere';

  @override
  String get seedPostMilestone =>
      'due settimane. oggi ho fatto le scale fino al quarto piano senza sembrare una fisarmonica posseduta. piccole vittorie';

  @override
  String get seedPostWinParty =>
      'ho superato una festa intera senza chiedere un tiro a nessuno. le mani sono sopravvissute stringendo un\'acqua tonica tutta la sera, come una persona strana';

  @override
  String get seedReplyWalk =>
      'cammina. solo il giro dell\'isolato. il portafoglio resta pieno e tu ne resti fuori. martedì ho fatto esattamente la stessa cosa';

  @override
  String get seedReplyScience =>
      'il giorno 4 è il peggiore, è scienza. sei al picco PROPRIO ADESSO. 15 minuti e muore';

  @override
  String get seedReplyGatorade =>
      'comprati un gatorade, invece. acquisto cerimoniale. funziona stranamente bene';

  @override
  String get seedReplyUpdate =>
      'aggiornamento: gatorade comprato. torno a casa a piedi. grazie, davvero 💙';

  @override
  String get dangerReminderTitle => 'Sta arrivando la tua ora a rischio';

  @override
  String get dangerReminderBody =>
      'Di solito ti prende a quest\'ora. Hai un piano — e 15 minuti bastano per batterla.';

  @override
  String checkinNotifTitle(int day) {
    return 'Giorno $day: il punto della sera';
  }

  @override
  String get checkinNotifTitlePast => 'Il punto della sera';

  @override
  String checkinNotifBody(int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      limit,
      locale: localeName,
      other: 'Il limite di oggi è $limit tiri. Tocca per segnare come va.',
      one: 'Il limite di oggi è 1 tiro. Tocca per segnare come va.',
    );
    return '$_temp0';
  }

  @override
  String get checkinNotifBodyZero =>
      'Oggi si punta a zero. Tocca per confermare il giorno senza svapo.';

  @override
  String get communityLoading => 'Sto caricando il feed…';

  @override
  String memoriesLoading(String name) {
    return 'Vediamo cosa ha tenuto $name…';
  }

  @override
  String get coachLoadingThread => 'Riprendiamo la chat…';

  @override
  String get moderationLoading => 'Caricamento della coda…';

  @override
  String get slipCurveNoteParty =>
      'Due giorni in più, stessa meta. Prima della prossima festa imposta un orario a rischio, così il promemoria arriva prima.';

  @override
  String get slipCurveNoteStress =>
      'Due giorni in più, stessa meta. Quando arriva lo stress, i 60 secondi di respiro del tasto panico sono fatti apposta per quel minuto.';

  @override
  String get slipCurveNoteBoredom =>
      'Due giorni in più, stessa meta. Per i minuti vuoti, il gioco dentro la modalità panico è a un tap.';

  @override
  String get slipCurveNoteDrinking =>
      'Due giorni in più, stessa meta. Imposta un orario a rischio prima della prossima bevuta — il promemoria arriva prima del primo bicchiere.';

  @override
  String get slipCurveNoteFriends =>
      'Due giorni in più, stessa meta. La prossima volta scrivi al coach prima di vederli, non dopo.';

  @override
  String get slipCurveNoteJustHappened =>
      'Due giorni in più, stessa meta. Capita. Il diario resta onesto, e domani è un giorno pulito.';

  @override
  String get widgetDay => 'giorno %1\$d';

  @override
  String get widgetDayFreedom => 'Freedom Day 🏆';

  @override
  String get widgetDayPastOne => '%1\$d giorno dopo il Freedom Day';

  @override
  String get widgetDayPastOther => '%1\$d giorni dopo il Freedom Day';

  @override
  String get widgetLeftAhead => 'ancora %1\$d · sei avanti sulla curva';

  @override
  String get widgetLeftTight => 'ancora %1\$d · stretto, ma ce la fai';

  @override
  String get widgetOverLimit => 'oltre il limite di oggi · nessuna vergogna';

  @override
  String get widgetEmptyTitle => 'Inizia il tuo piano';

  @override
  String get widgetEmptyBody => 'Tocca per aprire Cirrus';

  @override
  String get widgetWatchOpenPhone => 'Apri Cirrus sul tuo iPhone';

  @override
  String get milestoneNotifTitle => 'Vieni a vedere la tua fiamma';

  @override
  String get milestoneNotifSpark =>
      'Tre giorni puliti. La parte più dura è alle spalle — la tua fiamma è accesa.';

  @override
  String get milestoneNotifWeekFlame =>
      'Una settimana intera. Sette giorni che non credevi di avere.';

  @override
  String get milestoneNotifTwoWeekFlame =>
      'Due settimane. DUE SETTIMANE. La tua fiamma è ufficialmente un incendio.';

  @override
  String get milestoneNotifInferno =>
      'Trenta giorni. Questi non te li ha regalati nessuno.';

  @override
  String get milestoneNotifFreedomDay =>
      'Freedom Day. Il piano è finito, e l\'hai portato in fondo tu.';

  @override
  String get communityThreadGoneTitle => 'Quel thread non c\'è più';

  @override
  String get communityThreadGoneBody =>
      'Forse è stato eliminato o rimosso dopo che ti è arrivata la notifica.';

  @override
  String get communityThreadGoneCta => 'Torna al feed';

  @override
  String get pushOpen => 'Apri';

  @override
  String get pushRefresh => 'Aggiorna';

  @override
  String get settingsPushTitle => 'Cosa ti mandiamo';

  @override
  String get settingsPushSubtitle =>
      'Solo per i tuoi thread. Mai per quelli degli altri.';

  @override
  String get settingsPushBlocked =>
      'Le notifiche di Cirrus sono disattivate nelle impostazioni del telefono. Riattivale lì e queste inizieranno a funzionare.';

  @override
  String get settingsPushReplies => 'Risposte ai miei post';

  @override
  String get settingsPushRepliesNote =>
      'Raggruppate: un thread molto attivo è una sola notifica.';

  @override
  String get settingsPushMentions => 'Menzioni';

  @override
  String get settingsPushMentionsNote =>
      'Quando qualcuno ti menziona in una risposta.';

  @override
  String get settingsPushWeekly => 'Report settimanale';

  @override
  String get settingsPushWeeklyNote =>
      'Quando la tua settimana è pronta da rileggere.';

  @override
  String get settingsPushCategories => 'Categorie';

  @override
  String get pushAskTitle => 'Vuoi sapere quando qualcuno risponde?';

  @override
  String get pushAskBody =>
      'Ti avvisiamo solo per i tuoi post. Mai per quelli degli altri.';

  @override
  String get pushAskCta => 'Attiva le notifiche';

  @override
  String get pushAskDayOneTitle => 'Ti avviso stasera?';

  @override
  String get pushAskDayOneBody =>
      'Il punto della sera con il tuo limite, un avviso prima dei tuoi orari a rischio e due parole quando raggiungi un traguardo.';

  @override
  String get pushAskSurvivedTitle => 'Rinforzi per la prossima volta?';

  @override
  String get pushAskSurvivedBody =>
      'Un avviso poco prima dei tuoi orari a rischio, così la prossima voglia non ti coglie di sorpresa.';

  @override
  String get notificationsTitle => 'Notifiche';

  @override
  String get notificationsEmptyTitle => 'Ancora niente';

  @override
  String get notificationsEmptyBody =>
      'Quando qualcuno risponde a un tuo post, lo trovi qui.';

  @override
  String notificationsBadgeLabel(int count) {
    return 'Notifiche non lette: $count';
  }
}
