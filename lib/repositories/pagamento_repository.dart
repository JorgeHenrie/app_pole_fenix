import '../models/pagamento.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de pagamentos.
class PagamentoRepository {
  static const String _colecao = 'pagamentos';
  final FirestoreService _firestore = FirestoreService();

  /// Lista os pagamentos de uma aluna em ordem decrescente.
  Future<List<Pagamento>> listarDeAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .orderBy('criadoEm', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => Pagamento.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Registra um novo pagamento e retorna seu id.
  Future<String> registrar(Pagamento pagamento) async {
    return _firestore.adicionar(
      colecao: _colecao,
      dados: pagamento.toMap(),
    );
  }
}
