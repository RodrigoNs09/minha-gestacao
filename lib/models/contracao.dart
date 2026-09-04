import 'package:cloud_firestore/cloud_firestore.dart';

enum OrigemDuracao {
  campo,

  observacoes,

  indisponivel,
}

class Contracao {
  final String? id;

  final String data;
  final String inicio;
  final String fim;
  final String intensidade; // Leve | Moderada | Forte
  final String observacoes;

  final int? duracaoSegundos;

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

  static final RegExp _padraoDuracao = RegExp(r'Duração:\s*(\d{1,3}):(\d{2})(?!\d)');

  static int? duracaoSegundosDe(String? observacoes) {
    if (observacoes == null || observacoes.isEmpty) return null;

    final match = _padraoDuracao.firstMatch(observacoes);
    if (match == null) return null;

    final minutos = int.tryParse(match.group(1)!);
    final segundos = int.tryParse(match.group(2)!);
    if (minutos == null || segundos == null) return null;

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

  String? get duracaoFormatada {
    final segundosTotais = duracaoSegundos;
    if (segundosTotais == null) return null;
    final minutos = segundosTotais ~/ 60;
    final segundos = segundosTotais % 60;
    return '${minutos.toString().padLeft(2, '0')}:${segundos.toString().padLeft(2, '0')}';
  }

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
      data: map['data'] as String?, 
      inicio: map['inicio'] ?? '',
      fim: map['fim'] ?? '',
      intensidade: map['intensidade'] ?? '',
      observacoes: map['observacoes'] ?? '',
      duracaoSegundos: _normalizarSegundos(map['duracaoSegundos']),
    );
  }

  factory Contracao.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Contracao.fromMap(doc.data() ?? const <String, dynamic>{}, id: doc.id);
  }
}