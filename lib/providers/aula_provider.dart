import 'package:flutter/material.dart';
import '../models/aula.dart';
import '../repositories/aula_repository.dart';

/// Provider responsável pelo estado das aulas disponíveis.
class AulaProvider extends ChangeNotifier {
  final AulaRepository _repository = AulaRepository();

  List<Aula> _aulas = [];
  bool _carregando = false;
  String? _erro;

  List<Aula> get aulas => List.unmodifiable(_aulas);
  bool get carregando => _carregando;
  String? get erro => _erro;

  /// Carrega as próximas aulas agendadas.
  Future<void> carregarProximas() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _aulas = await _repository.listarProximas();
    } catch (e) {
      _erro = 'Erro ao carregar aulas.';
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  /// Limpa a lista de aulas.
  void limpar() {
    _aulas = [];
    _erro = null;
    notifyListeners();
  }
}
