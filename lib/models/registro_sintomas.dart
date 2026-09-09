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

  factory RegistroSintomas.fromMap(
    Map<String, dynamic> map, {
    String? dataDoDocumento,
  }) {
    return RegistroSintomas(
      data: _texto(map['data']) ?? dataDoDocumento ?? '',
      humor: _inteiro(map['humor']),
      sintomas: _listaDeTextos(map['sintomas']),
      peso: _decimal(map['peso']),
    );
  }

  static String? _texto(Object? bruto) {
    if (bruto is! String || bruto.isEmpty) return null;
    return bruto;
  }

  static int? _inteiro(Object? bruto) {
    if (bruto is int) return bruto;
    if (bruto is num) return bruto.toInt();
    if (bruto is String) return int.tryParse(bruto);
    return null;
  }

  static double? _decimal(Object? bruto) {
    final double? valor;
    if (bruto is num) {
      valor = bruto.toDouble();
    } else if (bruto is String) {
      valor = double.tryParse(bruto.replaceAll(',', '.'));
    } else {
      valor = null;
    }

    if (valor == null || valor.isNaN || valor.isInfinite) return null;
    return valor;
  }

  static List<String> _listaDeTextos(Object? bruto) {
    if (bruto is! List) return const [];
    return bruto.whereType<String>().where((item) => item.isNotEmpty).toList();
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
