import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/register_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

import '../support/responsivo.dart';

void main() {

  String fonte() => File('lib/screens/register_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String corpoDoMetodo(String assinatura) {
    final codigo = fonte();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  Future<void> abrir(
    WidgetTester tester, {
    Size tamanho = Telas.comum,
    double escalaDeTexto = 1.0,
  }) => montar(
    tester,
    const RegisterScreen(),
    tamanho: tamanho,
    escalaDeTexto: escalaDeTexto,
  );

  void esperarFormularioInteiro() {
    expect(find.text('Criar conta'), findsWidgets);
    expect(find.text('Comece a acompanhar sua gestação'), findsOneWidget);
    expect(find.text('Voltar'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Senha (mín. 6 caracteres)'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Confirmar senha'), findsOneWidget);
  }

  Size cartao(WidgetTester tester) => tester.getSize(
    find
        .descendant(
          of: find.byType(MolduraResponsiva),
          matching: find.byType(Container),
        )
        .first,
  );

  group('RegisterScreen — a tela monta', () {
    testWidgets('sem Firebase e sem estourar', (tester) async {
      await abrir(tester);

      expect(tester.takeException(), isNull);
      esperarFormularioInteiro();
    });

    testWidgets('o botão de criar conta está presente', (tester) async {
      await abrir(tester);

      expect(find.widgetWithText(ElevatedButton, 'Criar conta'), findsOneWidget);
    });

    testWidgets('a senha começa oculta e o olho a revela', (tester) async {
      await abrir(tester);

      TextField campoSenha() => tester.widget<TextField>(
        find.widgetWithText(TextField, 'Senha (mín. 6 caracteres)'),
      );

      expect(campoSenha().obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_rounded));
      await tester.pumpAndSettle();

      expect(campoSenha().obscureText, isFalse);
    });
  });

  group('RegisterScreen — validações continuam valendo', () {
    Future<void> preencherEEnviar(
      WidgetTester tester, {
      required String email,
      required String senha,
      required String confirmar,
    }) async {
      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'),
        email,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Senha (mín. 6 caracteres)'),
        senha,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirmar senha'),
        confirmar,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pumpAndSettle();
    }

    testWidgets('campos vazios são recusados', (tester) async {
      await abrir(tester);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pumpAndSettle();

      expect(find.text('Preencha todos os campos.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('senha curta é recusada', (tester) async {
      await abrir(tester);

      await preencherEEnviar(
        tester,
        email: 'gestante@exemplo.com',
        senha: '123',
        confirmar: '123',
      );

      expect(
        find.text('A senha deve ter pelo menos 6 caracteres.'),
        findsOneWidget,
      );
    });

    testWidgets('senhas diferentes são recusadas', (tester) async {
      await abrir(tester);

      await preencherEEnviar(
        tester,
        email: 'gestante@exemplo.com',
        senha: 'segredo123',
        confirmar: 'outrasenha',
      );

      expect(find.text('As senhas não coincidem.'), findsOneWidget);
    });

    testWidgets('a mensagem de erro cabe na tela menor', (tester) async {
      await abrir(tester, tamanho: Telas.pequena);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pumpAndSettle();

      expect(find.text('Preencha todos os campos.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('RegisterScreen — responsividade', () {
    Telas.todas.forEach((nome, tamanho) {
      testWidgets('cabe em $nome', (tester) async {
        await abrir(tester, tamanho: tamanho);

        expect(tester.takeException(), isNull);
        esperarFormularioInteiro();
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
        esperarFormularioInteiro();
      });

      testWidgets('cabe com fonte $escala em tela pequena', (tester) async {
        await abrir(
          tester,
          tamanho: Telas.pequena,
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
        esperarFormularioInteiro();
      });
    }

    testWidgets('a largura não depende da escala de fonte', (tester) async {
      await abrir(tester, tamanho: Telas.g10);
      final normal = cartao(tester).width;

      await abrir(tester, tamanho: Telas.g10, escalaDeTexto: 1.5);

      expect(cartao(tester).width, closeTo(normal, 0.01));
    });
  });

  group('RegisterScreen — teclado e rolagem', () {
    testWidgets('teclado em retrato não estoura', (tester) async {
      await abrir(tester, tamanho: Telas.g10);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('teclado em paisagem não estoura', (tester) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      expect(tester.takeException(), isNull);
    });

    testWidgets('com o teclado aberto o botão continua alcançável', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      await tester.ensureVisible(
        find.widgetWithText(ElevatedButton, 'Criar conta'),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ElevatedButton, 'Criar conta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('todos os campos continuam alcançáveis com o teclado', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      for (final rotulo in [
        'E-mail',
        'Senha (mín. 6 caracteres)',
        'Confirmar senha',
      ]) {
        await tester.ensureVisible(find.widgetWithText(TextField, rotulo));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextField, rotulo), findsOneWidget,
            reason: rotulo);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('em paisagem com teclado a tela realmente rola', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.paisagem);
      await abrirTeclado(tester, altura: alturaDeTecladoPaisagem);

      final posicao = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      expect(posicao.maxScrollExtent, greaterThan(0));
    });

    testWidgets('em retrato folgado não há rolagem — visual preservado', (
      tester,
    ) async {
      await abrir(tester, tamanho: Telas.tablet);

      final posicao = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position;

      expect(posicao.maxScrollExtent, 0);
    });
  });

  group('RegisterScreen — estrutura', () {
    testWidgets('a tela usa mesmo a MolduraResponsiva', (tester) async {
      await abrir(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
    });

    test('a moldura não é reimplementada na tela', () {
      final corpo = corpoDoMetodo('Widget build(BuildContext context)');

      expect(corpo, contains('MolduraResponsiva('));
      expect(corpo, isNot(contains('width: 360')));
      expect(corpo, isNot(contains('minHeight: 620')));
      expect(corpo, isNot(contains('BoxConstraints(maxWidth:')));
      expect(corpo, isNot(contains('BorderRadius.circular(36)')));
    });

    test('o SingleChildScrollView original foi preservado', () {
      final corpo = corpoDoMetodo('Widget build(BuildContext context)');

      expect(corpo, contains('SingleChildScrollView('));
      expect(corpo, contains('padding: const EdgeInsets.all(28)'));
    });

    test('o Scaffold continua encolhendo com o teclado', () {
      final corpo = corpoDoMetodo('Widget build(BuildContext context)');

      expect(corpo, isNot(contains('resizeToAvoidBottomInset: false')));
    });

    test('a lógica de cadastro não foi tocada', () {
      final corpo = corpoDoMetodo('Future<void> _cadastrar(');

      expect(corpo, contains('AuthService.cadastrar(email: email, senha: senha)'));
      expect(corpo, contains('GestacaoStorage.restaurarDUM()'));
      expect(corpo, contains('pushAndRemoveUntil'));
      expect(corpo, contains('senha.length < 6'));
      expect(corpo, contains('senha != confirmar'));
    });

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];

      final esteTeste = File(
        'test/screens/register_screen_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });
  });
}
