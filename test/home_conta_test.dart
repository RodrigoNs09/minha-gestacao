import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/screens/conta_screen.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

void main() {
  List<String> linhasDeCodigo() {
    return File('lib/main.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .toList();
  }

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  Future<void> montarHome(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
  }

  group('Home — entrada da Conta', () {
    testWidgets('o ícone de conta aparece no cabeçalho', (tester) async {
      await montarHome(tester);

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    });

    testWidgets('tocar no ícone abre a ContaScreen', (tester) async {
      await montarHome(tester);

      expect(find.byType(ContaScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(ContaScreen), findsOneWidget);
    });
  });

  group('Home — o que não pode ter mudado', () {
    testWidgets('o botão de tema continua no lugar e funcionando', (
      tester,
    ) async {
      final temaOriginal = themeNotifier.value;
      addTearDown(() => themeNotifier.value = temaOriginal);

      themeNotifier.value = ThemeMode.light;
      await montarHome(tester);

      expect(find.byIcon(Icons.dark_mode_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.dark_mode_rounded));
      await tester.pumpAndSettle();

      expect(themeNotifier.value, ThemeMode.dark);
      expect(find.byIcon(Icons.light_mode_rounded), findsOneWidget);
    });

    testWidgets('conta e tema convivem no cabeçalho', (tester) async {
      await montarHome(tester);

      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
      expect(
        find.byIcon(Icons.dark_mode_rounded).evaluate().length +
            find.byIcon(Icons.light_mode_rounded).evaluate().length,
        1,
      );
    });

    test('a barra inferior continua com as mesmas quatro abas', () {
      final codigo = linhasDeCodigo().join('\n');

      expect('navItem(icon:'.allMatches(codigo), hasLength(4));
      expect(codigo, isNot(contains('navItem(icon: Icons.person')));
    });

    test('a Home não sabe sair da conta — só abre a tela', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, contains('const ContaScreen()'));
      expect(codigo, isNot(contains('AuthService.logout')));
      expect(codigo, isNot(contains('limparEstadoDaSessao')));
      expect(codigo, isNot(contains('signOut')));
    });

    test('a entrada da conta é um push comum, não troca a pilha', () {
      final codigo = linhasDeCodigo().join('\n');

      final entrada = codigo.indexOf('const ContaScreen()');
      final trecho = codigo.substring(
        (entrada - 260).clamp(0, codigo.length),
        entrada,
      );

      expect(trecho, contains('Navigator.push('));
      expect(trecho, isNot(contains('pushAndRemoveUntil')));
    });
  });
}
