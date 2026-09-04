import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';

void main() {
  group('Calendário PNI-2026 — composição', () {
    test('contém exatamente as sete recomendações da gestante', () {
      expect(calendarioPni2026, hasLength(7));

      expect(
        calendarioPni2026.map((r) => r.codigo).toSet(),
        {
          'HEPATITE_B',
          'DT',
          'INFLUENZA',
          'COVID_19',
          'DTPA',
          'VSR',
          'FEBRE_AMARELA',
        },
      );
    });

    test('os códigos são únicos', () {
      final codigos = calendarioPni2026.map((r) => r.codigo).toList();
      expect(codigos.toSet().length, codigos.length);
    });

    test('nenhum código é vazio e nenhum nome de exibição é vazio', () {
      for (final regra in calendarioPni2026) {
        expect(regra.codigo, isNotEmpty, reason: 'código vazio');
        expect(regra.nomeExibicao, isNotEmpty, reason: '${regra.codigo} sem nome');
      }
    });

    test('todas as regras declaram a versão PNI-2026', () {
      expect(versaoCalendarioPni2026, 'PNI-2026');

      for (final regra in calendarioPni2026) {
        expect(regra.versaoCalendario, 'PNI-2026', reason: regra.codigo);
      }
    });

    test('regraPorCodigo encontra todas e devolve null para desconhecido', () {
      for (final regra in calendarioPni2026) {
        expect(regraPorCodigo(regra.codigo), same(regra));
      }

      expect(regraPorCodigo('VACINA_INEXISTENTE'), isNull);
      expect(regraPorCodigo(''), isNull);
    });
  });

  group('Janelas automáticas', () {
    test('dTpa abre na 20ª semana', () {
      final dtpa = regraPorCodigo(codigoDtpa);

      expect(dtpa, isA<RegraJanelaSemana>());
      expect((dtpa as RegraJanelaSemana).semanaInicial, 20);
    });

    test('VSR abre na 28ª semana', () {
      final vsr = regraPorCodigo(codigoVsr);

      expect(vsr, isA<RegraJanelaSemana>());
      expect((vsr as RegraJanelaSemana).semanaInicial, 28);
    });

    test('dTpa e VSR preveem 1 dose por gestação', () {
      expect(regraPorCodigo(codigoDtpa)!.dosesPorGestacao, 1);
      expect(regraPorCodigo(codigoVsr)!.dosesPorGestacao, 1);
    });

    test('dTpa declara diftérico, tetânico e pertussis na composição', () {
      expect(regraPorCodigo(codigoDtpa)!.composicao, {
        ComponenteVacinal.difterico,
        ComponenteVacinal.tetanico,
        ComponenteVacinal.pertussis,
      });
    });

    test('apenas dTpa e VSR são janelas por semana', () {
      final janelas = calendarioPni2026
          .whereType<RegraJanelaSemana>()
          .map((r) => r.codigo)
          .toSet();

      expect(janelas, {codigoDtpa, codigoVsr});
    });

    test('as janelas não exigem avaliação profissional para abrir', () {
      for (final regra in calendarioPni2026.whereType<RegraJanelaSemana>()) {
        expect(regra.exigeAvaliacaoProfissional, isFalse, reason: regra.codigo);
      }
    });
  });

  group('Febre amarela — excepcional, nunca janela automática', () {
    test('é marcada como avaliação profissional', () {
      final febreAmarela = regraPorCodigo(codigoFebreAmarela);

      expect(febreAmarela, isA<RegraAvaliacaoProfissional>());
      expect(febreAmarela!.exigeAvaliacaoProfissional, isTrue);
      expect(febreAmarela.categoria, CategoriaVacina.excepcional);
    });

    test('não é uma janela por semana e não carrega semana inicial', () {
      final febreAmarela = regraPorCodigo(codigoFebreAmarela)!;

      // A garantia é estrutural: RegraAvaliacaoProfissional não tem onde
      // guardar uma semana inicial, então não há como reinterpretá-la como
      // janela automática sem trocar o tipo da regra.
      expect(febreAmarela, isNot(isA<RegraJanelaSemana>()));
    });

    test('é a única regra que exige avaliação profissional', () {
      final queExigem = calendarioPni2026
          .where((r) => r.exigeAvaliacaoProfissional)
          .map((r) => r.codigo)
          .toSet();

      expect(queExigem, {codigoFebreAmarela});
    });

    test('não carrega nenhum parâmetro que abra uma janela', () {
      final febreAmarela = regraPorCodigo(codigoFebreAmarela)!;

      // Nem semana (o tipo não tem o campo), nem contagem por gestação que
      // pudesse ser lida como uma dose devida nesta gestação.
      expect(febreAmarela, isNot(isA<RegraJanelaSemana>()));
      expect(febreAmarela, isNot(isA<RegraDependeHistorico>()));
      expect(febreAmarela, isNot(isA<RegraDependeTemporada>()));
      expect(febreAmarela, isNot(isA<RegraDependeIntervaloUltimaDose>()));
      expect(febreAmarela.dosesPorGestacao, isNull);
    });
  });

  group('Vacinas condicionais — tipo de avaliação', () {
    test('hepatite B e dT dependem do histórico vacinal', () {
      expect(regraPorCodigo(codigoHepatiteB), isA<RegraDependeHistorico>());
      expect(regraPorCodigo(codigoDt), isA<RegraDependeHistorico>());
    });

    test('influenza depende da temporada', () {
      expect(regraPorCodigo(codigoInfluenza), isA<RegraDependeTemporada>());
    });

    test('COVID-19 depende do intervalo desde a última dose', () {
      expect(
        regraPorCodigo(codigoCovid19),
        isA<RegraDependeIntervaloUltimaDose>(),
      );
    });

    test('hepatite B tem esquema básico de 3 doses e não reinicia o iniciado', () {
      final hepatiteB = regraPorCodigo(codigoHepatiteB) as RegraDependeHistorico;

      expect(hepatiteB.dosesDoEsquemaBasico, 3);
      expect(hepatiteB.reiniciaEsquemaIniciado, isFalse);
    });

    test('hepatite B define os três intervalos entre doses do esquema', () {
      final hepatiteB = regraPorCodigo(codigoHepatiteB) as RegraDependeHistorico;

      expect(hepatiteB.intervalosEntreDoses, hasLength(3));
      expect(
        hepatiteB.intervalosEntreDoses.map((i) => '${i.doseInicial}-${i.doseFinal}'),
        containsAll(['1-2', '2-3', '1-3']),
      );
    });

    IntervaloEntreDoses parDaHepatiteB(int inicial, int fim) {
      final hepatiteB = regraPorCodigo(codigoHepatiteB) as RegraDependeHistorico;
      return hepatiteB.intervalosEntreDoses
          .firstWhere((i) => i.doseInicial == inicial && i.doseFinal == fim);
    }

    test('hepatite B: 1ª para 2ª dose — recomendado e mínimo de 1 mês', () {
      final par = parDaHepatiteB(1, 2);

      expect(par.recomendado, const Intervalo.meses(1));
      expect(par.minimo, const Intervalo.meses(1));
    });

    test('hepatite B: 2ª para 3ª dose — mínimo de 2 meses', () {
      final par = parDaHepatiteB(2, 3);
      expect(par.minimo, const Intervalo.meses(2));
    });

    test('hepatite B: 1ª para 3ª dose — recomendado 6 meses, mínimo 4 meses', () {
      final par = parDaHepatiteB(1, 3);

      expect(par.recomendado, const Intervalo.meses(6));
      expect(par.minimo, const Intervalo.meses(4));
    });

    test('hepatite B não usa intervalo desde a última dose nem componentes', () {
      final hepatiteB = regraPorCodigo(codigoHepatiteB) as RegraDependeHistorico;

      expect(hepatiteB.intervaloRecomendadoDesdeUltimaDose, isNull);
      expect(hepatiteB.intervaloMinimoExcepcionalDesdeUltimaDose, isNull);
      expect(hepatiteB.componentesDoIntervalo, isEmpty);
    });

    test('dT tem esquema básico de 3 doses', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;
      expect(dt.dosesDoEsquemaBasico, 3);
    });

    test('dT não reinicia esquema já iniciado', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;
      expect(dt.reiniciaEsquemaIniciado, isFalse);
    });

    test('dT tem intervalo recomendado de 60 dias', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;
      expect(dt.intervaloRecomendadoDesdeUltimaDose, const Intervalo.dias(60));
    });

    test('dT tem mínimo excepcional de 30 dias', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;
      expect(
        dt.intervaloMinimoExcepcionalDesdeUltimaDose,
        const Intervalo.dias(30),
      );
    });

    test('o intervalo do dT é contado sobre componentes diftérico e tetânico', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;

      expect(dt.componentesDoIntervalo, {
        ComponenteVacinal.difterico,
        ComponenteVacinal.tetanico,
      });
    });

    test('influenza prevê 1 dose por temporada, sem datas fixas', () {
      final influenza = regraPorCodigo(codigoInfluenza) as RegraDependeTemporada;

      expect(influenza.dosesPorTemporada, 1);
      // A temporada vigente não é parâmetro do calendário: determiná-la é
      // responsabilidade de um serviço explícito na engine.
      expect(influenza.dosesPorGestacao, isNull);
    });

    test('COVID-19 tem intervalo mínimo de 6 meses e 1 dose por gestação', () {
      final covid = regraPorCodigo(codigoCovid19) as RegraDependeIntervaloUltimaDose;

      expect(covid.intervaloMinimoDesdeUltimaDose, const Intervalo.meses(6));
      expect(covid.dosesPorGestacao, 1);
    });

    test('as quatro condicionais estão na categoria condicional', () {
      for (final codigo in [codigoHepatiteB, codigoDt, codigoInfluenza, codigoCovid19]) {
        expect(
          regraPorCodigo(codigo)!.categoria,
          CategoriaVacina.condicional,
          reason: codigo,
        );
      }
    });

    test('nenhuma condicional é tratada como janela por semana', () {
      for (final codigo in [codigoHepatiteB, codigoDt, codigoInfluenza, codigoCovid19]) {
        expect(
          regraPorCodigo(codigo),
          isNot(isA<RegraJanelaSemana>()),
          reason: codigo,
        );
      }
    });
  });

  group('Parâmetros — nada impossível nem contraditório', () {
    test('semanas iniciais ficam dentro da faixa gestacional', () {
      for (final regra in calendarioPni2026.whereType<RegraJanelaSemana>()) {
        expect(regra.semanaInicial, greaterThanOrEqualTo(1), reason: regra.codigo);
        expect(regra.semanaInicial, lessThanOrEqualTo(42), reason: regra.codigo);
      }
    });

    test('VSR abre depois de dTpa, como define a especificação', () {
      final dtpa = regraPorCodigo(codigoDtpa) as RegraJanelaSemana;
      final vsr = regraPorCodigo(codigoVsr) as RegraJanelaSemana;

      expect(vsr.semanaInicial, greaterThan(dtpa.semanaInicial));
    });

    test('categoria e tipo de regra não se contradizem', () {
      for (final regra in calendarioPni2026) {
        switch (regra) {
          case RegraJanelaSemana():
            expect(regra.categoria, CategoriaVacina.janelaAutomatica,
                reason: regra.codigo);
          case RegraAvaliacaoProfissional():
            expect(regra.categoria, CategoriaVacina.excepcional,
                reason: regra.codigo);
          case RegraDependeHistorico():
          case RegraDependeTemporada():
          case RegraDependeIntervaloUltimaDose():
            expect(regra.categoria, CategoriaVacina.condicional,
                reason: regra.codigo);
        }
      }
    });

    test('todas as sete regras têm parâmetros completos nesta versão', () {
      // Ausência de parâmetro seria sinalizada, não silenciosa: a engine
      // precisa distinguir "não há exigência" de "o dado não foi definido".
      final pendentes = calendarioPni2026
          .where((r) => !r.parametrosCompletos)
          .map((r) => r.codigo)
          .toSet();

      expect(pendentes, isEmpty);
      expect(calendarioPni2026.every((r) => r.parametrosCompletos), isTrue);
    });

    test('nenhuma regra de histórico fica sem conduta sobre reinício', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        expect(regra.reiniciaEsquemaIniciado, isFalse, reason: regra.codigo);
      }
    });

    test('contagens de doses são positivas quando definidas', () {
      for (final regra in calendarioPni2026) {
        final porGestacao = regra.dosesPorGestacao;
        if (porGestacao != null) {
          expect(porGestacao, greaterThan(0), reason: regra.codigo);
        }

        switch (regra) {
          case RegraDependeHistorico():
            expect(regra.dosesDoEsquemaBasico, greaterThan(0), reason: regra.codigo);
          case RegraDependeTemporada():
            expect(regra.dosesPorTemporada, greaterThan(0), reason: regra.codigo);
          case RegraDependeIntervaloUltimaDose():
            expect(regra.intervaloMinimoDesdeUltimaDose.valor, greaterThan(0),
                reason: regra.codigo);
          case RegraJanelaSemana():
          case RegraAvaliacaoProfissional():
            break;
        }
      }
    });

    test('o mínimo excepcional nunca excede o intervalo recomendado', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        final recomendado = regra.intervaloRecomendadoDesdeUltimaDose;
        final excepcional = regra.intervaloMinimoExcepcionalDesdeUltimaDose;

        if (recomendado != null && excepcional != null) {
          expect(excepcional.unidade, recomendado.unidade, reason: regra.codigo);
          expect(excepcional.valor, lessThanOrEqualTo(recomendado.valor),
              reason: regra.codigo);
          expect(excepcional.valor, greaterThan(0), reason: regra.codigo);
        }
      }
    });

    test('intervalo declarado sempre vem com os componentes que o qualificam', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        if (regra.intervaloRecomendadoDesdeUltimaDose != null) {
          expect(regra.componentesDoIntervalo, isNotEmpty, reason: regra.codigo);
        }
      }
    });

    test('regras sem intervalo não carregam componentes soltos', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        if (regra.intervaloRecomendadoDesdeUltimaDose == null) {
          expect(regra.componentesDoIntervalo, isEmpty, reason: regra.codigo);
        }
      }
    });

    test('intervalos entre doses referenciam doses do próprio esquema', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        for (final par in regra.intervalosEntreDoses) {
          expect(par.doseInicial, greaterThanOrEqualTo(1), reason: regra.codigo);
          expect(par.doseFinal, greaterThan(par.doseInicial), reason: regra.codigo);
          expect(par.doseFinal, lessThanOrEqualTo(regra.dosesDoEsquemaBasico),
              reason: regra.codigo);
        }
      }
    });

    test('em cada par de doses, o mínimo nunca excede o recomendado', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        for (final par in regra.intervalosEntreDoses) {
          final recomendado = par.recomendado;
          final minimo = par.minimo;
          if (recomendado != null && minimo != null) {
            expect(minimo.unidade, recomendado.unidade, reason: '${regra.codigo} $par');
            expect(minimo.valor, lessThanOrEqualTo(recomendado.valor),
                reason: '${regra.codigo} $par');
          }
        }
      }
    });

    test('não há pares de doses duplicados no mesmo esquema', () {
      for (final regra in calendarioPni2026.whereType<RegraDependeHistorico>()) {
        final pares = regra.intervalosEntreDoses
            .map((i) => '${i.doseInicial}-${i.doseFinal}')
            .toList();
        expect(pares.toSet().length, pares.length, reason: regra.codigo);
      }
    });

    test('regras que não se organizam por gestação não declaram dose por gestação', () {
      // Hepatite B e dT são esquema de vida; influenza é por temporada.
      for (final codigo in [codigoHepatiteB, codigoDt, codigoInfluenza]) {
        expect(regraPorCodigo(codigo)!.dosesPorGestacao, isNull, reason: codigo);
      }
    });

    test('os códigos de componente são estáveis e distintos', () {
      expect(ComponenteVacinal.difterico.codigo, 'DIFTERICO');
      expect(ComponenteVacinal.tetanico.codigo, 'TETANICO');
      expect(ComponenteVacinal.pertussis.codigo, 'PERTUSSIS');

      final codigos = ComponenteVacinal.values.map((c) => c.codigo).toSet();
      expect(codigos.length, ComponenteVacinal.values.length);
    });

    test('as unidades de intervalo são estáveis e distintas', () {
      expect(UnidadeIntervalo.dias.codigo, 'DIAS');
      expect(UnidadeIntervalo.meses.codigo, 'MESES');

      final codigos = UnidadeIntervalo.values.map((u) => u.codigo).toSet();
      expect(codigos.length, UnidadeIntervalo.values.length);
    });

    test('Intervalo compara por valor e unidade, sem converter entre elas', () {
      expect(const Intervalo.dias(60), const Intervalo.dias(60));
      expect(const Intervalo.meses(6), const Intervalo.meses(6));

      // 30 dias e 1 mês não são declarados equivalentes: converter é
      // decisão da engine, não do calendário.
      expect(const Intervalo.dias(30), isNot(const Intervalo.meses(1)));
      expect(const Intervalo.dias(60), isNot(const Intervalo.dias(30)));
    });
  });

  group('Composição — quais doses contam para os intervalos do dT', () {
    test('dT e dTpa contêm diftérico e tetânico', () {
      final comAmbos = codigosComComponentes({
        ComponenteVacinal.difterico,
        ComponenteVacinal.tetanico,
      });

      expect(comAmbos, containsAll([codigoDt, codigoDtpa]));
    });

    test('uma dose de dTpa satisfaz os componentes do intervalo do dT', () {
      final dt = regraPorCodigo(codigoDt) as RegraDependeHistorico;
      final dtpa = regraPorCodigo(codigoDtpa)!;

      // É este dado que permitirá à engine contar uma dose de dTpa no
      // intervalo do dT, sem precisar saber composição de vacina sozinha.
      expect(dtpa.composicao.containsAll(dt.componentesDoIntervalo), isTrue);
    });

    test('vacinas sem composição declarada não entram na contagem', () {
      final comAmbos = codigosComComponentes({
        ComponenteVacinal.difterico,
        ComponenteVacinal.tetanico,
      });

      expect(comAmbos, isNot(contains(codigoHepatiteB)));
      expect(comAmbos, isNot(contains(codigoInfluenza)));
      expect(comAmbos, isNot(contains(codigoCovid19)));
      expect(comAmbos, isNot(contains(codigoVsr)));
      expect(comAmbos, isNot(contains(codigoFebreAmarela)));
    });

    test('pertussis está apenas na dTpa', () {
      expect(
        codigosComComponentes({ComponenteVacinal.pertussis}),
        {codigoDtpa},
      );
    });

    test('consulta sem componentes devolve conjunto vazio', () {
      expect(codigosComComponentes(const {}), isEmpty);
    });

    test('os códigos de categoria são estáveis e distintos', () {
      expect(CategoriaVacina.janelaAutomatica.codigo, 'JANELA_AUTOMATICA');
      expect(CategoriaVacina.condicional.codigo, 'CONDICIONAL');
      expect(CategoriaVacina.excepcional.codigo, 'EXCEPCIONAL');

      final codigos = CategoriaVacina.values.map((c) => c.codigo).toSet();
      expect(codigos.length, CategoriaVacina.values.length);
    });
  });

  group('Mensagens aprovadas', () {
    test('mensagem de período recomendado bate com o texto aprovado', () {
      expect(
        mensagemPeriodoRecomendado,
        'Você entrou no período recomendado para esta vacina. '
        'Confirme a indicação e a aplicação com a equipe de saúde.',
      );
    });

    test('mensagem geral bate com o texto aprovado', () {
      expect(
        mensagemGeralVacinas,
        'As informações desta tela são baseadas no Calendário Nacional de '
        'Vacinação do Ministério da Saúde. Elas têm caráter informativo e '
        'não substituem a avaliação da equipe de saúde. Mantenha seu Cartão '
        'de Vacinas atualizado e confirme as orientações para sua gestação '
        'com um profissional de saúde.',
      );
    });

    test('as mensagens não são prescritivas', () {
      const proibidos = [
        'tome agora',
        'você precisa tomar',
        'você está atrasada',
      ];

      for (final mensagem in [mensagemPeriodoRecomendado, mensagemGeralVacinas]) {
        final texto = mensagem.toLowerCase();
        for (final termo in proibidos) {
          expect(texto, isNot(contains(termo)), reason: termo);
        }
      }
    });
  });

  group('Determinismo', () {
    test('a lista é constante: mesma ordem e mesmas instâncias', () {
      final primeira = calendarioPni2026;
      final segunda = calendarioPni2026;

      expect(identical(primeira, segunda), isTrue);
      expect(primeira.map((r) => r.codigo).toList(),
          segunda.map((r) => r.codigo).toList());
    });

    test('a ordem das regras é estável', () {
      expect(
        calendarioPni2026.map((r) => r.codigo).toList(),
        [
          codigoHepatiteB,
          codigoDt,
          codigoInfluenza,
          codigoCovid19,
          codigoDtpa,
          codigoVsr,
          codigoFebreAmarela,
        ],
      );
    });

    test('consultas repetidas devolvem sempre o mesmo resultado', () {
      for (var i = 0; i < 3; i++) {
        expect(regraPorCodigo(codigoDtpa), same(regraPorCodigo(codigoDtpa)));
        expect(
          (regraPorCodigo(codigoVsr)! as RegraJanelaSemana).semanaInicial,
          28,
        );
      }
    });
  });
}
