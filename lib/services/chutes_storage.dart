import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chute_sessao.dart';

class ChutesStorage {
  static const String campoProgresso = 'chute_em_andamento';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>>? get _colecao {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('usuarios')
        .doc(uid)
        .collection('chutes');
  }

  static DocumentReference<Map<String, dynamic>>? get _documentoConfig {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('usuarios').doc(uid);
  }

  static bool idEhEnderecavel(String id) => id.isNotEmpty && !id.contains('/');

  static String? novoId() => _colecao?.doc().id;

  static Future<ChuteSessao?> adicionar(ChuteSessao sessao) async {
    final colecao = _colecao;
    if (colecao == null) return null;

    final idDaSessao = sessao.id ?? '';
    final id = idEhEnderecavel(idDaSessao) ? idDaSessao : colecao.doc().id;
    final gravada = sessao.comId(id);

    await colecao.doc(id).set(gravada.toMap());
    return gravada;
  }

  static Future<List<ChuteSessao>> carregarSessoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs
        .map((doc) => ChuteSessao.fromMap(doc.data(), idDoDocumento: doc.id))
        .toList();
  }

  static Future<bool> salvarProgressoAtual(ProgressoDeChutes progresso) async {
    final doc = _documentoConfig;
    if (doc == null) return false;

    await doc.set({campoProgresso: progresso.toMap()}, SetOptions(merge: true));
    return true;
  }

  static Future<ProgressoDeChutes?> carregarProgressoAtual() async {
    final doc = _documentoConfig;
    if (doc == null) return null;

    final snapshot = await doc.get();
    if (!snapshot.exists) return null;

    return ProgressoDeChutes.deBruto(snapshot.data()?[campoProgresso]);
  }

  static Future<bool> limparProgressoAtual() async {
    final doc = _documentoConfig;
    if (doc == null) return false;

    await doc.set({
      campoProgresso: FieldValue.delete(),
    }, SetOptions(merge: true));
    return true;
  }
}
