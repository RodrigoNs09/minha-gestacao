import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {

  Widget conteudo({int itens = 3}) => Column(
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: const Text('Cabeçalho'),
      ),
      Expanded(
        child: ListView(
          children: [
            for (var i = 0; i < itens; i++) ListTile(title: Text('Item $i')),
          ],
        ),
      ),
    ],
  );

  Widget telaCom(Widget filho, {double maxWidth = 400}) => Scaffold(
    backgroundColor: const Color(0xFFF0EEFF),
    body: MolduraResponsiva(maxWidth: maxWidth, child: filho),
  );

  Size cartao(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.byType(Container),
        )
        .first,
  );

  group('MolduraResponsiva — largura em cada tela', () {
    Telas.todas.forEach((nome, tamanho) {
      testWidgets('cabe e respeita as constraints em $nome', (tester) async {
        await montar(tester, telaCom(conteudo()), tamanho: tamanho);

        expect(tester.takeException(), isNull);
        expect(
          cartao(tester).width,
          closeTo(larguraEsperadaDoCartao(tamanho.width), 1),
          reason: nome,
        );
      });
    });

    testWidgets('em 411 dp o cartão fica em 387,43 dp', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.g10);

      expect(cartao(tester).width, closeTo(387.43, 1));
    });

    testWidgets('em 800 dp o cartão para no teto de 400 dp', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.tablet);

      expect(cartao(tester).width, closeTo(400, 1));
    });

    testWidgets('em 320 dp usa a largura disponível, não o teto', (
      tester,
    ) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.pequena);

      expect(cartao(tester).width, closeTo(296, 1));
    });

    testWidgets('maxWidth é configurável', (tester) async {
      await montar(
        tester,
        telaCom(conteudo(), maxWidth: 500),
        tamanho: Telas.tablet,
      );

      expect(cartao(tester).width, closeTo(500, 1));
    });

    testWidgets('o cartão fica centralizado', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.tablet);

      final caixa = tester.getRect(
        find
            .descendant(
              of: find.byType(MolduraResponsiva),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(caixa.left, closeTo(800 - caixa.right, 1));
    });
  });

  group('MolduraResponsiva — altura e orientação', () {
    testWidgets('não estoura em paisagem', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.paisagem);

      expect(tester.takeException(), isNull);
      expect(find.text('Cabeçalho'), findsOneWidget);
    });

    testWidgets('não estoura numa altura muito pequena', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: const Size(360, 200));

      expect(tester.takeException(), isNull);
    });

    testWidgets('não estoura com o teclado aberto', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.g10);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('não estoura em paisagem com o teclado aberto', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      expect(tester.takeException(), isNull);
    });

    testWidgets('a altura é livre — acompanha o espaço disponível', (
      tester,
    ) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.comum);
      final baixa = cartao(tester).height;

      await montar(tester, telaCom(conteudo()), tamanho: Telas.tablet);
      final alta = cartao(tester).height;

      expect(alta, greaterThan(baixa));
      expect(alta, lessThanOrEqualTo(1280 - 16));
    });

    testWidgets('muito conteúdo rola em vez de estourar', (tester) async {
      await montar(
        tester,
        telaCom(conteudo(itens: 80)),
        tamanho: Telas.pequena,
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('MolduraResponsiva — fonte ampliada', () {
    for (final escala in [1.3, 1.5, 2.0]) {
      testWidgets('a moldura não estoura com fonte $escala', (tester) async {
        await montar(
          tester,
          telaCom(conteudo()),
          tamanho: Telas.pequena,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('a largura não muda com fonte $escala', (tester) async {
        await montar(
          tester,
          telaCom(conteudo()),
          tamanho: Telas.g10,
          escalaDeTexto: escala,
        );

        expect(cartao(tester).width, closeTo(387.43, 1));
      });
    }
  });

  group('MolduraResponsiva — SafeArea', () {
    testWidgets('a SafeArea é o widget mais externo da moldura', (
      tester,
    ) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.comum);

      final externa = find
          .descendant(
            of: find.byType(MolduraResponsiva),
            matching: find.byType(SafeArea),
          )
          .first;

      expect(externa, findsOneWidget);
      expect(
        find.descendant(of: externa, matching: find.byType(ConstrainedBox)),
        findsWidgets,
      );
    });

    testWidgets('o recorte do sistema é respeitado', (tester) async {
      const recorte = FakeViewPadding(top: 48, bottom: 32);
      tester.view.physicalSize = Telas.comum;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewPadding = recorte;
      tester.view.padding = recorte;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewPadding);
      addTearDown(tester.view.resetPadding);

      await tester.pumpWidget(MaterialApp(home: telaCom(conteudo())));
      await tester.pumpAndSettle();

      final caixa = tester.getRect(
        find
            .descendant(
              of: find.byType(MolduraResponsiva),
              matching: find.byType(Container),
            )
            .first,
      );

      expect(caixa.top, greaterThanOrEqualTo(48));
      expect(caixa.bottom, lessThanOrEqualTo(640 - 32));
      expect(tester.takeException(), isNull);
    });
  });

  group('MolduraResponsiva — aparência preservada', () {
    testWidgets('mantém a decoração aprovada da moldura', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.comum);

      final container = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(MolduraResponsiva),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoracao = container.decoration as BoxDecoration;

      expect(decoracao.borderRadius, BorderRadius.circular(36));
      expect((decoracao.border as Border).top.width, 0.5);
      expect(container.clipBehavior, Clip.antiAlias);
    });

    testWidgets('as cores acompanham o tema', (tester) async {
      late Color claro;
      late Color escuro;

      for (final modo in [ThemeMode.light, ThemeMode.dark]) {
        tester.view.physicalSize = Telas.comum;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: modo,
            home: telaCom(conteudo()),
          ),
        );
        await tester.pumpAndSettle();

        final container = tester.widget<Container>(
          find
              .descendant(
                of: find.byType(MolduraResponsiva),
                matching: find.byType(Container),
              )
              .first,
        );
        final cor = (container.decoration as BoxDecoration).color!;
        if (modo == ThemeMode.light) {
          claro = cor;
        } else {
          escuro = cor;
        }
      }

      expect(claro, isNot(escuro));
    });

    testWidgets('o child é renderizado dentro da moldura', (tester) async {
      await montar(tester, telaCom(conteudo()), tamanho: Telas.comum);

      expect(
        find.descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.text('Cabeçalho'),
        ),
        findsOneWidget,
      );
    });
  });

  group('MolduraResponsiva — o molde antigo não pode voltar', () {
    test('o widget não tem largura nem altura fixas', () {
      final codigo = File(
        'lib/widgets/moldura_responsiva.dart',
      ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join(
        '\n',
      );

      expect(codigo, isNot(contains('width: 300')));
      expect(codigo, isNot(contains('width: 360')));
      expect(codigo, isNot(contains('minHeight:')));
      expect(codigo, contains('SafeArea('));
      expect(codigo, contains('ConstrainedBox('));
    });

    test('o widget não carrega lógica de negócio', () {
      final codigo = File('lib/widgets/moldura_responsiva.dart')
          .readAsStringSync();

      for (final proibido in [
        'Firebase',
        'Storage',
        'Navigator',
        'setState',
        'Future',
      ]) {
        expect(codigo, isNot(contains(proibido)), reason: proibido);
      }
      expect(codigo, contains('extends StatelessWidget'));
    });
  });
}
