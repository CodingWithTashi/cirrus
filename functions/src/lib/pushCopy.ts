/**
 * Push copy, in the five languages the app ships.
 *
 * The app's rule is zero hardcoded UI strings, and a push notification is UI —
 * arguably the most exposed UI there is, since the OS draws it before the app
 * is even running. That is also why it cannot come from the ARB files: the
 * notification is rendered without our code involved, so the text has to be
 * decided server-side, where `users/{uid}.locale` already tells us which
 * language to decide in (`syncUserContext` has been writing it all along).
 *
 * Kept deliberately tiny. If this table grows past a handful of entries it
 * wants to be generated from the ARBs rather than maintained twice.
 */

export type PushKey = 'sosReply' | 'insightReady';

interface Copy {
  readonly title: string;
  readonly body: string;
}

const COPY: Record<PushKey, Record<string, Copy>> = {
  sosReply: {
    en: {title: 'Someone had your back', body: 'A quitter replied to your SOS. Go see.'},
    es: {title: 'Alguien te cubrió', body: 'Alguien respondió a tu SOS. Ve a verlo.'},
    fr: {title: "Quelqu'un t'a soutenu", body: 'Un quitteur a répondu à ton SOS. Va voir.'},
    de: {title: 'Jemand war für dich da', body: 'Jemand hat auf dein SOS geantwortet. Schau mal.'},
    pt: {title: 'Alguém apoiou-te', body: 'Alguém respondeu ao teu SOS. Vai ver.'},
  },
  insightReady: {
    en: {title: 'Your week, read back to you', body: 'This week’s insight is ready.'},
    es: {title: 'Tu semana, contada', body: 'Tu resumen de la semana está listo.'},
    fr: {title: 'Ta semaine, racontée', body: 'Ton bilan de la semaine est prêt.'},
    de: {title: 'Deine Woche, zurückgespiegelt', body: 'Dein Wochenrückblick ist da.'},
    pt: {title: 'A tua semana, contada', body: 'O teu resumo da semana está pronto.'},
  },
};

/**
 * Copy for [key] in the closest language we have.
 *
 * Matches on the language subtag only: `pt-BR` and `pt-PT` both get `pt`,
 * which is right for two sentences of encouragement and wrong for nothing yet.
 * Anything unknown falls back to English rather than sending nothing — a push
 * in the wrong language still reaches someone; an empty one does not.
 */
export function pushCopy(key: PushKey, locale: string | undefined): Copy {
  const table = COPY[key];
  const lang = (locale ?? 'en').split(/[-_]/)[0]?.toLowerCase() ?? 'en';
  return table[lang] ?? table['en'] as Copy;
}
