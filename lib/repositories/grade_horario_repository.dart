import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/grade_horario.dart';
import '../services/firebase/firestore_service.dart';

class GradeHorarioRepository {
  static const String _colecao = 'grade_horarios';
  final FirestoreService _firestore = FirestoreService();

  Future<List<GradeHorario>> listarAtivos() async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => GradeHorario.fromFirestore(doc)).toList();
  }

  Future<List<GradeHorario>> listarTodos() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    return snapshot.docs.map((doc) => GradeHorario.fromFirestore(doc)).toList();
  }

  Future<List<GradeHorario>> listarPorDia(int diaSemana) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('diaSemana', isEqualTo: diaSemana)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => GradeHorario.fromFirestore(doc)).toList();
  }

  Future<GradeHorario?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return GradeHorario.fromMap(doc.data()!, doc.id);
  }

  Future<GradeHorario?> buscarPorDiaHorario(
    int diaSemana,
    String horario,
  ) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('diaSemana', isEqualTo: diaSemana)
        .where('horario', isEqualTo: horario)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return GradeHorario.fromFirestore(snapshot.docs.first);
  }

  Future<String> criar(GradeHorario gradeHorario) async {
    return _firestore.adicionar(
      colecao: _colecao,
      dados: gradeHorario.toMap(),
    );
  }

  Future<void> atualizar(GradeHorario gradeHorario) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: gradeHorario.id,
      dados: gradeHorario.toMap(),
    );
  }

  Future<void> ativarDesativar(String id, bool ativo) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {'ativo': ativo},
    );
  }

  /// Retorna os primeiros nomes das alunas matriculadas neste slot via horário fixo.
  Future<List<String>> buscarNomesFixosPorSlot(
    int diaSemana,
    String horario,
  ) async {
    final snapshot = await _firestore
        .colecao('horarios_fixos')
        .where('diaSemana', isEqualTo: diaSemana)
        .where('horario', isEqualTo: horario)
        .where('ativo', isEqualTo: true)
        .get();

    final alunaIds = snapshot.docs
        .map((doc) => doc.data()['alunaId'] as String?)
        .whereType<String>()
        .toList();

    if (alunaIds.isEmpty) return [];
    return _buscarPrimeirosNomes(alunaIds);
  }

  /// Retorna os primeiros nomes das alunas que agendaram reposição neste slot e data.
  Future<List<String>> buscarNomesReposicoesPorSlot(
    String gradeHorarioId,
    DateTime dataHora,
  ) async {
    final snapshot = await _firestore
        .colecao('reposicoes')
        .where('novoHorarioId', isEqualTo: gradeHorarioId)
        .where('status', isEqualTo: 'agendada')
        .get();

    final alunaIds = snapshot.docs
        .where((doc) {
          final raw = doc.data()['novaDataHora'];
          if (raw == null) return false;
          DateTime? dt;
          if (raw is Timestamp) {
            dt = raw.toDate();
          } else if (raw is String) {
            dt = DateTime.tryParse(raw);
          }
          if (dt == null) return false;
          return dt.year == dataHora.year &&
              dt.month == dataHora.month &&
              dt.day == dataHora.day &&
              dt.hour == dataHora.hour &&
              dt.minute == dataHora.minute;
        })
        .map((doc) => doc.data()['alunaId'] as String?)
        .whereType<String>()
        .toList();

    if (alunaIds.isEmpty) return [];
    return _buscarPrimeirosNomes(alunaIds);
  }

  Future<List<String>> _buscarPrimeirosNomes(List<String> ids) async {
    final nomes = <String>[];
    for (var i = 0; i < ids.length; i += 10) {
      final batch = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      for (final doc in snap.docs) {
        final nome = doc.data()['nome'] as String? ?? '';
        if (nome.isNotEmpty) {
          nomes.add(nome.trim().split(' ').first);
        }
      }
    }
    return nomes;
  }
}
