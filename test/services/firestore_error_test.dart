import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suacontracao_ai/services/firestore_error.dart';

void main() {
  group('FirestoreErro.mensagemAmigavel', () {
    test('unavailable devolve a mensagem de sem conexão', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      expect(FirestoreErro.mensagemAmigavel(erro), FirestoreErro.semConexao);
    });

    test('deadline-exceeded devolve a mensagem de tempo esgotado', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded');
      expect(FirestoreErro.mensagemAmigavel(erro), FirestoreErro.tempoEsgotado);
    });

    test('permission-denied devolve a mensagem de sem permissão', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');
      expect(FirestoreErro.mensagemAmigavel(erro), FirestoreErro.semPermissao);
    });

    test('cancelled devolve a mensagem de operação cancelada', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'cancelled');
      expect(FirestoreErro.mensagemAmigavel(erro), FirestoreErro.operacaoCancelada);
    });

    test('código desconhecido de FirebaseException cai no fallback genérico', () {
      final erro = FirebaseException(plugin: 'cloud_firestore', code: 'algum-codigo-nunca-mapeado');
      expect(FirestoreErro.mensagemAmigavel(erro), FirestoreErro.falhaGenerica);
    });

    test('erro que não é FirebaseException recebe a mensagem genérica de erro inesperado', () {
      expect(FirestoreErro.mensagemAmigavel(Exception('falha qualquer')), FirestoreErro.erroInesperado);
      expect(FirestoreErro.mensagemAmigavel('uma string qualquer'), FirestoreErro.erroInesperado);
    });

    test('os seis casos cobertos produzem mensagens distintas entre si', () {
      final mensagens = <String>{
        FirestoreErro.mensagemAmigavel(FirebaseException(plugin: 'cloud_firestore', code: 'unavailable')),
        FirestoreErro.mensagemAmigavel(FirebaseException(plugin: 'cloud_firestore', code: 'deadline-exceeded')),
        FirestoreErro.mensagemAmigavel(FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')),
        FirestoreErro.mensagemAmigavel(FirebaseException(plugin: 'cloud_firestore', code: 'cancelled')),
        FirestoreErro.mensagemAmigavel(FirebaseException(plugin: 'cloud_firestore', code: 'codigo-desconhecido')),
        FirestoreErro.mensagemAmigavel(Exception('não é FirebaseException')),
      };
      expect(mensagens.length, 6);
    });
  });
}
