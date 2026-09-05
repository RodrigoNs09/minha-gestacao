library;

const String versaoCalendarioPni2026 = 'PNI-2026';

const String mensagemPeriodoRecomendado =
    'Você entrou no período recomendado para esta vacina. Confirme a '
    'indicação e a aplicação com a equipe de saúde.';

const String mensagemGeralVacinas =
    'As informações desta tela são baseadas no Calendário Nacional de '
    'Vacinação do Ministério da Saúde. Elas têm caráter informativo e não '
    'substituem a avaliação da equipe de saúde. Mantenha seu Cartão de '
    'Vacinas atualizado e confirme as orientações para sua gestação com um '
    'profissional de saúde.';

enum ComponenteVacinal {
  difterico('DIFTERICO'),
  tetanico('TETANICO'),
  pertussis('PERTUSSIS');

  const ComponenteVacinal(this.codigo);

  final String codigo;
}

enum UnidadeIntervalo {
  dias('DIAS'),
  meses('MESES');

  const UnidadeIntervalo(this.codigo);

  final String codigo;
}

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

final class IntervaloEntreDoses {
  final int doseInicial;

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

enum CategoriaVacina {
  janelaAutomatica('JANELA_AUTOMATICA'),

  condicional('CONDICIONAL'),

  excepcional('EXCEPCIONAL');

  const CategoriaVacina(this.codigo);

  final String codigo;
}

sealed class RegraCalendario {
  final String codigo;

  final String nomeExibicao;

  final CategoriaVacina categoria;

  final String versaoCalendario;

  final int? dosesPorGestacao;

  final Set<ComponenteVacinal> composicao;

  const RegraCalendario({
    required this.codigo,
    required this.nomeExibicao,
    required this.categoria,
    required this.versaoCalendario,
    this.dosesPorGestacao,
    this.composicao = const {},
  });

  bool get exigeAvaliacaoProfissional;

  bool get parametrosCompletos;
}

final class RegraJanelaSemana extends RegraCalendario {
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

final class RegraDependeHistorico extends RegraCalendario {
  final int dosesDoEsquemaBasico;

  final bool reiniciaEsquemaIniciado;

  final List<IntervaloEntreDoses> intervalosEntreDoses;

  final Set<ComponenteVacinal> componentesDoIntervalo;

  final Intervalo? intervaloRecomendadoDesdeUltimaDose;

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

final class RegraDependeTemporada extends RegraCalendario {
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

final class RegraDependeIntervaloUltimaDose extends RegraCalendario {
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

final class RegraAvaliacaoProfissional extends RegraCalendario {
  const RegraAvaliacaoProfissional({
    required super.codigo,
    required super.nomeExibicao,
    required super.versaoCalendario,
    super.categoria = CategoriaVacina.excepcional,
  });

  @override
  bool get exigeAvaliacaoProfissional => true;

  @override
  bool get parametrosCompletos => true;
}


const String codigoHepatiteB = 'HEPATITE_B';
const String codigoDt = 'DT';
const String codigoInfluenza = 'INFLUENZA';
const String codigoCovid19 = 'COVID_19';
const String codigoDtpa = 'DTPA';
const String codigoVsr = 'VSR';
const String codigoFebreAmarela = 'FEBRE_AMARELA';

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

RegraCalendario? regraPorCodigo(String codigo) {
  for (final regra in calendarioPni2026) {
    if (regra.codigo == codigo) return regra;
  }
  return null;
}

Set<String> codigosComComponentes(Set<ComponenteVacinal> componentes) {
  if (componentes.isEmpty) return const {};

  return calendarioPni2026
      .where((regra) => regra.composicao.containsAll(componentes))
      .map((regra) => regra.codigo)
      .toSet();
}
