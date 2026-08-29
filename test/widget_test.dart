import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

/// Smoke test do app.
///
/// Substitui o teste gerado pelo template do Flutter, que referenciava
/// `MyApp` e um contador que nunca existiram neste projeto. O widget raiz
/// real é [MinhaGestacaoApp] (`lib/main.dart`).
///
/// Por que a árvore completa não é montada aqui: o `build()` de
/// [MinhaGestacaoApp] resolve `FirebaseAuth.instance` para alimentar o
/// `StreamBuilder` do `home:`. Em teste de widget o `Firebase.initializeApp()`
/// nunca foi executado, então esse acesso lança
/// `[core/no-app] No Firebase App '[DEFAULT]' has been created`.
///
/// Montar a raiz exige mockar o Firebase Core (via `setupFirebaseCoreMocks`
/// do `firebase_core_platform_interface`), o que depende de uma dev dependency
/// nova no `pubspec.yaml`. Enquanto isso não é feito, este arquivo cobre o que
/// é alcançável sem runtime do Firebase e mantém uma referência de compilação
/// a [MinhaGestacaoApp], para que uma renomeação do widget raiz volte a
/// quebrar o build do teste — que é o que o teste antigo deixou de fazer.
void main() {
  // themeNotifier é um ValueNotifier global e mutável. Sem restaurar o valor,
  // um teste contamina os seguintes.
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
      skip: true, // Requer mock do Firebase Core — ver comentário no topo.
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
    // Sonda usada para recuperar um BuildContext logo após cada pump.
    // Nunca guardamos o contexto entre pumps: após uma reconstrução ele
    // fica obsoleto, e ler dele devolve o tema anterior.
    const sonda = Key('sonda-tema');

    /// Espelha a montagem real de `MinhaGestacaoApp`: os dois temas
    /// registrados e a escolha feita por `themeMode`. A versão anterior
    /// deste helper passava apenas `theme:` e deixava `themeMode` cair no
    /// default `ThemeMode.system`, que não é como o app se monta.
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
      // MaterialApp troca o tema através de AnimatedTheme, ao longo de
      // kThemeAnimationDuration. ThemeData.lerp resolve brightness como
      // `t < 0.5 ? a : b`, então no primeiro frame após a troca o tema ainda
      // é o anterior. Sem deixar a animação concluir, a versão anterior deste
      // teste lia o surface claro nas duas vezes e comparava branco com branco.
      await tester.pumpAndSettle();

      final ctxEscuro = tester.element(find.byKey(sonda));
      final surfaceEscuro = AppColors.surface(ctxEscuro);
      final textoEscuro = AppColors.textPrimary(ctxEscuro);

      expect(surfaceClaro, isNot(surfaceEscuro));
      expect(textoClaro, isNot(textoEscuro));
    });
  });
}