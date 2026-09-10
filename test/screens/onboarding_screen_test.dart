import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/screens/onboarding_screen.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;

  setUp(() {
    gestacaoOriginal = gestacaoAtual;
    encerrarGestacao();
  });

  tearDown(() => gestacaoAtual = gestacaoOriginal);

  String fonteDaTela() => File('lib/screens/onboarding_screen.dart')
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

    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pumpAndSettle();
  }

  Future<void> escolherSemanas(WidgetTester tester) async {
    await tester.tap(find.text('Sei quantas semanas estou'));
    await tester.pumpAndSettle();
  }

  group('OnboardingScreen — montagem', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Continuar'), findsOneWidget);
      expect(find.text('Não sei, configurar depois'), findsOneWidget);
    });

    testWidgets('Continuar fica desabilitado até escolher o modo', (
      tester,
    ) async {
      await montar(tester);

      final antes = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuar'),
      );
      expect(antes.onPressed, isNull);

      await escolherSemanas(tester);

      final depois = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuar'),
      );
      expect(depois.onPressed, isNotNull);
    });
  });

  group('OnboardingScreen — falha ao salvar', () {
    testWidgets('não navega e mostra mensagem inline', (tester) async {
      await montar(tester);
      await escolherSemanas(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Continua no onboarding.
      expect(find.text('Sei quantas semanas estou'), findsOneWidget);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
    });

    testWidgets('a falha não configura a gestação', (tester) async {
      await montar(tester);
      await escolherSemanas(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      // Sem estado fantasma: a memória só muda depois da persistência.
      expect(gestacaoAtual.configurada, isFalse);
      expect(gestacaoAtual.id, isNull);
    });

    testWidgets('o botão volta a aceitar toque depois da falha', (
      tester,
    ) async {
      await montar(tester);
      await escolherSemanas(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      final botao = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Continuar'),
      );
      expect(botao.onPressed, isNotNull);
    });

    testWidgets('tentar de novo não estoura', (tester) async {
      await montar(tester);
      await escolherSemanas(tester);

      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(gestacaoAtual.configurada, isFalse);
    });
  });

  group('OnboardingScreen — pular', () {
    testWidgets('pular não configura a gestação', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Não sei, configurar depois'));
      await tester.pump();

      expect(gestacaoAtual.configurada, isFalse);
    });
  });

  group('Estrutural — A1', () {
    test('duplo toque é bloqueado', () {
      final corpo = corpoDoMetodo('Future<void> _continuar(');

      expect(corpo, contains('if (_salvando) return;'));
    });

    test('a navegação só acontece depois de salvou == true', () {
      final corpo = corpoDoMetodo('Future<void> _continuar(');

      final falha = corpo.indexOf('if (!salvou)');
      final navegacao = corpo.indexOf('Navigator.pushReplacement');

      expect(falha, greaterThan(-1));
      expect(navegacao, greaterThan(falha));
      expect(corpo.substring(falha, navegacao), contains('return;'));
    });

    test('a exceção é capturada e traduzida', () {
      final corpo = corpoDoMetodo('Future<void> _continuar(');

      expect(corpo, contains('} catch (e) {'));
      expect(corpo, contains('FirestoreErro.mensagemAmigavel(erro)'));
      expect(corpo, contains('mensagemSemSessao'));
    });

    test('mounted é checado depois do await', () {
      final corpo = corpoDoMetodo('Future<void> _continuar(');

      final espera = corpo.indexOf('await GestacaoStorage.salvarDUM(');
      final guarda = corpo.indexOf('if (!mounted) return;', espera);
      final estado = corpo.indexOf('setState(', espera);

      expect(guarda, greaterThan(espera));
      expect(guarda, lessThan(estado));
    });

    test('o botão respeita o estado de salvamento', () {
      final codigo = fonteDaTela();

      expect(codigo, contains('(_podeContinuar && !_salvando)'));
      expect(codigo, contains('onPressed: _salvando ? null : _pular'));
    });

    test('a mensagem de erro é inline, não SnackBar', () {
      final codigo = fonteDaTela();

      expect(codigo, contains('if (_erro != null)'));
      expect(codigo, isNot(contains('showSnackBar')));
    });

    test('a memória não é escrita antes da persistência', () {
      final codigo = fonteDaTela();

      expect(codigo, isNot(contains('iniciarGestacao(')));
      expect(codigo, isNot(contains('definirGestacao(')));
      expect(codigo, isNot(contains('atualizarDUM(')));
    });
  });
}
