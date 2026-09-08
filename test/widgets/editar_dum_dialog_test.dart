import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/widgets/editar_dum_dialog.dart';

void main() {
  // A regra de edição é pura e recebe "hoje" injetado: nenhum teste aqui
  // depende do relógio da máquina.
  group('Editar DUM — confirmar sem alteração', () {
    test('1. preserva exatamente a DUM atual, em qualquer resto de semana', () {
      // O resto da divisão por 7 é o que o cálculo antigo perdia: o diálogo
      // pré-preenche o piso das semanas.
      final hoje = DateTime(2026, 8, 1);
      const semanas = 20;

      for (final resto in [0, 1, 2, 3, 4, 5, 6]) {
        final dumAtual = hoje.subtract(Duration(days: semanas * 7 + resto));

        final resultado = dumAoConfirmarSemanas(
          semanasInformadas: semanas,
          semanasIniciais: semanas,
          dumAtual: dumAtual,
          hoje: hoje,
        );

        expect(resultado, dumAtual, reason: 'resto de $resto dias');

        if (resto > 0) {
          // O que o cálculo antigo teria devolvido: a DUM adiantada.
          expect(
            resultado,
            isNot(hoje.subtract(const Duration(days: semanas * 7))),
            reason: 'resto de $resto dias',
          );
        }
      }
    });

    test('1b. a DUM não se desloca por confirmações sucessivas', () {
      // Abrir e confirmar várias vezes tem de ser idempotente.
      final hoje = DateTime(2026, 5, 27);
      final original = DateTime(2026, 1, 5);
      var dum = original;

      for (var i = 0; i < 5; i++) {
        final semanas = hoje.difference(dum).inDays ~/ 7;
        dum = dumAoConfirmarSemanas(
          semanasInformadas: semanas,
          semanasIniciais: semanas,
          dumAtual: dum,
          hoje: hoje,
        );
      }

      expect(dum, original);
    });

    test('1c. o dia é preservado mesmo com resto de 6 dias', () {
      // 20 semanas e 6 dias: o cálculo antigo devolveria hoje - 140 dias,
      // adiantando a DUM em 6 dias.
      final dumAtual = DateTime(2026, 1, 5);
      final hoje = DateTime(2026, 5, 31);

      expect(hoje.difference(dumAtual).inDays, 20 * 7 + 6);

      final resultado = dumAoConfirmarSemanas(
        semanasInformadas: 20,
        semanasIniciais: 20,
        dumAtual: dumAtual,
        hoje: hoje,
      );

      expect(resultado, dumAtual);
      expect(resultado, isNot(DateTime(2026, 1, 11)));
    });
  });

  group('Editar DUM — data civil', () {
    test('2. a hora do dia não desloca a DUM preservada', () {
      final dumComHora = DateTime(2026, 1, 5, 23, 59);

      final resultado = dumAoConfirmarSemanas(
        semanasInformadas: 20,
        semanasIniciais: 20,
        dumAtual: dumComHora,
        hoje: DateTime(2026, 5, 25, 0, 1),
      );

      // Mesmo dia civil, sem resto de hora.
      expect(resultado, DateTime(2026, 1, 5));
      expect(resultado.hour, 0);
      expect(resultado.minute, 0);
    });

    test('2b. a hora do dia não desloca a DUM recalculada', () {
      final aoLongoDoDia = [
        for (final hora in [0, 8, 14, 23])
          dumAoConfirmarSemanas(
            semanasInformadas: 22,
            semanasIniciais: 20,
            dumAtual: DateTime(2026, 1, 5, 9, 30),
            hoje: DateTime(2026, 5, 25, hora, 45),
          ),
      ];

      expect(aoLongoDoDia.toSet(), hasLength(1));
      expect(aoLongoDoDia.first, DateTime(2025, 12, 22));
      expect(aoLongoDoDia.first.hour, 0);
    });

    test('2c. a DPP também produz data civil', () {
      final resultado = dumAoConfirmarDpp(DateTime(2026, 10, 12, 18, 20));

      // 12/10/2026 menos 280 dias.
      expect(resultado, DateTime(2026, 1, 5));
      expect(resultado.hour, 0);
    });
  });

  group('Editar DUM — alteração explícita', () {
    test('3. mudar as semanas recalcula a partir de hoje', () {
      final hoje = DateTime(2026, 5, 25);

      expect(
        dumAoConfirmarSemanas(
          semanasInformadas: 22,
          semanasIniciais: 20,
          dumAtual: DateTime(2026, 1, 5),
          hoje: hoje,
        ),
        DateTime(2025, 12, 22),
      );

      expect(
        dumAoConfirmarSemanas(
          semanasInformadas: 18,
          semanasIniciais: 20,
          dumAtual: DateTime(2026, 1, 5),
          hoje: hoje,
        ),
        DateTime(2026, 1, 19),
      );
    });

    test('3b. a semana informada volta corretamente pela GestacaoInfo', () {
      final hoje = DateTime(2026, 5, 25);

      for (final semanas in [1, 8, 20, 28, 40, 42]) {
        final dum = dumAoConfirmarSemanas(
          semanasInformadas: semanas,
          semanasIniciais: semanas + 1,
          dumAtual: DateTime(2026, 1, 5),
          hoje: hoje,
        );

        expect(hoje.difference(dum).inDays, semanas * 7, reason: '$semanas');
      }
    });

    test('3c. voltar ao valor inicial preserva, não recalcula', () {
      // Subir e descer o contador até o valor original não pode mover a DUM.
      final dumAtual = DateTime(2026, 1, 5);

      expect(
        dumAoConfirmarSemanas(
          semanasInformadas: 20,
          semanasIniciais: 20,
          dumAtual: dumAtual,
          hoje: DateTime(2026, 5, 31),
        ),
        dumAtual,
      );
    });
  });

  group('Editar DUM — o cálculo é puro', () {
    test('nenhuma das duas funções lê o relógio', () {
      // Duas chamadas com o mesmo "hoje" injetado dão o mesmo resultado,
      // e "hoje" é sempre parâmetro.
      final a = dumAoConfirmarSemanas(
        semanasInformadas: 22,
        semanasIniciais: 20,
        dumAtual: DateTime(2026, 1, 5),
        hoje: DateTime(2026, 5, 25),
      );
      final b = dumAoConfirmarSemanas(
        semanasInformadas: 22,
        semanasIniciais: 20,
        dumAtual: DateTime(2026, 1, 5),
        hoje: DateTime(2026, 5, 25),
      );

      expect(a, b);
      expect(dumAoConfirmarDpp(DateTime(2026, 10, 12)), DateTime(2026, 1, 5));
    });
  });
}
