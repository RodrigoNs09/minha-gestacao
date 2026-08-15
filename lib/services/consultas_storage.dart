import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/consulta.dart';

class ConsultasStorage {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _colecao {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('consultas');
  }

  static Future<void> salvarConsultas(List<Consulta> consultas) async {
    final colecao = _colecao;
    if (colecao == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final existentes = await colecao.get();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }

    for (final c in consultas) {
      // Usa o id que a própria Consulta já gera (timestamp) como ID do documento
      final novoDoc = colecao.doc(c.id);
      batch.set(novoDoc, c.toMap());
    }

    await batch.commit();
  }

  static Future<List<Consulta>> carregarConsultas() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => Consulta.fromMap(doc.data())).toList();
  }
}