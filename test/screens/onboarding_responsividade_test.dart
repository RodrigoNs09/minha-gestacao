import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/onboarding_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {

  String fonte() => File('lib/screens/onboarding_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const OnboardingScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
  );

  void esperarTelaInteira() {
    expect(find.text('Bem-vinda ao\nMinha Gestação'), findsOneWidget);
    expect(find.text('Sei quantas semanas estou'), findsOneWidget);
    expect(find.text('Sei a data prevista do parto'), findsOneWidget);
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

  group('OnboardingScreen — regressão de posição', () {
    testWidgets('o cartão preenche a altura disponível', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      expect(cartao(tester).height, closeTo(835 - 16, 1));
    });

    testWidgets('o título fica onde o conteúdo centralizado manda', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);

      expect(
        tester.getRect(find.text('Bem-vinda ao\nMinha Gestação')).top,
        closeTo(212, 3),
      );
    });
  });

  group('OnboardingScreen — responsividade', () {
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
        await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);
        esperarTelaInteira();
      });

      testWidgets('cabe com fonte $escala em paisagem', (tester) async {
        await abrir(tester, tamanho: Telas.paisagem, escalaDeTexto: escala);

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

  group('OnboardingScreen — rolagem', () {
    testWidgets('em paisagem o conteúdo rola', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem);

      expect(corpo(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('num tablet alto o conteúdo cabe sem rolar', (tester) async {
      await abrir(tester, tamanho: Telas.tablet);

      expect(corpo(tester).maxScrollExtent, 0);
    });

    testWidgets('a segunda opção é alcançável em tela pequena', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      await tester.ensureVisible(find.text('Sei a data prevista do parto'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('OnboardingScreen — estrutura', () {
    testWidgets('usa mesmo a MolduraResponsiva', (tester) async {
      await abrir(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
    });

    test('a moldura não é reimplementada na tela', () {
      final codigo = fonte();

      expect(codigo, contains('MolduraResponsiva('));
      expect(codigo, isNot(contains('width: 360')));
      expect(codigo, isNot(contains('minHeight: 760')));
      expect(codigo, isNot(contains('BoxConstraints(maxWidth:')));
      expect(codigo, isNot(contains('BorderRadius.circular(36)')));
    });

    test('o SingleChildScrollView original foi preservado', () {
      final codigo = fonte();

      expect(codigo, contains('SingleChildScrollView('));
      expect(codigo, contains('padding: const EdgeInsets.all(28)'));
    });

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];
      final esteTeste = File(
        'test/screens/onboarding_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
