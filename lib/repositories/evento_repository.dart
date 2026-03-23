import '../models/evento.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de eventos.
class EventoRepository {
  static const String _colecao = 'eventos';
  final FirestoreService _firestore = FirestoreService();

  /// Lista todos os eventos publicados, ordenados por data.
  Future<List<Evento>> listarPublicados() async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('publicado', isEqualTo: true)
        .get();
    final eventos = snapshot.docs
        .map((doc) => Evento.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return eventos;
  }

  /// Cria um novo evento e retorna seu id.
  Future<String> criar(Evento evento) async {
    return _firestore.adicionar(colecao: _colecao, dados: evento.toMap());
  }

  /// Remove um evento pelo id.
  Future<void> remover(String id) async {
    await _firestore.remover(colecao: _colecao, id: id);
  }
}
