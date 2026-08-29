// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appName => 'Cirrus';

  @override
  String get appTagline => 'A tua última passa está mais perto\ndo que pensas.';

  @override
  String appVersionFooter(String version) {
    return 'Cirrus $version · feito por gente que largou';
  }

  @override
  String get commonContinue => 'Continuar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonDone => 'Feito';

  @override
  String get commonSave => 'Guardar';

  @override
  String get commonSkip => 'Saltar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonRetry => 'Tentar de novo';

  @override
  String get commonUndo => 'Desfazer';

  @override
  String get commonEdit => 'Editar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get commonNotNow => 'Agora não';

  @override
  String get commonMaybeLater => 'Talvez depois';

  @override
  String get commonComingSoon => 'Em breve';

  @override
  String get commonToday => 'Hoje';

  @override
  String get commonDay => 'Dia';

  @override
  String get commonYou => 'tu';

  @override
  String get commonPremium => 'Premium';

  @override
  String get commonFree => 'Grátis';

  @override
  String get commonUpgrade => 'Fazer upgrade';

  @override
  String get commonSeeAll => 'Ver tudo';

  @override
  String get commonOfflineBanner =>
      'Offline — os teus registos ficam no telemóvel e sincronizam quando voltares.';

  @override
  String get commonErrorTitle => 'Houve um soluço.';

  @override
  String get commonErrorBody =>
      'Os teus dados estão bem. Toca para tentar de novo.';

  @override
  String commonDayOfDay(int day, int total) {
    return 'Dia $day de $total';
  }

  @override
  String commonDayN(int day) {
    return 'dia $day';
  }

  @override
  String commonStreakDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dias',
      one: '$count dia',
    );
    return '$_temp0';
  }

  @override
  String commonPuffsUnit(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passas',
      one: '$count passa',
    );
    return '$_temp0';
  }

  @override
  String get authSplashAutoAdvance => 'A carregar o teu plano…';

  @override
  String get authSignInTitle => 'Vamos pôr o teu plano\nem segurança.';

  @override
  String get authSignInSubtitle =>
      'Anónimo por defeito — vais escolher um alias para a comunidade.';

  @override
  String get authSignInWithApple => 'Iniciar sessão com a Apple';

  @override
  String get authSignInWithGoogle => 'Iniciar sessão com o Google';

  @override
  String get authContinueWithEmail => 'Continuar com email';

  @override
  String get authWhyAccountDivider => 'porquê uma conta?';

  @override
  String get authWhyAccountCard =>
      'A tua sequência, o plano e a memória do teu coach sincronizam entre dispositivos. 🔒 Nunca vendemos os teus dados. Zero rastreadores de anúncios. Nunca.';

  @override
  String get authTerms => 'Termos';

  @override
  String get authPrivacy => 'Privacidade';

  @override
  String get authRestorePurchase => 'Restaurar compra';

  @override
  String get authRegisterTitle => 'Cria a tua conta';

  @override
  String get authEmailLabel => 'EMAIL';

  @override
  String get authPasswordLabel => 'PALAVRA-PASSE';

  @override
  String get authShowPassword => 'ver';

  @override
  String get authHidePassword => 'ocultar';

  @override
  String get authPasswordStrengthWeak => 'continua a escrever…';

  @override
  String get authPasswordStrengthDecent => 'palavra-passe decente';

  @override
  String get authPasswordStrengthStrong => 'palavra-passe forte';

  @override
  String get authNoSpamCard =>
      'Sem spam, sem emails de \"temos saudades\". A conta é o teu backup, só isso.';

  @override
  String get authCreateAccount => 'Criar conta';

  @override
  String get authAlreadyHaveOne => 'Já tens uma?';

  @override
  String get authLogIn => 'Entrar';

  @override
  String get authLoginTitle => 'Olá outra vez.';

  @override
  String get authLoginSubtitle => 'A tua sequência sentiu a tua falta.';

  @override
  String get authForgotPassword => 'Esqueceste a palavra-passe?';

  @override
  String get authNewHere => 'Novo por aqui?';

  @override
  String get authWrongPassword => 'não é essa — tenta de novo';

  @override
  String get authForgotTitle => 'Acontece a toda a gente.';

  @override
  String get authForgotSubtitle =>
      'Deixa o teu email — enviamos um link de reposição. A tua sequência fica intacta.';

  @override
  String get authLinkSent =>
      'Link enviado. Espreita o spam se ele se esconder.';

  @override
  String get authResendLink => 'Reenviar link';

  @override
  String authResendCountdown(int seconds) {
    return 'Reenviar em ${seconds}s';
  }

  @override
  String get authBackToLogin => 'Voltar ao início de sessão';

  @override
  String get authInvalidEmail => 'isso não parece um email';

  @override
  String get authEmailInUse => 'esse email já tem um percurso — inicia sessão';

  @override
  String obProgressOf(int step, int total) {
    return '$step/$total';
  }

  @override
  String get obWelcomeCounterHint => 'passas por dia — estás quase a descobrir';

  @override
  String get obWelcomeTitle => 'Quão dependente és, na verdade?';

  @override
  String get obWelcomeSubtitle =>
      'Check-up de 2 minutos. Resultados brutalmente honestos. Um plano feito para ti.';

  @override
  String get obWelcomeFactLabel => 'Já fizeste o check-up?';

  @override
  String get obWelcomeFactValue => '83% terminam em menos de 2 min';

  @override
  String get obWelcomeCta => 'Começar o meu check-up';

  @override
  String get obGenderTitle => 'Como te identificas?';

  @override
  String get obGenderSubtitle =>
      'Calibra o teu plano — o metabolismo da nicotina varia.';

  @override
  String get obGenderWoman => 'Mulher';

  @override
  String get obGenderMan => 'Homem';

  @override
  String get obGenderNonBinary => 'Não binário / prefiro não dizer';

  @override
  String get obGenderPrivacyNote => '🔒 Privado. Nunca aparece na comunidade.';

  @override
  String get obBirthYearTitle => 'Em que ano nasceste?';

  @override
  String get obBirthYearSubtitle => 'O teu plano adapta-se à tua idade.';

  @override
  String get obUnder18Title => 'Aqui não te podemos ajudar — mas isto pode.';

  @override
  String get obUnder18Subtitle =>
      'O Cirrus é para maiores de 18. Estas duas opções são gratuitas, privadas e feitas para a tua idade. Funcionam.';

  @override
  String get obUnder18TiqTitle => 'This is Quitting';

  @override
  String get obUnder18TiqBody =>
      'Mensagens diárias de quem percebe. Mais de 500.000 jovens inscritos.';

  @override
  String get obUnder18TiqCta => 'Envia DITCHVAPE para 88709';

  @override
  String get obUnder18MlmqTitle => 'My Life, My Quit';

  @override
  String get obUnder18MlmqBody =>
      'Coaching gratuito por mensagem ou chamada, feito para adolescentes. Sem sermões.';

  @override
  String get obUnder18MlmqCta => 'mylifemyquit.org';

  @override
  String get obUnder18Footer =>
      'Estamos contigo. Volta aos 18 se ainda precisares de nós — não vais precisar. 💪';

  @override
  String get obTriedTitle => 'Já tentaste largar antes?';

  @override
  String get obTriedNever => 'Nunca';

  @override
  String get obTriedNeverSub => 'primeira vez';

  @override
  String get obTriedOnce => 'Uma vez';

  @override
  String get obTriedOnceSub => 'não pegou';

  @override
  String get obTried2to5 => '2–5';

  @override
  String get obTried2to5Sub => 'algumas rondas';

  @override
  String get obTried5plus => '5+';

  @override
  String get obTried5plusSub => 'perdi a conta';

  @override
  String get obTriedReaction =>
      'A maioria precisa de várias tentativas. Cada uma ensinou algo ao teu cérebro — desta vez terás um plano.';

  @override
  String get obFrequencyTitle => 'Quanto tempo passa na tua mão?';

  @override
  String get obFrequencySubtitle => 'Sem julgamentos. Só calibração.';

  @override
  String get obFreqDaily => 'DIÁRIO';

  @override
  String get obFreqDailySub => 'Todos os dias, com pausas a sério pelo meio.';

  @override
  String get obFreqOften => 'MUITAS VEZES';

  @override
  String get obFreqOftenSub => 'Quase o dia todo, por sessões.';

  @override
  String get obFreqAlways => 'SEMPRE';

  @override
  String get obFreqAlwaysSub => 'É praticamente parte da minha mão.';

  @override
  String get obPuffsTitle => 'Passas num dia normal?';

  @override
  String get obPuffsBadgeLight => 'Hábito leve';

  @override
  String get obPuffsBadgeModerate => 'Dependência moderada';

  @override
  String get obPuffsBadgeHeavy => 'Dependência alta';

  @override
  String get obPuffsBadgeSevere => 'Dependência severa';

  @override
  String obPuffsCigEquiv(int count) {
    return '≈ $count cigarros em passas';
  }

  @override
  String get obPuffsNotSure => 'Não sabes? Estima pelo dispositivo →';

  @override
  String get obPuffsHelperTitle => 'Estimativa rápida';

  @override
  String get obPuffsHelperBody =>
      'Um descartável típico tem ~600 passas. Quantos gastas por semana?';

  @override
  String obPuffsHelperResult(int count) {
    return 'Isso dá cerca de $count passas por dia. Autocorrigimos na tua primeira semana.';
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
  String get obStrengthTitle => 'Qual a força do teu habitual?';

  @override
  String get obStrength20Sub => '2% · leve';

  @override
  String get obStrength35Sub => '3,5% · médio';

  @override
  String get obStrength50Sub => '5% · quase todos os descartáveis';

  @override
  String get obStrengthNotSure => 'Não sei';

  @override
  String get obStrengthNotSureSub => 'sem problema';

  @override
  String get obStrengthNote =>
      'A maioria dos descartáveis é 5% — na dúvida, é a aposta segura.';

  @override
  String get obSpendTitle => 'Quanto te custa por semana?';

  @override
  String get obSpendPerWeek => 'por semana';

  @override
  String get obSpendThats => 'isso é';

  @override
  String obSpendPerYear(String amount) {
    return '$amount por ano';
  }

  @override
  String get obSpendKickerSmall => 'Um telemóvel novo. Todos os anos.';

  @override
  String get obSpendKickerMid => 'Um voo para Tóquio. Todos os anos.';

  @override
  String get obSpendKickerBig => 'Dinheiro de renda. Todos os anos.';

  @override
  String obSpendPerMonthChip(String amount) {
    return '$amount / mês';
  }

  @override
  String obSpendPerDayChip(String amount) {
    return '$amount / dia';
  }

  @override
  String get obSpendYourMath => 'as tuas contas, não as nossas';

  @override
  String get obFirstPuffTitle => 'Primeira passa depois de acordar?';

  @override
  String get obFirstPuffWithin5 => 'Nos primeiros 5 minutos';

  @override
  String get obFirstPuff5to30 => '5–30 minutos';

  @override
  String get obFirstPuff30to60 => '30–60 minutos';

  @override
  String get obFirstPuffHourPlus => 'Uma hora ou mais';

  @override
  String get obFirstPuffScienceLabel => 'A CIÊNCIA';

  @override
  String get obFirstPuffScience =>
      'O tempo até à primeira passa é o melhor preditor de dependência. 76% dos jovens vapers pegam nele nos 30 min após acordar.';

  @override
  String get obWhyTitle => 'Porque queres sair?';

  @override
  String get obWhySubtitle =>
      'Marca tudo o que te tocar. O teu coach usa isto quando ficar difícil.';

  @override
  String get obWhyHealth => 'Saúde';

  @override
  String get obWhyMoney => 'Dinheiro';

  @override
  String get obWhyFreedom => 'Liberdade';

  @override
  String get obWhyFamily => 'Família';

  @override
  String get obWhyFitness => 'Desporto';

  @override
  String get obWhyAppearance => 'Pele & aparência';

  @override
  String get obWhyCardLabel => 'O TEU PORQUÊ';

  @override
  String get obWorriesTitle => 'O que te preocupa mais?';

  @override
  String get obWorriesSubtitle => 'Sê honesto. Esta é a parte útil.';

  @override
  String get obWorryCravings => 'Cravings';

  @override
  String get obWorryStress => 'Stress';

  @override
  String get obWorrySocial => 'Pressão social';

  @override
  String get obWorryFailing => 'Medo de falhar';

  @override
  String get obWorryWeight => 'Ganhar peso';

  @override
  String get obWorryBreaks => 'Perder as minhas pausas';

  @override
  String get obWorriesAiNote =>
      'O teu coach treina exatamente nisto. Craving às 23h? Já conhece a tua jogada.';

  @override
  String get obMethodFailingNote =>
      'Escolheste \"medo de falhar\" — por isso este plano dobra em vez de partir. Um deslize ajusta a curva; nada é reposto a zero.';

  @override
  String get obMethodTitle => 'Como queres fazer isto?';

  @override
  String get obMethodSubtitle => 'Ambos funcionam. Uma linha honesta de cada.';

  @override
  String get obMethodTaper => 'Reduzir aos poucos';

  @override
  String get obMethodTaperSub =>
      'Desces numa curva diária. Abstinência mais suave, pede disciplina.';

  @override
  String get obMethodTaperReco => 'Ideal com 100+ passas/dia — ou seja, tu';

  @override
  String get obMethodCold => 'Corte total';

  @override
  String get obMethodColdSub =>
      'Uma paragem seca. Primeira semana dura, sais do túnel mais depressa.';

  @override
  String get obMethodColdReco => 'Viável ao teu nível — decides tu';

  @override
  String get obPaceTitle => 'Escolhe o teu ritmo.';

  @override
  String obPaceMostChosen(int days) {
    return '$days dias — o mais escolhido';
  }

  @override
  String obPaceCurveStart(int count) {
    return '$count passas';
  }

  @override
  String get obPaceCurveLabel => 'a tua curva';

  @override
  String get obPaceCurveEnd => '0 passas';

  @override
  String obPaceFreedomDay(String date) {
    return '$date · Dia da liberdade';
  }

  @override
  String get obPaceNote =>
      'A curva redesenha-se em direto quando tocas num ritmo. Datas reais, não \"dia n\".';

  @override
  String get obPaceCta => 'Fixar o meu ritmo';

  @override
  String get obBuildingTitle => 'A construir o teu plano…';

  @override
  String obBuildingStep1(int count) {
    return 'A analisar $count passas/dia';
  }

  @override
  String get obBuildingStep2 => 'A mapear os teus gatilhos';

  @override
  String obBuildingStep3(int days) {
    return 'A calibrar a tua curva de $days dias…';
  }

  @override
  String get obBuildingStep4 => 'A reservar o teu coach…';

  @override
  String obRevealTitle(int days) {
    return 'O teu plano de rutura de $days dias.';
  }

  @override
  String get obRevealMilestone3 =>
      'pico de cravings — é aqui que estaremos mais presentes';

  @override
  String get obRevealMilestone7 => 'o paladar e o olfato voltam';

  @override
  String obRevealMilestoneFreedom(String date) {
    return '🏆 Dia da liberdade — $date';
  }

  @override
  String get obRevealSavedLabel => 'poupado até ao Dia da liberdade';

  @override
  String get obRevealPuffsLabel => 'passas que não vais dar';

  @override
  String get obRevealProofLabel => 'PROVA HONESTA';

  @override
  String get obRevealProof =>
      '24% largam com um programa estruturado vs 19% sozinhos — ensaio aleatorizado com 2.588 jovens adultos. Não é magia. São melhores probabilidades.';

  @override
  String get obRevealCta => 'Estou pronto';

  @override
  String get obCommitTitle => 'Torna-o real.';

  @override
  String get obCommitSubtitle => 'Mantém o botão premido. A sério.';

  @override
  String get obCommitHold => 'Mantém para\nte comprometeres';

  @override
  String get obCommitFreedomLabel => '🏆 DIA DA LIBERDADE';

  @override
  String obCommitDaysOut(int days) {
    return '$days dias a partir de hoje. Já está no calendário.';
  }

  @override
  String get obCommitPrivacy =>
      '🔒 Nunca vendemos os teus dados. Zero rastreadores. Nunca.';

  @override
  String get obRatingTitle =>
      'A avaliação de um ex-vaper ajuda o próximo a encontrar-nos.';

  @override
  String get obRatingSubtitle =>
      '30 segundos. Podes saltar. Sem ressentimentos.';

  @override
  String get obRatingBetaTester => 'BETA TESTER';

  @override
  String get obRatingQuote1 =>
      '\"O botão de pânico levou-me pela primeira semana. Sem ele tinha cedido no dia 3.\"';

  @override
  String get obRatingQuote2 =>
      '\"A primeira app que não fala comigo como um médico ou a minha mãe.\"';

  @override
  String get obRatingCardTitle => 'Estás a gostar do Cirrus?';

  @override
  String get obRatingCardSubtitle =>
      'Toca numa estrela para avaliar na App Store.';

  @override
  String get obNotifTitle => 'Reforços, mesmo quando cedes.';

  @override
  String get obNotifSubtitle =>
      'Nada de spam. Um toque antes das tuas horas de perigo e outro em cada marco.';

  @override
  String get obNotifPreviewTime => 'Sex 21:54';

  @override
  String get obNotifPreviewBody =>
      'atenção — sexta à noite é o teu pico. O plano está pronto 💪';

  @override
  String get obNotifBullet1 => 'Aviso de horas de perigo (tu defines as horas)';

  @override
  String get obNotifBullet2 => 'Celebrações de sequências e marcos';

  @override
  String get obNotifBullet3 => 'Pings SOS do teu parceiro — mais nada';

  @override
  String get obNotifCta => 'Ativar reforços';

  @override
  String get paywallTitle => 'O teu plano está pronto.';

  @override
  String get paywallSubtitle => 'Experimenta tudo grátis durante 3 dias.';

  @override
  String get paywallFeatCoach => 'Coach IA sem limites';

  @override
  String get paywallFeatPanic => 'Botão de pânico + ping ao parceiro';

  @override
  String get paywallFeatPlan => 'Plano adaptativo';

  @override
  String get paywallFeatForecasts => 'Previsão de cravings';

  @override
  String get paywallFeatCommunity => 'Comunidade';

  @override
  String get paywallFeatReports => 'Relatórios semanais';

  @override
  String get paywallYearly => 'ANUAL';

  @override
  String get paywallYearlyBadge => 'MELHOR VALOR';

  @override
  String get paywallYearlySub => '0,77 \$/semana · POUPA 74%';

  @override
  String get paywallMonthly => 'MENSAL';

  @override
  String get paywallWeekly => 'SEMANAL';

  @override
  String get paywallWeeklySub => 'Preço fundador — fixo para sempre';

  @override
  String get paywallTrialReminder => '🔔 Avisamos-te antes de o teste acabar';

  @override
  String get paywallCancelAnytime => 'Cancela quando quiseres';

  @override
  String get paywallAnchor => 'Menos do que um descartável por semana';

  @override
  String get paywallCta => 'Começar os meus 3 dias grátis';

  @override
  String get paywallFreeLink => 'Continuar com o plano Grátis →';

  @override
  String get freePlanTitle => 'O Grátis já te põe em marcha.';

  @override
  String get freePlanSubtitle =>
      'Teu para sempre. Sem contagem decrescente, sem insistência.';

  @override
  String get freePlanFeat1 => 'Registo de passas + sequências';

  @override
  String get freePlanFeat2 => 'Contador de poupança';

  @override
  String get freePlanFeat3 => '5 mensagens de coach por dia';

  @override
  String get freePlanFeat4 => '1 sessão de Botão de pânico por dia';

  @override
  String get freePlanFeat5 => 'Comunidade (ler + reagir)';

  @override
  String get freePlanUpgradeNote =>
      'Faz upgrade quando quiseres — a sequência e o histórico vão contigo.';

  @override
  String get freePlanCta => 'Começar com o Grátis';

  @override
  String get winbackBadge => 'OFERTA FUNDADORA · SÓ UMA VEZ';

  @override
  String get winbackTitle => 'Ok — o primeiro mês por nossa conta. Quase.';

  @override
  String get winbackSubtitle =>
      'Já construíste o plano. Experimenta o kit completo um mês antes de decidir.';

  @override
  String get winbackFirstMonth => 'primeiro mês';

  @override
  String winbackNote(String price) {
    return 'Depois $price/mês. Cancela quando quiseres. Aparece uma vez, nunca mais.';
  }

  @override
  String get winbackCta => 'Garantir o mês fundador';

  @override
  String get winbackDecline => 'Não, obrigado — o Grátis chega-me';

  @override
  String get day1Title => 'Dia 1. Vamos a isto.';

  @override
  String get day1Subtitle =>
      'Três passos de arranque. Dois minutos. Depois a app faz o trabalho dela.';

  @override
  String get day1Task1 => 'Regista a tua primeira passa';

  @override
  String get day1Task1Done => 'feito — honestidade desde a primeira';

  @override
  String get day1Task1Sub => 'um toque honesto no botão grande';

  @override
  String get day1Task2 => 'Conhece o teu coach';

  @override
  String get day1Task2Sub => 'Olá de 30 seg. Já conhece os teus gatilhos.';

  @override
  String get day1Task3 => 'Define as tuas horas de perigo';

  @override
  String get day1Task3Sub => 'quando cedes? chegamos mais cedo';

  @override
  String day1FreedomNote(String date, int days) {
    return 'Dia da liberdade: $date · daqui a $days dias · plano armado';
  }

  @override
  String get day1CtaCoach => 'Conhecer o meu coach';

  @override
  String get day1CtaHome => 'Ir para Hoje';

  @override
  String homeGreetingDate(String date, int day, int total) {
    return '$date · Dia $day de $total';
  }

  @override
  String get homeTitle => 'Hoje';

  @override
  String homeStreakChip(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '🔥 $count dias',
      one: '🔥 $count dia',
    );
    return '$_temp0';
  }

  @override
  String get homePuffsToday => 'passas hoje';

  @override
  String homeOfLimit(int limit) {
    return 'de $limit';
  }

  @override
  String homeLeftAhead(int count) {
    return '$count abaixo da tua linha de hoje. Estás à frente da tua curva.';
  }

  @override
  String homeLeftTight(int count) {
    return 'Restam $count na linha de hoje. Apertado — tu consegues.';
  }

  @override
  String get homeOverLine =>
      'Acima da linha de hoje. Respira — amanhã ajusta-se.';

  @override
  String homeVsDay1(String percent) {
    return '$percent vs dia 1';
  }

  @override
  String get homeSavedSoFar => 'poupado até agora';

  @override
  String get homeCravingsBeaten => 'cravings vencidos';

  @override
  String homeCoachNudgeTitle(String weekday) {
    return '$weekday difícil? Reparei.';
  }

  @override
  String homeCoachNudgeBody(String hour) {
    return 'O teu pico das $hour está a chegar — queres um plano?';
  }

  @override
  String get homeLogPuff => 'REGISTAR PASSA';

  @override
  String get homeSos => 'SOS';

  @override
  String get homeVapeFreeTitle => 'Hoje sem passas?';

  @override
  String get homeVapeFreeCta => 'Confirmar dia sem vape ✓';

  @override
  String get homeVapeFreeDone =>
      'Dia sem vape garantido. É este o jogo todo. 🔥';

  @override
  String get homeLoggedSnack => '1 passa registada';

  @override
  String get homeLogPlusOne => '+1 registada';

  @override
  String homeLogRingNote(int count) {
    return 'o anel avança com um salto · restam $count hoje';
  }

  @override
  String get homeOverLimitTitle => 'Acima da tua linha';

  @override
  String get homeOverLimitBody =>
      'Respira — a linha de amanhã ajusta-se. Sem vergonha.';

  @override
  String get homeOverLimitBreathe => 'Respirar 60s';

  @override
  String get homeOverLimitCoach => 'Falar com o coach';

  @override
  String get homeOverLimitFooter =>
      'Continua a registar com honestidade — os dados são o jogo todo.';

  @override
  String get homeTokenUsedNote =>
      'Ficha de reparação usada — a tua sequência sobrevive. A chama esmorece hoje, não se apaga.';

  @override
  String get navHome => 'Início';

  @override
  String get navStats => 'Dados';

  @override
  String get navCommunity => 'Comunidade';

  @override
  String get navCoach => 'Coach';

  @override
  String panicStepLabel(int step) {
    return 'MODO PÂNICO · $step DE 3';
  }

  @override
  String get panicBreatheNote =>
      'esta sensação atinge o pico e passa — a maioria dos cravings morre em 15 min';

  @override
  String get panicBreatheIn => 'Inspira…';

  @override
  String get panicBreatheHold => 'Sustém…';

  @override
  String get panicBreatheOut => 'Expira…';

  @override
  String get panicBreathePattern => 'Inspira 4 · Sustém 7 · Expira 8';

  @override
  String panicCravingTimer(String time) {
    return 'cronómetro do craving · $time · pico ~15 min';
  }

  @override
  String panicCravingTimerLate(String time) {
    return 'cronómetro do craving · $time · já passaste o pior';
  }

  @override
  String get panicSkipToWhy => 'Ir para o meu porquê →';

  @override
  String get panicWhyTitle => 'Lembra-te porque começaste.';

  @override
  String get panicYouSaid => 'TU DISSESTE';

  @override
  String panicWhyLine(String why, String amount) {
    return 'Fazes isto pela tua $why e pelos $amount por ano que estás a recuperar.';
  }

  @override
  String get panicIntensityQuestion => 'Quão mau está agora?';

  @override
  String get panicIntensityLow => 'meh';

  @override
  String get panicIntensityHigh => 'aos gritos';

  @override
  String get panicStillCraving => 'Ainda com craving — seguinte';

  @override
  String get panicItPassed => 'Passou 🎉 estou bem';

  @override
  String get panicLoopTitle => 'Quebra o ciclo.';

  @override
  String get panicLoopSubtitle =>
      'As tuas mãos e a tua cabeça precisam de uma tarefa por 60 segundos. Escolhe uma.';

  @override
  String get panicLoopGame => 'Jogo de 60 segundos';

  @override
  String get panicLoopGameSub =>
      'ocupa exatamente essa comichão — polegares ocupados, cabeça ocupada';

  @override
  String get panicLoopBuddy => 'Mandar mensagem ao parceiro';

  @override
  String panicLoopBuddySub(String name) {
    return '$name recebe: \"craving — tira-me esta ideia\"';
  }

  @override
  String get panicLoopCoach => 'Falar com o coach';

  @override
  String panicLoopCoachSub(String hour) {
    return 'ele sabe que este é o teu padrão de stress das $hour';
  }

  @override
  String get panicLoopCoachLocked =>
      'já usaste a tua sessão de IA gratuita de hoje';

  @override
  String panicBuddyPinged(String name) {
    return 'Ping enviado. $name está contigo.';
  }

  @override
  String get gameTitle => 'Apanha cada faísca';

  @override
  String get gameSubtitle => '60 segundos. Polegares ocupados, cabeça ocupada.';

  @override
  String get gameScore => 'faíscas';

  @override
  String gameTimeLeft(int seconds) {
    return '${seconds}s';
  }

  @override
  String get gameDone => 'Tempo. Olha só — a onda quebrou.';

  @override
  String get survivedPlusOne => '+1 craving vencido';

  @override
  String get survivedLine1 => 'Esse não tinha hipótese contra ti.';

  @override
  String get survivedLine2 => 'A onda quebrou. Tu não.';

  @override
  String get survivedLine3 => '15 minutos de coragem. Guardados para sempre.';

  @override
  String get survivedLine4 => 'O teu cérebro acabou de aprender quem manda.';

  @override
  String get survivedLine5 => 'Craving 0 — tu 1. Outra vez.';

  @override
  String get survivedLine6 => 'Continuas livre. Continuas em frente.';

  @override
  String get survivedLine7 =>
      'Essa vontade acabou de pagar ao teu eu do futuro.';

  @override
  String get survivedLine8 => 'Sangue-frio. Do bom.';

  @override
  String get survivedTotalLabel => 'cravings superados no total';

  @override
  String get survivedShare => 'Partilhar a vitória ↗';

  @override
  String get survivedBack => 'Voltar a hoje';

  @override
  String get survivedShareCopied => 'Cartão copiado — cola-o onde quiseres.';

  @override
  String get coachName => 'Ember';

  @override
  String coachStatus(int day) {
    return '● conhece o teu plano · dia $day';
  }

  @override
  String get coachChipCraving => 'Estou com craving';

  @override
  String get coachChipRoughDay => 'Dia difícil';

  @override
  String get coachChipSlipped => 'Escorreguei';

  @override
  String get coachChipProgress => 'Mostra o meu progresso';

  @override
  String get coachInputHint => 'Escreve ao teu coach…';

  @override
  String get coachTyping => 'O Ember está a escrever…';

  @override
  String coachFreeCounter(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mensagens grátis hoje',
      one: '$count mensagem grátis hoje',
    );
    return '$_temp0';
  }

  @override
  String get coachCapReached =>
      'Foram as minhas 5 mensagens grátis de hoje — volto à meia-noite. Queres-me 24/7? É isso o Premium.';

  @override
  String get coachConnectionLost =>
      'A ligação caiu a meio da ideia 😅 Continuo aqui — repetes isso quando voltares a estar online?';

  @override
  String get errorOfflineBanner =>
      'offline — os registos contam, sincronizamos depois';

  @override
  String get errorOfflineTitle => 'Sem wifi, sem stress';

  @override
  String get errorOfflineBody =>
      'Estás offline agora. Nada se perde — volta a ligar-te e continuamos exatamente onde ficaste.';

  @override
  String get errorGenericTitle => 'Bem, isso falhou';

  @override
  String get errorGenericBody =>
      'A culpa é nossa, não tua. Tenta outra vez daqui a nada.';

  @override
  String get errorRetry => 'Tenta de novo';

  @override
  String get errorGotIt => 'Entendido';

  @override
  String get errorFeedTitle => 'O feed deixou-nos em visto';

  @override
  String get errorFeedBody =>
      'Não conseguimos chegar à comunidade. Vê a tua ligação e tenta de novo.';

  @override
  String get errorRouteTitle => 'Esta página não existe';

  @override
  String get errorRouteBody =>
      'O que procuravas não está aqui. Vamos voltar ao que interessa.';

  @override
  String get errorRouteCta => 'Leva-me para casa';

  @override
  String get errorBackstage =>
      'algo falhou nos bastidores — podes continuar à vontade';

  @override
  String get coachWeekCardLabel => 'A TUA SEMANA';

  @override
  String coachWeekCardCaption(String day) {
    return 'a descer — $day foi o dia difícil';
  }

  @override
  String coachGreeting(int puffs, String method, String date) {
    return 'Olá. Sou o Ember — larguei há dois anos e lembro-me exatamente de como se sente. Li o teu plano: $puffs por dia, $method, Dia da liberdade a $date. De mim nunca vêm sermões. O que se passa agora?';
  }

  @override
  String get coachReplyCraving1 =>
      'Essa onda é brutal, eu sei. Em 15 minutos quebra — não é discurso, é biologia. Água fria nos pulsos e fica comigo. O que a disparou?';

  @override
  String coachReplyCraving2(int count) {
    return 'Ok. Respira comigo uma ronda — inspira 4, sustém 7, expira 8. Os cravings morrem em 15–20 minutos. Já venceste $count. Este não é diferente.';
  }

  @override
  String get coachReplyCraving3 =>
      'Entendido. Não discutas com o craving, sobrevive-lhe. Anda um quarteirão ou abre o jogo de 60 segundos. Sobe e morre — 15 minutos no máximo.';

  @override
  String coachReplyRough1(int percent) {
    return 'Justo. Nos dias difíceis o velho hábito grita mais alto. Acordo: caminhada de 10 min antes da próxima. Se ainda a quiseres, regista com honestidade — continuas $percent% abaixo da tua base.';
  }

  @override
  String get coachReplyRough2 =>
      'Parece pesado. Não tens de resolver o dia de hoje, só de o atravessar — e consegues fazê-lo sem nicotina. Estou aqui na mesma.';

  @override
  String coachReplySlip1(int count) {
    return 'Um deslize é informação, não derrota. O que o disparou — stress, pessoas, tédio? O plano já se dobrou para te amparar. Os teus $count dias continuam a contar.';
  }

  @override
  String coachReplySlip2(String amount) {
    return 'Aqui não há vergonha. A maioria de quem larga de vez escorregou pelo caminho. Regista com honestidade, encontra o gatilho, segue. O teu registo continua teu: $amount poupados, melhor sequência intacta.';
  }

  @override
  String coachReplyProgress1(int day, String saved, int cravings) {
    return 'Olha para os números reais: dia $day, $saved de volta no teu bolso, $cravings cravings vencidos. O teu eu do dia 1 não aguentava o dia de hoje. Isto é real.';
  }

  @override
  String coachReplyProgress2(int today, int limit) {
    return '$today passas hoje contra uma linha de $limit. Há duas semanas esse número seria o dobro. Estás mesmo a conseguir.';
  }

  @override
  String get coachReplyGeneric1 =>
      'Estou a ouvir. Conta mais — o que está por baixo disso?';

  @override
  String coachReplyGeneric2(int day) {
    return 'Faz sentido. Só para constar: vais no dia $day e continuas aqui. Isso vale muito.';
  }

  @override
  String get coachReplyGeneric3 =>
      'Entendido. Uma pergunta honesta: isto é coisa de nicotina, ou é a vida com o casaco da nicotina vestido?';

  @override
  String get coachReplyGeneric4 =>
      'Ok. Isto ganha-se com pequenos passos. O que podes fazer nos próximos 10 minutos que não seja vapear?';

  @override
  String coachReplyParty(int count) {
    return 'Manual de festa: bebida fresca na mão a noite toda, escreve-me ou ao teu parceiro quando o primeiro vape aparecer, e prepara a tua frase de saída. Já sobreviveste a $count cravings — uma festa são só vários seguidos.';
  }

  @override
  String get coachSafetyNote =>
      'O Ember é uma ferramenta de apoio, não um médico. Em crise? Liga ou envia mensagem para o 988 (EUA e Canadá), a qualquer hora.';

  @override
  String get planTitle => 'O teu plano';

  @override
  String planHeaderMeta(String method, int days) {
    return '$method · $days dias';
  }

  @override
  String get planMethodTaper => 'Redução';

  @override
  String get planMethodCold => 'Corte total';

  @override
  String planTodayMarker(int limit) {
    return 'hoje · $limit/dia';
  }

  @override
  String planFreedomMarker(String date) {
    return '$date · 0';
  }

  @override
  String get planComingUp => 'A SEGUIR';

  @override
  String planHalfwayTitle(int day) {
    return 'Dia $day — meio caminho';
  }

  @override
  String planHalfwaySub(int limit) {
    return 'a linha desce para $limit/dia';
  }

  @override
  String planCravingsFadeTitle(int day) {
    return 'Dia $day — os cravings esmorecem';
  }

  @override
  String get planCravingsFadeSub => 'a maioria nota manhãs mais fáceis';

  @override
  String planFreedomTitle(int day) {
    return 'Dia $day — Dia da liberdade';
  }

  @override
  String get planAdjustCta => 'Ajustar o meu plano';

  @override
  String get planAdjustNote =>
      'ritmo + método editáveis · sem reset, sem histórico perdido';

  @override
  String get planAdaptiveLabel => 'AJUSTE DESTA NOITE';

  @override
  String planAdaptiveCrushing(int limit) {
    return 'Estás há três dias abaixo da tua linha, por isso o objetivo de hoje desce para $limit. Impulso, não castigo.';
  }

  @override
  String planAdaptiveOnTrack(int limit) {
    return 'Estás a segurar a linha. O objetivo de hoje mantém-se em $limit.';
  }

  @override
  String planAdaptiveStruggling(int limit) {
    return 'Os últimos dois dias passaram do limite, por isso o objetivo de hoje ajusta-se para $limit. Uma linha que consegues segurar vale mais do que uma que não consegues.';
  }

  @override
  String get planAdaptiveStretched =>
      'O Dia da Liberdade recuou um dia para acompanhar.';

  @override
  String get planAdjustSheetTitle => 'Ajusta o teu plano';

  @override
  String get planAdjustSheetNote =>
      'A curva regenera a partir de hoje com os teus números reais. O histórico fica. O Dia da liberdade move-se com honestidade.';

  @override
  String get planAdjustApply => 'Aplicar — recalcular a minha curva';

  @override
  String planAdjusted(String date) {
    return 'Plano recalculado. Novo Dia da liberdade: $date';
  }

  @override
  String get statsTitle => 'Dados';

  @override
  String get statsRangeDay => 'Dia';

  @override
  String get statsRangeWeek => 'Semana';

  @override
  String get statsRangeMonth => 'Mês';

  @override
  String get statsPuffsThisWeek => 'PASSAS ESTA SEMANA';

  @override
  String get statsPuffsToday => 'PASSAS HOJE · POR HORA';

  @override
  String get statsPuffsThisMonth => 'PASSAS · ÚLTIMOS 30 DIAS';

  @override
  String statsVsLast(String percent) {
    return '$percent vs anterior';
  }

  @override
  String statsHardDayCaption(String day, String reason) {
    return '$day foi o dia difícil — $reason. Recuperaste logo de manhã.';
  }

  @override
  String statsHardDayCaptionPlain(String day) {
    return '$day foi o dia difícil. Recuperaste logo de manhã.';
  }

  @override
  String get statsTriggerHours => 'HORAS GATILHO';

  @override
  String statsDangerWindow(String range) {
    return '$range é a tua janela de perigo · avisos armados aí';
  }

  @override
  String get statsNicotinePerDay => 'NICOTINA / DIA';

  @override
  String statsNicotineValue(int mg) {
    return '${mg}mg ↓';
  }

  @override
  String get statsLongestGap => 'maior intervalo';

  @override
  String get statsBestDay => 'melhor dia (passas)';

  @override
  String get statsCravingsBeaten => 'cravings vencidos';

  @override
  String get statsEmptyTitle => 'Os gráficos aparecem amanhã.';

  @override
  String get statsEmptyBody =>
      'Um dia de registos = um ponto. Continua — o desenho faz-se sozinho.';

  @override
  String statsEditDayTitle(String date) {
    return 'Editar $date';
  }

  @override
  String get statsEditDayNote =>
      'O histórico é teu. Sequência e dinheiro recalculam daqui para a frente.';

  @override
  String get statsEditHint => 'mantém premida uma barra para corrigir um dia';

  @override
  String get communityTitle => 'Comunidade';

  @override
  String communityYouAre(String alias) {
    return 'és $alias';
  }

  @override
  String get communityFilterAll => 'Tudo';

  @override
  String get communityTagWin => '🏆 Vitória';

  @override
  String get communityTagSos => '🆘 SOS';

  @override
  String get communityTagDay1 => 'Dia 1';

  @override
  String get communityTagMilestone => 'Marco';

  @override
  String get communityTagVent => 'Desabafo';

  @override
  String get communityIGotYou => 'Estou aqui 💬';

  @override
  String communityReplyingNow(int count) {
    return '$count a responder agora…';
  }

  @override
  String get communityReport => 'Denunciar';

  @override
  String get communityMute => 'Silenciar';

  @override
  String get communityBlock => 'Bloquear utilizador';

  @override
  String get communityReported =>
      'Denunciado. Revemos em 24h — 3 denúncias escondem o post.';

  @override
  String get communityBlocked => 'Bloqueado. Não se voltam a ver.';

  @override
  String get communityMuted => 'Silenciado. Não voltas a ver os posts dele.';

  @override
  String get communityAutoFlagged =>
      'Retido para revisão — marcas e onde-comprar não são permitidos aqui.';

  @override
  String get communityComposerTitle => 'Novo post';

  @override
  String get communityComposerPost => 'Publicar';

  @override
  String communityPostingAs(String alias, int day) {
    return 'a publicar como $alias · dia $day · sempre anónimo';
  }

  @override
  String get communityComposerHint => 'O que se passa no teu processo?';

  @override
  String get communityTagIt => 'ETIQUETA-O';

  @override
  String get communityKindnessNote =>
      'Sê gentil — aqui está toda a gente em plena luta. Sem marcas, sem onde-comprar.';

  @override
  String get communityTagRequired =>
      'Escolhe uma etiqueta — leva o teu post às pessoas certas.';

  @override
  String communitySosBanner(int count) {
    return '🛡️ $count pessoas estão contigo agora mesmo';
  }

  @override
  String get communityAddVoice => 'Junta a tua voz…';

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
    return 'dia $day';
  }

  @override
  String get communityEmptyTitle => 'Ainda não há posts — diz olá.';

  @override
  String get communityEmptyBody =>
      'O teu post do Dia 1 é o que alguém no Dia 0 precisa de ler.';

  @override
  String get communityPosted => 'Publicado. Alguém precisava de ler isso.';

  @override
  String get buddyTitle => 'O teu parceiro';

  @override
  String get buddyCombinedStreak => 'sequência combinada';

  @override
  String get buddyNeitherCaves => 'ninguém cede sozinho';

  @override
  String buddyNudge(String name) {
    return '👊 Animar $name';
  }

  @override
  String get buddyMessage => '💬 Mensagem';

  @override
  String buddyPrivacyNote(String name) {
    return '$name vê os teus pings SOS e recebe um toque se desapareceres 2 dias. Só isso — as tuas passas não são partilhadas salvo se quiseres.';
  }

  @override
  String get buddyPairsLabel => 'LARGAR A DOIS É MAIS FÁCIL';

  @override
  String get buddyInviteTitle => 'Convida outra pessoa';

  @override
  String get buddyCopyLink => 'Copiar link';

  @override
  String get buddyLinkCopied =>
      'Link copiado — largar com reforços é outra coisa.';

  @override
  String buddyNudged(String name) {
    return 'Incentivo enviado. $name vai senti-lo.';
  }

  @override
  String get buddyNudgeCap =>
      'Dois toques por dia mantêm a amizade. Mais amanhã.';

  @override
  String get moneyTitle => 'Dinheiro de volta';

  @override
  String moneySavedSince(String date, String perDay) {
    return 'poupado desde $date · $perDay a entrar todos os dias';
  }

  @override
  String get moneyBuysLabel => 'O QUE JÁ COMPRA';

  @override
  String moneyToGo(String amount, int days) {
    return 'faltam $amount · ~$days dias ao teu ritmo';
  }

  @override
  String moneyToGoShort(String amount) {
    return 'faltam $amount';
  }

  @override
  String moneyFromOnboarding(String amount) {
    return 'o do teu registo inicial · faltam $amount';
  }

  @override
  String get moneySetGoal => 'Cria uma meta';

  @override
  String get moneySetGoalSub =>
      'dá-lhe nome, dá-lhe preço, vê a barra a encher';

  @override
  String get moneyGoalSheetTitle => 'Nova meta de poupança';

  @override
  String get moneyGoalNameHint =>
      'Dá-lhe nome — \"PS5\", \"Lisboa\", \"bateria\"';

  @override
  String get moneyGoalPriceHint => 'Preço';

  @override
  String get moneyGoalCreate => 'Arrancar a barra';

  @override
  String moneyMathNote(String weekly, String yearly) {
    return 'As contas são tuas: $weekly/semana × 52 = $yearly/ano. Nada inventado.';
  }

  @override
  String get moneyGoalDone => 'Meta cumprida. Confetes merecidos. 🎉';

  @override
  String get seedGoalKicks => 'Ténis novos';

  @override
  String get seedGoalTokyo => 'Voo para Tóquio';

  @override
  String get healthTitle => 'O teu corpo a sarar';

  @override
  String healthAnchor(String ago) {
    return 'Com base na tua última passa registada · há $ago';
  }

  @override
  String healthYouAreHere(String milestone) {
    return '$milestone — estás aqui';
  }

  @override
  String get healthM20min => '20 minutos';

  @override
  String get healthM20minBody => 'O pulso e a tensão voltam ao normal.';

  @override
  String get healthM8h => '8 horas';

  @override
  String get healthM8hBody => 'O oxigénio normaliza enquanto a nicotina desce.';

  @override
  String get healthM12h => '12 horas';

  @override
  String get healthM12hBody =>
      'O monóxido de carbono no teu sangue cai para níveis normais.';

  @override
  String get healthM24h => '24 horas';

  @override
  String get healthM24hBody =>
      'A nicotina cai depressa. Os cravings gritam — é a porta de saída.';

  @override
  String get healthM48h => '48 horas';

  @override
  String get healthM48hBody =>
      'As terminações nervosas regeneram. Paladar e olfato afinam-se.';

  @override
  String get healthM72h => '72 horas';

  @override
  String get healthM72hBody =>
      'A nicotina quase desapareceu. Pico de cravings — o Botão de pânico vive para isto.';

  @override
  String get healthM1w => '1 semana';

  @override
  String get healthM1wBody =>
      'Paladar e olfato claramente mais finos. Respirar fica mais fácil.';

  @override
  String get healthM2w => '2 semanas';

  @override
  String get healthM2wBody =>
      'A circulação melhora. A função pulmonar começa a subir.';

  @override
  String get healthM1m => '1 mês';

  @override
  String get healthM1mBody => 'A tosse e a falta de ar aliviam.';

  @override
  String get healthM3m => '3 meses';

  @override
  String get healthM3mBody =>
      'A capacidade pulmonar continua a subir. O ginásio parece outro.';

  @override
  String get healthM6m => '6 meses';

  @override
  String get healthM6mBody =>
      'O teu nível base de stress desce — aguentas os dias maus sem isso.';

  @override
  String get healthM1y => '1 ano';

  @override
  String get healthM1yBody =>
      'O teu perfil de risco parece o de alguém que nunca vapeou diariamente.';

  @override
  String get healthUnlockNote =>
      'Cada desbloqueio traz uma pequena celebração + cartão para partilhar.';

  @override
  String get healthSourceNote =>
      'Baseado na investigação sobre deixar de fumar — a evidência sobre vaping ainda está a emergir.';

  @override
  String get milestonesTitle => 'Marcos';

  @override
  String milestonesEarned(int earned, int total) {
    return '$earned de $total ganhos';
  }

  @override
  String milestonesNext(String name) {
    return 'A seguir: $name';
  }

  @override
  String milestonesNextProgress(int day, int target) {
    return 'dia $day de $target · mais dois amanheceres';
  }

  @override
  String get milestonesNotLeaderboard =>
      'As medalhas são tuas, não um ranking. Não há grelha alheia para comparar.';

  @override
  String get mFirstLog => 'Primeiro registo';

  @override
  String get mFirstCraving => 'Primeiro craving vencido';

  @override
  String get mSpark => 'Faísca de 3 dias';

  @override
  String get mWeekFlame => 'Chama de 7 dias';

  @override
  String get mHundredSaved => '100 \$ poupados';

  @override
  String get mCleanWeekend => 'Fim de semana limpo';

  @override
  String get mHelpedSos => 'Ajudou num SOS';

  @override
  String get mTwoWeekFlame => 'Chama de duas semanas';

  @override
  String get mHalfNicotine => 'Metade da nicotina';

  @override
  String get mMoodWeek => 'Semana de humor';

  @override
  String get mTenCravings => '10 cravings vencidos';

  @override
  String get mQuarterCurve => 'Um quarto da curva';

  @override
  String get mInferno => 'Inferno de 30 dias';

  @override
  String get mFreedomDay => 'Dia da liberdade';

  @override
  String get mFirstPost => 'Primeiro post';

  @override
  String get mFiveHundredSaved => '500 \$ poupados';

  @override
  String get mBuddyBond => 'Laço de parceiros';

  @override
  String get mComeback => 'Regresso';

  @override
  String get moodTitle => 'Como está o dia de hoje?';

  @override
  String get moodSubtitle => '10 segundos. Importa mais do que pensas.';

  @override
  String get moodRough => 'duro';

  @override
  String get moodMeh => 'meh';

  @override
  String get moodOkay => 'ok';

  @override
  String get moodGood => 'bom';

  @override
  String get moodGreat => 'ótimo';

  @override
  String get moodNoteHint =>
      'Uma linha, opcional — \"festa do trabalho logo, nervoso\"';

  @override
  String get moodUnlockTitle => '🔓 Ligação humor ↔ craving';

  @override
  String moodUnlockProgress(int done, int total) {
    return '$done/$total check-ins';
  }

  @override
  String moodUnlockNote(int count) {
    return 'Mais $count e o teu relatório mostra como o humor dispara os teus cravings.';
  }

  @override
  String get moodCta => 'Registar';

  @override
  String get moodSaved => 'Anotado. Dados ganham a sensações. 🙌';

  @override
  String get insightLinkTitle => 'Relatório semanal';

  @override
  String insightTitle(int week, String range) {
    return 'Relatório da semana $week · $range';
  }

  @override
  String get insightWinLabel => 'A tua vitória';

  @override
  String get insightWatchoutLabel => 'Atenção';

  @override
  String get insightWeekChartLabel => 'PASSAS, ÚLTIMOS 7 DIAS';

  @override
  String get insightCravingsChartLabel => 'DESEJOS SUPERADOS, ÚLTIMOS 7 DIAS';

  @override
  String get insightHoursChartLabel => 'PASSAS POR HORA, ÚLTIMOS 14 DIAS';

  @override
  String insightCounter(int index, int total) {
    return 'INSIGHT $index DE $total';
  }

  @override
  String get insight1Headline =>
      'Vapeias 3× mais depois das 22h ao fim de semana.';

  @override
  String get insight1Body =>
      'As noites de sexta e sábado somam 41% das tuas passas semanais. É um gatilho social, não de nicotina — outro manual.';

  @override
  String get insight1ChartLabel => 'PASSAS POR HORA · FIM DE SEMANA';

  @override
  String get insight1Action =>
      'Sugestão do coach: agenda um aviso para sexta às 21:45 + mãos ocupadas na festa (jogo pronto).';

  @override
  String get insight2Headline => 'As tuas manhãs já são livres.';

  @override
  String get insight2Body =>
      'Zero passas registadas antes das 11h durante cinco dias seguidos. O relógio de nicotina que mandava no teu acordar? Partido.';

  @override
  String get insight2ChartLabel => 'PRIMEIRA PASSA DO DIA';

  @override
  String get insight2Action =>
      'Sugestão do coach: protege isso — vape fora do quarto e a primeira hora continua tua.';

  @override
  String get insight3Headline =>
      'Cravings vencidos: 9. Cravings que te venceram: 2.';

  @override
  String get insight3Body =>
      '82% de vitórias. As duas derrotas foram a menos de uma hora de uma refeição saltada — a fome veste o casaco da nicotina.';

  @override
  String get insight3ChartLabel => 'RESULTADO DOS CRAVINGS';

  @override
  String get insight3Action =>
      'Sugestão do coach: petisca antes da tua janela das 21h. Conselho aborrecido, diferença mensurável.';

  @override
  String get insight4Headline => 'Próxima semana: a curva do meio.';

  @override
  String get insight4Body =>
      'A tua linha desce para 100/dia na terça. Aqui a curva fica mais íngreme — é a semana em que o Botão de pânico ganha o ordenado.';

  @override
  String get insight4ChartLabel => 'A SEMANA QUE VEM';

  @override
  String get insight4Action =>
      'Sugestão do coach: marca algo de que gostes para sábado. Premeia a curva, não a atravesses só de dentes cerrados.';

  @override
  String get slipTitle => 'Um deslize é informação, não derrota.';

  @override
  String slipSubtitle(int days) {
    return 'Registaste passas após $days dias limpos. Isso é informação — diz-nos exatamente onde blindar o plano.';
  }

  @override
  String get slipWhatHappened => 'O QUE SE ESTAVA A PASSAR?';

  @override
  String get slipTriggerParty => 'Festa';

  @override
  String get slipTriggerStress => 'Stress';

  @override
  String get slipTriggerBoredom => 'Tédio';

  @override
  String get slipTriggerDrinking => 'Copos';

  @override
  String get slipTriggerFriends => 'Amigos tinham um';

  @override
  String get slipTriggerJustHappened => 'Simplesmente aconteceu';

  @override
  String get slipNoBannedWords =>
      'Aqui nunca há palavras proibidas. A maioria de quem larga de vez escorregou pelo caminho. O registo continua honesto, o plano adapta-se.';

  @override
  String get slipAdjustCta => 'Ajustar o meu plano';

  @override
  String get slipAdjustTitle => 'Eis o ajuste.';

  @override
  String get slipCurveLabel => 'A TUA CURVA — SUAVEMENTE RECALCULADA';

  @override
  String get slipTheBump => 'a bossa do deslize';

  @override
  String slipNewFreedom(String date, int days) {
    return 'Dia da liberdade: $date (+$days dias)';
  }

  @override
  String get slipCurveNote =>
      'Dois dias extra, mesmo destino. As noites de festa ganham aviso pré-armado + atalho para o jogo.';

  @override
  String slipStreakSurvives(int days) {
    return 'Os teus $days dias continuam a contar.';
  }

  @override
  String get slipFlameDims =>
      'A chama esmorece, não morre. Um dia limpo devolve-a à força total.';

  @override
  String get slipBackOnCurve => 'De volta à curva';

  @override
  String get slipTalkFirst => 'Falar primeiro com o coach';

  @override
  String profileQuittingSince(String date, String method, int day) {
    return 'a largar desde $date · $method · dia $day';
  }

  @override
  String get profileCountdownLabel => '🏆 CONTAGEM PARA O DIA DA LIBERDADE';

  @override
  String profileDaysTo(String date) {
    return 'dias até $date';
  }

  @override
  String get profileLifetimeSaved => 'poupança total';

  @override
  String get profilePuffsNotTaken => 'passas não dadas';

  @override
  String get profileBadgesEarned => 'medalhas ganhas';

  @override
  String get profileSettings => '⚙️ Definições';

  @override
  String get profileEditAlias => 'Escolhe o teu alias';

  @override
  String get profileEditAvatar => 'Escolhe o teu avatar';

  @override
  String get profileAliasHint => 'anónimo — é tudo o que veem';

  @override
  String get memoriesTitle => 'O que a Ember recorda';

  @override
  String get memoriesIntro =>
      'Coisas que contaste à Ember, guardadas para te serem úteis daqui a semanas em vez de recomeçar sempre. Só o que escreveste: nunca os teus números, nunca algo que não disseste.';

  @override
  String get memoriesEmpty =>
      'Ainda nada. A Ember começa a recordar quando lhe contas algo da tua vida.';

  @override
  String get memoriesFailed => 'Não foi possível carregar agora.';

  @override
  String get memoriesForget => 'Esquecer isto';

  @override
  String get memoriesForgotten => 'Esquecido. A Ember não volta a mencionar.';

  @override
  String get memoriesForgetFailed => 'Não foi aplicado — continua guardado.';

  @override
  String get memoriesKindPerson => 'Alguém na tua vida';

  @override
  String get memoriesKindTrigger => 'Um gatilho';

  @override
  String get memoriesKindMotivation => 'Porque fazes isto';

  @override
  String get memoriesKindMilestone => 'Algo que procuras';

  @override
  String get memoriesKindPreference => 'Como gostas que te falem';

  @override
  String get memoriesKindContext => 'Sobre ti';

  @override
  String get settingsMemories => 'O que a Ember recorda';

  @override
  String get moderationTitle => 'Fila de revisão';

  @override
  String get moderationEmpty =>
      'Nada à espera. Todos os alertas estão revistos.';

  @override
  String get moderationFailed => 'Não foi possível abrir a fila.';

  @override
  String get moderationRetry => 'Tentar de novo';

  @override
  String get moderationShowReviewed => 'Ver revistos';

  @override
  String moderationPendingCount(int count) {
    return '$count à espera';
  }

  @override
  String get moderationSubjectGone =>
      'A publicação já não existe; só resta o alerta.';

  @override
  String get moderationAllow => 'Permitir';

  @override
  String get moderationBlock => 'Bloquear';

  @override
  String get moderationDismiss => 'Está tudo bem';

  @override
  String get moderationResolveFailed =>
      'Não foi aplicado. A publicação continua igual.';

  @override
  String moderationFlaggedAs(String action, String reason) {
    return '$action · $reason';
  }

  @override
  String get settingsTitle => 'Definições';

  @override
  String get settingsAccount => 'Conta';

  @override
  String get settingsSubscription => 'Gerir subscrição';

  @override
  String get settingsSubscriptionValue => 'Premium · anual';

  @override
  String get settingsSubscriptionFree => 'Plano Grátis';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsDangerHours => 'Horas de perigo';

  @override
  String settingsDangerHoursEdit(String range) {
    return '$range · editar ›';
  }

  @override
  String get settingsPrivacy => 'Privacidade';

  @override
  String get settingsPrivacyNote =>
      'Nunca vendemos os teus dados. Zero rastreadores. Nunca.';

  @override
  String get settingsExportData => 'Exportar os meus dados';

  @override
  String get settingsDeleteEverything => 'Apagar tudo';

  @override
  String get settingsDeleteConfirmTitle => 'Apagar tudo?';

  @override
  String get settingsDeleteConfirmBody =>
      'O teu plano, registos, sequência e posts — desaparecem de vez. É o único botão que não conseguimos desfazer.';

  @override
  String get settingsDeleteConfirmCta => 'Sim, apagar tudo';

  @override
  String get settingsExported => 'Pacote de dados pronto — é teu, sempre foi.';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsAppearanceSystem => 'Como o sistema';

  @override
  String get settingsAppearanceMidnight => 'Midnight';

  @override
  String get settingsAppearanceDaylight => 'Daylight';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSystem => 'Como o sistema';

  @override
  String get settingsSupport => 'Suporte e FAQ';

  @override
  String get settingsRestorePurchases => 'Restaurar compras';

  @override
  String get settingsRestored => 'Compras restauradas — bem-vindo de volta.';

  @override
  String get settingsSignOut => 'Terminar sessão';

  @override
  String get settingsSignOutConfirmTitle => 'Terminar sessão?';

  @override
  String get settingsSignOutConfirmBody =>
      'Os teus dados ficam na tua conta. A sequência continua a arder.';

  @override
  String get settingsDangerHoursTitle => 'Horas de perigo';

  @override
  String get settingsDangerHoursNote =>
      'Avisamos-te 10 minutos antes de a tua janela abrir. Máximo 3 avisos por dia, horas de silêncio respeitadas.';

  @override
  String settingsQuietHours(String range) {
    return 'Horas de silêncio: $range';
  }

  @override
  String get trialEndingPushTime => 'agora';

  @override
  String get trialEndingPush =>
      'o teu teste acaba amanhã — como prometido, aqui está o aviso. Sem cobranças surpresa.';

  @override
  String get trialEndingTitle => 'O teste acaba amanhã.';

  @override
  String get trialEndingBody =>
      'Dissemos que te avisávamos, por isso: aqui está. Fica com o Premium ou passa ao Grátis — a sequência, o plano e o histórico ficam na mesma.';

  @override
  String get trialEndingStatsLabel => 'OS TEUS 3 DIAS ATÉ AGORA';

  @override
  String get trialEndingVsDay1 => 'passas vs dia 1';

  @override
  String get trialEndingCravings => 'cravings vencidos';

  @override
  String get trialEndingSaved => 'poupado';

  @override
  String trialEndingKeep(String price) {
    return 'Manter Premium — $price/ano';
  }

  @override
  String get trialEndingSwitchFree => 'Passar ao Grátis (os dados ficam)';

  @override
  String get frameMapTitle => 'Os 52 frames do design';

  @override
  String get frameMapOpen => 'Ver os 52 ecrãs →';

  @override
  String get frameMapNote =>
      'Cada frame dos quatro handoffs, a um toque. As linhas carregam a jornada demo ou as respostas do quiz quando preciso.';

  @override
  String get frameMapEdgeNote =>
      'Estes estados ativam-se com o backend — uma app em memória não tem offline nem erros de servidor para mostrar com honestidade.';

  @override
  String get seedPostWin30 =>
      'DIA DA LIBERDADE. 30 dias, zero passas na última semana. O botão de pânico levou-me pelos fins de semana. Se estás no dia 2 e a morrer — fica mesmo mais fácil perto do dia 8.';

  @override
  String get seedPostSos =>
      'à porta da bomba de gasolina. carteira na mão. alguém que me tire esta ideia';

  @override
  String get seedPostDay1 =>
      'atirei o meu ao lago. provavelmente mau para o lago. o dia 1 começa agora';

  @override
  String get seedPostVent =>
      'o meu colega sopra nuvens de manga na secretária O DIA TODO e eu devia… concentrar-me? a desabafar para não ceder';

  @override
  String get seedPostMilestone =>
      'duas semanas. hoje subi as escadas até ao 4.º sem soar a um acordeão assombrado. pequenas vitórias';

  @override
  String get seedPostWinParty =>
      'aguentei uma festa inteira sem pedir o vape a ninguém. as mãos sobreviveram agarradas a uma água com gás de lima como um esquisito';

  @override
  String get seedReplyWalk =>
      'anda. só um quarteirão. a carteira continua cheia, tu continuas livre. fiz exatamente isto na terça';

  @override
  String get seedReplyScience =>
      'o dia 4 é o pior, é ciência. estás no pico AGORA MESMO. 15 minutos e isto morre';

  @override
  String get seedReplyGatorade =>
      'compra antes um gatorade. compra cerimonial. funciona estranhamente bem';

  @override
  String get seedReplyUpdate =>
      'update: comprei o gatorade. a caminhar para casa. obrigado, a sério 💙';

  @override
  String get dangerReminderTitle => 'A tua hora crítica está a chegar';

  @override
  String get dangerReminderBody =>
      'É normalmente agora que aperta. Tens um plano, e 15 minutos chegam.';
}
