import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';

void main() {
  late GestacaoInfo original;

  setUp(() => original = gestacaoAtual);
  tearDown(() => gestacaoAtual = original);

  String fonteDe(String caminho) => File(caminho)
      .readAsLinesSync()
      .where((l) => !l.trimLeft().startsWith('//'))
      .join('\n');

  group('GestacaoInfo — identidade', () {
    test('o id é opcional e nulo por padrão', () {
      final semId = GestacaoInfo(dum: DateTime(2026, 1, 5));

      expect(semId.id, isNull);
      expect(semId.dum, DateTime(2026, 1, 5));
    });

    test('a DUM continua intacta quando há id', () {
      final comId = GestacaoInfo(dum: DateTime(2026, 1, 5), id: 'g1');

      expect(comId.id, 'g1');
      expect(comId.dum, DateTime(2026, 1, 5));
    });
  });

  group('Editar DUM é a mesma gestação', () {
    test('atualizarDUM preserva o id existente', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      atualizarDUM(DateTime(2026, 1, 12));

      expect(gestacaoAtual.id, 'gestacao-1');
      expect(gestacaoAtual.dum, DateTime(2026, 1, 12));
    });

    test('várias edições seguidas não trocam o id', () {
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-1');

      for (final dias in [3, -10, 40, -2]) {
        atualizarDUM(gestacaoAtual.dum.add(Duration(days: dias)));
        expect(gestacaoAtual.id, 'gestacao-1');
      }
    });

    test('atualizarDUM sem id anterior continua sem id', () {
      iniciarGestacao(DateTime(2026, 1, 5));

      atualizarDUM(DateTime(2026, 1, 12));

      expect(gestacaoAtual.id, isNull);
    });

    test('iniciarGestacao descarta o id anterior', () {
      // É o que impede herdar a identidade de quem estava logado antes.
      definirGestacao(DateTime(2026, 1, 5), 'gestacao-de-outra-usuaria');

      iniciarGestacao(DateTime(2026, 3, 1));

      expect(gestacaoAtual.id, isNull);
      expect(gestacaoAtual.dum, DateTime(2026, 3, 1));
    });

    test('definirGestacao adota dum e id juntos', () {
      definirGestacao(DateTime(2026, 2, 2), 'gestacao-2');

      expect(gestacaoAtual.dum, DateTime(2026, 2, 2));
      expect(gestacaoAtual.id, 'gestacao-2');
    });
  });

  group('GestacaoStorage — o id nasce uma única vez', () {
    String fonte() => fonteDe('lib/services/gestacao_storage.dart');

    test('salvarDUM só cunha quando ainda não existe id', () {
      expect(
        fonte(),
        contains('final id = gestacaoAtual.id ?? novoGestacaoId();'),
      );
      // Uma chamada seguinte encontra o id definido por definirGestacao.
      expect(fonte(), contains('definirGestacao(data, id);'));
    });

    test('persiste dum e id no mesmo documento, com merge', () {
      final codigo = fonte();

      expect(codigo, contains("static const String _campoId = 'gestacao_id';"));
      expect(codigo, contains('{_campo: data.toIso8601String(), _campoId: id}'));
      expect('SetOptions(merge: true)'.allMatches(codigo), hasLength(2));
      expect(codigo, contains("collection('usuarios').doc(uid)"));
    });

    test('restaurarDUM adota o id persistido sem gerar outro', () {
      final codigo = fonte();

      expect(codigo, contains('final idPersistido = dados?[_campoId];'));
      expect(
        codigo,
        contains('if (idPersistido is String && idPersistido.isNotEmpty)'),
      );
      expect(codigo, contains('definirGestacao(dum, idPersistido);'));

      // O caminho que cunha vem depois, e só é alcançado sem id persistido.
      final adota = codigo.indexOf('definirGestacao(dum, idPersistido);');
      final cunha = codigo.indexOf('final id = novoGestacaoId();');
      expect(adota, greaterThan(-1));
      expect(cunha, greaterThan(adota));
    });

    test('a gestação legada ganha id uma vez e ele é persistido', () {
      final codigo = fonte();

      expect(codigo, contains('await doc.set({_campoId: id}'));
      // Dois pontos de geração no arquivo: salvar e restaurar legado.
      expect('novoGestacaoId()'.allMatches(codigo), hasLength(3));
    });

    test('o id é gerado no cliente, sem ida ao servidor', () {
      expect(
        fonte(),
        contains("FirebaseFirestore.instance.collection('usuarios').doc().id"),
      );
    });
  });

  group('Onboarding — a primeira gestação declara identidade nova', () {
    test('usa iniciarGestacao, não atualizarDUM', () {
      final codigo = fonteDe('lib/screens/onboarding_screen.dart');

      expect(codigo, contains('iniciarGestacao(dum);'));
      expect(codigo, isNot(contains('atualizarDUM(')));
      expect(codigo, contains('await GestacaoStorage.salvarDUM(dum);'));

      // A ordem importa: sem id primeiro, cunhagem depois.
      expect(
        codigo.indexOf('iniciarGestacao(dum);'),
        lessThan(codigo.indexOf('await GestacaoStorage.salvarDUM(dum);')),
      );
    });

    test('o diálogo de edição não declara gestação nova', () {
      final codigo = fonteDe('lib/widgets/editar_dum_dialog.dart');

      expect(codigo, contains('atualizarDUM(novaDum);'));
      expect(codigo, isNot(contains('iniciarGestacao(')));
      expect(codigo, isNot(contains('novoGestacaoId(')));
    });
  });
}
