/// Motor de regras de vacinação da gestante.
///
/// Puro e determinístico: mesmas entradas, mesma saída, sempre. Não toca
/// Firebase, Firestore, Flutter nem `BuildContext`, e **nunca** chama
/// `DateTime.now()` — a data corrente entra como parâmetro. É o que permite
/// testar "o que acontece exatamente na semana 20" sem depender do relógio
/// da máquina, e o que permite testá-lo na infraestrutura de teste atual do
/// projeto, que não tem mocks de Firestore.
///
/// A engine **calcula** estados; não os persiste. [StatusVacinacao] é
/// resultado derivado, recomputado a cada avaliação — como `GestacaoInfo`,
/// nunca vai para o Firestore.
library;

import '../data/vacinas_calendario_2026.dart';
import '../models/registro_vacinacao.dart';

/// Situação de uma vacina para uma gestante, num instante.
///
/// Sete estados aprovados na especificação funcional.
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

  /// Valor estável, independente do nome da constante em Dart.
  final String codigo;
}

/// Quanto destaque a situação merece na interface.
///
/// Derivado do estado por um mapeamento explícito ([nivelDoEstado]), e não
/// escolhido caso a caso na UI — é o que impede a interface de inventar
/// urgência que a regra não tem.
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

/// Quando uma janela ainda fechada deve abrir.
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

  /// Texto para a usuária. Nunca prescritivo.
  final String mensagem;

  final NivelAtencao nivelAtencao;

  /// Preenchido quando a janela ainda não abriu e há uma data prevista.
  final ProximaJanela? proximaJanela;

  /// Se faz sentido oferecer o registro de uma dose agora.
  final bool podeRegistrar;

  /// Por que a engine chegou a este estado. Diagnóstico interno — serve
  /// para depuração e para testes, não é texto de interface.
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

// ── Mensagens da engine ─────────────────────────────────────────────────
//
// A mensagem de período recomendado vem do calendário
// ([mensagemPeriodoRecomendado]), porque é texto aprovado na especificação.
// As demais descrevem estados que a especificação não redigiu, e seguem o
// mesmo princípio: nunca afirmam conduta, nunca dizem "validada".

/// Registro é declaração da usuária, não validação do sistema.
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

// ── Aritmética de calendário ────────────────────────────────────────────

/// Soma [meses] a [data] respeitando o calendário, não uma quantidade fixa
/// de dias.
///
/// Somar `Duration(days: 180)` daria resultados diferentes conforme os
/// meses envolvidos, e não é o que o calendário quer dizer com "6 meses".
///
/// ## Convenção de cálculo deste aplicativo — não é regra do PNI
///
/// Quando o dia de origem não existe no mês de destino (31/08 + 6 meses
/// cairia em 31/02), a data resultante é o **último dia** do mês de
/// destino: 28/02, ou 29/02 em ano bissexto.
///
/// Esta é uma decisão de implementação, adotada por ser determinística e
/// por antecipar a data de liberação em vez de adiá-la. **Não** foi
/// encontrada orientação do Ministério da Saúde sobre esse caso — a
/// Instrução Normativa do Calendário Nacional de Vacinação define os
/// intervalos, não a aritmética de datas para dias inexistentes. Portanto
/// esta convenção não deve ser apresentada à usuária, nem em código nem em
/// interface, como se fosse orientação oficial.
///
/// Se uma orientação oficial vier a existir e divergir daqui, basta alterar
/// esta função: nenhuma regra do calendário depende da convenção escolhida.
DateTime adicionarMeses(DateTime data, int meses) {
  final totalMeses = data.month - 1 + meses;
  final ano = data.year + (totalMeses ~/ 12);
  final mes = (totalMeses % 12) + 1;

  // Dia 0 do mês seguinte é o último dia do mês corrente.
  final ultimoDiaDoMes = DateTime(ano, mes + 1, 0).day;
  final dia = data.day <= ultimoDiaDoMes ? data.day : ultimoDiaDoMes;

  return DateTime(ano, mes, dia);
}

// ── Faixa gestacional plausível ─────────────────────────────────────────

/// Menor valor de dias de gestação que a engine considera interpretável.
///
/// Abaixo disso a DUM está no futuro, e nada pode ser afirmado.
const int diasGestacaoMinimoPlausivel = 0;

/// Maior valor de dias de gestação que a engine considera interpretável.
///
/// 294 dias são 42 semanas — o mesmo teto que `GestacaoInfo.semanaAtual`
/// já usa no app. A diferença é que aqui o valor não é *clampeado*: acima
/// dele a engine declara a gestação indeterminada em vez de fingir que são
/// 42 semanas.
const int diasGestacaoMaximoPlausivel = 294;

/// Se [diasGestacaoBruto] cai numa faixa que permite alguma afirmação.
bool gestacaoPlausivel(int diasGestacaoBruto) =>
    diasGestacaoBruto >= diasGestacaoMinimoPlausivel &&
    diasGestacaoBruto <= diasGestacaoMaximoPlausivel;

/// Semana gestacional a partir dos dias brutos, **sem clamp**.
///
/// Semana 20 começa no dia 140. Não usar `GestacaoInfo.semanaAtual` aqui: o
/// clamp de lá esconde exatamente os casos que esta engine precisa detectar.
int semanaGestacionalDe(int diasGestacaoBruto) => diasGestacaoBruto ~/ 7;

/// Motor de avaliação.
class VacinasEngine {
  const VacinasEngine._();

  /// Avalia todas as regras do [calendario] para uma gestante.
  ///
  /// [diasGestacaoBruto] deve vir **sem clamp** — é a diferença em dias
  /// entre [dataAtual] e [dum], como ela for, inclusive negativa.
  ///
  /// [temporadaInfluenza] identifica a temporada vigente de influenza, se
  /// conhecida. `null` significa temporada indeterminada: a engine não a
  /// calcula, nem deduz do ano civil. Sem essa informação, a influenza não
  /// pode ser avaliada — e a engine diz isso, em vez de supor.
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
    // O switch é exaustivo sobre a hierarquia selada e trata cada tipo em
    // um único lugar — não há caminho de exceção nem ramo alcançável sem
    // resposta. Avaliação profissional é o primeiro caso justamente para
    // deixar explícito que nenhuma condição de gestação ou histórico a
    // desvia para outro estado.
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

      // Etapa seguinte. Até lá, a engine não afirma nada sobre esta.
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

  /// Avalia uma regra organizada por temporada — o caso da influenza no
  /// PNI-2026.
  ///
  /// A temporada vigente entra pronta, vinda de quem chamou. A engine não a
  /// calcula, não a deduz do ano civil, da DUM ou da data de aplicação, e
  /// não interpreta o conteúdo do identificador: a comparação é igualdade
  /// estrita de String, e `'2026'` é diferente de `'2026 '`.
  ///
  /// [dataAplicacao] não participa de nenhuma decisão aqui. Sem limites de
  /// início e fim de temporada — que o calendário deliberadamente não
  /// define — uma data não diz a que temporada pertence. O vínculo vem
  /// exclusivamente do snapshot gravado no registro.
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

    // Sem saber qual é a temporada vigente, "1 dose por temporada" é
    // inavaliável. A engine diz isso em vez de supor uma temporada.
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

    // Igualdade estrita: registros de outra temporada, ou sem temporada
    // conhecida, simplesmente não pertencem a esta — não provam aplicação
    // nem bloqueiam a avaliação.
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

  /// Avalia uma regra de dose por gestação com intervalo mínimo desde a
  /// última dose — o caso do COVID-19 no PNI-2026.
  ///
  /// A gestação atual e o histórico anterior têm papéis distintos: doses
  /// vinculadas a esta gestação contam para o limite de doses por gestação;
  /// doses de qualquer época contam para o intervalo mínimo. Uma dose
  /// anterior nunca é confundida com dose desta gestação.
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

    // Para o intervalo, o que importa é a última dose declarada — de
    // qualquer gestação, inclusive sem vínculo com alguma.
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

    // Uma dose sem data pode ter sido ontem: com ela no histórico, não há
    // como afirmar que o intervalo foi cumprido, mesmo que exista outra
    // dose antiga com data conhecida.
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

  /// Soma um [Intervalo] do calendário a uma data, respeitando a unidade
  /// declarada. Meses nunca viram uma quantidade fixa de dias.
  static DateTime _somarIntervalo(DateTime data, Intervalo intervalo) {
    switch (intervalo.unidade) {
      case UnidadeIntervalo.dias:
        return data.add(Duration(days: intervalo.valor));
      case UnidadeIntervalo.meses:
        return adicionarMeses(data, intervalo.valor);
    }
  }

  /// Se [a] não é posterior a [b], comparando apenas o dia — hora do
  /// registro não deve mudar a decisão.
  static bool _naoPosteriorA(DateTime a, DateTime b) =>
      !_soData(a).isAfter(_soData(b));

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  static StatusVacinacao _avaliarJanelaSemana({
    required RegraJanelaSemana regra,
    required int diasGestacaoBruto,
    required DateTime dum,
    required List<RegistroVacinacao> historico,
  }) {
    // Só registros vinculados a esta gestação entram na avaliação. Um
    // registro histórico sem vínculo não prova aplicação nem bloqueia a
    // janela atual — ele simplesmente não diz nada sobre esta gestação.
    final registrosDestaGestacao = historico
        .where((r) => r.vacinaCodigo == regra.codigo)
        .where((r) => _pertenceAGestacaoAtual(r, dum))
        .toList(growable: false);

    // A regra diz quantas doses prevê por gestação; a engine não presume
    // esse número. Sem ele declarado, não há como saber se o previsto foi
    // cumprido — e a engine não inventa o valor.
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

    // Atingido o previsto pela regra, a janela deixa de importar. Vale
    // mesmo com a gestação indeterminada — o registro é um fato informado,
    // não uma dedução.
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

    // Registro cuja situação é desconhecida não é "não aplicada": não dá
    // para afirmar que a dose falta, nem que foi tomada.
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

    // Idade gestacional fora de faixa interpretável: nenhuma afirmação
    // automática, nem de janela aberta nem de janela fechada.
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

  /// Se o registro está vinculado à gestação em avaliação.
  ///
  /// O vínculo é o snapshot da DUM gravado no registro: sem identificador
  /// formal de gestação, é o único disponível. DUM ausente ou diferente
  /// significa que não dá para afirmar que o registro é desta gestação — e
  /// a engine não afirma.
  ///
  /// Critério único de propósito: um registro sem vínculo não serve nem
  /// como prova de aplicação, nem como motivo para bloquear a janela atual.
  /// Tratá-lo de formas diferentes conforme a situação declarada faria um
  /// registro antigo, sem DUM, travar a gestação de hoje indefinidamente.
  static bool _pertenceAGestacaoAtual(RegistroVacinacao registro, DateTime dum) {
    final dumDoRegistro = registro.dumNoRegistro;
    if (dumDoRegistro == null) return false;

    return _mesmoDia(dumDoRegistro, dum);
  }

  /// Se o registro declara que a dose foi aplicada — com ou sem data.
  static bool _declaraDoseAplicada(RegistroVacinacao registro) {
    return registro.situacaoInformada == SituacaoInformada.aplicadaComData ||
        registro.situacaoInformada == SituacaoInformada.aplicadaDataDesconhecida;
  }

  /// Se a usuária não determinou a situação deste registro. Diferente de
  /// "ela informou que não tomou".
  static bool _temSituacaoIndeterminada(RegistroVacinacao registro) =>
      registro.situacaoInformada == SituacaoInformada.situacaoDesconhecida;

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
