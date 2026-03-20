import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/usuario.dart';
import '../services/firebase/auth_service.dart';
import '../repositories/usuario_repository.dart';

/// Estado de autenticação do app.
enum EstadoAuth { inicial, autenticado, naoAutenticado, carregando }

/// Provider responsável pelo estado de autenticação do usuário.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();

  EstadoAuth _estado = EstadoAuth.inicial;
  Usuario? _usuario;
  bool _carregando = false;
  String? _erro;

  // Flag para evitar condição de corrida durante cadastro
  bool _cadastrando = false;

  EstadoAuth get estado => _estado;
  Usuario? get usuario => _usuario;
  bool get carregando => _carregando;
  String? get erro => _erro;
  User? get usuarioFirebase => _authService.usuarioAtual;
  bool get estaAutenticado => _estado == EstadoAuth.autenticado;

  AuthProvider() {
    _authService.estadoAutenticacao.listen(_onEstadoAlterado);
  }

  void _onEstadoAlterado(User? firebaseUser) async {
    if (firebaseUser != null) {
      _estado = EstadoAuth.autenticado;
      notifyListeners();
      // Só busca no Firestore se não houver dados do usuário atual
      if (!_cadastrando &&
          (_usuario == null || _usuario!.id != firebaseUser.uid)) {
        await _carregarDadosUsuario(firebaseUser.uid);
      }
    } else {
      _estado = EstadoAuth.naoAutenticado;
      _usuario = null;
      notifyListeners();
    }
  }

  Future<void> _carregarDadosUsuario(String uid) async {
    try {
      _usuario = await _usuarioRepository.buscarPorId(uid);
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
      _usuario = null;
    }
    notifyListeners();
  }

  /// Realiza login com e-mail e senha.
  Future<void> login(String email, String senha) async {
    _setCarregando(true);
    try {
      final credencial =
          await _authService.login(email: email, senha: senha);
      if (credencial.user != null) {
        await _carregarDadosUsuario(credencial.user!.uid);
      }
      _estado = EstadoAuth.autenticado;
    } on FirebaseAuthException catch (e) {
      _erro = _mensagemErroAuth(e.code);
      _estado = EstadoAuth.naoAutenticado;
    } finally {
      _setCarregando(false);
    }
  }

  /// Cria nova conta e salva dados no Firestore.
  Future<void> cadastro({
    required String email,
    required String senha,
    required String nome,
    String? telefone,
    String tipoUsuario = 'aluna',
  }) async {
    _cadastrando = true;
    _setCarregando(true);
    try {
      final credencial =
          await _authService.cadastrar(email: email, senha: senha);
      if (credencial.user != null) {
        final novoUsuario = Usuario(
          id: credencial.user!.uid,
          nome: nome,
          email: email,
          tipoUsuario: tipoUsuario,
          telefone: telefone,
          dataCadastro: DateTime.now(),
          ativo: true,
        );
        // Define _usuario antes de salvar para evitar race condition
        _usuario = novoUsuario;
        await _usuarioRepository.criar(novoUsuario);
      }
      _estado = EstadoAuth.autenticado;
    } on FirebaseAuthException catch (e) {
      _erro = _mensagemErroAuth(e.code);
      _estado = EstadoAuth.naoAutenticado;
      _usuario = null;
    } finally {
      _cadastrando = false;
      _setCarregando(false);
    }
  }

  /// Realiza logout.
  Future<void> logout() async {
    await _authService.logout();
    _usuario = null;
    _estado = EstadoAuth.naoAutenticado;
    notifyListeners();
  }

  /// Envia e-mail de recuperação de senha. Retorna true em caso de sucesso.
  Future<bool> recuperarSenha(String email) async {
    _setCarregando(true);
    try {
      await _authService.recuperarSenha(email);
      return true;
    } on FirebaseAuthException catch (e) {
      _erro = _mensagemErroAuth(e.code);
      return false;
    } finally {
      _setCarregando(false);
    }
  }

  /// Limpa a mensagem de erro atual.
  void limparErro() {
    _erro = null;
    notifyListeners();
  }

  void _setCarregando(bool valor) {
    _carregando = valor;
    if (valor) _erro = null;
    notifyListeners();
  }

  String _mensagemErroAuth(String codigo) {
    switch (codigo) {
      case 'user-not-found':
        return 'Usuária não encontrada.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'E-mail já cadastrado.';
      case 'invalid-email':
        return 'E-mail inválido.';
      case 'weak-password':
        return 'Senha muito fraca. Use pelo menos 6 caracteres.';
      case 'network-request-failed':
        return 'Erro de conexão. Verifique sua internet.';
      case 'too-many-requests':
        return 'Muitas tentativas. Tente novamente mais tarde.';
      default:
        return 'Erro ao realizar operação. Tente novamente.';
    }
  }
}
