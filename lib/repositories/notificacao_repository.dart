import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/notificacao.dart';
import '../models/usuario.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas notificações persistidas no Firestore.
class NotificacaoRepository {
  static const String _colecao = 'notificacoes';

  final FirestoreService _firestore = FirestoreService();

  Stream<List<Notificacao>> observarPorUsuario(String usuarioId) {
    return FirebaseFirestore.instance
        .collection(_colecao)
        .where('usuarioId', isEqualTo: usuarioId)
        .orderBy('criadaEm', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Notificacao.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<List<Notificacao>> observarCadastrosPendentesParaAdmin(
    String adminId,
  ) {
    return FirebaseFirestore.instance
        .collection('usuarios')
        .where('tipoUsuario', isEqualTo: 'aluna')
        .where('statusCadastro', isEqualTo: 'pendente')
        .snapshots()
        .map((snapshot) {
      final notificacoes = snapshot.docs.map((doc) {
        final usuario = Usuario.fromFirestore(doc);
        return Notificacao(
          id: 'cadastro_pendente:${usuario.id}',
          usuarioId: adminId,
          titulo: 'Novo cadastro aguardando aprovação',
          mensagem: '${usuario.nome} solicitou acesso ao aplicativo.',
          tipo: 'cadastro_pendente',
          referenciaId: usuario.id,
          lida: false,
          criadaEm: usuario.dataCadastro,
        );
      }).toList()
        ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));

      return notificacoes;
    });
  }

  Future<void> marcarComoLida(String notificacaoId) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: notificacaoId,
      dados: {'lida': true},
    );
  }

  Future<void> marcarTodasComoLidas(String usuarioId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('usuarioId', isEqualTo: usuarioId)
        .where('lida', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {'lida': true});
    }

    await batch.commit();
  }
}
