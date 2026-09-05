import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/vacinas_calendario_2026.dart';
import 'package:suacontracao_ai/data/vacinas_ui.dart';
import 'package:suacontracao_ai/services/vacinas_engine.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

void main() {
  // Só o código executável interessa nas inspeções de fonte.
  List<String> linhasDeCodigo() {
    return File('lib/data/vacinas_ui.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .toList();
  }

  group('apresentacaoDe — cobertura dos estados', () {
    test('todos os estados de EstadoVacina têm apresentação', () {
      expect(EstadoVacina.values, hasLength(7));

      for (final estado in EstadoVacina.values) {
        final apresentacao = apresentacaoDe(estado);

        expect(apresentacao.rotulo, isNotEmpty, reason: estado.codigo);
        expect(apresentacao.rotulo.trim(), apresentacao.rotulo,
            reason: estado.codigo);
      }
    });

    test('cada um dos sete estados tem o mapeamento aprovado', () {
      final esperado = <EstadoVacina, ApresentacaoDeEstado>{
        EstadoVacina.periodoRecomendado: const ApresentacaoDeEstado(
          rotulo: 'Período recomendado',
          icone: Icons.event_available,
          fundo: AppColors.statGreen,
        ),
        EstadoVacina.aguardarIntervalo: const ApresentacaoDeEstado(
          rotulo: 'Aguardando intervalo',
          icone: Icons.hourglass_bottom,
          fundo: AppColors.statOrange,
        ),
        EstadoVacina.verificarHistorico: const ApresentacaoDeEstado(
          rotulo: 'Verificar histórico',
          icone: Icons.help_outline,
          fundo: AppColors.statOrange,
        ),
        EstadoVacina.avaliacaoProfissional: const ApresentacaoDeEstado(
          rotulo: 'Avaliação profissional',
          icone: Icons.medical_services_outlined,
          fundo: AppColors.statPurple,
        ),
        EstadoVacina.naoDisponivel: const ApresentacaoDeEstado(
          rotulo: 'Ainda não',
          icone: Icons.schedule,
          fundo: AppColors.statPurple,
        ),
        EstadoVacina.registrada: const ApresentacaoDeEstado(
          rotulo: 'Registrada',
          icone: Icons.check_circle_outline,
          fundo: AppColors.statGreen,
        ),
        EstadoVacina.naoIndicada: const ApresentacaoDeEstado(
          rotulo: 'Não indicada',
          icone: Icons.remove_circle_outline,
          fundo: AppColors.statPurple,
        ),
      };

      // O mapa cobre o enum inteiro, sem estado de fora nem estado a mais.
      expect(esperado.keys.toSet(), EstadoVacina.values.toSet());

      esperado.forEach((estado, referencia) {
        final obtida = apresentacaoDe(estado);

        expect(obtida.rotulo, referencia.rotulo, reason: estado.codigo);
        expect(obtida.icone, referencia.icone, reason: estado.codigo);
        expect(obtida.fundo, same(referencia.fundo), reason: estado.codigo);
      });
    });

    test('os rótulos são distintos entre si', () {
      final rotulos =
          EstadoVacina.values.map((e) => apresentacaoDe(e).rotulo).toList();

      expect(rotulos.toSet(), hasLength(rotulos.length));
    });

    test('nenhum estado é mapeado para outra cor além das três aprovadas', () {
      const aprovadas = <CorDeSuperficie>[
        AppColors.statGreen,
        AppColors.statOrange,
        AppColors.statPurple,
      ];

      for (final estado in EstadoVacina.values) {
        expect(aprovadas, contains(apresentacaoDe(estado).fundo),
            reason: estado.codigo);
      }
    });

    test('o mapeamento é estável entre chamadas', () {
      for (final estado in EstadoVacina.values) {
        final a = apresentacaoDe(estado);
        final b = apresentacaoDe(estado);

        expect(a.rotulo, b.rotulo);
        expect(a.icone, b.icone);
        expect(a.fundo, same(b.fundo));
      }
    });
  });

  group('apresentacaoDe — os rótulos não são clínicos', () {
    test('nenhum rótulo usa linguagem prescritiva', () {
      const proibidos = [
        'tome agora',
        'você precisa tomar',
        'você está atrasada',
        'tome ',
        'atrasad',
        'precisa',
        'urgente',
        'obrigat',
      ];

      for (final estado in EstadoVacina.values) {
        final rotulo = apresentacaoDe(estado).rotulo.toLowerCase();

        for (final termo in proibidos) {
          expect(rotulo, isNot(contains(termo)),
              reason: '${estado.codigo}: $termo');
        }
      }
    });

    test('os rótulos são curtos: são chips, não mensagem clínica', () {
      for (final estado in EstadoVacina.values) {
        expect(apresentacaoDe(estado).rotulo.length, lessThanOrEqualTo(24),
            reason: estado.codigo);
      }
    });

    test('nenhum rótulo repete a mensagem da engine', () {
      const mensagens = [
        mensagemPeriodoRecomendado,
        mensagemAguardarIntervalo,
        mensagemAguardarRecomendado,
        mensagemVerificarHistorico,
        mensagemAvaliacaoProfissional,
        mensagemGestacaoIndeterminada,
        mensagemJanelaNaoAberta,
        mensagemDoseRegistrada,
      ];

      // A mensagem clínica continua vindo de StatusVacinacao.mensagem; o
      // rótulo é só a etiqueta do chip.
      for (final estado in EstadoVacina.values) {
        expect(mensagens, isNot(contains(apresentacaoDe(estado).rotulo)),
            reason: estado.codigo);
      }
    });
  });

  group('apresentacaoDe — é apresentação pura', () {
    test('a função não recebe BuildContext', () {
      final assinatura = linhasDeCodigo()
          .where((linha) => linha.contains('ApresentacaoDeEstado apresentacaoDe('))
          .toList();

      expect(assinatura, hasLength(1));
      expect(assinatura.single, contains('(EstadoVacina estado)'));
      expect(assinatura.single, isNot(contains('BuildContext')));
    });

    test('o estado é decidido sem BuildContext em tempo de execução', () {
      // Nenhuma chamada deste arquivo passa contexto: a cor resolvida
      // depois é escolha do widget, não deste mapeamento.
      for (final estado in EstadoVacina.values) {
        expect(() => apresentacaoDe(estado), returnsNormally);
      }
    });

    test('o switch é exaustivo e não usa default', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, contains('switch (estado)'));
      expect(codigo, isNot(contains('default:')));
      expect(codigo, isNot(contains('_:')));
    });

    test('há um case para cada valor de EstadoVacina', () {
      final codigo = linhasDeCodigo().join('\n');

      for (final estado in EstadoVacina.values) {
        expect(codigo, contains('case EstadoVacina.${estado.name}:'),
            reason: estado.codigo);
      }
    });

    test('não importa Firebase nem o storage de vacinas', () {
      final imports = linhasDeCodigo()
          .where((linha) => linha.trimLeft().startsWith('import '))
          .toList();

      expect(imports, isNotEmpty, reason: 'sanidade: o arquivo tem imports');

      for (final linha in imports) {
        expect(linha, isNot(contains('cloud_firestore')), reason: linha);
        expect(linha, isNot(contains('firebase_auth')), reason: linha);
        expect(linha, isNot(contains('firebase_core')), reason: linha);
        expect(linha, isNot(contains('vacinas_storage')), reason: linha);
      }
    });

    test('da engine importa apenas o enum de estados', () {
      final daEngine = linhasDeCodigo()
          .where((linha) => linha.contains('vacinas_engine.dart'))
          .toList();

      expect(daEngine, hasLength(1));
      expect(daEngine.single, contains('show EstadoVacina'));
    });

    test('não define cor, data nem intervalo próprios', () {
      final codigo = linhasDeCodigo().join('\n');

      expect(codigo, isNot(contains('Color(0x')));
      // \b impede que AppColors.statGreen seja lido como Colors.statGreen.
      expect(codigo, isNot(matches(RegExp(r'\bColors\.'))));
      expect(codigo, isNot(contains('DateTime')));
      expect(codigo, isNot(contains('Duration')));
      expect(codigo, isNot(contains('VacinasEngine')));
      expect(codigo, isNot(contains('RegistroVacinacao')));
    });
  });
}
