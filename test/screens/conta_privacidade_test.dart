import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/screens/conta_screen.dart';
import 'package:suacontracao_ai/services/links_publicos.dart';

import '../support/responsivo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    mensageiro.setMockMethodCallHandler(LinksPublicos.canal, null);
    mensageiro.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  void semNavegador() {
    mensageiro.setMockMethodCallHandler(
      LinksPublicos.canal,
      (_) async => false,
    );
  }

  Future<void> tocarNaPolitica(WidgetTester tester) async {
    final alvo = find.text('Política de Privacidade');

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

  group('ContaScreen — Política de Privacidade', () {
    testWidgets('a tela oferece a política', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Política de Privacidade'), findsOneWidget);
    });

    testWidgets('o toque abre a política pública no navegador', (
      tester,
    ) async {
      final pedidas = <Object?>[];
      mensageiro.setMockMethodCallHandler(LinksPublicos.canal, (chamada) async {
        pedidas.add(chamada.arguments);
        return true;
      });

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();
      await tocarNaPolitica(tester);

      expect(pedidas, [
        {'url': LinksPublicos.politicaDePrivacidade},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sem navegador mostra o endereço para copiar', (tester) async {
      semNavegador();
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();
      await tocarNaPolitica(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              w.data == LinksPublicos.politicaDePrivacidade,
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('fechar o aviso devolve a tela', (tester) async {
      semNavegador();
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();
      await tocarNaPolitica(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Fechar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Conta'), findsOneWidget);
    });

    testWidgets('copiar leva o endereço exato e confirma', (tester) async {
      semNavegador();
      String? copiado;
      mensageiro.setMockMethodCallHandler(SystemChannels.platform, (
        chamada,
      ) async {
        if (chamada.method == 'Clipboard.setData') {
          copiado = (chamada.arguments as Map)['text'] as String?;
        }
        return null;
      });

      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();
      await tocarNaPolitica(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Copiar link'));
      await tester.pumpAndSettle();

      expect(copiado, LinksPublicos.politicaDePrivacidade);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Link copiado.'), findsOneWidget);
    });

    testWidgets('o aviso de fallback cabe em 320x568 com fonte 1.5', (
      tester,
    ) async {
      semNavegador();
      await montar(
        tester,
        const ContaScreen(),
        tamanho: Telas.pequena,
        escalaDeTexto: 1.5,
      );
      await tocarNaPolitica(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ContaScreen — texto da exclusão', () {
    Future<void> abrirConfirmacao(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ContaScreen()));
      await tester.pumpAndSettle();

      final alvo = find.text('Excluir minha conta');
      await tester.ensureVisible(alvo);
      await tester.pumpAndSettle();
      await tester.tap(alvo);
      await tester.pumpAndSettle();
    }

    Finder noDialogo(Finder alvo) =>
        find.descendant(of: find.byType(AlertDialog), matching: alvo);

    testWidgets('avisa que a senha será pedida', (tester) async {
      await abrirConfirmacao(tester);

      expect(
        noDialogo(find.textContaining('confirmar sua senha')),
        findsOneWidget,
      );
    });

    testWidgets('inclui humor e peso entre os dados apagados', (tester) async {
      await abrirConfirmacao(tester);

      expect(noDialogo(find.textContaining('humor e peso')), findsOneWidget);
    });
  });
}
