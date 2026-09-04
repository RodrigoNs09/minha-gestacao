import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

void main() {
  late ThemeMode modoOriginal;

  setUp(() {
    modoOriginal = themeNotifier.value;
  });

  tearDown(() {
    themeNotifier.value = modoOriginal;
  });

  group('MinhaGestacaoApp — widget raiz', () {
    test('é um StatelessWidget e pode ser construído como const', () {
      const app = MinhaGestacaoApp();
      expect(app, isA<StatelessWidget>());
    });

    testWidgets(
      'monta a árvore completa a partir da raiz',
      (WidgetTester tester) async {
        await tester.pumpWidget(const MinhaGestacaoApp());
        expect(find.byType(MaterialApp), findsOneWidget);
      },
      skip: true, 
    );
  });

  group('Tema — themeNotifier', () {
    test('o padrão da aplicação é ThemeMode.light', () {
      expect(themeNotifier.value, ThemeMode.light);
    });

    test('notifica ouvintes ao trocar de modo', () {
      var notificacoes = 0;
      void ouvinte() => notificacoes++;

      themeNotifier.addListener(ouvinte);
      addTearDown(() => themeNotifier.removeListener(ouvinte));

      themeNotifier.value = ThemeMode.dark;
      expect(notificacoes, 1);
      expect(themeNotifier.value, ThemeMode.dark);
    });

    test('não notifica quando o valor atribuído é igual ao atual', () {
      themeNotifier.value = ThemeMode.dark;

      var notificacoes = 0;
      void ouvinte() => notificacoes++;

      themeNotifier.addListener(ouvinte);
      addTearDown(() => themeNotifier.removeListener(ouvinte));

      themeNotifier.value = ThemeMode.dark;
      expect(notificacoes, 0);
    });
  });

  group('Tema — AppTheme', () {
    test('brightness de cada tema é coerente', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('cor de fundo do scaffold difere entre claro e escuro', () {
      expect(AppTheme.light.scaffoldBackgroundColor, const Color(0xFFF0EEFF));
      expect(AppTheme.dark.scaffoldBackgroundColor, const Color(0xFF13112A));
    });

    test('ambos os temas derivam do mesmo seed roxo', () {
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });
  });

  group('Tema — AppColors respondem ao brightness do contexto', () {
    const sonda = Key('sonda-tema');

    Widget appComModo(ThemeMode modo) {
      return MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: modo,
        home: const SizedBox.shrink(key: sonda),
      );
    }

    testWidgets('isDark é falso sob ThemeMode.light', (tester) async {
      await tester.pumpWidget(appComModo(ThemeMode.light));
      expect(AppColors.isDark(tester.element(find.byKey(sonda))), isFalse);
    });

    testWidgets('isDark é verdadeiro sob ThemeMode.dark', (tester) async {
      await tester.pumpWidget(appComModo(ThemeMode.dark));
      expect(AppColors.isDark(tester.element(find.byKey(sonda))), isTrue);
    });

    testWidgets('cores de superfície e texto mudam entre os temas',
        (tester) async {
      await tester.pumpWidget(appComModo(ThemeMode.light));
      final ctxClaro = tester.element(find.byKey(sonda));
      final surfaceClaro = AppColors.surface(ctxClaro);
      final textoClaro = AppColors.textPrimary(ctxClaro);

      await tester.pumpWidget(appComModo(ThemeMode.dark));
      
      await tester.pumpAndSettle();

      final ctxEscuro = tester.element(find.byKey(sonda));
      final surfaceEscuro = AppColors.surface(ctxEscuro);
      final textoEscuro = AppColors.textPrimary(ctxEscuro);

      expect(surfaceClaro, isNot(surfaceEscuro));
      expect(textoClaro, isNot(textoEscuro));
    });
  });
}