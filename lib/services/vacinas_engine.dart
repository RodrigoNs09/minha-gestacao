library;

import '../data/vacinas_calendario_2026.dart';
import '../models/registro_vacinacao.dart';

enum EstadoVacina {
  /// A janela ainda não abriu.
  naoDisponivel('NAO_DISPONIVEL'),

  /// A janela está aberta. Nunca significa "tome agora": a mensagem
  /// associada orienta confirmar com a equipe de saúde.
  periodoRecomendado('PERIODO_RECOMENDADO'),

  /// Falta informação para determinar a situação com segurança.
  verificarHistorico('VERIFICAR_HISTORICO'),

  /// Há um intervalo mínimo a cumprir desde uma dose anterior.
  aguardarIntervalo('AGUARDAR_INTERVALO'),

  /// A usuária registrou a dose. Registro dela, não validação do sistema.
  registrada('REGISTRADA'),

  /// A indicação depende de avaliação de um profissional.
  avaliacaoProfissional('AVALIACAO_PROFISSIONAL'),

  /// A recomendação não se aplica.
  naoIndicada('NAO_INDICADA');

  const EstadoVacina(this.codigo);
  final String codigo;
}

enum NivelAtencao {
  /// Nada a fazer agora.
  nenhum('NENHUM'),

  /// Vale saber, sem ação imediata.
  informativo('INFORMATIVO'),

  /// Vale levar à equipe de saúde.
  atencao('ATENCAO');

  const NivelAtencao(this.codigo);

  final String codigo;
}

/// Mapeamento explícito de estado para nível de atenção.
NivelAtencao nivelDoEstado(EstadoVacina estado) {
  switch (estado) {
    case EstadoVacina.naoDisponivel:
    case EstadoVacina.registrada:
    case EstadoVacina.naoIndicada:
      return NivelAtencao.nenhum;
    case EstadoVacina.aguardarIntervalo:
      return NivelAtencao.informativo;
    case EstadoVacina.periodoRecomendado:
    case EstadoVacina.verificarHistorico:
    case EstadoVacina.avaliacaoProfissional:
      return NivelAtencao.atencao;
  }
}

final class ProximaJanela {
  /// Semana gestacional em que a janela abre.
  final int semanaGestacional;

  /// Data estimada de abertura, derivada da DUM. Estimativa aritmética,
  /// não uma data marcada por ninguém.
  final DateTime dataEstimada;

  const ProximaJanela({
    required this.semanaGestacional,
    required this.dataEstimada,
  });

  @override
  bool operator ==(Object other) =>
      other is ProximaJanela &&
      other.semanaGestacional == semanaGestacional &&
      other.dataEstimada == dataEstimada;

  @override
  int get hashCode => Object.hash(semanaGestacional, dataEstimada);

  @override
  String toString() => 'semana $semanaGestacional ($dataEstimada)';
}

/// Resultado da avaliação de uma vacina. Derivado, nunca persistido.
final class StatusVacinacao {
  final String vacinaCodigo;
  final EstadoVacina estado;

  final String mensagem;

  final NivelAtencao nivelAtencao;

  final ProximaJanela? proximaJanela;

  final bool podeRegistrar;

  final String motivo;

  const StatusVacinacao({
    required this.vacinaCodigo,
    required this.estado,
    required this.mensagem,
    required this.nivelAtencao,
    required this.podeRegistrar,
    required this.motivo,
    this.proximaJanela,
  });

  @override
  String toString() => '$vacinaCodigo: ${estado.codigo} ($motivo)';
}

const String mensagemDoseRegistrada = 'Registrada por você.';

const String mensagemJanelaNaoAberta =
    'O período recomendado para esta vacina ainda não começou nesta '
    'gestação.';

const String mensagemGestacaoIndeterminada =
    'Não foi possível determinar a idade gestacional a partir da data '
    'informada. Confirme as orientações com a equipe de saúde.';

const String mensagemAvaliacaoProfissional =
    'Esta vacina depende de avaliação da equipe de saúde para a sua '
    'situação.';

const String mensagemVerificarHistorico =
    'Não é possível determinar esta situação com as informações '
    'disponíveis. Confirme seu histórico com a equipe de saúde.';

const String mensagemAguardarIntervalo =
    'Ainda não foi cumprido o intervalo mínimo desde a última dose '
    'registrada. Confirme as orientações com a equipe de saúde.';

DateTime adicionarMeses(DateTime data, int meses) {
  final totalMeses = data.month - 1 + meses;
  final ano = data.year + (totalMeses ~/ 12);
  final mes = (totalMeses % 12) + 1;

  final ultimoDiaDoMes = DateTime(ano, mes + 1, 0).day;
  final dia = data.day <= ultimoDiaDoMes ? data.day : ultimoDiaDoMes;

  return DateTime(ano, mes, dia);
}

const int diasGestacaoMinimoPlausivel = 0;

const int diasGestacaoMaximoPlausivel = 294;

bool gestacaoPlausivel(int diasGestacaoBruto) =>
    diasGestacaoBruto >= diasGestacaoMinimoPlausivel &&
    diasGestacaoBruto <= diasGestacaoMaximoPlausivel;


int semanaGestacionalDe(int diasGestacaoBruto) => diasGestacaoBruto ~/ 7;

class VacinasEngine {
  const VacinasEngine._();
  static List<StatusVacinacao> avaliar({
    required int diasGestacaoBruto,
    required DateTime dum,
    required DateTime dataAtual,
    required List<RegistroVacinacao> historico,
    required List<RegraCalendario> calendario,
    String? temporadaInfluenza,
  }) {
    return [
      for (final regra in calendario)
        _avaliarRegra(
          regra: regra,
          diasGestacaoBruto: diasGestacaoBruto,
          dum: dum,
          dataAtual: dataAtual,
          historico: historico,
          temporadaInfluenza: temporadaInfluenza,
        ),
    ];
  }

  static StatusVacinacao _avaliarRegra({
    required RegraCalendario regra,
    required int diasGestacaoBruto,
    required DateTime dum,
    required DateTime dataAtual,
    required List<RegistroVacinacao> historico,
    required String? temporadaInfluenza,
  }) {
    
    switch (regra) {
      case RegraAvaliacaoProfissional():
        return StatusVacinacao(
          vacinaCodigo: regra.codigo,
          estado: EstadoVacina.avaliacaoProfissional,
          mensagem: mensagemAvaliacaoProfissional,
          nivelAtencao: nivelDoEstado(EstadoVacina.avaliacaoProfissional),
          podeRegistrar: true,
          motivo: 'regra excepcional: indicação depende de avaliação profissional',
        );

      case RegraJanelaSemana():
        return _avaliarJanelaSemana(
          regra: regra,
          diasGestacaoBruto: diasGestacaoBruto,
          dum: dum,
          historico: historico,
        );

      case RegraDependeIntervaloUltimaDose():
        return _avaliarIntervaloUltimaDose(
          regra: regra,
          dum: dum,
          dataAtual: dataAtual,
          historico: historico,
        );

      case RegraDependeTemporada():
        return _avaliarTemporada(
          regra: regra,
          historico: historico,
          temporadaVigente: temporadaInfluenza,
        );

      case RegraDependeHistorico():
        return StatusVacinacao(
          vacinaCodigo: regra.codigo,
          estado: EstadoVacina.verificarHistorico,
          mensagem: mensagemVerificarHistorico,
          nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
          podeRegistrar: true,
          motivo: 'avaliação condicional ainda não implementada nesta versão',
        );
    }
  }

  static StatusVacinacao _avaliarTemporada({
    required RegraDependeTemporada regra,
    required List<RegistroVacinacao> historico,
    required String? temporadaVigente,
  }) {
    if (regra.dosesPorTemporada <= 0) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'regra sem doses por temporada declaradas',
      );
    }

    if (temporadaVigente == null) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'temporada vigente não informada',
      );
    }

    final daTemporada = historico
        .where((r) => r.vacinaCodigo == regra.codigo)
        .where((r) => r.temporadaNoRegistro == temporadaVigente)
        .toList(growable: false);

    final aplicadas = daTemporada.where(_declaraDoseAplicada).length;
    if (aplicadas >= regra.dosesPorTemporada) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.registrada,
        mensagem: mensagemDoseRegistrada,
        nivelAtencao: nivelDoEstado(EstadoVacina.registrada),
        podeRegistrar: false,
        motivo: 'doses da temporada $temporadaVigente registradas pela '
            'usuária: $aplicadas de ${regra.dosesPorTemporada}',
      );
    }

    if (daTemporada.any(_temSituacaoIndeterminada)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'há registro desta temporada sem situação determinada',
      );
    }

    return StatusVacinacao(
      vacinaCodigo: regra.codigo,
      estado: EstadoVacina.periodoRecomendado,
      mensagem: mensagemPeriodoRecomendado,
      nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
      podeRegistrar: true,
      motivo: 'sem dose declarada na temporada $temporadaVigente: '
          '$aplicadas de ${regra.dosesPorTemporada}',
    );
  }

  static StatusVacinacao _avaliarIntervaloUltimaDose({
    required RegraDependeIntervaloUltimaDose regra,
    required DateTime dum,
    required DateTime dataAtual,
    required List<RegistroVacinacao> historico,
  }) {
    final registros = historico
        .where((r) => r.vacinaCodigo == regra.codigo)
        .toList(growable: false);

    final destaGestacao = registros
        .where((r) => _pertenceAGestacaoAtual(r, dum))
        .toList(growable: false);

    final dosesPrevistas = regra.dosesPorGestacao;
    if (dosesPrevistas == null) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'regra sem doses por gestação declaradas',
      );
    }

    final aplicadasNestaGestacao = destaGestacao.where(_declaraDoseAplicada).length;
    if (aplicadasNestaGestacao >= dosesPrevistas) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.registrada,
        mensagem: mensagemDoseRegistrada,
        nivelAtencao: nivelDoEstado(EstadoVacina.registrada),
        podeRegistrar: false,
        motivo: 'doses desta gestação registradas pela usuária: '
            '$aplicadasNestaGestacao de $dosesPrevistas',
      );
    }

    if (destaGestacao.any(_temSituacaoIndeterminada)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'há registro desta vacina sem situação determinada',
      );
    }

    final dosesAplicadas =
        registros.where(_declaraDoseAplicada).toList(growable: false);

    if (dosesAplicadas.isEmpty) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.periodoRecomendado,
        mensagem: mensagemPeriodoRecomendado,
        nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
        podeRegistrar: true,
        motivo: 'sem dose anterior declarada; nenhum intervalo a cumprir',
      );
    }

    if (dosesAplicadas.any((r) => r.dataAplicacao == null)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'há dose declarada sem data: intervalo não verificável',
      );
    }

    final ultimaDose = dosesAplicadas
        .map((r) => r.dataAplicacao!)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final liberacao = _somarIntervalo(ultimaDose, regra.intervaloMinimoDesdeUltimaDose);

    if (_naoPosteriorA(liberacao, dataAtual)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.periodoRecomendado,
        mensagem: mensagemPeriodoRecomendado,
        nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
        podeRegistrar: true,
        motivo: 'intervalo de ${regra.intervaloMinimoDesdeUltimaDose} cumprido '
            'desde ${_soData(ultimaDose)}',
      );
    }

    return StatusVacinacao(
      vacinaCodigo: regra.codigo,
      estado: EstadoVacina.aguardarIntervalo,
      mensagem: mensagemAguardarIntervalo,
      nivelAtencao: nivelDoEstado(EstadoVacina.aguardarIntervalo),
      podeRegistrar: true,
      motivo: 'intervalo de ${regra.intervaloMinimoDesdeUltimaDose} desde '
          '${_soData(ultimaDose)} completa em ${_soData(liberacao)}',
    );
  }

  static DateTime _somarIntervalo(DateTime data, Intervalo intervalo) {
    switch (intervalo.unidade) {
      case UnidadeIntervalo.dias:
        return data.add(Duration(days: intervalo.valor));
      case UnidadeIntervalo.meses:
        return adicionarMeses(data, intervalo.valor);
    }
  }

  static bool _naoPosteriorA(DateTime a, DateTime b) =>
      !_soData(a).isAfter(_soData(b));

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  static StatusVacinacao _avaliarJanelaSemana({
    required RegraJanelaSemana regra,
    required int diasGestacaoBruto,
    required DateTime dum,
    required List<RegistroVacinacao> historico,
  }) {
  
    final registrosDestaGestacao = historico
        .where((r) => r.vacinaCodigo == regra.codigo)
        .where((r) => _pertenceAGestacaoAtual(r, dum))
        .toList(growable: false);

    final dosesPrevistas = regra.dosesPorGestacao;
    if (dosesPrevistas == null) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'regra sem doses por gestação declaradas',
      );
    }

    final dosesAplicadas =
        registrosDestaGestacao.where(_declaraDoseAplicada).length;

    if (dosesAplicadas >= dosesPrevistas) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.registrada,
        mensagem: mensagemDoseRegistrada,
        nivelAtencao: nivelDoEstado(EstadoVacina.registrada),
        podeRegistrar: false,
        motivo: 'doses desta gestação registradas pela usuária: '
            '$dosesAplicadas de $dosesPrevistas',
      );
    }

    if (registrosDestaGestacao.any(_temSituacaoIndeterminada)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: 'há registro desta vacina sem situação determinada',
      );
    }

    if (!gestacaoPlausivel(diasGestacaoBruto)) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.avaliacaoProfissional,
        mensagem: mensagemGestacaoIndeterminada,
        nivelAtencao: nivelDoEstado(EstadoVacina.avaliacaoProfissional),
        podeRegistrar: true,
        motivo: 'dias de gestação fora da faixa plausível: $diasGestacaoBruto',
      );
    }

    final semana = semanaGestacionalDe(diasGestacaoBruto);

    if (semana < regra.semanaInicial) {
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.naoDisponivel,
        mensagem: mensagemJanelaNaoAberta,
        nivelAtencao: nivelDoEstado(EstadoVacina.naoDisponivel),
        podeRegistrar: true,
        proximaJanela: ProximaJanela(
          semanaGestacional: regra.semanaInicial,
          dataEstimada: dum.add(Duration(days: regra.semanaInicial * 7)),
        ),
        motivo: 'semana $semana anterior à semana ${regra.semanaInicial}',
      );
    }

    return StatusVacinacao(
      vacinaCodigo: regra.codigo,
      estado: EstadoVacina.periodoRecomendado,
      mensagem: mensagemPeriodoRecomendado,
      nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
      podeRegistrar: true,
      motivo: 'semana $semana dentro da janela a partir de '
          '${regra.semanaInicial}',
    );
  }

  static bool _pertenceAGestacaoAtual(RegistroVacinacao registro, DateTime dum) {
    final dumDoRegistro = registro.dumNoRegistro;
    if (dumDoRegistro == null) return false;

    return _mesmoDia(dumDoRegistro, dum);
  }

  static bool _declaraDoseAplicada(RegistroVacinacao registro) {
    return registro.situacaoInformada == SituacaoInformada.aplicadaComData ||
        registro.situacaoInformada == SituacaoInformada.aplicadaDataDesconhecida;
  }

  static bool _temSituacaoIndeterminada(RegistroVacinacao registro) =>
      registro.situacaoInformada == SituacaoInformada.situacaoDesconhecida;

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
