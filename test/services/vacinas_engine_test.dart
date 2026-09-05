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

    test('8b. situação desconhecida sem DUM: VERIFICAR_HISTORICO', () {
      // Sem vínculo, o registro não é atribuído a esta gestação — mas o
      // intervalo desta regra conta qualquer dose anterior, então não dá
      // para concluir que não há dose a considerar.
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: DateTime(2026, 6, 1),
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.verificarHistorico);
      expect(covid.estado, isNot(EstadoVacina.periodoRecomendado));
      expect(covid.estado, isNot(EstadoVacina.registrada));
    });

    test('8c. situação desconhecida sem DUM e sem data: VERIFICAR_HISTORICO',
        () {
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: null,
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.verificarHistorico);
      expect(covid.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('8d. situação desconhecida de outra gestação não infere vínculo', () {
      // O registro traz DUM de outra gestação: a relevância dele está
      // determinada, e a engine não o puxa para esta gestação.
      final covid = covidEm(
        diasGestacaoBruto: 200,
        historico: [
          doseCovid(
            dataAplicacao: DateTime(2020, 6, 1),
            dumNoRegistro: DateTime(2020, 3, 10),
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(covid.estado, EstadoVacina.periodoRecomendado);
      expect(covid.estado, isNot(EstadoVacina.registrada));
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

  group('Hepatite B — esquema de 3 doses', () {
    final primeiraDose = DateTime(2026, 1, 10);

    RegistroVacinacao dose({
      required int? numero,
      DateTime? data,
      SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
      DateTime? dumNoRegistro,
      String codigo = codigoHepatiteB,
    }) {
      return RegistroVacinacao(
        vacinaCodigo: codigo,
        situacaoInformada: situacao,
        versaoCalendario: versaoCalendarioPni2026,
        numeroDaDose: numero,
        dataAplicacao: data,
        dumNoRegistro: dumNoRegistro,
      );
    }

    StatusVacinacao hepatiteEm({
      List<RegistroVacinacao> historico = const [],
      required DateTime dataAtual,
    }) {
      return statusDe(
        avaliarEm(
          diasGestacaoBruto: 200,
          historico: historico,
          dataAtual: dataAtual,
        ),
        codigoHepatiteB,
      );
    }

    test('1. zero doses: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(dataAtual: DateTime(2026, 6, 1));

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('2. dose 1 com recomendado ainda não atingido: AGUARDAR_INTERVALO', () {
      final status = hepatiteEm(
        historico: [dose(numero: 1, data: primeiraDose)],
        dataAtual: DateTime(2026, 1, 20),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
      expect(status.mensagem, mensagemAguardarIntervalo);
    });

    test('3. dose 1 com recomendado atingido: PERIODO_RECOMENDADO', () {
      final status = hepatiteEm(
        historico: [dose(numero: 1, data: primeiraDose)],
        dataAtual: DateTime(2026, 2, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.mensagem, mensagemPeriodoRecomendado);
    });

    test('4. dose 1 sem data: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(
        historico: [
          dose(
            numero: 1,
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
        dataAtual: DateTime(2026, 6, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });

    test('5. dose aplicada sem numeroDaDose: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(
        historico: [dose(numero: null, data: primeiraDose)],
        dataAtual: DateTime(2026, 6, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('sem posição'));
    });

    test('6. duas doses válidas, dose 3 liberada pelo recomendado', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
        ],
        dataAtual: DateTime(2026, 7, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
    });

    test('7. dose 3 abaixo do mínimo 2→3: AGUARDAR_INTERVALO', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
        ],
        dataAtual: DateTime(2026, 3, 1),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
      expect(status.motivo, contains('mínimo'));
      expect(status.motivo, isNot(contains('mínimo cumprido')));
      // O mínimo realmente não foi cumprido: a mensagem pode dizer isso.
      expect(status.mensagem, mensagemAguardarIntervalo);
    });

    test('8. mínimos cumpridos mas recomendado 1→3 não: AGUARDAR_INTERVALO', () {
      // 10/01 + 4 meses (mínimo 1→3) = 10/05; 10/02 + 2 meses = 10/04.
      // O recomendado 1→3 (6 meses) só completa em 10/07.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
        ],
        dataAtual: DateTime(2026, 5, 10),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
      expect(status.motivo, contains('mínimo cumprido'));
      // A mensagem não pode afirmar que o mínimo falta: ele foi cumprido.
      expect(status.mensagem, mensagemAguardarRecomendado);
      expect(status.mensagem, isNot(mensagemAguardarIntervalo));
    });

    test('8b. as duas mensagens de espera são distintas entre si', () {
      expect(mensagemAguardarRecomendado, isNot(mensagemAguardarIntervalo));
      expect(
        mensagemAguardarIntervalo.toLowerCase(),
        contains('ainda não foi cumprido o intervalo mínimo'),
      );
      expect(
        mensagemAguardarRecomendado.toLowerCase(),
        contains('intervalo mínimo desde a última dose registrada já foi '
            'cumprido'),
      );
    });

    test('9. recomendado 1→3 exatamente atingido: PERIODO_RECOMENDADO', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
        ],
        dataAtual: DateTime(2026, 7, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
    });

    test('10. três doses válidas: REGISTRADA', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 7, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.registrada);
      expect(status.mensagem, mensagemDoseRegistrada);
      expect(status.podeRegistrar, isFalse);
    });

    test('10i. três doses com a dose 3 no futuro: não é REGISTRADA', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          // Erro de digitação no ano: os três intervalos mínimos passam,
          // mas a dose ainda não aconteceu.
          dose(numero: 3, data: DateTime(2027, 1, 10)),
        ],
        dataAtual: DateTime(2026, 9, 5),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.podeRegistrar, isTrue);
      expect(status.motivo, contains('futuro'));
    });

    test('10j. dose futura no limite: o próprio dia de hoje ainda completa',
        () {
      final hoje = DateTime(2026, 9, 5);

      final noFuturo = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 9, 6)),
        ],
        dataAtual: hoje,
      );
      final hojeMesmo = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: hoje),
        ],
        dataAtual: hoje,
      );

      expect(noFuturo.estado, EstadoVacina.verificarHistorico);
      expect(hojeMesmo.estado, EstadoVacina.registrada);
    });

    test('10k. dose futura em esquema incompleto segue em AGUARDAR_INTERVALO',
        () {
      // Contraste com 10i: a regra de dose futura só vale para o esquema
      // completo, e o comportamento conservador anterior é preservado.
      final status = hepatiteEm(
        historico: [dose(numero: 1, data: DateTime(2027, 1, 1))],
        dataAtual: DateTime(2026, 6, 1),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
    });

    test('10b. três doses com uma data ausente: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(
            numero: 2,
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
          dose(numero: 3, data: DateTime(2026, 7, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('cronologia: dose 2 anterior à dose 1, com esquema incompleto', () {
      // A inconsistência é detectada mesmo faltando a terceira dose.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: DateTime(2026, 3, 10)),
          dose(numero: 2, data: DateTime(2026, 1, 10)),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.periodoRecomendado));
      expect(status.motivo, contains('não é posterior'));
    });

    test('cronologia: dose 3 anterior à dose 1', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: DateTime(2026, 6, 10)),
          dose(numero: 2, data: DateTime(2026, 7, 10)),
          dose(numero: 3, data: DateTime(2026, 1, 10)),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('cronologia: duas doses numeradas na mesma data', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: primeiraDose),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('não é posterior'));
    });

    test('cronologia: três doses na mesma data não formam esquema completo', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: primeiraDose),
          dose(numero: 3, data: primeiraDose),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('cronologia: dose sem data não dispara falso positivo', () {
      // Sem data não há como comparar; o caminho segue para as demais
      // validações, que exigem data.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(
            numero: 2,
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, isNot(contains('não é posterior')));
    });

    test('cronologia: doses corretamente ordenadas seguem válidas', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 7, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.registrada);
    });

    test('cronologia: ordem de entrada embaralhada não muda o resultado', () {
      final coerentes = [
        dose(numero: 3, data: DateTime(2026, 7, 10)),
        dose(numero: 1, data: primeiraDose),
        dose(numero: 2, data: DateTime(2026, 2, 10)),
      ];

      final a = hepatiteEm(historico: coerentes, dataAtual: DateTime(2026, 8, 1));
      final b = hepatiteEm(
        historico: coerentes.reversed.toList(),
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(a.estado, EstadoVacina.registrada);
      expect(a.estado, b.estado);
      expect(a.motivo, b.motivo);
    });

    test('10c. dose 2 anterior à dose 1: não é REGISTRADA', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: DateTime(2026, 3, 10)),
          dose(numero: 2, data: DateTime(2026, 1, 10)),
          dose(numero: 3, data: DateTime(2026, 9, 10)),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('não é posterior'));
    });

    test('10d. dose 3 anterior à dose 2: não é REGISTRADA', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 6, 10)),
          dose(numero: 3, data: DateTime(2026, 3, 10)),
        ],
        dataAtual: DateTime(2026, 10, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('10e. mínimo 1→2 não cumprido: não é REGISTRADA', () {
      // 10/01 → 20/01: menos de 1 mês entre a 1ª e a 2ª dose.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 1, 20)),
          dose(numero: 3, data: DateTime(2026, 8, 10)),
        ],
        dataAtual: DateTime(2026, 9, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('mínimo'));
    });

    test('10f. mínimo 2→3 não cumprido: não é REGISTRADA', () {
      // 10/02 → 20/02: menos de 2 meses entre a 2ª e a 3ª dose.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 2, 20)),
        ],
        dataAtual: DateTime(2026, 9, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('10g. mínimo 1→3 não cumprido: não é REGISTRADA', () {
      // 1→2 e 2→3 cumpridos, mas 1→3 fecha em 3 meses, abaixo dos 4 mínimos.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 4, 10)),
        ],
        dataAtual: DateTime(2026, 9, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('10h. mínimos exatamente cumpridos: REGISTRADA', () {
      // 10/01 → 10/02 (1 mês) → 10/05 (3 meses depois da 2ª, 4 meses da 1ª).
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
          dose(numero: 3, data: DateTime(2026, 5, 10)),
        ],
        dataAtual: DateTime(2026, 9, 1),
      );

      expect(status.estado, EstadoVacina.registrada);
    });

    test('11. ordem dos registros na lista não altera o resultado', () {
      final doses = [
        dose(numero: 2, data: DateTime(2026, 2, 10)),
        dose(numero: 1, data: primeiraDose),
      ];
      final invertidas = doses.reversed.toList();

      final a = hepatiteEm(historico: doses, dataAtual: DateTime(2026, 7, 10));
      final b = hepatiteEm(historico: invertidas, dataAtual: DateTime(2026, 7, 10));

      expect(a.estado, b.estado);
      expect(a.motivo, b.motivo);
    });

    test('12. posição de dose repetida: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 2, data: primeiraDose),
          dose(numero: 2, data: DateTime(2026, 2, 10)),
        ],
        dataAtual: DateTime(2026, 6, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('repetidas'));
    });

    test('13. posição fora de 1..3: VERIFICAR_HISTORICO', () {
      for (final numero in [0, 4, 99, -1]) {
        final status = hepatiteEm(
          historico: [dose(numero: numero, data: primeiraDose)],
          dataAtual: DateTime(2026, 6, 1),
        );

        expect(status.estado, EstadoVacina.verificarHistorico, reason: '$numero');
      }
    });

    test('14. situação desconhecida: VERIFICAR_HISTORICO', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(
            numero: 2,
            data: DateTime(2026, 2, 10),
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
        dataAtual: DateTime(2026, 7, 10),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });

    test('15. naoAplicadaInformado não conta como dose', () {
      final status = hepatiteEm(
        historico: [
          dose(
            numero: 1,
            data: null,
            situacao: SituacaoInformada.naoAplicadaInformado,
          ),
        ],
        dataAtual: DateTime(2026, 6, 1),
      );

      // Sem nenhuma dose aplicada, o esquema segue indeterminado.
      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('sem dose registrada'));
    });

    test('16. dose sem DUM participa do histórico', () {
      final status = hepatiteEm(
        historico: [dose(numero: 1, data: primeiraDose)],
        dataAtual: DateTime(2026, 2, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.estado, isNot(EstadoVacina.verificarHistorico));
    });

    test('17. dose de outra gestação participa do histórico', () {
      final status = hepatiteEm(
        historico: [
          dose(
            numero: 1,
            data: primeiraDose,
            dumNoRegistro: DateTime(2020, 3, 10),
          ),
        ],
        dataAtual: DateTime(2026, 2, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
    });

    test('18. nova gestação não reinicia o esquema', () {
      // Duas doses aplicadas sob outra DUM continuam contando: a próxima é
      // a 3ª, não a 1ª.
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose, dumNoRegistro: DateTime(2020, 3, 10)),
          dose(
            numero: 2,
            data: DateTime(2026, 2, 10),
            dumNoRegistro: DateTime(2020, 3, 10),
          ),
        ],
        dataAtual: DateTime(2026, 7, 10),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 3'));
    });

    test('19. dose com data futura mantém o esquema em espera', () {
      final status = hepatiteEm(
        historico: [dose(numero: 1, data: DateTime(2027, 1, 1))],
        dataAtual: DateTime(2026, 6, 1),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
      expect(status.estado, isNot(EstadoVacina.periodoRecomendado));
    });

    test('20. virada de mês e ano bissexto na aritmética dos intervalos', () {
      // 31/01 + 1 mês = 28/02 (2026 não é bissexto).
      expect(
        hepatiteEm(
          historico: [dose(numero: 1, data: DateTime(2026, 1, 31))],
          dataAtual: DateTime(2026, 2, 27),
        ).estado,
        EstadoVacina.aguardarIntervalo,
      );
      expect(
        hepatiteEm(
          historico: [dose(numero: 1, data: DateTime(2026, 1, 31))],
          dataAtual: DateTime(2026, 2, 28),
        ).estado,
        EstadoVacina.periodoRecomendado,
      );

      // 31/01/2028 + 1 mês = 29/02/2028 (bissexto).
      expect(
        hepatiteEm(
          historico: [dose(numero: 1, data: DateTime(2028, 1, 31))],
          dataAtual: DateTime(2028, 2, 28),
        ).estado,
        EstadoVacina.aguardarIntervalo,
      );
      expect(
        hepatiteEm(
          historico: [dose(numero: 1, data: DateTime(2028, 1, 31))],
          dataAtual: DateTime(2028, 2, 29),
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('21 e 22. mínimo 2→3 exatamente atingido e um dia antes', () {
      final historico = [
        dose(numero: 1, data: DateTime(2025, 1, 10)),
        dose(numero: 2, data: DateTime(2026, 2, 10)),
      ];

      // 1→3 mínimo (4 meses de 10/01/2025) e recomendado (6 meses) já
      // cumpridos: quem manda é o mínimo 2→3, que completa em 10/04/2026.
      expect(
        hepatiteEm(historico: historico, dataAtual: DateTime(2026, 4, 9)).estado,
        EstadoVacina.aguardarIntervalo,
      );
      expect(
        hepatiteEm(historico: historico, dataAtual: DateTime(2026, 4, 10)).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('23 e 24. recomendado 1→2 exatamente atingido e um dia antes', () {
      final historico = [dose(numero: 1, data: primeiraDose)];

      expect(
        hepatiteEm(historico: historico, dataAtual: DateTime(2026, 2, 9)).estado,
        EstadoVacina.aguardarIntervalo,
      );
      expect(
        hepatiteEm(historico: historico, dataAtual: DateTime(2026, 2, 10)).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('25. doses de outra vacina não interferem', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose, codigo: codigoDtpa),
          dose(numero: 2, data: DateTime(2026, 2, 10), codigo: codigoCovid19),
        ],
        dataAtual: DateTime(2026, 7, 10),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('sem dose registrada'));
    });

    test('26. determinismo campo a campo', () {
      final historico = [
        dose(numero: 1, data: primeiraDose),
        dose(numero: 2, data: DateTime(2026, 2, 10)),
      ];
      final data = DateTime(2026, 5, 10);

      final a = hepatiteEm(historico: historico, dataAtual: data);
      final b = hepatiteEm(historico: historico, dataAtual: data);

      expect(a.estado, b.estado);
      expect(a.mensagem, b.mensagem);
      expect(a.nivelAtencao, b.nivelAtencao);
      expect(a.podeRegistrar, b.podeRegistrar);
      expect(a.motivo, b.motivo);
      expect(a.proximaJanela, b.proximaJanela);
    });

    test('a hepatite B não depende da idade gestacional', () {
      final historico = [dose(numero: 1, data: primeiraDose)];

      for (final dias in [0, 140, 200, 294, -30, 400]) {
        final status = statusDe(
          avaliarEm(
            diasGestacaoBruto: dias,
            historico: historico,
            dataAtual: DateTime(2026, 2, 10),
          ),
          codigoHepatiteB,
        );

        expect(status.estado, EstadoVacina.periodoRecomendado, reason: '$dias dias');
      }
    });

    test('dose 2 ausente com dose 1 e 3 registradas avalia a dose 2', () {
      final status = hepatiteEm(
        historico: [
          dose(numero: 1, data: primeiraDose),
          dose(numero: 3, data: DateTime(2026, 7, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 2'));
    });

    test('dose de referência ausente leva a VERIFICAR_HISTORICO', () {
      // Só a dose 2: a próxima ausente é a 1, que não tem intervalo
      // declarado que leve até ela.
      final status = hepatiteEm(
        historico: [dose(numero: 2, data: DateTime(2026, 2, 10))],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });
  });

  group('Hepatite B — parâmetros vêm da regra', () {
    const codigoFicticio = 'ESQUEMA_DE_TESTE';

    StatusVacinacao avaliarCom({
      required int dosesDoEsquema,
      required List<IntervaloEntreDoses> intervalos,
      required List<int> numerosRegistrados,
      required DateTime dataAtual,
    }) {
      return VacinasEngine.avaliar(
        diasGestacaoBruto: 200,
        dum: dum,
        dataAtual: dataAtual,
        historico: [
          for (final numero in numerosRegistrados)
            RegistroVacinacao(
              vacinaCodigo: codigoFicticio,
              situacaoInformada: SituacaoInformada.aplicadaComData,
              versaoCalendario: versaoCalendarioPni2026,
              numeroDaDose: numero,
              dataAplicacao: DateTime(2026, numero, 10),
            ),
        ],
        calendario: [
          RegraDependeHistorico(
            codigo: codigoFicticio,
            nomeExibicao: 'Esquema de teste',
            versaoCalendario: versaoCalendarioPni2026,
            dosesDoEsquemaBasico: dosesDoEsquema,
            reiniciaEsquemaIniciado: false,
            intervalosEntreDoses: intervalos,
          ),
        ],
      ).single;
    }

    test('esquema de 2 doses encerra com 2 doses, não com 3', () {
      expect(
        avaliarCom(
          dosesDoEsquema: 2,
          intervalos: const [
            IntervaloEntreDoses(
              doseInicial: 1,
              doseFinal: 2,
              recomendado: Intervalo.meses(1),
            ),
          ],
          numerosRegistrados: [1, 2],
          dataAtual: DateTime(2026, 6, 1),
        ).estado,
        EstadoVacina.registrada,
      );
    });

    test('esquema de 4 doses não encerra com 3', () {
      expect(
        avaliarCom(
          dosesDoEsquema: 4,
          intervalos: const [
            IntervaloEntreDoses(
              doseInicial: 1,
              doseFinal: 4,
              recomendado: Intervalo.meses(1),
            ),
          ],
          numerosRegistrados: [1, 2, 3],
          dataAtual: DateTime(2026, 6, 1),
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('o intervalo declarado é respeitado, sem número fixo', () {
      final intervalos = [
        const IntervaloEntreDoses(
          doseInicial: 1,
          doseFinal: 2,
          recomendado: Intervalo.meses(9),
        ),
      ];

      expect(
        avaliarCom(
          dosesDoEsquema: 2,
          intervalos: intervalos,
          numerosRegistrados: [1],
          dataAtual: DateTime(2026, 10, 9),
        ).estado,
        EstadoVacina.aguardarIntervalo,
      );
      expect(
        avaliarCom(
          dosesDoEsquema: 2,
          intervalos: intervalos,
          numerosRegistrados: [1],
          dataAtual: DateTime(2026, 10, 10),
        ).estado,
        EstadoVacina.periodoRecomendado,
      );
    });

    test('sem intervalo declarado para a próxima dose: VERIFICAR_HISTORICO', () {
      expect(
        avaliarCom(
          dosesDoEsquema: 3,
          intervalos: const [],
          numerosRegistrados: [1],
          dataAtual: DateTime(2026, 6, 1),
        ).estado,
        EstadoVacina.verificarHistorico,
      );
    });
  });

  group('dT — esquema com intervalo desde a última dose relevante', () {
    final hoje = DateTime(2026, 8, 1);

    RegistroVacinacao doseDt({
      required int? numero,
      required DateTime? data,
      SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
      DateTime? dumNoRegistro,
    }) {
      return RegistroVacinacao(
        vacinaCodigo: codigoDt,
        situacaoInformada: situacao,
        versaoCalendario: versaoCalendarioPni2026,
        numeroDaDose: numero,
        dataAplicacao: data,
        dumNoRegistro: dumNoRegistro,
      );
    }

    RegistroVacinacao doseDtpa({
      required DateTime? data,
      SituacaoInformada situacao = SituacaoInformada.aplicadaComData,
      DateTime? dumNoRegistro,
    }) {
      return RegistroVacinacao(
        vacinaCodigo: codigoDtpa,
        situacaoInformada: situacao,
        versaoCalendario: versaoCalendarioPni2026,
        dataAplicacao: data,
        dumNoRegistro: dumNoRegistro,
      );
    }

    RegistroVacinacao doseDe(String codigo, DateTime data) {
      return RegistroVacinacao(
        vacinaCodigo: codigo,
        situacaoInformada: SituacaoInformada.aplicadaComData,
        versaoCalendario: versaoCalendarioPni2026,
        dataAplicacao: data,
      );
    }

    StatusVacinacao dtEm({
      List<RegistroVacinacao> historico = const [],
      DateTime? dataAtual,
    }) {
      return statusDe(
        avaliarEm(
          diasGestacaoBruto: 200,
          historico: historico,
          dataAtual: dataAtual ?? hoje,
        ),
        codigoDt,
      );
    }

    test('1. nenhuma dose relevante: VERIFICAR_HISTORICO', () {
      expect(dtEm().estado, EstadoVacina.verificarHistorico);
    });

    test('2. uma dT: esquema incompleto, intervalo cumprido', () {
      final status = dtEm(
        historico: [doseDt(numero: 1, data: DateTime(2026, 1, 10))],
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 2'));
    });

    test('3. duas dT: falta a terceira', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 3'));
    });

    test('4. três dT: REGISTRADA', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDt(numero: 3, data: DateTime(2026, 5, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.registrada);
      expect(status.podeRegistrar, isFalse);
    });

    test('5. dT + dTpa: duas de três, ainda incompleto', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(data: DateTime(2026, 3, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('dose 3'));
    });

    test('6. duas dT + dTpa: a dTpa completa o esquema', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDtpa(data: DateTime(2026, 5, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.registrada);
      expect(status.motivo, contains('completo'));
    });

    test('7. três dT + dTpa: a dTpa é reforço, não quarta dose', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDt(numero: 3, data: DateTime(2026, 5, 10)),
          doseDtpa(data: DateTime(2026, 7, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.registrada);
      expect(status.motivo, contains('3 de DT'));
      expect(status.motivo, contains('0 de outra vacina'));
    });

    test('8. dTpa isolada a partir da 20ª semana abre o esquema', () {
      // 200 dias são cerca de 28 semanas: sem dT no histórico, a dTpa pode
      // representar a 1ª dose de quem chega ao serviço já na gestação.
      final status = dtEm(historico: [doseDtpa(data: DateTime(2026, 1, 10))]);

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.estado, isNot(EstadoVacina.verificarHistorico));
      expect(status.motivo, contains('dose 2'));
    });

    test('8b. dTpa isolada exatamente na 20ª semana abre o esquema', () {
      final status = statusDe(
        avaliarEm(
          diasGestacaoBruto: 140,
          historico: [doseDtpa(data: DateTime(2026, 1, 10))],
          dataAtual: hoje,
        ),
        codigoDt,
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
    });

    test('8c. dTpa isolada um dia antes da 20ª semana: VERIFICAR_HISTORICO',
        () {
      final status = statusDe(
        avaliarEm(
          diasGestacaoBruto: 139,
          historico: [doseDtpa(data: DateTime(2026, 1, 10))],
          dataAtual: hoje,
        ),
        codigoDt,
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('sem contexto gestacional'));
    });

    test('8d. dTpa isolada com gestação indeterminada: VERIFICAR_HISTORICO',
        () {
      final status = statusDe(
        avaliarEm(
          diasGestacaoBruto: -30,
          historico: [doseDtpa(data: DateTime(2026, 1, 10))],
          dataAtual: hoje,
        ),
        codigoDt,
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });

    test('8e. com uma dT no histórico a dTpa conta em qualquer semana', () {
      // A dT já ancora o esquema: a janela da dTpa não entra na conta.
      final status = statusDe(
        avaliarEm(
          diasGestacaoBruto: 100,
          historico: [
            doseDt(numero: 1, data: DateTime(2026, 1, 10)),
            doseDtpa(data: DateTime(2026, 3, 10)),
          ],
          dataAtual: hoje,
        ),
        codigoDt,
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 3'));
    });

    test('8f. com o esquema completo por dT a dTpa segue sendo reforço', () {
      final status = statusDe(
        avaliarEm(
          diasGestacaoBruto: 100,
          historico: [
            doseDt(numero: 1, data: DateTime(2026, 1, 10)),
            doseDt(numero: 2, data: DateTime(2026, 3, 10)),
            doseDt(numero: 3, data: DateTime(2026, 5, 10)),
            doseDtpa(data: DateTime(2026, 7, 10)),
          ],
          dataAtual: hoje,
        ),
        codigoDt,
      );

      expect(status.estado, EstadoVacina.registrada);
    });

    test('8g. sem nenhuma dose relevante o resultado não muda com a semana',
        () {
      for (final dias in [100, 140, 200]) {
        expect(
          statusDe(avaliarEm(diasGestacaoBruto: dias, dataAtual: hoje), codigoDt)
              .estado,
          EstadoVacina.verificarHistorico,
          reason: '$dias dias',
        );
      }
    });

    test('8h. várias dTpa não ultrapassam o esquema básico', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2020, 1, 10)),
          doseDtpa(data: DateTime(2022, 5, 10)),
          doseDtpa(data: DateTime(2024, 5, 10)),
          doseDtpa(data: DateTime(2026, 1, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.registrada);
      expect(status.motivo, contains('2 de outra vacina'));
    });

    test('8i. só dTpa: duas abrem e completam parte do esquema', () {
      final status = dtEm(
        historico: [
          doseDtpa(data: DateTime(2024, 5, 10)),
          doseDtpa(data: DateTime(2026, 1, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.periodoRecomendado);
      expect(status.motivo, contains('dose 3'));
    });

    test('8j. dTpa de outra gestação e da atual participam igualmente', () {
      final outraGestacao = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDtpa(
            data: DateTime(2026, 5, 10),
            dumNoRegistro: DateTime(2020, 3, 10),
          ),
        ],
      );
      final gestacaoAtual = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDtpa(data: DateTime(2026, 5, 10), dumNoRegistro: dum),
        ],
      );

      expect(outraGestacao.estado, EstadoVacina.registrada);
      expect(gestacaoAtual.estado, EstadoVacina.registrada);
    });

    test('8k. dTpa duplicada na mesma data não completa o esquema', () {
      final duplicada = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(data: DateTime(2026, 3, 10)),
          doseDtpa(data: DateTime(2026, 3, 10)),
        ],
      );
      final emDatasDistintas = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(data: DateTime(2026, 3, 10)),
          doseDtpa(data: DateTime(2026, 5, 10)),
        ],
      );

      expect(duplicada.estado, EstadoVacina.verificarHistorico);
      expect(duplicada.estado, isNot(EstadoVacina.registrada));
      expect(duplicada.motivo, contains('indistinguíveis'));
      // Contraste: datas distintas continuam sendo duas doses.
      expect(emDatasDistintas.estado, EstadoVacina.registrada);
    });

    test('8l. duas dTpa sem data são indistinguíveis entre si', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
          doseDtpa(
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('8m. com o esquema completo por dT a duplicidade não muda nada', () {
      // As doses de outra vacina já são reforço: não ocupam posição e não
      // precisam ser distinguidas entre si.
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDt(numero: 3, data: DateTime(2026, 5, 10)),
          doseDtpa(data: DateTime(2026, 7, 10)),
          doseDtpa(data: DateTime(2026, 7, 10)),
        ],
      );

      expect(status.estado, EstadoVacina.registrada);
    });

    test('8n. três dT com a última no futuro: não é REGISTRADA', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDt(numero: 3, data: DateTime(2027, 5, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('futuro'));
    });

    test('8o. dTpa no futuro não completa o esquema', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 3, 10)),
          doseDtpa(data: DateTime(2027, 5, 10)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
    });

    test('9. dTpa é dose relevante para o intervalo', () {
      // dTpa recente segura a próxima dose, mesmo o esquema estando incompleto.
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(data: DateTime(2026, 7, 20)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
    });

    test('10 a 14. vacinas sem os componentes não afetam o dT', () {
      for (final codigo in [
        codigoHepatiteB,
        codigoInfluenza,
        codigoCovid19,
        codigoVsr,
        codigoFebreAmarela,
      ]) {
        final status = dtEm(
          historico: [
            doseDt(numero: 1, data: DateTime(2026, 1, 10)),
            doseDe(codigo, DateTime(2026, 7, 25)),
          ],
        );

        // A dose recente da outra vacina não segura o intervalo do dT.
        expect(status.estado, EstadoVacina.periodoRecomendado, reason: codigo);
      }
    });

    test('10b. vacina sem componentes não serve de âncora do esquema', () {
      final status = dtEm(
        historico: [doseDe(codigoHepatiteB, DateTime(2026, 1, 10))],
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });

    test('15. dose relevante sem data: VERIFICAR_HISTORICO', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(
            data: null,
            situacao: SituacaoInformada.aplicadaDataDesconhecida,
          ),
        ],
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('sem data'));
    });

    test('16. situação desconhecida: VERIFICAR_HISTORICO', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2026, 1, 10)),
          doseDtpa(
            data: DateTime(2026, 3, 10),
            situacao: SituacaoInformada.situacaoDesconhecida,
          ),
        ],
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
    });

    test('17. naoAplicadaInformado não conta como dose', () {
      final status = dtEm(
        historico: [
          doseDt(
            numero: 1,
            data: null,
            situacao: SituacaoInformada.naoAplicadaInformado,
          ),
        ],
      );

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.motivo, contains('sem dose relevante'));
    });

    test('18 e 19. registro sem DUM e de outra gestação participam', () {
      final semDum = dtEm(
        historico: [doseDt(numero: 1, data: DateTime(2026, 1, 10))],
      );
      final outraGestacao = dtEm(
        historico: [
          doseDt(
            numero: 1,
            data: DateTime(2026, 1, 10),
            dumNoRegistro: DateTime(2020, 3, 10),
          ),
        ],
      );

      expect(semDum.estado, EstadoVacina.periodoRecomendado);
      expect(outraGestacao.estado, EstadoVacina.periodoRecomendado);
    });

    test('20 a 25. faixas de intervalo desde a última dose relevante', () {
      final ultima = DateTime(2026, 6, 1);
      final historico = [doseDt(numero: 1, data: ultima)];

      EstadoVacina estadoApos(int dias) => dtEm(
            historico: historico,
            dataAtual: ultima.add(Duration(days: dias)),
          ).estado;

      expect(estadoApos(29), EstadoVacina.aguardarIntervalo);
      expect(estadoApos(30), EstadoVacina.aguardarIntervalo);
      expect(estadoApos(31), EstadoVacina.aguardarIntervalo);
      expect(estadoApos(59), EstadoVacina.aguardarIntervalo);
      expect(estadoApos(60), EstadoVacina.periodoRecomendado);
      expect(estadoApos(61), EstadoVacina.periodoRecomendado);
    });

    test('a faixa de 30 a 59 dias registra o mínimo excepcional no motivo', () {
      final ultima = DateTime(2026, 6, 1);
      final historico = [doseDt(numero: 1, data: ultima)];

      final antesDoMinimo = dtEm(
        historico: historico,
        dataAtual: ultima.add(const Duration(days: 29)),
      );
      final aposOMinimo = dtEm(
        historico: historico,
        dataAtual: ultima.add(const Duration(days: 45)),
      );

      expect(antesDoMinimo.motivo, isNot(contains('excepcional')));
      expect(aposOMinimo.motivo, contains('excepcional'));
      // Mesmo estado: a engine não caracteriza a exceção.
      expect(antesDoMinimo.estado, aposOMinimo.estado);
      // Mas a mensagem acompanha o motivo, sem afirmar o contrário dele.
      expect(antesDoMinimo.mensagem, mensagemAguardarIntervalo);
      expect(aposOMinimo.mensagem, mensagemAguardarRecomendado);
    });

    test('26. a dose relevante mais recente determina o intervalo', () {
      final status = dtEm(
        historico: [
          doseDt(numero: 1, data: DateTime(2020, 1, 10)),
          doseDt(numero: 2, data: DateTime(2026, 7, 25)),
        ],
        dataAtual: DateTime(2026, 8, 1),
      );

      expect(status.estado, EstadoVacina.aguardarIntervalo);
    });

    test('27. determinismo campo a campo', () {
      final historico = [
        doseDt(numero: 1, data: DateTime(2026, 1, 10)),
        doseDtpa(data: DateTime(2026, 7, 20)),
      ];

      final a = dtEm(historico: historico);
      final b = dtEm(historico: historico);

      expect(a.estado, b.estado);
      expect(a.mensagem, b.mensagem);
      expect(a.nivelAtencao, b.nivelAtencao);
      expect(a.podeRegistrar, b.podeRegistrar);
      expect(a.motivo, b.motivo);
    });

    test('a numeração das doses próprias continua sendo exigida', () {
      final semNumero = dtEm(
        historico: [doseDt(numero: null, data: DateTime(2026, 1, 10))],
      );

      expect(semNumero.estado, EstadoVacina.verificarHistorico);
      expect(semNumero.motivo, contains('sem posição'));
    });

    test('o dT não depende da idade gestacional', () {
      final historico = [doseDt(numero: 1, data: DateTime(2026, 1, 10))];

      for (final dias in [0, 140, 200, 294, -30, 400]) {
        final status = statusDe(
          avaliarEm(
            diasGestacaoBruto: dias,
            historico: historico,
            dataAtual: hoje,
          ),
          codigoDt,
        );

        expect(status.estado, EstadoVacina.periodoRecomendado, reason: '$dias dias');
      }
    });
  });

  group('dT — componentes vêm da regra e do calendário', () {
    const codigoBase = 'BASE_DE_TESTE';
    const codigoParcial = 'PARCIAL_DE_TESTE';
    const codigoCompleto = 'COMPLETO_DE_TESTE';

    final calendarioSintetico = <RegraCalendario>[
      const RegraDependeHistorico(
        codigo: codigoBase,
        nomeExibicao: 'Base de teste',
        versaoCalendario: versaoCalendarioPni2026,
        dosesDoEsquemaBasico: 2,
        reiniciaEsquemaIniciado: false,
        composicao: {ComponenteVacinal.difterico, ComponenteVacinal.tetanico},
        componentesDoIntervalo: {
          ComponenteVacinal.difterico,
          ComponenteVacinal.tetanico,
        },
        intervaloRecomendadoDesdeUltimaDose: Intervalo.dias(60),
      ),
      // Só um dos componentes: com containsAll, não entra na contagem.
      const RegraJanelaSemana(
        codigo: codigoParcial,
        nomeExibicao: 'Parcial de teste',
        versaoCalendario: versaoCalendarioPni2026,
        semanaInicial: 20,
        dosesPorGestacao: 1,
        composicao: {ComponenteVacinal.tetanico},
      ),
      const RegraJanelaSemana(
        codigo: codigoCompleto,
        nomeExibicao: 'Completo de teste',
        versaoCalendario: versaoCalendarioPni2026,
        semanaInicial: 20,
        dosesPorGestacao: 1,
        composicao: {
          ComponenteVacinal.difterico,
          ComponenteVacinal.tetanico,
          ComponenteVacinal.pertussis,
        },
      ),
    ];

    StatusVacinacao avaliarCom(List<RegistroVacinacao> historico) {
      return VacinasEngine.avaliar(
        diasGestacaoBruto: 200,
        dum: dum,
        dataAtual: DateTime(2026, 8, 1),
        historico: historico,
        calendario: calendarioSintetico,
      ).firstWhere((s) => s.vacinaCodigo == codigoBase);
    }

    RegistroVacinacao registro(String codigo, DateTime data, {int? numero}) {
      return RegistroVacinacao(
        vacinaCodigo: codigo,
        situacaoInformada: SituacaoInformada.aplicadaComData,
        versaoCalendario: versaoCalendarioPni2026,
        numeroDaDose: numero,
        dataAplicacao: data,
      );
    }

    test('30. containsAll: vacina com apenas um componente não conta', () {
      final status = avaliarCom([
        registro(codigoBase, DateTime(2026, 1, 10), numero: 1),
        registro(codigoParcial, DateTime(2026, 7, 25)),
      ]);

      // A dose parcial não completa o esquema nem segura o intervalo.
      expect(status.estado, EstadoVacina.periodoRecomendado);
    });

    test('29. vacina com todos os componentes conta, sem hardcode de código', () {
      final status = avaliarCom([
        registro(codigoBase, DateTime(2026, 1, 10), numero: 1),
        registro(codigoCompleto, DateTime(2026, 3, 10)),
      ]);

      expect(status.estado, EstadoVacina.registrada);
    });

    test('a dose com todos os componentes também segura o intervalo', () {
      final status = avaliarCom([
        registro(codigoBase, DateTime(2026, 1, 10), numero: 1),
        registro(codigoCompleto, DateTime(2026, 7, 25)),
      ]);

      expect(status.estado, EstadoVacina.registrada);
    });

    test('sem componentes declarados, nenhuma vacina entra na contagem', () {
      // containsAll de um conjunto vazio é verdadeiro para toda regra: sem a
      // guarda, qualquer dose do calendário contaria como dose desta vacina.
      const codigoSemComponentes = 'SEM_COMPONENTES_DE_TESTE';

      final calendarioSemComponentes = <RegraCalendario>[
        const RegraDependeHistorico(
          codigo: codigoSemComponentes,
          nomeExibicao: 'Sem componentes de teste',
          versaoCalendario: versaoCalendarioPni2026,
          dosesDoEsquemaBasico: 2,
          reiniciaEsquemaIniciado: false,
          intervaloRecomendadoDesdeUltimaDose: Intervalo.dias(60),
        ),
        const RegraDependeTemporada(
          codigo: 'OUTRA_DE_TESTE',
          nomeExibicao: 'Outra de teste',
          versaoCalendario: versaoCalendarioPni2026,
          dosesPorTemporada: 1,
        ),
      ];

      final status = VacinasEngine.avaliar(
        diasGestacaoBruto: 200,
        dum: dum,
        dataAtual: DateTime(2026, 8, 1),
        historico: [
          registro(codigoSemComponentes, DateTime(2026, 1, 10), numero: 1),
          registro('OUTRA_DE_TESTE', DateTime(2026, 3, 10)),
        ],
        calendario: calendarioSemComponentes,
      ).firstWhere((s) => s.vacinaCodigo == codigoSemComponentes);

      expect(status.estado, EstadoVacina.verificarHistorico);
      expect(status.estado, isNot(EstadoVacina.registrada));
      expect(status.motivo, contains('componentes'));
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
