import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/chutes_data.dart';
import 'package:suacontracao_ai/data/consultas_data.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/data/sintomas_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/screens/consentimento_screen.dart';
import 'package:suacontracao_ai/services/auth_service.dart';
import 'package:suacontracao_ai/services/links_publicos.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

import '../support/responsivo.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mensageiro =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late GestacaoInfo gestacaoOriginal;

  setUp(() => gestacaoOriginal = gestacaoAtual);

  tearDown(() {
    gestacaoAtual = gestacaoOriginal;
    listaContracoes = [];
    listaChutes = [];
    listaSintomas = [];
    listaConsultas = [];
    mensageiro.setMockMethodCallHandler(LinksPublicos.canal, null);
  });

  String fonte() => File('lib/screens/consentimento_screen.dart')
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

  String politica() => File('public/privacidade.html')
      .readAsStringSync()
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  Widget tela({VoidCallback? aoAceitar, Future<bool> Function()? registrar}) =>
      ConsentimentoScreen(
        aoAceitar: aoAceitar ?? () {},
        registrarAceite: registrar ?? () async => true,
      );

  Future<void> abrir(WidgetTester tester, Widget t) async {
    await tester.pumpWidget(MaterialApp(home: t));
    await tester.pumpAndSettle();
  }

  Future<void> alcancar(WidgetTester tester, Finder alvo) async {
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
  }

  Future<void> tocar(WidgetTester tester, Finder alvo) async {
    await alcancar(tester, alvo);
    await tester.tap(alvo);
    await tester.pumpAndSettle();
  }

  Finder caixa() => find.byType(CheckboxListTile);
  Finder continuar() => find.widgetWithText(ElevatedButton, 'Continuar');
  bool continuarAtivo(WidgetTester tester) =>
      tester.widget<ElevatedButton>(continuar()).onPressed != null;

  group('ConsentimentoScreen — conteúdo', () {
    testWidgets('mostra os quatro blocos, o link e o texto do aceite', (
      tester,
    ) async {
      await abrir(tester, tela());

      expect(find.text('Seus dados de saúde'), findsOneWidget);
      for (final texto in [
        consentimentoDados,
        consentimentoFinalidade,
        consentimentoArmazenamento,
        consentimentoRevogacao,
      ]) {
        await alcancar(tester, find.text(texto));
        expect(find.text(texto), findsOneWidget);
      }
      expect(find.text('Como retirar a autorização'), findsOneWidget);
      expect(find.text('Como excluir'), findsNothing);
      await alcancar(tester, find.text('Ler a Política de Privacidade'));
      expect(find.text('Ler a Política de Privacidade'), findsOneWidget);
      await alcancar(tester, find.text(textoDoAceite));
      expect(find.text(textoDoAceite), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('o texto do aceite é exatamente o decidido', () {
      expect(
        textoDoAceite,
        'Li a Política de Privacidade e autorizo o tratamento dos meus dados '
        'de saúde para essas finalidades.',
      );
    });
  });

  group('ConsentimentoScreen — respaldo na Política de Privacidade', () {
    test('os dados citados são os que a política declara como de saúde', () {
      expect(
        politica(),
        contains(
          'As informações sobre gestação, contrações, movimentos do bebê, '
          'sintomas, humor, peso, consultas e vacinação dizem respeito à sua '
          'saúde.',
        ),
      );
      for (final dado in [
        'data da última menstruação',
        'contrações',
        'movimentos do bebê',
        'sintomas',
        'humor',
        'peso',
        'consultas',
        'vacinas',
      ]) {
        expect(consentimentoDados, contains(dado), reason: dado);
      }
      expect(politica(), contains('Data da última menstruação (DUM)'));
    });

    test('a finalidade é a da seção 5', () {
      expect(
        politica(),
        contains(
          'Guardar os seus registros e exibi-los no aplicativo, inclusive '
          'quando você entra em outro aparelho.',
        ),
      );
      expect(consentimentoFinalidade, contains('outro aparelho'));
    });

    test('onde ficam segue as seções 6 e 7', () {
      final p = politica();

      expect(p, contains('serviços do Firebase, plataforma do Google'));
      expect(
        p,
        contains('Os registros ficam no Cloud Firestore, na região de'),
      );
      expect(p, contains('São Paulo (Brasil)'));
      expect(
        p,
        contains('Nenhuma outra conta do aplicativo tem acesso a eles.'),
      );
      expect(
        consentimentoArmazenamento,
        contains('Nenhuma outra conta do aplicativo tem acesso a eles.'),
      );
      expect(consentimentoArmazenamento, contains('Cloud Firestore'));
      expect(consentimentoArmazenamento, contains('São Paulo'));
    });

    test('retirar a autorização segue as seções 10 e 9', () {
      final p = politica();

      expect(
        p,
        contains(
          'A autorização para o tratamento dos dados de saúde pode ser '
          'revogada a qualquer momento. Como o aplicativo não funciona sem '
          'esses dados, a revogação é feita pela exclusão da conta, pelo '
          'caminho descrito na seção 9.',
        ),
      );
      expect(p, contains('para abrir a tela Conta'));
      expect(p, contains('Excluir minha conta'));
      expect(consentimentoRevogacao, contains('retirar a autorização'));
      expect(consentimentoRevogacao, contains('quando quiser'));
      expect(consentimentoRevogacao, contains('excluindo a conta'));
      expect(consentimentoRevogacao, contains('tela Conta'));
    });

    test('a base legal declarada é o consentimento dado nesta tela', () {
      final p = politica();

      expect(
        p,
        contains(
          'o seu consentimento específico e destacado (LGPD, art. 11, I)',
        ),
      );
      expect(p, contains('dado na tela Seus dados de saúde do aplicativo'));
      expect(fonte(), contains("'Seus dados de saúde'"));
    });

    test('a tela não promete que só a usuária acessa os dados', () {
      for (final texto in [
        consentimentoDados,
        consentimentoFinalidade,
        consentimentoArmazenamento,
        consentimentoRevogacao,
      ]) {
        expect(texto, isNot(contains('só você')));
        expect(texto, isNot(contains('apenas você')));
      }
    });
  });

  group('ConsentimentoScreen — caixa e botão', () {
    testWidgets('a caixa começa desmarcada', (tester) async {
      await abrir(tester, tela());
      await alcancar(tester, caixa());

      expect(tester.widget<CheckboxListTile>(caixa()).value, isFalse);
    });

    testWidgets('Continuar fica desativado até marcar', (tester) async {
      await abrir(tester, tela());
      await alcancar(tester, continuar());

      expect(continuarAtivo(tester), isFalse);

      await tocar(tester, caixa());
      expect(tester.widget<CheckboxListTile>(caixa()).value, isTrue);
      expect(continuarAtivo(tester), isTrue);

      await tocar(tester, caixa());
      expect(tester.widget<CheckboxListTile>(caixa()).value, isFalse);
      expect(continuarAtivo(tester), isFalse);
    });

    testWidgets('tocar em Continuar desativado não grava nada', (tester) async {
      var chamadas = 0;
      await abrir(
        tester,
        tela(
          registrar: () async {
            chamadas++;
            return true;
          },
        ),
      );

      await tocar(tester, continuar());

      expect(chamadas, 0);
    });
  });

  group('ConsentimentoScreen — gravação', () {
    testWidgets('marcar e continuar grava uma vez e avisa o aceite', (
      tester,
    ) async {
      var gravacoes = 0;
      var aceites = 0;
      await abrir(
        tester,
        tela(
          registrar: () async {
            gravacoes++;
            return true;
          },
          aoAceitar: () => aceites++,
        ),
      );

      await tocar(tester, caixa());
      await tocar(tester, continuar());

      expect(gravacoes, 1);
      expect(aceites, 1);
    });

    testWidgets('falha ao gravar mostra erro amigável e não aceita', (
      tester,
    ) async {
      var aceites = 0;
      await abrir(
        tester,
        tela(
          registrar: () async => throw StateError('sem servidor'),
          aoAceitar: () => aceites++,
        ),
      );

      await tocar(tester, caixa());
      await tocar(tester, continuar());

      expect(aceites, 0);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
      expect(continuarAtivo(tester), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('depois da falha dá para tentar de novo', (tester) async {
      var tentativas = 0;
      var aceites = 0;
      await abrir(
        tester,
        tela(
          registrar: () async {
            tentativas++;
            if (tentativas == 1) throw StateError('sem servidor');
            return true;
          },
          aoAceitar: () => aceites++,
        ),
      );

      await tocar(tester, caixa());
      await tocar(tester, continuar());
      await tocar(tester, continuar());

      expect(tentativas, 2);
      expect(aceites, 1);
    });

    testWidgets('sem sessão avisa que a sessão expirou', (tester) async {
      await abrir(tester, tela(registrar: () async => false));

      await tocar(tester, caixa());
      await tocar(tester, continuar());

      expect(find.text(AuthService.sessaoExpirada), findsOneWidget);
    });

    test('por padrão grava pelo ConsentimentoStorage', () {
      expect(
        fonte(),
        contains('this.registrarAceite = ConsentimentoStorage.registrarAceite'),
      );
    });

    test('o aceite só é avisado depois de gravar com sucesso', () {
      final normalizado = corpoDoMetodo(
        'Future<void> _continuar(',
      ).replaceAll(RegExp(r'\s+'), ' ');

      final gravacao = normalizado.indexOf('await widget.registrarAceite()');
      final falha = normalizado.indexOf('if (!gravou)');
      final aviso = normalizado.indexOf('widget.aoAceitar()');

      expect(gravacao, greaterThan(-1));
      expect(falha, greaterThan(gravacao));
      expect(aviso, greaterThan(falha));
      expect(normalizado.substring(falha, aviso), contains('return;'));
    });
  });

  group('ConsentimentoScreen — Política de Privacidade', () {
    testWidgets('o link abre a política pública', (tester) async {
      final pedidas = <Object?>[];
      mensageiro.setMockMethodCallHandler(LinksPublicos.canal, (chamada) async {
        pedidas.add(chamada.arguments);
        return true;
      });

      await abrir(tester, tela());
      await tocar(tester, find.text('Ler a Política de Privacidade'));

      expect(pedidas, [
        {'url': LinksPublicos.politicaDePrivacidade},
      ]);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sem navegador mostra o endereço para copiar', (tester) async {
      mensageiro.setMockMethodCallHandler(
        LinksPublicos.canal,
        (_) async => false,
      );

      await abrir(tester, tela());
      await tocar(tester, find.text('Ler a Política de Privacidade'));

      expect(
        find.byWidgetPredicate(
          (w) =>
              w is SelectableText &&
              w.data == LinksPublicos.politicaDePrivacidade,
        ),
        findsOneWidget,
      );
    });
  });

  group('ConsentimentoScreen — Não concordo', () {
    Future<void> abrirRecusa(WidgetTester tester) async {
      await abrir(tester, tela());
      await tocar(tester, find.text('Não concordo'));
    }

    testWidgets('explica que o app não funciona e oferece sair ou excluir', (
      tester,
    ) async {
      await abrirRecusa(tester);

      expect(find.text('Sem autorização, o app não funciona'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Voltar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Sair da conta'), findsOneWidget);
      expect(
        find.widgetWithText(TextButton, 'Excluir minha conta'),
        findsOneWidget,
      );
    });

    testWidgets('Voltar fecha o diálogo sem mudar nada', (tester) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await abrirRecusa(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Voltar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Seus dados de saúde'), findsOneWidget);
      expect(gestacaoAtual.id, 'gestacao-1');
    });

    testWidgets('Excluir leva ao fluxo de exclusão existente, na tela Conta', (
      tester,
    ) async {
      await abrirRecusa(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Excluir minha conta'));
      await tester.pumpAndSettle();

      expect(find.text('Conta'), findsOneWidget);
      await alcancar(
        tester,
        find.widgetWithText(OutlinedButton, 'Excluir minha conta'),
      );
      expect(
        find.widgetWithText(OutlinedButton, 'Excluir minha conta'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Sair sem Firebase limpa a sessão, avisa e não navega', (
      tester,
    ) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      await abrirRecusa(tester);
      await tester.tap(find.widgetWithText(TextButton, 'Sair da conta'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Seus dados de saúde'), findsOneWidget);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
      expect(gestacaoAtual.id, isNull);
      expect(gestacaoAtual.configurada, isFalse);
    });

    test('sair limpa a sessão antes do logout e só navega depois dele', () {
      final normalizado = corpoDoMetodo(
        'Future<void> _sairDaConta(',
      ).replaceAll(RegExp(r'\s+'), ' ');

      final limpeza = normalizado.indexOf('limparEstadoDaSessao()');
      final logout = normalizado.indexOf('await AuthService.logout()');
      final falha = normalizado.indexOf('} catch (erro) {');
      final navegacao = normalizado.indexOf('pushAndRemoveUntil');

      expect(limpeza, greaterThan(-1));
      expect(logout, greaterThan(limpeza));
      expect(falha, greaterThan(logout));
      expect(navegacao, greaterThan(falha));
      expect(normalizado.substring(falha, navegacao), contains('return;'));
      expect(normalizado, contains('const LoginScreen()'));
      expect(normalizado, contains('(route) => false'));
    });

    test('excluir reaproveita a tela Conta em vez de duplicar a exclusão', () {
      final codigo = fonte();

      expect(codigo, contains('const ContaScreen()'));
      expect(codigo, isNot(contains('ExclusaoDeConta')));
      expect(codigo, isNot(contains('reauthenticate')));
    });
  });

  group('ConsentimentoScreen — responsividade', () {
    for (final entrada in Telas.todas.entries) {
      for (final escala in [1.0, 1.5]) {
        testWidgets('cabe em ${entrada.key} com fonte $escala', (tester) async {
          await montar(
            tester,
            tela(),
            tamanho: entrada.value,
            escalaDeTexto: escala,
          );

          expect(tester.takeException(), isNull);

          await alcancar(tester, find.text('Não concordo'));
          expect(find.text('Não concordo'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('o diálogo de recusa cabe em 320x568 com fonte 1.5', (
      tester,
    ) async {
      await montar(tester, tela(), tamanho: Telas.pequena, escalaDeTexto: 1.5);
      await tocar(tester, find.text('Não concordo'));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    for (final modo in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('monta no tema ${modo.name} com a caixa marcada', (
        tester,
      ) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: modo,
            home: tela(),
          ),
        );
        await tester.pumpAndSettle();
        await tocar(tester, caixa());

        expect(continuarAtivo(tester), isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ConsentimentoScreen — estrutura', () {
    test('usa a MolduraResponsiva, sem supressor de overflow', () {
      final codigo = fonte();

      expect(codigo, contains('MolduraResponsiva('));
      expect(
        codigo,
        isNot(
          contains(
            'ignorarOverflow'
            'DeLayout',
          ),
        ),
      );
      expect(
        codigo,
        isNot(
          contains(
            'FlutterError.'
            'onError',
          ),
        ),
      );
    });

    test('abre a política pelo LinksPublicos', () {
      expect(
        fonte(),
        contains(
          'LinksPublicos.abrir(\n      LinksPublicos.politicaDePrivacidade',
        ),
      );
    });

    test('não grava no Firestore nem mexe na gestação diretamente', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('FirebaseFirestore')));
      expect(codigo, isNot(contains('GestacaoStorage')));
    });
  });
}
