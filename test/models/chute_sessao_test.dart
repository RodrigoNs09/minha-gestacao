import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/models/chute_sessao.dart';
import 'package:suacontracao_ai/screens/historico_chutes_screen.dart';

void main() {
  group('ChuteSessao.toMap / fromMap', () {
    test('toMap gera todos os campos esperados', () {
      final sessao = ChuteSessao(
        data: '2026-09-02',
        horaInicio: '14:00',
        horaFim: '14:12',
        totalChutes: 10,
        completa: true,
      );

      expect(sessao.toMap(), {
        'data': '2026-09-02',
        'horaInicio': '14:00',
        'horaFim': '14:12',
        'totalChutes': 10,
        'completa': true,
      });
    });

    test('fromMap reconstrói os campos a partir do map', () {
      final sessao = ChuteSessao.fromMap({
        'data': '2026-09-02',
        'horaInicio': '14:00',
        'horaFim': '14:12',
        'totalChutes': 10,
        'completa': true,
      });

      expect(sessao.data, '2026-09-02');
      expect(sessao.horaInicio, '14:00');
      expect(sessao.horaFim, '14:12');
      expect(sessao.totalChutes, 10);
      expect(sessao.completa, isTrue);
    });

    test('fromMap aplica defaults quando campos estão ausentes', () {
      final sessao = ChuteSessao.fromMap(const {});

      expect(sessao.data, '');
      expect(sessao.horaInicio, '');
      expect(sessao.horaFim, '');
      expect(sessao.totalChutes, 0);
      expect(sessao.completa, isFalse);
    });

    test('ida e volta preserva os valores, inclusive sessão incompleta', () {
      final original = ChuteSessao(
        data: '2026-01-15',
        horaInicio: '09:05',
        horaFim: '09:40',
        totalChutes: 7,
        completa: false,
      );

      final reconstruida = ChuteSessao.fromMap(original.toMap());

      expect(reconstruida.data, original.data);
      expect(reconstruida.horaInicio, original.horaInicio);
      expect(reconstruida.horaFim, original.horaFim);
      expect(reconstruida.totalChutes, original.totalChutes);
      expect(reconstruida.completa, original.completa);
    });
  });

  group('duracaoDaSessao', () {
    ChuteSessao sessaoCom({required String inicio, required String fim}) {
      return ChuteSessao(
        data: '2026-09-02',
        horaInicio: inicio,
        horaFim: fim,
        totalChutes: 10,
        completa: true,
      );
    }

    test('calcula a duração dentro da mesma hora', () {
      final sessao = sessaoCom(inicio: '14:00', fim: '14:12');
      expect(duracaoDaSessao(sessao), const Duration(minutes: 12));
    });

    test('calcula a duração cruzando a hora', () {
      final sessao = sessaoCom(inicio: '13:50', fim: '14:05');
      expect(duracaoDaSessao(sessao), const Duration(minutes: 15));
    });

    test('início igual ao fim resulta em duração zero, não null', () {
      final sessao = sessaoCom(inicio: '10:00', fim: '10:00');
      expect(duracaoDaSessao(sessao), Duration.zero);
    });

    test('horaInicio vazia retorna null', () {
      final sessao = sessaoCom(inicio: '', fim: '14:12');
      expect(duracaoDaSessao(sessao), isNull);
    });

    test('horaFim malformada (não numérica) retorna null', () {
      final sessao = sessaoCom(inicio: '14:00', fim: 'ab:cd');
      expect(duracaoDaSessao(sessao), isNull);
    });

    test('formato sem separador de dois-pontos retorna null', () {
      final sessao = sessaoCom(inicio: '1400', fim: '1412');
      expect(duracaoDaSessao(sessao), isNull);
    });

    test('fim anterior ao início retorna null (dado malformado)', () {
      final sessao = sessaoCom(inicio: '14:12', fim: '14:00');
      expect(duracaoDaSessao(sessao), isNull);
    });
  });

  ChuteSessao sessaoValida({String? id}) => ChuteSessao(
    id: id,
    data: '2026-09-02',
    horaInicio: '14:00',
    horaFim: '14:12',
    totalChutes: 10,
    completa: true,
  );

  group('ChuteSessao — identidade', () {
    test('o id fica fora do mapa persistido', () {
      final mapa = sessaoValida(id: 'abc123').toMap();

      expect(mapa.containsKey('id'), isFalse);
      expect(mapa.keys.toSet(), {
        'data',
        'horaInicio',
        'horaFim',
        'totalChutes',
        'completa',
      });
    });

    test('o id vem do documento', () {
      final sessao = ChuteSessao.fromMap(
        sessaoValida().toMap(),
        idDoDocumento: 'doc-1',
      );

      expect(sessao.id, 'doc-1');
      expect(sessao.data, '2026-09-02');
      expect(sessao.totalChutes, 10);
    });

    test('sem id do documento a sessão fica sem identidade', () {
      expect(ChuteSessao.fromMap(sessaoValida().toMap()).id, isNull);
    });

    test('id vazio ou só espaços não vira identidade', () {
      for (final vazio in ['', '   ']) {
        expect(
          ChuteSessao.fromMap(const {}, idDoDocumento: vazio).id,
          isNull,
          reason: '"$vazio"',
        );
      }
    });

    test('comId carimba o id e preserva o resto', () {
      final carimbada = sessaoValida().comId('novo-id');

      expect(carimbada.id, 'novo-id');
      expect(carimbada.data, '2026-09-02');
      expect(carimbada.horaInicio, '14:00');
      expect(carimbada.horaFim, '14:12');
      expect(carimbada.totalChutes, 10);
      expect(carimbada.completa, isTrue);
    });

    test('comId não altera o mapa persistido', () {
      expect(sessaoValida().comId('x').toMap(), sessaoValida().toMap());
    });
  });

  group('ChuteSessao.fromMap — campos malformados', () {
    test('mapa vazio produz defaults seguros, sem lançar', () {
      final sessao = ChuteSessao.fromMap(const {});

      expect(sessao.data, '');
      expect(sessao.horaInicio, '');
      expect(sessao.horaFim, '');
      expect(sessao.totalChutes, 0);
      expect(sessao.completa, isFalse);
    });

    test('nulos explícitos não lançam', () {
      expect(
        () => ChuteSessao.fromMap(const {
          'data': null,
          'horaInicio': null,
          'horaFim': null,
          'totalChutes': null,
          'completa': null,
        }),
        returnsNormally,
      );
    });

    test('totalChutes como double vira inteiro', () {
      expect(ChuteSessao.fromMap(const {'totalChutes': 10.0}).totalChutes, 10);
    });

    test('totalChutes como texto numérico é aproveitado', () {
      expect(ChuteSessao.fromMap(const {'totalChutes': '10'}).totalChutes, 10);
    });

    test('totalChutes de tipo absurdo não lança e vira zero', () {
      for (final invalido in <Object>[
        'muitos',
        true,
        <int>[10],
        <String, int>{'n': 10},
      ]) {
        expect(
          () => ChuteSessao.fromMap({'totalChutes': invalido}),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          ChuteSessao.fromMap({'totalChutes': invalido}).totalChutes,
          0,
          reason: '$invalido',
        );
      }
    });

    test('completa como texto e como número é interpretada', () {
      expect(ChuteSessao.fromMap(const {'completa': 'true'}).completa, isTrue);
      expect(ChuteSessao.fromMap(const {'completa': 'TRUE'}).completa, isTrue);
      expect(ChuteSessao.fromMap(const {'completa': 'nao'}).completa, isFalse);
      expect(ChuteSessao.fromMap(const {'completa': 1}).completa, isTrue);
      expect(ChuteSessao.fromMap(const {'completa': 0}).completa, isFalse);
    });

    test('textos vindos como número não lançam e viram vazio', () {
      final sessao = ChuteSessao.fromMap(const {
        'data': 20260902,
        'horaInicio': 1400,
        'horaFim': <String>['14:12'],
      });

      expect(sessao.data, '');
      expect(sessao.horaInicio, '');
      expect(sessao.horaFim, '');
    });

    test('uma sessão malformada continua sendo endereçável', () {
      final sessao = ChuteSessao.fromMap(const {
        'totalChutes': 'x',
      }, idDoDocumento: 'doc-ruim');

      expect(sessao.id, 'doc-ruim');
    });
  });

  group('ProgressoDeChutes — leitura tolerante', () {
    test('lê uma contagem completa', () {
      final progresso = ProgressoDeChutes.deBruto(const {
        'chutes': 7,
        'data': '2026-09-02',
        'horaInicio': '2026-09-02T14:00:00.000',
        'sessaoId': 'sessao-1',
      });

      expect(progresso, isNotNull);
      expect(progresso!.chutes, 7);
      expect(progresso.data, '2026-09-02');
      expect(progresso.inicio, DateTime.parse('2026-09-02T14:00:00.000'));
      expect(progresso.sessaoId, 'sessao-1');
    });

    test('progresso antigo, sem sessaoId, continua legível', () {
      final progresso = ProgressoDeChutes.deBruto(const {
        'chutes': 10,
        'data': '2026-09-02',
        'horaInicio': '2026-09-02T14:00:00.000',
      });

      expect(progresso, isNotNull);
      expect(progresso!.chutes, 10);
      expect(progresso.sessaoId, isNull);
    });

    test('horário de início inválido vira nulo, sem lançar', () {
      final progresso = ProgressoDeChutes.deBruto(const {
        'chutes': 3,
        'data': '2026-09-02',
        'horaInicio': 'ontem à tarde',
      });

      expect(progresso, isNotNull);
      expect(progresso!.inicio, isNull);
    });

    test('valor que não é mapa devolve nulo', () {
      for (final invalido in <Object?>[
        null,
        'chute_em_andamento',
        7,
        <int>[1, 2],
      ]) {
        expect(
          () => ProgressoDeChutes.deBruto(invalido),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          ProgressoDeChutes.deBruto(invalido),
          isNull,
          reason: '$invalido',
        );
      }
    });

    test('contagem sem data ou sem chutes não é aproveitada', () {
      expect(ProgressoDeChutes.deBruto(const {'chutes': 5}), isNull);
      expect(ProgressoDeChutes.deBruto(const {'data': '2026-09-02'}), isNull);
      expect(
        ProgressoDeChutes.deBruto(const {'chutes': 0, 'data': '2026-09-02'}),
        isNull,
      );
    });

    test('chutes de tipo inesperado não lança', () {
      for (final invalido in <Object>[
        'cinco',
        true,
        <int>[5],
      ]) {
        expect(
          () => ProgressoDeChutes.deBruto({
            'chutes': invalido,
            'data': '2026-09-02',
          }),
          returnsNormally,
          reason: '$invalido',
        );
        expect(
          ProgressoDeChutes.deBruto({'chutes': invalido, 'data': '2026-09-02'}),
          isNull,
          reason: '$invalido',
        );
      }
    });

    test('chutes como texto numérico é aproveitado', () {
      final progresso = ProgressoDeChutes.deBruto(const {
        'chutes': '4',
        'data': '2026-09-02',
      });

      expect(progresso?.chutes, 4);
    });

    test('ida e volta preserva a contagem e o id da sessão', () {
      final original = ProgressoDeChutes(
        chutes: 6,
        data: '2026-09-02',
        inicio: DateTime(2026, 9, 2, 14),
        sessaoId: 'sessao-1',
      );

      final devolvido = ProgressoDeChutes.deBruto(original.toMap());

      expect(devolvido!.chutes, 6);
      expect(devolvido.data, '2026-09-02');
      expect(devolvido.inicio, DateTime(2026, 9, 2, 14));
      expect(devolvido.sessaoId, 'sessao-1');
    });

    test('sem sessaoId a chave não é gravada', () {
      final mapa = ProgressoDeChutes(
        chutes: 2,
        data: '2026-09-02',
        inicio: DateTime(2026, 9, 2, 14),
      ).toMap();

      expect(mapa.containsKey('sessaoId'), isFalse);
      expect(mapa.keys.toSet(), {'chutes', 'data', 'horaInicio'});
    });
  });
}
