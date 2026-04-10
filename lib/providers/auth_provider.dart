import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario.dart';
import '../services/local/session_cache_service.dart';
import '../services/firebase/auth_service.dart';
import '../services/firebase/messaging_service.dart';
import '../repositories/usuario_repository.dart';

/// Estado de autenticação do app.
enum EstadoAuth { inicial, autenticado, naoAutenticado, carregando }

/// Provider responsável pelo estado de autenticação do usuário.
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final UsuarioRepository _usuarioRepository = UsuarioRepository();
  final MessagingService _messagingService = MessagingService();
  final SessionCacheService _sessionCacheService = SessionCacheService();

  EstadoAuth _estado = EstadoAuth.inicial;
  Usuario? _usuario;
  bool _carregando = false;
  String? _erro;
  bool _sessaoInicializada = false;

  // Flag para evitar condição de corrida durante cadastro
  bool _cadastrando = false;
  StreamSubscription<User?>? _authStateSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _tokenNotificacaoAtual;

  EstadoAuth get estado => _estado;
  Usuario? get usuario => _usuario;
  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get sessaoInicializada => _sessaoInicializada;
  User? get usuarioFirebase => _authService.usuarioAtual;
  bool get estaAutenticado => _estado == EstadoAuth.autenticado;

  AuthProvider() {
    unawaited(_inicializarSessao());
  }

  Future<void> _inicializarSessao() async {
    final firebaseUser = _authService.usuarioAtual;
    final usuarioCache = await _sessionCacheService.carregarUsuario();

    if (firebaseUser == null) {
      _usuario = null;
      _estado = EstadoAuth.naoAutenticado;
      await _sessionCacheService.limparUsuario();
    } else {
      _estado = EstadoAuth.autenticado;
      if (usuarioCache != null && usuarioCache.id == firebaseUser.uid) {
        _usuario = usuarioCache;
      }
      notifyListeners();
      await _carregarDadosUsuario(
        firebaseUser.uid,
        usarCacheComoFallback: true,
      );
    }

    _sessaoInicializada = true;
    notifyListeners();

    _authStateSubscription =
        _authService.estadoAutenticacao.skip(1).listen((firebaseUser) {
      unawaited(_onEstadoAlterado(firebaseUser));
    });
  }

  Future<void> _onEstadoAlterado(User? firebaseUser) async {
    if (firebaseUser != null) {
      _estado = EstadoAuth.autenticado;
      notifyListeners();
      if (!_cadastrando &&
          (_usuario == null || _usuario!.id != firebaseUser.uid)) {
        final usuarioCache = await _sessionCacheService.carregarUsuario();
        if (usuarioCache != null && usuarioCache.id == firebaseUser.uid) {
          _usuario = usuarioCache;
          notifyListeners();
        }
        await _carregarDadosUsuario(
          firebaseUser.uid,
          usarCacheComoFallback: true,
        );
      }
    } else {
      await _sessionCacheService.limparUsuario();
      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _tokenNotificacaoAtual = null;
      _estado = EstadoAuth.naoAutenticado;
      _usuario = null;
      notifyListeners();
    }
  }

  Future<void> _carregarDadosUsuario(
    String uid, {
    bool usarCacheComoFallback = false,
  }) async {
    try {
      final usuarioCarregado = await _usuarioRepository.buscarPorId(uid);
      if (usuarioCarregado != null) {
        _usuario = usuarioCarregado;
        await _sessionCacheService.salvarUsuario(usuarioCarregado);
        await _inicializarNotificacoes(uid);
      } else if (!usarCacheComoFallback || _usuario?.id != uid) {
        _usuario = null;
        await _sessionCacheService.limparUsuario();
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados do usuário: $e');
      if (!usarCacheComoFallback || _usuario?.id != uid) {
        _usuario = null;
      }
    }
    notifyListeners();
  }

  /// Realiza login com e-mail e senha.
  Future<void> login(String email, String senha) async {
    _setCarregando(true);
    try {
      final credencial = await _authService.login(email: email, senha: senha);
      if (credencial.user != null) {
        await _carregarDadosUsuario(
          credencial.user!.uid,
          usarCacheComoFallback: true,
        );
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
    String? planoId,
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
          tipoUsuario: 'aluna',
          telefone: telefone,
          dataCadastro: DateTime.now(),
          ativo: true,
          statusCadastro: 'pendente',
          planoId: planoId,
        );
        // Define _usuario antes de salvar para evitar race condition
        _usuario = novoUsuario;
        await _usuarioRepository.criar(novoUsuario);
        await _sessionCacheService.salvarUsuario(novoUsuario);
        await _inicializarNotificacoes(credencial.user!.uid);
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
    await _removerTokenAtual();
    await _authService.logout();
    await _sessionCacheService.limparUsuario();
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

  /// Recarrega os dados do usuário autenticado a partir do Firestore.
  Future<void> recarregarUsuario() async {
    final uid = _authService.usuarioAtual?.uid;
    if (uid == null) return;
    await _carregarDadosUsuario(uid);
  }

  /// Atualiza a URL da foto de perfil localmente e no Firestore.
  Future<void> atualizarFotoUrl(String fotoUrl) async {
    if (_usuario == null) return;
    await _usuarioRepository.atualizarFotoUrl(_usuario!.id, fotoUrl);
    _usuario = _usuario!.copyWith(fotoUrl: fotoUrl);
    await _sessionCacheService.salvarUsuario(_usuario!);
    notifyListeners();
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

  Future<void> _inicializarNotificacoes(String uid) async {
    if (!_messagingService.suportaPush) return;

    try {
      await _messagingService.solicitarPermissao();

      final token = await _messagingService.obterToken();
      if (token != null && token.isNotEmpty) {
        await _atualizarTokenNotificacao(uid, token);
      }

      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription =
          _messagingService.escutarAtualizacaoToken((novoToken) async {
        if (novoToken.isEmpty) return;
        await _atualizarTokenNotificacao(uid, novoToken);
      });
    } catch (e) {
      debugPrint('Erro ao inicializar notificações push: $e');
    }
  }

  Future<void> _atualizarTokenNotificacao(String uid, String novoToken) async {
    if (_tokenNotificacaoAtual == novoToken) return;

    try {
      final tokenAnterior = _tokenNotificacaoAtual;
      if (tokenAnterior != null && tokenAnterior.isNotEmpty) {
        await _usuarioRepository.removerTokenNotificacao(uid, tokenAnterior);
      }

      await _usuarioRepository.salvarTokenNotificacao(uid, novoToken);
      _tokenNotificacaoAtual = novoToken;
    } catch (e) {
      debugPrint('Erro ao atualizar token de notificação: $e');
    }
  }

  Future<void> _removerTokenAtual() async {
    final usuarioId = _usuario?.id;
    final token = _tokenNotificacaoAtual;

    await _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = null;

    if (usuarioId == null || token == null || token.isEmpty) {
      _tokenNotificacaoAtual = null;
      return;
    }

    try {
      await _usuarioRepository.removerTokenNotificacao(usuarioId, token);
    } catch (e) {
      debugPrint('Erro ao remover token de notificação: $e');
    } finally {
      _tokenNotificacaoAtual = null;
    }
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

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}
