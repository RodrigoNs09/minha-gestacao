import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {
  // Responsividade da Home. Sem supressor de overflow e sem clamp de fonte
  // para baixo: um RenderFlex estourado reprova o teste.
  //
  // Os testes de comportamento da Home seguem em home_vacinas_test,
  // home_conta_test e home_gestacao_test. Este arquivo cobre só layout.

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

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const HomeScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
  );

  /// O que está sempre montado, em qualquer tela e escala.
  ///
  /// O corpo é um ListView, que constrói sob demanda: itens abaixo da
  /// dobra não existem na árvore até alguém rolar. Por isso aqui só entra
  /// o cabeçalho; o resto é verificado rolando, no grupo de rolagem.
  void esperarCabecalho() {
    expect(find.text('Minha Gestação'), findsOneWidget);
    expect(find.text('Olá, mamãe 👋'), findsOneWidget);
  }

  Size cartao(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.byType(Container),
        )
        .first,
  );

  group('Home — a tela monta', () {
    testWidgets('sem Firebase e sem estourar', (tester) async {
      await abrir(tester);

      expect(tester.takeException(), isNull);
      esperarCabecalho();
    });

    testWidgets('a barra inferior continua com as quatro abas', (tester) async {
      await abrir(tester);

      // Presença, não contagem: com o corpo num único filho do ListView
      // tudo é construído de uma vez, e o ícone de caminhada também
      // aparece no card "Histórico de Chutes".
      for (final icone in [
        Icons.home_rounded,
        Icons.directions_walk_rounded,
        Icons.sentiment_satisfied_alt_rounded,
        Icons.calendar_month_rounded,
      ]) {
        expect(find.byIcon(icone), findsWidgets, reason: '$icone');
      }
    });

    testWidgets('a barra inferior fica fora da área rolável', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      final nav = tester.getRect(find.byIcon(Icons.home_rounded));
      final rolagem = tester.getRect(find.byType(Scrollable).first);

      // O que prova que o bottomNav não entrou na rolagem junto com o
      // cabeçalho: ele fica abaixo do fim da viewport do ListView.
      expect(nav.top, greaterThanOrEqualTo(rolagem.bottom - 1));
    });
  });

  group('Home — geometria do título', () {
    testWidgets('o título não se moveu com o retrofit', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      // 57,0 dp era a posição antes do retrofit, com a moldura fixa e o
      // topo do cabeçalho em 48. Depois de entrar a MolduraResponsiva
      // (padding 8) e o cabeçalho ir para dentro do ListView, o topo de 40
      // devolve exatamente os mesmos 57,0 — medido, não estimado.
      expect(tester.getRect(find.text('Minha Gestação')).top, closeTo(57, 3));
    });
  });

  group('Home — responsividade', () {
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
  });

  group('Home — rolagem do corpo', () {
    ScrollPosition posicaoDoCorpo(WidgetTester tester) => tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(MolduraResponsiva),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    testWidgets('em tela pequena o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      expect(posicaoDoCorpo(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('em paisagem o corpo rola', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem);

      expect(posicaoDoCorpo(tester).maxScrollExtent, greaterThan(0));
    });

    testWidgets('num tablet alto o conteúdo cabe sem rolar', (tester) async {
      await abrir(tester, tamanho: Telas.tablet);

      expect(posicaoDoCorpo(tester).maxScrollExtent, 0);
    });

    testWidgets('em 600x960 o corpo ainda rola um pouco', (tester) async {
      await abrir(tester, tamanho: Telas.tabletPequeno);

      // 136,5 dp — medido. Com o cabeçalho dentro da rolagem, 960 dp de
      // altura deixaram de comportar o corpo inteiro; antes do retrofit o
      // cabeçalho ficava fora e só o corpo disputava o espaço. Rolar aqui
      // é o comportamento correto, não um defeito a espremer.
      expect(posicaoDoCorpo(tester).maxScrollExtent, closeTo(136.5, 2));
    });

    testWidgets('o conteúdo do fim da lista é alcançável em tela pequena', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.pequena);

      await tester.ensureVisible(find.text('Histórico de Chutes'));
      await tester.pumpAndSettle();

      expect(find.text('Histórico de Chutes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Home — o cabeçalho continua encaixado no cartão', () {
    testWidgets('ocupa a largura inteira do cartão', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      // A faixa do cabeçalho é o Container com surfaceVariant logo abaixo
      // do ListView; comparar com o cartão prova que o padding lateral de
      // 18 não vazou para ele quando entrou na rolagem.
      final faixa = tester.getRect(
        find
            .ancestor(
              of: find.text('Olá, mamãe 👋'),
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
    });

    testWidgets('encosta no topo do cartão', (tester) async {
      await abrir(tester, tamanho: Telas.g10);

      final faixa = tester.getRect(
        find
            .ancestor(
              of: find.text('Olá, mamãe 👋'),
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

      // Sem os 20 dp de topo que o ListView tinha antes.
      expect(faixa.top, closeTo(moldura.top, 1));
    });
  });

  group('Home — estrutura', () {
    testWidgets('a Home usa mesmo a MolduraResponsiva', (tester) async {
      await abrir(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
    });

    test('a moldura não é reimplementada na Home', () {
      final codigo = fonteDoMain();

      expect(codigo, contains('MolduraResponsiva('));
      expect(codigo, isNot(contains('width: 360')));
      expect(codigo, isNot(contains('minHeight: 760')));
      expect(codigo, isNot(contains('minHeight: 620')));
      expect(codigo, isNot(contains('width: 300')));
      expect(codigo, isNot(contains('BoxConstraints(maxWidth:')));
    });

    test('o Scaffold da Home continua encolhendo com o teclado', () {
      // A Home não tem formulário: nada a desativar.
      final codigo = fonteDoMain();

      expect(codigo, isNot(contains('resizeToAvoidBottomInset')));
    });

    test('o ValueListenableBuilder do tema não foi tocado', () {
      final codigo = fonteDoMain();

      expect(codigo, contains('ValueListenableBuilder<ThemeMode>'));
      expect(codigo, contains('valueListenable: themeNotifier'));
    });

    test('bottomNav continua depois do Expanded, no fim da Column', () {
      final codigo = fonteDoMain();

      final moldura = codigo.indexOf('MolduraResponsiva(');
      final expanded = codigo.indexOf('Expanded(', moldura);
      final nav = codigo.indexOf('bottomNav(context)', moldura);

      expect(moldura, greaterThan(-1));
      expect(expanded, greaterThan(moldura));
      expect(nav, greaterThan(expanded), reason: 'bottomNav vem por último');
    });

    test('nenhum supressor de overflow neste arquivo de teste', () {
      // Agulhas por concatenação: como literais inteiros, casariam com esta
      // própria asserção.
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];

      final esteTeste = File(
        'test/screens/home_responsividade_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(esteTeste, isNot(contains(agulha)), reason: agulha);
      }
    });
  });
}
