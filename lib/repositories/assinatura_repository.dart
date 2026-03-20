import '../models/assinatura.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de assinaturas.
class AssinaturaRepository {
  static const String _colecao = 'assinaturas';
  final FirestoreService _firestore = FirestoreService();

  /// Busca a assinatura ativa de uma aluna.
  Future<Assinatura?> buscarAtivaDeAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .where('status', isEqualTo: 'ativa')
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Assinatura.fromMap(doc.data(), doc.id);
  }

  /// Salva ou atualiza os dados de uma assinatura.
  Future<void> salvar(Assinatura assinatura) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: assinatura.id,
      dados: assinatura.toMap(),
    );
  }
}
