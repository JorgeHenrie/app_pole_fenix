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
    final agora = DateTime.now().toIso8601String();
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .where('dataHora', isGreaterThanOrEqualTo: agora)
        .get();
    final aulas = snapshot.docs
        .map((doc) => Aula.fromMap(doc.data(), doc.id))
        .where((a) => a.status == 'agendada')
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
}
