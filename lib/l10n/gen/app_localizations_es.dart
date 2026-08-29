// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline => 'Tu última calada está más cerca\nde lo que crees.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · hecho por gente que lo dejó';
  }

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDone => 'Listo';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonBack => 'Atrás';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonUndo => 'Deshacer';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonNotNow => 'Ahora no';

  @override
  String get commonMaybeLater => 'Quizá luego';

  @override
  String get commonComingSoon => 'Muy pronto';

  @override
  String get commonToday => 'Hoy';

  @override
  String get commonDay => 'Día';

  @override
  String get commonYou => 'tú';

  @override
  String get commonPremium => 'Premium';

  @override
  String get commonFree => 'Gratis';

  @override
  String get commonUpgrade => 'Mejorar';

  @override
  String get commonSeeAll => 'Ver todo';

  @override
  String get commonOfflineBanner =>
      'Sin conexión — tus registros se guardan en el teléfono y se sincronizan al volver.';

  @override
  String get commonErrorTitle => 'Algo falló un segundo.';

  @override
  String get commonErrorBody => 'Tus datos están bien. Toca para reintentar.';

  @override
  String commonDayOfDay(int day, int total) {
    return 'Día $day de $total';
  }

  @override
  String commonDayN(int day) {
    return 'día $day';
  }

  @override
  String commonStreakDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count días',
      one: '$count día',
    );
    return '$_temp0';
  }

  @override
  String commonPuffsUnit(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count caladas',
      one: '$count calada',
    );
    return '$_temp0';
  }

  @override
  String get authSplashAutoAdvance => 'Cargando tu plan…';

  @override
  String get authSignInTitle => 'Vamos a proteger\ntu plan.';

  @override
  String get authSignInSubtitle =>
      'Anónimo por defecto — elegirás un alias para la comunidad.';

  @override
  String get authSignInWithApple => 'Iniciar sesión con Apple';

  @override
  String get authSignInWithGoogle => 'Iniciar sesión con Google';

  @override
  String get authContinueWithEmail => 'Continuar con email';

  @override
  String get authWhyAccountDivider => '¿por qué una cuenta?';

  @override
  String get authWhyAccountCard =>
      'Tu racha, tu plan y la memoria de tu coach se sincronizan entre dispositivos. 🔒 Nunca vendemos tus datos. Sin rastreadores de anuncios. Jamás.';

  @override
  String get authTerms => 'Términos';

  @override
  String get authPrivacy => 'Privacidad';

  @override
  String get authRestorePurchase => 'Restaurar compra';

  @override
  String get authRegisterTitle => 'Crea tu cuenta';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'CONTRASEÑA';

  @override
  String get authShowPassword => 'ver';

  @override
  String get authHidePassword => 'ocultar';

  @override
  String get authPasswordStrengthWeak => 'sigue escribiendo…';

  @override
  String get authPasswordStrengthDecent => 'contraseña decente';

  @override
  String get authPasswordStrengthStrong => 'contraseña fuerte';

  @override
  String get authNoSpamCard =>
      'Sin spam, sin emails de \"te echamos de menos\". La cuenta es tu copia de seguridad, nada más.';

  @override
  String get authCreateAccount => 'Crear cuenta';

  @override
  String get authAlreadyHaveOne => '¿Ya tienes una?';

  @override
  String get authLogIn => 'Entrar';

  @override
  String get authLoginTitle => 'Hola de nuevo.';

  @override
  String get authLoginSubtitle => 'Tu racha te echaba de menos.';

  @override
  String get authForgotPassword => '¿Olvidaste la contraseña?';

  @override
  String get authNewHere => '¿Nuevo por aquí?';

  @override
  String get authWrongPassword => 'esa no es — prueba otra vez';

  @override
  String get authForgotTitle => 'Le pasa a cualquiera.';

  @override
  String get authForgotSubtitle =>
      'Deja tu email y te mandamos un enlace. Tu racha sigue intacta.';

  @override
  String get authLinkSent => 'Enlace enviado. Mira en spam si se esconde.';

  @override
  String get authResendLink => 'Reenviar enlace';

  @override
  String authResendCountdown(int seconds) {
    return 'Reenviar en ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Volver a entrar';

  @override
  String get authInvalidEmail => 'eso no parece un email';

  @override
  String get authEmailInUse => 'ese email ya tiene un plan — inicia sesión';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint =>
      'caladas al día — estás a punto de saberlo';

  @override
  String get obWelcomeTitle => '¿Cuánto dependes de verdad?';

  @override
  String get obWelcomeSubtitle =>
      'Chequeo de 2 minutos. Resultados brutalmente honestos. Un plan hecho para ti.';

  @override
  String get obWelcomeFactLabel => '¿Ya te lo hiciste?';

  @override
  String get obWelcomeFactValue => 'El 83% termina en menos de 2 min';

  @override
  String get obWelcomeCta => 'Empezar mi chequeo';

  @override
  String get obGenderTitle => '¿Cómo te identificas?';

  @override
  String get obGenderSubtitle =>
      'Calibra tu plan — el metabolismo de la nicotina varía.';

  @override
  String get obGenderWoman => 'Mujer';

  @override
  String get obGenderMan => 'Hombre';

  @override
  String get obGenderNonBinary => 'No binario / prefiero no decirlo';

  @override
  String get obGenderPrivacyNote =>
      '🔒 Privado. Nunca se muestra a la comunidad.';

  @override
  String get obBirthYearTitle => '¿En qué año naciste?';

  @override
  String get obBirthYearSubtitle => 'Tu plan se adapta a tu edad.';

  @override
  String get obUnder18Title => 'Aquí no podemos ayudarte — pero esto sí.';

  @override
  String get obUnder18Subtitle =>
      'Cirrus es para mayores de 18. Estas dos opciones son gratis, privadas y hechas para tu edad. Funcionan.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Mensajes diarios de gente que lo entiende. Más de 500.000 jóvenes inscritos.';

  @override
  String get obUnder18TiqCta => 'Envía DITCHVAPE al 88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Coaching gratis por mensaje o llamada, para adolescentes. Sin sermones.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'Vamos contigo. Vuelve a los 18 si aún nos necesitas — no lo harás. 💪';

  @override
  String get obTriedTitle => '¿Has intentado dejarlo antes?';

  @override
  String get obTriedNever => 'Nunca';

  @override
  String get obTriedNeverSub => 'primera vez';

  @override
  String get obTriedOnce => 'Una vez';

  @override
  String get obTriedOnceSub => 'no cuajó';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'varias rondas';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'perdí la cuenta';

  @override
  String get obTriedReaction =>
      'La mayoría necesita varios intentos. Cada uno le enseñó algo a tu cerebro — esta vez tendrás un plan.';

  @override
  String get obFrequencyTitle => '¿Cuánto lo tienes en la mano?';

  @override
  String get obFrequencySubtitle => 'Sin juicios. Solo calibración.';

  @override
  String get obFreqDaily => 'A DIARIO';

  @override
  String get obFreqDailySub => 'Cada día, con pausas reales entre medias.';

  @override
  String get obFreqOften => 'A MENUDO';

  @override
  String get obFreqOftenSub => 'Casi todo el día, por sesiones.';

  @override
  String get obFreqAlways => 'SIEMPRE';

  @override
  String get obFreqAlwaysSub => 'Es prácticamente parte de mi mano.';

  @override
  String get obPuffsTitle => '¿Caladas en un día normal?';

  @override
  String get obPuffsBadgeLight => 'Hábito ligero';

  @override
  String get obPuffsBadgeModerate => 'Dependencia moderada';

  @override
  String get obPuffsBadgeHeavy => 'Dependencia alta';

  @override
  String get obPuffsBadgeSevere => 'Dependencia severa';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ $count cigarrillos en caladas';
  }

  @override
  String get obPuffsNotSure => '¿No lo sabes? Estímalo por dispositivo →';

  @override
  String get obPuffsHelperTitle => 'Estimación rápida';

  @override
  String get obPuffsHelperBody =>
      'Un desechable típico son ~600 caladas. ¿Cuántos gastas a la semana?';

  @override
  String obPuffsHelperResult(int count) {
    return 'Eso son unas $count caladas al día. Lo autocorregimos en tu primera semana.';
  }

  @override
  String obPuffsHelperDevicesPerWeek(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dispositivos / semana',
      one: '$count dispositivo / semana',
    );
    return '$_temp0';
  }

  @override
  String get obStrengthTitle => '¿Cómo de fuerte es el tuyo?';

  @override
  String get obStrength20Sub => '2% · suave';

  @override
  String get obStrength35Sub => '3,5% · medio';

  @override
  String get obStrength50Sub => '5% · casi todos los desechables';

  @override
  String get obStrengthNotSure => 'No lo sé';

  @override
  String get obStrengthNotSureSub => 'no pasa nada';

  @override
  String get obStrengthNote =>
      'La mayoría de desechables son al 5% — si dudas, esa es la apuesta segura.';

  @override
  String get obSpendTitle => '¿Cuánto te cuesta a la semana?';

  @override
  String get obSpendPerWeek => 'por semana';

  @override
  String get obSpendThats => 'eso es';

  @override
  String obSpendPerYear(String amount) {
    return '$amount al año';
  }

  @override
  String get obSpendKickerSmall => 'Un móvil nuevo. Cada año.';

  @override
  String get obSpendKickerMid => 'Un vuelo a Tokio. Cada año.';

  @override
  String get obSpendKickerBig => 'Dinero de alquiler. Cada año.';

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / mes';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / día';
  }

  @override
  String get obSpendYourMath => 'tus números, no los nuestros';

  @override
  String get obFirstPuffTitle => '¿Primera calada al despertar?';

  @override
  String get obFirstPuffWithin5 => 'En los primeros 5 minutos';

  @override
  String get obFirstPuff5to30 => '5–30 minutos';

  @override
  String get obFirstPuff30to60 => '30–60 minutos';

  @override
  String get obFirstPuffHourPlus => 'Una hora o más';

  @override
  String get obFirstPuffScienceLabel => 'LA CIENCIA';

  @override
  String get obFirstPuffScience =>
      'El tiempo hasta la primera calada es el mejor predictor de dependencia. El 76% de los vapeadores jóvenes la busca en los 30 min tras despertar.';

  @override
  String get obWhyTitle => '¿Por qué quieres salir?';

  @override
  String get obWhySubtitle =>
      'Marca todo lo que te toque. Tu coach lo usará cuando se ponga difícil.';

  @override
  String get obWhyHealth => 'Salud';

  @override
  String get obWhyMoney => 'Dinero';

  @override
  String get obWhyFreedom => 'Libertad';

  @override
  String get obWhyFamily => 'Familia';

  @override
  String get obWhyFitness => 'Deporte';

  @override
  String get obWhyAppearance => 'Piel y aspecto';

  @override
  String get obWhyCardLabel => 'TU PORQUÉ';

  @override
  String get obWorriesTitle => '¿Qué te preocupa más?';

  @override
  String get obWorriesSubtitle => 'Sé honesto. Esta es la parte útil.';

  @override
  String get obWorryCravings => 'Antojos';

  @override
  String get obWorryStress => 'Estrés';

  @override
  String get obWorrySocial => 'Presión social';

  @override
  String get obWorryFailing => 'Miedo a fallar';

  @override
  String get obWorryWeight => 'Subir de peso';

  @override
  String get obWorryBreaks => 'Perder mis pausas';

  @override
  String get obWorriesAiNote =>
      'Tu coach entrena con exactamente esto. ¿Antojo a las 11 de la noche? Ya conoce tu jugada.';

  @override
  String get obMethodFailingNote =>
      'Marcaste \"miedo a fallar\" — por eso este plan se dobla en vez de romperse. Una recaída ajusta la curva; nada se reinicia nunca.';

  @override
  String get obMethodTitle => '¿Cómo quieres hacerlo?';

  @override
  String get obMethodSubtitle =>
      'Ambos funcionan. Una línea honesta de cada uno.';

  @override
  String get obMethodTaper => 'Reducir poco a poco';

  @override
  String get obMethodTaperSub =>
      'Baja con una curva diaria. Retirada más suave, pide disciplina.';

  @override
  String get obMethodTaperReco => 'Ideal con 100+ caladas/día — o sea, tú';

  @override
  String get obMethodCold => 'De golpe';

  @override
  String get obMethodColdSub =>
      'Un corte total. Primera semana dura, sales antes del túnel.';

  @override
  String get obMethodColdReco => 'Viable a tu nivel — tú decides';

  @override
  String get obPaceTitle => 'Elige tu ritmo.';

  @override
  String obPaceMostChosen(int days) {
    return '$days días — el más elegido';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count caladas';
  }

  @override
  String get obPaceCurveLabel => 'tu curva';

  @override
  String get obPaceCurveEnd => '0 caladas';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Día de libertad';
  }

  @override
  String get obPaceNote =>
      'La curva se redibuja al tocar un ritmo. Fechas reales, no \"día n\".';

  @override
  String get obPaceCta => 'Fijar mi ritmo';

  @override
  String get obBuildingTitle => 'Construyendo tu plan…';

  @override
  String obBuildingStep1(int count) {
    return 'Analizando $count caladas/día';
  }

  @override
  String get obBuildingStep2 => 'Mapeando tus disparadores';

  @override
  String obBuildingStep3(int days) {
    return 'Calibrando tu curva de $days días…';
  }

  @override
  String get obBuildingStep4 => 'Reservando tu coach…';

  @override
  String obRevealTitle(int days) {
    return 'Tu plan de ruptura de $days días.';
  }

  @override
  String get obRevealMilestone3 =>
      'pico de antojos — aquí estaremos más presentes';

  @override
  String get obRevealMilestone7 => 'vuelven el gusto y el olfato';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Día de libertad — $date';
  }

  @override
  String get obRevealSavedLabel => 'ahorrado para el Día de libertad';

  @override
  String get obRevealPuffsLabel => 'caladas que no darás';

  @override
  String get obRevealProofLabel => 'PRUEBA HONESTA';

  @override
  String get obRevealProof =>
      '24% lo dejó con un programa estructurado vs 19% por su cuenta — ensayo aleatorizado con 2.588 jóvenes. No es magia. Son mejores probabilidades.';

  @override
  String get obRevealCta => 'Estoy listo';

  @override
  String get obCommitTitle => 'Hazlo real.';

  @override
  String get obCommitSubtitle => 'Mantén pulsado. En serio.';

  @override
  String get obCommitHold => 'Mantén para\ncomprometerte';

  @override
  String get obCommitFreedomLabel => '🏆 DÍA DE LIBERTAD';

  @override
  String obCommitDaysOut(int days) {
    return '$days días desde hoy. Ya está en el calendario.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 Nunca vendemos tus datos. Sin rastreadores. Jamás.';

  @override
  String get obRatingTitle =>
      'La reseña de un exvapeador ayuda al siguiente a encontrarnos.';

  @override
  String get obRatingSubtitle => '30 segundos. Se puede saltar. Sin rencores.';

  @override
  String get obRatingBetaTester => 'BETA TESTER';

  @override
  String get obRatingQuote1 =>
      '\"El botón de pánico me sacó de la primera semana. Habría caído el día 3 sin él.\"';

  @override
  String get obRatingQuote2 =>
      '\"La primera app que no me habla como un médico o como mi madre.\"';

  @override
  String get obRatingCardTitle => '¿Te gusta Cirrus?';

  @override
  String get obRatingCardSubtitle =>
      'Toca una estrella para puntuarla en el App Store.';

  @override
  String get obNotifTitle => 'Refuerzos, justo cuando caes.';

  @override
  String get obNotifSubtitle =>
      'Nada de spam. Un aviso antes de tus horas de peligro y otro cuando logras un hito.';

  @override
  String get obNotifPreviewTime => 'Vie 21:54';

  @override
  String get obNotifPreviewBody =>
      'ojo — los viernes por la noche son tu pico. El plan está listo 💪';

  @override
  String get obNotifBullet1 => 'Aviso de horas de peligro (tú pones las horas)';

  @override
  String get obNotifBullet2 => 'Celebraciones de rachas e hitos';

  @override
  String get obNotifBullet3 => 'Avisos SOS de tu aliado — nada más';

  @override
  String get obNotifCta => 'Activar refuerzos';

  @override
  String get paywallTitle => 'Tu plan está listo.';

  @override
  String get paywallSubtitle => 'Prueba todo gratis durante 3 días.';

  @override
  String get paywallFeatCoach => 'Coach IA, sin límite';

  @override
  String get paywallFeatPanic => 'Botón de pánico + aviso al aliado';

  @override
  String get paywallFeatPlan => 'Plan adaptativo';

  @override
  String get paywallFeatForecasts => 'Pronóstico de antojos';

  @override
  String get paywallFeatCommunity => 'Comunidad';

  @override
  String get paywallFeatReports => 'Informes semanales';

  @override
  String get paywallYearly => 'ANUAL';

  @override
  String get paywallYearlyBadge => 'MEJOR PRECIO';

  @override
  String get paywallYearlySub => '0,77 \$/semana · AHORRA 74%';

  @override
  String get paywallMonthly => 'MENSUAL';

  @override
  String get paywallWeekly => 'SEMANAL';

  @override
  String get paywallWeeklySub => 'Precio fundador — fijo para siempre';

  @override
  String get paywallTrialReminder =>
      '🔔 Te avisaremos antes de que acabe tu prueba';

  @override
  String get paywallCancelAnytime => 'Cancela cuando quieras';

  @override
  String get paywallAnchor => 'Menos que un desechable a la semana';

  @override
  String get paywallCta => 'Empezar mis 3 días gratis';

  @override
  String get paywallFreeLink => 'Seguir con el plan Gratis →';

  @override
  String get freePlanTitle => 'Gratis ya te pone en marcha.';

  @override
  String get freePlanSubtitle =>
      'Tuyo para siempre. Sin cuenta atrás, sin insistir.';

  @override
  String get freePlanFeat1 => 'Registro de caladas + rachas';

  @override
  String get freePlanFeat2 => 'Contador de dinero ahorrado';

  @override
  String get freePlanFeat3 => '5 mensajes de coach al día';

  @override
  String get freePlanFeat4 => '1 sesión de Botón de pánico al día';

  @override
  String get freePlanFeat5 => 'Comunidad (leer + reaccionar)';

  @override
  String get freePlanUpgradeNote =>
      'Mejora cuando quieras — tu racha y tu historial van contigo.';

  @override
  String get freePlanCta => 'Empezar con Gratis';

  @override
  String get winbackBadge => 'OFERTA FUNDADORA · SOLO UNA VEZ';

  @override
  String get winbackTitle => 'Vale — el primer mes casi gratis.';

  @override
  String get winbackSubtitle =>
      'Ya construiste el plan. Prueba el kit completo un mes antes de decidir.';

  @override
  String get winbackFirstMonth => 'primer mes';

  @override
  String winbackNote(String price) {
    return 'Luego $price/mes. Cancela cuando quieras. Se muestra una vez, nunca más.';
  }

  @override
  String get winbackCta => 'Reclamar mes fundador';

  @override
  String get winbackDecline => 'No gracias, Gratis me vale';

  @override
  String get day1Title => 'Día 1. Vamos.';

  @override
  String get day1Subtitle =>
      'Tres pasos de arranque. Dos minutos. Luego la app hace su trabajo.';

  @override
  String get day1Task1 => 'Registra tu primera calada';

  @override
  String get day1Task1Done => 'hecho — honestidad desde la primera';

  @override
  String get day1Task1Sub => 'un toque honesto en el botón grande';

  @override
  String get day1Task2 => 'Conoce a tu coach';

  @override
  String get day1Task2Sub => 'Hola de 30 seg. Ya conoce tus disparadores.';

  @override
  String get day1Task3 => 'Fija tus horas de peligro';

  @override
  String get day1Task3Sub => '¿cuándo caes? llegaremos antes';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Día de libertad: $date · a $days días · plan armado';
  }

  @override
  String get day1CtaCoach => 'Conocer a mi coach';

  @override
  String get day1CtaHome => 'Ir a Hoy';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Día $day de $total';
  }

  @override
  String get homeTitle => 'Hoy';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count días',
      one: '🔥 $count día',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'caladas hoy';

  @override
  String homeOfLimit(int limit) {
    return 'de $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return '$count por debajo de tu línea de hoy. Vas por delante de tu curva.';
  }

  @override
  String homeLeftTight(int count) {
    return 'Te quedan $count en la línea de hoy. Justo — tú puedes.';
  }

  @override
  String get homeOverLine =>
      'Por encima de la línea de hoy. Respira — mañana se ajusta.';

  @override
  String homeVsDay1(String percent) {
    return '$percent vs día 1';
  }

  @override
  String get homeSavedSoFar => 'ahorrado hasta hoy';

  @override
  String get homeCravingsBeaten => 'antojos vencidos';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return '¿$weekday duro? Lo noté.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'Tu pico de las $hour está al caer — ¿quieres un plan?';
  }

  @override
  String get homeLogPuff => 'REGISTRAR CALADA';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => '¿Hoy sin caladas?';

  @override
  String get homeVapeFreeCta => 'Confirmar día sin vapear ✓';

  @override
  String get homeVapeFreeDone =>
      'Día sin vapear confirmado. Eso es todo el juego. 🔥';

  @override
  String get homeLoggedSnack => '1 calada registrada';

  @override
  String get homeLogPlusOne => '+1 registrada';

  @override
  String homeLogRingNote(int count) {
    return 'el anillo avanza con un rebote · quedan $count hoy';
  }

  @override
  String get homeOverLimitTitle => 'Por encima de tu línea';

  @override
  String get homeOverLimitBody =>
      'Respira — la línea de mañana se ajusta. Sin culpas.';

  @override
  String get homeOverLimitBreathe => 'Respira 60s';

  @override
  String get homeOverLimitCoach => 'Hablar con el coach';

  @override
  String get homeOverLimitFooter =>
      'Sigue registrando con honestidad — los datos son todo el juego.';

  @override
  String get homeTokenUsedNote =>
      'Ficha de reparación usada — tu racha sobrevive. La llama se atenúa hoy, no se apaga.';

  @override
  String get navHome => 'Inicio';

  @override
  String get navStats => 'Datos';

  @override
  String get navCommunity => 'Comunidad';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'MODO PÁNICO · $step DE 3';
  }

  @override
  String get panicBreatheNote =>
      'esta sensación llega a un pico y pasa — la mayoría de antojos muere en 15 min';

  @override
  String get panicBreatheIn => 'Inhala…';

  @override
  String get panicBreatheHold => 'Mantén…';

  @override
  String get panicBreatheOut => 'Exhala…';

  @override
  String get panicBreathePattern => 'Inhala 4 · Mantén 7 · Exhala 8';

  @override
  String panicCravingTimer(String time) {
    return 'cronómetro del antojo · $time · pico ~15 min';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'cronómetro del antojo · $time · ya pasaste lo peor';
  }

  @override
  String get panicSkipToWhy => 'Ir a mi porqué →';

  @override
  String get panicWhyTitle => 'Recuerda por qué empezaste.';

  @override
  String get panicYouSaid => 'TÚ DIJISTE';

  @override
  String panicWhyLine(String why, String amount) {
    return 'Haces esto por tu $why y por los $amount al año que recuperas.';
  }

  @override
  String get panicIntensityQuestion => '¿Cómo de fuerte es ahora mismo?';

  @override
  String get panicIntensityLow => 'meh';

  @override
  String get panicIntensityHigh => 'gritando';

  @override
  String get panicStillCraving => 'Sigo con el antojo — siguiente';

  @override
  String get panicItPassed => 'Pasó 🎉 estoy bien';

  @override
  String get panicLoopTitle => 'Rompe el bucle.';

  @override
  String get panicLoopSubtitle =>
      'Tus manos y tu cabeza necesitan una tarea 60 segundos. Elige una.';

  @override
  String get panicLoopGame => 'Juego de 60 segundos';

  @override
  String get panicLoopGameSub =>
      'ocupa justo ese picor — pulgares ocupados, mente ocupada';

  @override
  String get panicLoopBuddy => 'Escribir a mi aliado';

  @override
  String panicLoopBuddySub(String name) {
    return '$name recibe: \"antojo — convénceme de no hacerlo\"';
  }

  @override
  String get panicLoopCoach => 'Hablar con el coach';

  @override
  String panicLoopCoachSub(String hour) {
    return 'sabe que este es tu patrón de estrés de las $hour';
  }

  @override
  String get panicLoopCoachLocked => 'ya usaste tu sesión de IA gratis de hoy';

  @override
  String panicBuddyPinged(String name) {
    return 'Aviso enviado. $name te cubre.';
  }

  @override
  String get gameTitle => 'Toca cada chispa';

  @override
  String get gameSubtitle => '60 segundos. Pulgares ocupados, mente ocupada.';

  @override
  String get gameScore => 'chispas';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get gameDone => 'Tiempo. Mira eso — la ola se rompió.';

  @override
  String get survivedPlusOne => '+1 antojo vencido';

  @override
  String get survivedLine1 => 'Ese no tenía nada que hacer contigo.';

  @override
  String get survivedLine2 => 'La ola se rompió. Tú no.';

  @override
  String get survivedLine3 => '15 minutos de valentía. Guardados para siempre.';

  @override
  String get survivedLine4 => 'Tu cerebro acaba de aprender quién manda.';

  @override
  String get survivedLine5 => 'Antojo 0 — tú 1. Otra vez.';

  @override
  String get survivedLine6 => 'Sigues libre. Sigues adelante.';

  @override
  String get survivedLine7 => 'Ese picor acaba de pagarle a tu yo del futuro.';

  @override
  String get survivedLine8 => 'Sangre fría. De la buena.';

  @override
  String get survivedTotalLabel => 'antojos superados en total';

  @override
  String get survivedShare => 'Compartir la victoria ↗';

  @override
  String get survivedBack => 'Volver a hoy';

  @override
  String get survivedShareCopied => 'Tarjeta copiada — pégala donde quieras.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● conoce tu plan · día $day';
  }

  @override
  String get coachChipCraving => 'Tengo un antojo';

  @override
  String get coachChipRoughDay => 'Día duro';

  @override
  String get coachChipSlipped => 'Recaí';

  @override
  String get coachChipProgress => 'Muéstrame mi progreso';

  @override
  String get coachInputHint => 'Escribe a tu coach…';

  @override
  String get coachTyping => 'Ember está escribiendo…';

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensajes gratis hoy',
      one: '$count mensaje gratis hoy',
    );
    return '$_temp0';
  }

  @override
  String get coachCapReached =>
      'Esos son mis 5 mensajes gratis de hoy — vuelvo a medianoche. ¿Me quieres 24/7? Eso es Premium.';

  @override
  String get coachConnectionLost =>
      'Se cortó la señal a mitad de idea 😅 Sigo aquí — ¿me lo repites cuando vuelvas a estar en línea?';

  @override
  String get errorOfflineBanner =>
      'sin conexión — todo cuenta, sincronizamos luego';

  @override
  String get errorOfflineTitle => 'Sin wifi, sin drama';

  @override
  String get errorOfflineBody =>
      'Ahora mismo estás sin conexión. No se pierde nada — reconecta y seguimos justo donde lo dejaste.';

  @override
  String get errorGenericTitle => 'Vaya, eso falló';

  @override
  String get errorGenericBody =>
      'Es cosa nuestra, no tuya. Inténtalo otra vez en un momento.';

  @override
  String get errorRetry => 'Otra vez';

  @override
  String get errorGotIt => 'Vale';

  @override
  String get errorFeedTitle => 'El feed nos dejó en visto';

  @override
  String get errorFeedBody =>
      'No pudimos llegar a la comunidad. Revisa tu señal e inténtalo otra vez.';

  @override
  String get errorRouteTitle => 'Esta página no existe';

  @override
  String get errorRouteBody =>
      'Lo que buscabas no está aquí. Volvamos a lo importante.';

  @override
  String get errorRouteCta => 'Llévame a casa';

  @override
  String get errorBackstage =>
      'algo falló entre bastidores — puedes seguir tranquilo';

  @override
  String get coachWeekCardLabel => 'TU SEMANA';

  @override
  String coachWeekCardCaption(String day) {
    return 'bajando — el $day fue el difícil';
  }

  @override
  String coachGreeting(int puffs, String method, String date) {
    return 'Hola. Soy Ember — lo dejé hace dos años y recuerdo exactamente cómo se siente. Leí tu plan: $puffs al día, $method, Día de libertad $date. De mí no salen sermones, nunca. ¿Qué está pasando ahora mismo?';
  }

  @override
  String get coachReplyCraving1 =>
      'Esa ola es brutal, lo sé. En 15 minutos se rompe — no es ánimo, es biología. Agua fría en las muñecas y quédate conmigo. ¿Qué la disparó?';

  @override
  String coachReplyCraving2(int count) {
    return 'Vale. Respira conmigo una ronda — inhala 4, mantén 7, exhala 8. Los antojos suelen morir en 15–20 minutos. Ya venciste $count. Este no es distinto.';
  }

  @override
  String get coachReplyCraving3 =>
      'Te escucho. No discutas con el antojo, solo aguántalo. Camina una manzana o abre el juego de 60 segundos. Sube y muere — 15 minutos, máximo.';

  @override
  String coachReplyRough1(int percent) {
    return 'Es justo. Los días duros son cuando el viejo hábito grita más. Trato: paseo de 10 min antes de la siguiente. Si aún la quieres, regístrala con honestidad — sigues un $percent% por debajo de tu base.';
  }

  @override
  String get coachReplyRough2 =>
      'Suena pesado. No tienes que arreglar hoy, solo atravesarlo — y puedes hacerlo sin nicotina. Aquí estoy igual.';

  @override
  String coachReplySlip1(int count) {
    return 'Una recaída es información, no derrota. ¿Qué la disparó — estrés, gente, aburrimiento? El plan ya se dobló para sostenerte. Tus $count días siguen contando.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Aquí no hay vergüenza. La mayoría de los que lo dejan para siempre recayeron por el camino. Regístralo, encuentra el disparador, sigue. Tu historial sigue siendo tuyo: $amount ahorrados, tu mejor racha intacta.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Mira los números reales: día $day, $saved de vuelta en tu bolsillo, $cravings antojos vencidos. El tú del día 1 no podía con el hoy. Eso es real.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today caladas hoy contra una línea de $limit. Hace dos semanas ese número habría sido el doble. Lo estás haciendo de verdad.';
  }

  @override
  String get coachReplyGeneric1 =>
      'Te escucho. Cuéntame más — ¿qué hay debajo de eso?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Tiene sentido. Por si sirve: vas por el día $day y sigues aquí. Eso cuenta mucho.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Entendido. Una pregunta honesta: ¿esto es cosa de nicotina o es la vida con la chaqueta de la nicotina puesta?';

  @override
  String get coachReplyGeneric4 =>
      'Vale. Esto se gana con movimientos pequeños. ¿Qué puedes hacer en los próximos 10 minutos que no sea vapear?';

  @override
  String coachReplyParty(int count) {
    return 'Manual de fiesta: bebida fría en la mano toda la noche, escríbenos a mí o a tu aliado cuando salga el primer vaper, y prepara tu frase de salida. Has superado $count antojos — una fiesta son varios seguidos.';
  }

  @override
  String get coachSafetyNote =>
      'Ember es una herramienta de apoyo, no un médico. ¿Crisis? Llama o escribe al 988 (EE. UU. y Canadá), a cualquier hora.';

  @override
  String get planTitle => 'Tu plan';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days días';
  }

  @override
  String get planMethodTaper => 'Reducción';

  @override
  String get planMethodCold => 'De golpe';

  @override
  String planTodayMarker(int limit) {
    return 'hoy · $limit/día';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'PRÓXIMAMENTE';

  @override
  String planHalfwayTitle(int day) {
    return 'Día $day — mitad de camino';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'la línea baja a $limit/día';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Día $day — los antojos se apagan';
  }

  @override
  String get planCravingsFadeSub => 'la mayoría nota mañanas más fáciles';

  @override
  String planFreedomTitle(int day) {
    return 'Día $day — Día de libertad';
  }

  @override
  String get planAdjustCta => 'Ajustar mi plan';

  @override
  String get planAdjustNote =>
      'ritmo + método editables · sin reinicios, sin perder historial';

  @override
  String get planAdaptiveLabel => 'AJUSTE DE ANOCHE';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'Llevas tres días por debajo de tu línea, así que hoy el objetivo baja a $limit. Impulso, no castigo.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'Estás manteniendo la línea. Hoy el objetivo sigue en $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'Los últimos dos días te pasaste, así que hoy el objetivo se ajusta a $limit. Una línea que puedes sostener vale más que una que no.';
  }

  @override
  String get planAdaptiveStretched =>
      'El Día de la Libertad se movió un día para acompañarlo.';

  @override
  String get planAdjustSheetTitle => 'Ajusta tu plan';

  @override
  String get planAdjustSheetNote =>
      'La curva se regenera desde hoy con tus números reales. El historial se queda. El Día de libertad se mueve con honestidad.';

  @override
  String get planAdjustApply => 'Aplicar — recalcular mi curva';

  @override
  String planAdjusted(String date) {
    return 'Plan recalculado. Nuevo Día de libertad: $date';
  }

  @override
  String get statsTitle => 'Datos';

  @override
  String get statsRangeDay => 'Día';

  @override
  String get statsRangeWeek => 'Semana';

  @override
  String get statsRangeMonth => 'Mes';

  @override
  String get statsPuffsThisWeek => 'CALADAS ESTA SEMANA';

  @override
  String get statsPuffsToday => 'CALADAS HOY · POR HORA';

  @override
  String get statsPuffsThisMonth => 'CALADAS · ÚLTIMOS 30 DÍAS';

  @override
  String statsVsLast(String percent) {
    return '$percent vs anterior';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return 'El $day fue el día difícil — $reason. Te recuperaste a la mañana siguiente.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return 'El $day fue el día difícil. Te recuperaste a la mañana siguiente.';
  }

  @override
  String get statsTriggerHours => 'HORAS DISPARADOR';

  @override
  String statsDangerWindow(String range) {
    return '$range es tu ventana de peligro · avisos armados ahí';
  }

  @override
  String get statsNicotinePerDay => 'NICOTINA / DÍA';

  @override
  String statsNicotineValue(int mg) {
    return '${mg}mg ↓';
  }

  @override
  String get statsLongestGap => 'mayor pausa';

  @override
  String get statsBestDay => 'mejor día (caladas)';

  @override
  String get statsCravingsBeaten => 'antojos vencidos';

  @override
  String get statsEmptyTitle => 'Las gráficas aparecen mañana.';

  @override
  String get statsEmptyBody =>
      'Un día de registros = un punto. Sigue registrando — el dibujo se hace solo.';

  @override
  String statsEditDayTitle(String date) {
    return 'Editar $date';
  }

  @override
  String get statsEditDayNote =>
      'El historial es tuyo. Racha y dinero se recalculan de aquí en adelante.';

  @override
  String get statsEditHint => 'mantén pulsada una barra para corregir un día';

  @override
  String get communityTitle => 'Comunidad';

  @override
  String communityYouAre(String alias) {
    return 'eres $alias';
  }

  @override
  String get communityFilterAll => 'Todo';

  @override
  String get communityTagWin => '🏆 Logro';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Día 1';

  @override
  String get communityTagMilestone => 'Hito';

  @override
  String get communityTagVent => 'Desahogo';

  @override
  String get communityIGotYou => 'Te cubro 💬';

  @override
  String communityReplyingNow(int count) {
    return '$count respondiendo ahora…';
  }

  @override
  String get communityReport => 'Denunciar';

  @override
  String get communityMute => 'Silenciar';

  @override
  String get communityBlock => 'Bloquear usuario';

  @override
  String get communityReported =>
      'Denunciado. Revisamos en 24h — 3 denuncias ocultan el post.';

  @override
  String get communityBlocked => 'Bloqueado. No volveréis a veros.';

  @override
  String get communityMuted => 'Silenciado. No verás más sus posts.';

  @override
  String get communityAutoFlagged =>
      'Retenido para revisión — aquí no se permiten marcas ni dónde comprar.';

  @override
  String get communityComposerTitle => 'Nuevo post';

  @override
  String get communityComposerPost => 'Publicar';

  @override
  String communityPostingAs(String alias, int day) {
    return 'publicando como $alias · día $day · siempre anónimo';
  }

  @override
  String get communityComposerHint => '¿Qué pasa en tu proceso?';

  @override
  String get communityTagIt => 'ETIQUÉTALO';

  @override
  String get communityKindnessNote =>
      'Sé amable — aquí todos estamos en plena pelea. Sin marcas, sin dónde-comprar.';

  @override
  String get communityTagRequired =>
      'Elige una etiqueta — lleva tu post a la gente correcta.';

  @override
  String communitySosBanner(int count) {
    return '🛡️ $count personas te cubren ahora mismo';
  }

  @override
  String get communityAddVoice => 'Suma tu voz…';

  @override
  String communityPostAge(int minutes) {
    return '${minutes}m';
  }

  @override
  String communityPostAgeHours(int hours) {
    return '${hours}h';
  }

  @override
  String communityDayTag(int day) {
    return 'día $day';
  }

  @override
  String get communityEmptyTitle => 'Aún no hay posts — saluda.';

  @override
  String get communityEmptyBody =>
      'Tu post del Día 1 es el que alguien en el Día 0 necesita leer.';

  @override
  String get communityPosted => 'Publicado. Alguien necesitaba leer eso.';

  @override
  String get buddyTitle => 'Tu aliado';

  @override
  String get buddyCombinedStreak => 'racha combinada';

  @override
  String get buddyNeitherCaves => 'ninguno cae solo';

  @override
  String buddyNudge(String name) {
    return '👊 Animar a $name';
  }

  @override
  String get buddyMessage => '💬 Mensaje';

  @override
  String buddyPrivacyNote(String name) {
    return '$name ve tus avisos SOS y recibe un toque si desapareces 2 días. Nada más — tus caladas no se comparten salvo que tú quieras.';
  }

  @override
  String get buddyPairsLabel => 'DEJARLO EN PAREJA ES MÁS FÁCIL';

  @override
  String get buddyInviteTitle => 'Invita a otra persona';

  @override
  String get buddyCopyLink => 'Copiar enlace';

  @override
  String get buddyLinkCopied =>
      'Enlace copiado — dejarlo con refuerzos pega distinto.';

  @override
  String buddyNudged(String name) {
    return 'Ánimo enviado. $name lo va a sentir.';
  }

  @override
  String get buddyNudgeCap =>
      'Dos ánimos al día lo mantienen sano. Más mañana.';

  @override
  String get moneyTitle => 'Dinero de vuelta';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'ahorrado desde $date · $perDay entrando cada día';
  }

  @override
  String get moneyBuysLabel => 'LO QUE YA COMPRA';

  @override
  String moneyToGo(String amount, int days) {
    return 'faltan $amount · ~$days días a tu ritmo';
  }

  @override
  String moneyToGoShort(String amount) {
    return 'faltan $amount';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'el de tu registro inicial · faltan $amount';
  }

  @override
  String get moneySetGoal => 'Crea una meta';

  @override
  String get moneySetGoalSub =>
      'ponle nombre, ponle precio, mira la barra llenarse';

  @override
  String get moneyGoalSheetTitle => 'Nueva meta de ahorro';

  @override
  String get moneyGoalNameHint => 'Nómbrala — \"PS5\", \"Lisboa\", \"batería\"';

  @override
  String get moneyGoalPriceHint => 'Precio';

  @override
  String get moneyGoalCreate => 'Arrancar la barra';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'Los números son tuyos: $weekly/semana × 52 = $yearly/año. Nada inventado.';
  }

  @override
  String get moneyGoalDone => 'Meta cumplida. Confeti ganado. 🎉';

  @override
  String get seedGoalKicks => 'Zapas nuevas';

  @override
  String get seedGoalTokyo => 'Vuelo a Tokio';

  @override
  String get healthTitle => 'Tu cuerpo, sanando';

  @override
  String healthAnchor(String ago) {
    return 'Según tu última calada registrada · hace $ago';
  }

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — estás aquí';
  }

  @override
  String get healthM20min => '20 minutos';

  @override
  String get healthM20minBody =>
      'El pulso y la presión vuelven a la normalidad.';

  @override
  String get healthM8h => '8 horas';

  @override
  String get healthM8hBody =>
      'El oxígeno se normaliza mientras la nicotina baja.';

  @override
  String get healthM12h => '12 horas';

  @override
  String get healthM12hBody =>
      'El monóxido de carbono en tu sangre cae a niveles normales.';

  @override
  String get healthM24h => '24 horas';

  @override
  String get healthM24hBody =>
      'La nicotina cae rápido. Los antojos gritan — esa es la puerta de salida.';

  @override
  String get healthM48h => '48 horas';

  @override
  String get healthM48hBody =>
      'Las terminaciones nerviosas se regeneran. Gusto y olfato se afinan.';

  @override
  String get healthM72h => '72 horas';

  @override
  String get healthM72hBody =>
      'La nicotina casi desapareció. Pico de antojos — el Botón de pánico vive para esto.';

  @override
  String get healthM1w => '1 semana';

  @override
  String get healthM1wBody =>
      'Gusto y olfato claramente más finos. Respirar se siente más fácil.';

  @override
  String get healthM2w => '2 semanas';

  @override
  String get healthM2wBody =>
      'Mejora la circulación. La función pulmonar empieza a subir.';

  @override
  String get healthM1m => '1 mes';

  @override
  String get healthM1mBody => 'La tos y la falta de aire aflojan.';

  @override
  String get healthM3m => '3 meses';

  @override
  String get healthM3mBody =>
      'La capacidad pulmonar sigue subiendo. El gimnasio se siente distinto.';

  @override
  String get healthM6m => '6 meses';

  @override
  String get healthM6mBody =>
      'Tu nivel base de estrés baja — manejas los días malos sin ello.';

  @override
  String get healthM1y => '1 año';

  @override
  String get healthM1yBody =>
      'Tu perfil de riesgo parece el de alguien que nunca vapeó a diario.';

  @override
  String get healthUnlockNote =>
      'Cada desbloqueo trae una pequeña celebración + tarjeta para compartir.';

  @override
  String get healthSourceNote =>
      'Basado en investigación sobre dejar de fumar — la evidencia sobre vapeo aún está emergiendo.';

  @override
  String get milestonesTitle => 'Hitos';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned de $total ganados';
  }

  @override
  String milestonesNext(String name) {
    return 'Siguiente: $name';
  }

  @override
  String milestonesNextProgress(int day, int target) {
    return 'día $day de $target · dos amaneceres más';
  }

  @override
  String get milestonesNotLeaderboard =>
      'Las insignias son tuyas, no una clasificación. No hay tablero ajeno que comparar.';

  @override
  String get mFirstLog => 'Primer registro';

  @override
  String get mFirstCraving => 'Primer antojo vencido';

  @override
  String get mSpark => 'Chispa de 3 días';

  @override
  String get mWeekFlame => 'Llama de 7 días';

  @override
  String get mHundredSaved => '100 \$ ahorrados';

  @override
  String get mCleanWeekend => 'Finde limpio';

  @override
  String get mHelpedSos => 'Ayudó en un SOS';

  @override
  String get mTwoWeekFlame => 'Llama de dos semanas';

  @override
  String get mHalfNicotine => 'Mitad de nicotina';

  @override
  String get mMoodWeek => 'Semana de ánimo';

  @override
  String get mTenCravings => '10 antojos vencidos';

  @override
  String get mQuarterCurve => 'Un cuarto de la curva';

  @override
  String get mInferno => 'Inferno de 30 días';

  @override
  String get mFreedomDay => 'Día de libertad';

  @override
  String get mFirstPost => 'Primer post';

  @override
  String get mFiveHundredSaved => '500 \$ ahorrados';

  @override
  String get mBuddyBond => 'Vínculo de aliados';

  @override
  String get mComeback => 'Regreso';

  @override
  String get moodTitle => '¿Cómo se siente hoy?';

  @override
  String get moodSubtitle => '10 segundos. Importa más de lo que crees.';

  @override
  String get moodRough => 'duro';

  @override
  String get moodMeh => 'meh';

  @override
  String get moodOkay => 'bien';

  @override
  String get moodGood => 'genial';

  @override
  String get moodGreat => 'increíble';

  @override
  String get moodNoteHint =>
      'Una línea, opcional — \"fiesta del trabajo esta noche, nervios\"';

  @override
  String get moodUnlockTitle => '🔓 Vínculo ánimo ↔ antojo';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total registros';
  }

  @override
  String moodUnlockNote(int count) {
    return '$count más y tu informe mostrará cómo tu ánimo dispara tus antojos.';
  }

  @override
  String get moodCta => 'Registrar';

  @override
  String get moodSaved => 'Anotado. Los datos ganan a las sensaciones. 🙌';

  @override
  String get insightLinkTitle => 'Informe semanal';

  @override
  String insightTitle(int week, String range) {
    return 'Informe semana $week · $range';
  }

  @override
  String get insightWinLabel => 'Tu victoria';

  @override
  String get insightWatchoutLabel => 'Ojo con esto';

  @override
  String get insightWeekChartLabel => 'CALADAS, ÚLTIMOS 7 DÍAS';

  @override
  String get insightCravingsChartLabel => 'ANTOJOS SUPERADOS, ÚLTIMOS 7 DÍAS';

  @override
  String get insightHoursChartLabel => 'CALADAS POR HORA, ÚLTIMOS 14 DÍAS';

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index DE $total';
  }

  @override
  String get insight1Headline =>
      'Vapeas 3× más después de las 10 p. m. los findes.';

  @override
  String get insight1Body =>
      'Las noches de viernes y sábado suman el 41% de tus caladas semanales. Es un disparador social, no de nicotina — otro manual.';

  @override
  String get insight1ChartLabel => 'CALADAS POR HORA · FINDE';

  @override
  String get insight1Action =>
      'Sugerencia del coach: programa un aviso el viernes 21:45 + manos ocupadas en la fiesta (juego listo).';

  @override
  String get insight2Headline => 'Tus mañanas ya son libres.';

  @override
  String get insight2Body =>
      'No registraste ni una calada antes de las 11 a. m. durante cinco días seguidos. ¿El reloj de nicotina que dominaba tu despertar? Roto.';

  @override
  String get insight2ChartLabel => 'PRIMERA CALADA DEL DÍA';

  @override
  String get insight2Action =>
      'Sugerencia del coach: protégelo — vaper fuera del dormitorio y la primera hora sigue siendo tuya.';

  @override
  String get insight3Headline =>
      'Antojos vencidos: 9. Antojos que te vencieron: 2.';

  @override
  String get insight3Body =>
      'Un 82% de victorias. Las dos derrotas fueron a menos de una hora de saltarte una comida — el hambre se pone la chaqueta de la nicotina.';

  @override
  String get insight3ChartLabel => 'RESULTADO DE ANTOJOS';

  @override
  String get insight3Action =>
      'Sugerencia del coach: come algo antes de tu ventana de las 9 p. m. Consejo aburrido, diferencia medible.';

  @override
  String get insight4Headline => 'Próxima semana: la curva se dobla.';

  @override
  String get insight4Body =>
      'Tu línea baja a 100/día el martes. Aquí la curva se empina — esta es la semana en que el Botón de pánico se gana el sueldo.';

  @override
  String get insight4ChartLabel => 'LA SEMANA QUE VIENE';

  @override
  String get insight4Action =>
      'Sugerencia del coach: reserva algo que te encante para el sábado. Premia la curva, no la aprietes con los dientes.';

  @override
  String get slipTitle => 'Una recaída es información, no derrota.';

  @override
  String slipSubtitle(int days) {
    return 'Registraste caladas tras $days días limpios. Eso es información — nos dice exactamente dónde blindar el plan.';
  }

  @override
  String get slipWhatHappened => '¿QUÉ ESTABA PASANDO?';

  @override
  String get slipTriggerParty => 'Fiesta';

  @override
  String get slipTriggerStress => 'Estrés';

  @override
  String get slipTriggerBoredom => 'Aburrimiento';

  @override
  String get slipTriggerDrinking => 'Copas';

  @override
  String get slipTriggerFriends => 'Alguien tenía uno';

  @override
  String get slipTriggerJustHappened => 'Simplemente pasó';

  @override
  String get slipNoBannedWords =>
      'Aquí no hay palabras prohibidas, nunca. La mayoría de los que lo dejan para siempre recayeron por el camino. El registro sigue honesto, el plan se adapta.';

  @override
  String get slipAdjustCta => 'Ajustar mi plan';

  @override
  String get slipAdjustTitle => 'Este es el ajuste.';

  @override
  String get slipCurveLabel => 'TU CURVA — SUAVEMENTE RECALCULADA';

  @override
  String get slipTheBump => 'el bache de la recaída';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Día de libertad: $date (+$days días)';
  }

  @override
  String get slipCurveNote =>
      'Dos días extra, mismo destino. Las noches de fiesta llevan aviso pre-armado + acceso directo al juego.';

  @override
  String slipStreakSurvives(int days) {
    return 'Tus $days días siguen contando.';
  }

  @override
  String get slipFlameDims =>
      'La llama se atenúa, no muere. Un día limpio la devuelve a plena llama.';

  @override
  String get slipBackOnCurve => 'De vuelta a la curva';

  @override
  String get slipTalkFirst => 'Hablarlo antes con el coach';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'dejándolo desde $date · $method · día $day';
  }

  @override
  String get profileCountdownLabel => '🏆 CUENTA ATRÁS AL DÍA DE LIBERTAD';

  @override
  String profileDaysTo(String date) {
    return 'días hasta el $date';
  }

  @override
  String get profileLifetimeSaved => 'ahorro total';

  @override
  String get profilePuffsNotTaken => 'caladas no dadas';

  @override
  String get profileBadgesEarned => 'insignias ganadas';

  @override
  String get profileSettings => '⚙️ Ajustes';

  @override
  String get profileEditAlias => 'Elige tu alias';

  @override
  String get profileEditAvatar => 'Elige tu avatar';

  @override
  String get profileAliasHint => 'anónimo — esto es todo lo que ven';

  @override
  String get memoriesTitle => 'Lo que Ember recuerda';

  @override
  String get memoriesIntro =>
      'Cosas que le contaste a Ember, guardadas para que te sirva dentro de semanas en vez de empezar de cero cada vez. Solo lo que escribiste: nunca tus números, nunca algo que no dijiste.';

  @override
  String get memoriesEmpty =>
      'Nada todavía. Ember empieza a recordar cuando le cuentas algo de tu vida.';

  @override
  String get memoriesFailed => 'No se pudieron cargar ahora mismo.';

  @override
  String get memoriesForget => 'Olvidar esto';

  @override
  String get memoriesForgotten => 'Olvidado. Ember no lo volverá a mencionar.';

  @override
  String get memoriesForgetFailed => 'No se pudo aplicar: sigue recordándolo.';

  @override
  String get memoriesKindPerson => 'Alguien en tu vida';

  @override
  String get memoriesKindTrigger => 'Un detonante';

  @override
  String get memoriesKindMotivation => 'Por qué lo haces';

  @override
  String get memoriesKindMilestone => 'Algo que persigues';

  @override
  String get memoriesKindPreference => 'Cómo te gusta que te hablen';

  @override
  String get memoriesKindContext => 'Sobre ti';

  @override
  String get settingsMemories => 'Lo que Ember recuerda';

  @override
  String get moderationTitle => 'Cola de revisión';

  @override
  String get moderationEmpty =>
      'Nada pendiente. Todos los avisos están revisados.';

  @override
  String get moderationFailed => 'No se pudo abrir la cola.';

  @override
  String get moderationRetry => 'Reintentar';

  @override
  String get moderationShowReviewed => 'Ver revisados';

  @override
  String moderationPendingCount(int count) {
    return '$count pendientes';
  }

  @override
  String get moderationSubjectGone =>
      'La publicación ya no existe; solo queda el aviso.';

  @override
  String get moderationAllow => 'Permitir';

  @override
  String get moderationBlock => 'Bloquear';

  @override
  String get moderationDismiss => 'Está bien';

  @override
  String get moderationResolveFailed =>
      'No se pudo aplicar. La publicación sigue igual.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsAccount => 'Cuenta';

  @override
  String get settingsSubscription => 'Gestionar suscripción';

  @override
  String get settingsSubscriptionValue => 'Premium · anual';

  @override
  String get settingsSubscriptionFree => 'Plan Gratis';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsDangerHours => 'Horas de peligro';

  @override
  String settingsDangerHoursEdit(String range) {
    return '$range · editar ›';
  }

  @override
  String get settingsPrivacy => 'Privacidad';

  @override
  String get settingsPrivacyNote =>
      'Nunca vendemos tus datos. Sin rastreadores. Jamás.';

  @override
  String get settingsExportData => 'Exportar mis datos';

  @override
  String get settingsDeleteEverything => 'Borrarlo todo';

  @override
  String get settingsDeleteConfirmTitle => '¿Borrarlo todo?';

  @override
  String get settingsDeleteConfirmBody =>
      'Tu plan, registros, racha y posts — desaparecen para siempre. Este es el único botón que no podemos deshacer.';

  @override
  String get settingsDeleteConfirmCta => 'Sí, borrarlo todo';

  @override
  String get settingsExported =>
      'Paquete de datos listo — es tuyo, siempre lo fue.';

  @override
  String get settingsAppearance => 'Apariencia';

  @override
  String get settingsAppearanceSystem => 'Como el sistema';

  @override
  String get settingsAppearanceMidnight => 'Midnight';

  @override
  String get settingsAppearanceDaylight => 'Daylight';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Como el sistema';

  @override
  String get settingsSupport => 'Soporte y FAQ';

  @override
  String get settingsRestorePurchases => 'Restaurar compras';

  @override
  String get settingsRestored => 'Compras restauradas — bienvenido de vuelta.';

  @override
  String get settingsSignOut => 'Cerrar sesión';

  @override
  String get settingsSignOutConfirmTitle => '¿Cerrar sesión?';

  @override
  String get settingsSignOutConfirmBody =>
      'Tus datos se quedan en tu cuenta. La racha sigue ardiendo.';

  @override
  String get settingsDangerHoursTitle => 'Horas de peligro';

  @override
  String get settingsDangerHoursNote =>
      'Te avisamos 10 minutos antes de que abra tu ventana. Máximo 3 avisos al día, horas de silencio respetadas.';

  @override
  String settingsQuietHours(String range) {
    return 'Horas de silencio: $range';
  }

  @override
  String get trialEndingPushTime => 'ahora';

  @override
  String get trialEndingPush =>
      'tu prueba termina mañana — como prometimos, aquí está el aviso. Sin cargos sorpresa.';

  @override
  String get trialEndingTitle => 'La prueba termina mañana.';

  @override
  String get trialEndingBody =>
      'Dijimos que te avisaríamos, así que: aquí está. Sigue con Premium o baja a Gratis — tu racha, plan e historial se quedan igual.';

  @override
  String get trialEndingStatsLabel => 'TUS 3 DÍAS HASTA AHORA';

  @override
  String get trialEndingVsDay1 => 'caladas vs día 1';

  @override
  String get trialEndingCravings => 'antojos vencidos';

  @override
  String get trialEndingSaved => 'ahorrado';

  @override
  String trialEndingKeep(String price) {
    return 'Seguir con Premium — $price/año';
  }

  @override
  String get trialEndingSwitchFree => 'Pasar a Gratis (conserva tus datos)';

  @override
  String get frameMapTitle => 'Los 52 frames del diseño';

  @override
  String get frameMapOpen => 'Ver las 52 pantallas →';

  @override
  String get frameMapNote =>
      'Cada frame de los cuatro handoffs, a un toque. Las filas cargan el viaje demo o las respuestas del quiz según haga falta.';

  @override
  String get frameMapEdgeNote =>
      'Estos estados se activan con el backend — una app en memoria no tiene errores de red que mostrar con honestidad.';

  @override
  String get seedPostWin30 =>
      'DÍA DE LIBERTAD. 30 días, cero caladas la última semana. El botón de pánico me sacó de los findes. Si vas por el día 2 y te mueres — de verdad se pone más fácil hacia el día 8.';

  @override
  String get seedPostSos =>
      'en la puerta de la gasolinera. cartera en mano. que alguien me convenza de no hacerlo';

  @override
  String get seedPostDay1 =>
      'tiré el mío al lago. probablemente malo para el lago. el día 1 empieza ahora';

  @override
  String get seedPostVent =>
      'mi compañero suelta nubes de mango en su mesa TODO EL DÍA y se supone que yo… ¿me concentro? me desahogo para no caer';

  @override
  String get seedPostMilestone =>
      'dos semanas. hoy subí por las escaleras hasta el 4º y no soné como un acordeón embrujado. pequeñas victorias';

  @override
  String get seedPostWinParty =>
      'sobreviví una fiesta entera sin pedirle el vaper a nadie. mis manos sobrevivieron sujetando una gaseosa de lima como un bicho raro';

  @override
  String get seedReplyWalk =>
      'camina. solo una manzana. la cartera sigue llena, tú sigues libre. hice exactamente esto el martes';

  @override
  String get seedReplyScience =>
      'el día 4 es el peor, es ciencia. estás en el pico AHORA MISMO. 15 minutos y esto muere';

  @override
  String get seedReplyGatorade =>
      'cómprate un gatorade en su lugar. compra ceremonial. funciona sorprendentemente bien';

  @override
  String get seedReplyUpdate =>
      'actualización: compré el gatorade. caminando a casa. gracias, en serio 💙';

  @override
  String get dangerReminderTitle => 'Se acerca tu hora crítica';

  @override
  String get dangerReminderBody =>
      'Suele ser ahora cuando aprieta. Tienes un plan, y 15 minutos lo superan.';
}
