import '../models/reposicao.dart';
import '../services/firebase/firestore_service.dart';

class ReposicaoRepository {
  static const String _colecao = 'reposicoes';
  final FirestoreService _firestore = FirestoreService();

  Future<List<Reposicao>> buscarPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final reposicoes = snapshot.docs
        .map((doc) => Reposicao.fromFirestore(doc))
        .toList()
      ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));
    return reposicoes;
  }

  Future<List<Reposicao>> buscarPendentesPorAluna(String alunaId) async {
    final agora = DateTime.now();
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .where('status', isEqualTo: 'pendente')
        .get();
    return snapshot.docs
        .map((doc) => Reposicao.fromFirestore(doc))
        .where((r) => r.expiraEm == null || r.expiraEm!.isAfter(agora))
        .toList();
  }

  Future<String> criar(Reposicao reposicao) async {
    return _firestore.adicionar(
      colecao: _colecao,
      dados: reposicao.toMap(),
    );
  }

  Future<void> atualizar(Reposicao reposicao) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: reposicao.id,
      dados: reposicao.toMap(),
    );
  }

  Future<void> agendar(
    String id,
    DateTime novaDataHora,
    String novoHorarioId,
  ) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'agendada',
        'novaDataHora': novaDataHora.toIso8601String(),
        'novoHorarioId': novoHorarioId,
        'agendadaEm': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<void> marcarRealizada(String id) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'realizada',
        'realizadaEm': DateTime.now().toIso8601String(),
      },
    );
  }
}
