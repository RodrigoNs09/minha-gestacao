import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fonteDe(String caminho) {
    return File(caminho)
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .join('\n');
  }

  group('Localização — configuração global', () {
    test('o pubspec declara flutter_localizations pelo SDK', () {
      // Por linhas: o arquivo é CRLF e uma busca por \n não casaria.
      final linhas = File('pubspec.yaml').readAsLinesSync();
      final indice = linhas.indexWhere(
        (l) => l.trim() == 'flutter_localizations:',
      );

      expect(indice, greaterThan(-1));
      expect(linhas[indice + 1].trim(), 'sdk: flutter');
      // Nenhum pacote externo de localização foi adicionado.
      expect(linhas.any((l) => l.trim().startsWith('intl:')), isFalse);
    });

    test('o MaterialApp registra os três delegates globais', () {
      final codigo = fonteDe('lib/main.dart');

      expect(
        codigo,
        contains("import 'package:flutter_localizations/flutter_localizations.dart';"),
      );
      expect(codigo, contains('GlobalMaterialLocalizations.delegate'));
      expect(codigo, contains('GlobalWidgetsLocalizations.delegate'));
      expect(codigo, contains('GlobalCupertinoLocalizations.delegate'));
    });

    test('o app declara pt-BR como idioma suportado', () {
      final codigo = fonteDe('lib/main.dart');

      expect(codigo, contains("Locale('pt', 'BR')"));
      expect(codigo, contains('supportedLocales'));
      // Sem locale fixo no MaterialApp: a lista de suportados já resolve.
      expect(codigo, isNot(contains("locale: const Locale('pt', 'BR')")));
    });
  });

  group('Localização — o seletor de data da vacinação', () {
    test('pede pt-BR e continua barrando data futura', () {
      final codigo = fonteDe('lib/screens/vacinas_screen.dart');

      expect(codigo, contains("locale: const Locale('pt', 'BR')"));
      expect(codigo, contains('lastDate: hoje'));
      expect(codigo, contains('final hoje = DateTime.now();'));
      expect(codigo, isNot(contains('lastDate: DateTime(2')));
    });
  });

  group('Localização — o resultado é realmente português', () {
    // Prova executável: com os delegates registrados, as datas que o date
    // picker exibe saem em pt-BR.
    late MaterialLocalizations textos;

    Future<void> montarComOsDelegates(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          home: Builder(
            builder: (context) {
              textos = MaterialLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('o cabeçalho de mês e ano vem em português', (tester) async {
      await montarComOsDelegates(tester);

      final rotulo = textos.formatMonthYear(DateTime(2026, 9, 5));

      expect(rotulo.toLowerCase(), contains('setembro'));
      expect(rotulo.toLowerCase(), isNot(contains('september')));
    });

    testWidgets('a data compacta usa dd/MM/yyyy', (tester) async {
      await montarComOsDelegates(tester);

      // 05/09/2026 no padrão brasileiro; 09/05/2026 seria o americano.
      expect(textos.formatCompactDate(DateTime(2026, 9, 5)), '05/09/2026');
    });

    testWidgets('a data por extenso traz o dia da semana em português',
        (tester) async {
      await montarComOsDelegates(tester);

      final medium = textos.formatMediumDate(DateTime(2026, 9, 5)).toLowerCase();

      expect(medium, contains('set'));
      expect(medium, isNot(contains('sat')));
      expect(medium, isNot(contains('sep')));
    });

    testWidgets('o texto de entrada manual indica o formato brasileiro',
        (tester) async {
      await montarComOsDelegates(tester);

      // É a dica que aparece no campo de digitação do date picker.
      expect(textos.dateHelpText, 'dd/mm/aaaa');
      expect(textos.dateHelpText, isNot('mm/dd/yyyy'));
      expect(textos.dateInputLabel, isNot('Enter Date'));
    });

    testWidgets('sem os delegates o padrão seria inglês', (tester) async {
      // Contraprova: é isto que a tela mostrava antes desta correção.
      late MaterialLocalizations padrao;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              padrao = MaterialLocalizations.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(padrao.formatMonthYear(DateTime(2026, 9, 5)), contains('September'));
      expect(padrao.formatCompactDate(DateTime(2026, 9, 5)), '09/05/2026');
    });
  });
}
