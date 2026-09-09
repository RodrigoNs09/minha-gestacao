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

  static bool idEhEnderecavel(String id) => id.isNotEmpty && !id.contains('/');

  static DocumentReference<Map<String, dynamic>>? _documento(String id) {
    if (!idEhEnderecavel(id)) return null;
    return _colecao?.doc(id);
  }

  static String? novoId() => _colecao?.doc().id;

  static Future<Consulta?> adicionar(Consulta consulta) async {
    final colecao = _colecao;
    if (colecao == null) return null;

    final id = idEhEnderecavel(consulta.id) ? consulta.id : colecao.doc().id;
    final salva = consulta.comId(id);

    await colecao.doc(id).set(salva.toMap());
    return salva;
  }

  static Future<bool> atualizar(Consulta consulta) async {
    final doc = _documento(consulta.id);
    if (doc == null) return false;

    await doc.update(consulta.toMap());
    return true;
  }

  /// Remove só o documento daquela consulta.
  static Future<bool> remover(String id) async {
    final doc = _documento(id);
    if (doc == null) return false;

    await doc.delete();
    return true;
  }

  static Future<List<Consulta>> carregarConsultas() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs
        .map((doc) => Consulta.fromMap(doc.data(), idDoDocumento: doc.id))
        .toList();
  }
}
