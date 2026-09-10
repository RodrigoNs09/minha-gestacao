import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/screens/vacinas_screen.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;

  // A tela só avalia o calendário com gestação informada (C1). Sem isto
  // todos os testes abaixo veriam o painel "informe sua gestação".
  setUp(() {
    gestacaoOriginal = gestacaoAtual;
    definirGestacao(DateTime(2026, 1, 5), 'gestacao-de-teste');
  });

  tearDown(() => gestacaoAtual = gestacaoOriginal);

  List<String> linhasDeCodigo() {
    return File('lib/screens/vacinas_screen.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .toList();
  }

  String fonte() => linhasDeCodigo().join('\n');

  // Para asserções que o dart format pode quebrar em várias linhas.
  String fonteNormalizada() => fonte().replaceAll(RegExp(r'\s+'), ' ');

  // Corpo de um método, da assinatura até a chave de fecho na indentação de
  // método. Serve para checar invariantes que valem só dentro de um deles.
  String corpoDoMetodo(String assinatura) {
    final codigo = fonte();
    final inicio = codigo.indexOf(assinatura);
    expect(inicio, greaterThan(-1), reason: assinatura);

    // Uma linha contendo só "  }": o fecho na indentação de método. Precisa
    // do \n final para não casar com o "  }) async {" de uma assinatura
    // multilinha.
    final fim = codigo.indexOf('\n  }\n', inicio);
    expect(fim, greaterThan(inicio), reason: assinatura);

    return codigo.substring(inicio, fim);
  }

  group('VacinasScreen — falha de leitura', () {
    testWidgets('não quebra e mostra o painel de erro com retry', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text('Não foi possível carregar seus registros'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('nenhum card de vacina é exibido quando a leitura falha', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      for (final regra in calendarioPni2026) {
        expect(
          find.text(regra.nomeExibicao),
          findsNothing,
          reason: regra.codigo,
        );
      }
    });

    testWidgets('nenhuma mensagem da engine aparece quando a leitura falha', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text(mensagemPeriodoRecomendado), findsNothing);
      expect(find.text(mensagemGeralVacinas), findsNothing);
    });

    testWidgets('nenhuma ação de registro aparece quando a leitura falha', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Registrar'), findsNothing);
      expect(find.text('Registrar vacinação'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Editar registro'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('Excluir registro?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Registros não reconhecidos'), findsNothing);
    });

    testWidgets('o cabeçalho continua visível no estado de erro', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vacinas da Gestação'), findsOneWidget);
      expect(find.text('Calendário e seus registros'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('mostra indicador de carregamento antes de concluir', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });
  });

  group('VacinasScreen — a tela não decide regra clínica', () {
    test('não exibe status.motivo', () {
      expect(fonte(), isNot(contains('.motivo')));
    });

    test('a engine é chamada num único ponto, com a temporada explícita', () {
      final codigo = fonte();

      expect('VacinasEngine.avaliar('.allMatches(codigo), hasLength(1));
      // A temporada é a que a versão do calendário declara, não uma string
      // solta nem algo derivado da data.
      expect(codigo, contains('temporadaInfluenza: temporadaInfluenzaPni2026'));
      expect(codigo, isNot(contains('temporadaInfluenza: null')));
    });

    test('a avaliação usa uma única referência temporal', () {
      final codigo = fonte();

      expect(codigo, contains('dataAtual: avaliadoEm'));
      // Dias civis, não duração decorrida: a hora gravada na DUM não pode
      // atrasar a abertura de uma janela.
      expect(codigo, contains('diasDeCalendarioEntre(dum, avaliadoEm)'));
      expect(codigo, isNot(contains('avaliadoEm.difference(dum)')));
      expect(codigo, isNot(contains('.inDays')));

      // O instante é lido uma única vez por avaliação, e nunca dentro dela.
      final abertura = corpoDoMetodo('void _abrirNovaAvaliacao()');
      expect('DateTime.now()'.allMatches(abertura), hasLength(1));
      expect(abertura, contains('_avaliadoEm = DateTime.now();'));
      expect(abertura, contains('_dum = gestacaoAtual.dum;'));

      expect(
        corpoDoMetodo('List<StatusVacinacao> _avaliar()'),
        isNot(contains('DateTime.now()')),
      );
      expect(
        corpoDoMetodo('Future<void> _carregar()'),
        isNot(contains('DateTime.now()')),
      );
    });

    test('o relógio da tela não fica congelado após um salvamento', () {
      final codigo = fonte();

      // Três chamadas: ao carregar, ao gravar e ao excluir com sucesso.
      expect('_abrirNovaAvaliacao();'.allMatches(codigo), hasLength(3));
      expect(
        codigo,
        contains('_historico = registros;\n        _abrirNovaAvaliacao();'),
      );

      // Gravação e remoção renovam a avaliação nos seus próprios métodos.
      expect(
        fonteNormalizada(),
        contains(
          '_historico = lista; _idPendente = null; _abrirNovaAvaliacao();',
        ),
      );
      expect(
        fonteNormalizada(),
        contains(
          '_historico = [...?_historico]..removeWhere((r) => r.id == id); '
          '_abrirNovaAvaliacao();',
        ),
      );
    });

    test('não alimenta a engine com a semana clampeada de GestacaoInfo', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('semanaAtual')));
      expect(codigo, isNot(contains('semanaGestacionalDe')));
    });

    test('não calcula intervalo, janela nem estado por conta própria', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('Duration(')));
      expect(codigo, isNot(contains('adicionarMeses')));
      expect(codigo, isNot(contains('gestacaoPlausivel')));
      expect(codigo, isNot(contains('EstadoVacina')));
    });

    test('a apresentação do estado vem só de apresentacaoDe', () {
      final codigo = fonte();

      expect(codigo, contains('apresentacaoDe(status.estado)'));
      expect(codigo, isNot(contains('Color(0x')));
      // Colors.white e Colors.transparent são chrome do sheet, não paleta.
      expect(
        codigo,
        isNot(matches(RegExp(r'\bColors\.(?!white|transparent)'))),
      );
    });

    test('quem decide se cabe registrar é a engine', () {
      expect(fonte(), contains('if (status.podeRegistrar)'));
    });

    test('não usa Firebase direto: o acesso passa pelo storage', () {
      final imports = linhasDeCodigo()
          .where((linha) => linha.trimLeft().startsWith('import '))
          .toList();

      expect(imports, isNotEmpty, reason: 'sanidade: o arquivo tem imports');

      for (final linha in imports) {
        expect(linha, isNot(contains('cloud_firestore')), reason: linha);
        expect(linha, isNot(contains('firebase_auth')), reason: linha);
        expect(linha, isNot(contains('firebase_core')), reason: linha);
        expect(linha, isNot(contains('ia_service')), reason: linha);
      }
      expect(imports.where((l) => l.contains('vacinas_storage')), hasLength(1));
    });

    test('nenhum texto próprio da tela usa linguagem prescritiva', () {
      const proibidos = [
        'tome agora',
        'você precisa tomar',
        'você está atrasada',
        'está indicada para você',
        'atrasad',
        'urgente',
        'obrigatóri',
      ];

      final codigo = fonte().toLowerCase();

      for (final termo in proibidos) {
        expect(codigo, isNot(contains(termo)), reason: termo);
      }
    });
  });

  group('VacinasScreen — cadastro', () {
    test('cadastro e edição usam o mesmo bottom sheet', () {
      final codigo = fonte();

      expect('showModalBottomSheet'.allMatches(codigo), hasLength(1));
      expect('Future<void> _abrirFormulario('.allMatches(codigo), hasLength(1));
      expect(codigo, contains('showDatePicker'));
      expect(codigo, contains('RegistroVacinacao? edicaoDe,'));
    });

    test('cada operação do storage tem um único ponto de chamada', () {
      final codigo = fonte();

      expect('VacinasStorage.adicionar('.allMatches(codigo), hasLength(1));
      expect('VacinasStorage.novoId()'.allMatches(codigo), hasLength(1));
      expect('VacinasStorage.remover('.allMatches(codigo), hasLength(1));
      expect(
        'VacinasStorage.carregarRegistros('.allMatches(codigo),
        hasLength(1),
      );
      // \b evita casar dentro de isDismissible, que é parâmetro do sheet.
      expect(codigo, isNot(matches(RegExp(r'\bDismissible'))));
    });

    test('o id pendente é criado ao abrir e só é limpo depois do sheet', () {
      final codigo = fonte();

      final corpo = corpoDoMetodo('Future<void> _abrirFormulario(');

      final gera = corpo.indexOf(
        '_idPendente = edicaoDe?.id ?? VacinasStorage.novoId();',
      );
      final abre = corpo.indexOf('await showModalBottomSheet<void>');
      final limpa = corpo.indexOf('setState(() => _idPendente = null);');

      expect(gera, greaterThan(-1));
      expect(abre, greaterThan(gera));
      // A limpeza vem depois do sheet fechar, e só se nada estiver em voo.
      expect(limpa, greaterThan(abre));
      expect(corpo, contains('if (_gravando) return;'));
      expect(codigo, contains('id: _idPendente'));
      // Os dois pontos que zeram o id: o sucesso e o cancelamento limpo.
      expect('_idPendente = null'.allMatches(codigo), hasLength(2));
    });

    test('um registro novo leva os campos aprovados e nada além', () {
      final normalizada = fonteNormalizada();

      // Num cadastro novo edicaoDe é nulo, então valem os lados direitos.
      expect(normalizada, contains('vacinaCodigo: vacinaCodigo'));
      expect(normalizada, contains('?? versaoCalendarioPni2026'));
      expect(normalizada, contains('?? OrigemRegistro.registradoPelaUsuaria'));
      expect(normalizada, contains('?? gestacaoAtual.dum'));
      expect(normalizada, contains('?? DateTime.now()'));
      // Registro novo recebe a temporada só quando a regra é por temporada.
      expect(
        normalizada,
        contains(
          'temporadaNoRegistro: edicaoDe != null ? edicaoDe.temporadaNoRegistro '
          ': temporadaDeNovoRegistro',
        ),
      );
      expect(normalizada, isNot(contains("versaoCalendario: '")));
      expect(normalizada, isNot(contains('temporadaNoRegistro: DateTime')));
    });

    test('a temporada do registro novo vem da regra e do calendário', () {
      final normalizada = fonteNormalizada();

      const declaracao =
          'final temporadaDeNovoRegistro = regraPorCodigo(vacinaCodigo) is '
          'RegraDependeTemporada ? temporadaInfluenzaPni2026 : null;';

      expect(normalizada, contains(declaracao));

      // Nada de deduzir a temporada de uma data: nem do relógio, nem da
      // dataAplicacao, nem de um ano extraído dela.
      expect(declaracao, isNot(contains('.year')));
      expect(declaracao, isNot(contains('DateTime')));
      expect(declaracao, isNot(contains('dataAplicacao')));
      expect(normalizada, isNot(contains("temporadaNoRegistro: '")));
      expect(normalizada, isNot(contains('temporadaNoRegistro: DateTime')));
    });

    test('as posições de dose vêm da regra, não de uma lista fixa', () {
      final normalizada = fonteNormalizada();

      expect(
        normalizada,
        contains(
          'final posicoesDaDose = regraDaVacina is RegraDependeHistorico && '
          'regraDaVacina.dosesDoEsquemaBasico > 0 ? List<int>.generate( '
          'regraDaVacina.dosesDoEsquemaBasico, (indice) => indice + 1, ) '
          ': const <int>[];',
        ),
      );
      expect(normalizada, contains('for (final numero in posicoesDaDose)'));

      // O literal fixo não pode voltar.
      expect(normalizada, isNot(contains('[1, 2, 3]')));
      expect(normalizada, isNot(contains('in [1,')));
    });

    test('vacinas que não dependem de histórico não oferecem dose', () {
      final normalizada = fonteNormalizada();

      // Sem regra de histórico a lista é vazia, então o for não gera nada,
      // e o bloco inteiro segue atrás de mostraNumero.
      expect(normalizada, contains(': const <int>[];'));
      expect(
        normalizada,
        contains(
          'final mostraNumero = pedeNumeroDaDose && _declaraAplicacao(situacao)',
        ),
      );
      expect(normalizada, contains('if (mostraNumero)'));
    });

    test('o número da dose vem do tipo da regra, sem código fixo', () {
      final codigo = fonte();

      expect(codigo, contains('regraDaVacina is RegraDependeHistorico'));
      expect(
        codigo,
        contains('final regraDaVacina = regraPorCodigo(vacinaCodigo)'),
      );

      for (final codigoDeVacina in [
        'codigoHepatiteB',
        'codigoDt',
        'codigoDtpa',
        'codigoInfluenza',
        'codigoCovid19',
        'codigoVsr',
        'codigoFebreAmarela',
      ]) {
        expect(codigo, isNot(contains(codigoDeVacina)), reason: codigoDeVacina);
      }
    });

    test(
      'as quatro situações do modelo são oferecidas, sem inventar rótulo',
      () {
        final codigo = fonte();

        expect(codigo, contains('SituacaoInformada.values.map'));
        expect(codigo, contains("'Aplicada com data'"));
        expect(codigo, contains("'Aplicada, mas não sei a data'"));
        expect(codigo, contains("'Não aplicada'"));
        expect(codigo, contains("'Não sei informar'"));
        expect(codigo, contains("'Situação da vacinação'"));
        expect(codigo, contains("'Data da aplicação'"));
        expect(codigo, contains("'Número da dose'"));
      },
    );

    test('só a situação com data envia dataAplicacao', () {
      expect(
        fonte(),
        contains(
          'dataAplicacao: situacao == SituacaoInformada.aplicadaComData',
        ),
      );
    });

    test('a data da aplicação não pode ser futura', () {
      final codigo = fonte();

      expect(codigo, contains('lastDate: hoje'));
      expect(codigo, isNot(contains('lastDate: DateTime(2')));
    });

    test('a lista só muda depois da confirmação do servidor', () {
      final codigo = fonte();

      // A lista só é tocada dentro de _registrarSalvo, e ele só é chamado
      // no ramo de sucesso da gravação.
      expect(codigo, contains('if (gravado != null)'));
      expect(codigo, contains('_registrarSalvo(gravado);'));
      expect('_registrarSalvo('.allMatches(codigo), hasLength(2));

      final corpo = corpoDoMetodo('Future<void> _abrirFormulario(');
      final grava = corpo.indexOf('await VacinasStorage.adicionar(registro)');
      final aplica = corpo.indexOf('_registrarSalvo(gravado);');

      expect(grava, greaterThan(-1));
      expect(aplica, greaterThan(grava));
    });

    test('há proteção contra clique duplo durante o salvamento', () {
      final codigo = fonte();

      expect(codigo, contains('if (salvando || !podeSalvar) return;'));
      expect(codigo, contains('salvando = true'));
      expect(
        fonteNormalizada(),
        contains('onPressed: (salvando || !podeSalvar) ? null : salvar'),
      );
      // Uma gravação em voo bloqueia abrir outro formulário, então nem
      // fechando o sheet dá para disparar uma segunda.
      expect(codigo, contains('if (_gravando) return;'));
      expect(codigo, isNot(contains('canPop')));
    });

    test('a falha mostra a mensagem do FirestoreErro e mantém o formulário', () {
      final codigo = fonte();

      expect(codigo, contains('FirestoreErro.mensagemAmigavel(falha)'));
      expect(codigo, contains('salvando = false'));
      // Nenhum pop no caminho de erro: o sheet fica aberto para nova tentativa.
      // Os dois do formulário são o Cancelar e o sucesso da gravação.
      final formulario = corpoDoMetodo('Future<void> _abrirFormulario(');
      expect('Navigator.pop(ctx'.allMatches(formulario), hasLength(2));
      expect(formulario, contains('if (!ctx.mounted) return;'));
    });
  });

  group('VacinasScreen — edição', () {
    test('existe ação de editar, ligada ao registro exibido', () {
      final codigo = fonte();

      expect(codigo, contains("'Editar'"));
      expect(codigo, contains("'Editar registro'"));
      expect(
        fonteNormalizada(),
        contains(
          'onTap: () => _abrirFormulario( context, registro.vacinaCodigo, '
          'edicaoDe: registro, )',
        ),
      );
    });

    test('a associação com o card é pelo código da vacina', () {
      expect(fonte(), contains('_registrosDaVacina(status.vacinaCodigo)'));
      expect(
        corpoDoMetodo('List<RegistroVacinacao> _registrosDaVacina('),
        contains('r.vacinaCodigo == codigo'),
      );
    });

    test('a edição não gera id novo: escreve no id do registro', () {
      final codigo = fonte();

      expect(
        codigo,
        contains('_idPendente = edicaoDe?.id ?? VacinasStorage.novoId();'),
      );
      expect('VacinasStorage.novoId()'.allMatches(codigo), hasLength(1));
      expect(codigo, contains('id: _idPendente'));
      expect(codigo, isNot(contains('.comId(')));
    });

    test('a edição grava pelo adicionar, nunca pelo remover', () {
      final codigo = fonte();

      expect('VacinasStorage.adicionar('.allMatches(codigo), hasLength(1));
      expect(codigo, isNot(matches(RegExp(r'\bDismissible'))));
      expect(codigo, isNot(contains('onLongPress')));

      // O remover não aparece dentro do formulário.
      expect(
        corpoDoMetodo('Future<void> _abrirFormulario('),
        isNot(contains('VacinasStorage.remover')),
      );
    });

    test('os campos históricos do registro são preservados', () {
      final normalizada = fonteNormalizada();

      expect(normalizada, contains('vacinaCodigo: vacinaCodigo'));
      expect(
        normalizada,
        contains(
          'versaoCalendario: edicaoDe?.versaoCalendario ?? versaoCalendarioPni2026',
        ),
      );
      expect(
        normalizada,
        contains(
          'origemRegistro: edicaoDe?.origemRegistro ?? OrigemRegistro.registradoPelaUsuaria',
        ),
      );
      expect(
        normalizada,
        contains('dumNoRegistro: edicaoDe?.dumNoRegistro ?? gestacaoAtual.dum'),
      );
      // Sem ?? aqui: um registro antigo com temporada nula continua nulo,
      // em vez de ser migrado para a temporada vigente.
      expect(
        normalizada,
        contains(
          'temporadaNoRegistro: edicaoDe != null ? edicaoDe.temporadaNoRegistro '
          ': temporadaDeNovoRegistro',
        ),
      );
      expect(normalizada, isNot(contains('edicaoDe?.temporadaNoRegistro ??')));
      expect(
        normalizada,
        contains('criadoEm: edicaoDe?.criadoEm ?? DateTime.now()'),
      );
      expect(normalizada, contains('observacao: edicaoDe?.observacao'));
    });

    test('o formulário abre com os valores atuais do registro', () {
      final normalizada = fonteNormalizada();

      expect(
        normalizada,
        contains('SituacaoInformada? situacao = edicaoDe?.situacaoInformada;'),
      );
      expect(
        normalizada,
        contains('DateTime? dataAplicacao = edicaoDe?.dataAplicacao;'),
      );
      expect(
        normalizada,
        contains('int? numeroDaDose = edicaoDe?.numeroDaDose;'),
      );
    });

    test('trocar de situação limpa os campos que deixam de valer', () {
      final normalizada = fonteNormalizada();

      expect(
        normalizada,
        contains(
          'if (opcao != SituacaoInformada.aplicadaComData) { dataAplicacao = null; }',
        ),
      );
      expect(
        normalizada,
        contains('if (!_declaraAplicacao(opcao)) { numeroDaDose = null; }'),
      );
      // Segunda barreira na gravação: o que não é exibido não é gravado.
      expect(
        normalizada,
        contains(
          'dataAplicacao: situacao == SituacaoInformada.aplicadaComData ? dataAplicacao : null',
        ),
      );
      expect(
        normalizada,
        contains('numeroDaDose: mostraNumero ? numeroDaDose : null'),
      );
    });

    test('a lista substitui pelo mesmo id em vez de duplicar', () {
      final codigo = fonte();

      final corpo = corpoDoMetodo('void _registrarSalvo(');

      expect(corpo, contains('lista.indexWhere((r) => r.id == salvo.id)'));
      expect(corpo, contains('lista[indice] = salvo;'));
      expect(corpo, contains('lista.add(salvo);'));
      // Um único ponto de escrita na lista, chamado só após o sucesso.
      expect('_historico = lista;'.allMatches(codigo), hasLength(1));
    });

    test('só registros com id podem ser editados', () {
      expect(
        corpoDoMetodo('List<RegistroVacinacao> _registrosDaVacina('),
        contains('r.id != null'),
      );
    });
  });

  group('VacinasScreen — nunca fica intransponível', () {
    String formulario() => corpoDoMetodo('Future<void> _abrirFormulario(');
    String exclusao() => corpoDoMetodo('Future<void> _excluirRegistro(');

    test('1. salvando não permite uma segunda submissão', () {
      final corpo = formulario();

      // Três barreiras: guarda na função, botão desabilitado e guarda no
      // State, que sobrevive ao sheet fechar.
      expect(corpo, contains('if (salvando || !podeSalvar) return;'));
      expect(
        fonteNormalizada(),
        contains('onPressed: (salvando || !podeSalvar) ? null : salvar'),
      );
      expect(corpo, contains('if (_gravando) return;'));
      expect('VacinasStorage.adicionar('.allMatches(fonte()), hasLength(1));
    });

    test('2. excluindo não permite uma segunda exclusão', () {
      final corpo = exclusao();

      expect(corpo, contains('if (excluindo) return;'));
      expect(corpo, contains('if (_excluindoId != null) return;'));
      expect(
        fonteNormalizada(),
        contains('onPressed: excluindo ? null : confirmar'),
      );
      expect('VacinasStorage.remover('.allMatches(fonte()), hasLength(1));
    });

    test('3. há saída segura durante a operação de rede', () {
      final codigo = fonte();

      // Nenhum PopScope segurando a navegação, nos dois lugares.
      expect(codigo, isNot(contains('PopScope')));
      expect(codigo, isNot(contains('canPop')));

      // E os dois Cancelar continuam clicáveis durante a operação.
      final normalizada = fonteNormalizada();
      expect(
        normalizada,
        contains(
          'onPressed: () => Navigator.pop(ctx), child: Text( \'Cancelar\'',
        ),
      );
      expect(normalizada, isNot(contains('onPressed: salvando ? null')));
      expect(
        normalizada,
        isNot(contains('onPressed: excluindo ? null : () => Navigator.pop')),
      );
    });

    test('4. a operação em voo não é reexecutada ao sair e voltar', () {
      final codigo = fonte();

      // Sair no meio preserva o id reservado: a próxima tentativa
      // sobrescreve o mesmo documento em vez de criar outro.
      expect(
        fonteNormalizada(),
        contains('if (_gravando) return; setState(() => _idPendente = null);'),
      );
      // E abrir outro formulário durante a gravação é barrado.
      expect(
        formulario().indexOf('if (_gravando) return;'),
        lessThan(formulario().indexOf('VacinasStorage.novoId()')),
      );
      expect(codigo, contains('_gravando = true;'));
      expect(codigo, contains('_gravando = false;'));
      expect(codigo, contains('_excluindoId = id;'));
      expect(codigo, contains('_excluindoId = null;'));
    });

    test('o resultado é aplicado mesmo se a tela já tiver fechado o sheet', () {
      final codigo = fonte();

      // _registrarSalvo e _registrarRemocao mexem no State, não no sheet, e
      // se protegem com mounted.
      for (final metodo in [
        'void _registrarSalvo(',
        'void _registrarRemocao(',
      ]) {
        expect(
          corpoDoMetodo(metodo),
          contains('if (!mounted) return;'),
          reason: metodo,
        );
      }

      expect(codigo, contains('_registrarSalvo(gravado);'));
      expect(codigo, contains('_registrarRemocao(id);'));
      expect(codigo, contains('if (ctx.mounted) Navigator.pop(ctx);'));

      // Um único ponto que insere e um único que remove do histórico.
      expect('_historico = lista;'.allMatches(codigo), hasLength(1));
      expect('removeWhere((r) => r.id == id)'.allMatches(codigo), hasLength(1));
    });

    test('o id só é liberado quando não há gravação pendente', () {
      final corpo = formulario();

      final guarda = corpo.indexOf('if (_gravando) return;\n\n    setState');
      final libera = corpo.indexOf('setState(() => _idPendente = null);');

      expect(libera, greaterThan(-1));
      expect(guarda, greaterThan(-1));
      expect(guarda, lessThan(libera));
    });
  });

  group('VacinasScreen — identidade da gestação', () {
    test('a avaliação recebe o id da gestação atual', () {
      final codigo = fonte();

      expect(codigo, contains('gestacaoId: _gestacaoId'));
      expect(
        corpoDoMetodo('void _abrirNovaAvaliacao()'),
        contains('_gestacaoId = gestacaoAtual.id;'),
      );
    });

    test('um registro novo recebe o id da gestação atual', () {
      expect(
        fonteNormalizada(),
        contains(
          'gestacaoId: edicaoDe != null ? edicaoDe.gestacaoId '
          ': gestacaoAtual.id',
        ),
      );
    });

    test('a edição preserva o id, inclusive quando é nulo', () {
      final normalizada = fonteNormalizada();

      // Sem ??: um registro legado não é migrado ao ser editado.
      expect(normalizada, isNot(contains('edicaoDe?.gestacaoId ??')));
      expect(normalizada, contains('dumNoRegistro: edicaoDe?.dumNoRegistro'));
    });

    test('o snapshot temporal e a identidade andam juntos', () {
      final corpo = corpoDoMetodo('void _abrirNovaAvaliacao()');

      expect(corpo, contains('_avaliadoEm = DateTime.now();'));
      expect(corpo, contains('_dum = gestacaoAtual.dum;'));
      expect(corpo, contains('_gestacaoId = gestacaoAtual.id;'));
    });
  });

  group('VacinasScreen — registros não reconhecidos', () {
    String corpoDoBloco() => corpoDoMetodo('Widget _blocoNaoReconhecidos(');

    test('5. o código desconhecido não é associado a nenhum card', () {
      // A associação do card é por igualdade exata; um código fora do
      // calendário nunca casa com status.vacinaCodigo.
      final daVacina = corpoDoMetodo(
        'List<RegistroVacinacao> _registrosDaVacina(',
      );

      expect(daVacina, contains('r.vacinaCodigo == codigo'));
      expect(daVacina, isNot(contains('contains(')));
      expect(daVacina, isNot(contains('startsWith')));
      expect(fonte(), contains('_registrosDaVacina(status.vacinaCodigo)'));
    });

    test('6. o desconhecido é separado por regraPorCodigo, sem inferência', () {
      final corpo = corpoDoMetodo(
        'List<RegistroVacinacao> _registrosNaoReconhecidos(',
      );

      expect(corpo, contains('regraPorCodigo(r.vacinaCodigo) == null'));
      expect(corpo, contains('r.id != null'));
      // Nada de adivinhar vacina, versão ou temporada a partir do código.
      expect(corpo, isNot(contains('versaoCalendario')));
      expect(corpo, isNot(contains('startsWith')));
      expect(corpo, isNot(contains('EstadoVacina')));
    });

    test('7. _registrosDaVacina continua filtrando por igualdade exata', () {
      expect(
        fonteNormalizada(),
        contains(
          'return historico .where((r) => r.vacinaCodigo == codigo && '
          'r.id != null) .toList(growable: false);',
        ),
      );
    });

    test('8. o bloco só entra na lista quando existe órfão', () {
      final normalizada = fonteNormalizada();

      expect(
        normalizada,
        contains(
          'if (naoReconhecidos.isNotEmpty) _blocoNaoReconhecidos(context, '
          'naoReconhecidos)',
        ),
      );
      // Depois dos sete cards do calendário.
      final cards = normalizada.indexOf('...status.map((s) => _cardVacina(');
      final bloco = normalizada.indexOf('if (naoReconhecidos.isNotEmpty)');
      expect(cards, greaterThan(-1));
      expect(bloco, greaterThan(cards));
    });

    test('9. mostra o código cru, o resumo e a ação de excluir', () {
      final corpo = corpoDoBloco();

      expect(corpo, contains("'Registros não reconhecidos'"));
      expect(
        corpo,
        contains(
          'Existem registros que não fazem parte do calendário desta versão.',
        ),
      );
      expect(corpo, contains('registro.vacinaCodigo'));
      expect(corpo, contains('_resumoDoRegistro(registro)'));
      expect(corpo, contains("semanticLabel: 'Excluir'"));
    });

    test('10. o bloco não oferece editar nem registrar', () {
      final corpo = corpoDoBloco();

      expect(corpo, isNot(contains("'Editar'")));
      expect(corpo, isNot(contains('_abrirFormulario')));
      expect(corpo, isNot(contains("'Registrar'")));
      expect(corpo, isNot(contains('_nomeDaVacina')));
    });

    test('11. a exclusão reaproveita _excluirRegistro, que remove pelo id', () {
      expect(
        fonteNormalizada(),
        contains('onTap: () => _excluirRegistro(context, registro)'),
      );
      // Um único caminho de exclusão para cards e para o bloco.
      expect(
        'Future<void> _excluirRegistro('.allMatches(fonte()),
        hasLength(1),
      );
      expect(
        corpoDoMetodo('Future<void> _excluirRegistro('),
        contains('await VacinasStorage.remover(id)'),
      );
    });

    test('o texto do bloco não faz afirmação clínica', () {
      final corpo = corpoDoBloco().toLowerCase();

      for (final termo in [
        'tome',
        'precisa',
        'atrasad',
        'indicada',
        'obrigat',
        'urgente',
        'vacina recomendada',
      ]) {
        expect(corpo, isNot(contains(termo)), reason: termo);
      }
    });
  });

  group('VacinasScreen — exclusão', () {
    String corpoDaExclusao() => corpoDoMetodo('Future<void> _excluirRegistro(');

    test('existe ação de excluir, ligada ao registro daquela linha', () {
      final codigo = fonte();

      expect(codigo, contains("semanticLabel: 'Excluir'"));
      expect(codigo, contains('Icons.delete_outline_rounded'));
      expect(
        fonteNormalizada(),
        contains('onTap: () => _excluirRegistro(context, registro)'),
      );
      // Recebe o registro inteiro, não um código de vacina.
      expect(
        codigo,
        contains(
          'Future<void> _excluirRegistro(\n    BuildContext context,\n'
          '    RegistroVacinacao registro,\n  )',
        ),
      );
    });

    test('a exclusão nunca se orienta por vacinaCodigo', () {
      final corpo = corpoDaExclusao();

      expect(corpo, isNot(contains('vacinaCodigo')));
      expect(corpo, isNot(contains('firstWhere')));
      expect(corpo, isNot(contains('VacinasStorage.novoId')));
      expect(corpo, isNot(contains('VacinasStorage.adicionar')));
    });

    test('remove pelo id do próprio registro, e só se houver id', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('final id = registro.id;'));
      expect(corpo, contains('if (id == null) return;'));
      expect(corpo, contains('await VacinasStorage.remover(id)'));
      expect(corpo, contains('_registrarRemocao(id);'));
      expect(
        corpoDoMetodo('void _registrarRemocao('),
        contains('removeWhere((r) => r.id == id)'),
      );
    });

    test('há confirmação explícita em AlertDialog antes de remover', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('showDialog<void>'));
      expect(corpo, contains('AlertDialog'));
      expect(corpo, contains("'Excluir registro?'"));
      expect(
        corpo,
        contains('Esse registro será removido do seu histórico de '),
      );
      expect(corpo, contains("'Cancelar'"));
      expect(corpo, contains("'Excluir'"));

      // O storage só é tocado dentro de confirmar(), depois do diálogo abrir.
      final abre = corpo.indexOf('showDialog<bool>');
      final remove = corpo.indexOf('await VacinasStorage.remover(id)');
      expect(remove, greaterThan(abre));
    });

    test('Cancelar não chega a chamar o storage', () {
      final corpo = corpoDaExclusao();

      expect(
        fonteNormalizada(),
        contains(
          'onPressed: () => Navigator.pop(ctx), child: Text( \'Cancelar\'',
        ),
      );
      // O remover está dentro de confirmar(), que é o onPressed do Excluir.
      expect(corpo, contains('onPressed: excluindo ? null : confirmar'));
      expect(
        corpo.indexOf('Future<void> confirmar()'),
        lessThan(corpo.indexOf('await VacinasStorage.remover(id)')),
      );
    });

    test('a lista só muda depois de remover() devolver true', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('if (removeu == true)'));

      final remove = corpo.indexOf('await VacinasStorage.remover(id)');
      final tiraDaLista = corpo.indexOf('_registrarRemocao(id);');
      expect(tiraDaLista, greaterThan(remove));
      // A remoção local só existe dentro de _registrarRemocao.
      expect(
        'removeWhere((r) => r.id == id)'.allMatches(fonte()),
        hasLength(1),
      );
    });

    test('falha e recusa mantêm o histórico intacto', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('FirestoreErro.mensagemAmigavel(falha)'));
      expect(corpo, contains('excluindo = false;'));
      // O método não toca no histórico: quem mexe é _registrarRemocao, e só
      // depois de remover() devolver true.
      expect(corpo, isNot(contains('_historico =')));
      // false não é sucesso: cai no mesmo ramo do erro.
      expect(corpo, contains('sessão expirada'));
    });

    test('após o sucesso a engine reavalia pelo mecanismo existente', () {
      final corpo = corpoDaExclusao();

      expect(
        corpoDoMetodo('void _registrarRemocao('),
        contains('_abrirNovaAvaliacao();'),
      );
      expect(corpo, isNot(contains('EstadoVacina')));
      expect(corpo, isNot(contains('VacinasEngine')));
      expect(corpo, isNot(contains('podeRegistrar')));
    });

    test('impede confirmar duas vezes e fechar no meio da exclusão', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('if (excluindo) return;'));
      expect(corpo, contains('excluindo = true;'));
      expect(corpo, contains('if (_excluindoId != null) return;'));
      expect(corpo, isNot(contains('canPop')));
    });

    test('as três ações coexistem, cada uma no seu ponto', () {
      final codigo = fonte();

      expect(codigo, contains("'Registrar'"));
      expect(codigo, contains("'Editar'"));
      expect(codigo, contains("semanticLabel: 'Excluir'"));
      expect('Future<void> _excluirRegistro('.allMatches(codigo), hasLength(1));
      expect('Future<void> _abrirFormulario('.allMatches(codigo), hasLength(1));
      expect('VacinasEngine.avaliar('.allMatches(codigo), hasLength(1));
    });
  });

  group('C1 — sem gestação informada a tela não avalia nem grava', () {
    Future<void> montarSemGestacao(WidgetTester tester) async {
      encerrarGestacao();
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('mostra o convite para informar a gestação', (tester) async {
      await montarSemGestacao(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(mensagemSemGestacaoConfigurada), findsOneWidget);
      expect(
        mensagemSemGestacaoConfigurada,
        'Informe a data da sua gestação para ver o calendário de vacinas.',
      );
    });

    testWidgets('nenhum card de vacina é avaliado', (tester) async {
      await montarSemGestacao(tester);

      for (final regra in calendarioPni2026) {
        expect(
          find.text(regra.nomeExibicao),
          findsNothing,
          reason: regra.codigo,
        );
      }
    });

    testWidgets('não oferece o painel de erro nem retry', (tester) async {
      await montarSemGestacao(tester);

      expect(
        find.text('Não foi possível carregar seus registros'),
        findsNothing,
      );
      expect(find.text('Tentar novamente'), findsNothing);
    });

    test('o formulário recusa abrir sem gestação informada', () {
      final codigo = linhasDeCodigo().join('\n');
      final inicio = codigo.indexOf('Future<void> _abrirFormulario(');
      final corpo = codigo.substring(inicio, codigo.indexOf('\n  }\n', inicio));

      expect(corpo, contains('if (_semGestacao) return;'));
    });

    test('a decisão vem de gestacaoAtual.configurada', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(
        codigo,
        contains('final bool _semGestacao = !gestacaoAtual.configurada;'),
      );
      expect(codigo, contains('if (_semGestacao) return _painelSemGestacao'));
    });

    test('a avaliação só acontece depois da checagem', () {
      final codigo = linhasDeCodigo().join('\n');
      final inicio = codigo.indexOf('Widget _conteudo(BuildContext context)');
      final corpo = codigo.substring(inicio, codigo.indexOf('\n  }\n', inicio));

      final checagem = corpo.indexOf('if (_semGestacao)');
      final avaliacao = corpo.indexOf('_avaliar()');

      expect(checagem, greaterThan(-1));
      expect(avaliacao, greaterThan(checagem));
    });
  });

  group('C1 — regressão: com gestação informada nada muda', () {
    testWidgets('a falha de leitura continua mostrando o painel de erro', (
      tester,
    ) async {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-de-teste');

      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível carregar seus registros'),
        findsOneWidget,
      );
      expect(find.text(mensagemSemGestacaoConfigurada), findsNothing);
    });
  });
}
