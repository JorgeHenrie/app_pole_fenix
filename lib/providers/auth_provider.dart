import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase/auth_service.dart';

/// Estado de autenticação do app.
enum EstadoAuth { inicial, autenticado, naoAutenticado, carregando }

/// Provider responsável pelo estado de autenticação do usuário.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  EstadoAuth _estado = EstadoAuth.inicial;
  String? _erro;

  EstadoAuth get estado => _estado;
  String? get erro => _erro;
  User? get usuarioAtual => _authService.usuarioAtual;
  bool get estaAutenticado => _estado == EstadoAuth.autenticado;

  AuthProvider() {
    _authService.estadoAutenticacao.listen(_onEstadoAlterado);
  }

  void _onEstadoAlterado(User? usuario) {
    _estado =
        usuario != null ? EstadoAuth.autenticado : EstadoAuth.naoAutenticado;
    notifyListeners();
  }

  /// Realiza login com e-mail e senha.
  Future<void> login(String email, String senha) async {
    _estado = EstadoAuth.carregando;
    _erro = null;
    notifyListeners();
    try {
      await _authService.login(email: email, senha: senha);
    } on FirebaseAuthException catch (e) {
      _erro = _mensagemErroAuth(e.code);
      _estado = EstadoAuth.naoAutenticado;
      notifyListeners();
    }
  }

  /// Realiza logout.
  Future<void> logout() async {
    await _authService.logout();
  }

  /// Envia e-mail de recuperação de senha.
  Future<void> recuperarSenha(String email) async {
    await _authService.recuperarSenha(email);
  }

  String _mensagemErroAuth(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'Usuária não encontrada.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Erro ao fazer login. Tente novamente.';
    }
  }
}
