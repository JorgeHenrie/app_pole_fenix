import 'package:flutter/foundation.dart';
import '../models/reposicao.dart';
import '../repositories/reposicao_repository.dart';

class ResultadoCancelamentoReposicao {
  final String? erro;
  final bool manteveReposicao;
  final String? mensagemSucesso;

  const ResultadoCancelamentoReposicao({
    this.erro,
    this.manteveReposicao = false,
    this.mensagemSucesso,
  });

  bool get sucesso => erro == null;
}

class ResultadoAgendamentoReposicao {
  final String? erro;
  final String? mensagemSucesso;

  const ResultadoAgendamentoReposicao({
    this.erro,
    this.mensagemSucesso,
  });

  bool get sucesso => erro == null;
}

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
  List<Reposicao> get historico => _reposicoes
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

  Future<ResultadoAgendamentoReposicao> agendarReposicao(
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
      return const ResultadoAgendamentoReposicao(
        mensagemSucesso: 'Reposicao agendada com sucesso.',
      );
    } catch (e) {
      debugPrint('ReposicaoProvider.agendarReposicao: $e');
      final texto = e.toString();
      return ResultadoAgendamentoReposicao(
        erro: texto.startsWith('Bad state: ')
            ? texto.substring('Bad state: '.length)
            : 'Erro ao agendar a reposicao.',
      );
    }
  }

  Future<ResultadoCancelamentoReposicao> cancelarReposicaoAgendada(
    Reposicao reposicao,
  ) async {
    final dataHora = reposicao.novaDataHora;
    if (dataHora == null) {
      return const ResultadoCancelamentoReposicao(
        erro: 'Essa reposição não possui horário agendado.',
      );
    }

    final agora = DateTime.now();
    if (dataHora.isBefore(agora)) {
      return const ResultadoCancelamentoReposicao(
        erro: 'Não é possível cancelar reposições passadas.',
      );
    }

    final dentroDoPrazo = dataHora.difference(agora).inHours >= 2;

    try {
      if (dentroDoPrazo) {
        await _repository.desagendar(reposicao.id);
        _reposicoes = _reposicoes.map((item) {
          if (item.id != reposicao.id) return item;
          return item.copyWith(
            status: 'pendente',
            novaDataHora: null,
            novoHorarioId: null,
            agendadaEm: null,
          );
        }).toList();
      } else {
        await _repository.marcarExpirada(reposicao.id);
        _reposicoes = _reposicoes.map((item) {
          if (item.id != reposicao.id) return item;
          return item.copyWith(status: 'expirada');
        }).toList();
      }

      notifyListeners();
      return ResultadoCancelamentoReposicao(
        manteveReposicao: dentroDoPrazo,
        mensagemSucesso: dentroDoPrazo
            ? 'Reposição cancelada. Ela voltou a ficar disponível para reagendamento.'
            : 'Reposição cancelada. Você perdeu esta reposição.',
      );
    } catch (e) {
      debugPrint('ReposicaoProvider.cancelarReposicaoAgendada: $e');
      return const ResultadoCancelamentoReposicao(
        erro: 'Erro ao cancelar a reposição. Tente novamente.',
      );
    }
  }

  void limpar() {
    _reposicoes = [];
    _erro = null;
    notifyListeners();
  }
}
