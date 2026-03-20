import 'package:flutter/material.dart';
import '../models/notificacao.dart';

/// Provider responsável pelas notificações da usuária.
class NotificacaoProvider extends ChangeNotifier {
  List<Notificacao> _notificacoes = [];
  bool _carregando = false;

  List<Notificacao> get notificacoes => List.unmodifiable(_notificacoes);
  bool get carregando => _carregando;

  int get naoLidas =>
      _notificacoes.where((n) => !n.lida).length;

  /// Adiciona uma nova notificação à lista local.
  void adicionar(Notificacao notificacao) {
    _notificacoes = [notificacao, ..._notificacoes];
    notifyListeners();
  }

  /// Marca uma notificação como lida.
  void marcarComoLida(String id) {
    _notificacoes = _notificacoes.map((n) {
      return n.id == id ? n.copyWith(lida: true) : n;
    }).toList();
    notifyListeners();
  }

  /// Limpa todas as notificações.
  void limpar() {
    _notificacoes = [];
    notifyListeners();
  }
}
