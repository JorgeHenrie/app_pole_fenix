import 'package:flutter/foundation.dart';
import '../models/reposicao.dart';
import '../repositories/reposicao_repository.dart';

class ReposicaoProvider extends ChangeNotifier {
  final ReposicaoRepository _repository = ReposicaoRepository();

  List<Reposicao> _reposicoes = [];
  bool _carregando = false;
  String? _erro;

  List<Reposicao> get reposicoes => List.unmodifiable(_reposicoes);
  List<Reposicao> get pendentes =>
      _reposicoes.where((r) => r.status == 'pendente' && !r.expirou).toList();
  List<Reposicao> get agendadas =>
      _reposicoes.where((r) => r.status == 'agendada').toList();
  List<Reposicao> get historico =>
      _reposicoes
          .where((r) => r.status == 'realizada' || r.status == 'expirada')
          .toList();
  bool get carregando => _carregando;
  String? get erro => _erro;
  int get quantidadePendentes => pendentes.length;

  Future<void> carregarPorAluna(String alunaId) async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _reposicoes = await _repository.buscarPorAluna(alunaId);
    } catch (e) {
      _erro = 'Erro ao carregar reposições.';
      debugPrint('ReposicaoProvider.carregarPorAluna: $e');
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<bool> agendarReposicao(
    String reposicaoId,
    DateTime novaDataHora,
    String novoHorarioId,
  ) async {
    try {
      await _repository.agendar(reposicaoId, novaDataHora, novoHorarioId);
      _reposicoes = _reposicoes.map((r) {
        if (r.id == reposicaoId) {
          return r.copyWith(
            status: 'agendada',
            novaDataHora: novaDataHora,
            novoHorarioId: novoHorarioId,
            agendadaEm: DateTime.now(),
          );
        }
        return r;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('ReposicaoProvider.agendarReposicao: $e');
      return false;
    }
  }

  void limpar() {
    _reposicoes = [];
    _erro = null;
    notifyListeners();
  }
}
