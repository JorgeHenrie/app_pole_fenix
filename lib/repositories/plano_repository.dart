import '../models/plano.dart';
import '../services/firebase/firestore_service.dart';

class PlanoRepository {
  static const String _colecao = 'planos';
  final FirestoreService _firestore = FirestoreService();

  Future<List<Plano>> listarAtivos() async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => Plano.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<Plano?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Plano.fromMap(doc.data()!, doc.id);
  }

  Future<String> criar(Plano plano) async {
    return _firestore.adicionar(colecao: _colecao, dados: plano.toMap());
  }

  Future<List<Plano>> listarTodos() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    return snapshot.docs
        .map((doc) => Plano.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<void> atualizar(Plano plano) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: plano.id,
      dados: plano.toMap(),
    );
  }

  Future<void> deletar(String id) async {
    await _firestore.remover(colecao: _colecao, id: id);
  }
}
