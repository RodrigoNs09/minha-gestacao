import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';
import 'package:suacontracao_ai/screens/vacinas_screen.dart';

void main() {
  List<String> linhasDeCodigo() {
    return File('lib/screens/vacinas_screen.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .toList();
  }

  group('VacinasScreen — falha de leitura', () {
    // Sem Firebase inicializado, VacinasStorage lança ao ser chamado: é
    // exatamente o caminho de erro que a tela precisa sustentar.
    testWidgets('não quebra e mostra o painel de erro com retry', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Não foi possível carregar seus registros'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('nenhum card de vacina é exibido quando a leitura falha',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      for (final regra in calendarioPni2026) {
        expect(find.text(regra.nomeExibicao), findsNothing,
            reason: regra.codigo);
      }
    });

    testWidgets('nenhuma mensagem da engine aparece quando a leitura falha',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text(mensagemPeriodoRecomendado), findsNothing);
      expect(find.text(mensagemGeralVacinas), findsNothing);
    });

    testWidgets('o cabeçalho continua visível no estado de erro', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vacinas da Gestação'), findsOneWidget);
      expect(find.text('Calendário e seus registros'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('mostra indicador de carregamento antes de concluir',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  group('VacinasScreen — a tela não decide regra clínica', () {
    test('não exibe status.motivo', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('.motivo')));
    });

    test('a engine só é chamada num ponto, e com a temporada explícita', () {
      final codigo = linhasDeCodigo().join('\n');

      expect('VacinasEngine.avaliar('.allMatches(codigo), hasLength(1));
      expect(codigo, contains('temporadaInfluenza: null'));
    });

    test('a avaliação usa uma única referência temporal', () {
      final codigo = linhasDeCodigo().join('\n');

      expect('DateTime.now()'.allMatches(codigo), hasLength(1));
      expect(codigo, contains('dataAtual: avaliadoEm'));
      expect(codigo, contains('avaliadoEm.difference(dum).inDays'));
    });

    test('não alimenta a engine com a semana clampeada de GestacaoInfo', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('semanaAtual')));
      expect(codigo, isNot(contains('diasGestacao)')));
      expect(codigo, isNot(contains('semanaGestacionalDe')));
    });

    test('não calcula intervalo, janela nem dose por conta própria', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('Duration(')));
      expect(codigo, isNot(contains('adicionarMeses')));
      expect(codigo, isNot(contains('gestacaoPlausivel')));
      expect(codigo, isNot(contains('EstadoVacina.')));
    });

    test('a apresentação do estado vem só de apresentacaoDe', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, contains('apresentacaoDe(status.estado)'));
      expect(codigo, isNot(contains('switch (')));
      expect(codigo, isNot(matches(RegExp(r'\bColors\.(?!white)'))));
      expect(codigo, isNot(contains('Color(0x')));
    });

    test('não usa Firebase direto: o acesso passa pelo storage', () {
      final imports = linhasDeCodigo()
          .where((linha) => linha.trimLeft().startsWith('import '))
          .toList();

      expect(imports, isNotEmpty, reason: 'sanidade: o arquivo tem imports');

      for (final linha in imports) {
        expect(linha, isNot(contains('cloud_firestore')), reason: linha);
        expect(linha, isNot(contains('firebase_auth')), reason: linha);
        expect(linha, isNot(contains('firebase_core')), reason: linha);
        expect(linha, isNot(contains('ia_service')), reason: linha);
      }
      expect(imports.where((l) => l.contains('vacinas_storage')), hasLength(1));
    });

    test('nesta etapa não há cadastro, edição nem exclusão', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('VacinasStorage.adicionar')));
      expect(codigo, isNot(contains('VacinasStorage.remover')));
      expect(codigo, isNot(contains('VacinasStorage.novoId')));
      expect(codigo, isNot(contains('showModalBottomSheet')));
      expect(codigo, isNot(contains('Dismissible')));
      expect('VacinasStorage.carregarRegistros('.allMatches(codigo),
          hasLength(1));
    });

    test('nenhum texto próprio da tela usa linguagem prescritiva', () {
      const proibidos = [
        'tome agora',
        'você precisa tomar',
        'você está atrasada',
        'atrasad',
        'urgente',
        'obrigatóri',
      ];

      final codigo = linhasDeCodigo().join('\n').toLowerCase();

      for (final termo in proibidos) {
        expect(codigo, isNot(contains(termo)), reason: termo);
      }
    });
  });
}
