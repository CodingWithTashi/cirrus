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
 *
 * ONE QUERY, ONE PAGE. Where a blog post now owns a question, the answer here is
 * deliberately cut to a two-sentence summary with a `more` link to that post.
 * A full answer in both places puts the home page and the post in competition
 * for the same search, and Google usually resolves that by ranking neither.
 * `more` is rendered as a visible link but is NOT part of the FAQPage schema —
 * the schema carries the plain answer only.
 */
export const FAQS = [
  {
    q: 'Is tapering better than quitting vaping cold turkey?',
    a: 'Cold turkey works for some people and fails most. A taper lowers your nicotine slowly enough that withdrawal stays manageable, which is why Cirrus counts puffs going down instead of days going up. If cold turkey has already worked for you, you do not need an app.',
  },
  {
    q: 'How many puffs a day is a lot?',
    a: 'There is no clean line, and no health body publishes one. Roughly 14 puffs is about one cigarette, so 150 a day is in the region of ten.',
    more: { label: 'The full answer, and the question that tells you more', href: '/blog/how-many-puffs-a-day-is-a-lot' },
  },
  {
    q: 'How many puffs are in a disposable vape?',
    a: 'Fewer than the box says. Advertised counts come from a machine taking short, even puffs, so real use commonly lands well under the number on the front.',
    more: { label: 'Why the box number is optimistic', href: '/blog/how-many-puffs-in-a-disposable-vape' },
  },
  {
    q: 'What does vaping actually cost per year?',
    a: 'Take what you spend a week and multiply by 52. At £20 or $20 a week that is over a thousand a year. Use the calculator above with your own number; we are not going to invent one for you.',
  },
  {
    q: 'What happens if I slip and go over my limit?',
    a: 'Nothing dramatic. A repair token absorbs one over-limit day so your streak dims instead of dying, and the plan stretches your Freedom Day rather than resetting you to day one. A slip is data, not failure.',
  },
  {
    q: 'How long does vaping withdrawal last?',
    a: 'Symptoms usually start within a day and peak on day two or three, earlier than most people expect. Most of the physical side settles within about ten days.',
    more: { label: 'The day-by-day timeline', href: '/blog/how-long-does-vaping-withdrawal-last' },
  },
  {
    q: 'What are the benefits of quitting vaping?',
    a: 'Sleep and taste tend to come back first, usually within a couple of weeks. Breathing and stamina follow. The money is immediate and often the most motivating: whatever you spend a week, multiply by 52. We will not quote you a percentage we cannot source.',
  },
  {
    q: 'What quit vaping methods actually work?',
    a: 'Broadly three: cold turkey, tapering, and nicotine replacement. Cold turkey is fastest and has the lowest success rate. Tapering trades speed for a much higher chance of it sticking. NRT can support either. Cirrus is a taper app because that is the method most people can actually hold.',
  },
  {
    q: 'When is Cirrus available, and is it on iPhone?',
    a: 'Android first. iPhone is a fast-follow. It genuinely is not built yet, and we would rather say so than take your money for a pre-order. Join the waitlist and you will hear the day it lands on your platform.',
  },
  {
    q: 'Is Cirrus free?',
    a: 'There is a free tier that keeps working forever: puff logging, streaks, money saved, your daily limit, community, and a few coach messages a day. Paid unlocks the adaptive plan and unlimited coaching. We never sell your data and there are no ad trackers in the app.',
  },
  {
    q: 'How is this different from Puff Count?',
    a: 'Mostly honesty, and which phone you own. We publish a source for every statistic, the free tier is not a lockout, and there is a coach and a community rather than a counter on its own.',
    more: { label: 'What to look for in a puff counter app', href: '/blog/how-to-choose-a-puff-counter-app' },
  },
] as const;
