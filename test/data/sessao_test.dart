import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/chutes_data.dart';
import 'package:suacontracao_ai/data/consultas_data.dart';
import 'package:suacontracao_ai/data/contracoes_data.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/data/sessao.dart';
import 'package:suacontracao_ai/data/sintomas_data.dart';
import 'package:suacontracao_ai/models/chute_sessao.dart';
import 'package:suacontracao_ai/models/consulta.dart';
import 'package:suacontracao_ai/models/contracao.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
import 'package:suacontracao_ai/models/registro_sintomas.dart';
import 'package:suacontracao_ai/theme/app_theme.dart';

void main() {
  late GestacaoInfo gestacaoOriginal;
  late ThemeMode temaOriginal;

  setUp(() {
    gestacaoOriginal = gestacaoAtual;
    temaOriginal = themeNotifier.value;
  });

  tearDown(() {
    gestacaoAtual = gestacaoOriginal;
    themeNotifier.value = temaOriginal;
    listaContracoes = [];
    listaChutes = [];
    listaSintomas = [];
    listaConsultas = [];
  });

  void popularTudo() {
    definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');
    listaContracoes = [
      Contracao(
        inicio: '08:00',
        fim: '08:01',
        intensidade: 'Leve',
        observacoes: '',
      ),
    ];
    listaChutes = [
      ChuteSessao(
        data: '2026-01-05',
        horaInicio: '08:00',
        horaFim: '08:30',
        totalChutes: 10,
        completa: true,
      ),
    ];
    listaSintomas = [RegistroSintomas(data: '2026-01-05', humor: 4)];
    listaConsultas = [
      Consulta(
        id: 'c1',
        titulo: 'Pré-natal',
        profissional: 'Dra. Ana',
        data: '2026-01-10',
        hora: '09:00',
      ),
    ];
  }

  group('encerrarGestacao', () {
    test('descarta a DUM configurada', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();

      expect(gestacaoAtual.dum, isNot(DateTime(2026, 1, 5)));
    });

    test('descarta o id da gestação', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();

      expect(gestacaoAtual.id, isNull);
    });

    test('a gestação deixa de estar configurada', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();

      expect(gestacaoAtual.configurada, isFalse);
    });

    test('restaura um placeholder utilizável, não um nulo', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();

      expect(gestacaoAtual.semanaAtual, greaterThan(0));
      expect(gestacaoAtual.semanaAtual, lessThanOrEqualTo(42));
    });

    test('é idempotente', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();
      encerrarGestacao();

      expect(gestacaoAtual.id, isNull);
      expect(gestacaoAtual.dum, isNot(DateTime(2026, 1, 5)));
    });

    test('a gestação encerrada não é adotada como legada por engano', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      encerrarGestacao();
      atualizarDUM(DateTime(2026, 2, 2));

      expect(gestacaoAtual.id, isNull);
    });
  });

  group('limparEstadoDaSessao', () {
    test('limpa as quatro listas em memória', () {
      popularTudo();

      limparEstadoDaSessao();

      expect(listaContracoes, isEmpty);
      expect(listaChutes, isEmpty);
      expect(listaSintomas, isEmpty);
      expect(listaConsultas, isEmpty);
    });

    test('descarta a identidade da gestação', () {
      popularTudo();

      limparEstadoDaSessao();

      expect(gestacaoAtual.configurada, isFalse);
      expect(gestacaoAtual.id, isNull);
      expect(gestacaoAtual.dum, isNot(DateTime(2026, 1, 5)));
    });

    test('não altera o tema escolhido no aparelho', () {
      popularTudo();
      themeNotifier.value = ThemeMode.dark;

      limparEstadoDaSessao();

      expect(themeNotifier.value, ThemeMode.dark);
    });

    test('é idempotente', () {
      popularTudo();

      limparEstadoDaSessao();
      limparEstadoDaSessao();

      expect(listaContracoes, isEmpty);
      expect(listaConsultas, isEmpty);
      expect(gestacaoAtual.id, isNull);
    });

    test('funciona com o estado já vazio', () {
      expect(limparEstadoDaSessao, returnsNormally);
      expect(listaChutes, isEmpty);
    });

    test('as listas seguem utilizáveis depois da limpeza', () {
      popularTudo();

      limparEstadoDaSessao();
      listaSintomas.add(RegistroSintomas(data: '2026-03-01'));

      expect(listaSintomas, hasLength(1));
    });
  });
}
