import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/despesa_studio.dart';

class DespesaStudioRepository {
  static const String _colecao = 'despesas_studio';
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<List<DespesaStudio>> listarDoMes(DateTime referencia) async {
    final inicio = DateTime(referencia.year, referencia.month);
    final fim = DateTime(referencia.year, referencia.month + 1);

    final snapshot = await _db
        .collection(_colecao)
        .where('dataReferencia',
            isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('dataReferencia', isLessThan: Timestamp.fromDate(fim))
        .orderBy('dataReferencia', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => DespesaStudio.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> criar(DespesaStudio despesa) async {
    final ref = await _db.collection(_colecao).add(despesa.toMap());
    return ref.id;
  }

  Future<void> excluir(String despesaId) async {
    await _db.collection(_colecao).doc(despesaId).delete();
  }
}
