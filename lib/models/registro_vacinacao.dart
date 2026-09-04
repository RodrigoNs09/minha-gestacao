/// Como a usuária descreveu a situação de uma dose.
///
/// Captura o que ela informou — nunca infere uma certeza que ela não deu.
/// Os quatro casos são distintos e não intercambiáveis:
///
/// - [aplicadaComData]: informou que recebeu a dose e sabe a data.
/// - [aplicadaDataDesconhecida]: informou que recebeu, mas não sabe quando.
/// - [naoAplicadaInformado]: informou que não recebeu.
/// - [situacaoDesconhecida]: não há informação suficiente para saber.
///
/// A separação entre "não recebeu" e "não se sabe" é o que impede o app de
/// concluir uma conduta a partir de um silêncio. "Sem data" também é
/// diferente de "não tomou", e nenhuma das duas equivale a "está em dia".
enum SituacaoInformada {
  aplicadaComData('APLICADA_COM_DATA'),
  aplicadaDataDesconhecida('APLICADA_DATA_DESCONHECIDA'),
  naoAplicadaInformado('NAO_APLICADA_INFORMADO'),
  situacaoDesconhecida('SITUACAO_DESCONHECIDA');

  const SituacaoInformada(this.codigo);

  /// Valor persistido. Estável e independente do nome em Dart: renomear a
  /// constante não invalida documentos já gravados.
  final String codigo;

  /// `null` quando o valor é ausente ou desconhecido — quem lê decide o
  /// fallback, em vez de receber um significado inventado aqui.
  static SituacaoInformada? porCodigo(Object? bruto) {
    if (bruto is! String) return null;
    for (final situacao in SituacaoInformada.values) {
      if (situacao.codigo == bruto) return situacao;
    }
    return null;
  }
}

/// De onde veio a informação da dose.
///
/// Tem um único valor de propósito: nesta versão o app não integra com
/// nenhuma fonte oficial de vacinação, então todo registro é declaração da
/// própria usuária. Acrescentar um valor aqui (ex.: "validado por serviço
/// de saúde") muda o que o dado significa para quem lê a tela e exige uma
/// decisão explícita de produto — o modelo não deve ser capaz de
/// representar como validada uma informação que a usuária digitou.
enum OrigemRegistro {
  registradoPelaUsuaria('REGISTRADO_PELA_USUARIA');

  const OrigemRegistro(this.codigo);

  final String codigo;

  /// Fallback deliberadamente conservador: valor ausente, desconhecido ou
  /// vindo de um esquema futuro é lido como declaração da usuária, nunca
  /// como validação.
  static OrigemRegistro porCodigo(Object? bruto) {
    if (bruto is! String) return OrigemRegistro.registradoPelaUsuaria;
    for (final origem in OrigemRegistro.values) {
      if (origem.codigo == bruto) return origem;
    }
    return OrigemRegistro.registradoPelaUsuaria;
  }
}

/// Uma dose informada pela usuária.
///
/// Registro histórico, não uma avaliação: este modelo guarda o que foi
/// declarado, e nada mais. A leitura clínica desses dados (se o esquema
/// está completo, se há janela aberta) é responsabilidade da engine de
/// regras, nunca deste arquivo nem de um widget.
///
/// Puro por exigência: sem Firebase, sem Flutter, sem UI. É o que permite
/// testá-lo — e à futura engine que o consome — na infraestrutura de teste
/// atual do projeto, que não tem mocks de Firestore.
class RegistroVacinacao {
  /// Identificador do documento no Firestore, ou `null` para um registro
  /// ainda não persistido.
  ///
  /// Preenchido por [RegistroVacinacao.fromMap] na leitura e por [comId] na
  /// gravação. Nunca é serializado — ver [toMap].
  final String? id;

  /// Código da vacina no calendário (ex.: `dtpa`). Chave de ligação com as
  /// regras oficiais; o modelo não valida se o código existe, porque não
  /// conhece o calendário.
  final String vacinaCodigo;

  /// Dia em que a dose foi aplicada, ou `null` quando a usuária informou
  /// que não sabe a data — ou que não tomou.
  ///
  /// `null` significa "não informado", nunca "hoje".
  final DateTime? dataAplicacao;

  final SituacaoInformada situacaoInformada;

  final OrigemRegistro origemRegistro;

  /// DUM vigente no momento em que o registro foi feito.
  ///
  /// O app não tem identificador formal de gestação: este snapshot é o
  /// único vínculo disponível entre uma dose e a gestação em que ela foi
  /// registrada. É uma pista de auditoria, não uma garantia — duas
  /// gestações com DUM próxima não são distinguíveis por aqui.
  final DateTime? dumNoRegistro;

  /// Quando o registro foi criado no app — distinto de [dataAplicacao],
  /// que é quando a dose foi tomada.
  final DateTime? criadoEm;

  final String? observacao;

  /// Versão do calendário vigente quando o registro foi feito.
  ///
  /// Vazio em documentos gravados antes deste campo existir: ausência é
  /// lida como "versão não registrada", não como a versão atual.
  final String versaoCalendario;

  const RegistroVacinacao({
    this.id,
    required this.vacinaCodigo,
    required this.situacaoInformada,
    required this.versaoCalendario,
    this.origemRegistro = OrigemRegistro.registradoPelaUsuaria,
    this.dataAplicacao,
    this.dumNoRegistro,
    this.criadoEm,
    this.observacao,
  });

  /// Cópia com o identificador do documento anexado.
  ///
  /// Mesmo papel de `Contracao.comId`: o storage gera o id no cliente e
  /// devolve a instância já identificada.
  RegistroVacinacao comId(String novoId) {
    return RegistroVacinacao(
      id: novoId,
      vacinaCodigo: vacinaCodigo,
      situacaoInformada: situacaoInformada,
      versaoCalendario: versaoCalendario,
      origemRegistro: origemRegistro,
      dataAplicacao: dataAplicacao,
      dumNoRegistro: dumNoRegistro,
      criadoEm: criadoEm,
      observacao: observacao,
    );
  }

  // ── Serialização ────────────────────────────────────────────────────

  /// Mapa para gravação.
  ///
  /// Segue duas convenções que já convivem no projeto: datas de calendário
  /// como `yyyy-MM-dd` (igual a `Contracao.data`) e instantes como ISO8601
  /// (igual ao campo `gestacao_dum`).
  ///
  /// Chaves de valores desconhecidos são **omitidas**, não gravadas como
  /// `null` — ausência já significa "desconhecido" para [fromMap], mesmo
  /// critério de `Contracao.toMap`.
  ///
  /// `id` NÃO é gravado: a identidade é o `doc.id`. Duplicá-lo dentro do
  /// payload é o que produz caminhos inválidos quando as duas cópias
  /// divergem.
  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'vacinaCodigo': vacinaCodigo,
      'situacaoInformada': situacaoInformada.codigo,
      'origemRegistro': origemRegistro.codigo,
      'versaoCalendario': versaoCalendario,
    };

    final aplicacao = dataAplicacao;
    if (aplicacao != null) mapa['dataAplicacao'] = _formatarDia(aplicacao);

    final dum = dumNoRegistro;
    if (dum != null) mapa['dumNoRegistro'] = dum.toIso8601String();

    final criacao = criadoEm;
    if (criacao != null) mapa['criadoEm'] = criacao.toIso8601String();

    final obs = observacao;
    if (obs != null) mapa['observacao'] = obs;

    return mapa;
  }

  /// Reconstrói a partir de um documento.
  ///
  /// Nenhum campo malformado lança: data ilegível vira `null`
  /// ("desconhecida"), texto ausente vira vazio. Um documento corrompido
  /// deve degradar para incerteza, nunca derrubar a tela.
  factory RegistroVacinacao.fromMap(Map<String, dynamic> map, {String? id}) {
    return RegistroVacinacao(
      id: id,
      vacinaCodigo: _texto(map['vacinaCodigo']) ?? '',
      // Ausência de informação é ausência de informação: nunca é lida como
      // dose aplicada nem como dose recusada. Um código desconhecido — de um
      // esquema futuro, por exemplo — recebe o mesmo tratamento conservador.
      situacaoInformada: SituacaoInformada.porCodigo(map['situacaoInformada']) ??
          SituacaoInformada.situacaoDesconhecida,
      origemRegistro: OrigemRegistro.porCodigo(map['origemRegistro']),
      versaoCalendario: _texto(map['versaoCalendario']) ?? '',
      dataAplicacao: _parsearData(map['dataAplicacao']),
      dumNoRegistro: _parsearData(map['dumNoRegistro']),
      criadoEm: _parsearData(map['criadoEm']),
      observacao: _texto(map['observacao']),
    );
  }

  static String _formatarDia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Aceita tanto `yyyy-MM-dd` quanto ISO8601 completo. Qualquer outra
  /// coisa — inclusive tipo inesperado — vira `null`.
  ///
  /// `DateTime.tryParse` aceita componentes fora de faixa e os normaliza em
  /// silêncio: `2026-13-45` vira `2027-02-14`. Uma data corrompida que se
  /// transforma em outra data plausível é pior do que uma data
  /// desconhecida — a engine calcularia intervalos entre doses sobre um
  /// valor inventado. Por isso só aceitamos quando ano, mês e dia
  /// sobrevivem ao round-trip.
  static DateTime? _parsearData(Object? bruto) {
    if (bruto is! String || bruto.isEmpty) return null;

    final parseada = DateTime.tryParse(bruto);
    if (parseada == null) return null;

    final componentes = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(bruto);
    if (componentes == null) return null;

    final ano = int.parse(componentes.group(1)!);
    final mes = int.parse(componentes.group(2)!);
    final dia = int.parse(componentes.group(3)!);

    if (parseada.year != ano || parseada.month != mes || parseada.day != dia) {
      return null;
    }

    return parseada;
  }

  static String? _texto(Object? bruto) => bruto is String ? bruto : null;
}
