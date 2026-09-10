import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/data/gestacao_data.dart';
import 'package:suacontracao_ai/models/gestacao_info.dart';

void main() {
  late GestacaoInfo original;

  setUp(() => original = gestacaoAtual);
  tearDown(() => gestacaoAtual = original);

  String fonteDe(String caminho) => File(
    caminho,
  ).readAsLinesSync().where((l) => !l.trimLeft().startsWith('//')).join('\n');

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
      expect(
        codigo,
        contains('{_campo: data.toIso8601String(), _campoId: id}'),
      );
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

      final adota = codigo.indexOf('definirGestacao(dum, idPersistido);');
      final cunha = codigo.indexOf('final id = novoGestacaoId();');
      expect(adota, greaterThan(-1));
      expect(cunha, greaterThan(adota));
    });

    test('a gestação legada ganha id uma vez e ele é persistido', () {
      final codigo = fonte();

      expect(codigo, contains('await doc.set({_campoId: id}'));

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
    test('a memória é escrita só pelo salvarDUM, depois da persistência', () {
      final codigo = fonteDe('lib/screens/onboarding_screen.dart');

      expect(codigo, isNot(contains('iniciarGestacao(')));
      expect(codigo, isNot(contains('atualizarDUM(')));
      expect(codigo, contains('await GestacaoStorage.salvarDUM(dum)'));
    });

    test('o diálogo de edição não declara gestação nova nem cunha id', () {
      final codigo = fonteDe('lib/widgets/editar_dum_dialog.dart');

      expect(codigo, isNot(contains('atualizarDUM(')));
      expect(codigo, isNot(contains('iniciarGestacao(')));
      expect(codigo, isNot(contains('novoGestacaoId(')));
      expect(codigo, contains('await GestacaoStorage.salvarDUM(novaDum)'));
    });
  });

  group('C1 — gestação configurada é declarada explicitamente', () {
    String fonteDoStorage() => fonteDe('lib/services/gestacao_storage.dart');

    test('o placeholder inicial não é uma gestação configurada', () {
      encerrarGestacao();

      expect(gestacaoAtual.configurada, isFalse);
      expect(gestacaoAtual.id, isNull);
    });

    test('GestacaoInfo nasce não configurada por padrão', () {
      expect(GestacaoInfo(dum: DateTime(2026, 1, 5)).configurada, isFalse);
    });

    test('iniciarGestacao marca como configurada', () {
      iniciarGestacao(DateTime(2026, 1, 5));

      expect(gestacaoAtual.configurada, isTrue);
    });

    test('definirGestacao marca como configurada', () {
      definirGestacao(DateTime(2026, 1, 5), 'g1');

      expect(gestacaoAtual.configurada, isTrue);
      expect(gestacaoAtual.id, 'g1');
    });

    test('atualizarDUM marca como configurada e preserva o id', () {
      definirGestacao(DateTime(2026, 1, 5), 'g1');
      atualizarDUM(DateTime(2026, 1, 12));

      expect(gestacaoAtual.configurada, isTrue);
      expect(gestacaoAtual.id, 'g1');
    });

    test('encerrarGestacao volta a não configurada', () {
      definirGestacao(DateTime(2026, 1, 5), 'g1');
      encerrarGestacao();

      expect(gestacaoAtual.configurada, isFalse);
    });

    test('salvarDUM sinaliza ausência de sessão em vez de silenciar', () {
      final codigo = fonteDoStorage();

      expect(codigo, contains('static Future<bool> salvarDUM(DateTime data)'));
      expect(codigo, contains('if (doc == null) return false;'));
      expect(codigo, contains('return true;'));
    });

    test('salvarDUM só toca a memória depois da escrita', () {
      final codigo = fonteDoStorage();

      final escrita = codigo.indexOf('await doc.set(');
      final memoria = codigo.indexOf('definirGestacao(data, id)');

      expect(escrita, greaterThan(-1));
      expect(memoria, greaterThan(escrita));
    });
  });
}
