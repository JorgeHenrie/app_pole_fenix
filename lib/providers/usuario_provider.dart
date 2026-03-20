import 'package:flutter/material.dart';
import '../models/usuario.dart';
import '../repositories/usuario_repository.dart';

/// Provider responsável pelos dados da usuária logada.
class UsuarioProvider extends ChangeNotifier {
  final UsuarioRepository _repository = UsuarioRepository();

  Usuario? _usuario;
  bool _carregando = false;
  String? _erro;

  Usuario? get usuario => _usuario;
  bool get carregando => _carregando;
  String? get erro => _erro;

  /// Carrega os dados da usuária a partir do id.
  Future<void> carregar(String id) async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _usuario = await _repository.buscarPorId(id);
    } catch (e) {
      _erro = 'Erro ao carregar dados da usuária.';
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Limpa os dados ao deslogar.
  void limpar() {
    _usuario = null;
    _erro = null;
    notifyListeners();
  }
}
