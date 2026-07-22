import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chute_sessao.dart';

class ChutesStorage {
  static const String _key = 'sessoes_chutes';
  static const String _keyEmAndamento = 'chute_em_andamento';

  static Future<void> salvarSessoes(List<ChuteSessao> sessoes) async {
    final prefs = await SharedPreferences.getInstance();
    final listaJson = sessoes.map((s) => jsonEncode(s.toMap())).toList();
    await prefs.setStringList(_key, listaJson);
  }

  static Future<List<ChuteSessao>> carregarSessoes() async {
    final prefs = await SharedPreferences.getInstance();
    final listaJson = prefs.getStringList(_key) ?? [];
    return listaJson.map((item) => ChuteSessao.fromMap(jsonDecode(item))).toList();
  }

  // Salva o progresso da sessão em andamento (não completa ainda)
  static Future<void> salvarProgressoAtual({
    required int chutes,
    required String data,
    required String horaInicio,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyEmAndamento, jsonEncode({
      'chutes': chutes,
      'data': data,
      'horaInicio': horaInicio,
    }));
  }

  static Future<Map<String, dynamic>?> carregarProgressoAtual() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_keyEmAndamento);
    if (valor == null) return null;
    return jsonDecode(valor);
  }

  static Future<void> limparProgressoAtual() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyEmAndamento);
  }
}