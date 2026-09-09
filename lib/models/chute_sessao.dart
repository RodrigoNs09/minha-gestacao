class ChuteSessao {

  final String? id;

  final String data;
  final String horaInicio;
  final String horaFim;
  final int totalChutes;
  final bool completa; // true se atingiu a meta de chutes

  ChuteSessao({
    this.id,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.totalChutes,
    required this.completa,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'horaInicio': horaInicio,
      'horaFim': horaFim,
      'totalChutes': totalChutes,
      'completa': completa,
    };
  }

  factory ChuteSessao.fromMap(
    Map<String, dynamic> map, {
    String? idDoDocumento,
  }) {
    return ChuteSessao(
      id: identidadeUtilizavel(idDoDocumento),
      data: textoSeguro(map['data']),
      horaInicio: textoSeguro(map['horaInicio']),
      horaFim: textoSeguro(map['horaFim']),
      totalChutes: inteiroSeguro(map['totalChutes']) ?? 0,
      completa: booleanoSeguro(map['completa']),
    );
  }

  ChuteSessao comId(String novoId) {
    return ChuteSessao(
      id: novoId,
      data: data,
      horaInicio: horaInicio,
      horaFim: horaFim,
      totalChutes: totalChutes,
      completa: completa,
    );
  }
}

class ProgressoDeChutes {
  final int chutes;
  final String data;

  final DateTime? inicio;

  final String? sessaoId;

  const ProgressoDeChutes({
    required this.chutes,
    required this.data,
    this.inicio,
    this.sessaoId,
  });

  static ProgressoDeChutes? deBruto(Object? bruto) {
    if (bruto is! Map) return null;

    final chutes = inteiroSeguro(bruto['chutes']);
    final data = textoSeguro(bruto['data']);
    if (chutes == null || chutes <= 0 || data.isEmpty) return null;

    return ProgressoDeChutes(
      chutes: chutes,
      data: data,
      inicio: DateTime.tryParse(textoSeguro(bruto['horaInicio'])),
      sessaoId: identidadeUtilizavel(textoSeguro(bruto['sessaoId'])),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chutes': chutes,
      'data': data,
      'horaInicio': inicio?.toIso8601String() ?? '',
      if (sessaoId != null) 'sessaoId': sessaoId,
    };
  }
}

String textoSeguro(Object? bruto) => bruto is String ? bruto : '';

int? inteiroSeguro(Object? bruto) {
  if (bruto is int) return bruto;
  if (bruto is num) return bruto.toInt();
  if (bruto is String) return int.tryParse(bruto);
  return null;
}

bool booleanoSeguro(Object? bruto) {
  if (bruto is bool) return bruto;
  if (bruto is num) return bruto != 0;
  if (bruto is String) return bruto.toLowerCase() == 'true';
  return false;
}

String? identidadeUtilizavel(String? bruto) {
  final limpo = bruto?.trim() ?? '';
  return limpo.isEmpty ? null : limpo;
}
