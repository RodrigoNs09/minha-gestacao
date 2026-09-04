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

  group('adicionarMeses — aritmética de calendário', () {
    test('mês com o mesmo dia', () {
      expect(adicionarMeses(DateTime(2026, 1, 15), 6), DateTime(2026, 7, 15));
    });

    test('vira o ano corretamente', () {
      expect(adicionarMeses(DateTime(2026, 8, 10), 6), DateTime(2027, 2, 10));
      expect(adicionarMeses(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 31));
    });

    test('31/08 + 6 meses cai no último dia de fevereiro, não em março', () {
      expect(adicionarMeses(DateTime(2026, 8, 31), 6), DateTime(2027, 2, 28));
      expect(adicionarMeses(DateTime(2026, 8, 31), 6), isNot(DateTime(2027, 3, 3)));
    });

    test('respeita ano bissexto', () {
      // 2028 é bissexto: 29 dias em fevereiro.
      expect(adicionarMeses(DateTime(2027, 8, 31), 6), DateTime(2028, 2, 29));
      expect(adicionarMeses(DateTime(2028, 2, 29), 12), DateTime(2029, 2, 28));
    });

    test('31/03 + 1 mês cai em 30/04', () {
      expect(adicionarMeses(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
    });

    test('não equivale a somar 180 dias', () {
      final origem = DateTime(2026, 1, 1);
      expect(
        adicionarMeses(origem, 6),
        isNot(origem.add(const Duration(days: 180))),
      );
    });
  });

  group('COVID-19 — 1 dose por gestação e intervalo de 6 meses', () {
    StatusVacinacao covidEm({
      required int diasGestacaoBruto,
      List<RegistroVacinacao> historico = const [],
      DateTime? dataAtual,
    }) {
      return statusDe(
        avaliarEm(
          diasGestacaoBruto: diasGestacaoBruto,
          historico: historico,
          dataAtual: dataAtual,
        ),
        codigoCovid19,
      );
    }

    RegistroVacinacao doseCovid({
      required DateTime? dataAplicacao,
      DateTime? dumNoRegistro,
      SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
    }) {
      return RegistroVacinacao(
        vacinaCodigo: codigoCovid19,
        situacaoInformada: situacao,
        versaoCalendario: versaoCalendarioPni2026,
        dataAplicacao: dataAplicacao,
        dumNoRegistro: dumNoRegistro,
      );
    }

    test('1. sem histórico e sem dose nesta gestação: período recomendado', () {
      final covid = covidEm(diasGestacaoBruto: 200);

      expect(covid.estado, EstadoVacina.periodoRecomendado);
      expect(covid.mensagem, mensagemPeriodoRecomendado);
    });

    test('2. última dose exatamente 6 meses antes: liberado', () {
      final hoje = DateTime(2026, 7, 15);

      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: hoje,
        historico: [doseCovid(dataAplicacao: DateTime(2026, 1, 15))],
      );

      expect(covid.estado, EstadoVacina.periodoRecomendado);
    });

    test('3. um dia antes de completar 6 meses: aguardar intervalo', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 14),
        historico: [doseCovid(dataAplicacao: DateTime(2026, 1, 15))],
      );

      expect(covid.estado, EstadoVacina.aguardarIntervalo);
      expect(covid.mensagem, mensagemAguardarIntervalo);
      expect(covid.nivelAtencao, NivelAtencao.informativo);
    });

    test('4. bem depois de 6 meses: liberado', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2027, 3, 1),
        historico: [doseCovid(dataAplicacao: DateTime(2026, 1, 15))],
      );

      expect(covid.estado, EstadoVacina.periodoRecomendado);
    });

    test('5. dose anterior à gestação não conta como desta, mas conta no intervalo', () {
      // Dose de outra gestação, recente demais: não é dose desta gestação,
      // mas impede afirmar que o intervalo foi cumprido.
      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 1),
        historico: [
          doseCovid(
            dataAplicacao: DateTime(2026, 5, 1),
            dumNoRegistro: DateTime(2024, 3, 10),
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.aguardarIntervalo);
      expect(covid.estado, isNot(EstadoVacina.registrada));
    });

    test('6. dose registrada nesta gestação: REGISTRADA', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(dataAplicacao: DateTime(2026, 6, 1), dumNoRegistro: dum),
        ],
      );

      expect(covid.estado, EstadoVacina.registrada);
      expect(covid.mensagem, mensagemDoseRegistrada);
      expect(covid.podeRegistrar, isFalse);
    });

    test('7. dose de outra gestação não conta como registrada nesta', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2027, 1, 1),
        historico: [
          doseCovid(
            dataAplicacao: DateTime(2024, 4, 1),
            dumNoRegistro: DateTime(2024, 3, 10),
          ),
        ],
      );

      expect(covid.estado, isNot(EstadoVacina.registrada));
      // Intervalo antigo já cumprido, então a janela está aberta.
      expect(covid.estado, EstadoVacina.periodoRecomendado);
    });

    test('8. situação desconhecida não é tratada como dose aplicada', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: DateTime(2026, 6, 1),
            dumNoRegistro: dum,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.verificarHistorico);
      expect(covid.estado, isNot(EstadoVacina.registrada));
      expect(covid.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('dose aplicada sem data não permite afirmar o intervalo', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.verificarHistorico);
      expect(covid.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('dose sem data prevalece mesmo havendo outra antiga com data', () {
      // A dose sem data pode ter sido ontem; não dá para concluir nada.
      final covid = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2027, 1, 1),
        historico: [
          doseCovid(dataAplicacao: DateTime(2020, 1, 1)),
          doseCovid(
            dataAplicacao: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.verificarHistorico);
    });

    test('quem informou que não recebeu não tem intervalo a cumprir', () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: null,
            situacao: SituacaoInformada.naoAplicadaInformado,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.periodoRecomendado);
    });

    test('9. virada de ano é tratada corretamente', () {
      final ultima = DateTime(2026, 10, 20);

      // 20/10/2026 + 6 meses = 20/04/2027.
      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2027, 4, 19),
          historico: [doseCovid(dataAplicacao: ultima)],
        ).estado,
        EstadoVacina.aguardarIntervalo,
      );

      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2027, 4, 20),
          historico: [doseCovid(dataAplicacao: ultima)],
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('10. ano bissexto: 31/08/2027 + 6 meses libera em 29/02/2028', () {
      final ultima = DateTime(2027, 8, 31);

      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2028, 2, 28),
          historico: [doseCovid(dataAplicacao: ultima)],
        ).estado,
        EstadoVacina.aguardarIntervalo,
      );

      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2028, 2, 29),
          historico: [doseCovid(dataAplicacao: ultima)],
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('11. dataAtual diferente muda o resultado ao cruzar o corte', () {
      final historico = [doseCovid(dataAplicacao: DateTime(2026, 1, 15))];

      final antes = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 14),
        historico: historico,
      );
      final depois = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 15),
        historico: historico,
      );

      // Mesmas entradas exceto a data injetada: o resultado muda.
      expect(antes.estado, EstadoVacina.aguardarIntervalo);
      expect(depois.estado, EstadoVacina.periodoRecomendado);
      expect(antes.estado, isNot(depois.estado));
    });

    test('12. a decisão vem da dataAtual injetada, não do relógio', () {
      final historico = [doseCovid(dataAplicacao: DateTime(2026, 1, 15))];

      // Uma data no passado distante e outra no futuro distante em relação
      // a qualquer "agora" real: se a engine consultasse o relógio, uma
      // destas daria o mesmo resultado da outra.
      final passado = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 2, 1),
        historico: historico,
      );
      final futuro = covidEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2099, 1, 1),
        historico: historico,
      );

      expect(passado.estado, EstadoVacina.aguardarIntervalo);
      expect(futuro.estado, EstadoVacina.periodoRecomendado);
    });

    test('a hora do dia não altera a decisão no dia do corte', () {
      final historico = [doseCovid(dataAplicacao: DateTime(2026, 1, 15, 23, 59))];

      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2026, 7, 15, 0, 1),
          historico: historico,
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('o intervalo usado vem do calendário, não de um número fixo', () {
      final regra = regraPorCodigo(codigoCovid19) as RegraDependeIntervaloUltimaDose;

      expect(regra.intervaloMinimoDesdeUltimaDose, const Intervalo.meses(6));
      expect(
        covidEm(
          diasGestacaoBruto: 200,
          dataAtual: DateTime(2026, 7, 14),
          historico: [doseCovid(dataAplicacao: DateTime(2026, 1, 15))],
        ).motivo,
        contains('6 meses'),
      );
    });
  });

  group('Influenza — 1 dose por temporada', () {
    const temporadaAtual = '2026';
    const temporadaAnterior = '2025';

    RegistroVacinacao doseInfluenza({
      String? temporada,
      SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
      DateTime? dataAplicacao,
    }) {
      return RegistroVacinacao(
        vacinaCodigo: codigoInfluenza,
        situacaoInformada: situacao,
        versaoCalendario: versaoCalendarioPni2026,
        temporadaNoRegistro: temporada,
        dataAplicacao: dataAplicacao,
      );
    }

    StatusVacinacao influenzaEm({
      List<RegistroVacinacao> historico = const [],
      String? temporada = temporadaAtual,
    }) {
      return statusDe(
        avaliarEm(
          diasGestacaoBruto: 200,
          historico: historico,
          temporadaInfluenza: temporada,
        ),
        codigoInfluenza,
      );
    }

    test('1. temporada informada e sem histórico: período recomendado', () {
      final influenza = influenzaEm();

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
      expect(influenza.mensagem, mensagemPeriodoRecomendado);
    });

    test('2. dose aplicada na temporada atual: REGISTRADA', () {
      final influenza = influenzaEm(
        historico: [doseInfluenza(temporada: temporadaAtual)],
      );

      expect(influenza.estado, EstadoVacina.registrada);
      expect(influenza.mensagem, mensagemDoseRegistrada);
      expect(influenza.podeRegistrar, isFalse);
    });

    test('3. dose com data desconhecida na temporada atual: REGISTRADA', () {
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(
            temporada: temporadaAtual,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.registrada);
    });

    test('4. dose de temporada anterior não bloqueia a atual', () {
      final influenza = influenzaEm(
        historico: [doseInfluenza(temporada: temporadaAnterior)],
      );

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
      expect(influenza.estado, isNot(EstadoVacina.registrada));
    });

    test('5. situação desconhecida na temporada atual: VERIFICAR_HISTORICO', () {
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(
            temporada: temporadaAtual,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.verificarHistorico);
      expect(influenza.estado, isNot(EstadoVacina.registrada));
      expect(influenza.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('6. temporada vigente não informada: VERIFICAR_HISTORICO', () {
      final influenza = influenzaEm(temporada: null);

      expect(influenza.estado, EstadoVacina.verificarHistorico);
      expect(influenza.estado, isNot(EstadoVacina.periodoRecomendado));
      expect(influenza.motivo, contains('temporada vigente não informada'));
    });

    test('6b. sem temporada, nem uma dose registrada muda o resultado', () {
      // A engine não deduz a temporada do registro para "descobrir" qual é
      // a vigente.
      final influenza = influenzaEm(
        temporada: null,
        historico: [doseInfluenza(temporada: temporadaAtual)],
      );

      expect(influenza.estado, EstadoVacina.verificarHistorico);
    });

    test('7. registro sem temporada não conta como dose da temporada atual', () {
      final influenza = influenzaEm(
        historico: [doseInfluenza(temporada: null)],
      );

      // Não prova aplicação nesta temporada, e também não bloqueia.
      expect(influenza.estado, EstadoVacina.periodoRecomendado);
      expect(influenza.estado, isNot(EstadoVacina.registrada));
      expect(influenza.estado, isNot(EstadoVacina.verificarHistorico));
    });

    test('7b. situação desconhecida sem temporada não bloqueia', () {
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(
            temporada: null,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
    });

    test('8. quem informou que não recebeu: período recomendado', () {
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(
            temporada: temporadaAtual,
            situacao: SituacaoInformada.naoAplicadaInformado,
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
      expect(influenza.estado, isNot(EstadoVacina.registrada));
    });

    test('9. duas doses na mesma temporada com 1 prevista: REGISTRADA', () {
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(temporada: temporadaAtual),
          doseInfluenza(temporada: temporadaAtual),
        ],
      );

      expect(influenza.estado, EstadoVacina.registrada);
    });

    test('11. a comparação de temporada é igualdade estrita', () {
      // Espaço em branco e outro formato são temporadas diferentes: a
      // engine não normaliza nem interpreta o identificador.
      for (final outra in ['2026 ', ' 2026', '2026/2027', '2026-SUL', '']) {
        final influenza = influenzaEm(
          historico: [doseInfluenza(temporada: outra)],
        );

        expect(
          influenza.estado,
          EstadoVacina.periodoRecomendado,
          reason: 'temporada do registro: "$outra"',
        );
      }
    });

    test('12. a data de aplicação não influencia a decisão', () {
      final datas = <DateTime?>[
        null,
        DateTime(2020, 1, 1),
        DateTime(2026, 4, 15),
        DateTime(2099, 12, 31),
      ];

      for (final data in datas) {
        final influenza = influenzaEm(
          historico: [doseInfluenza(temporada: temporadaAtual, dataAplicacao: data)],
        );

        expect(influenza.estado, EstadoVacina.registrada, reason: 'data: $data');
      }
    });

    test('12b. data recente de temporada anterior não vira dose atual', () {
      // Data de aplicação dentro do ano da temporada vigente, mas snapshot
      // de temporada anterior: vale o snapshot, não a data.
      final influenza = influenzaEm(
        historico: [
          doseInfluenza(
            temporada: temporadaAnterior,
            dataAplicacao: DateTime(2026, 4, 15),
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
    });

    test('13. mudar a temporada devolve a vacina ao período recomendado', () {
      final historico = [doseInfluenza(temporada: temporadaAtual)];

      // Mesma gestação, mesmo histórico: só a temporada vigente muda.
      expect(
        influenzaEm(historico: historico, temporada: temporadaAtual).estado,
        EstadoVacina.registrada,
      );
      expect(
        influenzaEm(historico: historico, temporada: '2027').estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('16. todas as situações informadas produzem o estado esperado', () {
      const esperado = {
        SituacaoInformada.aplicadaComData: EstadoVacina.registrada,
        SituacaoInformada.aplicadaDataDesconhecida: EstadoVacina.registrada,
        SituacaoInformada.naoAplicadaInformado: EstadoVacina.periodoRecomendado,
        SituacaoInformada.situacaoDesconhecida: EstadoVacina.verificarHistorico,
      };

      // Cobre todos os valores do enum: se um valor novo aparecer, o teste
      // falha por não estar mapeado.
      expect(esperado.keys.toSet(), SituacaoInformada.values.toSet());

      esperado.forEach((situacao, estado) {
        final influenza = influenzaEm(
          historico: [doseInfluenza(temporada: temporadaAtual, situacao: situacao)],
        );

        expect(influenza.estado, estado, reason: situacao.codigo);
      });
    });

    test('a influenza não depende da idade gestacional', () {
      final historico = [doseInfluenza(temporada: temporadaAtual)];

      for (final dias in [0, 139, 140, 200, 294, -30, 400]) {
        final influenza = statusDe(
          avaliarEm(
            diasGestacaoBruto: dias,
            historico: historico,
            temporadaInfluenza: temporadaAtual,
          ),
          codigoInfluenza,
        );

        expect(influenza.estado, EstadoVacina.registrada, reason: '$dias dias');
      }
    });

    test('doses de outras vacinas não contam para a influenza', () {
      final influenza = influenzaEm(
        historico: [
          RegistroVacinacao(
            vacinaCodigo: codigoDtpa,
            situacaoInformada: SituacaoInformada.aplicadaComData,
            versaoCalendario: versaoCalendarioPni2026,
            temporadaNoRegistro: temporadaAtual,
          ),
        ],
      );

      expect(influenza.estado, EstadoVacina.periodoRecomendado);
    });
  });

  group('Influenza — dosesPorTemporada vem da regra', () {
    const temporada = '2026';
    const codigoFicticio = 'SAZONAL_DE_TESTE';

    List<RegraCalendario> calendarioCom({required int dosesPorTemporada}) {
      return [
        RegraDependeTemporada(
          codigo: codigoFicticio,
          nomeExibicao: 'Sazonal de teste',
          versaoCalendario: versaoCalendarioPni2026,
          dosesPorTemporada: dosesPorTemporada,
        ),
      ];
    }

    StatusVacinacao avaliarCom({
      required int dosesPorTemporada,
      required int quantasDoses,
    }) {
      return VacinasEngine.avaliar(
        diasGestacaoBruto: 200,
        dum: dum,
        dataAtual: dum.add(const Duration(days: 200)),
        historico: List.generate(
          quantasDoses,
          (_) => RegistroVacinacao(
            vacinaCodigo: codigoFicticio,
            situacaoInformada: SituacaoInformada.aplicadaComData,
            versaoCalendario: versaoCalendarioPni2026,
            temporadaNoRegistro: temporada,
          ),
        ),
        calendario: calendarioCom(dosesPorTemporada: dosesPorTemporada),
        temporadaInfluenza: temporada,
      ).single;
    }

    test('10. com 2 previstas, uma dose ainda não encerra', () {
      expect(
        avaliarCom(dosesPorTemporada: 2, quantasDoses: 1).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('10b. com 2 previstas, duas doses encerram', () {
      expect(
        avaliarCom(dosesPorTemporada: 2, quantasDoses: 2).estado,
        EstadoVacina.registrada,
      );
    });

    test('com 3 previstas, duas doses ainda não encerram', () {
      expect(
        avaliarCom(dosesPorTemporada: 3, quantasDoses: 2).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('doses por temporada não positivas: VERIFICAR_HISTORICO', () {
      expect(
        avaliarCom(dosesPorTemporada: 0, quantasDoses: 1).estado,
        EstadoVacina.verificarHistorico,
      );
    });

    test('o motivo cita o previsto pela regra, não um número fixo', () {
      expect(
        avaliarCom(dosesPorTemporada: 2, quantasDoses: 2).motivo,
        contains('2'),
      );
    });
  });

  group('Condicionais ainda não avaliadas (Etapa seguinte)', () {
    test('hepatite B e dT não afirmam período recomendado', () {
      final resultado = avaliarEm(diasGestacaoBruto: 200);

      for (final codigo in [codigoHepatiteB, codigoDt]) {
        final status = statusDe(resultado, codigo);
        expect(status.estado, EstadoVacina.verificarHistorico, reason: codigo);
        expect(status.estado, isNot(EstadoVacina.periodoRecomendado), reason: codigo);
      }
    });
  });

  group('Determinismo', () {
    test('mesmas entradas produzem exatamente o mesmo resultado', () {
      final historico = [
        doseRegistrada(codigoDtpa, dumNoRegistro: dum),
        RegistroVacinacao(
          vacinaCodigo: codigoInfluenza,
          situacaoInformada: SituacaoInformada.aplicadaComData,
          versaoCalendario: versaoCalendarioPni2026,
          temporadaNoRegistro: '2026',
        ),
      ];

      final primeira = avaliarEm(
        diasGestacaoBruto: 200,
        historico: historico,
        temporadaInfluenza: '2026',
      );
      final segunda = avaliarEm(
        diasGestacaoBruto: 200,
        historico: historico,
        temporadaInfluenza: '2026',
      );

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

    test('janelas por semana (dTpa/VSR) não mudam com a dataAtual', () {
      // Duas datas correntes muito distantes entre si, mesmos dias de
      // gestação: as janelas por semana produzem o mesmo estado. Quem manda
      // nelas é a idade gestacional, não o calendário civil.
      //
      // Vale só para RegraJanelaSemana: o COVID-19 depende legitimamente da
      // dataAtual, e por isso é verificado à parte.
      final comUmaData = avaliarEm(
        diasGestacaoBruto: 140,
        dataAtual: DateTime(2026, 5, 25),
      );
      final comOutraData = avaliarEm(
        diasGestacaoBruto: 140,
        dataAtual: DateTime(2030, 12, 31),
      );

      for (final codigo in [codigoDtpa, codigoVsr]) {
        expect(
          statusDe(comUmaData, codigo).estado,
          statusDe(comOutraData, codigo).estado,
          reason: codigo,
        );
      }
    });

    test('dTpa e VSR dependem da gestação, não da dataAtual', () {
      // Mesma dataAtual, gestações diferentes: o estado muda.
      final mesmaData = DateTime(2026, 8, 1);

      final antesDaJanela = avaliarEm(
        diasGestacaoBruto: 139,
        dataAtual: mesmaData,
      );
      final dentroDaJanela = avaliarEm(
        diasGestacaoBruto: 140,
        dataAtual: mesmaData,
      );

      expect(statusDe(antesDaJanela, codigoDtpa).estado, EstadoVacina.naoDisponivel);
      expect(statusDe(dentroDaJanela, codigoDtpa).estado, EstadoVacina.periodoRecomendado);
    });

    test('COVID-19 depende da dataAtual, não da idade gestacional', () {
      // O contraste com o teste acima: aqui a gestação é a mesma e só a
      // data corrente muda — e é ela que decide.
      final historico = [
        RegistroVacinacao(
          vacinaCodigo: codigoCovid19,
          situacaoInformada: SituacaoInformada.aplicadaComData,
          versaoCalendario: versaoCalendarioPni2026,
          dataAplicacao: DateTime(2026, 1, 15),
        ),
      ];

      final antesDoCorte = avaliarEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 14),
        historico: historico,
      );
      final depoisDoCorte = avaliarEm(
        diasGestacaoBruto: 200,
        dataAtual: DateTime(2026, 7, 15),
        historico: historico,
      );

      expect(statusDe(antesDoCorte, codigoCovid19).estado, EstadoVacina.aguardarIntervalo);
      expect(statusDe(depoisDoCorte, codigoCovid19).estado, EstadoVacina.periodoRecomendado);
    });

    test('COVID-19 não muda com a gestação quando a dataAtual é a mesma', () {
      // A recíproca: variar a idade gestacional não move o intervalo.
      final historico = [
        RegistroVacinacao(
          vacinaCodigo: codigoCovid19,
          situacaoInformada: SituacaoInformada.aplicadaComData,
          versaoCalendario: versaoCalendarioPni2026,
          dataAplicacao: DateTime(2026, 1, 15),
        ),
      ];
      final mesmaData = DateTime(2026, 7, 14);

      final gestacaoInicial = avaliarEm(
        diasGestacaoBruto: 50,
        dataAtual: mesmaData,
        historico: historico,
      );
      final gestacaoAvancada = avaliarEm(
        diasGestacaoBruto: 250,
        dataAtual: mesmaData,
        historico: historico,
      );

      expect(
        statusDe(gestacaoInicial, codigoCovid19).estado,
        statusDe(gestacaoAvancada, codigoCovid19).estado,
      );
      expect(statusDe(gestacaoInicial, codigoCovid19).estado, EstadoVacina.aguardarIntervalo);
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
