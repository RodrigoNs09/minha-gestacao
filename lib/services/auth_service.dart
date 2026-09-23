import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get usuarioAtual => _auth.currentUser;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  static Future<String?> cadastrar({
    required String email,
    required String senha,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(email: email, password: senha);
      return null;
    } on FirebaseAuthException catch (e) {
      return _traduzirErro(e.code);
    }
  }

  static Future<String?> login({
    required String email,
    required String senha,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: senha);
      return null;
    } on FirebaseAuthException catch (e) {
      return _traduzirErro(e.code);
    }
  }

  static Future<String?> recuperarSenha({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return null;
      return _traduzirErroDeRecuperacao(e.code);
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
  }

  static Future<String?> reautenticar({required String senha}) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return sessaoExpirada;

    final email = usuario.email;
    if (email == null || email.isEmpty) return contaSemSenha;

    try {
      await usuario.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: senha),
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return _traduzirErroDeConta(e.code);
    }
  }

  static Future<String?> excluirUsuario() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return sessaoExpirada;

    try {
      await usuario.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      return _traduzirErroDeConta(e.code);
    }
  }

  static const String sessaoExpirada =
      'Sua sessão expirou. Entre de novo para continuar.';
  static const String contaSemSenha =
      'Esta conta não entra por e-mail e senha, então não dá para confirmar '
      'a exclusão por aqui.';

  static String _traduzirErroDeConta(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Senha incorreta.';
      case 'user-mismatch':
        return 'Esta senha não é da conta que está aberta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'requires-recent-login':
        return 'Por segurança, confirme sua senha de novo para continuar.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível concluir a operação. Tente novamente.';
    }
  }

  static String _traduzirErro(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'A senha deve ter pelo menos 6 caracteres.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Ocorreu um erro. Tente novamente.';
    }
  }

  static String _traduzirErroDeRecuperacao(String code) {
    switch (code) {
      case 'invalid-email':
      case 'missing-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      case 'network-request-failed':
        return 'Sem conexão. Verifique sua internet e tente novamente.';
      default:
        return 'Não foi possível enviar o e-mail agora. Tente novamente.';
    }
  }
}
