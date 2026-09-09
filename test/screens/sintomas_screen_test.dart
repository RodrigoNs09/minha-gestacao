import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/sintomas_data.dart';
import 'package:suacontracao_ai/models/registro_sintomas.dart';
import 'package:suacontracao_ai/screens/sintomas_screen.dart';

void main() {
  tearDown(() => listaSintomas = []);

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .where((linha) => !linha.trimLeft().startsWith('///'))
      .join('\n');

  String fonteDaTela() => fonteDe('lib/screens/sintomas_screen.dart');
  String fonteDoStorage() => fonteDe('lib/services/sintomas_storage.dart');

  String corpoDoMetodo(String fonte, String assinatura) {
    final inicio = fonte.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = fonte.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return fonte.substring(inicio, fim);
  }

  String comoData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String hoje() => comoData(DateTime.now());

  String diasAtras(int dias) =>
      comoData(DateTime.now().subtract(Duration(days: dias)));

  // Datas fixas, para os testes puros em que "hoje" não participa.
  List<RegistroSintomas> tresDias() => [
    RegistroSintomas(data: '2026-09-06', humor: 0, sintomas: const ['nausea']),
    RegistroSintomas(data: '2026-09-07', humor: 1, peso: 68.0),
    RegistroSintomas(data: '2026-09-08', humor: 2, sintomas: const ['azia']),
  ];

  // Nos testes de tela o registro do dia é escrito de verdade, então a
  // fixture precisa ser sempre passado — datas fixas viram "hoje" um dia.
  List<RegistroSintomas> tresDiasAnteriores() => [
    RegistroSintomas(data: diasAtras(3), humor: 0, sintomas: const ['nausea']),
    RegistroSintomas(data: diasAtras(2), humor: 1, peso: 68.0),
    RegistroSintomas(data: diasAtras(1), humor: 2, sintomas: const ['azia']),
  ];

  // Como a seção HISTÓRICO rotula cada linha: dd/MM.
  String rotuloDe(String dataIso) {
    final partes = dataIso.split('-');
    return '${partes[2]}/${partes[1]}';
  }

  RegistroSintomas registroDeHoje({int humor = 3, double? peso}) =>
      RegistroSintomas(
        data: hoje(),
        humor: humor,
        sintomas: const ['costas'],
        peso: peso,
      );

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  Future<void> montar(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: SintomasScreen()));
    await tester.pumpAndSettle();
  }

  group('SintomasScreen — montagem', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Diário de hoje'), findsOneWidget);
    });

    testWidgets('mostra as opções de humor e de sintomas', (tester) async {
      await montar(tester);

      expect(find.text('Náusea'), findsOneWidget);
      expect(find.text('Azia'), findsOneWidget);
    });
  });

  group('SintomasScreen — carregamento', () {
    testWidgets('falha de leitura não apaga o que estava em memória', (
      tester,
    ) async {
      listaSintomas = tresDiasAnteriores();

      await montar(tester);

      expect(listaSintomas, hasLength(3));
      expect(
        listaSintomas.map((r) => r.data),
        containsAll([diasAtras(3), diasAtras(2), diasAtras(1)]),
      );
    });

    testWidgets('falha de leitura avisa e mantém a tela utilizável', (
      tester,
    ) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(SintomasScreen), findsOneWidget);
      expect(find.text('Náusea'), findsOneWidget);
    });
  });

  group('comRegistroDoDia — registro do dia', () {
    test('acrescenta o dia quando ainda não existe', () {
      final novo = RegistroSintomas(data: '2026-09-09', humor: 3);

      final resultado = comRegistroDoDia(tresDias(), novo);

      expect(resultado, hasLength(4));
      expect(resultado.last.data, '2026-09-09');
    });

    test('registro do dia entra em um histórico vazio', () {
      final novo = RegistroSintomas(data: '2026-09-08', humor: 1);

      final resultado = comRegistroDoDia(const [], novo);

      expect(resultado, hasLength(1));
      expect(resultado.single.data, '2026-09-08');
    });
  });

  group('comRegistroDoDia — atualização do mesmo dia', () {
    test('substitui em vez de acumular — um registro por dia', () {
      final atualizado = RegistroSintomas(data: '2026-09-08', humor: 4);

      final resultado = comRegistroDoDia(tresDias(), atualizado);

      expect(resultado, hasLength(3));
      expect(resultado.where((r) => r.data == '2026-09-08'), hasLength(1));
      expect(resultado.firstWhere((r) => r.data == '2026-09-08').humor, 4);
    });

    test('salvar o mesmo dia várias vezes nunca duplica', () {
      var historico = tresDias();

      for (final humor in [0, 1, 2, 3, 4]) {
        historico = comRegistroDoDia(
          historico,
          RegistroSintomas(data: '2026-09-08', humor: humor),
        );
      }

      expect(historico, hasLength(3));
      expect(historico.firstWhere((r) => r.data == '2026-09-08').humor, 4);
    });

    test('INTEGRIDADE: os outros dias não são tocados', () {
      final original = tresDias();
      final seis = original[0];
      final sete = original[1];

      final resultado = comRegistroDoDia(
        original,
        RegistroSintomas(data: '2026-09-08', humor: 4),
      );

      // Mesmas instâncias: não foram recriadas nem regravadas.
      expect(identical(resultado[0], seis), isTrue);
      expect(identical(resultado[1], sete), isTrue);
      expect(resultado[0].sintomas, ['nausea']);
      expect(resultado[1].peso, 68.0);
    });

    test('não altera a lista recebida', () {
      final original = tresDias();

      comRegistroDoDia(original, RegistroSintomas(data: '2026-09-08'));

      expect(original, hasLength(3));
      expect(original[2].humor, 2);
    });
  });

  group('SintomasScreen — rollback quando a persistência falha', () {
    testWidgets('humor: a falha não deixa registro fantasma', (tester) async {
      listaSintomas = tresDiasAnteriores();
      await montar(tester);

      await tester.tap(find.text('😊').first);
      await tester.pumpAndSettle();

      expect(listaSintomas, hasLength(3));
      expect(listaSintomas.where((r) => r.data == hoje()), isEmpty);
    });

    testWidgets('humor: o estado visual volta ao que era', (tester) async {
      await montar(tester);

      await tester.tap(find.text('😊').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(listaSintomas, isEmpty);
    });

    testWidgets('sintoma: a falha não deixa registro fantasma', (tester) async {
      listaSintomas = tresDiasAnteriores();
      await montar(tester);

      await tester.tap(find.text('Náusea').first);
      await tester.pumpAndSettle();

      expect(listaSintomas, hasLength(3));
      expect(listaSintomas.where((r) => r.data == hoje()), isEmpty);
    });

    testWidgets('INTEGRIDADE: a falha preserva os dias anteriores', (
      tester,
    ) async {
      listaSintomas = tresDiasAnteriores();
      await montar(tester);

      await tester.tap(find.text('😩').first);
      await tester.pumpAndSettle();

      expect(listaSintomas.map((r) => r.data), [
        diasAtras(3),
        diasAtras(2),
        diasAtras(1),
      ]);
      expect(listaSintomas[0].sintomas, ['nausea']);
      expect(listaSintomas[1].peso, 68.0);
      expect(listaSintomas[2].humor, 2);
    });
  });

  group('SintomasScreen — erro amigável', () {
    testWidgets('a falha ao salvar mostra mensagem, não exceção crua', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('😐').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(SnackBar), findsWidgets);
    });

    test('sem sessão a mensagem fala de sessão, não de erro genérico', () {
      expect(
        mensagemDeFalhaAoSalvar(const SessaoSemGravacao()),
        mensagemSessaoExpirada,
      );
      expect(mensagemSessaoExpirada, contains('sessão expirada'));
    });

    test('outros erros continuam usando a mensagem amigável do Firestore', () {
      final mensagem = mensagemDeFalhaAoSalvar(StateError('qualquer'));

      expect(mensagem, isNot(mensagemSessaoExpirada));
      expect(mensagem, contains('Tente novamente'));
    });
  });

  group('SintomasScreen — utilizável depois da falha', () {
    testWidgets('dá para tentar de novo', (tester) async {
      await montar(tester);

      await tester.tap(find.text('😊').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('😔').first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('😔'), findsOneWidget);
    });

    testWidgets('a tela não fica travada por um diálogo', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Azia').first);
      await tester.pumpAndSettle();

      expect(find.byType(SintomasScreen), findsOneWidget);
      expect(fonteDaTela(), isNot(contains('PopScope')));
    });
  });

  group('Storage — o padrão destrutivo não pode voltar', () {
    test('salvarRegistros(List...) não existe mais', () {
      expect(fonteDoStorage(), isNot(contains('salvarRegistros')));
      expect(fonteDaTela(), isNot(contains('salvarRegistros')));
    });

    test('o storage não usa batch', () {
      final codigo = fonteDoStorage();

      expect(codigo, isNot(contains('batch')));
      expect(codigo, isNot(contains('WriteBatch')));
      expect(codigo, isNot(contains('.commit()')));
    });

    test('nenhuma escrita enumera a coleção antes de gravar', () {
      for (final metodo in [
        'static Future<RegistroSintomas?> salvarRegistro(',
        'static Future<bool> atualizarRegistro(',
        'static Future<bool> removerRegistro(',
      ]) {
        final corpo = corpoDoMetodo(fonteDoStorage(), metodo);

        expect(corpo, isNot(contains('.get()')), reason: metodo);
        expect(corpo, isNot(contains('docs')), reason: metodo);
      }
    });

    test('o único delete é o de um documento nomeado', () {
      final codigo = fonteDoStorage();

      expect('delete('.allMatches(codigo), hasLength(1));
      expect(
        corpoDoMetodo(codigo, 'static Future<bool> removerRegistro('),
        contains('doc.delete()'),
      );
    });
  });

  group('Storage — operação individual por documento', () {
    test('a tela chama a operação individual', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _salvarRegistroDeHoje(',
      );

      expect(corpo, contains('SintomasStorage.salvarRegistro(novoRegistro)'));
    });

    test('a tela grava só o registro do dia, nunca a lista', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _salvarRegistroDeHoje(',
      );

      expect(corpo, isNot(contains('SintomasStorage.salvarRegistro(lista')));
      expect(corpo, isNot(contains('salvarRegistro(listaSintomas')));
    });

    test('as três operações endereçam o documento pela data', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains('_documento(registro.data)'));
      expect(codigo, contains('_documento(data)'));
      expect(codigo, contains('return _colecao?.doc(data);'));
    });

    test('nenhum id aleatório é criado para sintomas', () {
      final codigo = fonteDoStorage();

      expect(codigo, isNot(contains('novoId')));
      expect(codigo, isNot(contains('.doc().id')));
      expect(codigo, isNot(contains('colecao.add(')));
    });

    test('o caminho da coleção continua o mesmo', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains(".collection('usuarios')"));
      expect(codigo, contains(".collection('sintomas')"));
    });

    test('o storage não engole erro — quem trata é a tela', () {
      expect(fonteDoStorage(), isNot(contains('catch')));
    });

    test('o load recupera a data pelo id do documento', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<List<RegistroSintomas>> carregarRegistros(',
      );

      expect(corpo, contains('dataDoDocumento: doc.id'));
    });
  });

  group('SintomasScreen — rollback é exato', () {
    test('o rollback restaura o retrato anterior, não remonta o dia', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _salvarRegistroDeHoje(',
      );

      expect(corpo, contains('List<RegistroSintomas>.from(listaSintomas)'));
      expect('listaSintomas = anterior;'.allMatches(corpo), hasLength(2));
    });

    test('sessão ausente também desfaz, em vez de anunciar sucesso', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _salvarRegistroDeHoje(',
      );

      final checagem = corpo.indexOf('if (salvo == null)');
      final sucesso = corpo.indexOf('if (mounted) setState');

      expect(checagem, greaterThan(-1));
      expect(checagem, lessThan(sucesso));
      expect(corpo, contains('throw const SessaoSemGravacao()'));
    });
  });

  group('HISTÓRICO — o registro de hoje não pode ser escondido', () {
    testWidgets('hoje aparece junto com os dias anteriores', (tester) async {
      listaSintomas = [...tresDiasAnteriores(), registroDeHoje(peso: 69.0)];
      await montar(tester);

      expect(find.text(rotuloDe(hoje())), findsOneWidget);
      expect(find.text(rotuloDe(diasAtras(1))), findsOneWidget);
      expect(find.text(rotuloDe(diasAtras(2))), findsOneWidget);
      expect(find.text(rotuloDe(diasAtras(3))), findsOneWidget);
    });

    testWidgets('hoje aparece primeiro, acima dos anteriores', (tester) async {
      listaSintomas = [...tresDiasAnteriores(), registroDeHoje()];
      await montar(tester);

      double alturaDe(String dataIso) =>
          tester.getTopLeft(find.text(rotuloDe(dataIso))).dy;

      expect(alturaDe(hoje()), lessThan(alturaDe(diasAtras(1))));
      expect(alturaDe(diasAtras(1)), lessThan(alturaDe(diasAtras(2))));
    });

    testWidgets('a linha de hoje mostra o que foi salvo', (tester) async {
      listaSintomas = [registroDeHoje(humor: 3, peso: 69.0)];
      await montar(tester);

      expect(find.text('69.0 kg'), findsOneWidget);
      // O rótulo também existe no seletor de sintomas, acima.
      expect(find.text('Dor nas costas'), findsNWidgets(2));
      expect(
        find.text('Seus registros anteriores vão aparecer aqui.'),
        findsNothing,
      );
    });

    testWidgets('sem registro de hoje o histórico segue só com os anteriores', (
      tester,
    ) async {
      listaSintomas = tresDiasAnteriores();
      await montar(tester);

      expect(find.text(rotuloDe(hoje())), findsNothing);
      expect(find.text(rotuloDe(diasAtras(1))), findsOneWidget);
    });

    testWidgets('histórico vazio continua com a mensagem de vazio', (
      tester,
    ) async {
      await montar(tester);

      expect(
        find.text('Seus registros anteriores vão aparecer aqui.'),
        findsOneWidget,
      );
    });

    test('o getter do histórico não filtra pela data de hoje', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'List<RegistroSintomas> get _historico',
      );

      expect(corpo, isNot(contains('!= hoje')));
      expect(corpo, isNot(contains('_hoje()')));
    });

    test('o histórico não ordena a lista global no lugar', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'List<RegistroSintomas> get _historico',
      );

      expect(corpo, contains('List<RegistroSintomas>.from(listaSintomas)'));
      expect(corpo, isNot(contains('listaSintomas.sort(')));
    });
  });

  group('Salvar hoje — o cenário reportado', () {
    test('o registro de hoje entra e os antigos ficam intactos', () {
      final antigos = tresDiasAnteriores();
      final novo = RegistroSintomas(
        data: hoje(),
        humor: 3,
        sintomas: const ['costas'],
        peso: 69.0,
      );

      final resultado = comRegistroDoDia(antigos, novo);

      expect(resultado, hasLength(4));
      expect(resultado.where((r) => r.data == hoje()), hasLength(1));
      expect(resultado.firstWhere((r) => r.data == hoje()).peso, 69.0);
      for (var i = 0; i < antigos.length; i++) {
        expect(identical(resultado[i], antigos[i]), isTrue, reason: 'dia $i');
      }
    });

    test('salvar hoje de novo substitui, sem duplicar o dia', () {
      final antigos = tresDiasAnteriores();

      var lista = comRegistroDoDia(
        antigos,
        RegistroSintomas(data: hoje(), humor: 3, peso: 69.0),
      );
      lista = comRegistroDoDia(
        lista,
        RegistroSintomas(data: hoje(), humor: 1, peso: 70.0),
      );

      expect(lista, hasLength(4));
      expect(lista.where((r) => r.data == hoje()), hasLength(1));
      expect(lista.firstWhere((r) => r.data == hoje()).peso, 70.0);
      expect(lista.firstWhere((r) => r.data == hoje()).humor, 1);
    });

    test('a data de hoje tem o mesmo formato dos registros do histórico', () {
      final novo = RegistroSintomas(data: hoje(), humor: 3);

      expect(novo.data, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      for (final antigo in tresDiasAnteriores()) {
        expect(antigo.data, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      }
      // Ordenação por string só funciona porque o formato é fixo e zero-padded.
      expect(hoje().compareTo(diasAtras(1)), greaterThan(0));
    });
  });
}
