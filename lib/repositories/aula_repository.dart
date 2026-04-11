import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/aula.dart';
import '../services/firebase/firestore_service.dart';

class AulaRepository {
  static const String _colecao = 'aulas';
  final FirestoreService _firestore = FirestoreService();

  bool _mesmaDataHora(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  bool _estaNoPeriodo(DateTime dataHora, DateTime inicio, DateTime limite) {
    return !dataHora.isBefore(inicio) && !dataHora.isAfter(limite);
  }

  Future<Aula?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Aula.fromFirestore(doc);
  }

  Future<List<Aula>> listarProximas() async {
    final agora = DateTime.now();
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('status', isEqualTo: 'agendada')
        .get();
    final aulas = snapshot.docs
        .map((doc) => Aula.fromFirestore(doc))
        .where((a) => !a.dataHora.isBefore(agora))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return aulas;
  }

  Future<Aula?> buscarPorHorarioFixoEDataHora(
    String horarioFixoId,
    DateTime dataHora,
  ) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('horarioFixoId', isEqualTo: horarioFixoId)
        .get();

    Aula? cancelada;
    for (final doc in snapshot.docs) {
      final aula = Aula.fromFirestore(doc);
      if (!_mesmaDataHora(aula.dataHora, dataHora)) continue;
      if (aula.status != 'cancelada') return aula;
      cancelada ??= aula;
    }

    return cancelada;
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
        .map((doc) => Aula.fromFirestore(doc))
        .where((a) => a.status == 'agendada' && a.dataHora.isAfter(agora))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return aulas.take(limite).toList();
  }

  Future<List<Aula>> buscarPorAlunaNoPeriodo(
    String alunaId, {
    required DateTime inicio,
    required DateTime limite,
  }) async {
    final docsPorId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    var consultaPorPeriodoExecutada = false;

    Future<void> tentarConsultaPorPeriodo(
      dynamic inicioFiltro,
      dynamic limiteFiltro,
    ) async {
      try {
        final snapshot = await _firestore
            .colecao(_colecao)
            .where('alunaId', isEqualTo: alunaId)
            .where('dataHora', isGreaterThanOrEqualTo: inicioFiltro)
            .where('dataHora', isLessThanOrEqualTo: limiteFiltro)
            .get();
        consultaPorPeriodoExecutada = true;
        for (final doc in snapshot.docs) {
          docsPorId[doc.id] = doc;
        }
      } catch (e) {
        debugPrint('AulaRepository.buscarPorAlunaNoPeriodo: $e');
      }
    }

    await tentarConsultaPorPeriodo(
      inicio.toIso8601String(),
      limite.toIso8601String(),
    );
    await tentarConsultaPorPeriodo(
      Timestamp.fromDate(inicio),
      Timestamp.fromDate(limite),
    );

    if (!consultaPorPeriodoExecutada) {
      final snapshot = await _firestore
          .colecao(_colecao)
          .where('alunaId', isEqualTo: alunaId)
          .get();
      for (final doc in snapshot.docs) {
        docsPorId[doc.id] = doc;
      }
    }

    final aulas = docsPorId.values
        .map((doc) => Aula.fromFirestore(doc))
        .where((aula) => _estaNoPeriodo(aula.dataHora, inicio, limite))
        .toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

    return aulas;
  }

  Future<bool> aulaJaExiste(String horarioFixoId, DateTime dataHora) async {
    return buscarPorHorarioFixoEDataHora(horarioFixoId, dataHora)
        .then((aula) => aula != null);
  }

  Future<List<Aula>> buscarHistoricoPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final aulas = snapshot.docs
        .map((doc) {
          try {
            return Aula.fromFirestore(doc);
          } catch (e) {
            return null;
          }
        })
        .whereType<Aula>()
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return aulas;
  }

  Future<List<Aula>> buscarPorHorarioFixo(String horarioFixoId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('horarioFixoId', isEqualTo: horarioFixoId)
        .get();
    final aulas = snapshot.docs.map((doc) => Aula.fromFirestore(doc)).toList()
      ..sort((a, b) => a.dataHora.compareTo(b.dataHora));
    return aulas;
  }

  Future<String> criar(Aula aula) async {
    final id = aula.id.trim();
    if (id.isEmpty) {
      return _firestore.adicionar(colecao: _colecao, dados: aula.toMap());
    }

    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(id)
        .set(aula.toMap());
    return id;
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
        'origemCancelamento': 'aluna',
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
      try {
        final aula = Aula.fromFirestore(doc);
        return aula.dataHora.isBefore(agora);
      } catch (_) {
        return false;
      }
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
