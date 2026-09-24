import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/services/consentimento_storage.dart';
import 'package:suacontracao_ai/services/proximo_destino.dart';

void main() {
  const campo = ConsentimentoStorage.campo;
  const vigente = ConsentimentoStorage.versaoPoliticaVigente;
  final horario = Timestamp.fromDate(DateTime(2026, 9, 24, 10));

  Map<String, dynamic> comAceite(String versao, {Object? aceitoEm}) => {
    campo: {'versao_politica': versao, 'aceito_em': aceitoEm},
    'gestacao_dum': '2026-01-05T00:00:00.000',
    'gestacao_id': 'gestacao-1',
  };

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String corpoDe(String caminho, String assinatura) {
    final codigo = fonteDe(caminho);
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);
    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);
    return codigo.substring(inicio, fim);
  }

  group('ConsentimentoStorage.aceiteVigente', () {
    test('sem documento não há aceite', () {
      expect(ConsentimentoStorage.aceiteVigente(null), isFalse);
    });

    test('documento sem o campo não tem aceite', () {
      expect(
        ConsentimentoStorage.aceiteVigente({
          'gestacao_dum': '2026-01-05T00:00:00.000',
        }),
        isFalse,
      );
    });

    test('campo em formato inesperado não vale', () {
      for (final valor in [true, 'sim', vigente, 1]) {
        expect(
          ConsentimentoStorage.aceiteVigente({campo: valor}),
          isFalse,
          reason: '$valor',
        );
      }
    });

    test('aceite de outra versão da política não vale', () {
      expect(
        ConsentimentoStorage.aceiteVigente(
          comAceite('2026-01-01', aceitoEm: horario),
        ),
        isFalse,
      );
    });

    test('aceite sem o horário do servidor não vale', () {
      expect(ConsentimentoStorage.aceiteVigente(comAceite(vigente)), isFalse);
      expect(
        ConsentimentoStorage.aceiteVigente(
          comAceite(vigente, aceitoEm: '2026-09-24T10:00:00'),
        ),
        isFalse,
      );
    });

    test('o histórico sozinho não vale como aceite', () {
      expect(
        ConsentimentoStorage.aceiteVigente({
          ConsentimentoStorage.campoHistorico: {vigente: horario},
        }),
        isFalse,
      );
    });

    test('aceite da versão vigente com horário do servidor vale', () {
      expect(
        ConsentimentoStorage.aceiteVigente(
          comAceite(vigente, aceitoEm: horario),
        ),
        isTrue,
      );
    });
  });

  group('ProximoDestino.decidir — o consentimento vem antes da DUM', () {
    late int restauracoes;

    Future<bool> Function() restaurar(bool configurada) => () async {
      restauracoes++;
      return configurada;
    };

    setUp(() => restauracoes = 0);

    test('documento inexistente leva ao consentimento', () async {
      final destino = await ProximoDestino.decidir(
        null,
        restaurarDUM: restaurar(true),
      );

      expect(destino, Destino.consentimento);
      expect(restauracoes, 0);
    });

    test(
      'sem aceite gravado leva ao consentimento, sem tocar na DUM',
      () async {
        final destino = await ProximoDestino.decidir({
          'gestacao_dum': '2026-01-05T00:00:00.000',
          'gestacao_id': 'gestacao-1',
        }, restaurarDUM: restaurar(true));

        expect(destino, Destino.consentimento);
        expect(restauracoes, 0);
      },
    );

    test('versão da política mudou: consentimento de novo', () async {
      final destino = await ProximoDestino.decidir(
        comAceite('2026-01-01', aceitoEm: horario),
        restaurarDUM: restaurar(true),
      );

      expect(destino, Destino.consentimento);
      expect(restauracoes, 0);
    });

    test('aceite vigente e DUM configurada seguem para a Home', () async {
      final destino = await ProximoDestino.decidir(
        comAceite(vigente, aceitoEm: horario),
        restaurarDUM: restaurar(true),
      );

      expect(destino, Destino.home);
      expect(restauracoes, 1);
    });

    test('aceite vigente sem DUM segue para o Onboarding', () async {
      final destino = await ProximoDestino.decidir(
        comAceite(vigente, aceitoEm: horario),
        restaurarDUM: restaurar(false),
      );

      expect(destino, Destino.onboarding);
      expect(restauracoes, 1);
    });

    test('falha ao restaurar a DUM sobe para a porta de entrada', () {
      expect(
        ProximoDestino.decidir(
          comAceite(vigente, aceitoEm: horario),
          restaurarDUM: () async => throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
          ),
        ),
        throwsA(isA<FirebaseException>()),
      );
    });

    test('a checagem do aceite vem antes da restauração da DUM', () {
      final corpo = corpoDe(
        'lib/services/proximo_destino.dart',
        'static Future<Destino> decidir(',
      );

      final checagem = corpo.indexOf('ConsentimentoStorage.aceiteVigente(');
      final saida = corpo.indexOf('return Destino.consentimento;');
      final restauracao = corpo.indexOf('await restaurarDUM()');

      expect(checagem, greaterThan(-1));
      expect(saida, greaterThan(checagem));
      expect(restauracao, greaterThan(saida));
    });
  });

  group('ProximoDestino.calcular — uma leitura só, que aceita o cache', () {
    String corpo() => corpoDe(
      'lib/services/proximo_destino.dart',
      'static Future<Destino> calcular(',
    );

    test('lê o documento raiz do usuário uma única vez', () {
      final codigo = fonteDe('lib/services/proximo_destino.dart');

      expect(corpo(), contains('GestacaoStorage.documentoDoUsuario'));
      expect('.get('.allMatches(codigo), hasLength(1));
      expect(corpo(), contains('final snapshot = await doc.get();'));
    });

    test('o aceite e a DUM saem da mesma leitura', () {
      final normalizado = corpo().replaceAll(RegExp(r'\s+'), ' ');

      expect(
        normalizado,
        contains(
          'return decidir( snapshot.data(), '
          'restaurarDUM: () => GestacaoStorage.restaurarDUM(snapshot), );',
        ),
      );
    });

    test('a leitura usa a origem padrão: servidor, ou o cache sem conexão', () {
      final codigo = fonteDe('lib/services/proximo_destino.dart');

      expect(codigo, isNot(contains('GetOptions')));
      expect(codigo, isNot(contains('Source.')));
    });

    test('a leitura não engole erro: a porta de entrada mostra a falha', () {
      final codigo = fonteDe('lib/services/proximo_destino.dart');

      expect(codigo, isNot(contains('catch')));
      expect(codigo, isNot(contains('try')));
    });

    test('sem usuário, vai para o consentimento', () {
      expect(
        corpo(),
        contains('if (doc == null) return Destino.consentimento;'),
      );
    });

    test('a restauração da DUM reaproveita a leitura, sem ler de novo', () {
      final restaurar = corpoDe(
        'lib/services/gestacao_storage.dart',
        'static Future<bool> restaurarDUM(',
      );

      expect(
        restaurar,
        contains('DocumentSnapshot<Map<String, dynamic>> snapshot'),
      );
      expect(restaurar, isNot(contains('.get(')));
      expect(restaurar, contains('final doc = snapshot.reference;'));
    });
  });

  group('O aceite não fica em memória', () {
    List<String> estadoGuardado(String caminho) =>
        fonteDe(caminho).split('\n').where((linha) {
          final t = linha.trim();
          if (linha.startsWith(RegExp(r'[A-Za-z]'))) {
            return !RegExp(r'^(import|enum|class) ').hasMatch(t);
          }
          return t.startsWith('static ') &&
              !t.startsWith('static const ') &&
              !t.contains('(') &&
              !t.contains(' get ');
        }).toList();

    test('nem a decisão nem o storage guardam estado entre leituras', () {
      for (final caminho in [
        'lib/services/proximo_destino.dart',
        'lib/services/consentimento_storage.dart',
      ]) {
        expect(estadoGuardado(caminho), isEmpty, reason: caminho);
      }
    });

    test('por isso a limpeza da sessão não precisa conhecer o aceite', () {
      expect(fonteDe('lib/data/sessao.dart'), isNot(contains('consentimento')));
    });
  });
}
