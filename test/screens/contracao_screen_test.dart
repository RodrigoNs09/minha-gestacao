import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/screens/contracao_screen.dart';

void main() {
  tearDown(() => listaContracoes = []);

  String fonteDaTela() => File('lib/screens/contracao_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String corpoDoMetodo(String fonte, String assinatura) {
    final inicio = fonte.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = fonte.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return fonte.substring(inicio, fim);
  }

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  // O cronômetro é um Timer.periodic: pumpAndSettle nunca assentaria.
  Future<void> assentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  // A transição de saída do AlertDialog é mais longa que os 50 ms de
  // assentar. O cronômetro já está parado aqui, então pumpar mais não conta
  // segundos a mais.
  Future<void> fecharDialogo(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> montar(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ContracaoScreen()));
    await assentar(tester);
  }

  Future<void> iniciarEContar(WidgetTester tester, int segundos) async {
    await tester.tap(find.text('▶ Iniciar Contração'));
    await tester.pump();

    for (var i = 0; i < segundos; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  Future<void> pararESalvar(WidgetTester tester) async {
    await tester.tap(find.text('■ Parar e Salvar'));
    await assentar(tester);
  }

  group('ContracaoScreen — montagem', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Registrar Contração'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('▶ Iniciar Contração'), findsOneWidget);
    });

    testWidgets('não oferece descarte quando não há medição', (tester) async {
      await montar(tester);

      expect(find.text('Descartar medição'), findsNothing);
    });
  });

  group('ContracaoScreen — salvar sem iniciar', () {
    testWidgets('avisa e não grava nada', (tester) async {
      await montar(tester);

      await pararESalvar(tester);

      expect(tester.takeException(), isNull);
      expect(
        find.text('Inicie uma contração antes de salvar.'),
        findsOneWidget,
      );
      expect(listaContracoes, isEmpty);
      expect(find.text('00:00'), findsOneWidget);
    });
  });

  group('ContracaoScreen — cronômetro', () {
    testWidgets('iniciar liga o contador', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);

      expect(find.text('00:01'), findsOneWidget);
      expect(find.text('Contração em andamento...'), findsOneWidget);
    });

    testWidgets('o contador avança segundo a segundo', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 3);

      expect(find.text('00:03'), findsOneWidget);
    });

    testWidgets('iniciar de novo durante a medição não reinicia', (
      tester,
    ) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await tester.tap(find.text('Contração em andamento...'));
      await tester.pump(const Duration(seconds: 1));

      // Um único timer: se dois estivessem correndo, saltaria para 00:05.
      expect(find.text('00:03'), findsOneWidget);
    });
  });

  group('ContracaoScreen — falha ao salvar preserva a medição', () {
    testWidgets('a duração medida não é zerada', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('00:02'), findsOneWidget);
      expect(find.text('00:00'), findsNothing);
    });

    testWidgets('nada entra na lista em memória', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);

      expect(listaContracoes, isEmpty);
    });

    testWidgets('mostra mensagem amigável', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);
      await pararESalvar(tester);

      expect(find.byType(SnackBar), findsWidgets);
      expect(find.text('Contração salva com sucesso!'), findsNothing);
    });

    testWidgets('o botão de salvar volta a aceitar toque', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);
      await pararESalvar(tester);

      expect(find.text('■ Parar e Salvar'), findsOneWidget);
      expect(find.text('Salvando...'), findsNothing);
    });

    testWidgets('o cronômetro para de verdade — não volta a andar', (
      tester,
    ) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.pump(const Duration(seconds: 3));

      expect(find.text('00:02'), findsOneWidget);
    });

    testWidgets('a retentativa mantém a mesma duração', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.pump(const Duration(seconds: 3));
      await pararESalvar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('00:02'), findsOneWidget);
      expect(listaContracoes, isEmpty);
    });
  });

  group('ContracaoScreen — descartar medição', () {
    testWidgets('o botão só aparece com medição pendente', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);
      expect(find.text('Descartar medição'), findsNothing);

      await pararESalvar(tester);
      expect(find.text('Descartar medição'), findsOneWidget);
    });

    testWidgets('tocar abre a confirmação', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.tap(find.text('Descartar medição'));
      await assentar(tester);

      expect(find.text('Descartar medição?'), findsOneWidget);
      expect(find.textContaining('00:02'), findsWidgets);
      expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Descartar'), findsOneWidget);
    });

    testWidgets('cancelar mantém a medição intacta', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.tap(find.text('Descartar medição'));
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await fecharDialogo(tester);

      expect(find.text('Descartar medição?'), findsNothing);
      expect(find.text('00:02'), findsOneWidget);
      expect(find.text('Descartar medição'), findsOneWidget);
      expect(find.text('Contração em andamento...'), findsOneWidget);
    });

    testWidgets('confirmar volta ao estado ocioso', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.tap(find.text('Descartar medição'));
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Descartar'));
      await fecharDialogo(tester);

      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('▶ Iniciar Contração'), findsOneWidget);
      expect(find.text('Descartar medição'), findsNothing);
      expect(listaContracoes, isEmpty);
    });

    testWidgets('depois do descarte dá para medir de novo', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 2);
      await pararESalvar(tester);
      await tester.tap(find.text('Descartar medição'));
      await assentar(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Descartar'));
      await fecharDialogo(tester);

      await iniciarEContar(tester, 1);

      expect(tester.takeException(), isNull);
      expect(find.text('00:01'), findsOneWidget);
    });

    testWidgets('a confirmação não trava a tela', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);
      await pararESalvar(tester);
      await tester.tap(find.text('Descartar medição'));
      await assentar(tester);

      final cancelar = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancelar'),
      );

      expect(cancelar.onPressed, isNotNull);
      expect(fonteDaTela(), isNot(contains('PopScope')));
    });
  });

  group('ContracaoScreen — ciclo de vida', () {
    testWidgets('sair da tela não dispara setState após dispose', (
      tester,
    ) async {
      ignorarOverflowDeLayout();
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: ContracaoScreen()));
      await assentar(tester);

      await iniciarEContar(tester, 2);
      await tester.tap(find.text('■ Parar e Salvar'));
      // Desmonta no meio da gravação.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 3));

      expect(tester.takeException(), isNull);
    });

    testWidgets('o timer não sobrevive ao dispose', (tester) async {
      await montar(tester);

      await iniciarEContar(tester, 1);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump(const Duration(seconds: 5));

      expect(tester.takeException(), isNull);
    });
  });

  group('Estrutural — P3: novoId dentro do try', () {
    test('a cunhagem do id fica no bloco protegido', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> pararESalvarContracao(',
      );

      final abreTry = corpo.indexOf('try {');
      final cunhagem = corpo.indexOf(
        '_idPendente ??= ContracoesStorage.novoId()',
      );
      final fechaTry = corpo.indexOf('} catch (e) {');

      expect(abreTry, greaterThan(-1));
      expect(cunhagem, greaterThan(abreTry));
      expect(cunhagem, lessThan(fechaTry));
    });
  });

  group('Estrutural — P4: iniciar guarda o salvamento', () {
    test('retorna imediatamente com medição ou gravação em curso', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'void iniciarContracao(');

      expect(corpo, contains('if (_emAndamento || _salvando) return;'));
    });
  });

  group('Estrutural — P5: timer cancelado antes de recriar', () {
    test('iniciarContracao cancela o timer anterior', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'void iniciarContracao(');

      final cancelamento = corpo.indexOf('_timer?.cancel()');
      final criacao = corpo.indexOf('Timer.periodic');

      expect(cancelamento, greaterThan(-1));
      expect(criacao, greaterThan(cancelamento));
    });

    test('o descarte também cancela o timer', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _descartarMedicao(',
      );

      expect(corpo, contains('_timer?.cancel()'));
    });

    test('dispose continua cancelando', () {
      expect(
        corpoDoMetodo(fonteDaTela(), 'void dispose('),
        contains('_timer?.cancel()'),
      );
    });
  });

  group('Estrutural — P1/P2: fim congelado e preservado no erro', () {
    test('o fim é congelado com ??=, não recalculado', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> pararESalvarContracao(',
      );

      expect(corpo, contains('_fimDateTime ??= DateTime.now();'));
      expect(corpo, isNot(contains('final fimDateTime = DateTime.now();')));
      expect(corpo, contains('final fimDateTime = _fimDateTime!;'));
    });

    test('o caminho de falha não zera a medição', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> pararESalvarContracao(',
      );

      final falha = corpo.indexOf('setState(() => _salvando = false);');
      expect(falha, greaterThan(-1));

      final depoisDaFalha = corpo.substring(falha);
      for (final preservado in [
        '_segundos = 0',
        '_inicioDateTime = null',
        '_fimDateTime = null',
        '_idPendente = null',
      ]) {
        expect(depoisDaFalha, isNot(contains(preservado)), reason: preservado);
      }
    });

    test('o caminho de sucesso limpa tudo', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> pararESalvarContracao(',
      );

      final sucesso = corpo.indexOf('if (salva != null)');
      final falha = corpo.indexOf('setState(() => _salvando = false);');
      final blocoDeSucesso = corpo.substring(sucesso, falha);

      for (final limpo in [
        '_emAndamento = false',
        '_segundos = 0',
        '_inicioDateTime = null',
        '_fimDateTime = null',
        '_idPendente = null',
      ]) {
        expect(blocoDeSucesso, contains(limpo), reason: limpo);
      }
    });

    test('a pendência de gravação é derivada, não um campo solto', () {
      expect(
        fonteDaTela(),
        contains(
          'bool get _pendenteDeGravacao => _emAndamento && _fimDateTime != null;',
        ),
      );
    });

    test('o botão de descarte depende da pendência', () {
      expect(fonteDaTela(), contains('if (_pendenteDeGravacao)'));
      expect(
        fonteDaTela(),
        contains('onPressed: _salvando ? null : _descartarMedicao'),
      );
    });

    test('o descarte passa pela confirmação antes de limpar', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _descartarMedicao(',
      );

      final guarda = corpo.indexOf('if (!await _confirmarDescarte()) return;');
      final limpeza = corpo.indexOf('_emAndamento = false');

      expect(guarda, greaterThan(-1));
      expect(limpeza, greaterThan(guarda));
      expect(corpo, contains('if (!mounted) return;'));
    });

    test('nenhum setState pós-await sem mounted antes', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> pararESalvarContracao(',
      );

      final await_ = corpo.indexOf('await ContracoesStorage.adicionar(');
      final guarda = corpo.indexOf('if (!mounted) return;', await_);
      final setStateDepois = corpo.indexOf('setState(', await_);

      expect(guarda, greaterThan(await_));
      expect(guarda, lessThan(setStateDepois));
    });
  });
}
