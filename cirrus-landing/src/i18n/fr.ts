// French — the app's own vocabulary, verbatim from app_fr.arb: `tu`, taffes,
// cravings, Jour de liberté, série, Mode panique, TAFFE +1, Orbes / Tuiles /
// Blocs, heures calmes, heures déclencheurs.
//
// PUNCTUATION SPACING. French sets a no-break space before ? ! : ; and inside
// « ». They are written as the \u00a0 escape so they are visible in review and
// cannot be "tidied" into ordinary spaces by an editor. NEVER U+202F (the narrow
// one): Space Grotesk has no glyph for it, so it renders as a box on the social
// cards that scripts/og.mjs draws.
//
// Drafted by Claude, spot-checked by the founder. See en.ts for the rules every
// locale follows; scripts/check-i18n.mjs enforces the mechanical ones.
import type { Dictionary } from './en.ts';

export const fr: Dictionary = {
  chrome: {
    skip: 'Aller au contenu',
    navLabel: 'Principal',
    breadcrumbLabel: "Fil d'Ariane",
    home: 'Accueil',
    blog: 'Blog',
    getApp: "Obtenir l'app",
    footerLine: "Créé par quelqu'un qui a arrêté. 17+ · la nicotine rend dépendant.",
    privacy: 'Confidentialité',
    terms: 'Conditions',
    deleteAccount: 'Supprimer le compte',
    rssTitle: 'Blog {site}',
    inEnglish: ' (en anglais)',
    language: 'Langue',
  },

  meta: {
    title: "L'app pour arrêter de vapoter sans tout couper d'un coup",
    tagline: "Arrête de vapoter sans tout couper d'un coup",
    description:
      "App gratuite pour arrêter de vapoter, iPhone et Android. Un appui par taffe, et ta limite du jour descend à zéro. Sans arrêt brutal ni retour au jour un.",
  },

  // Apple's and Google's own wording for their badges in French.
  stores: {
    appStore: "Télécharger dans l'App Store",
    googlePlay: 'Disponible sur Google Play',
  },

  home: {
    hero: {
      eyebrow: 'App gratuite pour arrêter de vapoter · iPhone et Android',
      h1: { pre: 'Arrête de vapoter sans ', accent: "tout couper d'un coup", post: '.' },
      sub: "Un appui enregistre chaque taffe. Ta limite du jour baisse un peu chaque jour jusqu'à zéro, et un mauvais jour ne te renvoie jamais au jour un.",
      trust: ["L'offre gratuite n'expire jamais", 'Marche avec toutes les vapes', 'Aucun traceur publicitaire'],
    },
    number: {
      eyebrow: 'En direct · sans inscription',
      h2: 'Combien la vape te coûte vraiment par an\u00a0?',
      sub: "Tape sur le clavier là-haut, puis indique ce que tu dépenses. C'est ton chiffre\u00a0: ça pique exactement autant que ça doit piquer.",
    },
    day: {
      eyebrow: 'Une journée type',
      h2: 'Arrêter avec Cirrus, heure par heure.',
      sub: "Jour 12 d'une diminution sur 30 jours. Les heures sont inventées\u00a0; chaque fonction de cette frise est dans l'app que tu télécharges aujourd'hui.",
      steps: {
        first: {
          title: 'La première de la journée',
          body: "Un appui sur TAFFE +1, ou sur le + du widget de ton écran d'accueil, sans ouvrir l'app. Un appui, c'est toujours exactement une taffe, avec cinq secondes pour annuler en cas d'erreur.",
          tag: 'Gratuit',
        },
        lunch: {
          title: 'Le déjeuner dérape',
          body: "Tu as dépassé la limite du jour. Pas de remise à zéro, pas de jour un. C'est un gel de série, mais mérité\u00a0: sept jours sous ta limite t'ont rapporté un jeton de réparation, qui absorbe aujourd'hui. La série s'atténue au lieu de mourir.",
          tag: 'Gratuit',
        },
        headsUp: {
          title: "Un rappel, dix minutes avant",
          body: "Ta carte des heures déclencheurs dit que 15\u00a0h est la plus dure, alors c'est l'heure que tu as choisie. Un seul rappel arrive juste avant, et jamais pendant tes heures calmes.",
          tag: 'Gratuit',
        },
        craving: {
          title: 'Le craving arrive quand même',
          body: "Appuie sur Panique. Un guide de respiration 4-7-8, la raison que tu as écrite le jour un, et un jeu pour tes pouces pendant que la vague culmine. Ça s'ouvre à chaque fois, avec toutes les offres, et la porte du coach à l'intérieur n'est jamais fermée.",
          tag: 'Gratuit',
        },
        passed: {
          title: "C'est passé",
          body: "La plupart des cravings sont finis en 15 à 20 minutes. Touche «\u00a0C'est passé\u00a0» et ça compte comme un craving vaincu.",
        },
        night: {
          title: "Impossible de dormir, envie d'une taffe",
          body: "Écris à Ember, le coach IA. Il connaît déjà ton jour de plan, ta limite, et il sait que les nuits sont ton point dur\u00a0: tu t'épargnes les explications. Ou publie un SOS dans la communauté anonyme\u00a0: il reste épinglé en haut du fil pendant une heure.",
          tag: 'Gratuit · 5 messages au coach par jour',
        },
        midnight: {
          title: 'La ligne de demain baisse un peu',
          body: "Sur une bonne série, le plan accélère. Deux jours difficiles d'affilée, et il ajoute de la marge et déplace le Jour de liberté au lieu de te préparer à échouer.",
          tag: 'Plan adaptatif · Premium',
        },
      },
    },
    screens: {
      eyebrow: "Dans l'app",
      h2: "Voici l'app que tu vas télécharger.",
      sub: 'Les mêmes écrans que sur la fiche du store.',
      count: '{n} écrans · fais défiler →',
      railLabel: "Captures d'écran de l'app",
      alts: {
        home: "Accueil\u00a0: ta dernière taffe, suivie. Les taffes du jour face à ta limite, l'argent économisé et les cravings vaincus.",
        log: "Enregistre une taffe d'un seul appui, avec les barres de la semaine et le widget de l'écran d'accueil.",
        plan: "Une diminution faite pour toi\u00a0: ta ligne quotidienne baisse un peu chaque jour jusqu'au Jour de liberté.",
        coach: 'Un coach qui te répond\u00a0: Ember connaît ton plan, tes habitudes et ton point faible.',
        panic: "Un craving\u00a0? Appuie sur Panique\u00a0: un exercice de respiration guidée qui dure plus longtemps que l'envie.",
        community: 'Arrête avec des gens qui comprennent\u00a0: le fil anonyme de la communauté.',
        stats: 'Regarde la nicotine partir\u00a0: milligrammes par jour, heures déclencheurs et étapes santé.',
      },
    },
    devices: {
      eyebrow: 'Un appui, partout',
      h2: 'Enregistre une taffe là où ça arrive.',
      items: {
        iphone: { name: 'iPhone', body: "Sur l'App Store. iOS 15 ou version ultérieure." },
        android: { name: 'Android', body: 'Sur Google Play.' },
        widget: { name: "Widget d'écran d'accueil", body: "Enregistre une taffe sans ouvrir l'app, sur iPhone et Android." },
        watch: { name: 'Apple Watch', body: 'Le compte du jour, ta limite et un + qui enregistre depuis ton poignet.' },
      },
    },
    plans: {
      eyebrow: 'Ce que ça coûte',
      h2: "L'offre gratuite n'est pas un essai. Elle n'expire pas.",
      sub: "Compter, ta limite et ta série, c'est le cœur de l'app\u00a0: c'est gratuit pour de bon. Premium, c'est pour quand tu veux plus d'aide.",
      premium: 'Premium',
      perWeek: 'par semaine',
      perMonth: 'par mois',
      perYear: 'par an',
      note: {
        bold: 'Essai gratuit de 7 jours sur toutes les offres.',
        rest: "Prix américains\u00a0; ton store affiche les tiens. Facturation et annulation via l'App Store ou Google Play.",
      },
      tableLabel: 'Gratuit et Premium comparés',
      colFeature: 'Fonction',
      colFree: 'Gratuit',
      colPremium: 'Premium',
      included: 'Inclus',
      notIncluded: 'Non inclus',
      rows: {
        counter: { feature: "Compteur de taffes, widget, modification de n'importe quel jour" },
        limit: { feature: "Limite quotidienne qui baisse jusqu'au Jour de liberté" },
        streak: { feature: 'Série avec jetons de réparation' },
        money: { feature: "Argent économisé et objectifs d'épargne" },
        panic: { feature: 'Bouton Panique', free: "S'ouvre toujours · jeu Orbes", pro: 'Plus Tuiles et Blocs' },
        coach: { feature: 'Ember, le coach IA', free: '5 messages par jour', pro: "Jusqu'à 100 par jour" },
        community: { feature: 'Communauté anonyme', free: '1 publication par jour, plus les SOS', pro: '3 publications par jour, plus les SOS' },
        timeline: { feature: 'Frise santé', free: 'Les 4 premières étapes, et celles que tu atteins', pro: 'En entier' },
        history: { feature: 'Historique des stats', free: '7 jours', pro: '30 jours, vue mensuelle, prévisions de cravings' },
        adaptive: { feature: 'Plan qui se réajuste chaque nuit' },
        insight: { feature: "Rapport d'insights hebdomadaire" },
        themes: { feature: 'Thèmes Hearth et Tide' },
      },
    },
    stats: {
      eyebrow: 'Ça te parle\u00a0?',
      h2: "Ça fait longtemps que ce n'est plus un choix.",
      sub: "Sous la douche. Dans la voiture. Dès le réveil. Une vape n'a pas de paquet à finir, alors elle ne te donne jamais de moment pour t'arrêter. Ce n'est pas un défaut de caractère. C'est la nicotine.",
      hooks: {
        wake30: 'Elle est dans ta main avant même que tu te lèves.',
        failedAttempts: "Tu as déjà arrêté. Ça n'a pas tenu.",
        cravingWindow: "Le craving semble sans fin. Il ne l'est pas.",
      },
      note: "Chaque chiffre de cette page a une source. D'autres apps affichent «\u00a078\u00a0% des membres arrêtent\u00a0», sans citer personne.",
    },
    faq: {
      eyebrow: 'Des réponses franches',
      h2: 'Les questions que les gens se posent vraiment pour arrêter de vapoter',
    },
    closing: {
      eyebrow: 'Téléchargement gratuit',
      h2: 'Ta dernière taffe est plus proche que tu ne le crois.',
      sub: 'Compte ton vrai chiffre ce soir. Le plan part de là, au rythme que tu choisis.',
      qrLabel: 'Code QR vers cirrusquit.com/download',
      qrTitle: 'Sur un ordinateur\u00a0?',
      qrBody: "Scanne-le avec l'appareil photo de ton téléphone pour avoir la bonne version.",
    },
  },

  // Sources keep their published names: a reader has to be able to find them.
  stats: {
    abstinence: {
      figure: '24\u00a0% contre 19\u00a0%',
      claim: "d'abstinence dans un essai randomisé sur 2\u00a0588 jeunes adultes — l'aide à l'arrêt fonctionne, mais personne n'arrête neuf fois sur dix.",
      source: 'This is Quitting RCT, Truth Initiative / JMIR',
    },
    wake30: {
      figure: '76\u00a0%',
      claim: "des jeunes vapoteurs s'y mettent dans les 30 minutes après le réveil. Si c'est ton cas, c'est un schéma de dépendance, pas un problème de volonté.",
      source: 'Enquête Truth Initiative auprès des ados vapoteurs',
    },
    failedAttempts: {
      figure: '28\u00a0% → 53\u00a0%',
      claim: "la hausse des tentatives d'arrêt ratées chez les jeunes qui vapotent tous les jours, entre 2020 et 2024. Arrêter est devenu plus dur\u00a0; ce n'est pas toi qui as faibli.",
      source: 'JAMA Network Open',
    },
    cravingWindow: {
      figure: '15–20 min',
      claim: "la durée réelle de la plupart des cravings. C'est toute la fenêtre que le Mode panique doit t'aider à traverser.",
      source: 'Littérature sur le craving de nicotine',
    },
    puffsPerCig: {
      figure: '≈14 taffes',
      claim: "à peu près une cigarette. Toujours affiché avec un «\u00a0≈\u00a0», parce que la réponse honnête est une fourchette, et que celui qui donne un chiffre précis devine.",
      source: 'Heuristique de recherche',
    },
  },

  faq: {
    taper: {
      q: "Diminuer progressivement, c'est mieux qu'arrêter de vapoter d'un coup\u00a0?",
      a: "Arrêter d'un coup marche pour certains et échoue pour la plupart. Une diminution fait baisser ta nicotine assez lentement pour que le manque reste gérable\u00a0: c'est pour ça que Cirrus compte des taffes qui descendent plutôt que des jours qui montent. Si arrêter d'un coup a déjà marché pour toi, tu n'as pas besoin d'une app.",
    },
    autoCount: {
      q: 'Est-ce que Cirrus compte les taffes automatiquement\u00a0?',
      a: "Non. Cirrus ne peut pas voir ta vape, donc tu appuies une fois par taffe\u00a0: dans l'app, sur le widget de l'écran d'accueil ou sur ton Apple Watch. C'est aussi pour ça que ça marche avec n'importe quelle vape, jetables compris. Ce qui compte, c'est ce à quoi on compare le total\u00a0: la recherche sur l'auto-observation montre qu'elle aide le plus quand chaque fois est notée, comparée à un objectif et renvoyée tout de suite, et un appui face à la limite du jour fait les trois.",
    },
    puffsPerDay: {
      q: "Combien de taffes par jour, c'est beaucoup\u00a0?",
      a: "Il n'y a pas de limite nette, et aucune autorité de santé n'en publie. Environ 14 taffes font à peu près une cigarette, donc 150 par jour, c'est de l'ordre de dix.",
    },
    disposable: {
      q: 'Combien de taffes dans une puff jetable\u00a0?',
      a: "Moins que ce que dit la boîte. Les chiffres annoncés viennent d'une machine qui tire des taffes courtes et régulières\u00a0: en usage réel, on tombe souvent bien en dessous du nombre affiché.",
    },
    costPerYear: {
      q: 'Combien coûte vraiment la vape par an\u00a0?',
      a: "Prends ce que tu dépenses par semaine et multiplie par 52. À £20 ou $20 par semaine, ça fait plus de mille par an. Utilise le calculateur plus haut avec ton propre chiffre\u00a0; on ne va pas en inventer un pour toi.",
    },
    slip: {
      q: 'Que se passe-t-il si je craque et que je dépasse ma limite\u00a0?',
      a: "Rien de dramatique. Un jeton de réparation absorbe un jour au-dessus de la limite\u00a0: ta série s'atténue au lieu de mourir, et le plan repousse ton Jour de liberté plutôt que de te renvoyer au jour un. Un écart, c'est une donnée, pas un échec.",
    },
    withdrawal: {
      q: 'Combien de temps dure le sevrage de la vape\u00a0?',
      a: "Les symptômes commencent en général dans la journée et culminent le deuxième ou le troisième jour, plus tôt que ce que la plupart des gens imaginent. L'essentiel du côté physique se calme en une dizaine de jours.",
    },
    benefits: {
      q: "Quels sont les bénéfices de l'arrêt de la vape\u00a0?",
      a: "Le sommeil et le goût reviennent en général les premiers, souvent en deux semaines environ. Le souffle et l'endurance suivent. L'argent, lui, est immédiat et souvent ce qui motive le plus\u00a0: ce que tu dépenses par semaine, multiplie-le par 52. On ne te citera pas un pourcentage qu'on ne peut pas sourcer.",
    },
    methods: {
      q: 'Quelles méthodes pour arrêter de vapoter marchent vraiment\u00a0?',
      a: "En gros, trois\u00a0: l'arrêt d'un coup, la diminution progressive et les substituts nicotiniques. L'arrêt d'un coup est le plus rapide et celui qui réussit le moins. La diminution échange de la vitesse contre bien plus de chances que ça tienne. Les substituts peuvent soutenir l'un ou l'autre. Cirrus est une app de diminution parce que c'est la méthode que la plupart des gens arrivent à tenir.",
    },
    platforms: {
      q: 'Cirrus est-il sur iPhone et Android\u00a0?',
      a: "Oui, les deux. Cirrus est gratuit sur l'App Store pour iPhone (iOS 15 ou version ultérieure) et sur Google Play pour Android, et la version iPhone inclut une app Apple Watch.",
    },
    free: {
      q: 'Cirrus est-il gratuit\u00a0?',
      a: "Oui. L'offre gratuite fonctionne pour toujours\u00a0: enregistrement des taffes, le widget, les séries, l'argent économisé, ta limite quotidienne, la communauté et cinq messages au coach par jour. Premium ajoute le plan adaptatif, jusqu'à 100 messages au coach par jour et ton historique complet, à 2,99\u00a0$ par semaine, 7,99\u00a0$ par mois ou 39,99\u00a0$ par an aux États-Unis, avec un essai gratuit de 7 jours sur toutes les offres. On ne vend jamais tes données et l'app ne contient aucun traceur publicitaire.",
    },
    puffCount: {
      q: 'Quelle différence avec Puff Count\u00a0?',
      a: "Les deux sont des compteurs de taffes où tu appuies toi-même, et les deux te fixent une limite du jour. Les différences\u00a0: notre offre gratuite ne se bloque jamais, il y a un coach IA et une communauté anonyme, et chaque statistique qu'on affiche a une source. Cirrus est aussi sur iPhone et sur Android\u00a0; Puff Count n'existe que sur les appareils Apple, sans version Android en septembre 2026.",
    },
  },
  faqMore: {
    puffsPerDay: "La réponse complète, et la question qui t'en dit plus",
    disposable: 'Pourquoi le chiffre sur la boîte est optimiste',
    withdrawal: 'La chronologie jour par jour',
    puffCount: 'Que chercher dans une app de comptage de taffes',
  },

  // askPuffs, the bands, equiv*, toDevices and cta are the app's own strings
  // (obPuffs* and commonContinue in app_fr.arb).
  demo: {
    askPuffs: 'Des taffes, un jour normal\u00a0?',
    askDevices: 'Des puffs jetables par semaine\u00a0?',
    increase: 'Augmenter',
    decrease: 'Diminuer',
    del: 'Effacer',
    padLabel: 'Pavé numérique',
    equivPre: '≈ ',
    equivPost: ' cigarettes en taffes',
    toDevices: "Pas sûr\u00a0? Estime via l'appareil →",
    toPuffs: '← Je connais mon nombre de taffes',
    cta: 'Continuer',
    outEyebrow: 'Et voilà ce que ça veut dire',
    spendLabel: 'Si tu dépenses',
    perWeek: 'par semaine',
    yearNote: 'par an que tu gardes en arrêtant. Tes calculs, pas les nôtres',
    startSuffix: ' par jour',
    freedom: '0 · Jour de liberté',
    curveLabel: 'Ta courbe de diminution qui tombe à zéro en 30 jours.',
    curveCaption: 'Ta courbe sur 30 jours · redessinée pendant que tu tapes',
    bandEmpty: 'Allez, sois honnête',
    bandLight: 'Habitude légère',
    bandModerate: 'Dépendance modérée',
    bandHeavy: 'Dépendance forte',
    bandSevere: 'Dépendance sévère',
    quipEmpty: "Personne ne regarde. On ne peut pas faire de calcul sur une case vide.",
    quipLight: 'Franchement, tu y es presque. Ça ira plus vite que tu ne le penses.',
    quipModerate: 'Un paquet par jour, déguisé en vape. Très réparable.',
    quipHeavy: "Gros chiffre. Et très courant aussi\u00a0: tu n'es pas un cas à part.",
    quipSevere: "Ça fait beaucoup de nicotine. Pas de leçon\u00a0: juste un plan qui part de là où tu es.",
  },

  download: {
    title: "Télécharger l'app pour arrêter de vapoter, iPhone et Android",
    description:
      "Télécharge Cirrus, l'app gratuite pour arrêter de vapoter\u00a0: un appui par taffe, et ta limite du jour descend à zéro. Sur l'App Store (iPhone) et Google Play.",
    crumb: "Obtenir l'app",
    h1: 'Télécharger {site}',
    lede: "Une app pour arrêter de vapoter, avec un compteur de taffes en un appui et une limite du jour qui descend jusqu'à zéro. Un mauvais jour ne te renvoie jamais au jour un.",
    whichH2: 'Quel téléphone',
    whichBody:
      "Les deux. Cirrus est sur l'App Store pour iPhone (iOS 15 ou version ultérieure), avec une app Apple Watch incluse, et sur Google Play pour Android. Le widget d'écran d'accueil fonctionne sur les deux.",
    whatH2: 'Ce que tu obtiens',
    whatBody:
      "L'offre gratuite fonctionne pour toujours\u00a0: enregistrement des taffes, le widget, les séries, l'argent économisé, ta limite quotidienne, la communauté et cinq messages au coach par jour. Premium ajoute le plan adaptatif, jusqu'à 100 messages au coach par jour et ton historique complet, avec un essai gratuit de 7 jours sur toutes les offres. Aucun blocage, on ne vend jamais tes données, et l'app ne contient aucun traceur publicitaire — on a retiré l'identifiant publicitaire plutôt que de le désactiver.",
    unsure: {
      pre: 'Tu hésites encore\u00a0? ',
      link: "Regarde ce qu'une année de vape te coûte",
      post: " — ça prend une dizaine de secondes, sans inscription.",
    },
  },

  notFound: {
    title: 'Page introuvable',
    description: "Cette page n'existe pas.",
    h1: '404',
    lede: "Cette page n'existe pas.",
    home: "Retour à l'accueil",
    getApp: "Obtenir l'app",
    blog: 'Lire le blog',
  },
};
