enum SituacaoInformada {
  aplicadaComData('APLICADA_COM_DATA'),
  aplicadaDataDesconhecida('APLICADA_DATA_DESCONHECIDA'),
  naoAplicadaInformado('NAO_APLICADA_INFORMADO'),
  situacaoDesconhecida('SITUACAO_DESCONHECIDA');

  const SituacaoInformada(this.codigo);

  final String codigo;

  static SituacaoInformada? porCodigo(Object? bruto) {
    if (bruto is! String) return null;
    for (final situacao in SituacaoInformada.values) {
      if (situacao.codigo == bruto) return situacao;
    }
    return null;
  }
}

enum OrigemRegistro {
  registradoPelaUsuaria('REGISTRADO_PELA_USUARIA');

  const OrigemRegistro(this.codigo);

  final String codigo;

  static OrigemRegistro porCodigo(Object? bruto) {
    if (bruto is! String) return OrigemRegistro.registradoPelaUsuaria;
    for (final origem in OrigemRegistro.values) {
      if (origem.codigo == bruto) return origem;
    }
    return OrigemRegistro.registradoPelaUsuaria;
  }
}

class RegistroVacinacao {
  final String? id;

  final String vacinaCodigo;

  final DateTime? dataAplicacao;

  /// Posição declarada da dose no esquema. `null` = posição desconhecida,
  /// nunca primeira dose. Não é inferida da data nem da ordem dos registros.
  final int? numeroDaDose;

  final SituacaoInformada situacaoInformada;

  final OrigemRegistro origemRegistro;

  final DateTime? dumNoRegistro;

  final String? temporadaNoRegistro;

  final DateTime? criadoEm;

  final String? observacao;

  final String versaoCalendario;

  const RegistroVacinacao({
    this.id,
    required this.vacinaCodigo,
    required this.situacaoInformada,
    required this.versaoCalendario,
    this.origemRegistro = OrigemRegistro.registradoPelaUsuaria,
    this.dataAplicacao,
    this.numeroDaDose,
    this.dumNoRegistro,
    this.temporadaNoRegistro,
    this.criadoEm,
    this.observacao,
  });

  RegistroVacinacao comId(String novoId) {
    return RegistroVacinacao(
      id: novoId,
      vacinaCodigo: vacinaCodigo,
      situacaoInformada: situacaoInformada,
      versaoCalendario: versaoCalendario,
      origemRegistro: origemRegistro,
      dataAplicacao: dataAplicacao,
      numeroDaDose: numeroDaDose,
      dumNoRegistro: dumNoRegistro,
      temporadaNoRegistro: temporadaNoRegistro,
      criadoEm: criadoEm,
      observacao: observacao,
    );
  }

  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'vacinaCodigo': vacinaCodigo,
      'situacaoInformada': situacaoInformada.codigo,
      'origemRegistro': origemRegistro.codigo,
      'versaoCalendario': versaoCalendario,
    };

    final aplicacao = dataAplicacao;
    if (aplicacao != null) mapa['dataAplicacao'] = _formatarDia(aplicacao);

    final numero = numeroDaDose;
    if (numero != null) mapa['numeroDaDose'] = numero;

    final dum = dumNoRegistro;
    if (dum != null) mapa['dumNoRegistro'] = dum.toIso8601String();

    final temporada = temporadaNoRegistro;
    if (temporada != null) mapa['temporadaNoRegistro'] = temporada;

    final criacao = criadoEm;
    if (criacao != null) mapa['criadoEm'] = criacao.toIso8601String();

    final obs = observacao;
    if (obs != null) mapa['observacao'] = obs;

    return mapa;
  }

  factory RegistroVacinacao.fromMap(Map<String, dynamic> map, {String? id}) {
    return RegistroVacinacao(
      id: id,
      vacinaCodigo: _texto(map['vacinaCodigo']) ?? '',
      situacaoInformada: SituacaoInformada.porCodigo(map['situacaoInformada']) ??
          SituacaoInformada.situacaoDesconhecida,
      origemRegistro: OrigemRegistro.porCodigo(map['origemRegistro']),
      versaoCalendario: _texto(map['versaoCalendario']) ?? '',
      dataAplicacao: _parsearData(map['dataAplicacao']),
      numeroDaDose: _inteiro(map['numeroDaDose']),
      dumNoRegistro: _parsearData(map['dumNoRegistro']),
      temporadaNoRegistro: _texto(map['temporadaNoRegistro']),
      criadoEm: _parsearData(map['criadoEm']),
      observacao: _texto(map['observacao']),
    );
  }

  static String _formatarDia(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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

  static int? _inteiro(Object? bruto) => bruto is int ? bruto : null;
}
