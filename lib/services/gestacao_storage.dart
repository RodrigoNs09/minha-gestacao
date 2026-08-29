import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/gestacao_data.dart';

class GestacaoStorage {
  static const String _campo = 'gestacao_dum';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _documento {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('usuarios').doc(uid);
  }

  static Future<void> salvarDUM(DateTime data) async {
    final doc = _documento;
    if (doc == null) return;

    await doc.set(
      {_campo: data.toIso8601String()},
      SetOptions(merge: true), // não apaga outros campos do usuário
    );
  }

  static Future<DateTime?> carregarDUM() async {
    final doc = _documento;
    if (doc == null) return null;

    final snapshot = await doc.get();
    if (!snapshot.exists) return null;

    final valor = snapshot.data()?[_campo];
    if (valor == null) return null;

    return DateTime.tryParse(valor);
  }

  // Carrega a DUM persistida e, se existir, sincroniza gestacaoAtual com ela.
  static Future<bool> restaurarDUM() async {
    final dum = await carregarDUM();
    if (dum != null) {
      atualizarDUM(dum);
    }
    return dum != null;
  }
}