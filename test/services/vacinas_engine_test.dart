import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';
import 'package:suacontracao_ai/models/registro_vacinacao.dart';
import 'package:suacontracao_ai/services/vacinas_engine.dart';

void main() {
  // DUM fixa e data corrente derivada dela: nenhum teste depende do
  // relógio da máquina.
  final dum = DateTime(2026, 1, 5);

  DateTime dataNaSemana(int semana) => dum.add(Duration(days: semana * 7));

  List<StatusVacinacao> avaliarEm({
    required int diasGestacaoBruto,
    List<RegistroVacinacao> historico = const [],
    DateTime? dataAtual,
    String? temporadaInfluenza,
  }) {
    return VacinasEngine.avaliar(
      diasGestacaoBruto: diasGestacaoBruto,
      dum: dum,
      dataAtual: dataAtual ?? dum.add(Duration(days: diasGestacaoBruto)),
      historico: historico,
      calendario: calendarioPni2026,
      temporadaInfluenza: temporadaInfluenza,
    );
  }

  StatusVacinacao statusDe(List<StatusVacinacao> todos, String codigo) =>
      todos.firstWhere((s) => s.vacinaCodigo == codigo);

  RegistroVacinacao doseRegistrada(
    String codigo, {
    DateTime? dumNoRegistro,
    SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
  }) {
    return RegistroVacinacao(
      vacinaCodigo: codigo,
      situacaoInformada: situacao,
      versaoCalendario: versaoCalendarioPni2026,
      dataAplicacao: DateTime(2026, 6, 1),
      dumNoRegistro: dumNoRegistro,
    );
  }

  group('Saída da engine', () {
    test('devolve um status para cada regra do calendário', () {
      final resultado = avaliarEm(diasGestacaoBruto: 140);

      expect(resultado, hasLength(calendarioPni2026.length));
      expect(
        resultado.map((s) => s.vacinaCodigo).toSet(),
        calendarioPni2026.map((r) => r.codigo).toSet(),
      );
    });

    test('os sete estados têm códigos estáveis e distintos', () {
      expect(EstadoVacina.values, hasLength(7));
      expect(EstadoVacina.naoDisponivel.codigo, 'NAO_DISPONIVEL');
      expect(EstadoVacina.periodoRecomendado.codigo, 'PERIODO_RECOMENDADO');
      expect(EstadoVacina.verificarHistorico.codigo, 'VERIFICAR_HISTORICO');
      expect(EstadoVacina.aguardarIntervalo.codigo, 'AGUARDAR_INTERVALO');
      expect(EstadoVacina.registrada.codigo, 'REGISTRADA');
      expect(EstadoVacina.avaliacaoProfissional.codigo, 'AVALIACAO_PROFISSIONAL');
      expect(EstadoVacina.naoIndicada.codigo, 'NAO_INDICADA');

      final codigos = EstadoVacina.values.map((e) => e.codigo).toSet();
      expect(codigos.length, EstadoVacina.values.length);
    });

    test('todo estado tem um nível de atenção definido', () {
      for (final estado in EstadoVacina.values) {
        expect(nivelDoEstado(estado), isNotNull, reason: estado.codigo);
      }
    });

    test('nenhuma mensagem usa linguagem prescritiva', () {
      const proibidos = ['tome agora', 'você precisa tomar', 'você está atrasada'];

      final mensagens = [
        for (final dias in [0, 139, 140, 195, 196, 294])
          ...avaliarEm(diasGestacaoBruto: dias).map((s) => s.mensagem),
        ...avaliarEm(diasGestacaoBruto: -10).map((s) => s.mensagem),
      ];

      for (final mensagem in mensagens) {
        for (final termo in proibidos) {
          expect(mensagem.toLowerCase(), isNot(contains(termo)), reason: termo);
        }
      }
    });

    test('mensagem de dose registrada não afirma validação', () {
      expect(mensagemDoseRegistrada, 'Registrada por você.');
      expect(mensagemDoseRegistrada.toLowerCase(), isNot(contains('validad')));
    });
  });

  group('dTpa — janela a partir da 20ª semana', () {
    test('19 semanas: não disponível', () {
      // 139 dias = 19 semanas e 6 dias, a borda de dentro.
      final dtpa = statusDe(avaliarEm(diasGestacaoBruto: 139), codigoDtpa);

      expect(dtpa.estado, EstadoVacina.naoDisponivel);
      expect(dtpa.nivelAtencao, NivelAtencao.nenhum);
    });

    test('exatamente 20 semanas: período recomendado', () {
      final dtpa = statusDe(avaliarEm(diasGestacaoBruto: 140), codigoDtpa);

      expect(dtpa.estado, EstadoVacina.periodoRecomendado);
      expect(dtpa.mensagem, mensagemPeriodoRecomendado);
      expect(dtpa.nivelAtencao, NivelAtencao.atencao);
      expect(dtpa.podeRegistrar, isTrue);
    });

    test('antes da janela informa quando ela abre', () {
      final dtpa = statusDe(avaliarEm(diasGestacaoBruto: 139), codigoDtpa);

      expect(dtpa.proximaJanela, isNotNull);
      expect(dtpa.proximaJanela!.semanaGestacional, 20);
      expect(dtpa.proximaJanela!.dataEstimada, dataNaSemana(20));
    });

    test('dentro da janela não anuncia próxima janela', () {
      final dtpa = statusDe(avaliarEm(diasGestacaoBruto: 140), codigoDtpa);
      expect(dtpa.proximaJanela, isNull);
    });
  });

  group('VSR — janela a partir da 28ª semana', () {
    test('27 semanas: não disponível', () {
      final vsr = statusDe(avaliarEm(diasGestacaoBruto: 195), codigoVsr);

      expect(vsr.estado, EstadoVacina.naoDisponivel);
      expect(vsr.proximaJanela!.semanaGestacional, 28);
    });

    test('exatamente 28 semanas: período recomendado', () {
      final vsr = statusDe(avaliarEm(diasGestacaoBruto: 196), codigoVsr);

      expect(vsr.estado, EstadoVacina.periodoRecomendado);
      expect(vsr.mensagem, mensagemPeriodoRecomendado);
    });

    test('na 20ª semana a dTpa abre mas a VSR ainda não', () {
      final resultado = avaliarEm(diasGestacaoBruto: 140);

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.periodoRecomendado);
      expect(statusDe(resultado, codigoVsr).estado, EstadoVacina.naoDisponivel);
    });
  });

  group('Dose já registrada nesta gestação', () {
    test('dTpa registrada: estado REGISTRADA', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [doseRegistrada(codigoDtpa, dumNoRegistro: dum)],
      );

      final dtpa = statusDe(resultado, codigoDtpa);
      expect(dtpa.estado, EstadoVacina.registrada);
      expect(dtpa.mensagem, mensagemDoseRegistrada);
      expect(dtpa.podeRegistrar, isFalse);
    });

    test('VSR registrada: estado REGISTRADA', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [doseRegistrada(codigoVsr, dumNoRegistro: dum)],
      );

      expect(statusDe(resultado, codigoVsr).estado, EstadoVacina.registrada);
    });

    test('registro de uma vacina não afeta a outra', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [doseRegistrada(codigoDtpa, dumNoRegistro: dum)],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.registrada);
      expect(statusDe(resultado, codigoVsr).estado, EstadoVacina.periodoRecomendado);
    });

    test('dose aplicada com data desconhecida também conta como registrada', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoDtpa,
            dumNoRegistro: dum,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.registrada);
    });

    test('registro sem vínculo com esta gestação não vira REGISTRADA', () {
      // Sem dumNoRegistro não há como afirmar que a dose é desta gestação.
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [doseRegistrada(codigoDtpa)],
      );

      expect(statusDe(resultado, codigoDtpa).estado, isNot(EstadoVacina.registrada));
    });

    test('registro de outra gestação não vira REGISTRADA', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(codigoDtpa, dumNoRegistro: DateTime(2024, 3, 10)),
        ],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.periodoRecomendado);
    });

    test('registrada permanece registrada mesmo com gestação indeterminada', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: -30,
        historico: [doseRegistrada(codigoDtpa, dumNoRegistro: dum)],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.registrada);
    });
  });

  group('Vínculo com a gestação — registro sem DUM não pertence a ela', () {
    test('(a) dTpa: situação desconhecida sem DUM não bloqueia a janela', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoDtpa,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      final dtpa = statusDe(resultado, codigoDtpa);
      // Sem vínculo, o registro não diz nada sobre esta gestação: nem prova
      // aplicação, nem trava a janela em VERIFICAR_HISTORICO.
      expect(dtpa.estado, EstadoVacina.periodoRecomendado);
      expect(dtpa.estado, isNot(EstadoVacina.registrada));
    });

    test('(b) VSR: situação desconhecida sem DUM não bloqueia a janela', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoVsr,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(statusDe(resultado, codigoVsr).estado, EstadoVacina.periodoRecomendado);
    });

    test('(c) registro de outra gestação não interfere na atual', () {
      final outraDum = DateTime(2024, 3, 10);

      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(codigoDtpa, dumNoRegistro: outraDum),
          doseRegistrada(
            codigoVsr,
            dumNoRegistro: outraDum,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.periodoRecomendado);
      expect(statusDe(resultado, codigoVsr).estado, EstadoVacina.periodoRecomendado);
    });

    test('situação desconhecida COM vínculo continua bloqueando', () {
      // O contraste que prova que o critério é o vínculo, não a situação.
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoDtpa,
            dumNoRegistro: dum,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.verificarHistorico);
    });

    test('dose aplicada sem vínculo não conta como registrada nesta gestação', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [doseRegistrada(codigoDtpa)],
      );

      expect(statusDe(resultado, codigoDtpa).estado, isNot(EstadoVacina.registrada));
    });
  });

  group('dosesPorGestacao — a engine lê o valor declarado pela regra', () {
    // Calendário sintético, só para provar o contrato estrutural: nenhuma
    // regra clínica nova entra no PNI-2026 por causa deste teste.
    const codigoFicticio = 'REGRA_DE_TESTE';

    List<RegraCalendario> calendarioCom({required int? dosesPorGestacao}) {
      return [
        RegraJanelaSemana(
          codigo: codigoFicticio,
          nomeExibicao: 'Regra de teste',
          versaoCalendario: versaoCalendarioPni2026,
          semanaInicial: 20,
          dosesPorGestacao: dosesPorGestacao,
        ),
      ];
    }

    List<StatusVacinacao> avaliarCom({
      required int? dosesPorGestacao,
      required int quantasDosesRegistradas,
    }) {
      return VacinasEngine.avaliar(
        diasGestacaoBruto: 200,
        dum: dum,
        dataAtual: dum.add(const Duration(days: 200)),
        historico: List.generate(
          quantasDosesRegistradas,
          (_) => doseRegistrada(codigoFicticio, dumNoRegistro: dum),
        ),
        calendario: calendarioCom(dosesPorGestacao: dosesPorGestacao),
      );
    }

    test('regra de 2 doses: uma dose registrada ainda não encerra', () {
      final status = avaliarCom(dosesPorGestacao: 2, quantasDosesRegistradas: 1);

      expect(status.single.estado, EstadoVacina.periodoRecomendado);
      expect(status.single.estado, isNot(EstadoVacina.registrada));
    });

    test('regra de 2 doses: duas doses registradas encerram', () {
      final status = avaliarCom(dosesPorGestacao: 2, quantasDosesRegistradas: 2);

      expect(status.single.estado, EstadoVacina.registrada);
      expect(status.single.podeRegistrar, isFalse);
    });

    test('regra de 3 doses: duas registradas ainda não encerram', () {
      final status = avaliarCom(dosesPorGestacao: 3, quantasDosesRegistradas: 2);
      expect(status.single.estado, EstadoVacina.periodoRecomendado);
    });

    test('regra de 1 dose: uma registrada encerra, como dTpa e VSR', () {
      final status = avaliarCom(dosesPorGestacao: 1, quantasDosesRegistradas: 1);
      expect(status.single.estado, EstadoVacina.registrada);
    });

    test('sem doses por gestação declaradas, a engine não presume nenhum valor', () {
      final status = avaliarCom(dosesPorGestacao: null, quantasDosesRegistradas: 1);

      expect(status.single.estado, EstadoVacina.verificarHistorico);
      expect(status.single.estado, isNot(EstadoVacina.registrada));
      expect(status.single.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('o motivo cita o previsto pela regra, não um número fixo', () {
      final status = avaliarCom(dosesPorGestacao: 2, quantasDosesRegistradas: 2);
      expect(status.single.motivo, contains('2'));
    });
  });

  group('Histórico desconhecido não é "não aplicada"', () {
    test('registro com situação desconhecida leva a VERIFICAR_HISTORICO', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoDtpa,
            dumNoRegistro: dum,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      final dtpa = statusDe(resultado, codigoDtpa);
      expect(dtpa.estado, EstadoVacina.verificarHistorico);
      // Nem tratada como aplicada, nem como ausente.
      expect(dtpa.estado, isNot(EstadoVacina.registrada));
      expect(dtpa.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('quem informou que não recebeu entra no período normalmente', () {
      final resultado = avaliarEm(
        diasGestacaoBruto: 200,
        historico: [
          doseRegistrada(
            codigoDtpa,
            dumNoRegistro: dum,
            situacao: SituacaoInformada.naoAplicadaInformado,
          ),
        ],
      );

      expect(statusDe(resultado, codigoDtpa).estado, EstadoVacina.periodoRecomendado);
    });

    test('ausência de histórico não é lida como dose não realizada', () {
      final semHistorico = statusDe(avaliarEm(diasGestacaoBruto: 200), codigoDtpa);

      // O estado é o mesmo do período aberto, e a mensagem não afirma que
      // ela deixou de tomar: apenas que o período começou.
      expect(semHistorico.estado, EstadoVacina.periodoRecomendado);
      expect(semHistorico.mensagem, mensagemPeriodoRecomendado);
      expect(semHistorico.mensagem.toLowerCase(), isNot(contains('não tomou')));
      expect(semHistorico.mensagem.toLowerCase(), isNot(contains('pendente')));
    });
  });

  group('Idade gestacional fora de faixa plausível', () {
    test('DUM no futuro nunca recomenda automaticamente', () {
      final resultado = avaliarEm(diasGestacaoBruto: -1);

      for (final codigo in [codigoDtpa, codigoVsr]) {
        final status = statusDe(resultado, codigo);
        expect(status.estado, isNot(EstadoVacina.periodoRecomendado), reason: codigo);
        expect(status.estado, EstadoVacina.avaliacaoProfissional, reason: codigo);
      }
    });

    test('gestação muito além do termo nunca recomenda automaticamente', () {
      final resultado = avaliarEm(diasGestacaoBruto: 400);

      for (final codigo in [codigoDtpa, codigoVsr]) {
        expect(
          statusDe(resultado, codigo).estado,
          isNot(EstadoVacina.periodoRecomendado),
          reason: codigo,
        );
      }
    });

    test('as bordas da faixa plausível são interpretadas', () {
      expect(gestacaoPlausivel(diasGestacaoMinimoPlausivel), isTrue);
      expect(gestacaoPlausivel(diasGestacaoMaximoPlausivel), isTrue);
      expect(gestacaoPlausivel(diasGestacaoMinimoPlausivel - 1), isFalse);
      expect(gestacaoPlausivel(diasGestacaoMaximoPlausivel + 1), isFalse);
    });

    test('a semana não é clampeada como em GestacaoInfo', () {
      // GestacaoInfo.semanaAtual devolveria 1 e 42 nestes casos, escondendo
      // justamente o que a engine precisa enxergar.
      expect(semanaGestacionalDe(0), 0);
      expect(semanaGestacionalDe(139), 19);
      expect(semanaGestacionalDe(140), 20);
      expect(semanaGestacionalDe(400), 57);
    });
  });

  group('Febre amarela — nunca vira janela automática', () {
    test('é sempre avaliação profissional, em qualquer semana', () {
      for (final dias in [0, 100, 140, 196, 250, 294]) {
        final status = statusDe(avaliarEm(diasGestacaoBruto: dias), codigoFebreAmarela);

        expect(status.estado, EstadoVacina.avaliacaoProfissional, reason: '$dias dias');
        expect(status.estado, isNot(EstadoVacina.periodoRecomendado), reason: '$dias dias');
        expect(status.proximaJanela, isNull, reason: '$dias dias');
      }
    });

    test('não muda com histórico nem com gestação indeterminada', () {
      final comRegistro = avaliarEm(
        diasGestacaoBruto: -50,
        historico: [doseRegistrada(codigoFebreAmarela, dumNoRegistro: dum)],
      );

      expect(
        statusDe(comRegistro, codigoFebreAmarela).estado,
        EstadoVacina.avaliacaoProfissional,
      );
    });

    test('avaliar a regra isolada não lança em nenhuma condição', () {
      final febreAmarela = regraPorCodigo(codigoFebreAmarela)!;

      // Não existe caminho de exceção para esta regra: nem sem histórico,
      // nem com registro, nem com gestação absurda.
      for (final dias in [-500, -1, 0, 140, 294, 1000]) {
        expect(
          () => VacinasEngine.avaliar(
            diasGestacaoBruto: dias,
            dum: dum,
            dataAtual: dum,
            historico: [
              doseRegistrada(codigoFebreAmarela, dumNoRegistro: dum),
              doseRegistrada(codigoFebreAmarela),
            ],
            calendario: [febreAmarela],
          ),
          returnsNormally,
          reason: '$dias dias',
        );
      }
    });
  });

  group('Condicionais ainda não avaliadas (Etapa 3C)', () {
    test('não afirmam período recomendado', () {
      final resultado = avaliarEm(diasGestacaoBruto: 200);

      for (final codigo in [codigoHepatiteB, codigoDt, codigoInfluenza, codigoCovid19]) {
        final status = statusDe(resultado, codigo);
        expect(status.estado, EstadoVacina.verificarHistorico, reason: codigo);
        expect(status.estado, isNot(EstadoVacina.periodoRecomendado), reason: codigo);
      }
    });

    test('influenza sem temporada informada não é avaliada por conta própria', () {
      final semTemporada = statusDe(
        avaliarEm(diasGestacaoBruto: 200),
        codigoInfluenza,
      );

      expect(semTemporada.estado, EstadoVacina.verificarHistorico);
      expect(semTemporada.estado, isNot(EstadoVacina.periodoRecomendado));
    });
  });

  group('Determinismo', () {
    test('mesmas entradas produzem exatamente o mesmo resultado', () {
      final historico = [doseRegistrada(codigoDtpa, dumNoRegistro: dum)];

      final primeira = avaliarEm(diasGestacaoBruto: 200, historico: historico);
      final segunda = avaliarEm(diasGestacaoBruto: 200, historico: historico);

      expect(primeira.length, segunda.length);
      for (var i = 0; i < primeira.length; i++) {
        expect(primeira[i].vacinaCodigo, segunda[i].vacinaCodigo);
        expect(primeira[i].estado, segunda[i].estado);
        expect(primeira[i].mensagem, segunda[i].mensagem);
        expect(primeira[i].nivelAtencao, segunda[i].nivelAtencao);
        expect(primeira[i].proximaJanela, segunda[i].proximaJanela);
        expect(primeira[i].podeRegistrar, segunda[i].podeRegistrar);
        expect(primeira[i].motivo, segunda[i].motivo);
      }
    });

    test('a data atual injetada não altera a janela: quem manda é a gestação', () {
      // Duas datas correntes diferentes, mesmos dias de gestação: mesmo
      // resultado. A engine não consulta o relógio para decidir a janela.
      final comUmaData = avaliarEm(
        diasGestacaoBruto: 140,
        dataAtual: DateTime(2026, 5, 25),
      );
      final comOutraData = avaliarEm(
        diasGestacaoBruto: 140,
        dataAtual: DateTime(2030, 12, 31),
      );

      expect(
        comUmaData.map((s) => s.estado).toList(),
        comOutraData.map((s) => s.estado).toList(),
      );
    });

    test('a ordem de saída acompanha a ordem do calendário', () {
      final resultado = avaliarEm(diasGestacaoBruto: 140);

      expect(
        resultado.map((s) => s.vacinaCodigo).toList(),
        calendarioPni2026.map((r) => r.codigo).toList(),
      );
    });
  });

  group('Pureza', () {
    // Só o código executável interessa: a documentação da engine cita
    // "DateTime.now()" e "BuildContext" justamente para dizer que não os
    // usa, e uma busca no arquivo inteiro acusaria esses comentários.
    List<String> linhasDeCodigo() {
      return File('lib/services/vacinas_engine.dart')
          .readAsLinesSync()
          .where((linha) => !linha.trimLeft().startsWith('//'))
          .toList();
    }

    test('o código-fonte da engine não chama DateTime.now()', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo.contains('DateTime.now()'), isFalse,
          reason: 'a data corrente deve ser sempre injetada');
    });

    test('a engine não importa Flutter nem Firebase', () {
      final imports = linhasDeCodigo()
          .where((linha) => linha.trimLeft().startsWith('import '))
          .toList();

      expect(imports, isNotEmpty, reason: 'sanidade: o arquivo tem imports');

      for (final linha in imports) {
        expect(linha, isNot(contains('package:flutter/')), reason: linha);
        expect(linha, isNot(contains('cloud_firestore')), reason: linha);
        expect(linha, isNot(contains('firebase_auth')), reason: linha);
        expect(linha, isNot(contains('firebase_core')), reason: linha);
      }
    });

    test('a engine não menciona BuildContext no código', () {
      final codigo = linhasDeCodigo().join('\n');
      expect(codigo.contains('BuildContext'), isFalse);
    });
  });
}
