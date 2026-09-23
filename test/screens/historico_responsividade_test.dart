import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/historico_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {

  String fonte() => File('lib/screens/historico_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const HistoricoScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
  );

  void esperarCabecalho() {
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
    expect(find.text('Acompanhe todos os registros'), findsOneWidget);
  }

  Size cartao(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.byType(Container),
        )
        .first,
  );

  group('HistoricoScreen — regressão de posição', () {
    testWidgets('o título não se moveu com o retrofit', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      expect(tester.getRect(find.text('Histórico')).top, closeTo(52.5, 3));
    });
  });

  group('HistoricoScreen — responsividade', () {
    Telas.todas.forEach((nome, tamanho) {
      testWidgets('cabe em $nome', (tester) async {
        await abrir(tester, tamanho: tamanho);

        expect(tester.takeException(), isNull);
        esperarCabecalho();
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
        esperarCabecalho();
      });

      testWidgets('cabe com fonte $escala em tela pequena', (tester) async {
        await abrir(
          tester,
          tamanho: Telas.pequena,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
        esperarCabecalho();
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

    testWidgets('os filtros do cabeçalho cabem com fonte ampliada', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: 1.5);

      for (final filtro in ['Hoje', 'Semana', 'Mês']) {
        expect(find.text(filtro), findsOneWidget, reason: filtro);
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('HistoricoScreen — cabeçalho encaixado', () {
    testWidgets('a faixa ocupa a largura inteira e encosta no topo', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);

      final faixa = tester.getRect(
        find
            .ancestor(
              of: find.text('Histórico'),
              matching: find.byType(Container),
            )
            .last,
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

  group('HistoricoScreen — estrutura', () {
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

    test('a barra decorativa não voltou', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('navBar')));
      expect(codigo, isNot(contains('auto_graph_rounded')));
      expect(codigo, isNot(contains('chat_bubble_outline_rounded')));
    });

    testWidgets('o Voltar do cabeçalho continua lá', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      expect(find.text('Voltar'), findsOneWidget);
    });

    test('a leitura continua passando pelo storage', () {
      final codigo = fonte();

      expect(codigo, contains('ContracoesStorage.carregarContracoes()'));
      expect(codigo, isNot(contains('listaContracoes')));
    });

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];
      final esteTeste = File(
        'test/screens/historico_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
