import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String fonte() => File('lib/services/auth_service.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  // Corpo de um método, da assinatura até a chave de fecho na indentação de
  // método. Serve para checar invariantes que valem só dentro de um deles.
  String corpoDoMetodo(String assinatura) {
    final codigo = fonte();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  group('AuthService — recuperação de senha', () {
    test('expõe recuperarSenha com e-mail nomeado', () {
      expect(
        fonte(),
        contains(
          'static Future<String?> recuperarSenha({required String email})',
        ),
      );
    });

    test('usa sendPasswordResetEmail do Firebase', () {
      final corpo = corpoDoMetodo('static Future<String?> recuperarSenha(');

      expect(corpo, contains('_auth.sendPasswordResetEmail(email: email)'));
    });

    test('devolve null em caso de sucesso', () {
      final corpo = corpoDoMetodo('static Future<String?> recuperarSenha(');

      expect(corpo, contains('return null'));
    });

    test('trata FirebaseAuthException em vez de deixar vazar', () {
      final corpo = corpoDoMetodo('static Future<String?> recuperarSenha(');

      expect(corpo, contains('on FirebaseAuthException catch'));
    });
  });

  group('AuthService — mensagem neutra', () {
    test('user-not-found na recuperação devolve sucesso, não erro', () {
      final corpo = corpoDoMetodo('static Future<String?> recuperarSenha(');
      final semEspacos = corpo.replaceAll(RegExp(r'\s+'), ' ');

      expect(
        semEspacos,
        contains("if (e.code == 'user-not-found') return null"),
      );
    });

    test('a recuperação não reaproveita o tradutor do login', () {
      final corpo = corpoDoMetodo('static Future<String?> recuperarSenha(');

      expect(corpo, isNot(contains('_traduzirErro(')));
      expect(corpo, contains('_traduzirErroDeRecuperacao('));
    });

    test('o tradutor da recuperação não cita conta inexistente', () {
      final corpo = corpoDoMetodo('static String _traduzirErroDeRecuperacao(');

      for (final vazamento in [
        'user-not-found',
        'não encontrado',
        'não existe',
        'não cadastrado',
        'já está cadastrado',
      ]) {
        expect(corpo, isNot(contains(vazamento)), reason: vazamento);
      }
    });

    test('o default da recuperação é genérico', () {
      final corpo = corpoDoMetodo('static String _traduzirErroDeRecuperacao(');

      expect(corpo, contains('default:'));
      expect(
        corpo,
        contains("return 'Não foi possível enviar o e-mail agora."),
      );
    });
  });

  group('AuthService — erros que continuam visíveis', () {
    test('e-mail inválido vira mensagem específica', () {
      final corpo = corpoDoMetodo('static String _traduzirErroDeRecuperacao(');

      expect(corpo, contains("case 'invalid-email':"));
      expect(corpo, contains("return 'E-mail inválido.'"));
    });

    test('excesso de tentativas vira mensagem específica', () {
      final corpo = corpoDoMetodo('static String _traduzirErroDeRecuperacao(');

      expect(corpo, contains("case 'too-many-requests':"));
      expect(corpo, contains('Muitas tentativas.'));
    });

    test('falha de rede é distinguível de e-mail inválido', () {
      final corpo = corpoDoMetodo('static String _traduzirErroDeRecuperacao(');

      expect(corpo, contains("case 'network-request-failed':"));
    });
  });

  group('AuthService — login preservado', () {
    test(
      'o tradutor do login segue tratando user-not-found como credencial',
      () {
        final corpo = corpoDoMetodo('static String _traduzirErro(');

        expect(corpo, contains("case 'user-not-found':"));
        expect(corpo, contains("return 'E-mail ou senha incorretos.'"));
      },
    );

    test('login e cadastro continuam usando o tradutor original', () {
      expect(
        corpoDoMetodo('static Future<String?> login('),
        contains('_traduzirErro(e.code)'),
      );
      expect(
        corpoDoMetodo('static Future<String?> cadastrar('),
        contains('_traduzirErro(e.code)'),
      );
    });

    test('logout continua sendo o único ponto de signOut', () {
      final ocorrencias = 'signOut'.allMatches(fonte()).length;

      expect(ocorrencias, 1);
    });
  });
}
