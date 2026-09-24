import 'consentimento_storage.dart';
import 'gestacao_storage.dart';

enum Destino { consentimento, home, onboarding }

class ProximoDestino {
  static Future<Destino> calcular() async {
    final doc = GestacaoStorage.documentoDoUsuario;
    if (doc == null) return Destino.consentimento;

    final snapshot = await doc.get();
    return decidir(
      snapshot.data(),
      restaurarDUM: () => GestacaoStorage.restaurarDUM(snapshot),
    );
  }

  static Future<Destino> decidir(
    Map<String, dynamic>? dados, {
    required Future<bool> Function() restaurarDUM,
  }) async {
    if (!ConsentimentoStorage.aceiteVigente(dados)) {
      return Destino.consentimento;
    }

    final jaConfigurou = await restaurarDUM();
    return jaConfigurou ? Destino.home : Destino.onboarding;
  }
}
