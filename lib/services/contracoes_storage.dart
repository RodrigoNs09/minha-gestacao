import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/contracao.dart';

class ContracoesStorage {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _colecao {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('contracoes');
  }

  static Future<void> salvarContracoes(List<Contracao> contracoes) async {
    final colecao = _colecao;
    if (colecao == null) return; // usuário não logado

    // Apaga tudo que existe e reescreve a lista inteira
    // (simples e suficiente para o volume de dados desse app)
    final batch = FirebaseFirestore.instance.batch();

    final existentes = await colecao.get();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }

    for (final c in contracoes) {
      final novoDoc = colecao.doc();
      batch.set(novoDoc, c.toMap());
    }

    await batch.commit();
  }

  static Future<List<Contracao>> carregarContracoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => Contracao.fromMap(doc.data())).toList();
  }
}