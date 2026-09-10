import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';
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

  group('A2 — gravar primeiro, só então mexer na memória', () {
    late GestacaoInfo gestacaoOriginal;

    setUp(() {
      gestacaoOriginal = gestacaoAtual;
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');
    });

    tearDown(() => gestacaoAtual = gestacaoOriginal);

    void ignorarOverflowDeLayout() {
      final anterior = FlutterError.onError;
      FlutterError.onError = (detalhes) {
        if (detalhes.exceptionAsString().contains('overflowed')) return;
        anterior?.call(detalhes);
      };
      addTearDown(() => FlutterError.onError = anterior);
    }

    Future<void> abrirFolha(WidgetTester tester) async {
      ignorarOverflowDeLayout();

      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => mostrarEditarDUM(context, () {}),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('a folha abre com o botão Salvar habilitado', (tester) async {
      await abrirFolha(tester);

      final botao = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Salvar'),
      );

      expect(botao.onPressed, isNotNull);
    });

    testWidgets('falha ao gravar mantém a folha aberta e avisa', (
      tester,
    ) async {
      await abrirFolha(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Salvar'), findsOneWidget);
      expect(find.textContaining('Tente novamente'), findsOneWidget);
    });

    testWidgets('falha ao gravar não altera a DUM em memória', (tester) async {
      await abrirFolha(tester);

      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(gestacaoAtual.dum, DateTime(2026, 1, 5));
      expect(gestacaoAtual.id, 'gestacao-1');
    });

    testWidgets('segundo toque em Salvar não dispara segunda escrita', (
      tester,
    ) async {
      await abrirFolha(tester);

      await tester.tap(find.text('Salvar'));
      await tester.tap(find.text('Salvar'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(gestacaoAtual.dum, DateTime(2026, 1, 5));
    });

    testWidgets('cancelar fecha sem tocar na memória', (tester) async {
      await abrirFolha(tester);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Salvar'), findsNothing);
      expect(gestacaoAtual.dum, DateTime(2026, 1, 5));
    });
  });

  group('Estrutural — A2', () {
    String fonte() => File('lib/widgets/editar_dum_dialog.dart')
        .readAsLinesSync()
        .where((linha) => !linha.trimLeft().startsWith('//'))
        .join('\n');

    String corpoDeConfirmar() {
      final codigo = fonte();
      final inicio = codigo.indexOf('Future<void> confirmar() async {');
      expect(inicio, greaterThan(-1));

      final fim = codigo.indexOf('\n          }\n', inicio);
      expect(fim, greaterThan(inicio));

      return codigo.substring(inicio, fim);
    }

    test('a gravação acontece antes de fechar a folha', () {
      final corpo = corpoDeConfirmar();

      final escrita = corpo.indexOf('await GestacaoStorage.salvarDUM(');
      final fechamento = corpo.indexOf('Navigator.pop(ctx, true)');

      expect(escrita, greaterThan(-1));
      expect(fechamento, greaterThan(escrita));
    });

    test('o caminho de falha retorna antes de fechar', () {
      final corpo = corpoDeConfirmar();

      final falha = corpo.indexOf('if (!salvou)');
      final fechamento = corpo.indexOf('Navigator.pop(ctx, true)');

      expect(falha, greaterThan(-1));
      expect(falha, lessThan(fechamento));
      expect(corpo.substring(falha, fechamento), contains('return;'));
    });

    test('duplo toque é bloqueado dentro de confirmar', () {
      expect(corpoDeConfirmar(), contains('if (salvando) return;'));
    });

    test('o botão Salvar respeita o estado de gravação', () {
      expect(fonte(), contains('(podeConfirmar() && !salvando)'));
    });

    test('aoSalvar só roda com resultado true', () {
      expect(fonte(), contains('if (resultado == true) aoSalvar();'));
    });

    test('a tela não escreve na memória — quem escreve é o storage', () {
      final codigo = fonte();

      expect(codigo, isNot(contains('atualizarDUM(')));
      expect(codigo, isNot(contains('definirGestacao(')));
      expect(codigo, isNot(contains('iniciarGestacao(')));
    });

    test('mounted do contexto da folha é checado depois do await', () {
      final corpo = corpoDeConfirmar();

      final espera = corpo.indexOf('await GestacaoStorage.salvarDUM(');
      final guarda = corpo.indexOf('if (!ctx.mounted) return;', espera);

      expect(guarda, greaterThan(espera));
    });
  });
}
