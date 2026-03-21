import 'package:cloud_firestore/cloud_firestore.dart';
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

  /// Cria um novo documento de usuária no Firestore usando o UID como id.
  Future<void> criar(Usuario usuario) async {
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(usuario.id)
        .set(usuario.toMap());
  }

  /// Salva ou atualiza os dados de uma usuária.
  Future<void> salvar(Usuario usuario) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: usuario.id,
      dados: usuario.toMap(),
    );
  }

  /// Busca uma usuária pelo e-mail.
  Future<Usuario?> buscarPorEmail(String email) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return null;
    final doc = querySnapshot.docs.first;
    return Usuario.fromMap(doc.data(), doc.id);
  }

  /// Retorna lista de alunas com cadastro pendente de aprovação.
  Future<List<Usuario>> buscarPendentes() async {
    final snap = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('tipoUsuario', isEqualTo: 'aluna')
        .where('statusCadastro', isEqualTo: 'pendente')
        .orderBy('dataCadastro', descending: true)
        .get();
    return snap.docs.map((d) => Usuario.fromMap(d.data(), d.id)).toList();
  }

  /// Aprova o cadastro de uma aluna.
  Future<void> aprovar(String alunaId, String adminId) async {
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(alunaId)
        .update({
      'statusCadastro': 'aprovado',
      'dataAprovacao': DateTime.now().toIso8601String(),
      'aprovadoPor': adminId,
      'motivoRejeicao': null,
    });
  }

  /// Rejeita o cadastro de uma aluna com motivo opcional.
  Future<void> rejeitar(
      String alunaId, String adminId, String? motivo) async {
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(alunaId)
        .update({
      'statusCadastro': 'rejeitado',
      'dataAprovacao': DateTime.now().toIso8601String(),
      'aprovadoPor': adminId,
      'motivoRejeicao': motivo,
    });
  }
}
