import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/contracao_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {
  // Responsividade da ContracaoScreen — a tela mais crítica do app.
  // Sem supressor de overflow e sem clamp de fonte para baixo.
  // Os testes de comportamento seguem em contracao_screen_test.dart,
  // intocados.
  //
  // O cronômetro é um Timer.periodic de 1s: pumpAndSettle nunca
  // assentaria, então todo montar usa assentar: false.

  String fonte() => File('lib/screens/contracao_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const ContracaoScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
    assentar: false,
  );

  Finder rolagem() => find.byType(Scrollable).first;

  /// Traz [alvo] para a viewport. O corpo é um ListView, que constrói sob
  /// demanda: em tela pequena o alvo pode nem existir na árvore ainda.
  Future<void> revelar(WidgetTester tester, Finder alvo) async {
    await tester.scrollUntilVisible(alvo, 80, scrollable: rolagem());
    await tester.pump();
  }

  /// Inicia a contração pelo caminho real — tocando no botão — e avança
  /// [segundos] no relógio, um pump por segundo, como o Timer.periodic faz.
  ///
  /// Depois volta ao topo, porque rolar até o botão descarta o cronômetro
  /// da árvore em telas pequenas.
  Future<void> cronometrar(WidgetTester tester, int segundos) async {
    final botao = find.text('▶ Iniciar Contração');
    await revelar(tester, botao);
    await tester.tap(botao);
    await tester.pump();

    for (var i = 0; i < segundos; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    await tester.drag(rolagem(), const Offset(0, 600));
    await tester.pump();
  }

  void esperarCabecalho() {
    expect(find.text('Registrar Contração'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
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

  group('ContracaoScreen — regressão de posição', () {
    testWidgets('o título não se moveu com o retrofit', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      // 56,5 dp antes do retrofit, com a moldura fixa, a SafeArea interna
      // e o topo do cabeçalho em 20. Sem a SafeArea interna e com a
      // MolduraResponsiva (padding 8), o topo de 12 devolve exatamente os
      // mesmos 56,5 — medido, não estimado.
      expect(
        tester.getRect(find.text('Registrar Contração')).top,
        closeTo(56.5, 3),
      );
    });
  });

  group('ContracaoScreen — responsividade', () {
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
        await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);
        esperarCabecalho();
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

  group('ContracaoScreen — o cronômetro', () {
    testWidgets('começa em 00:00', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      expect(find.text('00:00'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final escala in [1.0, 1.3, 1.5]) {
      testWidgets('00:00 cabe em 320 dp com fonte $escala', (tester) async {
        await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: escala);
        await cronometrar(tester, 0);

        expect(find.text('00:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('59:59 cabe em 320 dp com fonte $escala', (tester) async {
        await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: escala);
        await cronometrar(tester, 59 * 60 + 59);

        expect(find.text('59:59'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('100:00 cabe em 320 dp com fonte $escala', (tester) async {
        await abrir(tester, tamanho: Telas.pequena, escalaDeTexto: escala);
        await cronometrar(tester, 100 * 60);

        // Seis caracteres: é aqui que o texto de 48px ganha largura.
        expect(find.text('100:00'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ContracaoScreen — teclado', () {
    Future<void> focarObservacoes(WidgetTester tester) async {
      // O campo fica no fim da lista: em tela pequena e em paisagem ele
      // só passa a existir depois de rolar até lá.
      await revelar(tester, find.byType(TextField));

      final campo = find.byType(TextField);
      expect(campo, findsOneWidget);

      await tester.tap(campo);
      await tester.pump();
    }

    testWidgets('o campo de observações é alcançável em retrato', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);
      await focarObservacoes(tester);
      await abrirTeclado(tester, assentar: false);

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('o campo de observações é alcançável em paisagem', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await focarObservacoes(tester);
      await abrirTeclado(
        tester,
        altura: alturaDeTecladoPaisagem,
        assentar: false,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('com o teclado aberto o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await abrirTeclado(
        tester,
        altura: alturaDeTecladoPaisagem,
        assentar: false,
      );

      expect(corpo(tester).maxScrollExtent, greaterThan(0));
    });
  });

  group('ContracaoScreen — o tempo continua intacto', () {
    test('o Timer de 1 segundo não foi tocado', () {
      final codigo = fonte();

      expect(
        codigo,
        contains('Timer.periodic(const Duration(seconds: 1)'),
      );
    });

    test('o dispose continua cancelando timer e controller', () {
      final codigo = fonte();
      final inicio = codigo.indexOf('void dispose()');
      expect(inicio, greaterThan(-1));

      final corpoDoDispose = codigo.substring(inicio, inicio + 200);
      expect(corpoDoDispose, contains('_timer?.cancel()'));
      expect(corpoDoDispose, contains('observacoesController.dispose()'));
    });

    testWidgets('iniciar a contração faz o cronômetro andar', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      expect(find.text('00:00'), findsOneWidget);

      await cronometrar(tester, 1);
      expect(find.text('00:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:02'), findsOneWidget);
    });

    test('a barra decorativa não voltou', () {
      // Eram quatro Icon puros, sem onTap, e dois deles apontavam para
      // features removidas: auto_graph para a AnaliseScreen (código morto)
      // e chat_bubble para o Assistente de IA (descontinuado). O "Voltar"
      // do cabeçalho é quem faz a navegação de volta.
      final codigo = fonte();

      expect(codigo, isNot(contains('navBar')));
      expect(codigo, isNot(contains('auto_graph_rounded')));
      expect(codigo, isNot(contains('chat_bubble_outline_rounded')));
    });

    testWidgets('o Voltar do cabeçalho continua lá', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      expect(find.text('Voltar'), findsOneWidget);
    });
  });

  group('ContracaoScreen — rolagem', () {
    testWidgets('em tela pequena o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      expect(corpo(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('em paisagem o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem);

      expect(corpo(tester).maxScrollExtent, greaterThan(0));
    });
  });

  group('ContracaoScreen — cabeçalho encaixado', () {
    testWidgets('a faixa ocupa a largura inteira e encosta no topo', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.g10);

      final faixa = tester.getRect(
        find
            .ancestor(
              of: find.text('Registrar Contração'),
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

  group('ContracaoScreen — estrutura', () {
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

    test('a SafeArea interna foi removida', () {
      // Ela ficava dentro do Container, depois do clipBehavior: não
      // protegia das barras do sistema, só somava padding. Quem protege
      // agora é a SafeArea da MolduraResponsiva, por fora do cartão.
      expect(fonte(), isNot(contains('SafeArea')));
    });

    test('o Scaffold continua encolhendo com o teclado', () {
      // A tela tem TextField: encolher é o que permite ao scroll trazer
      // o campo para cima do teclado.
      expect(fonte(), isNot(contains('resizeToAvoidBottomInset: false')));
    });

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];
      final esteTeste = File(
        'test/screens/contracao_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
