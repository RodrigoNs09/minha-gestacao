import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/login_screen.dart';

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
      // O aviso é uma constante única: não há ramo alternativo por conta.
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
}
