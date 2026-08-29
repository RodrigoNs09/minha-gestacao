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

  /// Gera um id de documento novo, sem round-trip de rede — permite à tela
  /// reaproveitar o mesmo id em retries de uma mesma contração, tornando o
  /// `set()` de [adicionar] idempotente em vez de criar um documento por
  /// tentativa. Retorna `null` quando não há sessão ativa.
  static String? novoId() => _colecao?.doc().id;

  /// Grava uma contração nova como um documento próprio.
  ///
  /// Uma única operação `set` em um caminho que ainda não existe na coleção.
  /// Não enumera, não apaga e não toca em nenhum outro documento — substitui
  /// o antigo `salvarContracoes`, que apagava a coleção inteira e a reescrevia
  /// a partir da memória a cada save.
  ///
  /// O identificador é gerado no cliente por `colecao.doc().id`, sem
  /// round-trip, e devolvido junto com a contração. Some o `id` prévio é
  /// reaproveitado quando presente, para que uma retentativa reescreva o
  /// mesmo documento em vez de criar um duplicado.
  ///
  /// Retorna `null` quando não há sessão ativa. O chamador precisa tratar
  /// esse caso: antes, a ausência de usuário virava um no-op silencioso e a
  /// tela ainda anunciava sucesso.
  ///
  /// Nota: `set` só resolve o Future após confirmação do servidor. Offline,
  /// a escrita fica enfileirada no cache local e o `await` permanece pendente
  /// — comportamento idêntico ao do `batch.commit()` anterior.
  static Future<Contracao?> adicionar(Contracao nova) async {
    final colecao = _colecao;
    if (colecao == null) return null; // usuário não logado

    final id = nova.id ?? colecao.doc().id;
    final salva = nova.comId(id);
    await colecao.doc(id).set(salva.toMap());
    return salva;
  }

  /// Caminho canônico de leitura.
  ///
  /// Usa [Contracao.fromDoc], que adota `doc.id` como identidade. Até aqui a
  /// leitura chamava `Contracao.fromMap(doc.data())` e descartava o `doc.id`,
  /// jogando fora um identificador que já existia no Firestore.
  ///
  /// Compatibilidade: documentos no esquema legado (sem o campo
  /// `duracaoSegundos`) continuam funcionando — o construtor de [Contracao]
  /// deriva a duração do prefixo "Duração: MM:SS" em `observacoes`. A
  /// derivação acontece apenas em memória; nada é gravado de volta.
  ///
  /// ATENÇÃO para quem for mexer na gravação: o `id` devolvido aqui é
  /// estável. Desde que [adicionar] substituiu o antigo delete-all, nenhum
  /// documento é recriado com auto-ID novo — o identificador de um registro
  /// não muda mais entre sessões.
  static Future<List<Contracao>> carregarContracoes() async {
    final colecao = _colecao;
    if (colecao == null) return [];

    final snapshot = await colecao.get();
    return snapshot.docs.map((doc) => Contracao.fromDoc(doc)).toList();
  }
}