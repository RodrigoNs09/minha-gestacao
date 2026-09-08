import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/chutes_data.dart';
import 'package:suacontracao_ai/data/consultas_data.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/data/sintomas_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/screens/conta_screen.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;

  setUp(() => gestacaoOriginal = gestacaoAtual);

  tearDown(() {
    gestacaoAtual = gestacaoOriginal;
    listaContracoes = [];
    listaChutes = [];
    listaSintomas = [];
    listaConsultas = [];
  });

  String fonte() => File('lib/screens/conta_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String fonteNormalizada() => fonte().replaceAll(RegExp(r'\s+'), ' ');

  String corpoDoMetodo(String assinatura) {
    final codigo = fonte();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  // Só código: um comentário citando "signOut" não é uma chamada.
  List<String> arquivosDeLibQueCitam(String trecho) {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'))
        .where(
          (arquivo) => arquivo
              .readAsLinesSync()
              .where((linha) => !linha.trimLeft().startsWith('//'))
              .join('\n')
              .contains(trecho),
        )
        .map((arquivo) => arquivo.path.replaceAll(Platform.pathSeparator, '/'))
        .toList()
      ..sort();
  }

  group('ContaScreen — montagem', () {
    testWidgets('monta sem Firebase e mostra o título', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Conta'), findsOneWidget);
    });

    testWidgets('mostra a área do e-mail da sessão', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('E-MAIL'), findsOneWidget);
      expect(find.text('Não disponível'), findsOneWidget);
    });

    testWidgets('oferece a saída da conta', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta'), findsOneWidget);
    });

    testWidgets('tem como voltar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Voltar'), findsOneWidget);
    });
  });

  group('ContaScreen — confirmação', () {
    testWidgets('o botão abre a confirmação', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('cancelar fecha o diálogo sem limpar a sessão', (tester) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsNothing);
      expect(gestacaoAtual.id, 'gestacao-1');
      expect(gestacaoAtual.dum, DateTime(2026, 1, 5));
    });

    testWidgets('cancelar mantém a tela utilizável', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
    });

    testWidgets('o diálogo é fechável — nada de tela travada', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      final cancelar = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancelar'),
      );

      expect(cancelar.onPressed, isNotNull);
      expect(fonte(), isNot(contains('PopScope')));
      expect(fonteNormalizada(), isNot(contains('barrierDismissible: false')));
    });
  });

  group('ContaScreen — falha ao sair', () {
    testWidgets('sem Firebase não navega e mostra erro amigável', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sair'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Conta'), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
    });

    testWidgets('depois da falha ainda dá para tentar de novo', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Sair'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();

      expect(find.text('Sair da conta?'), findsOneWidget);
    });
  });

  group('ContaScreen — ordem e navegação', () {
    test('limpa o estado antes de chamar o logout', () {
      final corpo = corpoDoMetodo('Future<void> _sairDaConta(');

      final limpeza = corpo.indexOf('limparEstadoDaSessao()');
      final logout = corpo.indexOf('AuthService.logout()');

      expect(limpeza, greaterThan(-1));
      expect(logout, greaterThan(-1));
      expect(limpeza, lessThan(logout), reason: 'limpar antes de sair');
    });

    test('só navega depois do logout, com pushAndRemoveUntil', () {
      final corpo = corpoDoMetodo('Future<void> _sairDaConta(');

      final logout = corpo.indexOf('AuthService.logout()');
      final navegacao = corpo.indexOf('pushAndRemoveUntil');

      expect(navegacao, greaterThan(logout));
      expect(corpo, contains('const LoginScreen()'));
      expect(corpo, contains('(route) => false'));
    });

    test('o caminho de erro retorna antes de navegar', () {
      final corpo = corpoDoMetodo('Future<void> _sairDaConta(');
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      final erro = normalizado.indexOf('} catch (erro) {');
      final navegacao = normalizado.indexOf('pushAndRemoveUntil');

      expect(erro, greaterThan(-1));
      expect(erro, lessThan(navegacao));
      expect(normalizado.substring(erro, navegacao), contains('return;'));
    });

    test('a confirmação é pré-requisito da saída', () {
      final corpo = corpoDoMetodo('Future<void> _sairDaConta(');

      final confirmacao = corpo.indexOf('_confirmarSaida(');
      final limpeza = corpo.indexOf('limparEstadoDaSessao()');

      expect(confirmacao, greaterThan(-1));
      expect(confirmacao, lessThan(limpeza));
      expect(corpo, contains('if (!confirmado'));
    });

    test('não oferece troca de e-mail, de senha nem exclusão de conta', () {
      final codigo = fonte();

      for (final fora in [
        'updateEmail',
        'updatePassword',
        'verifyBeforeUpdateEmail',
        'delete()',
        'reauthenticate',
      ]) {
        expect(codigo, isNot(contains(fora)), reason: fora);
      }
    });
  });

  group('Logout tem um único dono', () {
    test('só a ContaScreen chama AuthService.logout', () {
      expect(arquivosDeLibQueCitam('AuthService.logout'), [
        'lib/screens/conta_screen.dart',
      ]);
    });

    test('nenhuma tela chama signOut por fora do AuthService', () {
      expect(arquivosDeLibQueCitam('signOut'), [
        'lib/services/auth_service.dart',
      ]);
    });

    test('a limpeza de sessão só é disparada pela ContaScreen', () {
      expect(arquivosDeLibQueCitam('limparEstadoDaSessao()'), [
        'lib/data/sessao.dart',
        'lib/screens/conta_screen.dart',
      ]);
    });
  });
}
