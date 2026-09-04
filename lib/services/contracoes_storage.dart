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

  static String? novoId() => _colecao?.doc().id;

  static Future<Contracao?> adicionar(Contracao nova) async {
    final colecao = _colecao;
    if (colecao == null) return null; // usuário não logado

    final id = nova.id ?? colecao.doc().id;
    final salva = nova.comId(id);
    await colecao.doc(id).set(salva.toMap());
    return salva;
  }

  static Future<List<Contracao>> carregarContracoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => Contracao.fromDoc(doc)).toList();
  }
}