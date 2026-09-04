class ChuteSessao {
  final String data; 
  final String horaInicio;
  final String horaFim;
  final int totalChutes;
  final bool completa; // true se atingiu 10 chutes

  ChuteSessao({
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

  factory ChuteSessao.fromMap(Map<String, dynamic> map) {
    return ChuteSessao(
      data: map['data'] ?? '',
      horaInicio: map['horaInicio'] ?? '',
      horaFim: map['horaFim'] ?? '',
      totalChutes: map['totalChutes'] ?? 0,
      completa: map['completa'] ?? false,
    );
  }
}