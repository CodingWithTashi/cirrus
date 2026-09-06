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
 * ## No user text ever appears here
 *
 * A collapsed thread notification says how many people replied, never what
 * any of them wrote. A lock screen is as public as the home-screen widget,
 * and the widget's rule applies for the same reason: whoever picks the phone
 * up gets to read it. Counts are safe; sentences somebody typed are not.
 *
 * Kept deliberately tiny. If this table grows past a handful of entries it
 * wants to be generated from the ARBs rather than maintained twice.
 */
import type {PushKind} from './pushKinds';

/** The kinds that carry canned copy. `system` and `promo` supply their own. */
export type PushKey = Extract<
  PushKind,
  'communityReply' | 'communityMention' | 'sosReply' | 'insightReady'
>;

export interface Copy {
  readonly title: string;
  readonly body: string;
}

/**
 * One or two forms per language.
 *
 * `other` carries `{count}` and is used from two upwards; a key without one
 * never counts. English, Spanish, French, German and Portuguese all take the
 * same plain one/other split, so this needs no CLDR machinery — but it does
 * need the placeholder present in every `other`, which a test pins.
 */
interface Forms {
  readonly one: Copy;
  readonly other?: Copy;
}

const COPY: Record<PushKey, Record<string, Forms>> = {
  communityReply: {
    en: {
      one: {title: 'Someone replied', body: 'Go see what they said.'},
      other: {title: 'Your post is getting replies', body: '{count} new replies.'},
    },
    es: {
      one: {title: 'Alguien respondió', body: 'Ve a ver qué te dijeron.'},
      other: {
        title: 'Tu publicación tiene respuestas',
        body: '{count} respuestas nuevas.',
      },
    },
    fr: {
      one: {title: "Quelqu'un a répondu", body: "Va voir ce qu'on t'a dit."},
      other: {
        title: 'Ton message reçoit des réponses',
        body: '{count} nouvelles réponses.',
      },
    },
    de: {
      one: {title: 'Jemand hat geantwortet', body: 'Schau, was geschrieben wurde.'},
      other: {
        title: 'Dein Beitrag bekommt Antworten',
        body: '{count} neue Antworten.',
      },
    },
    pt: {
      one: {title: 'Alguém respondeu', body: 'Vai ver o que te disseram.'},
      other: {
        title: 'A tua publicação tem respostas',
        body: '{count} novas respostas.',
      },
    },
  },

  communityMention: {
    en: {one: {title: 'Someone tagged you', body: 'You were mentioned in a reply.'}},
    es: {one: {title: 'Alguien te mencionó', body: 'Te mencionaron en una respuesta.'}},
    fr: {
      one: {title: "Quelqu'un t'a mentionné", body: "On t'a mentionné dans une réponse."},
    },
    de: {
      one: {title: 'Jemand hat dich erwähnt', body: 'Du wurdest in einer Antwort erwähnt.'},
    },
    pt: {one: {title: 'Alguém mencionou-te', body: 'Foste mencionado numa resposta.'}},
  },

  sosReply: {
    en: {one: {title: 'Someone had your back', body: 'A quitter replied to your SOS. Go see.'}},
    es: {one: {title: 'Alguien te cubrió', body: 'Alguien respondió a tu SOS. Ve a verlo.'}},
    fr: {one: {title: "Quelqu'un t'a soutenu", body: 'Un quitteur a répondu à ton SOS. Va voir.'}},
    de: {one: {title: 'Jemand war für dich da', body: 'Jemand hat auf dein SOS geantwortet. Schau mal.'}},
    pt: {one: {title: 'Alguém apoiou-te', body: 'Alguém respondeu ao teu SOS. Vai ver.'}},
  },

  insightReady: {
    en: {one: {title: 'Your week, read back to you', body: 'This week’s insight is ready.'}},
    es: {one: {title: 'Tu semana, contada', body: 'Tu resumen de la semana está listo.'}},
    fr: {one: {title: 'Ta semaine, racontée', body: 'Ton bilan de la semaine est prêt.'}},
    de: {one: {title: 'Deine Woche, zurückgespiegelt', body: 'Dein Wochenrückblick ist da.'}},
    pt: {one: {title: 'A tua semana, contada', body: 'O teu resumo da semana está pronto.'}},
  },
};

/** Every language this table is expected to carry. Pinned by a test. */
export const PUSH_LOCALES: readonly string[] = ['en', 'es', 'fr', 'de', 'pt'];

/**
 * Copy for [key] in the closest language we have, for [count] items.
 *
 * Matches on the language subtag only: `pt-BR` and `pt-PT` both get `pt`,
 * which is right for two sentences of encouragement and wrong for nothing yet.
 * Anything unknown falls back to English rather than sending nothing — a push
 * in the wrong language still reaches someone; an empty one does not.
 */
export function pushCopy(
  key: PushKey,
  locale: string | undefined,
  count = 1,
): Copy {
  const table = COPY[key];
  const lang = (locale ?? 'en').split(/[-_]/)[0]?.toLowerCase() ?? 'en';
  const forms = table[lang] ?? table['en'];
  if (forms === undefined) throw new Error(`no copy for ${key}`);
  const chosen = count > 1 && forms.other !== undefined ? forms.other : forms.one;
  return {
    title: chosen.title,
    body: chosen.body.replace('{count}', String(count)),
  };
}
