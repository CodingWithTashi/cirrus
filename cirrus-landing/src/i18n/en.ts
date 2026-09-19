// English — and the SHAPE every other locale is checked against.
//
// `Dictionary` is `typeof en`, and each other locale is declared `: Dictionary`,
// so a missing key is TS2741 and an extra key is TS2353: `astro check` is this
// site's version of the app's l10n_parity_test. scripts/check-i18n.mjs covers
// what types cannot — placeholders, digits, lengths.
//
// RULES FOR EVERY STRING IN EVERY LOCALE
//   · No HTML. Where a sentence needs markup it is split ({ pre, accent, post }),
//     which also survives a language that puts the emphasis somewhere else.
//   · `{name}` placeholders, filled by fmt() — the ARB convention, and it keeps
//     the dictionary JSON-serialisable, which the live demo's data island needs.
//   · Every digit in a translation must also be in the English (check-i18n).
//     That is the honest-numbers rule (docs/02 §8) applied to a translator.
//   · "Cirrus" is an indeclinable proper noun: no article, no elision, no
//     gendered agreement — the rule the app's name-bearing strings follow.
//   · Feature NAMES come from the app's ARB files, so site and app say the same
//     words. Allowance CLAIMS never do: the ARB says "Unlimited AI coach", the
//     server enforces 100 a day, and this site says what the server does.
//
// Ids (`StatId`, `FaqId`, `DayStepId`, `CompareRowId`, `ScreenId`) live in
// lib/content.ts with everything about an item that is NOT language: its order,
// tier, tone, clock time, source link. Text is keyed by those ids here, so a
// locale cannot ship six timeline steps, or a statistic without its source.
//
// Imports carry their `.ts` extension so scripts/check-i18n.mjs can load these
// files straight through Node's type stripping, with no build step.
import { SITE_DESCRIPTION, SITE_TAGLINE } from '../consts.ts';
import type { CompareRowId, DayStepId, DeviceId, FaqId, FaqWithMoreId, HomeStatId, ScreenId, StatId } from '../lib/content.ts';

type Split = { pre: string; accent: string; post: string };

type Shape = {
  chrome: Record<string, string>;
  meta: Record<string, string>;
  stores: Record<string, string>;
  home: {
    hero: { eyebrow: string; h1: Split; sub: string; trust: readonly [string, string, string] };
    number: { eyebrow: string; h2: string; sub: string };
    day: {
      eyebrow: string; h2: string; sub: string;
      steps: Record<DayStepId, { title: string; body: string; tag?: string }>;
    };
    screens: { eyebrow: string; h2: string; sub: string; count: string; railLabel: string; alts: Record<ScreenId, string> };
    devices: { eyebrow: string; h2: string; items: Record<DeviceId, { name: string; body: string }> };
    plans: {
      eyebrow: string; h2: string; sub: string; premium: string;
      perWeek: string; perMonth: string; perYear: string;
      note: { bold: string; rest: string };
      tableLabel: string; colFeature: string; colFree: string; colPremium: string;
      included: string; notIncluded: string;
      rows: Record<CompareRowId, { feature: string; free?: string; pro?: string }>;
    };
    stats: { eyebrow: string; h2: string; sub: string; hooks: Record<HomeStatId, string>; note: string };
    faq: { eyebrow: string; h2: string };
    closing: { eyebrow: string; h2: string; sub: string; qrLabel: string; qrTitle: string; qrBody: string };
  };
  stats: Record<StatId, { figure: string; claim: string; source: string }>;
  faq: Record<FaqId, { q: string; a: string }>;
  faqMore: Record<FaqWithMoreId, string>;
  demo: Record<string, string>;
  download: {
    title: string; description: string; crumb: string; h1: string; lede: string;
    whichH2: string; whichBody: string; whatH2: string; whatBody: string;
    unsure: { pre: string; link: string; post: string };
  };
  notFound: { title: string; description: string; h1: string; lede: string; home: string; getApp: string; blog: string };
};

export const en = {
  // Header, footer and the accessibility labels around them.
  chrome: {
    skip: 'Skip to content',
    navLabel: 'Primary',
    breadcrumbLabel: 'Breadcrumb',
    home: 'Home',
    blog: 'Blog',
    getApp: 'Get the app',
    footerLine: 'Built by someone who quit. 17+ · nicotine is addictive.',
    privacy: 'Privacy',
    terms: 'Terms',
    deleteAccount: 'Delete account',
    rssTitle: '{site} blog',
    // Appended to a link that leaves the reader's language — " (en inglés)" —
    // and it carries its own leading space. Empty in English, where no link does;
    // it is the one key a locale may leave empty, and only English does.
    inEnglish: '',
    // The language switcher's accessible name.
    language: 'Language',
  },

  // The home <title>, the meta description and the default social-card alt.
  // `tagline` and `description` are read from consts.ts in English, which
  // scripts/og.mjs and the RSS feed also read, so the brand line has one home.
  // Every other locale writes its own here.
  //
  // `title` is the home page's <title> before " · Cirrus". It leads with the
  // query the page exists to answer ("quit vaping app") and keeps the brand line
  // after it; the tagline alone never said what the thing IS, and a brand nobody
  // has heard of yet was spending the first word of the result.
  meta: {
    title: 'Quit vaping app without going cold turkey',
    tagline: SITE_TAGLINE,
    description: SITE_DESCRIPTION,
  },

  // The badge links' accessible names. Both stores publish required wording for
  // these per language; a translation uses theirs, never its own.
  stores: {
    appStore: 'Download on the App Store',
    googlePlay: 'Get it on Google Play',
  },

  home: {
    hero: {
      eyebrow: 'Free quit vaping app · iPhone and Android',
      h1: { pre: 'Quit vaping without going ', accent: 'cold turkey', post: '.' },
      sub: 'One tap logs every puff. Your daily limit drops a little each day until it hits zero, and one bad day never sends you back to day one.',
      trust: ['Free tier never runs out', 'Works with any vape', 'No ad trackers'],
    },
    number: {
      eyebrow: 'Live · no signup',
      h2: 'What does vaping actually cost you a year?',
      sub: "Tap the keypad up there, then put in what you spend. It's your number, so it stings exactly as much as it should.",
    },
    day: {
      eyebrow: 'An example day',
      h2: 'What quitting with Cirrus looks like, hour by hour.',
      sub: 'Day 12 of a 30-day taper. The times are made up; every feature on this rail is in the app you download today.',
      steps: {
        first: {
          title: 'First one of the day',
          body: 'One tap on LOG PUFF, or the + on your home screen widget without opening the app. A tap is always exactly one puff, with a five-second undo for the mistap.',
          tag: 'Free',
        },
        lunch: {
          title: 'Lunch goes sideways',
          body: "You're over today's limit. No reset, no day one. It's a streak freeze you had to earn: seven days under your limit bought a repair token, and it absorbs today, so the streak dims instead of dying.",
          tag: 'Free',
        },
        headsUp: {
          title: 'A heads-up, ten minutes early',
          body: "Your trigger-hour heatmap says 3pm is the hard one, so that's the hour you picked. One nudge lands just before it, and never during your quiet hours.",
          tag: 'Free',
        },
        craving: {
          title: 'The craving shows up anyway',
          body: 'Hit Panic. A 4-7-8 breathing pacer, the reason you wrote down on day one, and a game for your thumbs while the wave peaks. It opens every time, on every plan, and the coach door inside it is never locked.',
          tag: 'Free',
        },
        passed: {
          title: 'It passed',
          body: "Most cravings are over in 15 to 20 minutes. Tap “It passed” and it's counted as one you beat.",
        },
        night: {
          title: "Can't sleep, want one",
          body: 'Message Ember, the AI coach. It already knows your plan day, your limit and that nights are your hard part, so you skip the explaining. Or post an SOS to the anonymous community and it pins to the top of the feed for an hour.',
          tag: 'Free · 5 coach messages a day',
        },
        midnight: {
          title: "Tomorrow's line drops a little",
          body: 'On a good run the plan speeds up. Two rough days running and it adds runway and moves Freedom Day instead of setting you up to fail.',
          tag: 'Adaptive plan · Premium',
        },
      },
    },
    screens: {
      eyebrow: 'Inside the app',
      h2: "This is the app you'll download.",
      sub: 'The same screens that are on the store listing.',
      count: '{n} screens · swipe →',
      railLabel: 'App screenshots',
      // Each screenshot's headline is part of the image, so the alt carries it.
      alts: {
        home: "Home: your last puff, tracked. Today's puffs against your limit, money saved and cravings beaten.",
        log: "Log a puff in one tap, with this week's bars and the home screen widget.",
        plan: 'A taper built for you: your daily line drops a little each day to Freedom Day.',
        coach: 'A coach that texts back: Ember knows your plan, your patterns and your weak spot.',
        panic: 'Craving? Hit Panic: a paced breathing exercise that outlasts the urge.',
        community: 'Quit with people who get it: the anonymous community feed.',
        stats: 'Watch nicotine leave: milligrams per day, trigger hours and health milestones.',
      },
    },
    devices: {
      eyebrow: 'One tap, anywhere',
      h2: 'Log a puff wherever it happens.',
      items: {
        iphone: { name: 'iPhone', body: 'On the App Store. iOS 15 or later.' },
        android: { name: 'Android', body: 'On Google Play.' },
        widget: { name: 'Home screen widget', body: 'Log a puff without opening the app, on iPhone and Android.' },
        watch: { name: 'Apple Watch', body: "Today's count, your limit and a + that logs from your wrist." },
      },
    },
    plans: {
      eyebrow: 'What it costs',
      h2: "The free tier isn't a trial. It doesn't run out.",
      sub: "Counting, your limit and your streak are the core, so they're free for good. Premium is for when you want more help.",
      premium: 'Premium',
      perWeek: 'a week',
      perMonth: 'a month',
      perYear: 'a year',
      note: {
        bold: '7-day free trial on every plan.',
        rest: 'US prices; your store shows yours. Billed and cancelled through the App Store or Google Play.',
      },
      tableLabel: 'Free and Premium compared',
      colFeature: 'Feature',
      colFree: 'Free',
      colPremium: 'Premium',
      included: 'Included',
      notIncluded: 'Not included',
      // Every value is a real allowance (docs/13 §4, LpAllowances in the app).
      // The coach says "up to 100" because that is what the server enforces.
      rows: {
        counter: { feature: 'Puff counter, widget, edit any day' },
        limit: { feature: 'Daily limit tapering to Freedom Day' },
        streak: { feature: 'Streak with repair tokens' },
        money: { feature: 'Money saved and savings goals' },
        panic: { feature: 'Panic Button', free: 'Always opens · Orbs game', pro: 'Plus Tiles and Blocks' },
        coach: { feature: 'Ember, the AI coach', free: '5 messages a day', pro: 'Up to 100 a day' },
        community: { feature: 'Anonymous community', free: '1 post a day, plus SOS', pro: '3 posts a day, plus SOS' },
        timeline: { feature: 'Recovery timeline', free: 'First 4 milestones, and any you reach', pro: 'All of it' },
        history: { feature: 'Stats history', free: '7 days', pro: '30 days, month view, craving forecast' },
        adaptive: { feature: 'Plan that re-adjusts every night' },
        insight: { feature: 'Weekly insight report' },
        themes: { feature: 'Hearth and Tide themes' },
      },
    },
    // The status quo, said plainly. Blunt about the dependence, never about the
    // person (docs/07 §8: no shame words, in marketing too): each hook is a
    // moment the reader recognises, the card under it is the sourced figure,
    // and the last card is the way out, because a threat with no answer beside
    // it is the version of this that makes people look away.
    stats: {
      eyebrow: 'Sound familiar?',
      h2: 'It stopped being a choice a while ago.',
      sub: "In the shower. In the car. The second you wake up. A vape has no pack to finish, so it never hands you a place to stop. That isn't a character flaw. That's nicotine.",
      hooks: {
        wake30: "It's in your hand before you're out of bed.",
        failedAttempts: "You've quit before. Until lunch.",
        cravingWindow: "The craving feels endless. It isn't.",
      },
      note: 'Every number on this page has a source. Other quit apps ship “78% of members quit”, cited to nobody.',
    },
    faq: {
      eyebrow: 'Straight answers',
      h2: 'Quit vaping questions people actually ask',
    },
    closing: {
      eyebrow: 'Free to download',
      h2: 'Your last puff is closer than you think.',
      sub: 'Count your real number tonight. The plan starts from there, at a pace you pick.',
      qrLabel: 'QR code for cirrusquit.com/download',
      qrTitle: 'On a computer?',
      qrBody: "Scan with your phone's camera to get the right version.",
    },
  },

  // The ONLY statistics permitted on this site (docs/02 §8). `source` is required
  // by the type, so no locale can show a figure without saying where it is from.
  stats: {
    abstinence: {
      figure: '24% vs 19%',
      claim: 'abstinence in a randomised trial of 2,588 young adults — quit support works, but nobody is quitting nine times out of ten.',
      source: 'This is Quitting RCT, Truth Initiative / JMIR',
    },
    wake30: {
      figure: '76%',
      claim: 'of young vapers reach for it within 30 minutes of waking. If that is you, it is a dependence pattern, not a willpower problem.',
      source: 'Truth Initiative teen-vaper survey',
    },
    failedAttempts: {
      figure: '28% → 53%',
      claim: 'the rise in failed quit attempts among daily young users between 2020 and 2024. Quitting got harder; you did not get weaker.',
      source: 'JAMA Network Open',
    },
    cravingWindow: {
      figure: '15–20 min',
      claim: 'how long most cravings actually last. That is the entire window Panic Mode has to get you through.',
      source: 'Nicotine craving literature',
    },
    puffsPerCig: {
      figure: '≈14 puffs',
      claim: 'roughly one cigarette. Always shown with a "≈", because the honest answer is a range and anyone quoting a precise number is guessing.',
      source: 'Research heuristic',
    },
  },

  // Each question is one somebody actually types into a search engine. ONE QUERY,
  // ONE PAGE: where a post owns the question, the answer here is a two-sentence
  // summary and `faqMore` labels the hand-off link (visible only — the FAQPage
  // schema carries the plain answer).
  faq: {
    taper: {
      q: 'Is tapering better than quitting vaping cold turkey?',
      a: 'Cold turkey works for some people and fails most. A taper lowers your nicotine slowly enough that withdrawal stays manageable, which is why Cirrus counts puffs going down instead of days going up. If cold turkey has already worked for you, you do not need an app.',
    },
    autoCount: {
      q: 'Does Cirrus count vape puffs automatically?',
      a: "No. Cirrus can't see your vape, so you tap once per puff: in the app, on the home screen widget or on your Apple Watch. That is also why it works with any vape, disposables included. And the tap is the useful part: writing down each one is a long-studied way to cut down in its own right, because it turns a reflex back into a decision you notice.",
    },
    puffsPerDay: {
      q: 'How many puffs a day is a lot?',
      a: 'There is no clean line, and no health body publishes one. Roughly 14 puffs is about one cigarette, so 150 a day is in the region of ten.',
    },
    disposable: {
      q: 'How many puffs are in a disposable vape?',
      a: 'Fewer than the box says. Advertised counts come from a machine taking short, even puffs, so real use commonly lands well under the number on the front.',
    },
    costPerYear: {
      q: 'What does vaping actually cost per year?',
      a: 'Take what you spend a week and multiply by 52. At £20 or $20 a week that is over a thousand a year. Use the calculator above with your own number; we are not going to invent one for you.',
    },
    slip: {
      q: 'What happens if I slip and go over my limit?',
      a: 'Nothing dramatic. A repair token absorbs one over-limit day so your streak dims instead of dying, and the plan stretches your Freedom Day rather than resetting you to day one. A slip is data, not failure.',
    },
    withdrawal: {
      q: 'How long does vaping withdrawal last?',
      a: 'Symptoms usually start within a day and peak on day two or three, earlier than most people expect. Most of the physical side settles within about ten days.',
    },
    benefits: {
      q: 'What are the benefits of quitting vaping?',
      a: 'Sleep and taste tend to come back first, usually within a couple of weeks. Breathing and stamina follow. The money is immediate and often the most motivating: whatever you spend a week, multiply by 52. We will not quote you a percentage we cannot source.',
    },
    methods: {
      q: 'What quit vaping methods actually work?',
      a: 'Broadly three: cold turkey, tapering, and nicotine replacement. Cold turkey is fastest and has the lowest success rate. Tapering trades speed for a much higher chance of it sticking. NRT can support either. Cirrus is a taper app because that is the method most people can actually hold.',
    },
    platforms: {
      q: 'Is Cirrus on iPhone and Android?',
      a: 'Yes, both. Cirrus is free on the App Store for iPhone (iOS 15 or later) and on Google Play for Android, and the iPhone version comes with an Apple Watch app.',
    },
    // Prices are the founder-locked US prices (docs/08 §1). "Up to 100" coach
    // messages, never "unlimited": 100 a day is what the server enforces.
    free: {
      q: 'Is Cirrus free?',
      a: 'Yes. The free tier keeps working forever: puff logging, the widget, streaks, money saved, your daily limit, the community and five coach messages a day. Premium adds the adaptive plan, up to 100 coach messages a day and your full history, at $2.99 a week, $7.99 a month or $39.99 a year in the US, with a 7-day free trial on every plan. We never sell your data and there are no ad trackers in the app.',
    },
    puffCount: {
      q: 'How is this different from Puff Count?',
      // Checked Sep 19 2026 against both stores and puffcount.com: Puff Count is
      // a manual logger with daily limits too, on Apple devices only, and its
      // Android page still says "coming soon". Say what is the same before what
      // is different — a reader who has used it will know.
      a: 'Both are puff counters you tap, and both set you a daily limit. The differences: our free tier never locks, there is an AI coach and an anonymous community, and every statistic we show has a source. Cirrus is also on iPhone and Android; Puff Count is only on Apple devices, with no Android version as of September 2026.',
    },
  },
  faqMore: {
    puffsPerDay: 'The full answer, and the question that tells you more',
    disposable: 'Why the box number is optimistic',
    withdrawal: 'The day-by-day timeline',
    puffCount: 'What to look for in a puff counter app',
  },

  // The live calculator. Flat and string-only because the client half of it is
  // read from a JSON data island — a dictionary cannot reach a bundled <script>.
  // The band and quip strings are the app's own onboarding copy (obPuffs* in the
  // ARB files), so every other locale copies them from there verbatim.
  demo: {
    askPuffs: 'Puffs on a normal day?',
    askDevices: 'Disposables a week?',
    increase: 'Increase',
    decrease: 'Decrease',
    del: 'Delete',
    padLabel: 'Number pad',
    equivPre: '≈ ',
    equivPost: " cigarettes' worth of puffs",
    toDevices: 'Not sure? Use device life →',
    toPuffs: '← I know my puff count',
    cta: 'Continue',
    outEyebrow: "And here's what that means",
    spendLabel: 'If you spend',
    perWeek: 'a week',
    yearNote: 'a year, every year. Your maths, not ours',
    startSuffix: ' a day',
    freedom: '0 · Freedom Day',
    curveLabel: 'Your taper curve falling to zero over 30 days.',
    curveCaption: 'Your 30-day curve · redrawn as you type',
    bandEmpty: 'Go on, be honest',
    bandLight: 'Light dependence',
    bandModerate: 'Moderate dependence',
    bandHeavy: 'Heavy dependence',
    bandSevere: 'Severe dependence',
    quipEmpty: "Nobody's watching. We can't do maths on an empty box.",
    quipLight: "Genuinely close already. This'll be quicker than you think.",
    quipModerate: 'A pack a day, in vape clothing. Extremely fixable.',
    quipHeavy: "Big number. Also a really common one — you're not an outlier.",
    quipSevere: 'That is a lot of nicotine. No lecture — just a plan that starts where you are.',
  },

  download: {
    // "Get Cirrus · Cirrus" said the brand twice and never said what it was.
    title: 'Download the quit vaping app for iPhone and Android',
    description:
      'Download Cirrus, the free quit vaping app: one tap logs a puff and your daily limit tapers to zero. On the App Store for iPhone and on Google Play.',
    crumb: 'Get the app',
    h1: 'Get {site}',
    lede: 'A quit vaping app with a one-tap puff counter and a daily limit that tapers to zero. One bad day never sends you back to day one.',
    whichH2: 'Which phone',
    whichBody:
      'Both. Cirrus is on the App Store for iPhone (iOS 15 or later), with an Apple Watch app included, and on Google Play for Android. The home screen widget works on both.',
    whatH2: 'What you get',
    whatBody:
      "The free tier keeps working forever: puff logging, the widget, streaks, money saved, your daily limit, the community and five coach messages a day. Premium adds the adaptive plan, up to 100 coach messages a day and your full history, with a 7-day free trial on every plan. There's no lockout, we never sell your data, and there are no ad trackers in the app — we removed the advertising ID rather than switching it off.",
    unsure: {
      pre: 'Not sure yet? ',
      link: 'See what a year of vaping is costing you',
      post: ' — it takes about ten seconds and it needs no signup.',
    },
  },

  notFound: {
    title: 'Page not found',
    description: "That page doesn't exist.",
    h1: '404',
    lede: "That page doesn't exist.",
    home: 'Back to home',
    getApp: 'Get the app',
    blog: 'Read the blog',
  },
} satisfies Shape;

export type Dictionary = typeof en;
