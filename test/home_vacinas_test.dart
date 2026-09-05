import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/screens/vacinas_screen.dart';

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

  group('Home — entrada das Vacinas da Gestação', () {
    testWidgets('o card aparece com o título e o subtítulo aprovados',
        (tester) async {
      await montarHome(tester);

      expect(find.text('Vacinas da Gestação'), findsOneWidget);
      expect(find.text('Calendário e seus registros'), findsOneWidget);
      expect(find.byIcon(Icons.vaccines_outlined), findsOneWidget);
    });

    testWidgets('tocar no card abre a VacinasScreen', (tester) async {
      await montarHome(tester);

      expect(find.byType(VacinasScreen), findsNothing);

      await tester.tap(find.byIcon(Icons.vaccines_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(VacinasScreen), findsOneWidget);
    });

    testWidgets('os cards existentes de EXPLORAR continuam presentes',
        (tester) async {
      await montarHome(tester);

      expect(find.text('Histórico de Contrações'), findsOneWidget);
      expect(find.text('Histórico de Chutes'), findsOneWidget);
      expect(find.text('Assistente de Dúvidas'), findsOneWidget);
    });
  });

  group('Home — o card é só navegação', () {
    test('o card das vacinas vem antes dos históricos em EXPLORAR', () {
      final codigo = linhasDeCodigo().join('\n');

      final explorar = codigo.indexOf("Text('EXPLORAR'");
      final vacinas = codigo.indexOf("title: 'Vacinas da Gestação'");
      final contracoes = codigo.indexOf("title: 'Histórico de Contrações'");

      expect(explorar, greaterThan(-1));
      expect(vacinas, greaterThan(explorar));
      expect(vacinas, lessThan(contracoes));
    });

    test('a barra inferior continua com as mesmas quatro abas', () {
      final codigo = linhasDeCodigo().join('\n');

      expect('navItem(icon:'.allMatches(codigo), hasLength(4));

      for (final icone in [
        'Icons.home_rounded',
        'Icons.directions_walk_rounded',
        'Icons.sentiment_satisfied_alt_rounded',
        'Icons.calendar_month_rounded',
      ]) {
        expect(codigo, contains('navItem(icon: $icone'), reason: icone);
      }

      expect(codigo, isNot(contains('navItem(icon: Icons.vaccines_outlined')));
      expect('index == '.allMatches(codigo), hasLength(4));
    });

    test('a Home não chama a engine nem o storage de vacinas', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('VacinasEngine')));
      expect(codigo, isNot(contains('VacinasStorage')));
      expect(codigo, isNot(contains('StatusVacinacao')));
      expect(codigo, isNot(contains('EstadoVacina')));
      expect(codigo, isNot(contains('apresentacaoDe')));
      expect(codigo, isNot(contains('calendarioPni2026')));
      expect(codigo, isNot(contains('RegistroVacinacao')));
    });

    test('das vacinas a Home importa apenas a tela', () {
      final imports = linhasDeCodigo()
          .where((linha) => linha.trimLeft().startsWith('import '))
          .toList();

      final deVacinas =
          imports.where((linha) => linha.contains('vacina')).toList();

      expect(deVacinas, hasLength(1));
      expect(deVacinas.single, contains('screens/vacinas_screen.dart'));
    });

    test('o card usa exatamente os valores aprovados, sem badge', () {
      final codigo = linhasDeCodigo().join('\n');

      final inicio = codigo.indexOf('icon: Icons.vaccines_outlined');
      final fim = codigo.indexOf('icon: Icons.description_outlined');
      expect(inicio, greaterThan(-1));
      expect(fim, greaterThan(inicio));

      final trecho = codigo.substring(inicio, fim);

      expect(trecho, contains("title: 'Vacinas da Gestação'"));
      expect(trecho, contains("subtitle: 'Calendário e seus registros'"));
      expect(trecho, contains('screen: const VacinasScreen()'));
      expect(trecho, contains('iconBg: AppColors.statPink(context)'));
      expect(trecho, contains('iconColor: AppTheme.pink'));
      expect(trecho, isNot(contains('badge')));
    });
  });
}
