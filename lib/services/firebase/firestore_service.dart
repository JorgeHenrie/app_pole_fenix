import 'package:cloud_firestore/cloud_firestore.dart';

/// Serviço genérico para operações no Firestore.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Retorna uma referência para uma coleção.
  CollectionReference<Map<String, dynamic>> colecao(String caminho) {
    return _db.collection(caminho);
  }

  /// Busca um documento pelo id em uma coleção.
  Future<DocumentSnapshot<Map<String, dynamic>>> buscarDocumento({
    required String colecao,
    required String id,
  }) {
    return _db.collection(colecao).doc(id).get();
  }

  /// Adiciona um documento a uma coleção e retorna o id gerado.
  Future<String> adicionar({
    required String colecao,
    required Map<String, dynamic> dados,
  }) async {
    final ref = await _db.collection(colecao).add(dados);
    return ref.id;
  }

  /// Atualiza campos de um documento existente.
  Future<void> atualizar({
    required String colecao,
    required String id,
    required Map<String, dynamic> dados,
  }) {
    return _db.collection(colecao).doc(id).update(dados);
  }

  /// Remove um documento de uma coleção.
  Future<void> remover({
    required String colecao,
    required String id,
  }) {
    return _db.collection(colecao).doc(id).delete();
  }
}
