import '../models/horario_fixo.dart';
import '../services/firebase/firestore_service.dart';

class HorarioFixoRepository {
  static const String _colecao = 'horarios_fixos';
  final FirestoreService _firestore = FirestoreService();

  Future<List<HorarioFixo>> buscarPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => HorarioFixo.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<HorarioFixo?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return HorarioFixo.fromMap(doc.data()!, doc.id);
  }

  Future<String> criar(HorarioFixo horario) async {
    return _firestore.adicionar(colecao: _colecao, dados: horario.toMap());
  }

  Future<void> atualizar(HorarioFixo horario) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: horario.id,
      dados: horario.toMap(),
    );
  }

  Future<void> desativar(String id, String motivo) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'ativo': false,
        'desativadoEm': DateTime.now().toIso8601String(),
        'motivoDesativacao': motivo,
      },
    );
  }

  Future<int> contarOcupacao(int diaSemana, String horario) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('diaSemana', isEqualTo: diaSemana)
        .where('horario', isEqualTo: horario)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs.length;
  }

  Future<List<HorarioFixo>> buscarTodosAtivos() async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => HorarioFixo.fromMap(doc.data(), doc.id))
        .toList();
  }

  Future<List<HorarioFixo>> buscarPorDiaHorario(
    int diaSemana,
    String horario,
  ) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('diaSemana', isEqualTo: diaSemana)
        .where('horario', isEqualTo: horario)
        .where('ativo', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => HorarioFixo.fromMap(doc.data(), doc.id))
        .toList();
  }
}
