class RegistroSintomas {
  final String data;
  final int? humor;
  final List<String> sintomas;
  final double? peso;

  RegistroSintomas({
    required this.data,
    this.humor,
    this.sintomas = const [],
    this.peso,
  });

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'humor': humor,
      'sintomas': sintomas,
      'peso': peso,
    };
  }

  factory RegistroSintomas.fromMap(Map<String, dynamic> map) {
    return RegistroSintomas(
      data: map['data'] ?? '',
      humor: map['humor'],
      sintomas: List<String>.from(map['sintomas'] ?? []),
      peso: map['peso'] != null ? (map['peso'] as num).toDouble() : null,
    );
  }

  RegistroSintomas copyWith({
    int? humor,
    List<String>? sintomas,
    double? peso,
  }) {
    return RegistroSintomas(
      data: data,
      humor: humor ?? this.humor,
      sintomas: sintomas ?? this.sintomas,
      peso: peso ?? this.peso,
    );
  }
}

class SintomaOpcao {
  final String id;
  final String label;

  const SintomaOpcao(this.id, this.label);
}

const List<SintomaOpcao> opcoesDeSintomas = [
  SintomaOpcao('nausea', 'Náusea'),
  SintomaOpcao('costas', 'Dor nas costas'),
  SintomaOpcao('inchaco', 'Inchaço'),
  SintomaOpcao('cansaco', 'Cansaço'),
  SintomaOpcao('insonia', 'Insônia'),
  SintomaOpcao('azia', 'Azia'),
];

const List<String> opcoesDeHumor = ['Ótima', 'Ok', 'Triste', 'Exausta', 'Enjoada'];