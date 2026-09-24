import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/services/consentimento_storage.dart';

void main() {
  String fonte() => File('lib/services/consentimento_storage.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String corpoDoRegistro() {
    final codigo = fonte();
    final inicio = codigo.indexOf('static Future<bool> registrarAceite(');
    expect(inicio, greaterThan(-1));
    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio));
    return codigo.substring(inicio, fim);
  }

  const meses = {
    'janeiro': '01',
    'fevereiro': '02',
    'março': '03',
    'abril': '04',
    'maio': '05',
    'junho': '06',
    'julho': '07',
    'agosto': '08',
    'setembro': '09',
    'outubro': '10',
    'novembro': '11',
    'dezembro': '12',
  };

  group('ConsentimentoStorage — versão da política', () {
    test('a versão é a data de "Última atualização" da política pública', () {
      final politica = File('public/privacidade.html').readAsStringSync();
      final m = RegExp(
        r'Última atualização: (\d{1,2}) de (\w+) de (\d{4})',
      ).firstMatch(politica);

      expect(m, isNotNull, reason: 'data não encontrada na política');

      final dia = m!.group(1)!.padLeft(2, '0');
      final mes = meses[m.group(2)!];
      final ano = m.group(3)!;

      expect(mes, isNotNull, reason: m.group(2));
      expect(ConsentimentoStorage.versaoPoliticaVigente, '$ano-$mes-$dia');
    });

    test('a política informa o que o registro do aceite guarda', () {
      final politica = File('public/privacidade.html')
          .readAsStringSync()
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ');

      expect(
        politica,
        contains(
          'o aplicativo registra na sua conta a data e a hora do aceite e a '
          'versão desta política que você aceitou, identificada pela data da '
          'última atualização.',
        ),
      );
      expect(
        politica,
        contains('o registro das versões anteriores é mantido.'),
      );
      expect(politica, contains('Esse registro é apagado junto com a conta.'));
    });

    test('a versão tem o formato aaaa-mm-dd', () {
      expect(
        ConsentimentoStorage.versaoPoliticaVigente,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });
  });

  group('ConsentimentoStorage — onde grava', () {
    test('grava no documento raiz do usuário', () {
      expect(fonte(), contains(".collection('usuarios').doc(uid)"));
    });

    test('os dois campos têm os nomes decididos', () {
      expect(ConsentimentoStorage.campo, 'consentimento_saude');
      expect(
        ConsentimentoStorage.campoHistorico,
        'consentimento_saude_historico',
      );
    });

    test('sem sessão não grava nada', () {
      expect(corpoDoRegistro(), contains('if (doc == null) return false;'));
    });

    test('não mexe no GestacaoStorage nem usa batch', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('GestacaoStorage')));
      expect(codigo, isNot(contains('batch')));
    });
  });

  group('ConsentimentoStorage — o que grava', () {
    test('o registro atual leva a versão e o horário do servidor', () {
      final normalizado = corpoDoRegistro().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        normalizado,
        contains(
          "campo: { 'versao_politica': versaoPoliticaVigente, "
          "'aceito_em': FieldValue.serverTimestamp(), }",
        ),
      );
    });

    test('o histórico guarda o horário do servidor por versão', () {
      final normalizado = corpoDoRegistro().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        normalizado,
        contains(
          'campoHistorico: {versaoPoliticaVigente: '
          'FieldValue.serverTimestamp()}',
        ),
      );
    });

    test('grava com merge, sem apagar os outros campos do documento', () {
      expect(corpoDoRegistro(), contains('SetOptions(merge: true)'));
    });
  });

  group('ConsentimentoStorage — só vale confirmado no servidor', () {
    test('lê do servidor antes de gravar: sem conexão, nem começa', () {
      final corpo = corpoDoRegistro();
      final leitura = corpo.indexOf(
        'await doc.get(const GetOptions(source: Source.server))',
      );
      final gravacao = corpo.indexOf('await doc.set(');

      expect(leitura, greaterThan(-1));
      expect(gravacao, greaterThan(leitura));
    });

    test('espera o backend reconhecer antes de devolver sucesso', () {
      final corpo = corpoDoRegistro();
      final gravacao = corpo.indexOf('await doc.set(');
      final espera = corpo.indexOf(
        'await FirebaseFirestore.instance.waitForPendingWrites()',
      );
      final sucesso = corpo.indexOf('return true;');

      expect(espera, greaterThan(gravacao));
      expect(sucesso, greaterThan(espera));
    });

    test('não engole erro: a falha sobe para a tela tratar', () {
      final corpo = corpoDoRegistro();

      expect(corpo, isNot(contains('catch')));
      expect(corpo, isNot(contains('try')));
    });
  });
}
