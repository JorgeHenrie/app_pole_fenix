import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/notificacao.dart';
import '../repositories/notificacao_repository.dart';

/// Provider responsável pelas notificações da usuária.
class NotificacaoProvider extends ChangeNotifier {
  final NotificacaoRepository _repository = NotificacaoRepository();

  StreamSubscription<List<Notificacao>>? _subscription;
  StreamSubscription<List<Notificacao>>? _subscriptionCadastrosPendentes;
  final Set<String> _idsSinteticosLidos = <String>{};
  List<Notificacao> _notificacoesPersistidas = [];
  List<Notificacao> _notificacoesCadastrosPendentes = [];
  List<Notificacao> _notificacoes = [];
  bool _carregando = false;
  String? _usuarioId;
  String? _tipoUsuario;

  List<Notificacao> get notificacoes => List.unmodifiable(_notificacoes);
  bool get carregando => _carregando;

  int get naoLidas => _notificacoes.where((n) => !n.lida).length;

  void conectar(String usuarioId, {required String tipoUsuario}) {
    final jaConectado = _usuarioId == usuarioId &&
        _tipoUsuario == tipoUsuario &&
        _subscription != null;
    if (jaConectado) return;

    _subscription?.cancel();
    _subscriptionCadastrosPendentes?.cancel();
    _usuarioId = usuarioId;
    _tipoUsuario = tipoUsuario;
    _idsSinteticosLidos.clear();
    _notificacoesPersistidas = [];
    _notificacoesCadastrosPendentes = [];
    _notificacoes = [];
    _carregando = true;
    notifyListeners();

    _subscription = _repository.observarPorUsuario(usuarioId).listen(
      (notificacoes) {
        _notificacoesPersistidas = notificacoes;
        _reconstruirLista();
      },
      onError: (Object erro, StackTrace stackTrace) {
        debugPrint('NotificacaoProvider.conectar: $erro');
        _carregando = false;
        notifyListeners();
      },
    );

    if (tipoUsuario == 'admin') {
      _subscriptionCadastrosPendentes =
          _repository.observarCadastrosPendentesParaAdmin(usuarioId).listen(
        (notificacoes) {
          _notificacoesCadastrosPendentes = notificacoes;
          _reconstruirLista();
        },
        onError: (Object erro, StackTrace stackTrace) {
          debugPrint('NotificacaoProvider.cadastrosPendentes: $erro');
          _carregando = false;
          notifyListeners();
        },
      );
    }
  }

  /// Marca uma notificação como lida.
  Future<void> marcarComoLida(String id) async {
    if (id.startsWith('cadastro_pendente:')) {
      _idsSinteticosLidos.add(id);
      _reconstruirLista();
      return;
    }

    await _repository.marcarComoLida(id);
  }

  Future<void> marcarTodasComoLidas() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return;

    for (final notificacao in _notificacoesCadastrosPendentes) {
      _idsSinteticosLidos.add(notificacao.id);
    }

    _reconstruirLista();
    await _repository.marcarTodasComoLidas(usuarioId);
  }

  void desconectar() {
    _subscription?.cancel();
    _subscriptionCadastrosPendentes?.cancel();
    _subscription = null;
    _subscriptionCadastrosPendentes = null;
    _usuarioId = null;
    _tipoUsuario = null;
    _idsSinteticosLidos.clear();
    _notificacoesPersistidas = [];
    _notificacoesCadastrosPendentes = [];
    _notificacoes = [];
    _carregando = false;
    notifyListeners();
  }

  void _reconstruirLista() {
    final cadastroPendentesPersistidos = _notificacoesPersistidas
        .where(
          (notificacao) =>
              notificacao.tipo == 'cadastro_pendente' &&
              notificacao.referenciaId != null,
        )
        .map((notificacao) => notificacao.referenciaId!)
        .toSet();

    final sinteticas = _notificacoesCadastrosPendentes
        .where(
          (notificacao) =>
              !cadastroPendentesPersistidos.contains(notificacao.referenciaId),
        )
        .map(
          (notificacao) => notificacao.copyWith(
            lida: _idsSinteticosLidos.contains(notificacao.id),
          ),
        )
        .toList();

    _notificacoes = [
      ..._notificacoesPersistidas,
      ...sinteticas,
    ]..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));

    _carregando = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscriptionCadastrosPendentes?.cancel();
    super.dispose();
  }
}
