import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/models/contracao.dart';
import 'package:suacontracao_ai/screens/historico_screen.dart';

void main() {
  tearDown(() => listaContracoes = []);

  String fonteDaTela() => File('lib/screens/historico_screen.dart')
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

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

  Contracao contracao({
    String? id,
    String? data,
    String inicio = '08:00',
    String intensidade = 'Forte',
    int? duracaoSegundos = 90,
  }) => Contracao(
    id: id,
    data: data ?? hoje(),
    inicio: inicio,
    fim: '08:02',
    intensidade: intensidade,
    observacoes: '',
    duracaoSegundos: duracaoSegundos,
  );

  Contracao quebrada({String id = 'ruim', String data = ''}) => Contracao(
    id: id,
    data: data,
    inicio: '07:45',
    fim: '07:47',
    intensidade: 'Moderada',
    observacoes: '',
    duracaoSegundos: 120,
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

    await tester.pumpWidget(const MaterialApp(home: HistoricoScreen()));
    await tester.pumpAndSettle();
  }

  group('HistoricoScreen — carregamento próprio', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Histórico'), findsOneWidget);
    });

    testWidgets('falha de leitura mostra erro e retry, não um vazio falso', (
      tester,
    ) async {
      await montar(tester);

      expect(
        find.text('Não foi possível carregar seu histórico'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.text('Nenhuma contração registrada.'), findsNothing);
    });

    testWidgets('o retry dispara uma nova tentativa', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('não usa o global pré-populado', (tester) async {
      // Mesmo com o global cheio, a tela carrega do storage — e aqui a
      // leitura falha, então nada do global pode aparecer.
      listaContracoes = [contracao(id: 'c1')];

      await montar(tester);

      expect(find.text('08:00'), findsNothing);
      expect(
        find.text('Não foi possível carregar seu histórico'),
        findsOneWidget,
      );
    });

    test('a tela não lê mais a lista global', () {
      expect(fonteDaTela(), isNot(contains('listaContracoes')));
      expect(fonteDaTela(), isNot(contains('contracoes_data.dart')));
    });

    test('o carregamento passa pelo storage e trata erro amigável', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'Future<void> _carregar(');

      expect(corpo, contains('ContracoesStorage.carregarContracoes()'));
      expect(corpo, contains('FirestoreErro.mensagemAmigavel('));
      expect(corpo, contains('if (!mounted) return;'));
    });
  });

  group('dataDoRegistro', () {
    test('reconhece uma data bem formada', () {
      expect(dataDoRegistro('2026-01-15'), DateTime(2026, 1, 15));
    });

    test('aceita componentes sem zero à esquerda', () {
      expect(dataDoRegistro('2026-1-5'), DateTime(2026, 1, 5));
    });

    test('devolve nulo sem lançar para entradas quebradas', () {
      for (final invalida in ['', 'abc', '2026', '2026-01', '2026/01/15']) {
        expect(
          () => dataDoRegistro(invalida),
          returnsNormally,
          reason: invalida,
        );
        expect(dataDoRegistro(invalida), isNull, reason: invalida);
      }
    });
  });

  group('Separação por data utilizável', () {
    test('separa os registros datados dos quebrados', () {
      final registros = [
        contracao(id: 'c1'),
        quebrada(id: 'x'),
        contracao(id: 'c2', data: '2026-01-15'),
        quebrada(id: 'y', data: 'ontem'),
      ];

      expect(comDataUtilizavel(registros).map((c) => c.id), ['c1', 'c2']);
      expect(semDataUtilizavel(registros).map((c) => c.id), ['x', 'y']);
    });

    test('nenhum registro é perdido na separação', () {
      final registros = [contracao(id: 'c1'), quebrada(id: 'x')];

      expect(
        comDataUtilizavel(registros).length +
            semDataUtilizavel(registros).length,
        registros.length,
      );
    });

    test('listas vazias não lançam', () {
      expect(comDataUtilizavel(const []), isEmpty);
      expect(semDataUtilizavel(const []), isEmpty);
    });

    test('não alteram a lista recebida', () {
      final registros = [contracao(id: 'c1'), quebrada(id: 'x')];

      comDataUtilizavel(registros);
      semDataUtilizavel(registros);

      expect(registros, hasLength(2));
    });
  });

  group('resumoDaContracao', () {
    test('junta os campos preenchidos', () {
      final resumo = resumoDaContracao(contracao(id: 'c1', data: '2026-01-15'));

      expect(resumo, contains('2026-01-15'));
      expect(resumo, contains('08:00'));
      expect(resumo, contains('Forte'));
      expect(resumo, contains('01:30'));
    });

    test('mostra os campos crus de um registro quebrado', () {
      final resumo = resumoDaContracao(quebrada(data: 'ontem'));

      expect(resumo, contains('ontem'));
      expect(resumo, contains('07:45'));
    });

    test('omite a duração quando é desconhecida', () {
      final resumo = resumoDaContracao(
        contracao(id: 'c1', data: '2026-01-15', duracaoSegundos: null),
      );

      expect(resumo, isNot(contains('Duração')));
      expect(resumo, contains('2026-01-15'));
    });

    test('registro sem nenhum campo tem rótulo próprio', () {
      final vazia = Contracao(
        id: 'c1',
        data: '',
        inicio: '',
        fim: '',
        intensidade: '',
        observacoes: '',
      );

      expect(resumoDaContracao(vazia), 'Contração sem informações');
    });
  });

  group('Registro malformado — visível, não escondido', () {
    test('a tela não descarta registros sem data válida', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'List<Contracao> get contracoesFiltradas',
      );

      // Antes: `if (dataContracao == null) return false;` sumia com o registro.
      expect(corpo, isNot(contains('return false;')));
      expect(corpo, contains('comDataUtilizavel(_contracoes)'));
    });

    test('existe uma faixa própria para os sem data', () {
      final tela = fonteDaTela();

      expect(tela, contains("'SEM DATA VÁLIDA'"));
      expect(tela, contains('semData.map((c) => _linhaSemData(context, c))'));
    });

    test('a faixa aparece em qualquer filtro', () {
      final tela = fonteDaTela().replaceAll(RegExp(r'\s+'), ' ');

      // semData vem de _contracoes inteiro, não de contracoesFiltradas.
      expect(tela, contains('get semData => semDataUtilizavel(_contracoes)'));
    });

    test('o registro quebrado mostra os campos crus', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'Widget _linhaSemData(');

      expect(corpo, contains('Data inválida:'));
      expect(corpo, contains(r'${c.data}'));
      expect(corpo, contains(r'${c.inicio}'));
      expect(corpo, contains(r'${c.intensidade}'));
    });

    test('o estado vazio só aparece quando não há nada de nada', () {
      expect(fonteDaTela(), contains('if (grupos.isEmpty && semData.isEmpty)'));
    });
  });

  group('Exclusão com confirmação', () {
    test('o swipe passa pela confirmação antes do storage', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarEExcluir(',
      );

      final guarda = corpo.indexOf(
        'if (!await _confirmarExclusao(c)) return false;',
      );
      final remocao = corpo.indexOf('ContracoesStorage.remover(');

      expect(guarda, greaterThan(-1));
      expect(
        remocao,
        greaterThan(guarda),
        reason: 'confirmar antes de excluir',
      );
    });

    test('a exclusão endereça só aquele documento', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarEExcluir(',
      );

      expect(corpo, contains('ContracoesStorage.remover(id)'));
      expect(corpo, isNot(contains('carregarContracoes')));
    });

    test('só remove da lista depois do sucesso', () {
      final tela = fonteDaTela();

      expect(tela, contains('confirmDismiss: (_) => _confirmarEExcluir(c)'));
      expect(
        corpoDoMetodo(tela, 'Future<bool> _confirmarEExcluir('),
        contains('if (removeu) return true;'),
      );
      expect(tela, contains('_contracoes.removeWhere((x) => x.id == id)'));
    });

    test('a falha devolve false e avisa', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarEExcluir(',
      );

      expect(corpo, contains('showSnackBar'));
      expect(corpo, contains('return false;'));
      expect(corpo, contains('mensagemSemSessao'));
    });

    test('o diálogo tem Cancelar e Excluir', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<bool> _confirmarExclusao(',
      );

      expect(corpo, contains("'Excluir contração?'"));
      expect(corpo, contains("'Cancelar'"));
      expect(corpo, contains("'Excluir'"));
      expect(corpo, contains('resumoDaContracao(c)'));
    });

    test('a tela não trava com PopScope', () {
      expect(fonteDaTela(), isNot(contains('PopScope')));
    });

    test('registro sem id não entra no fluxo de exclusão', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'Widget _cardExcluivel(');

      expect(corpo, contains('if (id == null) return child;'));
    });
  });

  group('Integridade — sem escrita destrutiva na tela', () {
    test('a tela não regrava a coleção', () {
      final tela = fonteDaTela();

      expect(tela, isNot(contains('batch')));
      expect(tela, isNot(contains('WriteBatch')));
      expect(tela, isNot(contains('.commit()')));
      expect(tela, isNot(contains('salvarContracoes')));
      expect(tela, isNot(contains('.docs')));
    });

    test('os filtros Hoje/Semana/Mês continuam existindo', () {
      final tela = fonteDaTela();

      expect(tela, contains("['Hoje', 'Semana', 'Mês']"));
      expect(tela, contains("_filtro == 'Hoje'"));
      expect(tela, contains("_filtro == 'Semana'"));
    });

    test('o resumo continua com os três indicadores', () {
      final tela = fonteDaTela();

      expect(tela, contains("_summaryItem('\$totalFiltrado', 'Total')"));
      expect(tela, contains("_summaryItem(intervaloMedio, 'Intervalo')"));
      expect(tela, contains("_summaryItem(duracaoMedia, 'Duração méd.')"));
    });
  });
}
