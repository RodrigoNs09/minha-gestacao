import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;

  setUp(() => gestacaoOriginal = gestacaoAtual);

  tearDown(() {
    gestacaoAtual = gestacaoOriginal;
    listaContracoes = [];
  });

  String fonteDoMain() => File('lib/main.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  Future<void> montarHome(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
  }

  group('C1 — Home sem gestação informada', () {
    testWidgets('não exibe semana, progresso nem semanas restantes', (
      tester,
    ) async {
      encerrarGestacao();
      await montarHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.textContaining('% concluído'), findsNothing);
      expect(find.textContaining('faltam'), findsNothing);
      expect(find.textContaining('trimestre'), findsNothing);
      expect(find.textContaining('º dia'), findsNothing);
    });

    testWidgets('mostra a chamada para informar a gestação', (tester) async {
      encerrarGestacao();
      await montarHome(tester);

      expect(find.text('Informe sua gestação'), findsOneWidget);
      expect(find.textContaining('Toque aqui para informar'), findsOneWidget);
    });

    testWidgets('não mostra o tamanho do bebê fabricado', (tester) async {
      encerrarGestacao();
      await montarHome(tester);

      expect(find.textContaining('Tam. '), findsNothing);
      expect(find.text('Toque para editar'), findsNothing);
    });

    testWidgets('tocar no cartão abre o editor de DUM', (tester) async {
      encerrarGestacao();
      await montarHome(tester);

      await tester.tap(find.text('Informe sua gestação'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });
  });

  group('C1 — regressão: com gestação informada nada muda', () {
    testWidgets('volta a exibir semana, progresso e semanas restantes', (
      tester,
    ) async {
      definirGestacao(
        DateTime.now().subtract(const Duration(days: 20 * 7)),
        'gestacao-1',
      );
      await montarHome(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('1º dia · 2º trimestre'), findsOneWidget);
      expect(find.textContaining('% concluído'), findsOneWidget);
      expect(find.textContaining('faltam'), findsOneWidget);
      expect(find.textContaining('Tam. '), findsOneWidget);
      expect(find.text('Toque para editar'), findsOneWidget);
      expect(find.text('Informe sua gestação'), findsNothing);
    });

    testWidgets('o cartão configurado continua abrindo o editor', (
      tester,
    ) async {
      definirGestacao(
        DateTime.now().subtract(const Duration(days: 20 * 7)),
        'gestacao-1',
      );
      await montarHome(tester);

      await tester.tap(find.text('Toque para editar'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar'), findsOneWidget);
    });
  });

  group('Estrutural — C1 e A4 na Home', () {
    test('o cartão escolhe pelo campo configurada', () {
      final codigo = fonteDoMain();

      expect(
        codigo,
        contains('if (!g.configurada) return gestacaoNaoConfiguradaCard'),
      );
    });

    test('o cartão não configurado não lê nenhum valor derivado da DUM', () {
      final codigo = fonteDoMain();
      final inicio = codigo.indexOf(
        'Widget gestacaoNaoConfiguradaCard(BuildContext context)',
      );
      expect(inicio, greaterThan(-1));

      final corpo = codigo.substring(inicio, codigo.indexOf('\n  }\n', inicio));

      for (final derivado in [
        'semanaAtual',
        'diaAtual',
        'trimestre',
        'percentualConcluido',
        'semanasRestantes',
        'dataProvavelParto',
        'tamanhoBebe',
      ]) {
        expect(corpo, isNot(contains(derivado)), reason: derivado);
      }
    });

    test('o recarregamento guarda mounted depois do await', () {
      final codigo = fonteDoMain();
      final inicio = codigo.indexOf('Future<void> _recarregar() async {');
      expect(inicio, greaterThan(-1));

      final corpo = codigo.substring(inicio, codigo.indexOf('\n  }\n', inicio));

      final espera = corpo.indexOf(
        'await ContracoesStorage.carregarContracoes()',
      );
      final guarda = corpo.indexOf('if (!mounted) return;', espera);
      final estado = corpo.indexOf('setState(', espera);

      expect(guarda, greaterThan(espera));
      expect(guarda, lessThan(estado));
    });
  });
}
