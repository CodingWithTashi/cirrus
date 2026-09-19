// Portuguese — written for the WIDER audience, which means BRAZILIAN Portuguese:
// `você`, celular, tela inicial, app, tragadas, fissura. Founder decision, Sep 19
// 2026 (docs/10 §43.3). That is NOT the app's dialect — app_pt.arb is European
// ("a tua", "telemóvel", "passas", "registar") — and the difference is wider than
// it is in Spanish, so this file deliberately does not copy the ARB wording.
//
// What it DOES keep are the app's feature names that read the same in both
// countries — Dia da liberdade, sequência, Modo pânico, Orbes / Peças / Blocos,
// Ember — so the site and the app still call things by the same names. It never
// quotes a European button label ("REGISTAR PASSA") at a Brazilian reader; it
// describes the button instead. Closing the gap properly is an app task
// (app_pt_BR.arb), logged in docs/08 §6.
//
// "fissura" is the word Brazilian cessation material uses for a craving.
//
// Drafted by Claude, spot-checked by the founder. See en.ts for the rules every
// locale follows; scripts/check-i18n.mjs enforces the mechanical ones.
import type { Dictionary } from './en.ts';

export const pt: Dictionary = {
  chrome: {
    skip: 'Ir para o conteúdo',
    navLabel: 'Principal',
    breadcrumbLabel: 'Trilha de navegação',
    home: 'Início',
    blog: 'Blog',
    getApp: 'Baixar o app',
    footerLine: 'Feito por alguém que parou. 17+ · a nicotina vicia.',
    privacy: 'Privacidade',
    terms: 'Termos',
    deleteAccount: 'Excluir conta',
    rssTitle: 'Blog do {site}',
    inEnglish: ' (em inglês)',
    language: 'Idioma',
  },

  meta: {
    tagline: 'Pare de usar vape sem cortar de uma vez',
    description:
      'O app para parar de fumar vape que conta suas tragadas reais e reduz até zero. Sem cortar de uma vez, sem voltar ao dia um e sem estatística inventada.',
  },

  // Apple's and Google's own wording for their badges in Brazilian Portuguese.
  stores: {
    appStore: 'Baixar na App Store',
    googlePlay: 'Disponível no Google Play',
  },

  home: {
    hero: {
      eyebrow: 'Grátis no iPhone e no Android',
      h1: { pre: 'Pare de usar vape sem ', accent: 'cortar de uma vez', post: '.' },
      sub: 'O app para largar o vape que vai reduzindo aos poucos em vez de exigir que você pare de repente. Uma terça-feira ruim não deveria custar três semanas.',
      trust: ['Grátis para começar', 'O plano grátis nunca expira', 'Sem rastreadores de anúncios'],
    },
    number: {
      eyebrow: 'Ao vivo · sem cadastro',
      h2: 'Quanto o vape custa para você por ano, de verdade?',
      sub: 'Toque no teclado ali em cima. Tudo aqui embaixo muda junto.',
    },
    day: {
      eyebrow: 'Um dia de exemplo',
      h2: 'Como é parar com Cirrus, hora a hora.',
      sub: 'Dia 12 de uma redução de 30 dias. Os horários são inventados; cada recurso desta linha está no app que você baixa hoje.',
      steps: {
        first: {
          title: 'A primeira do dia',
          body: 'Um toque no botão de registrar, ou no + do widget da sua tela inicial, sem abrir o app. Um toque é sempre exatamente uma tragada, com cinco segundos para desfazer se você errar.',
          tag: 'Grátis',
        },
        lunch: {
          title: 'O almoço sai do controle',
          body: 'Você passou do limite de hoje. Sem zerar, sem dia um. Uma ficha de reparo que você ganhou com sete dias limpos absorve isso, e a sequência esmaece em vez de morrer.',
          tag: 'Grátis',
        },
        headsUp: {
          title: 'Um aviso, dez minutos antes',
          body: 'Seu mapa de horas gatilho diz que 3 da tarde é a mais difícil, então foi essa a hora que você escolheu. Um único aviso chega logo antes, e nunca durante suas horas de silêncio.',
          tag: 'Grátis',
        },
        craving: {
          title: 'A fissura aparece mesmo assim',
          body: 'Aperte Pânico. Um guia de respiração 4-7-8, o motivo que você escreveu no dia um e um jogo para os seus polegares enquanto a onda chega ao pico. Abre sempre, em qualquer plano, e a porta para o coach lá dentro nunca está trancada.',
          tag: 'Grátis',
        },
        passed: {
          title: 'Passou',
          body: 'A maioria das fissuras acaba em 15 a 20 minutos. Toque em “Passou” e ela conta como uma que você venceu.',
        },
        night: {
          title: 'Sem conseguir dormir, querendo uma',
          body: 'Mande uma mensagem para Ember, o coach com IA. Ele já sabe em que dia do plano você está, qual é o seu limite e que as noites são a sua parte difícil, então você não precisa explicar. Ou publique um SOS na comunidade anônima, e ele fica fixado no topo do feed por uma hora.',
          tag: 'Grátis · 5 mensagens ao coach por dia',
        },
        midnight: {
          title: 'A linha de amanhã desce um pouco',
          body: 'Numa boa sequência, o plano acelera. Dois dias difíceis seguidos e ele dá mais folga e move o Dia da liberdade, em vez de preparar você para falhar.',
          tag: 'Plano adaptativo · Premium',
        },
      },
    },
    screens: {
      eyebrow: 'Dentro do app',
      h2: 'Este é o app que você vai baixar.',
      sub: 'As mesmas telas que estão na página da loja.',
      count: '{n} telas · deslize →',
      railLabel: 'Capturas de tela do app',
      alts: {
        home: 'Início: sua última tragada, registrada. As tragadas de hoje contra o seu limite, o dinheiro economizado e as fissuras vencidas.',
        log: 'Registre uma tragada com um toque, com as barras desta semana e o widget da tela inicial.',
        plan: 'Uma redução feita para você: sua linha diária desce um pouco a cada dia até o Dia da liberdade.',
        coach: 'Um coach que responde: Ember conhece o seu plano, os seus padrões e o seu ponto fraco.',
        panic: 'Fissura? Aperte Pânico: um exercício de respiração guiada que dura mais que a vontade.',
        community: 'Pare junto com quem entende: o feed anônimo da comunidade.',
        stats: 'Veja a nicotina ir embora: miligramas por dia, horas gatilho e marcos de saúde.',
      },
    },
    devices: {
      eyebrow: 'Onde ele vive',
      h2: 'No celular que está na sua mão, e no pulso que vem junto.',
      items: {
        iphone: { name: 'iPhone', body: 'Na App Store. iOS 15 ou posterior.' },
        android: { name: 'Android', body: 'No Google Play.' },
        widget: { name: 'Widget da tela inicial', body: 'Registre uma tragada sem abrir o app, no iPhone e no Android.' },
        watch: { name: 'Apple Watch', body: 'A contagem de hoje, o seu limite e um + que registra direto do pulso.' },
      },
    },
    plans: {
      eyebrow: 'Quanto custa',
      h2: 'O plano grátis não é um teste. Ele não expira.',
      sub: 'Contar, o seu limite e a sua sequência são o essencial, então são grátis para sempre. O Premium é para quando você quiser mais ajuda.',
      premium: 'Premium',
      perWeek: 'por semana',
      perMonth: 'por mês',
      perYear: 'por ano',
      note: {
        bold: 'Teste grátis de 7 dias em todos os planos.',
        rest: 'Preços dos EUA; a sua loja mostra os seus. Cobrança e cancelamento pela App Store ou pelo Google Play.',
      },
      tableLabel: 'Grátis e Premium comparados',
      colFeature: 'Recurso',
      colFree: 'Grátis',
      colPremium: 'Premium',
      included: 'Incluído',
      notIncluded: 'Não incluído',
      rows: {
        counter: { feature: 'Contador de tragadas, widget, edição de qualquer dia' },
        limit: { feature: 'Limite diário que desce até o Dia da liberdade' },
        streak: { feature: 'Sequência com fichas de reparo' },
        money: { feature: 'Dinheiro economizado e metas de economia' },
        panic: { feature: 'Botão de pânico', free: 'Abre sempre · jogo Orbes', pro: 'Mais Peças e Blocos' },
        coach: { feature: 'Ember, o coach com IA', free: '5 mensagens por dia', pro: 'Até 100 por dia' },
        community: { feature: 'Comunidade anônima', free: '1 publicação por dia, mais SOS', pro: '3 publicações por dia, mais SOS' },
        timeline: { feature: 'Linha da saúde', free: 'Os primeiros 4 marcos, e os que você alcançar', pro: 'Completa' },
        history: { feature: 'Histórico de estatísticas', free: '7 dias', pro: '30 dias, visão mensal, previsão de fissuras' },
        adaptive: { feature: 'Plano que se reajusta toda noite' },
        insight: { feature: 'Relatório semanal de insights' },
        themes: { feature: 'Temas Hearth e Tide' },
      },
    },
    stats: {
      eyebrow: 'Sem estatísticas inventadas',
      h2: 'Aqui, todo número tem uma fonte.',
      sub: 'Outros apps para parar publicam “78% dos membros param”, sem citar ninguém. Nós não.',
    },
    faq: {
      eyebrow: 'Respostas diretas',
      h2: 'Perguntas sobre parar com o vape que as pessoas realmente fazem',
    },
    closing: {
      eyebrow: 'Download grátis',
      h2: 'Sua última tragada está mais perto do que você imagina.',
      sub: 'Conte o seu número real hoje à noite. O plano começa daí, no ritmo que você escolher.',
      qrLabel: 'Código QR para cirrusquit.com/download',
      qrTitle: 'Está no computador?',
      qrBody: 'Aponte a câmera do seu celular para baixar a versão certa.',
    },
  },

  // Sources keep their published names: a reader has to be able to find them.
  stats: {
    abstinence: {
      figure: '24% vs. 19%',
      claim: 'de abstinência em um ensaio randomizado com 2.588 jovens adultos — o apoio para parar funciona, mas ninguém consegue nove vezes em cada dez.',
      source: 'This is Quitting RCT, Truth Initiative / JMIR',
    },
    wake30: {
      figure: '76%',
      claim: 'dos jovens que usam vape recorrem a ele nos primeiros 30 minutos depois de acordar. Se é o seu caso, é um padrão de dependência, não um problema de força de vontade.',
      source: 'Pesquisa da Truth Initiative com adolescentes que usam vape',
    },
    failedAttempts: {
      figure: '28% → 53%',
      claim: 'o aumento das tentativas fracassadas de parar entre jovens que usam vape todos os dias, de 2020 a 2024. Parar ficou mais difícil; não foi você que enfraqueceu.',
      source: 'JAMA Network Open',
    },
    cravingWindow: {
      figure: '15–20 min',
      claim: 'quanto dura, de fato, a maioria das fissuras. Essa é toda a janela que o Modo pânico precisa ajudar você a atravessar.',
      source: 'Literatura sobre a fissura por nicotina',
    },
    puffsPerCig: {
      figure: '≈14 tragadas',
      claim: 'mais ou menos um cigarro. Sempre com “≈”, porque a resposta honesta é uma faixa, e quem cita um número exato está chutando.',
      source: 'Heurística de pesquisa',
    },
  },

  faq: {
    taper: {
      q: 'Reduzir aos poucos é melhor do que parar com o vape de uma vez?',
      a: 'Parar de uma vez funciona para algumas pessoas e falha para a maioria. Reduzir aos poucos baixa a sua nicotina devagar o bastante para que a abstinência continue administrável, e é por isso que Cirrus conta tragadas que descem em vez de dias que sobem. Se parar de uma vez já funcionou para você, você não precisa de um app.',
    },
    puffsPerDay: {
      q: 'Quantas tragadas por dia é muito?',
      a: 'Não existe uma linha clara, e nenhum órgão de saúde publica uma. Cerca de 14 tragadas equivalem a mais ou menos um cigarro, então 150 por dia ficam na casa dos dez.',
    },
    disposable: {
      q: 'Quantas tragadas tem um vape descartável?',
      a: 'Menos do que a caixa diz. Os números anunciados vêm de uma máquina que dá tragadas curtas e uniformes, então o uso real costuma ficar bem abaixo do número estampado na frente.',
    },
    costPerYear: {
      q: 'Quanto custa o vape por ano, de verdade?',
      a: 'Pegue o que você gasta por semana e multiplique por 52. Com £20 ou $20 por semana, isso passa de mil por ano. Use a calculadora lá em cima com o seu próprio número; não vamos inventar um para você.',
    },
    slip: {
      q: 'O que acontece se eu escorregar e passar do meu limite?',
      a: 'Nada dramático. Uma ficha de reparo absorve um dia acima do limite, então a sua sequência esmaece em vez de morrer, e o plano estica o seu Dia da liberdade em vez de mandar você de volta ao dia um. Um escorregão é um dado, não um fracasso.',
    },
    withdrawal: {
      q: 'Quanto tempo dura a abstinência do vape?',
      a: 'Os sintomas costumam começar em até um dia e chegam ao pico no segundo ou no terceiro, mais cedo do que a maioria espera. A maior parte do lado físico se acalma em cerca de dez dias.',
    },
    benefits: {
      q: 'Quais são os benefícios de parar com o vape?',
      a: 'O sono e o paladar costumam voltar primeiro, em geral em algumas semanas. Depois vêm a respiração e o fôlego. O dinheiro é imediato e muitas vezes o que mais motiva: o que você gasta por semana, multiplique por 52. Não vamos citar uma porcentagem que não conseguimos comprovar.',
    },
    methods: {
      q: 'Quais métodos para parar com o vape realmente funcionam?',
      a: 'Em linhas gerais, três: parar de uma vez, reduzir aos poucos e a reposição de nicotina. Parar de uma vez é o mais rápido e o que menos dá certo. Reduzir troca velocidade por uma chance muito maior de durar. A reposição de nicotina pode apoiar qualquer um dos dois. Cirrus é um app de redução porque esse é o método que a maioria consegue manter.',
    },
    platforms: {
      q: 'Cirrus está no iPhone e no Android?',
      a: 'Sim, nos dois. Cirrus é grátis na App Store para iPhone (iOS 15 ou posterior) e no Google Play para Android, e a versão para iPhone vem com um app para Apple Watch.',
    },
    free: {
      q: 'Cirrus é grátis?',
      a: 'Sim. O plano grátis funciona para sempre: registro de tragadas, o widget, sequências, dinheiro economizado, o seu limite diário, a comunidade e cinco mensagens ao coach por dia. O Premium acrescenta o plano adaptativo, até 100 mensagens ao coach por dia e o seu histórico completo, por US$ 2,99 por semana, US$ 7,99 por mês ou US$ 39,99 por ano nos EUA, com teste grátis de 7 dias em todos os planos. Nunca vendemos os seus dados, e o app não tem rastreadores de anúncios.',
    },
    puffCount: {
      q: 'Qual é a diferença para o Puff Count?',
      a: 'A honestidade, principalmente. Publicamos uma fonte para cada estatística, o plano grátis não trava você, e há um coach e uma comunidade em vez de um contador sozinho. Cirrus também está no iPhone e no Android; o Puff Count só existe para iPhone.',
    },
  },
  faqMore: {
    puffsPerDay: 'A resposta completa, e a pergunta que diz mais',
    disposable: 'Por que o número da caixa é otimista',
    withdrawal: 'A linha do tempo, dia a dia',
    puffCount: 'O que procurar em um app contador de tragadas',
  },

  // The bands and `cta` are the app's own strings (app_pt.arb), which read the
  // same in Brazil. The rest is Brazilian wording of the app's onboarding step.
  demo: {
    askPuffs: 'Tragadas em um dia normal?',
    askDevices: 'Descartáveis por semana?',
    increase: 'Aumentar',
    decrease: 'Diminuir',
    del: 'Apagar',
    padLabel: 'Teclado numérico',
    equivPre: '≈ ',
    equivPost: ' cigarros em tragadas',
    toDevices: 'Não sabe? Estime pelo dispositivo →',
    toPuffs: '← Eu sei quantas tragadas dou',
    cta: 'Continuar',
    outEyebrow: 'E é isto que significa',
    spendLabel: 'Se você gasta',
    perWeek: 'por semana',
    yearNote: 'por ano. As suas contas, não as nossas',
    startSuffix: ' por dia',
    freedom: '0 · Dia da liberdade',
    curveLabel: 'Sua curva de redução caindo a zero em 30 dias.',
    curveCaption: 'Sua curva de 30 dias · redesenhada enquanto você digita',
    bandEmpty: 'Vai, fale a verdade',
    bandLight: 'Hábito leve',
    bandModerate: 'Dependência moderada',
    bandHeavy: 'Dependência alta',
    bandSevere: 'Dependência severa',
    quipEmpty: 'Ninguém está olhando. Não dá para fazer conta com um campo vazio.',
    quipLight: 'Você já está bem perto, de verdade. Vai ser mais rápido do que imagina.',
    quipModerate: 'Um maço por dia, fantasiado de vape. Dá para resolver, e muito.',
    quipHeavy: 'É um número grande. E também muito comum: você não é um caso à parte.',
    quipSevere: 'Isso é muita nicotina. Sem sermão: só um plano que começa de onde você está.',
  },

  download: {
    title: 'Baixar Cirrus',
    description:
      'Baixe Cirrus, o app para parar de fumar vape que conta suas tragadas reais e reduz até zero. Grátis na App Store para iPhone e no Google Play.',
    crumb: 'Baixar o app',
    h1: 'Baixar {site}',
    lede: 'Um contador de tragadas que vai reduzindo aos poucos em vez de exigir que você pare de repente. Uma terça-feira ruim não deveria custar três semanas.',
    whichH2: 'Qual celular',
    whichBody:
      'Os dois. Cirrus está na App Store para iPhone (iOS 15 ou posterior), com um app para Apple Watch incluído, e no Google Play para Android. O widget da tela inicial funciona nos dois.',
    whatH2: 'O que você recebe',
    whatBody:
      'O plano grátis funciona para sempre: registro de tragadas, o widget, sequências, dinheiro economizado, o seu limite diário, a comunidade e cinco mensagens ao coach por dia. O Premium acrescenta o plano adaptativo, até 100 mensagens ao coach por dia e o seu histórico completo, com teste grátis de 7 dias em todos os planos. Não há bloqueio, nunca vendemos os seus dados, e o app não tem rastreadores de anúncios — removemos o ID de publicidade em vez de só desativá-lo.',
    unsure: {
      pre: 'Ainda em dúvida? ',
      link: 'Veja quanto um ano de vape está custando para você',
      post: ' — leva uns dez segundos e não pede cadastro.',
    },
  },

  notFound: {
    title: 'Página não encontrada',
    description: 'Essa página não existe.',
    h1: '404',
    lede: 'Essa página não existe.',
    home: 'Voltar ao início',
    getApp: 'Baixar o app',
    blog: 'Ler o blog',
  },
};
