import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/login_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

void main() {
  String fonte() => File('lib/screens/login_screen.dart')
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

  Future<void> montar(
    WidgetTester tester, {
    Size tamanho = const Size(360, 800),
    double escalaDeTexto = 1.0,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: escalaDeTexto,
          maxScaleFactor: escalaDeTexto,
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirTeclado(
    WidgetTester tester, {
    double altura = 322,
  }) async {
    tester.view.viewInsets = FakeViewPadding(bottom: altura);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  group('LoginScreen — entrada da recuperação', () {
    testWidgets('mostra o link Esqueci minha senha', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Esqueci minha senha'), findsOneWidget);
    });

    testWidgets('o link não substitui a criação de conta', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Não tem conta? Criar agora'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('o link abre o formulário de recuperação', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar senha'), findsOneWidget);
      expect(find.text('Enviar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('vem preenchido com o e-mail já digitado', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'E-mail'),
        '  gestante@exemplo.com  ',
      );
      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      final campos = tester.widgetList<TextField>(
        find.widgetWithText(TextField, 'E-mail'),
      );

      expect(
        campos.any((c) => c.controller?.text == 'gestante@exemplo.com'),
        isTrue,
      );
    });

    testWidgets('e-mail em branco não dispara envio', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Enviar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Informe seu e-mail.'), findsOneWidget);
      expect(find.text('Recuperar senha'), findsOneWidget);
    });

    testWidgets('dá para cancelar sem enviar nada', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar senha'), findsNothing);
      expect(find.text('Entrar'), findsOneWidget);
    });
  });

  group('LoginScreen — neutralidade da recuperação', () {
    test('a confirmação é condicional, nunca afirma que a conta existe', () {
      final codigo = fonte();

      expect(codigo, contains('Se houver uma conta com esse e-mail'));
      for (final vazamento in [
        'E-mail não cadastrado',
        'Conta não encontrada',
        'não existe',
        'Este e-mail já está cadastrado',
      ]) {
        expect(codigo, isNot(contains(vazamento)), reason: vazamento);
      }
    });

    test('a mesma mensagem vale para qualquer e-mail informado', () {
      final corpo = corpoDoMetodo('Future<void> _abrirRecuperacao(');

      expect(corpo, contains('AuthService.recuperarSenha(email: email)'));
      expect(corpo, contains('_avisoNeutroDeRecuperacao'));
      expect(
        '_avisoNeutroDeRecuperacao'.allMatches(fonte()).length,
        2,
        reason: 'uma declaração e um uso',
      );
    });

    test('o aviso só aparece quando o envio foi aceito', () {
      final corpo = corpoDoMetodo('Future<void> _abrirRecuperacao(');
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      expect(normalizado, contains('if (enviou != true || !mounted) return;'));
    });

    test('o diálogo não trava a tela', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('PopScope')));
      expect(
        codigo.replaceAll(RegExp(r'\s+'), ' '),
        isNot(contains('barrierDismissible: false')),
      );
    });

    test('a recuperação não toca no login em si', () {
      final corpo = corpoDoMetodo('Future<void> _abrirRecuperacao(');

      expect(corpo, isNot(contains('AuthService.login(')));
      expect(corpo, isNot(contains('pushAndRemoveUntil')));
    });

    test('o controlador do diálogo é descartado', () {
      final corpo = corpoDoMetodo('Future<void> _abrirRecuperacao(');

      expect(corpo, contains('controller.dispose()'));
    });
  });

  group('LoginScreen — responsividade', () {
    void esperarFormularioInteiro() {
      expect(find.text('Minha Gestação'), findsOneWidget);
      expect(find.text('Entre na sua conta'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'E-mail'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Senha'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(find.text('Esqueci minha senha'), findsOneWidget);
      expect(find.text('Não tem conta? Criar agora'), findsOneWidget);
    }

    testWidgets('1. retrato normal', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      esperarFormularioInteiro();
    });

    testWidgets('2. tela pequena', (tester) async {
      await montar(tester, tamanho: const Size(320, 640));

      expect(tester.takeException(), isNull);
      esperarFormularioInteiro();
    });

    testWidgets('3. paisagem', (tester) async {
      await montar(tester, tamanho: const Size(800, 360));

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Não tem conta? Criar agora'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. teclado em retrato', (tester) async {
      await montar(tester);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
    });

    testWidgets('5. teclado em paisagem', (tester) async {
      await montar(tester, tamanho: const Size(800, 360));
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('Entrar'), findsOneWidget);
    });

    for (final escala in [1.3, 1.5]) {
      testWidgets('${escala == 1.3 ? '6' : '7'}. font_scale $escala', (
        tester,
      ) async {
        await montar(tester, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);
        esperarFormularioInteiro();
      });

      testWidgets('font_scale $escala em tela pequena', (tester) async {
        await montar(
          tester,
          tamanho: const Size(320, 640),
          escalaDeTexto: escala,
        );

        expect(tester.takeException(), isNull);
        esperarFormularioInteiro();
      });
    }

    testWidgets('font_scale 2.0 em tela pequena — limite superior', (
      tester,
    ) async {
      await montar(
        tester,
        tamanho: const Size(320, 640),
        escalaDeTexto: 2.0,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('fonte ampliada com o teclado aberto', (tester) async {
      await montar(tester, escalaDeTexto: 1.5);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('o cartão usa a largura disponível numa tela estreita', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(360, 800));

      final cartao = tester.getSize(
        find.ancestor(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Container),
        ).first,
      );

      expect(cartao.width, closeTo(336, 1));
    });

    testWidgets('o cartão não estica numa tela larga', (tester) async {
      await montar(tester, tamanho: const Size(1200, 900));

      final cartao = tester.getSize(
        find.ancestor(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Container),
        ).first,
      );

      expect(cartao.width, closeTo(400, 1));
    });

    testWidgets('a recuperação continua funcionando em tela pequena', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(320, 640));

      await tester.tap(find.text('Esqueci minha senha'));
      await tester.pumpAndSettle();

      expect(find.text('Recuperar senha'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('LoginScreen — estrutura responsiva', () {
    test('a moldura de tamanho fixo não existe mais', () {
      final corpo = corpoDoMetodo('Widget build(BuildContext context)');

      expect(corpo, isNot(contains('width: 360')));
      expect(corpo, isNot(contains('minHeight: 620')));
    });

    test('a moldura vem do widget compartilhado, não é reimplementada', () {
      final corpo = corpoDoMetodo('Widget build(BuildContext context)');

      expect(corpo, contains('MolduraResponsiva('));
      expect(corpo, isNot(contains('BoxConstraints(maxWidth:')));
      expect(corpo, isNot(contains('BorderRadius.circular(36)')));
    });

    testWidgets('a tela usa mesmo o widget compartilhado', (tester) async {
      await montar(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
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

    test('nenhum supressor de overflow na tela nem no teste', () {
      final agulhas = ['ignorarOverflow' 'DeLayout', 'FlutterError.' 'onError'];

      final esteTeste = File(
        'test/screens/login_recuperacao_test.dart',
      ).readAsStringSync();

      for (final agulha in agulhas) {
        expect(fonte(), isNot(contains(agulha)), reason: 'tela: $agulha');
        expect(esteTeste, isNot(contains(agulha)), reason: 'teste: $agulha');
      }
    });

    test('a autenticação segue igual e o destino vem da porta de entrada', () {
      final corpo = corpoDoMetodo('Future<void> _fazerLogin(');

      expect(corpo, contains('AuthService.login(email: email, senha: senha)'));
      expect(corpo, contains('const PortaDeEntrada()'));
      expect(corpo, contains('pushAndRemoveUntil'));
      expect(corpo, isNot(contains('restaurarDUM')));
      expect(corpo, isNot(contains('HomeScreen')));
      expect(corpo, isNot(contains('OnboardingScreen')));
    });
  });
}
