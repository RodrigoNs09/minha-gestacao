import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/models/contracao.dart';
import 'package:suacontracao_ai/screens/analise_screen.dart';

void main() {
  tearDown(() => listaContracoes = []);

  String fonteDaTela() => File('lib/screens/analise_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String corpoDoMetodo(String assinatura) {
    final codigo = fonteDaTela();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  Future<void> montar(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: AnaliseScreen()));
    await tester.pumpAndSettle();
  }

  group('AnaliseScreen — carregamento', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('falha de leitura avisa e mantém a tela utilizável', (
      tester,
    ) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(AnaliseScreen), findsOneWidget);
      expect(find.byType(SnackBar), findsWidgets);
    });

    testWidgets('falha de leitura não apaga o que estava em memória', (
      tester,
    ) async {
      listaContracoes = [
        Contracao(
          id: 'c1',
          data: '2026-01-15',
          inicio: '08:00',
          fim: '08:02',
          intensidade: 'Forte',
          observacoes: '',
          duracaoSegundos: 90,
        ),
      ];

      await montar(tester);

      expect(listaContracoes, hasLength(1));
    });

    testWidgets('sair durante a leitura não dispara setState após dispose', (
      tester,
    ) async {
      ignorarOverflowDeLayout();
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: AnaliseScreen()));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('Estrutural — A3', () {
    test('o carregamento trata erro com mensagem amigável', () {
      final corpo = corpoDoMetodo('Future<void> _recarregar(');

      expect(corpo, contains('try {'));
      expect(corpo, contains('} catch (erro) {'));
      expect(corpo, contains('FirestoreErro.mensagemAmigavel(erro)'));
    });

    test('mounted é checado depois do await, antes do setState', () {
      final corpo = corpoDoMetodo('Future<void> _recarregar(');

      final espera = corpo.indexOf(
        'await ContracoesStorage.carregarContracoes',
      );
      final guarda = corpo.indexOf('if (!mounted) return;', espera);
      final estado = corpo.indexOf('setState(', espera);

      expect(guarda, greaterThan(espera));
      expect(guarda, lessThan(estado));
    });

    test('mounted também guarda o caminho de erro', () {
      final corpo = corpoDoMetodo('Future<void> _recarregar(');

      expect('if (!mounted) return;'.allMatches(corpo).length, 2);
    });
  });
}
