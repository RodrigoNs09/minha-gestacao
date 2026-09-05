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

    final fim = codigo.indexOf('\n  }', inicio);
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
      expect(codigo, contains('temporadaInfluenza: null'));
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

      // Duas chamadas: uma ao carregar, outra depois de gravar com sucesso.
      expect('_abrirNovaAvaliacao();'.allMatches(codigo), hasLength(2));
      expect(codigo, contains('_historico = registros;\n        _abrirNovaAvaliacao();'));

      final atualiza = codigo.indexOf('_historico = [...?_historico, salvo];');
      final renova = codigo.indexOf('_abrirNovaAvaliacao();', atualiza);

      expect(atualiza, greaterThan(-1));
      expect(renova, greaterThan(atualiza));
      // Só se salvou: um cancelamento não abre avaliação nova.
      expect(codigo.substring(atualiza, renova), isNot(contains('}')));
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
    test('o cadastro abre em bottom sheet, no padrão do app', () {
      final codigo = fonte();

      expect('showModalBottomSheet'.allMatches(codigo), hasLength(1));
      expect(codigo, contains('showDatePicker'));
    });

    test('grava pelo storage e não remove nada nesta etapa', () {
      final codigo = fonte();

      expect('VacinasStorage.adicionar('.allMatches(codigo), hasLength(1));
      expect('VacinasStorage.novoId()'.allMatches(codigo), hasLength(1));
      expect('VacinasStorage.carregarRegistros('.allMatches(codigo),
          hasLength(1));
      expect(codigo, isNot(contains('VacinasStorage.remover')));
      // \b evita casar dentro de isDismissible, que é parâmetro do sheet.
      expect(codigo, isNot(matches(RegExp(r'\bDismissible'))));
    });

    test('o id pendente é criado ao abrir e só é limpo depois do sheet', () {
      final codigo = fonte();

      final gera = codigo.indexOf('_idPendente = VacinasStorage.novoId();');
      final abre = codigo.indexOf('await showModalBottomSheet<RegistroVacinacao>');
      final limpa = codigo.indexOf('_idPendente = null;');

      expect(gera, greaterThan(-1));
      expect(abre, greaterThan(gera));
      // A limpeza vem depois do sheet fechar: uma falha mantém o mesmo id.
      expect(limpa, greaterThan(abre));
      expect('_idPendente = null;'.allMatches(codigo), hasLength(1));
      expect(codigo, contains('id: _idPendente'));
    });

    test('o registro leva os campos aprovados e nada além', () {
      final codigo = fonte();

      expect(codigo, contains('vacinaCodigo: vacinaCodigo'));
      expect(codigo, contains('versaoCalendario: versaoCalendarioPni2026'));
      expect(codigo, contains('origemRegistro: OrigemRegistro.registradoPelaUsuaria'));
      expect(codigo, contains('dumNoRegistro: gestacaoAtual.dum'));
      expect(codigo, contains('temporadaNoRegistro: null'));
      expect(codigo, contains('criadoEm: DateTime.now()'));
      expect(codigo, isNot(contains("versaoCalendario: '")));
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
      final atualiza = codigo.indexOf('_historico = [...?_historico, salvo]');

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
      expect('Navigator.pop(ctx'.allMatches(codigo), hasLength(2));
    });

    test('nesta etapa não há edição', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('.comId(')));
      expect(codigo, isNot(contains('_abrirEdicao')));
      expect(codigo, isNot(contains('onLongPress')));
    });
  });
}
