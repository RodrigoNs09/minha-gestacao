import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/registro_vacinacao.dart';

class VacinasStorage {
  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _colecao {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('vacinas');
  }

  static String? novoId() => _colecao?.doc().id;

  static Future<List<RegistroVacinacao>> carregarRegistros() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs
        .map((doc) => RegistroVacinacao.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  static Future<RegistroVacinacao?> adicionar(RegistroVacinacao registro) async {
    final colecao = _colecao;
    if (colecao == null) return null;

    // Reaproveita o id recebido: um retry sobrescreve o mesmo documento em
    // vez de virar mais uma dose no histórico.
    final id = registro.id ?? colecao.doc().id;
    final salvo = registro.comId(id);
    await colecao.doc(id).set(salvo.toMap());
    return salvo;
  }

  static Future<bool> remover(String id) async {
    final colecao = _colecao;
    if (colecao == null) return false;

    await colecao.doc(id).delete();
    return true;
  }
}
