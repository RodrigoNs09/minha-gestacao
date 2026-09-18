import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/widgets/editar_dum_dialog.dart';

import '../support/responsivo.dart';

void main() {
  // Responsividade da folha "Editar progresso da gestação".
  // Sem supressor de overflow e sem clamp de fonte para baixo.
  // Os testes de comportamento seguem em editar_dum_dialog_test.dart,
  // intocados.
  //
  // Não é uma tela: é um showModalBottomSheet, então NÃO usa a
  // MolduraResponsiva — a folha tem moldura própria, dada pelo Material.

  String fonte() => File('lib/widgets/editar_dum_dialog.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  /// Abre a folha pelo caminho real: um botão que chama mostrarEditarDUM,
  /// como a Home faz nos dois pontos em que a oferece.
  Future<void> abrirFolha(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) async {
    await montar(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => mostrarEditarDUM(context, () {}),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
      tamanho: tamanho,
      escalaDeTexto: escalaDeTexto,
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  void esperarFolhaInteira() {
    expect(find.text('Editar progresso da gestação'), findsOneWidget);
  }

  ScrollPosition posicaoDaFolha(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  group('EditarDUM — a folha abre pelo caminho real', () {
    testWidgets('a partir de quem a chama', (tester) async {
      await abrirFolha(tester);

      expect(tester.takeException(), isNull);
      esperarFolhaInteira();
    });
  });

  group('EditarDUM — responsividade', () {
    Telas.todas.forEach((nome, tamanho) {
      testWidgets('cabe em $nome', (tester) async {
        await abrirFolha(tester, tamanho: tamanho);

        expect(tester.takeException(), isNull);
        esperarFolhaInteira();
      });
    });

    for (final escala in [1.3, 1.5]) {
      testWidgets('cabe com fonte $escala', (tester) async {
        await abrirFolha(tester, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);
        esperarFolhaInteira();
      });

      testWidgets('cabe com fonte $escala em tela pequena', (tester) async {
        await abrirFolha(
          tester,
          tamanho: Telas.pequena,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
        esperarFolhaInteira();
      });

      testWidgets('cabe com fonte $escala em paisagem', (tester) async {
        await abrirFolha(
          tester,
          tamanho: Telas.paisagem,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('EditarDUM — teclado', () {
    // A folha não tem campo de texto — a data vem de um showDatePicker —
    // mas o recuo do teclado pode chegar até ela por outros caminhos, e é
    // ele que antes empurrava o conteúdo para fora.
    testWidgets('não estoura com o recuo do teclado em retrato', (
      tester,
    ) async {
      await abrirFolha(tester, tamanho: Telas.g10);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
      esperarFolhaInteira();
    });

    testWidgets('não estoura com o recuo do teclado em paisagem', (
      tester,
    ) async {
      await abrirFolha(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      expect(tester.takeException(), isNull);
    });

    testWidgets('com o recuo do teclado em paisagem a folha rola', (
      tester,
    ) async {
      await abrirFolha(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      expect(posicaoDaFolha(tester).maxScrollExtent, greaterThan(0));
    });
  });

  group('EditarDUM — rolagem', () {
    testWidgets('em paisagem a folha rola', (tester) async {
      await abrirFolha(tester, tamanho: Telas.paisagem);

      expect(posicaoDaFolha(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('em retrato folgado a folha não rola — visual preservado', (
      tester,
    ) async {
      await abrirFolha(tester, tamanho: Telas.tablet);

      expect(posicaoDaFolha(tester).maxScrollExtent, 0);
    });

    testWidgets('o botão de salvar é alcançável em tela pequena', (
      tester,
    ) async {
      await abrirFolha(tester, tamanho: Telas.pequena, escalaDeTexto: 1.5);

      await tester.ensureVisible(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('EditarDUM — estrutura', () {
    test('a folha ganhou rolagem', () {
      expect(fonte(), contains('SingleChildScrollView('));
    });

    test('não usa a MolduraResponsiva — é folha, não tela', () {
      expect(fonte(), isNot(contains('MolduraResponsiva')));
    });

    test('o recuo do teclado e a barra de gestos entram no padding', () {
      final codigo = fonte().replaceAll(RegExp(r'\s+'), ' ');

      expect(codigo, contains('MediaQuery.of(ctx).viewInsets.bottom'));
      expect(codigo, contains('MediaQuery.of(ctx).padding.bottom'));
    });

    test('o fluxo de salvar não foi tocado', () {
      final codigo = fonte();

      expect(codigo, contains('if (resultado == true) aoSalvar()'));
      expect(codigo, contains('showDatePicker('));
    });

    test('nenhum supressor de overflow no widget nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];
      final esteTeste = File(
        'test/widgets/editar_dum_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'widget: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
