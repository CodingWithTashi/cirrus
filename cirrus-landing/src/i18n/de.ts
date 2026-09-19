// German — the app's own vocabulary, verbatim from app_de.arb: `du`, Züge,
// Cravings, Freiheitstag, Serie, Panik-Modus, ZUG LOGGEN, Kugeln / Kacheln /
// Blöcke, Ruhezeiten, Trigger-Stunden.
//
// German runs long, and the layout was written for English. Two things keep it
// inside: the header button is "App holen" (the shortest honest wording — it has
// to share a 320px header with the brand and "Blog"), and global.css turns on
// `hyphens: auto` for :lang(de), so a compound breaks at a syllable instead of
// overflowing a card. Do not add soft hyphens (&shy;) to a string: several of
// these also feed <title>, og tags and JSON-LD, where one would be visible junk.
//
// A no-break space (written as the \u00a0 escape, so it is visible in review)
// sits between a number and its % or $, so a line can never end on "24" and
// start the next with "%".
//
// Drafted by Claude, spot-checked by the founder. See en.ts for the rules every
// locale follows; scripts/check-i18n.mjs enforces the mechanical ones.
import type { Dictionary } from './en.ts';

export const de: Dictionary = {
  chrome: {
    skip: 'Zum Inhalt springen',
    navLabel: 'Hauptnavigation',
    breadcrumbLabel: 'Brotkrümelnavigation',
    home: 'Start',
    blog: 'Blog',
    getApp: 'App holen',
    footerLine: 'Gebaut von jemandem, der aufgehört hat. 17+ · Nikotin macht abhängig.',
    privacy: 'Datenschutz',
    terms: 'Nutzungsbedingungen',
    deleteAccount: 'Konto löschen',
    rssTitle: '{site}-Blog',
    inEnglish: ' (auf Englisch)',
    language: 'Sprache',
  },

  meta: {
    title: 'App zum Aufhören mit dem Vapen – ohne kalten Entzug',
    tagline: 'Mit dem Vapen aufhören – ohne kalten Entzug',
    description:
      'Gratis-App zum Aufhören mit dem Vapen – iPhone und Android. Einmal tippen pro Zug, dein Limit sinkt auf null. Kein kalter Entzug, kein Zurück auf Tag eins.',
  },

  // Apple's and Google's own wording for their badges in German.
  stores: {
    appStore: 'Laden im App Store',
    googlePlay: 'Jetzt bei Google Play',
  },

  home: {
    hero: {
      eyebrow: 'Kostenlose App gegen das Vapen · iPhone und Android',
      h1: { pre: 'Mit dem Vapen aufhören – ohne ', accent: 'kalten Entzug', post: '.' },
      sub: 'Einmal tippen erfasst jeden Zug. Dein Tageslimit sinkt jeden Tag ein Stück, bis es bei null ist – und ein schlechter Tag wirft dich nie auf Tag eins zurück.',
      trust: ['Die Gratis-Version läuft nie ab', 'Funktioniert mit jeder Vape', 'Keine Werbe-Tracker'],
    },
    number: {
      eyebrow: 'Live · ohne Anmeldung',
      h2: 'Was kostet dich das Vapen wirklich im Jahr?',
      sub: 'Tipp oben auf die Tastatur und gib ein, was du ausgibst. Es ist deine Zahl – also tut sie genau so weh, wie sie soll.',
    },
    day: {
      eyebrow: 'Ein Beispieltag',
      h2: 'So sieht Aufhören mit Cirrus aus, Stunde für Stunde.',
      sub: 'Tag 12 eines 30-Tage-Plans. Die Uhrzeiten sind ausgedacht; jede Funktion auf dieser Leiste steckt in der App, die du heute lädst.',
      steps: {
        first: {
          title: 'Der erste des Tages',
          body: 'Ein Tipp auf ZUG LOGGEN, oder auf das + im Widget auf deinem Homescreen, ohne die App zu öffnen. Ein Tipp ist immer genau ein Zug, mit fünf Sekunden zum Rückgängigmachen, falls du dich vertippst.',
          tag: 'Kostenlos',
        },
        lunch: {
          title: 'Die Mittagspause läuft aus dem Ruder',
          body: 'Du liegst über dem Limit von heute. Kein Reset, kein Tag eins. Wie ein Serienschutz, nur eben verdient: Sieben Tage unter deinem Limit haben dir einen Reparatur-Token gebracht, der den heutigen Tag abfängt – die Serie wird blasser, statt zu sterben.',
          tag: 'Kostenlos',
        },
        headsUp: {
          title: 'Eine Vorwarnung, zehn Minuten früher',
          body: 'Deine Karte der Trigger-Stunden sagt: 15 Uhr ist die schwere – also hast du genau diese Stunde gewählt. Ein einziger Hinweis kommt kurz davor, und nie während deiner Ruhezeiten.',
          tag: 'Kostenlos',
        },
        craving: {
          title: 'Das Craving kommt trotzdem',
          body: 'Drück auf Panik. Ein Atem-Taktgeber im 4-7-8-Rhythmus, der Grund, den du an Tag eins aufgeschrieben hast, und ein Spiel für deine Daumen, während die Welle ihren Höhepunkt hat. Er öffnet sich jedes Mal, in jedem Tarif, und die Tür zum Coach darin ist nie verschlossen.',
          tag: 'Kostenlos',
        },
        passed: {
          title: 'Vorbei',
          body: 'Die meisten Cravings sind nach 15 bis 20 Minuten vorüber. Tipp auf „Vorbei“, und es zählt als eines, das du besiegt hast.',
        },
        night: {
          title: 'Kannst nicht schlafen, willst einen Zug',
          body: 'Schreib Ember, dem KI-Coach. Er kennt deinen Plan-Tag und dein Limit schon und weiß, dass die Nächte dein schwerer Teil sind – das Erklären kannst du dir sparen. Oder poste ein SOS in der anonymen Community; es bleibt eine Stunde lang oben im Feed angepinnt.',
          tag: 'Kostenlos · 5 Coach-Nachrichten am Tag',
        },
        midnight: {
          title: 'Die Linie von morgen sinkt ein Stück',
          body: 'Läuft es gut, zieht der Plan an. Nach zwei harten Tagen in Folge gibt er dir mehr Luft und verschiebt den Freiheitstag, statt dich aufs Scheitern vorzubereiten.',
          tag: 'Adaptiver Plan · Premium',
        },
      },
    },
    screens: {
      eyebrow: 'In der App',
      h2: 'Das ist die App, die du lädst.',
      sub: 'Dieselben Screens wie im Store-Eintrag.',
      count: '{n} Screens · wischen →',
      railLabel: 'Screenshots der App',
      alts: {
        home: 'Start: dein letzter Zug, erfasst. Die Züge von heute gegen dein Limit, gespartes Geld und besiegte Cravings.',
        log: 'Einen Zug mit einem Tipp loggen, mit den Balken dieser Woche und dem Homescreen-Widget.',
        plan: 'Ein Plan, der für dich gebaut ist: Deine Tageslinie sinkt jeden Tag ein Stück bis zum Freiheitstag.',
        coach: 'Ein Coach, der zurückschreibt: Ember kennt deinen Plan, deine Muster und deine Schwachstelle.',
        panic: 'Craving? Drück auf Panik: eine geführte Atemübung, die länger durchhält als das Verlangen.',
        community: 'Hör mit Leuten auf, die es verstehen: der anonyme Community-Feed.',
        stats: 'Sieh dem Nikotin beim Verschwinden zu: Milligramm pro Tag, Trigger-Stunden und Gesundheits-Meilensteine.',
      },
    },
    devices: {
      eyebrow: 'Einmal tippen, überall',
      h2: 'Erfass einen Zug, wo immer er passiert.',
      items: {
        iphone: { name: 'iPhone', body: 'Im App Store. iOS 15 oder neuer.' },
        android: { name: 'Android', body: 'Bei Google Play.' },
        widget: { name: 'Homescreen-Widget', body: 'Einen Zug loggen, ohne die App zu öffnen – auf iPhone und Android.' },
        watch: { name: 'Apple Watch', body: 'Der Stand von heute, dein Limit und ein +, das vom Handgelenk aus loggt.' },
      },
    },
    plans: {
      eyebrow: 'Was es kostet',
      h2: 'Die Gratis-Version ist keine Testphase. Sie läuft nicht ab.',
      sub: 'Zählen, dein Limit und deine Serie sind der Kern – deshalb bleiben sie dauerhaft kostenlos. Premium ist für den Moment, in dem du mehr Hilfe willst.',
      premium: 'Premium',
      perWeek: 'pro Woche',
      perMonth: 'pro Monat',
      perYear: 'pro Jahr',
      note: {
        bold: '7 Tage kostenlos testen, in jedem Tarif.',
        rest: 'US-Preise; dein Store zeigt dir deine. Abrechnung und Kündigung laufen über den App Store oder Google Play.',
      },
      tableLabel: 'Kostenlos und Premium im Vergleich',
      colFeature: 'Funktion',
      colFree: 'Kostenlos',
      colPremium: 'Premium',
      included: 'Enthalten',
      notIncluded: 'Nicht enthalten',
      rows: {
        counter: { feature: 'Zug-Zähler, Widget, jeden Tag bearbeiten' },
        limit: { feature: 'Tageslimit, das bis zum Freiheitstag sinkt' },
        streak: { feature: 'Serie mit Reparatur-Tokens' },
        money: { feature: 'Gespartes Geld und Sparziele' },
        panic: { feature: 'Panik-Button', free: 'Öffnet immer · Spiel Kugeln', pro: 'Plus Kacheln und Blöcke' },
        coach: { feature: 'Ember, der KI-Coach', free: '5 Nachrichten am Tag', pro: 'Bis zu 100 am Tag' },
        community: { feature: 'Anonyme Community', free: '1 Beitrag am Tag, plus SOS', pro: '3 Beiträge am Tag, plus SOS' },
        timeline: { feature: 'Gesundheits-Zeitstrahl', free: 'Die ersten 4 Meilensteine und alle, die du erreichst', pro: 'Komplett' },
        history: { feature: 'Statistik-Verlauf', free: '7 Tage', pro: '30 Tage, Monatsansicht, Craving-Prognosen' },
        adaptive: { feature: 'Plan, der sich jede Nacht neu anpasst' },
        insight: { feature: 'Wöchentlicher Insight-Bericht' },
        themes: { feature: 'Themes Hearth und Tide' },
      },
    },
    stats: {
      eyebrow: 'Kommt dir bekannt vor?',
      h2: 'Eine Entscheidung ist das schon lange nicht mehr.',
      sub: 'Unter der Dusche. Im Auto. Direkt nach dem Aufwachen. Eine Vape hat keine Schachtel, die leer wird – also gibt sie dir nie einen Punkt zum Aufhören. Das ist keine Charakterschwäche. Das ist Nikotin.',
      hooks: {
        wake30: 'Sie ist in deiner Hand, bevor du aus dem Bett bist.',
        failedAttempts: 'Du hast schon mal aufgehört. Bis mittags.',
        cravingWindow: 'Das Craving fühlt sich endlos an. Ist es nicht.',
      },
      note: 'Jede Zahl auf dieser Seite hat eine Quelle. Andere Apps schreiben „78\u00a0% der Mitglieder hören auf“ – und zitieren niemanden.',
    },
    faq: {
      eyebrow: 'Klare Antworten',
      h2: 'Fragen zum Aufhören mit dem Vapen, die Leute wirklich stellen',
    },
    closing: {
      eyebrow: 'Kostenlos laden',
      h2: 'Dein letzter Zug ist näher, als du denkst.',
      sub: 'Zähl heute Abend deine echte Zahl. Von da aus startet der Plan – in dem Tempo, das du wählst.',
      qrLabel: 'QR-Code für cirrusquit.com/download',
      qrTitle: 'Am Computer?',
      qrBody: 'Scann ihn mit der Kamera deines Handys, dann bekommst du die richtige Version.',
    },
  },

  // Sources keep their published names: a reader has to be able to find them.
  stats: {
    abstinence: {
      figure: '24\u00a0% vs. 19\u00a0%',
      claim: 'Abstinenz in einer randomisierten Studie mit 2.588 jungen Erwachsenen – Unterstützung beim Aufhören wirkt, aber niemand schafft es in neun von zehn Fällen.',
      source: 'This is Quitting RCT, Truth Initiative / JMIR',
    },
    wake30: {
      figure: '76\u00a0%',
      claim: 'der jungen Vaper greifen innerhalb von 30 Minuten nach dem Aufwachen danach. Wenn das auf dich zutrifft, ist es ein Abhängigkeitsmuster, kein Problem mit deiner Willenskraft.',
      source: 'Truth-Initiative-Umfrage unter jugendlichen Vapern',
    },
    failedAttempts: {
      figure: '28\u00a0% → 53\u00a0%',
      claim: 'der Anstieg gescheiterter Aufhörversuche bei jungen Menschen, die täglich vapen, zwischen 2020 und 2024. Aufhören ist schwerer geworden; du bist nicht schwächer geworden.',
      source: 'JAMA Network Open',
    },
    cravingWindow: {
      figure: '15–20 Min.',
      claim: 'so lange dauern die meisten Cravings tatsächlich. Das ist das ganze Zeitfenster, durch das dich der Panik-Modus bringen muss.',
      source: 'Forschungsliteratur zum Nikotin-Craving',
    },
    puffsPerCig: {
      figure: '≈14 Züge',
      claim: 'ungefähr eine Zigarette. Immer mit „≈“ gezeigt, denn die ehrliche Antwort ist eine Spanne – und wer eine genaue Zahl nennt, rät.',
      source: 'Faustregel aus der Forschung',
    },
  },

  faq: {
    taper: {
      q: 'Ist schrittweises Reduzieren besser als ein kalter Entzug vom Vapen?',
      a: 'Kalter Entzug klappt bei manchen und scheitert bei den meisten. Schrittweises Reduzieren senkt dein Nikotin so langsam, dass der Entzug beherrschbar bleibt – deshalb zählt Cirrus Züge, die sinken, statt Tage, die steigen. Wenn kalter Entzug bei dir schon funktioniert hat, brauchst du keine App.',
    },
    autoCount: {
      q: 'Zählt Cirrus die Züge automatisch?',
      a: 'Nein. Cirrus kann deine Vape nicht sehen, also tippst du einmal pro Zug – in der App, im Homescreen-Widget oder auf deiner Apple Watch. Deshalb funktioniert es auch mit jeder Vape, Einweg-Vapes eingeschlossen. Und genau dieses Tippen ist das Nützliche: Jeden Zug festzuhalten ist eine seit Langem untersuchte Methode, schon für sich allein weniger zu vapen – weil es aus einem Reflex wieder eine Entscheidung macht, die du bemerkst.',
    },
    puffsPerDay: {
      q: 'Wie viele Züge am Tag sind viel?',
      a: 'Es gibt keine klare Grenze, und keine Gesundheitsbehörde veröffentlicht eine. Etwa 14 Züge entsprechen ungefähr einer Zigarette, also liegen 150 am Tag im Bereich von zehn.',
    },
    disposable: {
      q: 'Wie viele Züge hat eine Einweg-Vape?',
      a: 'Weniger, als auf der Packung steht. Die beworbenen Werte stammen von einer Maschine, die kurze, gleichmäßige Züge nimmt – im echten Gebrauch landet man meist deutlich unter der Zahl auf der Vorderseite.',
    },
    costPerYear: {
      q: 'Was kostet Vapen wirklich pro Jahr?',
      a: 'Nimm, was du pro Woche ausgibst, und multipliziere es mit 52. Bei £20 oder $20 pro Woche sind das über tausend im Jahr. Nutz den Rechner oben mit deiner eigenen Zahl; wir erfinden keine für dich.',
    },
    slip: {
      q: 'Was passiert, wenn ich ausrutsche und über mein Limit komme?',
      a: 'Nichts Dramatisches. Ein Reparatur-Token fängt einen Tag über dem Limit ab, sodass deine Serie blasser wird, statt zu sterben, und der Plan verschiebt deinen Freiheitstag, statt dich auf Tag eins zurückzusetzen. Ein Ausrutscher ist eine Information, kein Scheitern.',
    },
    withdrawal: {
      q: 'Wie lange dauert der Entzug vom Vapen?',
      a: 'Die Symptome beginnen meist innerhalb eines Tages und erreichen ihren Höhepunkt am zweiten oder dritten Tag – früher, als die meisten erwarten. Der größte Teil des Körperlichen legt sich innerhalb von etwa zehn Tagen.',
    },
    benefits: {
      q: 'Welche Vorteile hat es, mit dem Vapen aufzuhören?',
      a: 'Schlaf und Geschmackssinn kommen meist zuerst zurück, in der Regel innerhalb von ein paar Wochen. Atmung und Ausdauer folgen. Das Geld ist sofort da und oft der stärkste Antrieb: Was auch immer du pro Woche ausgibst, multipliziere es mit 52. Wir nennen dir keinen Prozentsatz, den wir nicht belegen können.',
    },
    methods: {
      q: 'Welche Methoden, mit dem Vapen aufzuhören, funktionieren wirklich?',
      a: 'Grob drei: kalter Entzug, schrittweises Reduzieren und Nikotinersatz. Kalter Entzug geht am schnellsten und hat die niedrigste Erfolgsquote. Reduzieren tauscht Tempo gegen eine deutlich höhere Chance, dass es hält. Nikotinersatz kann beides unterstützen. Cirrus ist eine App zum Reduzieren, weil das die Methode ist, die die meisten tatsächlich durchhalten.',
    },
    platforms: {
      q: 'Gibt es Cirrus für iPhone und Android?',
      a: 'Ja, für beide. Cirrus ist kostenlos im App Store für iPhone (iOS 15 oder neuer) und bei Google Play für Android, und zur iPhone-Version gehört eine Apple-Watch-App.',
    },
    free: {
      q: 'Ist Cirrus kostenlos?',
      a: 'Ja. Die Gratis-Version funktioniert für immer: Züge loggen, das Widget, Serien, gespartes Geld, dein Tageslimit, die Community und fünf Coach-Nachrichten am Tag. Premium bringt den adaptiven Plan, bis zu 100 Coach-Nachrichten am Tag und deinen kompletten Verlauf – für 2,99\u00a0$ pro Woche, 7,99\u00a0$ pro Monat oder 39,99\u00a0$ pro Jahr in den USA, mit 7 Tagen kostenlosem Test in jedem Tarif. Wir verkaufen deine Daten nie, und in der App stecken keine Werbe-Tracker.',
    },
    puffCount: {
      q: 'Worin unterscheidet sich das von Puff Count?',
      a: 'Beide sind Zug-Zähler zum Tippen, und beide geben dir ein Tageslimit. Die Unterschiede: Unsere Gratis-Version sperrt nie, es gibt einen KI-Coach und eine anonyme Community, und jede Statistik, die wir zeigen, hat eine Quelle. Außerdem gibt es Cirrus für iPhone und Android; Puff Count nur für Apple-Geräte, ohne Android-Version (Stand September 2026).',
    },
  },
  faqMore: {
    puffsPerDay: 'Die ganze Antwort – und die Frage, die dir mehr verrät',
    disposable: 'Warum die Zahl auf der Packung optimistisch ist',
    withdrawal: 'Der Verlauf, Tag für Tag',
    puffCount: 'Worauf du bei einer Zug-Zähler-App achten solltest',
  },

  // askPuffs, the bands, equiv*, toDevices and cta are the app's own strings
  // (obPuffs* and commonContinue in app_de.arb).
  demo: {
    askPuffs: 'Züge an einem normalen Tag?',
    askDevices: 'Einweg-Vapes pro Woche?',
    increase: 'Erhöhen',
    decrease: 'Verringern',
    del: 'Löschen',
    padLabel: 'Ziffernblock',
    equivPre: '≈ ',
    equivPost: ' Zigaretten in Zügen',
    toDevices: 'Unsicher? Über das Gerät schätzen →',
    toPuffs: '← Ich kenne meine Zugzahl',
    cta: 'Weiter',
    outEyebrow: 'Und das bedeutet es',
    spendLabel: 'Wenn du',
    perWeek: 'pro Woche ausgibst',
    yearNote: 'im Jahr, jedes Jahr. Deine Rechnung, nicht unsere',
    startSuffix: ' am Tag',
    freedom: '0 · Freiheitstag',
    curveLabel: 'Deine Reduktionskurve, die in 30 Tagen auf null fällt.',
    curveCaption: 'Deine 30-Tage-Kurve · neu gezeichnet, während du tippst',
    bandEmpty: 'Na los, sei ehrlich',
    bandLight: 'Leichte Gewohnheit',
    bandModerate: 'Mittlere Abhängigkeit',
    bandHeavy: 'Starke Abhängigkeit',
    bandSevere: 'Schwere Abhängigkeit',
    quipEmpty: 'Keiner schaut zu. Mit einem leeren Feld können wir nicht rechnen.',
    quipLight: 'Ehrlich, du bist schon nah dran. Das geht schneller, als du denkst.',
    quipModerate: 'Eine Schachtel am Tag, als Vape verkleidet. Sehr gut zu beheben.',
    quipHeavy: 'Große Zahl. Und eine sehr verbreitete – du bist kein Sonderfall.',
    quipSevere: 'Das ist eine Menge Nikotin. Keine Predigt – nur ein Plan, der da beginnt, wo du stehst.',
  },

  download: {
    title: 'App zum Aufhören mit dem Vapen für iPhone und Android',
    description:
      'Lade Cirrus, die kostenlose App zum Aufhören mit dem Vapen: Einmal tippen pro Zug, dein Tageslimit sinkt auf null. Im App Store für iPhone und bei Google Play.',
    crumb: 'App holen',
    h1: '{site} laden',
    lede: 'Eine App zum Aufhören mit dem Vapen – mit einem Zug-Zähler zum Tippen und einem Tageslimit, das bis auf null sinkt. Ein schlechter Tag wirft dich nie auf Tag eins zurück.',
    whichH2: 'Welches Handy',
    whichBody:
      'Beide. Cirrus gibt es im App Store für iPhone (iOS 15 oder neuer), inklusive Apple-Watch-App, und bei Google Play für Android. Das Homescreen-Widget funktioniert auf beiden.',
    whatH2: 'Was du bekommst',
    whatBody:
      'Die Gratis-Version funktioniert für immer: Züge loggen, das Widget, Serien, gespartes Geld, dein Tageslimit, die Community und fünf Coach-Nachrichten am Tag. Premium bringt den adaptiven Plan, bis zu 100 Coach-Nachrichten am Tag und deinen kompletten Verlauf, mit 7 Tagen kostenlosem Test in jedem Tarif. Es gibt keine Sperre, wir verkaufen deine Daten nie, und in der App stecken keine Werbe-Tracker – wir haben die Werbe-ID entfernt, statt sie nur abzuschalten.',
    unsure: {
      pre: 'Noch unsicher? ',
      link: 'Sieh dir an, was dich ein Jahr Vapen kostet',
      post: ' – das dauert etwa zehn Sekunden und braucht keine Anmeldung.',
    },
  },

  notFound: {
    title: 'Seite nicht gefunden',
    description: 'Diese Seite gibt es nicht.',
    h1: '404',
    lede: 'Diese Seite gibt es nicht.',
    home: 'Zurück zur Startseite',
    getApp: 'App holen',
    blog: 'Blog lesen',
  },
};
