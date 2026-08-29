import 'package:cloud_firestore/cloud_firestore.dart';

/// De onde veio o valor de [Contracao.duracaoSegundos].
///
/// Serve para classificar registros na leitura e, futuramente, para
/// preencher `migracaoNota` no backfill (Etapa 10 do plano de migração).
/// Nenhum valor é inventado: quando não há como determinar a duração,
/// o resultado é [indisponivel] e `duracaoSegundos` fica `null`.
enum OrigemDuracao {
  /// Lido do campo tipado `duracaoSegundos` do documento (esquema v2).
  campo,

  /// Derivado do prefixo "Duração: MM:SS" em `observacoes` (esquema v1).
  observacoes,

  /// Não foi possível determinar a duração deste registro.
  indisponivel,
}

class Contracao {
  /// Identificador do documento no Firestore, ou `null` para uma contração
  /// ainda não persistida.
  ///
  /// Preenchido por [Contracao.fromDoc] na leitura e por [comId] na gravação.
  /// Desde que `ContracoesStorage.adicionar` substituiu o antigo delete-all,
  /// o identificador é **estável**: nenhum documento é recriado com auto-ID
  /// novo, então o `id` de um registro não muda mais entre sessões.
  ///
  /// Continua anulável porque o construtor público é usado para montar uma
  /// contração antes de ela existir no Firestore — é o storage que atribui o
  /// `id` e devolve a instância já identificada.
  final String? id;

  final String data; // yyyy-MM-dd — dia em que a contração foi registrada
  final String inicio; // HH:mm
  final String fim; // HH:mm
  final String intensidade; // Leve | Moderada | Forte
  final String observacoes;

  /// Duração em segundos, ou `null` quando não é possível determiná-la.
  ///
  /// `null` significa "desconhecida", nunca "zero". Uma contração de 0s é
  /// representada por `0`, e isso é distinto de `null` em todo o app.
  final int? duracaoSegundos;

  /// Como [duracaoSegundos] foi obtido.
  final OrigemDuracao origemDuracao;

  const Contracao._({
    required this.id,
    required this.data,
    required this.inicio,
    required this.fim,
    required this.intensidade,
    required this.observacoes,
    required this.duracaoSegundos,
    required this.origemDuracao,
  });

  /// Resolve a duração na construção, com precedência:
  /// campo tipado > derivação do texto legado > indisponível.
  factory Contracao({
    required String inicio,
    required String fim,
    required String intensidade,
    required String observacoes,
    String? data,
    String? id,
    int? duracaoSegundos,
  }) {
    final int? doCampo = _normalizarSegundos(duracaoSegundos);
    final int? resolvida = doCampo ?? duracaoSegundosDe(observacoes);

    final OrigemDuracao origem;
    if (doCampo != null) {
      origem = OrigemDuracao.campo;
    } else if (resolvida != null) {
      origem = OrigemDuracao.observacoes;
    } else {
      origem = OrigemDuracao.indisponivel;
    }

    return Contracao._(
      id: id,
      data: data ?? _hojeFallback(),
      inicio: inicio,
      fim: fim,
      intensidade: intensidade,
      observacoes: observacoes,
      duracaoSegundos: resolvida,
      origemDuracao: origem,
    );
  }

  static String _hojeFallback() {
    final agora = DateTime.now();
    return '${agora.year}-${agora.month.toString().padLeft(2, '0')}-${agora.day.toString().padLeft(2, '0')}';
  }

  // ── Derivação da duração (fonte única) ──────────────────────────────

  /// Reconhece o prefixo gravado por `ContracaoScreen`:
  /// `Duração: MM:SS` ou `Duração: MM:SS | anotação livre`.
  ///
  /// Diferenças em relação às três regexes anteriores, que ficavam
  /// duplicadas em `main.dart` e `historico_screen.dart`:
  ///
  /// - minutos aceitam 1 a 3 dígitos (`\d{1,3}`) em vez de exatamente 2.
  ///   A versão antiga falhava em `Duração: 105:30`, perdendo silenciosamente
  ///   a duração de qualquer contração acima de 99 minutos;
  /// - `(?!\d)` impede casamento parcial em sequências mais longas
  ///   (`01:530` e `1050:30` são tratados como malformados, não como
  ///   valores truncados).
  ///
  /// Deliberadamente sensível a maiúsculas/minúsculas: todo registro legado
  /// foi produzido pelo mesmo escritor, sempre com a forma canônica
  /// "Duração". Tolerar variações não traria ganho e tornaria o
  /// comportamento dependente de dobra de caixa Unicode.
  static final RegExp _padraoDuracao = RegExp(r'Duração:\s*(\d{1,3}):(\d{2})(?!\d)');

  /// Deriva a duração em segundos a partir do texto de observações.
  ///
  /// Retorna `null` quando o padrão não é encontrado ou os valores são
  /// inconsistentes. Função pura — não depende de Firebase nem de estado.
  static int? duracaoSegundosDe(String? observacoes) {
    if (observacoes == null || observacoes.isEmpty) return null;

    final match = _padraoDuracao.firstMatch(observacoes);
    if (match == null) return null;

    final minutos = int.tryParse(match.group(1)!);
    final segundos = int.tryParse(match.group(2)!);
    if (minutos == null || segundos == null) return null;

    // "01:75" não é um tempo válido; preferimos desconhecido a um valor errado.
    if (segundos >= 60) return null;

    return (minutos * 60) + segundos;
  }

  static int? _normalizarSegundos(Object? bruto) {
    if (bruto == null) return null;
    int? valor;
    if (bruto is int) {
      valor = bruto;
    } else if (bruto is num) {
      valor = bruto.toInt();
    } else if (bruto is String) {
      valor = int.tryParse(bruto);
    }
    if (valor == null || valor < 0) return null;
    return valor;
  }

  /// Duração formatada como `MM:SS`, ou `null` se desconhecida.
  ///
  /// O texto de fallback fica a cargo de quem exibe, porque as telas usam
  /// marcadores diferentes (`--:--` no histórico, `—` na home).
  String? get duracaoFormatada {
    final segundosTotais = duracaoSegundos;
    if (segundosTotais == null) return null;
    final minutos = segundosTotais ~/ 60;
    final segundos = segundosTotais % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

  /// Devolve uma cópia com o identificador do Firestore anexado.
  ///
  /// Usa o construtor privado de propósito. Passar [duracaoSegundos] pelo
  /// construtor público faria [origemDuracao] virar [OrigemDuracao.campo]
  /// mesmo em registros cuja duração foi *derivada* do texto legado,
  /// corrompendo silenciosamente a classificação. Aqui todos os campos,
  /// inclusive a origem, atravessam intactos.
  Contracao comId(String novoId) {
    return Contracao._(
      id: novoId,
      data: data,
      inicio: inicio,
      fim: fim,
      intensidade: intensidade,
      observacoes: observacoes,
      duracaoSegundos: duracaoSegundos,
      origemDuracao: origemDuracao,
    );
  }

  // ── Serialização ────────────────────────────────────────────────────

  /// Esquema v2.
  ///
  /// Grava [duracaoSegundos] como campo tipado, mantendo o prefixo
  /// `Duração: MM:SS` dentro de `observacoes`. Essa redundância é
  /// deliberada: o leitor prefere o campo, mas continua derivando do texto
  /// nos documentos legados, então as duas formas convivem sem conversão.
  ///
  /// A chave é **omitida** quando a duração é desconhecida. Ausência já
  /// significa "desconhecida" para [fromMap], e assim o documento não fica
  /// com um campo nulo explícito.
  ///
  /// `id` NÃO é gravado: a identidade é o `doc.id`, e só ele. Duplicar o
  /// identificador dentro do payload é o que produz o caminho `doc('')`
  /// inválido quando as duas cópias divergem.
  ///
  /// ATENÇÃO: um registro carregado de um documento legado tem a duração
  /// derivada em memória, então serializá-lo aqui o promoveria a v2. Hoje
  /// nenhum caminho faz isso — [ContracoesStorage] só grava contrações
  /// recém-criadas. Quando um método de atualização existir, essa promoção
  /// passa a acontecer e precisa ser uma decisão consciente.
  Map<String, dynamic> toMap() {
    final mapa = <String, dynamic>{
      'data': data,
      'inicio': inicio,
      'fim': fim,
      'intensidade': intensidade,
      'observacoes': observacoes,
    };
    final segundos = duracaoSegundos;
    if (segundos != null) {
      mapa['duracaoSegundos'] = segundos;
    }
    return mapa;
  }

  factory Contracao.fromMap(Map<String, dynamic> map, {String? id}) {
    return Contracao(
      id: id,
      data: map['data'] as String?, // se não existir, usa fallback de hoje
      inicio: map['inicio'] ?? '',
      fim: map['fim'] ?? '',
      intensidade: map['intensidade'] ?? '',
      observacoes: map['observacoes'] ?? '',
      duracaoSegundos: _normalizarSegundos(map['duracaoSegundos']),
    );
  }

  /// Construtor canônico de leitura: adota `doc.id` como identidade.
  ///
  /// Até aqui o app descartava `doc.id` e lia apenas `doc.data()`, jogando
  /// fora um identificador que já existia no Firestore.
  factory Contracao.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Contracao.fromMap(doc.data() ?? const <String, dynamic>{}, id: doc.id);
  }
}