/// Regras do Calendário Nacional de Vacinação — Gestante, versão PNI-2026.
///
/// Dados puros: sem Firebase, sem Flutter, sem UI. As regras clínicas vivem
/// aqui e só aqui — nunca dentro de um widget.
///
/// Este arquivo descreve **o que** o calendário define: quantas doses, a
/// partir de que semana, com que intervalo, contendo que componentes.
/// Decidir a situação de uma gestante específica — se o esquema está
/// completo, se a temporada é a vigente, se o intervalo já passou — é
/// responsabilidade da engine de regras, que consome estes dados e não faz
/// parte deste arquivo.
library;

/// Versão do calendário representado aqui.
///
/// Toda regra carrega esta versão, e todo registro criado sob ela deve
/// guardá-la — é o que permite saber, no futuro, sob qual conjunto de
/// regras uma informação foi apresentada.
const String versaoCalendarioPni2026 = 'PNI-2026';

/// Mensagem exibida quando uma vacina entra no período recomendado.
///
/// Texto aprovado na especificação funcional. Não varia por vacina: a
/// especificação define uma única mensagem para essa transição.
const String mensagemPeriodoRecomendado =
    'Você entrou no período recomendado para esta vacina. Confirme a '
    'indicação e a aplicação com a equipe de saúde.';

/// Mensagem geral da funcionalidade. Texto aprovado na especificação.
const String mensagemGeralVacinas =
    'As informações desta tela são baseadas no Calendário Nacional de '
    'Vacinação do Ministério da Saúde. Elas têm caráter informativo e não '
    'substituem a avaliação da equipe de saúde. Mantenha seu Cartão de '
    'Vacinas atualizado e confirme as orientações para sua gestação com um '
    'profissional de saúde.';

/// Componentes vacinais que as regras deste calendário levam em conta.
///
/// Existe porque o intervalo do dT não é contado desde a última dose de dT,
/// e sim desde a última dose que contenha estes componentes — que pode ter
/// vindo de outra vacina, como a dTpa.
enum ComponenteVacinal {
  difterico('DIFTERICO'),
  tetanico('TETANICO'),
  pertussis('PERTUSSIS');

  const ComponenteVacinal(this.codigo);

  /// Valor estável, independente do nome da constante em Dart.
  final String codigo;
}

/// Unidade em que o calendário expressa um intervalo.
///
/// O calendário usa dias em umas regras e meses em outras. Converter meses
/// para dias seria uma interpretação — 6 meses é aritmética de calendário e
/// o resultado varia conforme os meses envolvidos. A unidade viaja junto
/// com o número, e a engine decide como contar cada uma.
enum UnidadeIntervalo {
  dias('DIAS'),
  meses('MESES');

  const UnidadeIntervalo(this.codigo);

  final String codigo;
}

/// Um intervalo do calendário: valor e unidade, sem conversão.
final class Intervalo {
  final int valor;
  final UnidadeIntervalo unidade;

  const Intervalo.dias(this.valor) : unidade = UnidadeIntervalo.dias;
  const Intervalo.meses(this.valor) : unidade = UnidadeIntervalo.meses;

  @override
  bool operator ==(Object other) =>
      other is Intervalo && other.valor == valor && other.unidade == unidade;

  @override
  int get hashCode => Object.hash(valor, unidade);

  @override
  String toString() => '$valor ${unidade.codigo.toLowerCase()}';
}

/// Intervalo previsto entre duas doses de um mesmo esquema.
///
/// Doses são numeradas a partir de 1. O calendário pode definir apenas o
/// mínimo, apenas o recomendado, ou os dois — `null` significa "não
/// definido para este par", nunca "sem exigência".
final class IntervaloEntreDoses {
  /// Número da dose de onde o intervalo é contado (1 = primeira dose).
  final int doseInicial;

  /// Número da dose até onde o intervalo é contado.
  final int doseFinal;

  final Intervalo? recomendado;
  final Intervalo? minimo;

  const IntervaloEntreDoses({
    required this.doseInicial,
    required this.doseFinal,
    this.recomendado,
    this.minimo,
  });

  @override
  String toString() => 'dose $doseInicial → $doseFinal';
}

/// Como a especificação agrupa a recomendação.
///
/// Serve para exibição e agrupamento. Não substitui o tipo da regra, que é
/// o que a engine usa para decidir como avaliar.
enum CategoriaVacina {
  /// Janela que abre sozinha a partir de uma semana gestacional.
  janelaAutomatica('JANELA_AUTOMATICA'),

  /// Depende de histórico, temporada ou intervalo — nunca só da semana.
  condicional('CONDICIONAL'),

  /// Situação excepcional, fora do fluxo automático.
  excepcional('EXCEPCIONAL');

  const CategoriaVacina(this.codigo);

  final String codigo;
}

/// Uma recomendação do calendário.
///
/// Hierarquia selada de propósito: cada subtipo carrega **apenas** os
/// parâmetros que fazem sentido para a sua forma de avaliação. Uma regra
/// que exige avaliação profissional não tem onde guardar uma semana
/// inicial, então não há como transformá-la em janela automática por
/// descuido — a garantia é do compilador, não de convenção.
///
/// Selar a hierarquia também obriga a engine a tratar todos os casos: um
/// `switch` sobre [RegraCalendario] não compila se um tipo novo aparecer sem
/// tratamento.
sealed class RegraCalendario {
  /// Código estável, independente do nome da constante em Dart e do nome
  /// de exibição. É a chave usada por `RegistroVacinacao.vacinaCodigo`.
  final String codigo;

  final String nomeExibicao;

  final CategoriaVacina categoria;

  final String versaoCalendario;

  /// Quantas doses a regra prevê **por gestação**, quando ela se organiza
  /// assim.
  ///
  /// `null` significa que a regra não se organiza por gestação — hepatite B
  /// e dT seguem esquema de vida, e influenza se organiza por temporada.
  /// Nunca significa "sem limite".
  final int? dosesPorGestacao;

  /// Componentes que uma dose **desta** vacina contém.
  ///
  /// É o que permite à engine reconhecer que uma dose de dTpa também conta
  /// como dose contendo componentes diftérico e tetânico, sem que ela
  /// precise saber composição de vacina por conta própria.
  ///
  /// Vazio significa que esta versão do calendário não declara componentes
  /// relevantes para as suas regras de intervalo — não é uma afirmação
  /// sobre a composição farmacológica da vacina.
  final Set<ComponenteVacinal> composicao;

  const RegraCalendario({
    required this.codigo,
    required this.nomeExibicao,
    required this.categoria,
    required this.versaoCalendario,
    this.dosesPorGestacao,
    this.composicao = const {},
  });

  /// Se a indicação depende, por definição, de avaliação de um
  /// profissional — isto é, se o app **não pode** concluir sozinho que a
  /// vacina está indicada.
  ///
  /// Não confundir com a orientação geral de confirmar tudo com a equipe
  /// de saúde, que vale para todas as recomendações desta tela.
  bool get exigeAvaliacaoProfissional;

  /// Se esta versão do calendário já traz todos os parâmetros que a
  /// avaliação desta regra precisa.
  ///
  /// Quando `false`, a engine não tem base para computar a situação e não
  /// deve afirmar nada — o parâmetro está ausente, o que é diferente de
  /// "não há exigência".
  bool get parametrosCompletos;
}

/// Janela que abre a partir de uma semana gestacional.
///
/// Único subtipo que guarda [semanaInicial]: é o único cuja abertura
/// depende apenas da idade gestacional.
final class RegraJanelaSemana extends RegraCalendario {
  /// Semana gestacional a partir da qual a janela abre.
  final int semanaInicial;

  const RegraJanelaSemana({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    required this.semanaInicial,
    required super.dosesPorGestacao,
    super.composicao,
    super.categoria = CategoriaVacina.janelaAutomatica,
  });

  @override
  bool get exigeAvaliacaoProfissional => false;

  @override
  bool get parametrosCompletos => dosesPorGestacao != null;
}

/// Depende do histórico vacinal da usuária.
///
/// O calendário fornece os parâmetros do esquema; **interpretar** o
/// histórico contra eles — decidir se está completo, incompleto ou
/// desconhecido — é da engine, não daqui.
///
/// Duas formas de intervalo convivem aqui porque a fonte oficial as
/// expressa de modos diferentes: a hepatite B define intervalos **entre
/// doses numeradas** do próprio esquema ([intervalosEntreDoses]), enquanto
/// o dT define um intervalo **desde a última dose que contenha certos
/// componentes** ([intervaloRecomendadoDesdeUltimaDose]), que pode ter
/// vindo de outra vacina.
final class RegraDependeHistorico extends RegraCalendario {
  /// Número de doses do esquema básico.
  final int dosesDoEsquemaBasico;

  /// Se um esquema já iniciado deve ser reiniciado.
  ///
  /// `false` significa completar o que falta, não ignorar o histórico.
  final bool reiniciaEsquemaIniciado;

  /// Intervalos previstos entre doses numeradas deste esquema.
  ///
  /// Vazio quando o calendário não define intervalos internos.
  final List<IntervaloEntreDoses> intervalosEntreDoses;

  /// Componentes que uma dose precisa conter para entrar na contagem de
  /// [intervaloRecomendadoDesdeUltimaDose].
  ///
  /// Vazio quando a regra não define esse tipo de intervalo.
  final Set<ComponenteVacinal> componentesDoIntervalo;

  /// Intervalo recomendado desde a última dose que contenha
  /// [componentesDoIntervalo]. `null` quando a regra não o define.
  final Intervalo? intervaloRecomendadoDesdeUltimaDose;

  /// Intervalo mínimo admitido em situação excepcional, desde a última
  /// dose que contenha [componentesDoIntervalo].
  final Intervalo? intervaloMinimoExcepcionalDesdeUltimaDose;

  const RegraDependeHistorico({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    required this.dosesDoEsquemaBasico,
    required this.reiniciaEsquemaIniciado,
    this.intervalosEntreDoses = const [],
    this.componentesDoIntervalo = const {},
    this.intervaloRecomendadoDesdeUltimaDose,
    this.intervaloMinimoExcepcionalDesdeUltimaDose,
    super.composicao,
    super.categoria = CategoriaVacina.condicional,
    super.dosesPorGestacao,
  });

  @override
  bool get exigeAvaliacaoProfissional => false;

  /// Exige o esquema e a conduta sobre reinício. Um intervalo desde a
  /// última dose declarado sem os componentes que o qualificam seria
  /// incompleto: a engine não saberia quais doses contar.
  @override
  bool get parametrosCompletos {
    if (dosesDoEsquemaBasico <= 0) return false;
    if (intervaloRecomendadoDesdeUltimaDose != null &&
        componentesDoIntervalo.isEmpty) {
      return false;
    }
    return true;
  }
}

/// Depende da temporada e da dose daquela temporada.
///
/// O calendário define quantas doses cabem por temporada. **Qual** é a
/// temporada vigente numa data não é parâmetro deste arquivo: a fonte
/// oficial não fixa limites de início e fim, então essa determinação fica
/// para um serviço explícito na engine.
final class RegraDependeTemporada extends RegraCalendario {
  /// Doses previstas por temporada.
  final int dosesPorTemporada;

  const RegraDependeTemporada({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    required this.dosesPorTemporada,
    super.composicao,
    super.categoria = CategoriaVacina.condicional,
  });

  @override
  bool get exigeAvaliacaoProfissional => false;

  @override
  bool get parametrosCompletos => dosesPorTemporada > 0;
}

/// Depende do intervalo mínimo desde a última dose.
final class RegraDependeIntervaloUltimaDose extends RegraCalendario {
  /// Intervalo mínimo desde a última dose, quando houve vacinação
  /// anterior.
  final Intervalo intervaloMinimoDesdeUltimaDose;

  const RegraDependeIntervaloUltimaDose({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    required this.intervaloMinimoDesdeUltimaDose,
    required super.dosesPorGestacao,
    super.composicao,
    super.categoria = CategoriaVacina.condicional,
  });

  @override
  bool get exigeAvaliacaoProfissional => false;

  @override
  bool get parametrosCompletos =>
      intervaloMinimoDesdeUltimaDose.valor > 0 && dosesPorGestacao != null;
}

/// Situação excepcional: nunca recomendada automaticamente.
///
/// Não tem semana inicial nem qualquer parâmetro que permita abrir uma
/// janela — por construção, não há como esta regra virar uma janela
/// automática. A indicação depende de avaliação profissional, sempre.
final class RegraAvaliacaoProfissional extends RegraCalendario {
  const RegraAvaliacaoProfissional({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    super.categoria = CategoriaVacina.excepcional,
  });

  @override
  bool get exigeAvaliacaoProfissional => true;

  /// A regra é completa: não depende de parâmetro nenhum para dizer que a
  /// avaliação é profissional.
  @override
  bool get parametrosCompletos => true;
}

// ── Códigos estáveis ────────────────────────────────────────────────────
//
// Independentes dos nomes das constantes Dart e dos nomes de exibição:
// renomear qualquer um dos dois não invalida registros já gravados.

const String codigoHepatiteB = 'HEPATITE_B';
const String codigoDt = 'DT';
const String codigoInfluenza = 'INFLUENZA';
const String codigoCovid19 = 'COVID_19';
const String codigoDtpa = 'DTPA';
const String codigoVsr = 'VSR';
const String codigoFebreAmarela = 'FEBRE_AMARELA';

/// As sete recomendações da gestante na versão PNI-2026.
///
/// Lista constante: mesma ordem, mesmos valores, em qualquer execução.
const List<RegraCalendario> calendarioPni2026 = [
  RegraDependeHistorico(
    codigo: codigoHepatiteB,
    nomeExibicao: 'Hepatite B',
    versaoCalendario: versaoCalendarioPni2026,
    dosesDoEsquemaBasico: 3,
    reiniciaEsquemaIniciado: false,
    intervalosEntreDoses: [
      IntervaloEntreDoses(
        doseInicial: 1,
        doseFinal: 2,
        recomendado: Intervalo.meses(1),
        minimo: Intervalo.meses(1),
      ),
      IntervaloEntreDoses(
        doseInicial: 2,
        doseFinal: 3,
        minimo: Intervalo.meses(2),
      ),
      IntervaloEntreDoses(
        doseInicial: 1,
        doseFinal: 3,
        recomendado: Intervalo.meses(6),
        minimo: Intervalo.meses(4),
      ),
    ],
  ),
  RegraDependeHistorico(
    codigo: codigoDt,
    nomeExibicao: 'dT',
    versaoCalendario: versaoCalendarioPni2026,
    dosesDoEsquemaBasico: 3,
    reiniciaEsquemaIniciado: false,
    composicao: {
      ComponenteVacinal.difterico,
      ComponenteVacinal.tetanico,
    },
    componentesDoIntervalo: {
      ComponenteVacinal.difterico,
      ComponenteVacinal.tetanico,
    },
    intervaloRecomendadoDesdeUltimaDose: Intervalo.dias(60),
    intervaloMinimoExcepcionalDesdeUltimaDose: Intervalo.dias(30),
  ),
  RegraDependeTemporada(
    codigo: codigoInfluenza,
    nomeExibicao: 'Influenza',
    versaoCalendario: versaoCalendarioPni2026,
    dosesPorTemporada: 1,
  ),
  RegraDependeIntervaloUltimaDose(
    codigo: codigoCovid19,
    nomeExibicao: 'COVID-19',
    versaoCalendario: versaoCalendarioPni2026,
    intervaloMinimoDesdeUltimaDose: Intervalo.meses(6),
    dosesPorGestacao: 1,
  ),
  RegraJanelaSemana(
    codigo: codigoDtpa,
    nomeExibicao: 'dTpa',
    versaoCalendario: versaoCalendarioPni2026,
    semanaInicial: 20,
    dosesPorGestacao: 1,
    composicao: {
      ComponenteVacinal.difterico,
      ComponenteVacinal.tetanico,
      ComponenteVacinal.pertussis,
    },
  ),
  RegraJanelaSemana(
    codigo: codigoVsr,
    nomeExibicao: 'VSR',
    versaoCalendario: versaoCalendarioPni2026,
    semanaInicial: 28,
    dosesPorGestacao: 1,
  ),
  RegraAvaliacaoProfissional(
    codigo: codigoFebreAmarela,
    nomeExibicao: 'Febre amarela',
    versaoCalendario: versaoCalendarioPni2026,
  ),
];

/// Busca uma regra pelo código estável, ou `null` se não existir nesta
/// versão do calendário.
RegraCalendario? regraPorCodigo(String codigo) {
  for (final regra in calendarioPni2026) {
    if (regra.codigo == codigo) return regra;
  }
  return null;
}

/// Códigos das vacinas cuja dose contém **todos** os [componentes]
/// pedidos, segundo a composição declarada neste calendário.
///
/// Consulta sobre dados, não decisão clínica: responde "quais vacinas deste
/// calendário contêm estes componentes", e não "esta dose conta para o
/// intervalo de fulano" — isso é da engine.
Set<String> codigosComComponentes(Set<ComponenteVacinal> componentes) {
  if (componentes.isEmpty) return const {};

  return calendarioPni2026
      .where((regra) => regra.composicao.containsAll(componentes))
      .map((regra) => regra.codigo)
      .toSet();
}
