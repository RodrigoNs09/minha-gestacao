import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro_sintomas.dart';

class SintomasStorage {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _colecao {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('sintomas');
  }

  static bool dataEhEnderecavel(String data) =>
      data.isNotEmpty && !data.contains('/');

  static DocumentReference<Map<String, dynamic>>? _documento(String data) {
    if (!dataEhEnderecavel(data)) return null;
    return _colecao?.doc(data);
  }

  static Future<RegistroSintomas?> salvarRegistro(
    RegistroSintomas registro,
  ) async {
    final doc = _documento(registro.data);
    if (doc == null) return null;

    await doc.set(registro.toMap());
    return registro;
  }

  static Future<bool> atualizarRegistro(RegistroSintomas registro) async {
    final doc = _documento(registro.data);
    if (doc == null) return false;

    await doc.update(registro.toMap());
    return true;
  }

  /// Remove só o documento daquele dia.
  static Future<bool> removerRegistro(String data) async {
    final doc = _documento(data);
    if (doc == null) return false;

    await doc.delete();
    return true;
  }

  static Future<List<RegistroSintomas>> carregarRegistros() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs
        .map(
          (doc) =>
              RegistroSintomas.fromMap(doc.data(), dataDoDocumento: doc.id),
        )
        .toList();
  }
}
