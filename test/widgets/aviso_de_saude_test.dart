import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/widgets/aviso_de_saude.dart';

import '../support/responsivo.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;

  setUp(() => gestacaoOriginal = gestacaoAtual);

  tearDown(() {
    gestacaoAtual = gestacaoOriginal;
    listaContracoes = [];
  });

  group('AvisoDeSaude — conteúdo', () {
    test('diz que é ferramenta de acompanhamento e registro', () {
      expect(
        textoDoAvisoDeSaude,
        contains('ferramenta de acompanhamento e registro'),
      );
    });

    test('diz que não é dispositivo médico', () {
      expect(textoDoAvisoDeSaude, contains('Não é um dispositivo médico'));
    });

    test('nega diagnosticar, tratar, curar e prevenir', () {
      expect(
        textoDoAvisoDeSaude,
        contains('não diagnostica, trata, cura nem previne'),
      );
    });

    test('não substitui a avaliação profissional', () {
      expect(
        textoDoAvisoDeSaude,
        contains('não substituem a avaliação de um profissional de saúde'),
      );
    });

    test('orienta a procurar atendimento em caso de urgência', () {
      expect(textoDoAvisoDeSaude, contains('urgência'));
      expect(textoDoAvisoDeSaude, contains('procure atendimento profissional'));
    });

    test('não inventa telefone de emergência nem protocolo clínico', () {
      expect(textoDoAvisoDeSaude, isNot(matches(RegExp(r'\d'))));
    });

    test('o site público mostra o mesmo texto do app', () {
      final pagina = File('public/index.html').readAsStringSync();

      expect(pagina, contains(textoDoAvisoDeSaude));
    });
  });

  group('AvisoDeSaude — responsividade', () {
    for (final entrada in Telas.todas.entries) {
      testWidgets('cabe em ${entrada.key} com fonte 1.5', (tester) async {
        await montar(
          tester,
          const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: AvisoDeSaude(),
            ),
          ),
          tamanho: entrada.value,
          escalaDeTexto: 1.5,
        );

        expect(find.text(textoDoAvisoDeSaude), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('AvisoDeSaude — na Home', () {
    testWidgets('aparece no fim da tela inicial', (tester) async {
      await montar(tester, const HomeScreen(), tamanho: Telas.g10);

      final aviso = find.byType(AvisoDeSaude);
      await tester.scrollUntilVisible(
        aviso,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(aviso, findsOneWidget);
      expect(find.text(textoDoAvisoDeSaude), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('é alcançável em tela pequena com fonte 1.5', (tester) async {
      await montar(
        tester,
        const HomeScreen(),
        tamanho: Telas.pequena,
        escalaDeTexto: 1.5,
      );

      final aviso = find.byType(AvisoDeSaude);
      await tester.scrollUntilVisible(
        aviso,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(aviso, findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('vem depois do último card e dentro da área rolável', () {
      final codigo = File('lib/main.dart').readAsStringSync();

      final ultimoCard = codigo.indexOf("title: 'Histórico de Chutes'");
      final aviso = codigo.indexOf('const AvisoDeSaude()');
      final barra = codigo.indexOf('bottomNav(context),');

      expect(ultimoCard, greaterThan(-1));
      expect(aviso, greaterThan(ultimoCard));
      expect(barra, greaterThan(aviso));
    });
  });
}
