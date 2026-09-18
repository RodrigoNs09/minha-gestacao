import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/conta_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {
  // Responsividade da ContaScreen. Sem supressor de overflow e sem clamp
  // de fonte para baixo. Os testes de comportamento seguem em
  // conta_screen_test.dart e home_conta_test.dart, intocados.

  String fonte() => File('lib/screens/conta_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const ContaScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
  );

  void esperarTelaInteira() {
    expect(find.text('Conta'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
    expect(find.text('Sair da conta'), findsWidgets);
  }

  Size cartao(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.byType(Container),
        )
        .first,
  );

  ScrollPosition corpo(WidgetTester tester) => tester
      .state<ScrollableState>(
        find
            .descendant(
              of: find.byType(MolduraResponsiva),
              matching: find.byType(Scrollable),
            )
            .first,
      )
      .position;

  group('ContaScreen — regressão de posição', () {
    testWidgets('o título não se moveu com o retrofit', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      // 52,5 dp antes do retrofit, com a moldura fixa e o topo do
      // cabeçalho em 20. Com a MolduraResponsiva (padding 8), o topo de 12
      // devolve exatamente os mesmos 52,5 — medido, não estimado.
      expect(tester.getRect(find.text('Conta')).top, closeTo(52.5, 3));
    });
  });

  group('ContaScreen — responsividade', () {
    Telas.todas.forEach((nome, tamanho) {
      testWidgets('cabe em $nome', (tester) async {
        await abrir(tester, tamanho: tamanho);

        expect(tester.takeException(), isNull);
        esperarTelaInteira();
      });
    });

    testWidgets('o cartão usa a largura disponível em 411,43 dp', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);

      expect(cartao(tester).width, closeTo(387.43, 1));
    });

    testWidgets('o cartão respeita o teto de 400 dp num tablet', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.tablet);

      expect(cartao(tester).width, closeTo(400, 1));
    });

    testWidgets('numa tela de 360 dp o cartão fica em 336 dp', (tester) async {
      await abrir(tester, tamanho: Telas.comum);

      expect(cartao(tester).width, closeTo(336, 1));
    });

    for (final escala in [1.3, 1.5]) {
      testWidgets('cabe com fonte $escala', (tester) async {
        await abrir(tester, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);
        esperarTelaInteira();
      });

      testWidgets('cabe com fonte $escala em tela pequena', (tester) async {
        await abrir(
          tester,
          tamanho: Telas.pequena,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
        esperarTelaInteira();
      });

      testWidgets('cabe com fonte $escala em paisagem', (tester) async {
        await abrir(
          tester,
          tamanho: Telas.paisagem,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a largura não depende da escala de fonte', (tester) async {
      await abrir(tester, tamanho: Telas.g10);
      final normal = cartao(tester).width;

      await abrir(tester, tamanho: Telas.g10, escalaDeTexto: 1.5);

      expect(cartao(tester).width, closeTo(normal, 0.01));
    });
  });

  group('ContaScreen — rolagem', () {
    testWidgets('num tablet alto o conteúdo cabe sem rolar', (tester) async {
      await abrir(tester, tamanho: Telas.tablet);

      expect(corpo(tester).maxScrollExtent, 0);
    });

    testWidgets('em paisagem com fonte ampliada o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem, escalaDeTexto: 1.5);

      expect(corpo(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('o aviso do rodapé é alcançável em tela pequena', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.pequena);

      await tester.ensureVisible(find.textContaining('Sair não apaga nada'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('ContaScreen — cabeçalho encaixado', () {
    testWidgets('a faixa ocupa a largura inteira e encosta no topo', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);

      final faixa = tester.getRect(
        find.ancestor(of: find.text('Conta'), matching: find.byType(Container)).last,
      );
      final moldura = tester.getRect(
        find
            .descendant(
              of: find.byType(MolduraResponsiva),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(faixa.left, closeTo(moldura.left, 1));
      expect(faixa.right, closeTo(moldura.right, 1));
      expect(faixa.top, closeTo(moldura.top, 1));
    });
  });

  group('ContaScreen — estrutura', () {
    testWidgets('usa mesmo a MolduraResponsiva', (tester) async {
      await abrir(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
    });

    test('a moldura não é reimplementada na tela', () {
      final codigo = fonte();

      expect(codigo, contains('MolduraResponsiva('));
      expect(codigo, isNot(contains('width: 300')));
      expect(codigo, isNot(contains('minHeight: 620')));
      expect(codigo, isNot(contains('BoxConstraints(maxWidth:')));
      expect(codigo, isNot(contains('BorderRadius.circular(36)')));
    });

    test('a lógica de sessão não foi tocada', () {
      final codigo = fonte();

      expect(codigo, contains('AuthService.usuarioAtual?.email'));
      expect(codigo, contains('AuthService.logout()'));
    });

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];
      final esteTeste = File(
        'test/screens/conta_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
