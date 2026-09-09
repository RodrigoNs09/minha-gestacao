class Consulta {
  final String id;
  final String titulo;
  final String profissional;
  final String data;
  final String hora;
  final bool realizada;

  Consulta({
    required this.id,
    required this.titulo,
    required this.profissional,
    required this.data,
    required this.hora,
    this.realizada = false,
  });

  DateTime? get dataHora => _dataHoraDe(data, hora);

  int? get diasRestantes {
    final quando = dataHora;
    if (quando == null) return null;

    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataConsulta = DateTime(quando.year, quando.month, quando.day);
    return dataConsulta.difference(hoje).inDays;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'profissional': profissional,
      'data': data,
      'hora': hora,
      'realizada': realizada,
    };
  }

  factory Consulta.fromMap(Map<String, dynamic> map, {String? idDoDocumento}) {
    return Consulta(
      id: _identidade(map['id'], idDoDocumento),
      titulo: _texto(map['titulo']),
      profissional: _texto(map['profissional']),
      data: _texto(map['data']),
      hora: _texto(map['hora']),
      realizada: _booleano(map['realizada']),
    );
  }

  static String _identidade(Object? bruto, String? idDoDocumento) {
    final doCampo = bruto is String ? bruto.trim() : '';
    if (doCampo.isNotEmpty) return doCampo;
    return idDoDocumento?.trim() ?? '';
  }

  static String _texto(Object? bruto) => bruto is String ? bruto : '';

  static bool _booleano(Object? bruto) {
    if (bruto is bool) return bruto;
    if (bruto is num) return bruto != 0;
    if (bruto is String) return bruto.toLowerCase() == 'true';
    return false;
  }

  static DateTime? _dataHoraDe(String data, String hora) {
    final partesData = data.split('-');
    if (partesData.length != 3) return null;

    final partesHora = hora.split(':');
    if (partesHora.length != 2) return null;

    final ano = int.tryParse(partesData[0]);
    final mes = int.tryParse(partesData[1]);
    final dia = int.tryParse(partesData[2]);
    final horas = int.tryParse(partesHora[0]);
    final minutos = int.tryParse(partesHora[1]);

    if (ano == null ||
        mes == null ||
        dia == null ||
        horas == null ||
        minutos == null) {
      return null;
    }

    if (horas < 0 || horas > 23 || minutos < 0 || minutos > 59) return null;

    final montada = DateTime(ano, mes, dia, horas, minutos);

    if (montada.year != ano || montada.month != mes || montada.day != dia) {
      return null;
    }

    return montada;
  }

  Consulta copyWith({
    String? titulo,
    String? profissional,
    String? data,
    String? hora,
    bool? realizada,
  }) {
    return Consulta(
      id: id,
      titulo: titulo ?? this.titulo,
      profissional: profissional ?? this.profissional,
      data: data ?? this.data,
      hora: hora ?? this.hora,
      realizada: realizada ?? this.realizada,
    );
  }

  Consulta comId(String novoId) {
    return Consulta(
      id: novoId,
      titulo: titulo,
      profissional: profissional,
      data: data,
      hora: hora,
      realizada: realizada,
    );
  }
}
