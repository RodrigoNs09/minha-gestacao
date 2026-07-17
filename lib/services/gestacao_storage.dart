import 'package:shared_preferences/shared_preferences.dart';

class GestacaoStorage {
  static const String _key = 'data_ultima_menstruacao';

  static Future<void> salvarDUM(DateTime data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.toIso8601String());
  }

  static Future<DateTime?> carregarDUM() async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(_key);
    if (valor == null) return null;
    return DateTime.tryParse(valor);
  }

  static Future<bool> jaConfigurou() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}