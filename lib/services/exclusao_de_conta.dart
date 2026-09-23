import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';
import 'chutes_storage.dart';
import 'consultas_storage.dart';
import 'contracoes_storage.dart';
import 'firestore_error.dart';
import 'gestacao_storage.dart';
import 'sintomas_storage.dart';
import 'vacinas_storage.dart';

class ResultadoDaExclusao {
  const ResultadoDaExclusao.sucesso() : erro = null;
  const ResultadoDaExclusao.falha(String mensagem) : erro = mensagem;

  final String? erro;

  bool get sucesso => erro == null;
}

class ExclusaoDeConta {
  static const int maximoPorLote = 500;

  static const GetOptions _doServidor = GetOptions(source: Source.server);

  static Future<ResultadoDaExclusao> executar({required String senha}) async {
    final erroDeSenha = await AuthService.reautenticar(senha: senha);
    if (erroDeSenha != null) return ResultadoDaExclusao.falha(erroDeSenha);

    final raiz = GestacaoStorage.documentoDoUsuario;
    final colecoes = <CollectionReference<Map<String, dynamic>>?>[
      ContracoesStorage.colecaoDoUsuario,
      ChutesStorage.colecaoDoUsuario,
      SintomasStorage.colecaoDoUsuario,
      ConsultasStorage.colecaoDoUsuario,
      VacinasStorage.colecaoDoUsuario,
    ];

    if (raiz == null || colecoes.any((colecao) => colecao == null)) {
      return const ResultadoDaExclusao.falha(AuthService.sessaoExpirada);
    }

    try {
      await raiz.get(_doServidor);

      for (final colecao in colecoes) {
        await _esvaziar(colecao!);
      }

      await raiz.delete();
      await FirebaseFirestore.instance.waitForPendingWrites();
    } catch (erro) {
      return ResultadoDaExclusao.falha(FirestoreErro.mensagemAmigavel(erro));
    }

    final erroDoAuth = await AuthService.excluirUsuario();
    if (erroDoAuth != null) return ResultadoDaExclusao.falha(erroDoAuth);

    return const ResultadoDaExclusao.sucesso();
  }

  static Future<void> _esvaziar(
    CollectionReference<Map<String, dynamic>> colecao,
  ) async {
    while (true) {
      final pagina = await colecao.limit(maximoPorLote).get(_doServidor);
      if (pagina.docs.isEmpty) return;

      final lote = FirebaseFirestore.instance.batch();
      for (final documento in pagina.docs) {
        lote.delete(documento.reference);
      }
      await lote.commit();

      await FirebaseFirestore.instance.waitForPendingWrites();
    }
  }
}
