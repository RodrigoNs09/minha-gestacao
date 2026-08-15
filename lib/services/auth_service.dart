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
      return null; // sucesso
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
      return null; // sucesso
    } on FirebaseAuthException catch (e) {
      return _traduzirErro(e.code);
    }
  }

  static Future<void> logout() async {
    await _auth.signOut();
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
}