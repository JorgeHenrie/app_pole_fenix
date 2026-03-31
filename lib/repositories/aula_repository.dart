import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/aula.dart';
import '../services/firebase/firestore_service.dart';

class AulaRepository {
  static const String _colecao = 'aulas';
  final FirestoreService _firestore = FirestoreService();

  Future<Aula?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Aula.fromMap(doc.data()!, doc.id);
  }

  Future<List<Aula>> listarProximas() async {
    final agora = DateTime.now().toIso8601String();
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('dataHora', isGreaterThanOrEqualTo: agora)
        .get();
    final aulas = snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .where((a) => a.status == 'agendada')
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return aulas;
  }

  Future<List<Aula>> buscarProximasPorAluna(
    String alunaId, {
    int limite = 3,
  }) async {
    final agora = DateTime.now();
    // Filtramos a data em Dart para evitar incompatibilidade de tipos
    // entre String ISO e Timestamp no Firestore.
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final aulas = snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .where((a) => a.status == 'agendada' && a.dataHora.isAfter(agora))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return aulas.take(limite).toList();
  }

  Future<bool> aulaJaExiste(String horarioFixoId, DateTime dataHora) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('horarioFixoId', isEqualTo: horarioFixoId)
        .where('dataHora', isEqualTo: dataHora.toIso8601String())
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  Future<List<Aula>> buscarHistoricoPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final aulas = snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return aulas;
  }

  Future<List<Aula>> buscarPorHorarioFixo(String horarioFixoId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('horarioFixoId', isEqualTo: horarioFixoId)
        .orderBy('dataHora')
        .get();
    return snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<String> criar(Aula aula) async {
    return _firestore.adicionar(colecao: _colecao, dados: aula.toMap());
  }

  Future<void> atualizar(Aula aula) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: aula.id,
      dados: aula.toMap(),
    );
  }

  Future<void> cancelarAula(
    String aulaId,
    String motivo,
    bool dentroDosPrazo,
  ) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: aulaId,
      dados: {
        'status': 'cancelada',
        'motivoCancelamento': motivo,
        'dataCancelamento': DateTime.now().toIso8601String(),
        'dentroDosPrazo': dentroDosPrazo,
      },
    );
  }

  Future<void> marcarFalta(String aulaId) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: aulaId,
      dados: {'status': 'falta'},
    );
  }

  Future<void> marcarRealizada(String aulaId) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: aulaId,
      dados: {'status': 'realizada'},
    );
  }

  /// Verifica aulas 'agendada' com dataHora no passado e as marca como
  /// 'realizada', descontando o crédito e incrementando aulasRealizadas
  /// na assinatura via WriteBatch atômico.
  /// Retorna o número de aulas que tiveram baixa.
  Future<int> darBaixaAulasPassadas(
    String alunaId,
    String assinaturaId,
  ) async {
    final agora = DateTime.now();

    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .where('status', isEqualTo: 'agendada')
        .get();

    final aulasPassadas = snapshot.docs.where((doc) {
      final aula = Aula.fromMap(doc.data(), doc.id);
      return aula.dataHora.isBefore(agora);
    }).toList();

    if (aulasPassadas.isEmpty) return 0;

    final batch = FirebaseFirestore.instance.batch();

    for (final doc in aulasPassadas) {
      batch.update(
        FirebaseFirestore.instance.collection(_colecao).doc(doc.id),
        {'status': 'realizada'},
      );
    }

    // Decrementar créditos e registrar aulas realizadas atomicamente.
    // Usamos FieldValue.increment para evitar race conditions.
    batch.update(
      FirebaseFirestore.instance.collection('assinaturas').doc(assinaturaId),
      {
        'creditosDisponiveis': FieldValue.increment(-aulasPassadas.length),
        'aulasRealizadas': FieldValue.increment(aulasPassadas.length),
      },
    );

    await batch.commit();
    return aulasPassadas.length;
  }
}
