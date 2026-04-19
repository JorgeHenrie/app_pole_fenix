import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/movimento_pole.dart';
import '../services/firebase/firestore_service.dart';

class MovimentoPoleRepository {
  static const String _colecao = 'movimentos_pole';
  static const String _colecaoJornada = 'jornada_movimentos';

  final FirestoreService _firestore = FirestoreService();

  Future<List<MovimentoPole>> listarTodos() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    final movimentos = snapshot.docs
        .map((doc) => MovimentoPole.fromMap(doc.data(), doc.id))
        .toList();

    movimentos.sort((a, b) {
      final porNivel = a.nivel.ordem.compareTo(b.nivel.ordem);
      if (porNivel != 0) return porNivel;
      return a.nome.compareTo(b.nome);
    });

    return movimentos;
  }

  Future<List<MovimentoPole>> listarAtivos() async {
    final movimentos = await listarTodos();
    return movimentos.where((movimento) => movimento.ativo).toList();
  }

  Future<MovimentoPole?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return MovimentoPole.fromMap(doc.data()!, doc.id);
  }

  Future<String> criar(MovimentoPole movimento) {
    return _firestore.adicionar(colecao: _colecao, dados: movimento.toMap());
  }

  Future<void> atualizar(MovimentoPole movimento) {
    return _firestore.atualizar(
      colecao: _colecao,
      id: movimento.id,
      dados: movimento.toMap(),
    );
  }

  Future<void> deletar(String id) async {
    final vinculados = await FirebaseFirestore.instance
        .collection(_colecaoJornada)
        .where('movimentoId', isEqualTo: id)
        .limit(1)
        .get();

    if (vinculados.docs.isNotEmpty) {
      throw StateError(
        'Esse movimento já foi liberado para uma aluna. Remova os vínculos antes de excluir.',
      );
    }

    await _firestore.remover(colecao: _colecao, id: id);
  }

  Future<void> sincronizarNivel(NivelDificuldadeMovimento nivel) async {
    final snapshot =
        await FirebaseFirestore.instance.collection(_colecao).get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    var atualizou = false;

    for (final doc in snapshot.docs) {
      final movimento = MovimentoPole.fromMap(doc.data(), doc.id);
      if (movimento.nivel.id != nivel.id) continue;
      batch.update(doc.reference, nivel.toEmbeddedMap());
      atualizou = true;
    }

    if (atualizou) {
      await batch.commit();
    }
  }
}
