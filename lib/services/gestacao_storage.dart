import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/gestacao_data.dart';

class GestacaoStorage {
  static const String _campo = 'gestacao_dum';
  static const String _campoId = 'gestacao_id';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _documento {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('usuarios').doc(uid);
  }

  static String novoGestacaoId() =>
      FirebaseFirestore.instance.collection('usuarios').doc().id;

  static Future<void> salvarDUM(DateTime data) async {
    final doc = _documento;
    if (doc == null) return;

    final id = gestacaoAtual.id ?? novoGestacaoId();

    await doc.set(
      {_campo: data.toIso8601String(), _campoId: id},
      SetOptions(merge: true), // não apaga outros campos do usuário
    );

    definirGestacao(data, id);
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

  static Future<bool> restaurarDUM() async {
    final doc = _documento;
    if (doc == null) return false;

    final snapshot = await doc.get();
    if (!snapshot.exists) return false;

    final dados = snapshot.data();
    final bruto = dados?[_campo];
    if (bruto is! String) return false;

    final dum = DateTime.tryParse(bruto);
    if (dum == null) return false;

    final idPersistido = dados?[_campoId];
    if (idPersistido is String && idPersistido.isNotEmpty) {
      definirGestacao(dum, idPersistido);
      return true;
    }

    final id = novoGestacaoId();
    await doc.set({_campoId: id}, SetOptions(merge: true));
    definirGestacao(dum, id);
    return true;
  }
}
