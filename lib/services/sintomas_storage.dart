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

  static Future<void> salvarRegistros(List<RegistroSintomas> registros) async {
    final colecao = _colecao;
    if (colecao == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final existentes = await colecao.get();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }

    for (final r in registros) {
      // Usa a data como ID do documento — evita duplicar o mesmo dia
      final novoDoc = colecao.doc(r.data);
      batch.set(novoDoc, r.toMap());
    }

    await batch.commit();
  }

  static Future<List<RegistroSintomas>> carregarRegistros() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => RegistroSintomas.fromMap(doc.data())).toList();
  }
}