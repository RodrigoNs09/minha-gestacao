import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/contracao.dart';

class ContracoesStorage {
  static const String _key = 'contracoes_salvas';

  static Future<void> salvarContracoes(List<Contracao> contracoes) async {
    final prefs = await SharedPreferences.getInstance();

    final listaJson = contracoes
        .map((c) => jsonEncode(c.toMap()))
        .toList();

    await prefs.setStringList(_key, listaJson);
  }

  static Future<List<Contracao>> carregarContracoes() async {
    final prefs = await SharedPreferences.getInstance();

    final listaJson = prefs.getStringList(_key) ?? [];

    return listaJson
        .map((item) => Contracao.fromMap(jsonDecode(item)))
        .toList();
  }
}