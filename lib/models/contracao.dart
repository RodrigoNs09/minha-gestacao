class Contracao {
  final String data; // yyyy-MM-dd — dia em que a contração foi registrada
  final String inicio;
  final String fim;
  final String intensidade;
  final String observacoes;

  Contracao({
    required this.inicio,
    required this.fim,
    required this.intensidade,
    required this.observacoes,
    String? data,
  }) : data = data ?? _hojeFallback();

  static String _hojeFallback() {
    final agora = DateTime.now();
    return '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toMap() {
    return {
      'data': data,
      'inicio': inicio,
      'fim': fim,
      'intensidade': intensidade,
      'observacoes': observacoes,
    };
  }

  factory Contracao.fromMap(Map<String, dynamic> map) {
    return Contracao(
      data: map['data'], // se não existir (registro antigo), usa fallback de hoje
      inicio: map['inicio'] ?? '',
      fim: map['fim'] ?? '',
      intensidade: map['intensidade'] ?? '',
      observacoes: map['observacoes'] ?? '',
    );
  }
}