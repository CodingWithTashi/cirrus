/**
 * Landing-page content that appears twice — once as visible markup, once inside
 * structured data. Defining it here means the FAQ a person reads and the FAQ
 * Google reads can never drift apart, which is the usual way FAQ schema turns
 * into a manual action.
 */

/**
 * The ONLY statistics permitted on this site.
 *
 * docs/02 §8 bans "any uncited number" outright — it names "78% of members quit"
 * as the exact thing not to do, because a direct competitor ships it. Every row
 * below is from that spec's approved table and carries its source on screen.
 * Adding a row here is part of the same change that renders it; if there is no
 * honest number for a section, the section says nothing instead.
 */
export const HONEST_STATS = [
  {
    figure: '24% vs 19%',
    claim: 'abstinence in a randomised trial of 2,588 young adults — quit support works, but nobody is quitting nine times out of ten.',
    source: 'This is Quitting RCT, Truth Initiative / JMIR',
  },
  {
    figure: '76%',
    claim: 'of young vapers reach for it within 30 minutes of waking. If that is you, it is a dependence pattern, not a willpower problem.',
    source: 'Truth Initiative teen-vaper survey',
  },
  {
    figure: '28% → 53%',
    claim: 'the rise in failed quit attempts among daily young users between 2020 and 2024. Quitting got harder; you did not get weaker.',
    source: 'JAMA Network Open',
  },
  {
    figure: '15–20 min',
    claim: 'how long most cravings actually last. That is the entire window Panic Mode has to get you through.',
    source: 'Nicotine craving literature',
  },
  {
    figure: '≈14 puffs',
    claim: 'roughly one cigarette. Always shown with a "≈", because the honest answer is a range and anyone quoting a precise number is guessing.',
    source: 'Research heuristic',
  },
] as const;

/**
 * FAQ. Each question is one somebody actually types into Google — that is the
 * point of the section. Answers are short enough to be quoted as a snippet and
 * honest enough to survive being quoted out of context.
 */
export const FAQS = [
  {
    q: 'Is tapering better than quitting vaping cold turkey?',
    a: 'Cold turkey works for some people and fails most. A taper lowers your nicotine slowly enough that withdrawal stays manageable, which is why Cirrus counts puffs going down instead of days going up. If cold turkey has already worked for you, you do not need an app.',
  },
  {
    q: 'How many puffs a day is a lot?',
    a: 'There is no clean line, but the honest maths helps: roughly 14 puffs is about one cigarette, so 150 puffs a day is in the region of ten. Cirrus starts from whatever your real number is rather than a number it wishes you had.',
  },
  {
    q: 'How many puffs are in a disposable vape?',
    a: 'Most disposables advertise somewhere between 600 and several thousand puffs, and the label is optimistic. Cirrus estimates from your device life when you do not want to count, then corrects itself as you log.',
  },
  {
    q: 'What does vaping actually cost per year?',
    a: 'Take what you spend a week and multiply by 52 — that is it. At £20 or $20 a week that is over a thousand a year. Use the calculator above with your own number; we are not going to invent one for you.',
  },
  {
    q: 'What happens if I slip and go over my limit?',
    a: 'Nothing dramatic. A repair token absorbs one over-limit day so your streak dims instead of dying, and the plan stretches your Freedom Day rather than resetting you to day one. A slip is data, not failure.',
  },
  {
    q: 'When is Cirrus available, and is it on iPhone?',
    a: 'Android first, on October 15. iPhone is a fast-follow — it genuinely is not built yet, and we would rather say so than take your money for a pre-order. Join the waitlist and you will hear the day it lands on your platform.',
  },
  {
    q: 'Is Cirrus free?',
    a: 'There is a free tier that keeps working forever: puff logging, streaks, money saved, your daily limit, community, and a few coach messages a day. Paid unlocks the adaptive plan and unlimited coaching. We never sell your data and there are no ad trackers in the app.',
  },
  {
    q: 'How is this different from Puff Count?',
    a: 'Mostly honesty and price. We publish sources for every statistic, the free tier is not a lockout, and there is a real coach plus a community rather than a counter on its own. An in-depth comparison is coming to the blog.',
  },
] as const;
