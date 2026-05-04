class Contracao {
  final String inicio;
  final String fim;
  final String intensidade;
  final String observacoes;

  Contracao({
    required this.inicio,
    required this.fim,
    required this.intensidade,
    required this.observacoes,
  });

  Map<String, dynamic> toMap() {
    return {
      'inicio': inicio,
      'fim': fim,
      'intensidade': intensidade,
      'observacoes': observacoes,
    };
  }

  factory Contracao.fromMap(Map<String, dynamic> map) {
    return Contracao(
      inicio: map['inicio'] ?? '',
      fim: map['fim'] ?? '',
      intensidade: map['intensidade'] ?? '',
      observacoes: map['observacoes'] ?? '',
    );
  }
}