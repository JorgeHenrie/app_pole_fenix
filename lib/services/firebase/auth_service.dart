import 'package:firebase_auth/firebase_auth.dart';

/// Serviço responsável pela autenticação via Firebase Auth.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream com o estado atual do usuário autenticado.
  Stream<User?> get estadoAutenticacao => _auth.authStateChanges();

  /// Usuário atualmente autenticado.
  User? get usuarioAtual => _auth.currentUser;

  /// Realiza login com e-mail e senha.
  Future<UserCredential> login({
    required String email,
    required String senha,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: senha);
  }

  /// Cria uma nova conta com e-mail e senha.
  Future<UserCredential> cadastrar({
    required String email,
    required String senha,
  }) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: senha);
  }

  /// Envia e-mail de recuperação de senha.
  Future<void> recuperarSenha(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// Realiza logout do usuário.
  Future<void> logout() async {
    await _auth.signOut();
  }
}
