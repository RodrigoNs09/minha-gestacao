import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/consultas_data.dart';
import 'package:suacontracao_ai/models/consulta.dart';
import 'package:suacontracao_ai/screens/agenda_screen.dart';
import 'package:suacontracao_ai/widgets/moldura_responsiva.dart';

void main() {
  tearDown(() => listaConsultas = []);

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String fonteDaTela() => fonteDe('lib/screens/agenda_screen.dart');
  String fonteDoStorage() => fonteDe('lib/services/consultas_storage.dart');

  String corpoDoMetodo(String fonte, String assinatura) {
    final inicio = fonte.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = fonte.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return fonte.substring(inicio, fim);
  }

  String comoData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String daquiADias(int dias) =>
      comoData(DateTime.now().add(Duration(days: dias)));

  Consulta consulta({
    required String id,
    String titulo = 'Pré-natal',
    String profissional = 'Dra. Ana',
    String? data,
    String hora = '14:30',
    bool realizada = false,
  }) => Consulta(
    id: id,
    titulo: titulo,
    profissional: profissional,
    data: data ?? daquiADias(7),
    hora: hora,
    realizada: realizada,
  );

  Consulta consultaQuebrada({String id = 'ruim'}) => Consulta(
    id: id,
    titulo: 'Exame antigo',
    profissional: 'Lab Central',
    data: '',
    hora: 'xx',
  );

  Future<void> montar(
    WidgetTester tester, {
    Size tamanho = const Size(360, 800),
    double escalaDeTexto = 1.0,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: const AgendaScreen(),
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: escalaDeTexto,
          maxScaleFactor: escalaDeTexto,
          child: child!,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> abrirTeclado(
    WidgetTester tester, {
    double altura = 230,
  }) async {
    tester.view.viewInsets = FakeViewPadding(bottom: altura);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
  }

  Future<void> deslizarParaExcluir(WidgetTester tester, String titulo) async {
    await tester.drag(find.text(titulo), const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  group('AgendaScreen — inicialização', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('PRÓXIMAS'), findsOneWidget);
    });

    testWidgets('falha de leitura não destrói a tela', (tester) async {
      listaConsultas = [consulta(id: 'c1')];

      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(listaConsultas, hasLength(1));
      expect(find.text('Pré-natal'), findsOneWidget);
      expect(find.text('+ Nova'), findsOneWidget);
    });

    testWidgets('agenda vazia mostra o convite para adicionar', (tester) async {
      await montar(tester);

      expect(find.textContaining('Nenhuma consulta agendada'), findsOneWidget);
    });
  });

  group('AgendaScreen — criação', () {
    testWidgets('o formulário aparece ao tocar em + Nova', (tester) async {
      await montar(tester);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();

      expect(find.text('Nova consulta'), findsOneWidget);
      expect(find.text('Adicionar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('título vazio não dispara gravação', (tester) async {
      await montar(tester);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(listaConsultas, isEmpty);
      expect(find.text('Nova consulta'), findsOneWidget);
    });

    testWidgets('falha ao salvar mantém o formulário aberto', (tester) async {
      await montar(tester);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título (ex: Pré-natal)'),
        'Ultrassom',
      );
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nova consulta'), findsOneWidget);
      expect(listaConsultas, isEmpty);
    });

    testWidgets('falha ao salvar não deixa consulta fantasma', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título (ex: Pré-natal)'),
        'Ultrassom',
      );
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(listaConsultas, hasLength(1));
      expect(listaConsultas.single.id, 'c1');
    });

    testWidgets('depois da falha ainda dá para tentar de novo', (tester) async {
      await montar(tester);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título (ex: Pré-natal)'),
        'Ultrassom',
      );

      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Adicionar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nova consulta'), findsOneWidget);
    });

    test('o id pendente é cunhado uma vez e só limpo no sucesso', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _abrirFormularioNovaConsulta(',
      );

      expect(corpo, contains('_idPendente ??='));
      expect(corpo, contains('id: _idPendente!'));

      final limpeza = corpo.indexOf('_idPendente = null;');
      final checagemDeFalha = corpo.indexOf('if (salva == null)');

      expect(limpeza, greaterThan(-1));
      expect(checagemDeFalha, greaterThan(-1));
      expect(
        limpeza,
        greaterThan(checagemDeFalha),
        reason: 'só limpa depois do caminho de erro ter retornado',
      );
    });

    test('a criação usa a operação individual', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _abrirFormularioNovaConsulta(',
      );

      expect(corpo, contains('ConsultasStorage.adicionar(novaConsulta)'));
      expect(corpo, isNot(contains('salvarConsultas')));
    });
  });

  group('AgendaScreen — marcar como realizada', () {
    testWidgets('o botão existe nas consultas não realizadas', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('não aparece nas já realizadas', (tester) async {
      listaConsultas = [consulta(id: 'c1', realizada: true)];
      await montar(tester);

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      expect(find.text('REALIZADAS'), findsOneWidget);
    });

    testWidgets('falha faz rollback e a consulta segue não realizada', (
      tester,
    ) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(listaConsultas, hasLength(1));
      expect(listaConsultas.single.realizada, isFalse);
      expect(find.text('REALIZADAS'), findsNothing);
    });

    testWidgets('o rollback preserva o id e os demais campos', (tester) async {
      listaConsultas = [consulta(id: 'c1', titulo: 'Ultrassom')];
      await montar(tester);

      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(listaConsultas.single.id, 'c1');
      expect(listaConsultas.single.titulo, 'Ultrassom');
    });

    testWidgets('depois da falha a tela continua utilizável', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pré-natal'), findsOneWidget);
    });

    test('marcar realizada usa a operação individual', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _marcarComoRealizada(',
      );

      expect(corpo, contains('ConsultasStorage.atualizar(atualizada)'));
      expect(corpo, isNot(contains('salvarConsultas')));
      expect(corpo, contains('copyWith(realizada: true)'));
    });

    test('o rollback reencontra a consulta pelo id', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _marcarComoRealizada(',
      );

      expect(corpo, contains('indexWhere((x) => x.id == c.id)'));
      expect(corpo, contains('listaConsultas[indiceAtual] = anterior'));
    });
  });

  group('AgendaScreen — exclusão com confirmação', () {
    testWidgets('o swipe abre a confirmação', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Pré-natal');

      expect(find.text('Excluir consulta?'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Excluir'), findsOneWidget);
    });

    testWidgets('a confirmação identifica qual consulta será removida', (
      tester,
    ) async {
      listaConsultas = [consulta(id: 'c1', titulo: 'Ultrassom morfológico')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Ultrassom morfológico');

      expect(find.textContaining('Ultrassom morfológico'), findsWidgets);
      expect(find.textContaining('Dra. Ana'), findsWidgets);
    });

    testWidgets('cancelar não altera a lista e mantém o card', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Pré-natal');
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir consulta?'), findsNothing);
      expect(listaConsultas, hasLength(1));
      expect(find.text('Pré-natal'), findsOneWidget);
    });

    testWidgets('falha na exclusão mantém o item na lista e na tela', (
      tester,
    ) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Pré-natal');
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(listaConsultas, hasLength(1));
      expect(find.text('Pré-natal'), findsOneWidget);
    });

    testWidgets('depois da falha ainda dá para tentar de novo', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Pré-natal');
      await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
      await tester.pumpAndSettle();

      await deslizarParaExcluir(tester, 'Pré-natal');

      expect(find.text('Excluir consulta?'), findsOneWidget);
    });

    testWidgets('a confirmação não trava a tela', (tester) async {
      listaConsultas = [consulta(id: 'c1')];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Pré-natal');

      final cancelar = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Cancelar'),
      );

      expect(cancelar.onPressed, isNotNull);
      expect(fonteDaTela(), isNot(contains('PopScope')));
    });

    test('cancelar não chega ao storage', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarEExcluir(',
      );

      final guarda = corpo.indexOf(
        'if (!await _confirmarExclusao(c)) return false;',
      );
      final remocao = corpo.indexOf('ConsultasStorage.remover(');

      expect(guarda, greaterThan(-1));
      expect(remocao, greaterThan(guarda));
    });

    test('a exclusão usa a operação individual pelo id', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarEExcluir(',
      );

      expect(corpo, contains('ConsultasStorage.remover(c.id)'));
      expect(corpo, isNot(contains('salvarConsultas')));
    });

    test('só remove da memória depois do sucesso', () {
      final tela = fonteDaTela();

      expect(tela, contains('confirmDismiss: (_) => _confirmarEExcluir(c)'));
      expect(
        corpoDoMetodo(tela, 'Future<bool> _confirmarEExcluir('),
        contains('if (removeu) return true;'),
      );
    });
  });

  group('AgendaScreen — dado malformado', () {
    testWidgets('a tela abre com uma consulta de data vazia e hora inválida', (
      tester,
    ) async {
      listaConsultas = [consultaQuebrada()];
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Agenda'), findsOneWidget);
    });

    testWidgets('o registro quebrado continua identificável', (tester) async {
      listaConsultas = [consultaQuebrada()];
      await montar(tester);

      expect(find.text('Exame antigo'), findsOneWidget);
      expect(find.text('Data inválida'), findsOneWidget);
      expect(find.textContaining('Lab Central'), findsWidgets);
    });

    testWidgets('o registro quebrado pode ser excluído', (tester) async {
      listaConsultas = [consultaQuebrada()];
      await montar(tester);

      await deslizarParaExcluir(tester, 'Exame antigo');

      expect(find.text('Excluir consulta?'), findsOneWidget);
      expect(find.textContaining('Exame antigo'), findsWidgets);
    });

    testWidgets('uma consulta quebrada não esconde as boas', (tester) async {
      listaConsultas = [
        consultaQuebrada(),
        consulta(id: 'c1'),
        consulta(id: 'c2', titulo: 'Ultrassom', data: daquiADias(2)),
      ];
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Pré-natal'), findsOneWidget);
      expect(find.text('Ultrassom'), findsOneWidget);
      expect(find.text('Exame antigo'), findsOneWidget);
    });

    testWidgets('quebrada e realizada também não derruba a tela', (
      tester,
    ) async {
      listaConsultas = [
        Consulta(
          id: 'r1',
          titulo: 'Consulta antiga',
          profissional: '',
          data: '2026-13-45',
          hora: '99:99',
          realizada: true,
        ),
      ];
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Consulta antiga'), findsOneWidget);
    });
  });

  group('ordenadasPorData', () {
    test('ordena crescente as que têm data', () {
      final lista = [
        consulta(id: 'c3', data: daquiADias(30)),
        consulta(id: 'c1', data: daquiADias(1)),
        consulta(id: 'c2', data: daquiADias(10)),
      ];

      final resultado = ordenadasPorData(lista, maisAntigaPrimeiro: true);

      expect(resultado.map((c) => c.id), ['c1', 'c2', 'c3']);
    });

    test('ordena decrescente quando pedido', () {
      final lista = [
        consulta(id: 'c1', data: daquiADias(1)),
        consulta(id: 'c3', data: daquiADias(30)),
        consulta(id: 'c2', data: daquiADias(10)),
      ];

      final resultado = ordenadasPorData(lista, maisAntigaPrimeiro: false);

      expect(resultado.map((c) => c.id), ['c3', 'c2', 'c1']);
    });

    test('as sem data válida vão para o fim, nas duas direções', () {
      final lista = [
        consultaQuebrada(id: 'x'),
        consulta(id: 'c2', data: daquiADias(10)),
        consulta(id: 'c1', data: daquiADias(1)),
      ];

      expect(
        ordenadasPorData(lista, maisAntigaPrimeiro: true).map((c) => c.id),
        ['c1', 'c2', 'x'],
      );
      expect(
        ordenadasPorData(lista, maisAntigaPrimeiro: false).map((c) => c.id),
        ['c2', 'c1', 'x'],
      );
    });

    test('não usa epoch como substituto — a quebrada nunca vem primeiro', () {
      final lista = [
        consultaQuebrada(id: 'x'),
        consulta(id: 'c1', data: daquiADias(1)),
      ];

      final resultado = ordenadasPorData(lista, maisAntigaPrimeiro: true);

      expect(resultado.first.id, 'c1');
      expect(resultado.last.id, 'x');
    });

    test('lista só de quebradas não lança e preserva todas', () {
      final lista = [consultaQuebrada(id: 'x'), consultaQuebrada(id: 'y')];

      final resultado = ordenadasPorData(lista, maisAntigaPrimeiro: true);

      expect(resultado, hasLength(2));
      expect(resultado.map((c) => c.id), ['x', 'y']);
    });

    test('lista vazia devolve lista vazia', () {
      expect(ordenadasPorData(const [], maisAntigaPrimeiro: true), isEmpty);
    });

    test('não altera a lista recebida', () {
      final lista = [
        consulta(id: 'c2', data: daquiADias(10)),
        consulta(id: 'c1', data: daquiADias(1)),
      ];

      ordenadasPorData(lista, maisAntigaPrimeiro: true);

      expect(lista.map((c) => c.id), ['c2', 'c1']);
    });
  });

  group('resumoDaConsulta', () {
    test('junta os campos preenchidos', () {
      final resumo = resumoDaConsulta(consulta(id: 'c1', data: '2026-09-08'));

      expect(resumo, contains('Pré-natal'));
      expect(resumo, contains('2026-09-08'));
      expect(resumo, contains('14:30'));
      expect(resumo, contains('Dra. Ana'));
    });

    test('mostra os campos crus de um registro quebrado', () {
      final resumo = resumoDaConsulta(consultaQuebrada());

      expect(resumo, contains('Exame antigo'));
      expect(resumo, contains('xx'));
      expect(resumo, contains('Lab Central'));
    });

    test('não deixa separador solto quando faltam campos', () {
      final resumo = resumoDaConsulta(
        Consulta(
          id: 'c1',
          titulo: 'Só título',
          profissional: '',
          data: '',
          hora: '',
        ),
      );

      expect(resumo, 'Só título');
    });

    test('consulta sem nenhum campo tem um rótulo próprio', () {
      final resumo = resumoDaConsulta(
        Consulta(id: 'c1', titulo: '', profissional: '', data: '', hora: ''),
      );

      expect(resumo, 'Consulta sem informações');
    });
  });

  group('Integridade — o padrão destrutivo não pode voltar', () {
    test('a tela não conhece mais a gravação de lista', () {
      expect(fonteDaTela(), isNot(contains('salvarConsultas')));
    });

    test('a tela nunca manda a lista inteira para o storage', () {
      final tela = fonteDaTela();

      expect(tela, isNot(contains('ConsultasStorage.adicionar(lista')));
      expect(tela, isNot(contains('ConsultasStorage.atualizar(lista')));
      expect(tela, isNot(contains('List<Consulta>.from(listaConsultas)')));
    });

    test('nem tela nem storage usam batch', () {
      for (final codigo in [fonteDaTela(), fonteDoStorage()]) {
        expect(codigo, isNot(contains('WriteBatch')));
        expect(codigo, isNot(contains('batch')));
        expect(codigo, isNot(contains('.commit()')));
      }
    });

    test('a tela não enumera documentos', () {
      final tela = fonteDaTela();

      expect(tela, isNot(contains('.docs')));
      expect(tela, isNot(contains('doc.reference')));
    });

    test('só a leitura toca a coleção inteira', () {
      final storage = fonteDoStorage();
      final leitura = corpoDoMetodo(
        storage,
        'static Future<List<Consulta>> carregarConsultas(',
      );

      expect(leitura, contains('colecao.get()'));
      expect('colecao.get()'.allMatches(storage), hasLength(1));
    });
  });

  group('Responsividade — sem moldura fixa', () {

    testWidgets('cabe numa tela pequena', (tester) async {
      await montar(tester, tamanho: const Size(320, 640));

      expect(tester.takeException(), isNull);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('+ Nova'), findsOneWidget);
    });

    testWidgets('cabe em paisagem', (tester) async {
      await montar(tester, tamanho: const Size(800, 360));

      expect(tester.takeException(), isNull);
      expect(find.text('Agenda'), findsOneWidget);
      expect(find.text('PRÓXIMAS'), findsOneWidget);
    });

    testWidgets('cabe com fonte ampliada', (tester) async {
      await montar(tester, escalaDeTexto: 2.0);

      expect(tester.takeException(), isNull);
      expect(find.text('+ Nova'), findsOneWidget);
    });

    testWidgets('o botão + Nova continua clicável em tela pequena', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(320, 640));

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();

      expect(find.text('Nova consulta'), findsOneWidget);
    });

    testWidgets('o botão + Nova continua clicável com fonte ampliada', (
      tester,
    ) async {
      await montar(tester, escalaDeTexto: 1.6);

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nova consulta'), findsOneWidget);
    });

    testWidgets('o formulário cabe em tela pequena', (tester) async {
      await montar(tester, tamanho: const Size(320, 640));

      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Adicionar'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);
    });

    testWidgets('ocupa a largura disponível numa tela estreita', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(360, 800));

      final largura = tester.getSize(find.byType(ListView)).width;

      expect(largura, closeTo(336, 1));
      expect(largura, greaterThan(300));
    });

    testWidgets('não estica além do máximo numa tela larga', (tester) async {
      await montar(tester, tamanho: const Size(1200, 900));

      expect(tester.getSize(find.byType(ListView)).width, closeTo(400, 1));
    });

    test('a moldura não depende mais de tamanho fixo', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Widget build(BuildContext context)',
      );

      expect(corpo, isNot(contains('width: 300')));
      expect(corpo, isNot(contains('minHeight: 620')));

      expect(corpo, contains('MolduraResponsiva('));
      expect(corpo, isNot(contains('BoxConstraints(maxWidth:')));
      expect(corpo, isNot(contains('BorderRadius.circular(36)')));
    });

    testWidgets('a tela usa mesmo o widget compartilhado', (tester) async {
      await montar(tester);

      expect(find.byType(MolduraResponsiva), findsOneWidget);
    });

    test('o título do cabeçalho é flexível', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Widget build(BuildContext context)',
      );

      final titulo = corpo.indexOf("Text('Agenda'");
      final expandedAntes = corpo.lastIndexOf('Expanded(', titulo);
      final rowAntes = corpo.lastIndexOf('Row(', titulo);

      expect(expandedAntes, greaterThan(rowAntes));
      expect(corpo, contains('overflow: TextOverflow.ellipsis'));
    });
  });

  group('Responsividade — com consulta renderizada', () {
    final umaQuinta = DateTime(2026, 10, 15);

    setUp(() {
      listaConsultas = [
        consulta(id: 'c1', titulo: 'Pré-natal', data: comoData(umaQuinta)),
      ];
    });

    testWidgets('o card aparece mesmo — o teste anterior não o renderizava', (
      tester,
    ) async {
      await montar(tester);

      expect(find.text('Pré-natal'), findsOneWidget);
      expect(find.text('Qui'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Out'), findsOneWidget);
    });

    for (final escala in [1.3, 1.5, 2.0]) {
      testWidgets('o badge da data cabe com fonte $escala', (tester) async {
        await montar(tester, escalaDeTexto: escala);

        expect(tester.takeException(), isNull);

        expect(find.text('Qui'), findsOneWidget);
        expect(find.text('15'), findsOneWidget);
        expect(find.text('Out'), findsOneWidget);
      });
    }

    testWidgets('o badge cabe com fonte ampliada em tela pequena', (
      tester,
    ) async {
      await montar(
        tester,
        tamanho: const Size(320, 640),
        escalaDeTexto: 1.5,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Out'), findsOneWidget);
    });

    testWidgets('o badge cresce com a fonte em vez de estourar', (
      tester,
    ) async {
      Size badge() => tester.getSize(
        find.ancestor(
          of: find.text('Qui'),
          matching: find.byType(Container),
        ).first,
      );

      await montar(tester);
      final normal = badge();

      expect(normal.height, 52);
      expect(normal.width, greaterThanOrEqualTo(44));

      await montar(tester, escalaDeTexto: 1.5);
      final ampliado = badge();

      expect(ampliado.height, greaterThan(normal.height));
      expect(ampliado.width, lessThan(normal.width * 2));
    });

    test('o badge não usa mais altura fixa', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Widget _consultaCard(Consulta c,',
      );

      expect(corpo, isNot(contains('height: 52')));
      expect(corpo, contains('minHeight: 52'));
    });
  });

  group('Responsividade — formulário com teclado', () {
    Future<void> abrirFormulario(WidgetTester tester) async {
      await tester.tap(find.text('+ Nova'));
      await tester.pumpAndSettle();
    }

    testWidgets('o formulário cabe em paisagem com o teclado aberto', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(800, 360));
      await abrirFormulario(tester);
      await abrirTeclado(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancelar e Adicionar continuam alcançáveis com o teclado', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(800, 360));
      await abrirFormulario(tester);
      await abrirTeclado(tester);

      await tester.ensureVisible(find.text('Adicionar'));
      await tester.pumpAndSettle();
      expect(find.text('Adicionar'), findsOneWidget);

      await tester.ensureVisible(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Nova consulta'), findsNothing);
    });

    testWidgets('todos os campos continuam acessíveis com o teclado', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(800, 360));
      await abrirFormulario(tester);
      await abrirTeclado(tester);

      for (final campo in ['Título (ex: Pré-natal)', 'Médico(a) / Local']) {
        await tester.ensureVisible(find.text(campo));
        await tester.pumpAndSettle();
        expect(find.text(campo), findsOneWidget, reason: campo);
      }

      expect(tester.takeException(), isNull);
    });

    testWidgets('em retrato sem teclado a folha não rola — visual preservado', (
      tester,
    ) async {
      await montar(tester);
      await abrirFormulario(tester);

      final posicao = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            ).first,
          )
          .position;

      expect(posicao.maxScrollExtent, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('em paisagem com teclado a folha realmente rola', (
      tester,
    ) async {
      await montar(tester, tamanho: const Size(800, 360));
      await abrirFormulario(tester);
      await abrirTeclado(tester);

      final posicao = tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byType(SingleChildScrollView),
              matching: find.byType(Scrollable),
            ).first,
          )
          .position;

      expect(posicao.maxScrollExtent, greaterThan(0));
    });

    testWidgets('o formulário continua cabendo em retrato com o teclado', (
      tester,
    ) async {
      await montar(tester);
      await abrirFormulario(tester);
      await abrirTeclado(tester, altura: 300);

      expect(tester.takeException(), isNull);
      expect(find.text('Adicionar'), findsOneWidget);
    });

    test('a folha usa rolagem em vez de Column solta', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _abrirFormularioNovaConsulta(',
      );

      expect(corpo, contains('SingleChildScrollView('));
      expect(fonteDaTela(), isNot(contains('FlutterError.onError')));
    });

    test('o Scaffold da Agenda não encolhe com o teclado', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Widget build(BuildContext context)',
      );

      expect(corpo, contains('resizeToAvoidBottomInset: false'));
    });
  });

  group('Integridade — a correção não mexeu em regra de negócio', () {
    test('a folha continua gravando por documento, sem batch', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _abrirFormularioNovaConsulta(',
      );

      expect(corpo, contains('ConsultasStorage.adicionar(novaConsulta)'));
      expect(corpo, contains('_idPendente ??='));
      expect(corpo, isNot(contains('batch')));
      expect(corpo, isNot(contains('salvarConsultas')));
    });
  });
}
