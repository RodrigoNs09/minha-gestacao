import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/chute_sessao.dart';

class ChutesStorage {
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

  /// Adiciona apenas UMA sessão nova, sem apagar/recriar o resto.
  /// Muito mais eficiente que salvarSessoes() para o caso comum
  /// de "completou uma sessão de chutes".
  static Future<void> adicionarSessao(ChuteSessao sessao) async {
    final colecao = _colecao;
    if (colecao == null) return;
    await colecao.add(sessao.toMap());
  }

  /// Mantido para casos de sincronização completa (ex: se algum dia
  /// precisar sobrescrever tudo). Evite usar no fluxo comum.
  static Future<void> salvarSessoes(List<ChuteSessao> sessoes) async {
    final colecao = _colecao;
    if (colecao == null) return;

    final batch = FirebaseFirestore.instance.batch();

    final existentes = await colecao.get();
    for (final doc in existentes.docs) {
      batch.delete(doc.reference);
    }

    for (final s in sessoes) {
      final novoDoc = colecao.doc();
      batch.set(novoDoc, s.toMap());
    }

    await batch.commit();
  }

  static Future<List<ChuteSessao>> carregarSessoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => ChuteSessao.fromMap(doc.data())).toList();
  }

  // Progresso da sessão em andamento (não completa ainda)
  static Future<void> salvarProgressoAtual({
    required int chutes,
    required String data,
    required String horaInicio,
  }) async {
    final doc = _documentoConfig;
    if (doc == null) return;

    await doc.set({
      'chute_em_andamento': {
        'chutes': chutes,
        'data': data,
        'horaInicio': horaInicio,
      }
    }, SetOptions(merge: true));
  }

  static Future<Map<String, dynamic>?> carregarProgressoAtual() async {
    final doc = _documentoConfig;
    if (doc == null) return null;

    final snapshot = await doc.get();
    if (!snapshot.exists) return null;

    final valor = snapshot.data()?['chute_em_andamento'];
    if (valor == null) return null;
    return Map<String, dynamic>.from(valor);
  }

  static Future<void> limparProgressoAtual() async {
    final doc = _documentoConfig;
    if (doc == null) return;
    await doc.set({'chute_em_andamento': FieldValue.delete()}, SetOptions(merge: true));
  }
}