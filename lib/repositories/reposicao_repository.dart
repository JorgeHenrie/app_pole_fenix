import '../models/reposicao.dart';
import '../services/firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReposicaoRepository {
  static const String _colecao = 'reposicoes';
  final FirestoreService _firestore = FirestoreService();

  Future<List<Reposicao>> buscarPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final reposicoes = snapshot.docs
        .map((doc) {
          try {
            return Reposicao.fromFirestore(doc);
          } catch (e) {
            return null;
          }
        })
        .whereType<Reposicao>()
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
        'novaDataHora': Timestamp.fromDate(novaDataHora),
        'novoHorarioId': novoHorarioId,
        'agendadaEm': Timestamp.fromDate(DateTime.now()),
      },
    );
  }

  Future<void> marcarRealizada(String id) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'realizada',
        'realizadaEm': Timestamp.fromDate(DateTime.now()),
      },
    );
  }
}
