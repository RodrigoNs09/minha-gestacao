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
          calendario: calendario,
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
    required List<RegraCalendario> calendario,
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
        return regra.intervaloRecomendadoDesdeUltimaDose != null
            ? _avaliarEsquemaPorUltimaDoseRelevante(
                regra: regra,
                diasGestacaoBruto: diasGestacaoBruto,
                dataAtual: dataAtual,
                historico: historico,
                calendario: calendario,
              )
            : _avaliarDependeHistorico(
                regra: regra,
                dataAtual: dataAtual,
                historico: historico,
              );
    }
  }

  static StatusVacinacao _verificar(RegraCalendario regra, String motivo) =>
      StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.verificarHistorico,
        mensagem: mensagemVerificarHistorico,
        nivelAtencao: nivelDoEstado(EstadoVacina.verificarHistorico),
        podeRegistrar: true,
        motivo: motivo,
      );

  /// Motivo da inconsistência na numeração declarada, ou `null` se coerente.
  static String? _inconsistenciaDeNumeracao(
    List<RegistroVacinacao> aplicadas,
    int dosesDoEsquema,
  ) {
    if (aplicadas.any((r) => r.numeroDaDose == null)) {
      return 'há dose declarada sem posição no esquema';
    }

    final numeros = aplicadas.map((r) => r.numeroDaDose!).toList(growable: false);

    if (numeros.any((n) => n < 1 || n > dosesDoEsquema)) {
      return 'há dose com posição fora de 1..$dosesDoEsquema';
    }

    if (numeros.toSet().length != numeros.length) {
      return 'há posições de dose repetidas no esquema';
    }

    // Consistência dos dados, não regra do calendário: uma dose de posição
    // maior tem de ser posterior às anteriores, e datas iguais também são
    // inconsistentes. A posição segue vindo só de numeroDaDose.
    final porNumero = {for (final r in aplicadas) r.numeroDaDose!: r};
    final ordenados = numeros.toList()..sort();
    for (var a = 0; a < ordenados.length - 1; a++) {
      for (var b = a + 1; b < ordenados.length; b++) {
        final anterior = porNumero[ordenados[a]]!.dataAplicacao;
        final posterior = porNumero[ordenados[b]]!.dataAplicacao;
        if (anterior == null || posterior == null) continue;

        if (!_soData(posterior).isAfter(_soData(anterior))) {
          return 'dose ${ordenados[b]} não é posterior à dose ${ordenados[a]}';
        }
      }
    }

    return null;
  }

  /// Se uma dose de outra vacina com os componentes pode abrir o esquema
  /// básico sozinha, sem nenhuma dose da própria vacina para ancorá-la.
  ///
  /// Ela só abre quando a gestação já alcançou a janela em que essa vacina é
  /// indicada — é o que permite ler uma dTpa como primeira dose de quem chega
  /// sem histórico a partir da 20ª semana. A semana vem da regra dela no
  /// calendário, não de um número fixo aqui.
  static bool _podeAbrirOEsquema({
    required RegraCalendario? regraDaDose,
    required int diasGestacaoBruto,
  }) {
    if (regraDaDose is! RegraJanelaSemana) return false;
    if (!gestacaoPlausivel(diasGestacaoBruto)) return false;
    return semanaGestacionalDe(diasGestacaoBruto) >= regraDaDose.semanaInicial;
  }

  /// Doses do esquema básico que o histórico sustenta.
  ///
  /// Com o esquema já completo pelas doses da própria vacina, doses de
  /// outras vacinas são reforço e não ampliam a contagem.
  static int _dosesDoEsquemaBasico({
    required int proprias,
    required int deOutrasVacinas,
    required int dosesDoEsquema,
  }) {
    if (proprias >= dosesDoEsquema) return proprias;

    final vagas = dosesDoEsquema - proprias;
    return proprias + (deOutrasVacinas < vagas ? deOutrasVacinas : vagas);
  }

  /// Esquema cujo intervalo é contado desde a última dose que contenha os
  /// componentes exigidos — o caso do dT no PNI-2026.
  static StatusVacinacao _avaliarEsquemaPorUltimaDoseRelevante({
    required RegraDependeHistorico regra,
    required int diasGestacaoBruto,
    required DateTime dataAtual,
    required List<RegistroVacinacao> historico,
    required List<RegraCalendario> calendario,
  }) {
    if (regra.dosesDoEsquemaBasico <= 0) {
      return _verificar(regra, 'regra sem doses de esquema básico declaradas');
    }

    // Quais vacinas contam vem da composição declarada no calendário, não de
    // códigos fixos aqui.
    final codigosRelevantes = calendario
        .where((r) => r.composicao.containsAll(regra.componentesDoIntervalo))
        .map((r) => r.codigo)
        .toSet();

    final relevantes = historico
        .where((r) => codigosRelevantes.contains(r.vacinaCodigo))
        .where((r) => r.situacaoInformada != SituacaoInformada.naoAplicadaInformado)
        .toList(growable: false);

    if (relevantes.any(_temSituacaoIndeterminada)) {
      return _verificar(regra, 'há registro relevante sem situação determinada');
    }

    final aplicadas = relevantes.where(_declaraDoseAplicada).toList(growable: false);

    if (aplicadas.isEmpty) {
      return _verificar(regra, 'sem dose relevante registrada para determinar o '
          'esquema');
    }

    final proprias =
        aplicadas.where((r) => r.vacinaCodigo == regra.codigo).toList(growable: false);
    final outras =
        aplicadas.where((r) => r.vacinaCodigo != regra.codigo).toList(growable: false);

    final inconsistencia =
        _inconsistenciaDeNumeracao(proprias, regra.dosesDoEsquemaBasico);
    if (inconsistencia != null) return _verificar(regra, inconsistencia);

    // Com alguma dose da própria vacina o esquema já tem âncora, e as doses de
    // outras vacinas apenas preenchem as vagas restantes. Sem âncora nenhuma,
    // só a gestação diz se a outra vacina pode abrir o esquema.
    if (proprias.isEmpty) {
      final porCodigo = {for (final r in calendario) r.codigo: r};

      final semPosicao = outras.any((dose) => !_podeAbrirOEsquema(
            regraDaDose: porCodigo[dose.vacinaCodigo],
            diasGestacaoBruto: diasGestacaoBruto,
          ));

      if (semPosicao) {
        return _verificar(regra, 'sem dose desta vacina e sem contexto '
            'gestacional para posicionar a dose de outra vacina no esquema');
      }
    }

    final totalDoEsquema = _dosesDoEsquemaBasico(
      proprias: proprias.length,
      deOutrasVacinas: outras.length,
      dosesDoEsquema: regra.dosesDoEsquemaBasico,
    );

    if (totalDoEsquema >= regra.dosesDoEsquemaBasico) {
      final deOutras = totalDoEsquema - proprias.length;
      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.registrada,
        mensagem: mensagemDoseRegistrada,
        nivelAtencao: nivelDoEstado(EstadoVacina.registrada),
        podeRegistrar: false,
        motivo: 'esquema de ${regra.dosesDoEsquemaBasico} doses completo: '
            '${proprias.length} de ${regra.codigo} e $deOutras de outra vacina '
            'com os componentes',
      );
    }

    if (aplicadas.any((r) => r.dataAplicacao == null)) {
      return _verificar(regra, 'há dose relevante sem data: intervalo não '
          'verificável');
    }

    final ultima = aplicadas
        .map((r) => r.dataAplicacao!)
        .reduce((a, b) => a.isAfter(b) ? a : b);

    final recomendado = regra.intervaloRecomendadoDesdeUltimaDose!;
    final liberacao = _somarIntervalo(ultima, recomendado);

    if (!_naoPosteriorA(liberacao, dataAtual)) {
      final excepcional = regra.intervaloMinimoExcepcionalDesdeUltimaDose;
      final minimoCumprido = excepcional != null &&
          _naoPosteriorA(_somarIntervalo(ultima, excepcional), dataAtual);

      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.aguardarIntervalo,
        mensagem: mensagemAguardarIntervalo,
        nivelAtencao: nivelDoEstado(EstadoVacina.aguardarIntervalo),
        podeRegistrar: true,
        motivo: minimoCumprido
            // A caracterização da exceção é do profissional; a engine apenas
            // registra que o mínimo excepcional já passou.
            ? 'dose ${totalDoEsquema + 1}: mínimo excepcional de $excepcional '
                'cumprido desde ${_soData(ultima)}, recomendado de $recomendado '
                'completa em ${_soData(liberacao)}'
            : 'dose ${totalDoEsquema + 1}: intervalo recomendado de $recomendado '
                'desde ${_soData(ultima)} completa em ${_soData(liberacao)}',
      );
    }

    return StatusVacinacao(
      vacinaCodigo: regra.codigo,
      estado: EstadoVacina.periodoRecomendado,
      mensagem: mensagemPeriodoRecomendado,
      nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
      podeRegistrar: true,
      motivo: 'dose ${totalDoEsquema + 1} de ${regra.dosesDoEsquemaBasico}: '
          'intervalo recomendado cumprido desde ${_soData(ultima)}',
    );
  }

  static StatusVacinacao _avaliarDependeHistorico({
    required RegraDependeHistorico regra,
    required DateTime dataAtual,
    required List<RegistroVacinacao> historico,
  }) {
    StatusVacinacao verificar(String motivo) => _verificar(regra, motivo);

    if (regra.dosesDoEsquemaBasico <= 0) {
      return verificar('regra sem doses de esquema básico declaradas');
    }

    final relevantes = historico
        .where((r) => r.vacinaCodigo == regra.codigo)
        .where((r) => r.situacaoInformada != SituacaoInformada.naoAplicadaInformado)
        .toList(growable: false);

    if (relevantes.any(_temSituacaoIndeterminada)) {
      return verificar('há registro desta vacina sem situação determinada');
    }

    final aplicadas = relevantes.where(_declaraDoseAplicada).toList(growable: false);

    if (aplicadas.isEmpty) {
      // Esquema de vida: sem registro não se conclui que a usuária nunca
      // recebeu as doses, então também não se afirma que deve iniciar.
      return verificar('sem dose registrada para determinar o esquema');
    }

    final inconsistencia =
        _inconsistenciaDeNumeracao(aplicadas, regra.dosesDoEsquemaBasico);
    if (inconsistencia != null) return verificar(inconsistencia);

    final numeros = aplicadas.map((r) => r.numeroDaDose!).toList(growable: false);
    final porNumero = {for (final r in aplicadas) r.numeroDaDose!: r};

    if (numeros.length >= regra.dosesDoEsquemaBasico) {
      // Ter as posições preenchidas não basta: o esquema só é dado como
      // registrado se as datas respeitarem os intervalos mínimos declarados.
      for (final intervalo in regra.intervalosEntreDoses) {
        final inicial = porNumero[intervalo.doseInicial];
        final ultima = porNumero[intervalo.doseFinal];
        if (inicial == null || ultima == null) continue;

        final dataInicial = inicial.dataAplicacao;
        final dataUltima = ultima.dataAplicacao;
        if (dataInicial == null || dataUltima == null) {
          return verificar('dose sem data: intervalo entre as doses '
              '${intervalo.doseInicial} e ${intervalo.doseFinal} não verificável');
        }

        final minimo = intervalo.minimo;
        if (minimo == null) continue;

        if (!_naoPosteriorA(_somarIntervalo(dataInicial, minimo), dataUltima)) {
          return verificar('intervalo mínimo de $minimo entre as doses '
              '${intervalo.doseInicial} e ${intervalo.doseFinal} não cumprido');
        }
      }

      return StatusVacinacao(
        vacinaCodigo: regra.codigo,
        estado: EstadoVacina.registrada,
        mensagem: mensagemDoseRegistrada,
        nivelAtencao: nivelDoEstado(EstadoVacina.registrada),
        podeRegistrar: false,
        motivo: 'esquema de ${regra.dosesDoEsquemaBasico} doses registrado pela '
            'usuária',
      );
    }

    var proxima = regra.dosesDoEsquemaBasico;
    for (var n = 1; n <= regra.dosesDoEsquemaBasico; n++) {
      if (!porNumero.containsKey(n)) {
        proxima = n;
        break;
      }
    }

    final intervalos = regra.intervalosEntreDoses
        .where((i) => i.doseFinal == proxima)
        .toList(growable: false);

    if (intervalos.isEmpty) {
      return verificar('sem intervalo declarado para a dose $proxima');
    }

    for (final intervalo in intervalos) {
      final referencia = porNumero[intervalo.doseInicial];
      if (referencia == null) {
        return verificar('falta a dose ${intervalo.doseInicial}, exigida para '
            'avaliar a dose $proxima');
      }
      if (referencia.dataAplicacao == null) {
        return verificar('dose ${intervalo.doseInicial} sem data: intervalo até '
            'a dose $proxima não verificável');
      }
    }

    // Mínimo antes do recomendado: os dois levam a AGUARDAR_INTERVALO, e o
    // motivo distingue quem já cumpriu o mínimo.
    for (final intervalo in intervalos) {
      final minimo = intervalo.minimo;
      if (minimo == null) continue;

      final referencia = porNumero[intervalo.doseInicial]!.dataAplicacao!;
      final liberacao = _somarIntervalo(referencia, minimo);

      if (!_naoPosteriorA(liberacao, dataAtual)) {
        return StatusVacinacao(
          vacinaCodigo: regra.codigo,
          estado: EstadoVacina.aguardarIntervalo,
          mensagem: mensagemAguardarIntervalo,
          nivelAtencao: nivelDoEstado(EstadoVacina.aguardarIntervalo),
          podeRegistrar: true,
          motivo: 'dose $proxima: intervalo mínimo de $minimo desde a dose '
              '${intervalo.doseInicial} completa em ${_soData(liberacao)}',
        );
      }
    }

    for (final intervalo in intervalos) {
      final recomendado = intervalo.recomendado;
      if (recomendado == null) continue;

      final referencia = porNumero[intervalo.doseInicial]!.dataAplicacao!;
      final liberacao = _somarIntervalo(referencia, recomendado);

      if (!_naoPosteriorA(liberacao, dataAtual)) {
        return StatusVacinacao(
          vacinaCodigo: regra.codigo,
          estado: EstadoVacina.aguardarIntervalo,
          mensagem: mensagemAguardarIntervalo,
          nivelAtencao: nivelDoEstado(EstadoVacina.aguardarIntervalo),
          podeRegistrar: true,
          motivo: 'dose $proxima: intervalo mínimo cumprido, recomendado de '
              '$recomendado desde a dose ${intervalo.doseInicial} completa em '
              '${_soData(liberacao)}',
        );
      }
    }

    return StatusVacinacao(
      vacinaCodigo: regra.codigo,
      estado: EstadoVacina.periodoRecomendado,
      mensagem: mensagemPeriodoRecomendado,
      nivelAtencao: nivelDoEstado(EstadoVacina.periodoRecomendado),
      podeRegistrar: true,
      motivo: 'dose $proxima de ${regra.dosesDoEsquemaBasico}: intervalos '
          'recomendados cumpridos',
    );
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
