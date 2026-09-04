import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreErro {
  static const String semConexao =
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
  static const String tempoEsgotado =
      'A operação demorou demais para responder. Tente novamente.';
  static const String semPermissao =
      'Sem permissão para acessar seus dados. Faça login novamente.';
  static const String operacaoCancelada = 'Operação cancelada. Tente novamente.';
  static const String falhaGenerica =
      'Não foi possível concluir a operação. Tente novamente.';
  static const String erroInesperado = 'Ocorreu um erro inesperado. Tente novamente.';

  static String mensagemAmigavel(Object erro) {
    if (erro is FirebaseException) {
      switch (erro.code) {
        case 'unavailable':
          return semConexao;
        case 'deadline-exceeded':
          return tempoEsgotado;
        case 'permission-denied':
          return semPermissao;
        case 'cancelled':
          return operacaoCancelada;
        default:
          return falhaGenerica;
      }
    }
    return erroInesperado;
  }
}
