import '../services/vacinas_engine.dart' show diasDeCalendarioEntre;

class GestacaoInfo {
  final DateTime dum; // Data da Última Menstruação

  final String? id;

  final bool configurada;

  GestacaoInfo({required this.dum, this.id, this.configurada = false});

  int get diasGestacao => diasDeCalendarioEntre(dum, DateTime.now());

  int get semanaAtual {
    final semana = (diasGestacao / 7).floor();
    return semana.clamp(1, 42);
  }

  int get diaAtual {
    final dia = diasGestacao % 7;
    return dia + 1;
  }

  int get trimestre {
    if (semanaAtual <= 13) return 1;
    if (semanaAtual <= 27) return 2;
    return 3;
  }

  int get semanasRestantes => (40 - semanaAtual).clamp(0, 40);

  double get percentualConcluido => (semanaAtual / 40 * 100).clamp(0, 100);

  DateTime get dataProvavelParto => dum.add(const Duration(days: 280));

  Map<String, String> get tamanhoBebe =>
      _tabelaTamanhos[semanaAtual] ??
      {'fruta': 'Bebê', 'emoji': '👶', 'tamanho': '--'};

  static const Map<int, Map<String, String>> _tabelaTamanhos = {
    4: {'fruta': 'Semente de papoula', 'emoji': '⚫', 'tamanho': '0,2 cm'},
    5: {'fruta': 'Semente de gergelim', 'emoji': '⚫', 'tamanho': '0,3 cm'},
    6: {'fruta': 'Lentilha', 'emoji': '🫘', 'tamanho': '0,6 cm'},
    7: {'fruta': 'Mirtilo', 'emoji': '🫐', 'tamanho': '1,3 cm'},
    8: {'fruta': 'Framboesa', 'emoji': '🍇', 'tamanho': '1,6 cm'},
    9: {'fruta': 'Azeitona', 'emoji': '🫒', 'tamanho': '2,3 cm'},
    10: {'fruta': 'Morango', 'emoji': '🍓', 'tamanho': '3,1 cm'},
    11: {'fruta': 'Figo', 'emoji': '🟤', 'tamanho': '4,1 cm'},
    12: {'fruta': 'Limão', 'emoji': '🍋', 'tamanho': '5,4 cm'},
    13: {'fruta': 'Vagem', 'emoji': '🫛', 'tamanho': '7,4 cm'},
    14: {'fruta': 'Limão siciliano', 'emoji': '🍋', 'tamanho': '8,7 cm'},
    15: {'fruta': 'Maçã', 'emoji': '🍎', 'tamanho': '10,1 cm'},
    16: {'fruta': 'Abacate', 'emoji': '🥑', 'tamanho': '11,6 cm'},
    17: {'fruta': 'Pera', 'emoji': '🍐', 'tamanho': '13 cm'},
    18: {'fruta': 'Pimentão', 'emoji': '🫑', 'tamanho': '14,2 cm'},
    19: {'fruta': 'Manga', 'emoji': '🥭', 'tamanho': '15,3 cm'},
    20: {'fruta': 'Banana', 'emoji': '🍌', 'tamanho': '16,4 cm'},
    21: {'fruta': 'Cenoura', 'emoji': '🥕', 'tamanho': '26,7 cm'},
    22: {'fruta': 'Batata-doce', 'emoji': '🍠', 'tamanho': '27,8 cm'},
    23: {'fruta': 'Espiga de milho', 'emoji': '🌽', 'tamanho': '28,9 cm'},
    24: {'fruta': 'Berinjela', 'emoji': '🍆', 'tamanho': '30 cm'},
    25: {'fruta': 'Couve-flor', 'emoji': '🥦', 'tamanho': '34,6 cm'},
    26: {'fruta': 'Alface', 'emoji': '🥬', 'tamanho': '35,6 cm'},
    27: {'fruta': 'Brócolis', 'emoji': '🥦', 'tamanho': '36,6 cm'},
    28: {'fruta': 'Coco', 'emoji': '🥥', 'tamanho': '37,6 cm'},
    29: {'fruta': 'Abóbora pequena', 'emoji': '🎃', 'tamanho': '38,6 cm'},
    30: {'fruta': 'Repolho', 'emoji': '🥬', 'tamanho': '39,9 cm'},
    31: {'fruta': 'Coco grande', 'emoji': '🥥', 'tamanho': '41,1 cm'},
    32: {'fruta': 'Jicama', 'emoji': '🥔', 'tamanho': '42,4 cm'},
    33: {'fruta': 'Abacaxi', 'emoji': '🍍', 'tamanho': '43,7 cm'},
    34: {'fruta': 'Melão', 'emoji': '🍈', 'tamanho': '45 cm'},
    35: {'fruta': 'Melão pequeno', 'emoji': '🍈', 'tamanho': '46,2 cm'},
    36: {'fruta': 'Alface romana', 'emoji': '🥬', 'tamanho': '47,4 cm'},
    37: {'fruta': 'Acelga suíça', 'emoji': '🥬', 'tamanho': '48,6 cm'},
    38: {'fruta': 'Alho-poró', 'emoji': '🌱', 'tamanho': '49,8 cm'},
    39: {'fruta': 'Melancia mini', 'emoji': '🍉', 'tamanho': '50,7 cm'},
    40: {'fruta': 'Melancia', 'emoji': '🍉', 'tamanho': '51,2 cm'},
  };
}
