import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/grade_horario.dart';
import '../services/firebase/firestore_service.dart';

class GradeHorarioRepository {
  static const String _colecao = 'grade_horarios';
  final FirestoreService _firestore = FirestoreService();

  static String _chaveSlot(int diaSemana, String horario) {
    return '${diaSemana}_$horario';
  }

  static String _chaveReposicao(String gradeHorarioId, DateTime dataHora) {
    return '$gradeHorarioId|${dataHora.toIso8601String()}';
  }

  DateTime? _parseDateNullable(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

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

  Future<void> excluir(String id) async {
    await _firestore.remover(
      colecao: _colecao,
      id: id,
    );
  }

  Future<Map<String, List<String>>> buscarNomesFixosPorSlots(
    Iterable<GradeHorario> grades,
  ) async {
    final gradeList = grades.toList();
    if (gradeList.isEmpty) return {};

    final chavesValidas = {
      for (final grade in gradeList) _chaveSlot(grade.diaSemana, grade.horario),
    };

    final snapshot = await _firestore
        .colecao('horarios_fixos')
        .where('ativo', isEqualTo: true)
        .get();

    final alunaIdsPorSlot = <String, List<String>>{};
    final todosAlunaIds = <String>{};

    for (final doc in snapshot.docs) {
      final dados = doc.data();
      final diaSemana = dados['diaSemana'] as int?;
      final horario = dados['horario'] as String?;
      final alunaId = dados['alunaId'] as String?;
      if (diaSemana == null || horario == null || alunaId == null) continue;

      final chave = _chaveSlot(diaSemana, horario);
      if (!chavesValidas.contains(chave)) continue;

      final ids = alunaIdsPorSlot.putIfAbsent(chave, () => []);
      if (!ids.contains(alunaId)) {
        ids.add(alunaId);
      }
      todosAlunaIds.add(alunaId);
    }

    final nomesPorId =
        await _buscarPrimeirosNomesPorIds(todosAlunaIds.toList());

    final resultado = <String, List<String>>{};
    for (final entry in alunaIdsPorSlot.entries) {
      resultado[entry.key] =
          entry.value.map((id) => nomesPorId[id]).whereType<String>().toList();
    }

    return resultado;
  }

  Future<Map<String, List<String>>> buscarNomesReposicoesPorPeriodo({
    required Iterable<String> gradeHorarioIds,
    required DateTime inicio,
    required DateTime limite,
  }) async {
    final ids = gradeHorarioIds.toSet().toList();
    if (ids.isEmpty) return {};

    final docsPorId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    for (var i = 0; i < ids.length; i += 10) {
      final lote = ids.sublist(i, (i + 10).clamp(0, ids.length));
      final reposicoes = await _buscarReposicoesAgendadas(lote, inicio, limite);
      for (final doc in reposicoes) {
        docsPorId[doc.id] = doc;
      }
    }

    final alunaIdsPorReposicao = <String, List<String>>{};
    final todosAlunaIds = <String>{};

    for (final doc in docsPorId.values) {
      final dados = doc.data();
      final gradeHorarioId = dados['novoHorarioId'] as String?;
      final alunaId = dados['alunaId'] as String?;
      final dataHora = _parseDateNullable(dados['novaDataHora']);
      if (gradeHorarioId == null || alunaId == null || dataHora == null)
        continue;
      if (dataHora.isBefore(inicio) || dataHora.isAfter(limite)) continue;

      final chave = _chaveReposicao(gradeHorarioId, dataHora);
      final idsNoSlot = alunaIdsPorReposicao.putIfAbsent(chave, () => []);
      if (!idsNoSlot.contains(alunaId)) {
        idsNoSlot.add(alunaId);
      }
      todosAlunaIds.add(alunaId);
    }

    final nomesPorId =
        await _buscarPrimeirosNomesPorIds(todosAlunaIds.toList());

    final resultado = <String, List<String>>{};
    for (final entry in alunaIdsPorReposicao.entries) {
      resultado[entry.key] =
          entry.value.map((id) => nomesPorId[id]).whereType<String>().toList();
    }

    return resultado;
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _buscarReposicoesAgendadas(
    List<String> gradeHorarioIds,
    DateTime inicio,
    DateTime limite,
  ) async {
    final docsPorId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    var consultaPorPeriodoExecutada = false;

    Future<void> tentarConsultaPorPeriodo(
      dynamic inicioFiltro,
      dynamic limiteFiltro,
    ) async {
      try {
        final snapshot = await _firestore
            .colecao('reposicoes')
            .where('status', isEqualTo: 'agendada')
            .where('novoHorarioId', whereIn: gradeHorarioIds)
            .where('novaDataHora', isGreaterThanOrEqualTo: inicioFiltro)
            .where('novaDataHora', isLessThanOrEqualTo: limiteFiltro)
            .get();
        consultaPorPeriodoExecutada = true;
        for (final doc in snapshot.docs) {
          docsPorId[doc.id] = doc;
        }
      } catch (e) {
        debugPrint('GradeHorarioRepository._buscarReposicoesAgendadas: $e');
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

    if (consultaPorPeriodoExecutada) {
      return docsPorId.values.toList();
    }

    try {
      final snapshot = await _firestore
          .colecao('reposicoes')
          .where('status', isEqualTo: 'agendada')
          .where('novoHorarioId', whereIn: gradeHorarioIds)
          .get();
      for (final doc in snapshot.docs) {
        docsPorId[doc.id] = doc;
      }
      return docsPorId.values.toList();
    } catch (e) {
      debugPrint(
          'GradeHorarioRepository._buscarReposicoesAgendadas fallback: $e');
    }

    for (final gradeHorarioId in gradeHorarioIds) {
      try {
        final snapshot = await _firestore
            .colecao('reposicoes')
            .where('novoHorarioId', isEqualTo: gradeHorarioId)
            .where('status', isEqualTo: 'agendada')
            .get();
        for (final doc in snapshot.docs) {
          docsPorId[doc.id] = doc;
        }
      } catch (e) {
        debugPrint(
          'GradeHorarioRepository._buscarReposicoesAgendadas legado [$gradeHorarioId]: $e',
        );
      }
    }

    return docsPorId.values.toList();
  }

  Future<List<String>> _buscarPrimeirosNomes(List<String> ids) async {
    final nomesPorId = await _buscarPrimeirosNomesPorIds(ids);
    return ids.map((id) => nomesPorId[id]).whereType<String>().toList();
  }

  Future<Map<String, String>> _buscarPrimeirosNomesPorIds(
      List<String> ids) async {
    final nomesPorId = <String, String>{};
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
          nomesPorId[doc.id] = nome.trim().split(' ').first;
        }
      }
    }

    for (final id in ids) {
      final nome = nomesPorId[id];
      if (nome != null) {
        nomes.add(nome);
      }
    }

    return nomesPorId;
  }
}
