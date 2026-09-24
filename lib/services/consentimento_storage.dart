import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConsentimentoStorage {
  static const String versaoPoliticaVigente = '2026-09-24';

  static const String campo = 'consentimento_saude';
  static const String campoHistorico = 'consentimento_saude_historico';

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  static DocumentReference<Map<String, dynamic>>? get _documento {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('usuarios').doc(uid);
  }

  static Future<bool> registrarAceite() async {
    final doc = _documento;
    if (doc == null) return false;

    await doc.get(const GetOptions(source: Source.server));

    await doc.set({
      campo: {
        'versao_politica': versaoPoliticaVigente,
        'aceito_em': FieldValue.serverTimestamp(),
      },
      campoHistorico: {versaoPoliticaVigente: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.waitForPendingWrites();

    return true;
  }
}
