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

import '../support/responsivo.dart';

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

  String corpoDoMetodo(String assinatura) {
    final codigo = fonte();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  Finder noDialogo(Finder alvo) =>
      find.descendant(of: find.byType(AlertDialog), matching: alvo);

  Future<void> tocarEmExcluir(WidgetTester tester) async {
    final alvo = find.text('Excluir minha conta');

    if (alvo.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        alvo,
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(alvo);
    await tester.pumpAndSettle();
    await tester.tap(alvo);
    await tester.pumpAndSettle();
  }

  Future<void> confirmarExclusao(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
  }

  Future<void> digitarSenhaEConfirmar(
    WidgetTester tester,
    String senha,
  ) async {
    if (senha.isNotEmpty) {
      await tester.enterText(find.byType(TextField), senha);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(TextButton, 'Excluir conta'));
    await tester.pumpAndSettle();
  }

  group('ContaScreen — a exclusão é oferecida com aviso', () {
    testWidgets('a tela oferece excluir a conta', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Excluir minha conta'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('o botão abre uma confirmação que diz ser permanente', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);

      expect(find.text('Excluir minha conta?'), findsOneWidget);
      expect(noDialogo(find.textContaining('permanente')), findsOneWidget);
      expect(
        noDialogo(find.textContaining('não há como desfazer')),
        findsOneWidget,
      );
    });

    testWidgets('a confirmação enumera o que será apagado', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);

      for (final dado in [
        'contrações',
        'chutes',
        'sintomas',
        'consultas',
        'vacinas',
        'login',
      ]) {
        expect(
          noDialogo(find.textContaining(dado)),
          findsOneWidget,
          reason: dado,
        );
      }
    });

    testWidgets('cancelar a confirmação não chega a pedir a senha', (
      tester,
    ) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirme sua senha'), findsNothing);
      expect(gestacaoAtual.id, 'gestacao-1');
    });
  });

  group('ContaScreen — a senha é o último portão', () {
    testWidgets('confirmar pede a senha num campo protegido', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);

      expect(find.text('Confirme sua senha'), findsOneWidget);

      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.obscureText, isTrue);
    });

    testWidgets('desistir no campo de senha não apaga nada', (tester) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Confirme sua senha'), findsNothing);
      expect(find.text('Conta'), findsOneWidget);
      expect(gestacaoAtual.id, 'gestacao-1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('senha em branco não inicia a exclusão', (tester) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await digitarSenhaEConfirmar(tester, '');

      expect(find.textContaining('Digite sua senha'), findsOneWidget);
      expect(find.text('Conta'), findsOneWidget);
      expect(gestacaoAtual.id, 'gestacao-1');
    });
  });

  group('ContaScreen — falha na exclusão', () {
    testWidgets('sem servidor não navega e mostra erro amigável', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await digitarSenhaEConfirmar(tester, 'senha-de-teste');

      expect(tester.takeException(), isNull);
      expect(find.text('Conta'), findsOneWidget);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
    });

    testWidgets('a sessão em memória sobrevive à falha', (tester) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');
      listaContracoes = [];

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await digitarSenhaEConfirmar(tester, 'senha-de-teste');

      expect(gestacaoAtual.id, 'gestacao-1');
      expect(gestacaoAtual.dum, DateTime(2026, 1, 5));
    });

    testWidgets('o botão volta a funcionar — dá para tentar de novo', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await digitarSenhaEConfirmar(tester, 'senha-de-teste');

      final botao = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Excluir minha conta'),
      );
      expect(botao.onPressed, isNotNull);

      await tocarEmExcluir(tester);
      expect(find.text('Excluir minha conta?'), findsOneWidget);
    });

    testWidgets('sair da conta continua disponível depois da falha', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await digitarSenhaEConfirmar(tester, 'senha-de-teste');

      final sair = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Sair da conta'),
      );
      expect(sair.onPressed, isNotNull);
    });
  });

  group('ContaScreen — ordem e reentrada', () {
    test('a confirmação e a senha vêm antes de qualquer exclusão', () {
      final corpo = corpoDoMetodo('Future<void> _excluirConta(');

      final confirmacao = corpo.indexOf('_confirmarExclusao(');
      final senha = corpo.indexOf('_pedirSenha(');
      final execucao = corpo.indexOf('ExclusaoDeConta.executar(');

      expect(confirmacao, greaterThan(-1));
      expect(confirmacao, lessThan(senha));
      expect(senha, lessThan(execucao));
      expect(corpo, contains('if (!confirmado'));
      expect(corpo, contains('if (senha == null'));
    });

    test('a sessão só é limpa depois do sucesso completo', () {
      final corpo = corpoDoMetodo('Future<void> _excluirConta(');
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      final falha = normalizado.indexOf('if (!resultado.sucesso)');
      final limpeza = normalizado.indexOf('limparEstadoDaSessao()');
      final navegacao = normalizado.indexOf('pushAndRemoveUntil');

      expect(falha, greaterThan(-1));
      expect(falha, lessThan(limpeza));
      expect(limpeza, lessThan(navegacao));

      expect(normalizado.substring(falha, limpeza), contains('return;'));
    });

    test('a falha libera o estado sem limpar nem navegar', () {
      final corpo = corpoDoMetodo('Future<void> _excluirConta(');
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      final falha = normalizado.indexOf('if (!resultado.sucesso)');
      final retorno = normalizado.indexOf('return;', falha);
      final ramo = normalizado.substring(falha, retorno);

      expect(ramo, contains('_excluindo = false'));
      expect(ramo, contains('_erro = resultado.erro'));
      expect(ramo, isNot(contains('limparEstadoDaSessao')));
      expect(ramo, isNot(contains('Navigator')));
    });

    test('a navegação final substitui a pilha inteira', () {
      final corpo = corpoDoMetodo('Future<void> _excluirConta(');

      expect(corpo, contains('const LoginScreen()'));
      expect(corpo, contains('(route) => false'));
    });

    test('um segundo toque não entra enquanto o primeiro roda', () {
      expect(
        corpoDoMetodo('Future<void> _excluirConta('),
        contains('if (_ocupado) return;'),
      );
      expect(
        corpoDoMetodo('Future<void> _sairDaConta('),
        contains('if (_ocupado) return;'),
      );

      final codigo = fonte();
      expect(codigo, contains('bool get _ocupado => _saindo || _excluindo;'));
      expect(codigo, contains('onPressed: _ocupado ? null : _excluirConta'));
      expect(codigo, contains('onPressed: _ocupado ? null : _sairDaConta'));
    });

    test('a tela não fala com o Firebase direto', () {
      final codigo = fonte();

      for (final fora in [
        'reauthenticate',
        'FirebaseFirestore',
        'WriteBatch',
        '.batch()',
      ]) {
        expect(codigo, isNot(contains(fora)), reason: fora);
      }
    });
  });

  group('ContaScreen — os diálogos aguentam o teclado', () {
    for (final entrada in Telas.todas.entries) {
      testWidgets('a confirmação cabe em ${entrada.key}', (tester) async {
        await montar(tester, const ContaScreen(), tamanho: entrada.value);

        await tocarEmExcluir(tester);

        expect(find.text('Excluir minha conta?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('o campo de senha cabe em ${entrada.key} com teclado', (
        tester,
      ) async {
        await montar(tester, const ContaScreen(), tamanho: entrada.value);

        await tocarEmExcluir(tester);
        await confirmarExclusao(tester);
        await abrirTeclado(
          tester,
          altura: entrada.value.height < entrada.value.width
              ? alturaDeTecladoPaisagem
              : alturaDeTecladoRetrato,
        );

        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('o campo de senha cabe em 320x568 com fonte 1.5 e teclado', (
      tester,
    ) async {
      await montar(
        tester,
        const ContaScreen(),
        tamanho: Telas.pequena,
        escalaDeTexto: 1.5,
      );

      await tocarEmExcluir(tester);
      await confirmarExclusao(tester);
      await abrirTeclado(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a confirmação cabe em 320x568 com fonte 1.5', (tester) async {
      await montar(
        tester,
        const ContaScreen(),
        tamanho: Telas.pequena,
        escalaDeTexto: 1.5,
      );

      await tocarEmExcluir(tester);

      expect(find.text('Excluir minha conta?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
