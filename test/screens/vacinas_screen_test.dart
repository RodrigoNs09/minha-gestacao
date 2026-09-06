import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';
import 'package:suacontracao_ai/screens/vacinas_screen.dart';

void main() {
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
    testWidgets('não quebra e mostra o painel de erro com retry', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Não foi possível carregar seus registros'), findsOneWidget);
      expect(find.text('Tentar novamente'), findsOneWidget);
    });

    testWidgets('nenhum card de vacina é exibido quando a leitura falha',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      for (final regra in calendarioPni2026) {
        expect(find.text(regra.nomeExibicao), findsNothing,
            reason: regra.codigo);
      }
    });

    testWidgets('nenhuma mensagem da engine aparece quando a leitura falha',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text(mensagemPeriodoRecomendado), findsNothing);
      expect(find.text(mensagemGeralVacinas), findsNothing);
    });

    testWidgets('nenhuma ação de registro aparece quando a leitura falha',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Registrar'), findsNothing);
      expect(find.text('Registrar vacinação'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Editar registro'), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('Excluir registro?'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('o cabeçalho continua visível no estado de erro', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: VacinasScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Vacinas da Gestação'), findsOneWidget);
      expect(find.text('Calendário e seus registros'), findsOneWidget);
      expect(find.text('Voltar'), findsOneWidget);
    });

    testWidgets('mostra indicador de carregamento antes de concluir',
        (tester) async {
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
      expect(codigo, contains('avaliadoEm.difference(dum).inDays'));

      // O instante é lido uma única vez por avaliação, e nunca dentro dela.
      final abertura = corpoDoMetodo('void _abrirNovaAvaliacao()');
      expect('DateTime.now()'.allMatches(abertura), hasLength(1));
      expect(abertura, contains('_avaliadoEm = DateTime.now();'));
      expect(abertura, contains('_dum = gestacaoAtual.dum;'));

      expect(corpoDoMetodo('List<StatusVacinacao> _avaliar()'),
          isNot(contains('DateTime.now()')));
      expect(corpoDoMetodo('Future<void> _carregar()'),
          isNot(contains('DateTime.now()')));
    });

    test('o relógio da tela não fica congelado após um salvamento', () {
      final codigo = fonte();

      // Três chamadas: ao carregar, ao gravar e ao excluir com sucesso.
      expect('_abrirNovaAvaliacao();'.allMatches(codigo), hasLength(3));
      expect(
        codigo,
        contains('_historico = registros;\n        _abrirNovaAvaliacao();'),
      );

      // A renovação fica dentro do if do salvamento; a limpeza do id, fora.
      expect(
        fonteNormalizada(),
        contains('_historico = lista; _abrirNovaAvaliacao(); } _idPendente = null;'),
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
      expect(codigo,
          isNot(matches(RegExp(r'\bColors\.(?!white|transparent)'))));
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

      final gera =
          codigo.indexOf('_idPendente = edicaoDe?.id ?? VacinasStorage.novoId();');
      final abre = codigo.indexOf('await showModalBottomSheet<RegistroVacinacao>');
      final limpa = codigo.indexOf('_idPendente = null;');

      expect(gera, greaterThan(-1));
      expect(abre, greaterThan(gera));
      // A limpeza vem depois do sheet fechar: uma falha mantém o mesmo id.
      expect(limpa, greaterThan(abre));
      expect('_idPendente = null;'.allMatches(codigo), hasLength(1));
      expect(codigo, contains('id: _idPendente'));
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

    test('o número da dose vem do tipo da regra, sem código fixo', () {
      final codigo = fonte();

      expect(codigo, contains('regraPorCodigo(vacinaCodigo) is RegraDependeHistorico'));

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

    test('as quatro situações do modelo são oferecidas, sem inventar rótulo',
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
    });

    test('só a situação com data envia dataAplicacao', () {
      expect(
        fonte(),
        contains(
            'dataAplicacao: situacao == SituacaoInformada.aplicadaComData'),
      );
    });

    test('a data da aplicação não pode ser futura', () {
      final codigo = fonte();

      expect(codigo, contains('lastDate: hoje'));
      expect(codigo, isNot(contains('lastDate: DateTime(2')));
    });

    test('a lista só muda depois da confirmação do servidor', () {
      final codigo = fonte();

      final grava = codigo.indexOf('await VacinasStorage.adicionar(registro)');
      final atualiza = codigo.indexOf('_historico = lista;');

      expect(grava, greaterThan(-1));
      expect(atualiza, greaterThan(grava));
      expect(codigo, contains('if (gravado != null)'));
      expect(codigo, contains('if (salvo != null)'));
    });

    test('há proteção contra clique duplo durante o salvamento', () {
      final codigo = fonte();

      expect(codigo, contains('if (salvando || !podeSalvar) return;'));
      expect(codigo, contains('salvando = true'));
      expect(
        fonteNormalizada(),
        contains('onPressed: (salvando || !podeSalvar) ? null : salvar'),
      );
      // O sheet também não pode ser fechado no meio de uma gravação.
      expect(codigo, contains('canPop: !salvando'));
    });

    test('a falha mostra a mensagem do FirestoreErro e mantém o formulário',
        () {
      final codigo = fonte();

      expect(codigo, contains('FirestoreErro.mensagemAmigavel(falha)'));
      expect(codigo, contains('salvando = false'));
      // Nenhum pop no caminho de erro: o sheet fica aberto para nova tentativa.
      // Os dois do formulário são o Cancelar e o sucesso da gravação.
      expect(
        'Navigator.pop(ctx'
            .allMatches(corpoDoMetodo('Future<void> _abrirFormulario(')),
        hasLength(2),
      );
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
      expect(
        normalizada,
        isNot(contains('edicaoDe?.temporadaNoRegistro ??')),
      );
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

      expect(codigo, contains('lista.indexWhere((r) => r.id == salvo.id)'));
      expect(codigo, contains('lista[indice] = salvo;'));
      expect(codigo, contains('lista.add(salvo);'));

      final grava = codigo.indexOf('await VacinasStorage.adicionar(registro)');
      final atualiza = codigo.indexOf('lista[indice] = salvo;');
      expect(atualiza, greaterThan(grava));
    });

    test('só registros com id podem ser editados', () {
      expect(
        corpoDoMetodo('List<RegistroVacinacao> _registrosDaVacina('),
        contains('r.id != null'),
      );
    });
  });

  group('VacinasScreen — exclusão', () {
    String corpoDaExclusao() =>
        corpoDoMetodo('Future<void> _excluirRegistro(');

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
        contains('Future<void> _excluirRegistro(\n    BuildContext context,\n'
            '    RegistroVacinacao registro,\n  )'),
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
      expect(corpo, contains('removeWhere((r) => r.id == id)'));
    });

    test('há confirmação explícita em AlertDialog antes de remover', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('showDialog<bool>'));
      expect(corpo, contains('AlertDialog'));
      expect(corpo, contains("'Excluir registro?'"));
      expect(
        corpo,
        contains(
          'Esse registro será removido do seu histórico de ',
        ),
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
        contains('onPressed: excluindo ? null : () => Navigator.pop(ctx, false)'),
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
      expect(corpo, contains('if (!mounted || confirmado != true) return;'));

      final remove = corpo.indexOf('await VacinasStorage.remover(id)');
      final tiraDaLista = corpo.indexOf('removeWhere((r) => r.id == id)');
      expect(tiraDaLista, greaterThan(remove));
    });

    test('falha e recusa mantêm o histórico intacto', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('FirestoreErro.mensagemAmigavel(falha)'));
      expect(corpo, contains('excluindo = false;'));
      // Um único ponto que mexe no histórico, e ele exige a confirmação.
      expect('_historico ='.allMatches(corpo), hasLength(1));
      // false não é sucesso: cai no mesmo ramo do erro.
      expect(corpo, contains('sessão expirada'));
    });

    test('após o sucesso a engine reavalia pelo mecanismo existente', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('_abrirNovaAvaliacao();'));
      expect(corpo, isNot(contains('EstadoVacina')));
      expect(corpo, isNot(contains('VacinasEngine')));
      expect(corpo, isNot(contains('podeRegistrar')));
    });

    test('impede confirmar duas vezes e fechar no meio da exclusão', () {
      final corpo = corpoDaExclusao();

      expect(corpo, contains('if (excluindo) return;'));
      expect(corpo, contains('excluindo = true;'));
      expect(corpo, contains('canPop: !excluindo'));
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
}
