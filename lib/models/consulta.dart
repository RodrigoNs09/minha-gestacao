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

  DateTime get dataHora {
    final partesData = data.split('-');
    final partesHora = hora.split(':');
    return DateTime(
      int.parse(partesData[0]),
      int.parse(partesData[1]),
      int.parse(partesData[2]),
      int.parse(partesHora[0]),
      int.parse(partesHora[1]),
    );
  }

  int get diasRestantes {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dataConsulta = DateTime(dataHora.year, dataHora.month, dataHora.day);
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

  factory Consulta.fromMap(Map<String, dynamic> map) {
    return Consulta(
      id: map['id'] ?? '',
      titulo: map['titulo'] ?? '',
      profissional: map['profissional'] ?? '',
      data: map['data'] ?? '',
      hora: map['hora'] ?? '',
      realizada: map['realizada'] ?? false,
    );
  }

  Consulta copyWith({bool? realizada}) {
    return Consulta(
      id: id,
      titulo: titulo,
      profissional: profissional,
      data: data,
      hora: hora,
      realizada: realizada ?? this.realizada,
    );
  }
}