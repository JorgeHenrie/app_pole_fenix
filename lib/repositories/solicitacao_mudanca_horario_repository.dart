import '../models/solicitacao_mudanca_horario.dart';
import '../services/firebase/firestore_service.dart';

class SolicitacaoMudancaHorarioRepository {
  static const String _colecao = 'solicitacoes_mudanca_horario';
  final FirestoreService _firestore = FirestoreService();

  Future<String> criar(SolicitacaoMudancaHorario solicitacao) async {
    final dados = solicitacao.toMap();
    if (solicitacao.id.isEmpty) {
      return _firestore.adicionar(colecao: _colecao, dados: dados);
    }
    await _firestore.atualizar(colecao: _colecao, id: solicitacao.id, dados: dados);
    return solicitacao.id;
  }

  Future<List<SolicitacaoMudancaHorario>> listarPendentes() async {
    final snap = await _firestore
        .colecao(_colecao)
        .where('status', isEqualTo: 'pendente')
        .orderBy('solicitadoEm', descending: true)
        .get();
    return snap.docs
        .map((d) => SolicitacaoMudancaHorario.fromMap(d.data(), d.id))
        .toList();
  }

  Future<void> responder(
    String id,
    String status,
    String? resposta,
    String adminId,
  ) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': status,
        'respostaAdmin': resposta,
        'respondidoEm': DateTime.now().toIso8601String(),
        'respondidoPor': adminId,
      },
    );
  }

  Future<List<SolicitacaoMudancaHorario>> listarPorAluna(String alunaId) async {
    final snap = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .orderBy('solicitadoEm', descending: true)
        .get();
    return snap.docs
        .map((d) => SolicitacaoMudancaHorario.fromMap(d.data(), d.id))
        .toList();
  }
}
