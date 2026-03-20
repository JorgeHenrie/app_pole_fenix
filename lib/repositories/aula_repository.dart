import '../models/aula.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de aulas.
class AulaRepository {
  static const String _colecao = 'aulas';
  final FirestoreService _firestore = FirestoreService();

  /// Busca uma aula pelo id.
  Future<Aula?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Aula.fromMap(doc.data()!, doc.id);
  }

  /// Lista todas as aulas agendadas a partir de hoje.
  Future<List<Aula>> listarProximas() async {
    final agora = DateTime.now().toIso8601String();
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('status', isEqualTo: 'agendada')
        .where('dataHora', isGreaterThanOrEqualTo: agora)
        .orderBy('dataHora')
        .get();
    return snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Cria uma nova aula e retorna seu id.
  Future<String> criar(Aula aula) async {
    return _firestore.adicionar(colecao: _colecao, dados: aula.toMap());
  }

  /// Atualiza os dados de uma aula existente.
  Future<void> atualizar(Aula aula) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: aula.id,
      dados: aula.toMap(),
    );
  }
}
