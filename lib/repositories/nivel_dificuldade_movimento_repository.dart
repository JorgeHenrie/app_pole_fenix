import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/movimento_pole.dart';
import '../services/firebase/firestore_service.dart';

class NivelDificuldadeMovimentoRepository {
  static const String _colecao = 'niveis_dificuldade_movimento';

  final FirestoreService _firestore = FirestoreService();

  Future<List<NivelDificuldadeMovimento>> listarTodos({
    bool incluirInativos = true,
  }) async {
    final snapshot = await _firestore.colecao(_colecao).get();
    final niveis = {
      for (final nivel in NivelDificuldadeMovimento.padroes) nivel.id: nivel,
    };

    for (final doc in snapshot.docs) {
      niveis[doc.id] = NivelDificuldadeMovimento.fromMap(doc.data(), doc.id);
    }

    final lista =
        niveis.values.where((nivel) => incluirInativos || nivel.ativo).toList()
          ..sort((a, b) {
            final porOrdem = a.ordem.compareTo(b.ordem);
            if (porOrdem != 0) return porOrdem;
            return a.label.compareTo(b.label);
          });

    return lista;
  }

  Future<List<NivelDificuldadeMovimento>> listarAtivos() {
    return listarTodos(incluirInativos: false);
  }

  Future<void> salvar(NivelDificuldadeMovimento nivel) async {
    final id = nivel.id.trim().isEmpty
        ? NivelDificuldadeMovimento.normalizarId(nivel.label)
        : nivel.id;

    if (id.isEmpty) {
      throw StateError('Informe um nome válido para o nível.');
    }

    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(id)
        .set(nivel.copyWith(id: id).toMap(), SetOptions(merge: true));
  }
}
