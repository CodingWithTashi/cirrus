// Spanish — written for the WIDER audience: neutral international Spanish, `tú`,
// no vosotros, and none of the words that are Peninsular only ("móvil",
// "ordenador"). Founder decision, Sep 19 2026 (docs/10 §43.3). That is NOT the
// app's dialect — app_es.arb is Peninsular — so where a word differs, the wider
// one wins here; the app's FEATURE NAMES are kept exactly (Día de libertad,
// racha, caladas, antojos, Modo pánico, REGISTRAR CALADA, Orbes / Fichas /
// Bloques), so the site and the app still call things by the same names.
//
// "caladas" is the app's word and is understood everywhere; "puffs" is what a
// lot of Latin American vape packaging says, so it appears once, in the meta
// description, where it helps a search match and costs the reader nothing.
//
// Drafted by Claude, spot-checked by the founder. See en.ts for the rules every
// locale follows; scripts/check-i18n.mjs enforces the mechanical ones.
import type { Dictionary } from './en.ts';

export const es: Dictionary = {
  chrome: {
    skip: 'Ir al contenido',
    navLabel: 'Principal',
    breadcrumbLabel: 'Ruta de navegación',
    home: 'Inicio',
    blog: 'Blog',
    getApp: 'Descargar',
    footerLine: 'Hecho por alguien que lo dejó. 17+ · la nicotina es adictiva.',
    privacy: 'Privacidad',
    terms: 'Términos',
    deleteAccount: 'Eliminar cuenta',
    rssTitle: 'Blog de {site}',
    inEnglish: ' (en inglés)',
    language: 'Idioma',
  },

  meta: {
    title: 'App para dejar de vapear sin dejarlo de golpe',
    tagline: 'Deja de vapear sin dejarlo de golpe',
    description:
      'App gratis para dejar de vapear, en iPhone y Android. Un toque por calada (puff) y tu límite diario baja hasta cero. Sin cortar de golpe ni volver al día uno.',
  },

  // Apple's and Google's own wording for their badges in Spanish.
  stores: {
    appStore: 'Descárgalo en el App Store',
    googlePlay: 'Disponible en Google Play',
  },

  home: {
    hero: {
      eyebrow: 'App gratis para dejar de vapear · iPhone y Android',
      h1: { pre: 'Deja de vapear sin ', accent: 'dejarlo de golpe', post: '.' },
      sub: 'Un toque registra cada calada. Tu límite diario baja un poco cada día hasta llegar a cero, y un mal día nunca te devuelve al día uno.',
      trust: ['El plan gratis no caduca', 'Funciona con cualquier vape', 'Sin rastreadores de anuncios'],
    },
    number: {
      eyebrow: 'En vivo · sin registro',
      h2: '¿Cuánto te cuesta vapear al año, en realidad?',
      sub: 'Toca el teclado de arriba y pon lo que gastas. Es tu número, así que duele exactamente lo que tiene que doler.',
    },
    day: {
      eyebrow: 'Un día de ejemplo',
      h2: 'Así se ve dejarlo con Cirrus, hora a hora.',
      sub: 'Día 12 de una reducción de 30 días. Las horas son inventadas; cada función de esta línea está en la app que descargas hoy.',
      steps: {
        first: {
          title: 'La primera del día',
          body: 'Un toque en REGISTRAR CALADA, o el + del widget de tu pantalla de inicio sin abrir la app. Un toque siempre es exactamente una calada, con cinco segundos para deshacer si te equivocas.',
          tag: 'Gratis',
        },
        lunch: {
          title: 'El almuerzo se tuerce',
          body: 'Te pasaste del límite de hoy. Sin reinicio, sin día uno. Es un protector de racha que tuviste que ganarte: siete días por debajo de tu límite te dieron una ficha de reparación, que absorbe el día de hoy, así que la racha se atenúa en vez de morir.',
          tag: 'Gratis',
        },
        headsUp: {
          title: 'Un aviso, diez minutos antes',
          body: 'Tu mapa de horas disparador dice que las 3 de la tarde son las difíciles, así que esa es la hora que elegiste. Un aviso llega justo antes, y nunca durante tus horas de silencio.',
          tag: 'Gratis',
        },
        craving: {
          title: 'El antojo llega igual',
          body: 'Pulsa Pánico. Una guía de respiración 4-7-8, el motivo que escribiste el día uno y un juego para tus pulgares mientras pasa la ola. Se abre siempre, en cualquier plan, y la puerta al coach que hay dentro nunca está cerrada.',
          tag: 'Gratis',
        },
        passed: {
          title: 'Pasó',
          body: 'La mayoría de los antojos terminan en 15 a 20 minutos. Toca «Pasó» y cuenta como uno que venciste.',
        },
        night: {
          title: 'No puedes dormir, quieres una',
          body: 'Escríbele a Ember, el coach con IA. Ya sabe en qué día del plan estás, cuál es tu límite y que las noches son lo que más te cuesta, así que te ahorras explicarlo. O publica un SOS en la comunidad anónima y se fija arriba del feed durante una hora.',
          tag: 'Gratis · 5 mensajes al coach por día',
        },
        midnight: {
          title: 'La línea de mañana baja un poco',
          body: 'En una buena racha el plan se acelera. Dos días difíciles seguidos y añade margen y mueve el Día de libertad, en vez de prepararte para fallar.',
          tag: 'Plan adaptativo · Premium',
        },
      },
    },
    screens: {
      eyebrow: 'Dentro de la app',
      h2: 'Esta es la app que vas a descargar.',
      sub: 'Las mismas pantallas que aparecen en la tienda.',
      count: '{n} pantallas · desliza →',
      railLabel: 'Capturas de la app',
      alts: {
        home: 'Inicio: tu última calada, registrada. Las caladas de hoy frente a tu límite, el dinero ahorrado y los antojos vencidos.',
        log: 'Registra una calada con un toque, con las barras de esta semana y el widget de la pantalla de inicio.',
        plan: 'Una reducción hecha para ti: tu línea diaria baja un poco cada día hasta el Día de libertad.',
        coach: 'Un coach que te responde: Ember conoce tu plan, tus patrones y tu punto débil.',
        panic: '¿Antojo? Pulsa Pánico: un ejercicio de respiración guiada que dura más que las ganas.',
        community: 'Déjalo con gente que te entiende: el feed anónimo de la comunidad.',
        stats: 'Mira cómo se va la nicotina: miligramos por día, horas disparador e hitos de salud.',
      },
    },
    devices: {
      eyebrow: 'Un toque, donde sea',
      h2: 'Registra una calada donde sea que pase.',
      items: {
        iphone: { name: 'iPhone', body: 'En el App Store. iOS 15 o posterior.' },
        android: { name: 'Android', body: 'En Google Play.' },
        widget: { name: 'Widget de pantalla de inicio', body: 'Registra una calada sin abrir la app, en iPhone y Android.' },
        watch: { name: 'Apple Watch', body: 'El conteo de hoy, tu límite y un + que registra desde tu muñeca.' },
      },
    },
    plans: {
      eyebrow: 'Lo que cuesta',
      h2: 'El plan gratis no es una prueba. No caduca.',
      sub: 'Contar, tu límite y tu racha son lo esencial, así que son gratis para siempre. Premium es para cuando quieras más ayuda.',
      premium: 'Premium',
      perWeek: 'por semana',
      perMonth: 'por mes',
      perYear: 'por año',
      note: {
        bold: 'Prueba gratis de 7 días en todos los planes.',
        rest: 'Precios de EE. UU.; tu tienda muestra los tuyos. Se cobra y se cancela desde el App Store o Google Play.',
      },
      tableLabel: 'Gratis y Premium comparados',
      colFeature: 'Función',
      colFree: 'Gratis',
      colPremium: 'Premium',
      included: 'Incluido',
      notIncluded: 'No incluido',
      rows: {
        counter: { feature: 'Contador de caladas, widget, edita cualquier día' },
        limit: { feature: 'Límite diario que baja hasta el Día de libertad' },
        streak: { feature: 'Racha con fichas de reparación' },
        money: { feature: 'Dinero ahorrado y metas de ahorro' },
        panic: { feature: 'Botón de pánico', free: 'Siempre abre · juego Orbes', pro: 'Más Fichas y Bloques' },
        coach: { feature: 'Ember, el coach con IA', free: '5 mensajes al día', pro: 'Hasta 100 al día' },
        community: { feature: 'Comunidad anónima', free: '1 publicación al día, más SOS', pro: '3 publicaciones al día, más SOS' },
        timeline: { feature: 'Línea de salud', free: 'Los primeros 4 hitos, y los que alcances', pro: 'Completa' },
        history: { feature: 'Historial de estadísticas', free: '7 días', pro: '30 días, vista mensual, previsión de antojos' },
        adaptive: { feature: 'Plan que se reajusta cada noche' },
        insight: { feature: 'Informe semanal de insights' },
        themes: { feature: 'Temas Hearth y Tide' },
      },
    },
    stats: {
      eyebrow: '¿Te suena?',
      h2: 'Hace tiempo que dejó de ser una decisión.',
      sub: 'En la ducha. En el tráfico. Apenas te despiertas. Un vape no tiene paquete que terminar, así que nunca te da un punto para parar. No es un defecto de carácter. Es la nicotina.',
      hooks: {
        wake30: 'Está en tu mano antes de salir de la cama.',
        failedAttempts: 'Ya lo dejaste antes. Hasta el almuerzo.',
        cravingWindow: 'El antojo parece eterno. No lo es.',
      },
      note: 'Cada número de esta página tiene una fuente. Otras apps para dejarlo publican «el 78% de los miembros lo deja», sin citar a nadie.',
    },
    faq: {
      eyebrow: 'Respuestas directas',
      h2: 'Preguntas sobre dejar de vapear que la gente hace de verdad',
    },
    closing: {
      eyebrow: 'Descarga gratis',
      h2: 'Tu última calada está más cerca de lo que crees.',
      sub: 'Cuenta tu número real esta noche. El plan empieza desde ahí, al ritmo que elijas.',
      qrLabel: 'Código QR de cirrusquit.com/download',
      qrTitle: '¿En una computadora?',
      qrBody: 'Escanéalo con la cámara de tu teléfono para obtener la versión correcta.',
    },
  },

  // Sources keep their published names: a reader has to be able to find them.
  stats: {
    abstinence: {
      figure: '24% vs. 19%',
      claim: 'de abstinencia en un ensayo aleatorizado con 2588 adultos jóvenes — el apoyo para dejarlo funciona, pero nadie lo logra nueve de cada diez veces.',
      source: 'This is Quitting RCT, Truth Initiative / JMIR',
    },
    wake30: {
      figure: '76%',
      claim: 'de los jóvenes que vapean lo buscan en los primeros 30 minutos tras despertar. Si te pasa, es un patrón de dependencia, no un problema de fuerza de voluntad.',
      source: 'Encuesta de Truth Initiative a adolescentes que vapean',
    },
    failedAttempts: {
      figure: '28% → 53%',
      claim: 'el aumento de los intentos fallidos de dejarlo entre jóvenes que vapean a diario, de 2020 a 2024. Dejarlo se volvió más difícil; tú no te volviste más débil.',
      source: 'JAMA Network Open',
    },
    cravingWindow: {
      figure: '15–20 min',
      claim: 'lo que dura en realidad la mayoría de los antojos. Esa es toda la ventana que el Modo pánico tiene que ayudarte a cruzar.',
      source: 'Literatura sobre el antojo de nicotina',
    },
    puffsPerCig: {
      figure: '≈14 caladas',
      claim: 'más o menos un cigarrillo. Siempre con «≈», porque la respuesta honesta es un rango y quien cite un número exacto está adivinando.',
      source: 'Heurística de investigación',
    },
  },

  faq: {
    taper: {
      q: '¿Es mejor reducir poco a poco que dejar de vapear de golpe?',
      a: 'Dejarlo de golpe le funciona a algunas personas y le falla a la mayoría. Una reducción gradual baja tu nicotina lo bastante despacio para que la abstinencia sea manejable, y por eso Cirrus cuenta caladas que bajan en vez de días que suben. Si dejarlo de golpe ya te funcionó, no necesitas una app.',
    },
    autoCount: {
      q: '¿Cirrus cuenta las caladas del vape automáticamente?',
      a: 'No. Cirrus no puede ver tu vape, así que tocas una vez por calada: en la app, en el widget de la pantalla de inicio o en tu Apple Watch. Por eso funciona con cualquier vape, desechables incluidos. Y ese toque es lo útil: anotar cada una es una forma estudiada desde hace mucho de reducir por sí misma, porque convierte un reflejo otra vez en una decisión que notas.',
    },
    puffsPerDay: {
      q: '¿Cuántas caladas al día son muchas?',
      a: 'No hay una línea clara, y ningún organismo de salud publica una. Unas 14 caladas equivalen más o menos a un cigarrillo, así que 150 al día rondan los diez.',
    },
    disposable: {
      q: '¿Cuántas caladas tiene un vape desechable?',
      a: 'Menos de las que dice la caja. Las cifras anunciadas salen de una máquina que da caladas cortas y uniformes, así que el uso real suele quedar muy por debajo del número del frente.',
    },
    costPerYear: {
      q: '¿Cuánto cuesta vapear al año, en realidad?',
      a: 'Toma lo que gastas a la semana y multiplícalo por 52. Con £20 o $20 a la semana, eso es más de mil al año. Usa la calculadora de arriba con tu propio número; no vamos a inventarte uno.',
    },
    slip: {
      q: '¿Qué pasa si tropiezo y me paso del límite?',
      a: 'Nada dramático. Una ficha de reparación absorbe un día por encima del límite, así que tu racha se atenúa en vez de morir, y el plan alarga tu Día de libertad en lugar de devolverte al día uno. Un tropiezo es un dato, no un fracaso.',
    },
    withdrawal: {
      q: '¿Cuánto dura la abstinencia del vapeo?',
      a: 'Los síntomas suelen empezar en el primer día y alcanzan su pico el segundo o el tercero, antes de lo que casi todos esperan. La mayor parte de lo físico se calma en unos diez días.',
    },
    benefits: {
      q: '¿Qué beneficios tiene dejar de vapear?',
      a: 'El sueño y el gusto suelen volver primero, normalmente en un par de semanas. Después, la respiración y la resistencia. El dinero es inmediato y a menudo lo que más motiva: lo que gastes a la semana, multiplícalo por 52. No te vamos a citar un porcentaje que no podamos respaldar.',
    },
    methods: {
      q: '¿Qué métodos para dejar de vapear funcionan de verdad?',
      a: 'A grandes rasgos, tres: dejarlo de golpe, reducir poco a poco y la terapia de reemplazo de nicotina. Dejarlo de golpe es lo más rápido y lo que menos éxito tiene. Reducir cambia velocidad por muchas más probabilidades de que dure. El reemplazo de nicotina puede apoyar cualquiera de los dos. Cirrus es una app de reducción porque es el método que la mayoría logra sostener.',
    },
    platforms: {
      q: '¿Cirrus está en iPhone y Android?',
      a: 'Sí, en ambos. Cirrus es gratis en el App Store para iPhone (iOS 15 o posterior) y en Google Play para Android, y la versión de iPhone incluye una app para Apple Watch.',
    },
    free: {
      q: '¿Cirrus es gratis?',
      a: 'Sí. El plan gratis funciona para siempre: registro de caladas, el widget, rachas, dinero ahorrado, tu límite diario, la comunidad y cinco mensajes al coach por día. Premium añade el plan adaptativo, hasta 100 mensajes al coach por día y tu historial completo, por $2.99 a la semana, $7.99 al mes o $39.99 al año en EE. UU., con una prueba gratis de 7 días en todos los planes. Nunca vendemos tus datos y la app no tiene rastreadores de anuncios.',
    },
    puffCount: {
      q: '¿En qué se diferencia de Puff Count?',
      a: 'Los dos son contadores de caladas que tocas, y los dos te ponen un límite diario. Las diferencias: nuestro plan gratis nunca se bloquea, hay un coach con IA y una comunidad anónima, y cada estadística que mostramos tiene una fuente. Además, Cirrus está en iPhone y en Android; Puff Count solo está en dispositivos de Apple, sin versión para Android a septiembre de 2026.',
    },
  },
  faqMore: {
    puffsPerDay: 'La respuesta completa, y la pregunta que te dice más',
    disposable: 'Por qué el número de la caja es optimista',
    withdrawal: 'La cronología día a día',
    puffCount: 'Qué buscar en una app para contar caladas',
  },

  // askPuffs, the bands, equiv*, toDevices and cta are the app's own strings
  // (obPuffs* and commonContinue in app_es.arb).
  demo: {
    askPuffs: '¿Caladas en un día normal?',
    askDevices: '¿Desechables a la semana?',
    increase: 'Aumentar',
    decrease: 'Disminuir',
    del: 'Borrar',
    padLabel: 'Teclado numérico',
    equivPre: '≈ ',
    equivPost: ' cigarrillos en caladas',
    toDevices: '¿No lo sabes? Estímalo por dispositivo →',
    toPuffs: '← Sé cuántas caladas doy',
    cta: 'Continuar',
    outEyebrow: 'Y esto es lo que significa',
    spendLabel: 'Si gastas',
    perWeek: 'a la semana',
    yearNote: 'al año, cada año. Tus cuentas, no las nuestras',
    startSuffix: ' al día',
    freedom: '0 · Día de libertad',
    curveLabel: 'Tu curva de reducción bajando a cero en 30 días.',
    curveCaption: 'Tu curva de 30 días · se redibuja mientras escribes',
    bandEmpty: 'Vamos, di la verdad',
    bandLight: 'Hábito ligero',
    bandModerate: 'Dependencia moderada',
    bandHeavy: 'Dependencia alta',
    bandSevere: 'Dependencia severa',
    quipEmpty: 'Nadie está mirando. No podemos hacer cuentas con una casilla vacía.',
    quipLight: 'Ya estás muy cerca, de verdad. Será más rápido de lo que crees.',
    quipModerate: 'Un paquete al día, disfrazado de vape. Muy arreglable.',
    quipHeavy: 'Es un número grande. Y también muy común: no eres un caso raro.',
    quipSevere: 'Eso es mucha nicotina. Sin sermones: solo un plan que empieza donde estás.',
  },

  download: {
    title: 'Descarga la app para dejar de vapear en iPhone y Android',
    description:
      'Descarga Cirrus, la app gratis para dejar de vapear: un toque por calada y tu límite diario baja hasta cero. En el App Store para iPhone y en Google Play.',
    crumb: 'Descargar la app',
    h1: 'Descarga {site}',
    lede: 'Una app para dejar de vapear con un contador de caladas de un toque y un límite diario que baja hasta cero. Un mal día nunca te devuelve al día uno.',
    whichH2: 'Qué teléfono',
    whichBody:
      'Los dos. Cirrus está en el App Store para iPhone (iOS 15 o posterior), con una app para Apple Watch incluida, y en Google Play para Android. El widget de pantalla de inicio funciona en ambos.',
    whatH2: 'Qué incluye',
    whatBody:
      'El plan gratis funciona para siempre: registro de caladas, el widget, rachas, dinero ahorrado, tu límite diario, la comunidad y cinco mensajes al coach por día. Premium añade el plan adaptativo, hasta 100 mensajes al coach por día y tu historial completo, con una prueba gratis de 7 días en todos los planes. No hay bloqueos, nunca vendemos tus datos y la app no tiene rastreadores de anuncios: quitamos el ID de publicidad en vez de solo desactivarlo.',
    unsure: {
      pre: '¿Aún no lo tienes claro? ',
      link: 'Mira lo que te cuesta un año de vapeo',
      post: ': toma unos diez segundos y no pide registro.',
    },
  },

  notFound: {
    title: 'Página no encontrada',
    description: 'Esa página no existe.',
    h1: '404',
    lede: 'Esa página no existe.',
    home: 'Volver al inicio',
    getApp: 'Descargar la app',
    blog: 'Leer el blog',
  },
};
