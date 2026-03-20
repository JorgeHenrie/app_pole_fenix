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
    return snapshot.docs
        .map((doc) => GradeHorario.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<GradeHorario>> listarTodos() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    return snapshot.docs
        .map((doc) => GradeHorario.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<GradeHorario>> listarPorDia(int diaSemana) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('diaSemana', isEqualTo: diaSemana)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => GradeHorario.fromMap(doc.data(), doc.id))
        .toList();
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
    final doc = snapshot.docs.first;
    return GradeHorario.fromMap(doc.data(), doc.id);
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
}
