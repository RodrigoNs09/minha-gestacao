import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/main.dart';
import 'package:suacontracao_ai/screens/consentimento_screen.dart';
import 'package:suacontracao_ai/screens/onboarding_screen.dart';
import 'package:suacontracao_ai/screens/porta_de_entrada.dart';
import 'package:suacontracao_ai/services/firestore_error.dart';
import 'package:suacontracao_ai/services/proximo_destino.dart';

import '../support/responsivo.dart';

class _Calculo {
  _Calculo(this._respostas);

  final List<Object> _respostas;
  int chamadas = 0;

  Future<Destino> call() async {
    final resposta = _respostas[chamadas.clamp(0, _respostas.length - 1)];
    chamadas++;
    if (resposta is Destino) return resposta;
    throw resposta;
  }
}

void main() {
  final semConexao = FirebaseException(
    plugin: 'cloud_firestore',
    code: 'unavailable',
  );

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  List<String> arquivosDeLibQueCitam(String trecho) {
    return Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((arquivo) => arquivo.path.endsWith('.dart'))
        .where((arquivo) => fonteDe(arquivo.path).contains(trecho))
        .map((arquivo) => arquivo.path.replaceAll(Platform.pathSeparator, '/'))
        .toList()
      ..sort();
  }

  Future<_Calculo> abrir(
    WidgetTester tester,
    List<Object> respostas, {
    Size tamanho = Telas.g10,
    double escalaDeTexto = 1.0,
  }) async {
    final calculo = _Calculo(respostas);
    await montar(
      tester,
      PortaDeEntrada(calcular: calculo.call),
      tamanho: tamanho,
      escalaDeTexto: escalaDeTexto,
    );
    return calculo;
  }

  Future<void> aceitar(WidgetTester tester) async {
    tester
        .widget<ConsentimentoScreen>(find.byType(ConsentimentoScreen))
        .aoAceitar();
    await tester.pumpAndSettle();
  }

  group('PortaDeEntrada — destino', () {
    testWidgets('mostra o carregamento enquanto decide', (tester) async {
      final pendente = Completer<Destino>();
      await montar(
        tester,
        PortaDeEntrada(calcular: () => pendente.future),
        tamanho: Telas.g10,
        assentar: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(ConsentimentoScreen), findsNothing);

      pendente.complete(Destino.onboarding);
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('sem aceite vigente, mostra o consentimento', (tester) async {
      final calculo = await abrir(tester, [Destino.consentimento]);

      expect(find.byType(ConsentimentoScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(calculo.chamadas, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com aceite vigente e DUM, vai direto para a Home', (
      tester,
    ) async {
      await abrir(tester, [Destino.home]);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ConsentimentoScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com aceite vigente e sem DUM, vai para o Onboarding', (
      tester,
    ) async {
      await abrir(tester, [Destino.onboarding]);

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(ConsentimentoScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('PortaDeEntrada — depois do aceite', () {
    testWidgets('continua para a Home quando já há DUM', (tester) async {
      final calculo = await abrir(tester, [
        Destino.consentimento,
        Destino.home,
      ]);

      await aceitar(tester);

      expect(calculo.chamadas, 2);
      expect(find.byType(ConsentimentoScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('continua para o Onboarding quando ainda não há DUM', (
      tester,
    ) async {
      final calculo = await abrir(tester, [
        Destino.consentimento,
        Destino.onboarding,
      ]);

      await aceitar(tester);

      expect(calculo.chamadas, 2);
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    test('o aceite refaz a mesma decisão, não um atalho para a Home', () {
      final codigo = fonteDe('lib/screens/porta_de_entrada.dart');

      expect(codigo, contains('ConsentimentoScreen(aoAceitar: _recalcular)'));
      expect(codigo, contains('final destino = await widget.calcular();'));
      expect(codigo, contains('this.calcular = ProximoDestino.calcular'));

      final recalcular = codigo.substring(
        codigo.indexOf('void _recalcular()'),
        codigo.indexOf('Widget build('),
      );
      expect(recalcular, contains('_calcular();'));
      expect(recalcular, isNot(contains('HomeScreen')));
    });
  });

  group('PortaDeEntrada — sem conexão', () {
    testWidgets('sem conexão e sem cache: erro com Tentar novamente', (
      tester,
    ) async {
      await abrir(tester, [semConexao]);

      expect(find.text('Não foi possível carregar seus dados'), findsOneWidget);
      expect(find.text(FirestoreErro.semConexao), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a falha de leitura não vira pedido de consentimento', (
      tester,
    ) async {
      await abrir(tester, [semConexao]);

      expect(find.byType(ConsentimentoScreen), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(find.byType(OnboardingScreen), findsNothing);
    });

    testWidgets('Tentar novamente refaz a decisão e segue', (tester) async {
      final calculo = await abrir(tester, [semConexao, Destino.home]);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(calculo.chamadas, 2);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Tentar novamente'), findsNothing);
    });

    testWidgets('continua oferecendo nova tentativa enquanto falhar', (
      tester,
    ) async {
      final calculo = await abrir(tester, [semConexao]);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(calculo.chamadas, 2);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    for (final entrada in Telas.todas.entries) {
      testWidgets('o erro cabe em ${entrada.key} com fonte 1.5', (
        tester,
      ) async {
        await abrir(
          tester,
          [semConexao],
          tamanho: entrada.value,
          escalaDeTexto: 1.5,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Tentar novamente'), findsOneWidget);
      });
    }
  });

  group('Um único caminho de entrada', () {
    test('main, login e cadastro abrem a mesma porta de entrada', () {
      expect(arquivosDeLibQueCitam('const PortaDeEntrada()'), [
        'lib/main.dart',
        'lib/screens/login_screen.dart',
        'lib/screens/register_screen.dart',
      ]);
    });

    test('só a porta de entrada chama a função de próximo destino', () {
      expect(arquivosDeLibQueCitam('ProximoDestino.calcular'), [
        'lib/screens/porta_de_entrada.dart',
      ]);
    });

    test('a DUM só é restaurada dentro da decisão', () {
      expect(arquivosDeLibQueCitam('restaurarDUM'), [
        'lib/services/gestacao_storage.dart',
        'lib/services/proximo_destino.dart',
      ]);
    });

    test('só a porta de entrada monta o consentimento e o Onboarding', () {
      expect(arquivosDeLibQueCitam('ConsentimentoScreen('), [
        'lib/screens/consentimento_screen.dart',
        'lib/screens/porta_de_entrada.dart',
      ]);
      expect(arquivosDeLibQueCitam('const OnboardingScreen()'), [
        'lib/screens/porta_de_entrada.dart',
      ]);
    });

    test('fora do Onboarding, só a porta de entrada abre a Home', () {
      expect(arquivosDeLibQueCitam('const HomeScreen()'), [
        'lib/screens/onboarding_screen.dart',
        'lib/screens/porta_de_entrada.dart',
      ]);
    });

    test('o gate do main entrega a sessão aberta à porta de entrada', () {
      final codigo = fonteDe('lib/main.dart');

      final login = codigo.indexOf('return const LoginScreen();');
      final porta = codigo.indexOf('return const PortaDeEntrada();');

      expect(login, greaterThan(-1));
      expect(porta, greaterThan(login));
      expect(codigo, isNot(contains('_RestaurarDumGate')));
      expect(codigo, isNot(contains('GestacaoStorage')));
    });
  });
}
