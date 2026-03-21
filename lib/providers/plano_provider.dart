import 'package:flutter/foundation.dart';

import '../models/plano.dart';
import '../repositories/plano_repository.dart';

/// Provider responsável pelo carregamento dos planos disponíveis.
class PlanoProvider extends ChangeNotifier {
  final PlanoRepository _planoRepository = PlanoRepository();

  List<Plano> _planos = [];
  bool _carregando = false;
  String? _erro;

  List<Plano> get planos => List.unmodifiable(_planos);
  bool get carregando => _carregando;
  String? get erro => _erro;

  Future<void> carregarPlanos() async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _planos = await _planoRepository.listarAtivos();
    } catch (e) {
      _erro = 'Erro ao carregar planos. Tente novamente.';
      debugPrint('PlanoProvider.carregarPlanos erro: $e');
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }
}
