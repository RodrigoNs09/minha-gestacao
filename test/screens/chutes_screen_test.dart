import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/chutes_data.dart';
import 'package:suacontracao_ai/models/chute_sessao.dart';
import 'package:suacontracao_ai/screens/chutes_screen.dart';

void main() {
  const meta = 10;

  tearDown(() => listaChutes = []);

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((linha) => !linha.trimLeft().startsWith('//'))
      .join('\n');

  String fonteDaTela() => fonteDe('lib/screens/chutes_screen.dart');
  String fonteDoStorage() => fonteDe('lib/services/chutes_storage.dart');

  String corpoDoMetodo(String fonte, String assinatura) {
    final inicio = fonte.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    final fim = fonte.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return fonte.substring(inicio, fim);
  }

  String comoData(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String comoHora(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  String hoje() => comoData(DateTime.now());

  ChuteSessao sessao({
    String? id,
    String? data,
    String horaInicio = '14:00',
    String horaFim = '14:12',
    int totalChutes = meta,
  }) => ChuteSessao(
    id: id,
    data: data ?? hoje(),
    horaInicio: horaInicio,
    horaFim: horaFim,
    totalChutes: totalChutes,
    completa: true,
  );

  ProgressoDeChutes progresso({
    int chutes = 10,
    String? data,
    DateTime? inicio,
    String? sessaoId,
  }) => ProgressoDeChutes(
    chutes: chutes,
    data: data ?? hoje(),
    inicio: inicio ?? DateTime.now().subtract(const Duration(minutes: 20)),
    sessaoId: sessaoId,
  );

  void ignorarOverflowDeLayout() {
    final anterior = FlutterError.onError;
    FlutterError.onError = (detalhes) {
      if (detalhes.exceptionAsString().contains('overflowed')) return;
      anterior?.call(detalhes);
    };
    addTearDown(() => FlutterError.onError = anterior);
  }

  // O pulso do contador é uma animação infinita: pumpAndSettle nunca
  // assentaria. Dois pumps bastam para o initState e os Futures da leitura.
  Future<void> assentar(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> montar(WidgetTester tester) async {
    ignorarOverflowDeLayout();

    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: ChutesScreen()));
    await assentar(tester);
  }

  group('ChutesScreen — inicialização', () {
    testWidgets('monta sem Firebase e não estoura', (tester) async {
      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Contador de Chutes'), findsOneWidget);
      expect(find.text('Registrar'), findsOneWidget);
    });

    testWidgets('falha de leitura não destrói a tela', (tester) async {
      listaChutes = [sessao(id: 's1')];

      await montar(tester);

      expect(tester.takeException(), isNull);
      expect(listaChutes, hasLength(1));
      expect(find.text('Sessões de hoje'), findsOneWidget);
    });

    testWidgets('a animação de pulso é descartada ao sair', (tester) async {
      await montar(tester);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await assentar(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('sair durante a leitura não chama setState após dispose', (
      tester,
    ) async {
      ignorarOverflowDeLayout();
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const MaterialApp(home: ChutesScreen()));
      // Desmonta antes de a leitura terminar.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await assentar(tester);

      expect(tester.takeException(), isNull);
    });
  });

  group('ChutesScreen — contagem', () {
    testWidgets('começa em zero', (tester) async {
      await montar(tester);

      expect(find.text('0'), findsOneWidget);
    });

    // Sem Firebase a gravação falha no mesmo turno síncrono do toque, então
    // o "1" intermediário não chega a ser pintado. O que dá para garantir
    // aqui é que o incremento é de exatamente um, e uma só vez.
    test('um toque incrementa exatamente uma vez', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _registrarChute(',
      );

      expect('_chutesAtuais++'.allMatches(corpo), hasLength(1));
      expect(corpo, isNot(contains('_chutesAtuais +=')));
      expect(corpo, contains('chutes: _chutesAtuais'));
      expect(corpo, contains('final chutesAntes = _chutesAtuais;'));
    });

    testWidgets('duplo toque durante o salvamento não conta duas vezes', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Registrar'), warnIfMissed: false);
      await tester.tap(find.text('Registrar'), warnIfMissed: false);
      await tester.pump();

      expect(find.text('2'), findsNothing);
    });

    testWidgets('falha ao gravar o progresso faz rollback do contador', (
      tester,
    ) async {
      await montar(tester);

      await tester.tap(find.text('Registrar'));
      await assentar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('falha não cria sessão fantasma no histórico', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Registrar'));
      await assentar(tester);

      expect(listaChutes, isEmpty);
      expect(find.textContaining('Nenhuma sessão registrada'), findsOneWidget);
    });

    testWidgets('depois da falha ainda dá para tentar de novo', (tester) async {
      await montar(tester);

      await tester.tap(find.text('Registrar'));
      await assentar(tester);
      await tester.tap(find.text('Registrar'));
      await assentar(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Registrar'), findsOneWidget);
    });
  });

  group('retomadaPara — o cenário K1', () {
    RetomadaDeProgresso decidir(
      ProgressoDeChutes? p, {
      List<ChuteSessao> historico = const [],
    }) => retomadaPara(
      p,
      hoje: hoje(),
      meta: meta,
      historico: historico,
      formatarHora: comoHora,
    );

    test('sem progresso não há nada a retomar', () {
      expect(decidir(null), RetomadaDeProgresso.nenhuma);
    });

    test('contagem parcial de hoje é restaurada', () {
      expect(decidir(progresso(chutes: 4)), RetomadaDeProgresso.restaurar);
    });

    test('K1: contagem completa com sessaoId manda concluir, não travar', () {
      expect(
        decidir(progresso(chutes: 10, sessaoId: 'sessao-1')),
        RetomadaDeProgresso.concluir,
      );
    });

    test('K1: contagem completa sem sessaoId também manda concluir', () {
      expect(decidir(progresso(chutes: 10)), RetomadaDeProgresso.concluir);
    });

    test('contagem acima da meta também manda concluir', () {
      expect(
        decidir(progresso(chutes: 12, sessaoId: 's')),
        RetomadaDeProgresso.concluir,
      );
    });

    test('progresso de outro dia é descartado em silêncio', () {
      expect(
        decidir(progresso(chutes: 10, data: '2020-01-01', sessaoId: 's')),
        RetomadaDeProgresso.deOutroDia,
      );
    });

    test('contagem completa sem horário de início é irrecuperável', () {
      final semInicio = ProgressoDeChutes(chutes: 10, data: hoje());

      expect(decidir(semInicio), RetomadaDeProgresso.irrecuperavel);
    });

    test('contagem parcial sem horário ainda é restaurada', () {
      final semInicio = ProgressoDeChutes(chutes: 3, data: hoje());

      expect(decidir(semInicio), RetomadaDeProgresso.restaurar);
    });

    test('progresso antigo cuja sessão já existe só precisa ser limpo', () {
      final inicio = DateTime.now().subtract(const Duration(minutes: 20));

      expect(
        decidir(
          progresso(chutes: 10, inicio: inicio),
          historico: [sessao(id: 's1', horaInicio: comoHora(inicio))],
        ),
        RetomadaDeProgresso.jaRegistrada,
      );
    });

    test('com sessaoId presente o histórico não muda a decisão', () {
      final inicio = DateTime.now().subtract(const Duration(minutes: 20));

      expect(
        decidir(
          progresso(chutes: 10, inicio: inicio, sessaoId: 'sessao-1'),
          historico: [sessao(id: 'sessao-1', horaInicio: comoHora(inicio))],
        ),
        RetomadaDeProgresso.concluir,
      );
    });

    test('sessão de outro horário não conta como já registrada', () {
      final inicio = DateTime.now().subtract(const Duration(minutes: 20));

      expect(
        decidir(
          progresso(chutes: 10, inicio: inicio),
          historico: [sessao(id: 's1', horaInicio: '03:00')],
        ),
        RetomadaDeProgresso.concluir,
      );
    });
  });

  group('comSessao — repetir a conclusão não duplica', () {
    test('acrescenta uma sessão nova', () {
      final resultado = comSessao([sessao(id: 's1')], sessao(id: 's2'));

      expect(resultado, hasLength(2));
      expect(resultado.last.id, 's2');
    });

    test('K1: concluir duas vezes com o mesmo id não cria duas sessões', () {
      var historico = <ChuteSessao>[];

      historico = comSessao(historico, sessao(id: 'sessao-1'));
      historico = comSessao(
        historico,
        sessao(id: 'sessao-1', horaFim: '14:15'),
      );

      expect(historico, hasLength(1));
      expect(historico.single.horaFim, '14:15');
    });

    test('as outras sessões continuam intactas', () {
      final antiga = sessao(id: 's1', horaInicio: '08:00');
      final outra = sessao(id: 's2', horaInicio: '10:00');

      final resultado = comSessao([antiga, outra], sessao(id: 's2'));

      expect(resultado, hasLength(2));
      expect(identical(resultado.first, antiga), isTrue);
    });

    test('sessões sem id nunca são substituídas', () {
      final semId = sessao(horaInicio: '08:00');

      final resultado = comSessao([semId], sessao(id: 's1'));

      expect(resultado, hasLength(2));
    });

    test('não altera a lista recebida', () {
      final historico = [sessao(id: 's1')];

      comSessao(historico, sessao(id: 's1'));

      expect(historico, hasLength(1));
    });
  });

  group('sessaoJaNoHistorico', () {
    test('reconhece pela data e pelo horário de início', () {
      final historico = [sessao(id: 's1', horaInicio: '14:00')];

      expect(
        sessaoJaNoHistorico(historico, data: hoje(), horaInicio: '14:00'),
        isTrue,
      );
    });

    test('horário diferente não é a mesma sessão', () {
      final historico = [sessao(id: 's1', horaInicio: '14:00')];

      expect(
        sessaoJaNoHistorico(historico, data: hoje(), horaInicio: '15:00'),
        isFalse,
      );
    });

    test('dia diferente não é a mesma sessão', () {
      final historico = [sessao(id: 's1', data: '2020-01-01')];

      expect(
        sessaoJaNoHistorico(historico, data: hoje(), horaInicio: '14:00'),
        isFalse,
      );
    });

    test('histórico vazio nunca reconhece', () {
      expect(
        sessaoJaNoHistorico(const [], data: hoje(), horaInicio: '14:00'),
        isFalse,
      );
    });
  });

  group('Ordem das operações — o que corrige o K1', () {
    test('a sessão é gravada antes de o progresso ser limpo', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _concluirSessaoPendente(',
      );

      final gravacao = corpo.indexOf('ChutesStorage.adicionar(');
      final limpeza = corpo.indexOf('_limparProgressoEReiniciar()');

      expect(gravacao, greaterThan(-1));
      expect(limpeza, greaterThan(gravacao), reason: 'gravar antes de limpar');
    });

    test('o caminho de falha retorna antes da limpeza', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _concluirSessaoPendente(',
      );
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      final falha = normalizado.indexOf('if (gravada == null)');
      final limpeza = normalizado.indexOf('_limparProgressoEReiniciar()');

      expect(falha, greaterThan(-1));
      expect(falha, lessThan(limpeza));
      expect(normalizado.substring(falha, limpeza), contains('return;'));
    });

    test('a conclusão reaproveita o id em vez de cunhar um novo', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _concluirSessaoPendente(',
      );

      expect(corpo, contains('_idSessaoPendente ??='));
      expect(corpo, contains('id: id'));
    });

    test('a falha não remove da memória uma sessão já gravada', () {
      final tela = fonteDaTela();

      expect(tela, isNot(contains('listaChutes.remove(')));
      expect(
        corpoDoMetodo(tela, 'Future<void> _concluirSessaoPendente('),
        contains('comSessao(listaChutes, gravada!)'),
      );
    });

    test('o botão não fica morto enquanto a conclusão está pendente', () {
      final tela = fonteDaTela().replaceAll(RegExp(r'\s+'), ' ');

      expect(tela, contains('_conclusaoPendente ? _concluirSessaoPendente'));
      expect(tela, isNot(contains('(metaAtingida || _salvando) ? null')));
    });

    test('o registro de chute persiste antes de concluir', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _registrarChute(',
      );

      final progressoGravado = corpo.indexOf('salvarProgressoAtual(');
      final conclusao = corpo.indexOf('_concluirSessaoPendente()');

      expect(progressoGravado, greaterThan(-1));
      expect(conclusao, greaterThan(progressoGravado));
      expect(corpo, contains('if (!gravou)'));
    });

    test('o duplo toque continua bloqueado', () {
      final corpo = corpoDoMetodo(
        fonteDaTela(),
        'Future<void> _registrarChute(',
      );

      expect(
        corpo,
        contains('if (_chutesAtuais >= _metaChutes || _salvando) return;'),
      );
    });

    test('_carregar guarda mounted antes de cada setState', () {
      final corpo = corpoDoMetodo(fonteDaTela(), 'Future<void> _carregar(');
      final normalizado = corpo.replaceAll(RegExp(r'\s+'), ' ');

      final primeiroSetState = normalizado.indexOf('setState(');
      final primeiraGuarda = normalizado.indexOf('if (!mounted) return;');

      expect(primeiraGuarda, greaterThan(-1));
      expect(primeiraGuarda, lessThan(primeiroSetState));
      expect('if (!mounted) return;'.allMatches(normalizado).length, 2);
    });
  });

  group('Storage — sem operação destrutiva', () {
    test('salvarSessoes não existe mais', () {
      expect(fonteDoStorage(), isNot(contains('salvarSessoes')));
      expect(fonteDaTela(), isNot(contains('salvarSessoes')));
    });

    test('o storage não usa batch', () {
      final codigo = fonteDoStorage();

      expect(codigo, isNot(contains('batch')));
      expect(codigo, isNot(contains('WriteBatch')));
      expect(codigo, isNot(contains('.commit()')));
      expect(codigo, isNot(contains('doc.reference')));
    });

    test('a escrita da sessão não enumera a coleção', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<ChuteSessao?> adicionar(',
      );

      expect(corpo, isNot(contains('.get()')));
      expect(corpo, isNot(contains('docs')));
      expect(corpo, contains('colecao.doc(id).set('));
    });

    test('só a leitura toca a coleção inteira', () {
      final storage = fonteDoStorage();

      expect('colecao.get()'.allMatches(storage), hasLength(1));
      expect(
        corpoDoMetodo(
          storage,
          'static Future<List<ChuteSessao>> carregarSessoes(',
        ),
        contains('idDoDocumento: doc.id'),
      );
    });

    test('os caminhos do Firestore continuam os mesmos', () {
      final storage = fonteDoStorage();

      expect(storage, contains(".collection('usuarios')"));
      expect(storage, contains(".collection('chutes')"));
      expect(
        storage,
        contains("static const String campoProgresso = 'chute_em_andamento'"),
      );
    });

    test('o progresso é gravado com merge, sem somar', () {
      final corpo = corpoDoMetodo(
        fonteDoStorage(),
        'static Future<bool> salvarProgressoAtual(',
      );

      expect(corpo, contains('SetOptions(merge: true)'));
      expect(corpo, isNot(contains('FieldValue.increment')));
    });

    test('as escritas sinalizam ausência de sessão', () {
      final storage = fonteDoStorage();

      expect(
        corpoDoMetodo(storage, 'static Future<ChuteSessao?> adicionar('),
        contains('return null;'),
      );
      expect(
        corpoDoMetodo(storage, 'static Future<bool> salvarProgressoAtual('),
        contains('return false;'),
      );
      expect(
        corpoDoMetodo(storage, 'static Future<bool> limparProgressoAtual('),
        contains('return false;'),
      );
    });

    test('o storage não engole erro — quem trata é a tela', () {
      expect(fonteDoStorage(), isNot(contains('catch')));
    });
  });
}
