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

  static bool idEhEnderecavel(String id) => id.isNotEmpty && !id.contains('/');

  static DocumentReference<Map<String, dynamic>>? _documento(String id) {
    if (!idEhEnderecavel(id)) return null;
    return _colecao?.doc(id);
  }

  static String? novoId() => _colecao?.doc().id;

  static Future<Contracao?> adicionar(Contracao nova) async {
    final colecao = _colecao;
    if (colecao == null) return null; // usuário não logado

    final idRecebido = nova.id ?? '';
    final id = idEhEnderecavel(idRecebido) ? idRecebido : colecao.doc().id;
    final salva = nova.comId(id);
    await colecao.doc(id).set(salva.toMap());
    return salva;
  }

  static Future<bool> atualizar(Contracao contracao) async {
    final doc = _documento(contracao.id ?? '');
    if (doc == null) return false;

    await doc.update(contracao.toMap());
    return true;
  }

  /// Remove só o documento daquela contração.
  static Future<bool> remover(String id) async {
    final doc = _documento(id);
    if (doc == null) return false;

    await doc.delete();
    return true;
  }

  static Future<List<Contracao>> carregarContracoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => Contracao.fromDoc(doc)).toList();
  }
}
