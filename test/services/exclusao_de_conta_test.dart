import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String fonte() => fonteDe('lib/services/exclusao_de_conta.dart');

  String corpoDoMetodo(String assinatura, {String? arquivo}) {
    final codigo = arquivo == null ? fonte() : fonteDe(arquivo);
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  String corpoDoExecutar() =>
      corpoDoMetodo('static Future<ResultadoDaExclusao> executar(');

  List<String> arquivosDeLibQueCitam(String trecho) {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'))
        .where(
          (arquivo) => arquivo
              .readAsLinesSync()
              .where((linha) => !linha.trimLeft().startsWith('//'))
              .join('\n')
              .contains(trecho),
        )
        .map((arquivo) => arquivo.path.replaceAll(Platform.pathSeparator, '/'))
        .toList()
      ..sort();
  }

  group('ExclusaoDeConta — a reautenticação vem primeiro', () {
    test('a senha é conferida antes de qualquer delete', () {
      final corpo = corpoDoExecutar();

      final reautenticacao = corpo.indexOf('AuthService.reautenticar(');
      final primeiroDelete = corpo.indexOf('delete(');

      expect(reautenticacao, greaterThan(-1));
      expect(primeiroDelete, greaterThan(-1));
      expect(reautenticacao, lessThan(primeiroDelete));
    });

    test('senha recusada interrompe antes de tocar nos dados', () {
      final normalizado = corpoDoExecutar().replaceAll(RegExp(r'\s+'), ' ');

      final recusa = normalizado.indexOf('if (erroDeSenha != null) return');
      final apagar = normalizado.indexOf('_esvaziar(');

      expect(recusa, greaterThan(-1));
      expect(apagar, greaterThan(-1));
      expect(recusa, lessThan(apagar));
    });

    test('a reautenticação usa a credencial de e-mail e senha', () {
      final corpo = corpoDoMetodo(
        'static Future<String?> reautenticar(',
        arquivo: 'lib/services/auth_service.dart',
      );

      expect(corpo, contains('reauthenticateWithCredential('));
      expect(
        corpo,
        contains('EmailAuthProvider.credential(email: email, password: senha)'),
      );
      expect(corpo, contains('on FirebaseAuthException catch'));
    });

    test('senha errada vira mensagem específica, não genérica', () {
      final corpo = corpoDoMetodo(
        'static String _traduzirErroDeConta(',
        arquivo: 'lib/services/auth_service.dart',
      );

      expect(corpo, contains("case 'wrong-password':"));
      expect(corpo, contains("case 'invalid-credential':"));
      expect(corpo, contains("return 'Senha incorreta.'"));
      expect(corpo, contains("case 'requires-recent-login':"));
      expect(corpo, contains("case 'network-request-failed':"));
    });
  });

  group('ExclusaoDeConta — acesso ao servidor antes de começar', () {
    test('existe uma leitura obrigatória com Source.server', () {
      expect(fonte(), contains('GetOptions(source: Source.server)'));
    });

    test('a leitura de checagem acontece antes do primeiro esvaziamento', () {
      final corpo = corpoDoExecutar();

      final checagem = corpo.indexOf('await raiz.get(_doServidor)');
      final apagar = corpo.indexOf('_esvaziar(');

      expect(checagem, greaterThan(-1));
      expect(checagem, lessThan(apagar));
    });

    test('a varredura também lê do servidor, nunca do cache', () {
      final corpo = corpoDoMetodo('static Future<void> _esvaziar(');

      expect(corpo, contains('.get(_doServidor)'));
    });
  });

  group('ExclusaoDeConta — as cinco subcoleções e o documento raiz', () {
    test('as cinco subcoleções entram na varredura', () {
      final corpo = corpoDoExecutar();

      for (final storage in [
        'ContracoesStorage.colecaoDoUsuario',
        'ChutesStorage.colecaoDoUsuario',
        'SintomasStorage.colecaoDoUsuario',
        'ConsultasStorage.colecaoDoUsuario',
        'VacinasStorage.colecaoDoUsuario',
      ]) {
        expect(corpo, contains(storage), reason: storage);
      }
    });

    test('o documento raiz é apagado depois das subcoleções', () {
      final corpo = corpoDoExecutar();

      final subcolecoes = corpo.indexOf('_esvaziar(colecao!)');
      final raiz = corpo.indexOf('await raiz.delete()');

      expect(subcolecoes, greaterThan(-1));
      expect(raiz, greaterThan(subcolecoes));
    });

    test('o delete do raiz também espera o backend reconhecer', () {
      final corpo = corpoDoExecutar();

      final raiz = corpo.indexOf('await raiz.delete()');
      final espera = corpo.indexOf(
        'await FirebaseFirestore.instance.waitForPendingWrites()',
        raiz,
      );

      expect(raiz, greaterThan(-1));
      expect(espera, greaterThan(raiz));
    });

    test('o raiz vem do storage que é dono dele', () {
      expect(fonte(), contains('GestacaoStorage.documentoDoUsuario'));
    });

    test('sem sessão nada é apagado', () {
      final normalizado = corpoDoExecutar().replaceAll(RegExp(r'\s+'), ' ');

      final guarda = normalizado.indexOf('if (raiz == null');
      final apagar = normalizado.indexOf('_esvaziar(');

      expect(guarda, greaterThan(-1));
      expect(guarda, lessThan(apagar));
      expect(
        normalizado,
        contains('colecoes.any((colecao) => colecao == null)'),
      );
    });
  });

  group('ExclusaoDeConta — os lotes', () {
    test('o teto é o do Firestore: 500 por lote', () {
      expect(fonte(), contains('static const int maximoPorLote = 500;'));
    });

    test('a página lida respeita o teto do lote', () {
      final corpo = corpoDoMetodo('static Future<void> _esvaziar(');

      expect(corpo, contains('.limit(maximoPorLote)'));
    });

    test('a quantidade de documentos não é presumida', () {
      final corpo = corpoDoMetodo('static Future<void> _esvaziar(');

      expect(corpo, contains('while (true)'));
      expect(corpo, contains('if (pagina.docs.isEmpty) return;'));
    });

    test('cada lote é aguardado antes do próximo', () {
      final corpo = corpoDoMetodo('static Future<void> _esvaziar(');

      final commit = corpo.indexOf('await lote.commit()');
      expect(commit, greaterThan(-1));
      expect(corpo, contains('lote.delete(documento.reference)'));

      expect(corpo.substring(commit), isNot(contains('.get(')));
    });

    test('todo commit espera o backend, não só a fila local', () {
      final corpo = corpoDoMetodo('static Future<void> _esvaziar(');

      final commit = corpo.indexOf('await lote.commit()');
      final espera = corpo.indexOf(
        'await FirebaseFirestore.instance.waitForPendingWrites()',
      );

      expect(commit, greaterThan(-1));
      expect(espera, greaterThan(commit));

      expect('await lote.commit()'.allMatches(corpo), hasLength(1));
      expect('waitForPendingWrites()'.allMatches(corpo), hasLength(1));
    });

    test('o batch vive só aqui — os storages seguem gravando por documento', () {
      expect(arquivosDeLibQueCitam('.batch()'), [
        'lib/services/exclusao_de_conta.dart',
      ]);
    });
  });

  group('ExclusaoDeConta — o Auth é o último a cair', () {
    test('user.delete() só acontece depois dos dados', () {
      final corpo = corpoDoExecutar();

      final raiz = corpo.indexOf('await raiz.delete()');
      final auth = corpo.indexOf('AuthService.excluirUsuario()');

      expect(raiz, greaterThan(-1));
      expect(auth, greaterThan(raiz));
    });

    test('nenhuma escrita fica pendente quando a sessão cai', () {
      final corpo = corpoDoExecutar();

      final espera = corpo.lastIndexOf(
        'await FirebaseFirestore.instance.waitForPendingWrites()',
      );
      final auth = corpo.indexOf('AuthService.excluirUsuario()');

      expect(espera, greaterThan(-1));
      expect(auth, greaterThan(-1));

      expect(espera, lessThan(auth));
    });

    test('excluirUsuario apaga o usuário do Firebase Auth', () {
      final corpo = corpoDoMetodo(
        'static Future<String?> excluirUsuario(',
        arquivo: 'lib/services/auth_service.dart',
      );

      expect(corpo, contains('await usuario.delete()'));
      expect(corpo, contains('on FirebaseAuthException catch'));
    });

    test('uma falha no Firestore impede a chamada ao Auth', () {
      final normalizado = corpoDoExecutar().replaceAll(RegExp(r'\s+'), ' ');

      final falha = normalizado.indexOf('} catch (erro) {');
      final auth = normalizado.indexOf('AuthService.excluirUsuario()');

      expect(falha, greaterThan(-1));
      expect(falha, lessThan(auth));
      expect(
        normalizado.substring(falha, auth),
        contains('return ResultadoDaExclusao.falha('),
      );
    });

    test('o erro do Firestore chega traduzido', () {
      expect(fonte(), contains('FirestoreErro.mensagemAmigavel(erro)'));
    });
  });

  group('ExclusaoDeConta — a sessão não é assunto do serviço', () {
    test('o orquestrador não limpa a sessão nem navega', () {
      final codigo = fonte();

      for (final fora in [
        'limparEstadoDaSessao',
        'Navigator',
        'LoginScreen',
        'setState',
      ]) {
        expect(codigo, isNot(contains(fora)), reason: fora);
      }
    });

    test('sucesso só existe quando não sobrou erro', () {
      final codigo = fonte();

      expect(codigo, contains('bool get sucesso => erro == null;'));
      expect(
        codigo,
        contains('const ResultadoDaExclusao.falha(String mensagem)'),
      );
    });
  });
}
