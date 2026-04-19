import '../models/reposicao.dart';
import '../services/firebase/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/aula.dart';

import 'assinatura_repository.dart';

class ReposicaoRepository {
  static const String _colecao = 'reposicoes';
  final FirestoreService _firestore = FirestoreService();
  final AssinaturaRepository _assinaturaRepository = AssinaturaRepository();

  Future<List<Reposicao>> buscarPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();
    final reposicoes = snapshot.docs
        .map((doc) {
          try {
            return Reposicao.fromFirestore(doc);
          } catch (e) {
            return null;
          }
        })
        .whereType<Reposicao>()
        .toList()
      ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));
    return _normalizarValidadePeloCicloAtual(alunaId, reposicoes);
  }

  Future<List<Reposicao>> buscarPendentesPorAluna(String alunaId) async {
    final agora = DateTime.now();
    final reposicoes = await buscarPorAluna(alunaId);
    return reposicoes
        .where((r) => r.status == 'pendente')
        .where((r) => r.expiraEm == null || r.expiraEm!.isAfter(agora))
        .toList();
  }

  Future<String> criar(Reposicao reposicao) async {
    return _firestore.adicionar(
      colecao: _colecao,
      dados: reposicao.toMap(),
    );
  }

  Future<void> atualizar(Reposicao reposicao) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: reposicao.id,
      dados: reposicao.toMap(),
    );
  }

  Future<void> agendar(
    String id,
    DateTime novaDataHora,
    String novoHorarioId,
  ) async {
    final db = FirebaseFirestore.instance;
    final reposicaoRef = db.collection(_colecao).doc(id);
    final reposicaoSnapshot = await reposicaoRef.get();

    if (!reposicaoSnapshot.exists || reposicaoSnapshot.data() == null) {
      throw StateError('Reposicao nao encontrada.');
    }

    final reposicaoAtual =
        Reposicao.fromMap(reposicaoSnapshot.data()!, reposicaoSnapshot.id);

    await _validarConflitosAgendamento(
      alunaId: reposicaoAtual.alunaId,
      reposicaoIdAtual: reposicaoAtual.id,
      novaDataHora: novaDataHora,
    );

    await db.runTransaction((transaction) async {
      final reposicaoSnap = await transaction.get(reposicaoRef);
      if (!reposicaoSnap.exists || reposicaoSnap.data() == null) {
        throw StateError('Reposicao nao encontrada.');
      }

      final reposicaoAtual =
          Reposicao.fromMap(reposicaoSnap.data()!, reposicaoSnap.id);
      if (reposicaoAtual.status != 'pendente') {
        throw StateError(
            'Essa reposicao nao esta disponivel para agendamento.');
      }

      final gradeRef = db.collection('grade_horarios').doc(novoHorarioId);
      final gradeSnap = await transaction.get(gradeRef);
      final gradeData = gradeSnap.data();
      if (!gradeSnap.exists ||
          gradeData == null ||
          gradeData['ativo'] != true) {
        throw StateError('Esse horario nao esta mais disponivel.');
      }

      transaction.update(reposicaoRef, {
        'status': 'agendada',
        'novaDataHora': Timestamp.fromDate(novaDataHora),
        'novoHorarioId': novoHorarioId,
        'agendadaEm': Timestamp.fromDate(DateTime.now()),
      });
    });
  }

  Future<void> desagendar(String id) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'pendente',
        'novaDataHora': null,
        'novoHorarioId': null,
        'agendadaEm': null,
      },
    );
  }

  Future<void> marcarExpirada(String id) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'expirada',
      },
    );
  }

  Future<void> marcarRealizada(String id) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: id,
      dados: {
        'status': 'realizada',
        'realizadaEm': Timestamp.fromDate(DateTime.now()),
      },
    );
  }

  Future<List<Reposicao>> _normalizarValidadePeloCicloAtual(
    String alunaId,
    List<Reposicao> reposicoes,
  ) async {
    if (reposicoes.isEmpty) return reposicoes;

    final assinatura = await _assinaturaRepository.buscarAtivaDeAluna(alunaId);
    if (assinatura == null) return reposicoes;

    final fimDoCiclo = assinatura.fimDoCiclo;
    final batch = FirebaseFirestore.instance.batch();
    var temAtualizacao = false;

    final ajustadas = reposicoes.map((reposicao) {
      if (!_statusUsaValidade(reposicao.status)) return reposicao;

      final expiraEm = reposicao.expiraEm;
      final expiraCorrigida = expiraEm == null || expiraEm.isAfter(fimDoCiclo)
          ? fimDoCiclo
          : expiraEm;

      if (expiraEm != null && expiraEm.isAtSameMomentAs(expiraCorrigida)) {
        return reposicao;
      }

      temAtualizacao = true;
      batch.update(
        FirebaseFirestore.instance.collection(_colecao).doc(reposicao.id),
        {'expiraEm': Timestamp.fromDate(expiraCorrigida)},
      );
      return reposicao.copyWith(expiraEm: expiraCorrigida);
    }).toList();

    if (temAtualizacao) {
      try {
        await batch.commit();
      } catch (_) {
        // Mantém a correção em memória mesmo se a sincronização falhar.
      }
    }

    return ajustadas;
  }

  bool _statusUsaValidade(String status) {
    return status == 'pendente' || status == 'agendada';
  }

  Future<void> _validarConflitosAgendamento({
    required String alunaId,
    required String reposicaoIdAtual,
    required DateTime novaDataHora,
  }) async {
    final reposicoesDaAlunaSnap = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();

    final conflitoReposicao = reposicoesDaAlunaSnap.docs.any((doc) {
      if (doc.id == reposicaoIdAtual) return false;

      final reposicao = Reposicao.fromMap(doc.data(), doc.id);
      return reposicao.status == 'agendada' &&
          _mesmaDataHora(reposicao.novaDataHora, novaDataHora);
    });

    if (conflitoReposicao) {
      throw StateError(
        'Voce ja possui uma reposicao agendada nesse mesmo horario.',
      );
    }

    final aulasDaAlunaSnap = await FirebaseFirestore.instance
        .collection('aulas')
        .where('alunaId', isEqualTo: alunaId)
        .get();

    final conflitoAula = aulasDaAlunaSnap.docs.any((doc) {
      final aula = Aula.fromMap(doc.data(), doc.id);
      return aula.status == 'agendada' &&
          _mesmaDataHora(aula.dataHora, novaDataHora);
    });

    if (conflitoAula) {
      throw StateError(
        'Voce ja esta inscrita em uma aula nesse mesmo horario. Escolha outro.',
      );
    }
  }

  bool _mesmaDataHora(DateTime? a, DateTime b) {
    if (a == null) return false;

    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }
}
