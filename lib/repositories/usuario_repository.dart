import '../models/usuario.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de usuárias.
class UsuarioRepository {
  static const String _colecao = 'usuarios';
  final FirestoreService _firestore = FirestoreService();

  /// Busca uma usuária pelo id.
  Future<Usuario?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Usuario.fromMap(doc.data()!, doc.id);
  }

  /// Salva ou atualiza os dados de uma usuária.
  Future<void> salvar(Usuario usuario) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: usuario.id,
      dados: usuario.toMap(),
    );
  }
}
