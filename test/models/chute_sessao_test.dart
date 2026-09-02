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
}
