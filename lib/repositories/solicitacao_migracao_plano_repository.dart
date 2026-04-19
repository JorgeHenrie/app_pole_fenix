import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/assinatura.dart';
import '../models/solicitacao_migracao_plano.dart';
import '../services/firebase/firestore_service.dart';

class SolicitacaoMigracaoPlanoRepository {
  static const String _colecao = 'solicitacoes_migracao_plano';

  final FirestoreService _firestore = FirestoreService();

  Future<String> criar(SolicitacaoMigracaoPlano solicitacao) async {
    final existente = await buscarPendentePorAluna(solicitacao.alunaId);
    if (existente != null) {
      throw StateError(
        'Você já possui uma solicitação de migração aguardando análise.',
      );
    }

    return _firestore.adicionar(
      colecao: _colecao,
      dados: solicitacao.toMap(),
    );
  }

  Future<List<SolicitacaoMigracaoPlano>> listarPendentes() async {
    final snap = await _firestore
        .colecao(_colecao)
        .where('status', isEqualTo: 'pendente')
        .get();

    final solicitacoes = snap.docs
        .map((doc) => SolicitacaoMigracaoPlano.fromMap(doc.data(), doc.id))
        .toList();

    solicitacoes.sort((a, b) => b.solicitadoEm.compareTo(a.solicitadoEm));
    return solicitacoes;
  }

  Future<List<SolicitacaoMigracaoPlano>> listarPorAluna(String alunaId) async {
    final snap = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();

    final solicitacoes = snap.docs
        .map((doc) => SolicitacaoMigracaoPlano.fromMap(doc.data(), doc.id))
        .toList();

    solicitacoes.sort((a, b) => b.solicitadoEm.compareTo(a.solicitadoEm));
    return solicitacoes;
  }

  Future<SolicitacaoMigracaoPlano?> buscarPendentePorAluna(
    String alunaId,
  ) async {
    final solicitacoes = await listarPorAluna(alunaId);
    for (final solicitacao in solicitacoes) {
      if (solicitacao.status == 'pendente') {
        return solicitacao;
      }
    }
    return null;
  }

  Future<int> contarPendentes() async {
    final solicitacoes = await listarPendentes();
    return solicitacoes.length;
  }

  Future<void> responder({
    required String solicitacaoId,
    required String status,
    String? respostaAdmin,
    required String adminId,
  }) async {
    final db = FirebaseFirestore.instance;
    final agora = DateTime.now();

    await db.runTransaction((transaction) async {
      final solicitacaoRef = db.collection(_colecao).doc(solicitacaoId);
      final solicitacaoSnap = await transaction.get(solicitacaoRef);

      if (!solicitacaoSnap.exists || solicitacaoSnap.data() == null) {
        throw StateError('Solicitação não encontrada.');
      }

      final solicitacao = SolicitacaoMigracaoPlano.fromMap(
        solicitacaoSnap.data()!,
        solicitacaoSnap.id,
      );

      if (solicitacao.status != 'pendente') {
        throw StateError('Esta solicitação já foi respondida.');
      }

      if (status == 'aprovada') {
        final assinaturaRef =
            db.collection('assinaturas').doc(solicitacao.assinaturaId);
        final assinaturaSnap = await transaction.get(assinaturaRef);

        if (!assinaturaSnap.exists || assinaturaSnap.data() == null) {
          throw StateError('Assinatura ativa não encontrada.');
        }

        final assinatura = Assinatura.fromMap(
          assinaturaSnap.data()!,
          assinaturaSnap.id,
        );

        final planoRef =
            db.collection('planos').doc(solicitacao.planoDestinoId);
        final planoSnap = await transaction.get(planoRef);
        if (!planoSnap.exists || planoSnap.data() == null) {
          throw StateError('Plano de destino não encontrado.');
        }

        final planoData = planoSnap.data()!;
        final aulasPorMes = planoData['aulasPorMes'] as int? ??
            planoData['quantidadeAulas'] as int? ??
            0;
        final creditosDisponiveis = _calcularCreditosDisponiveis(
          aulasPorMes,
          assinatura.aulasRealizadas,
        );

        transaction.update(assinaturaRef, {
          'planoId': solicitacao.planoDestinoId,
          'creditosDisponiveis': creditosDisponiveis,
          'status': 'ativa',
          'dataCancelamento': null,
        });

        transaction.set(
          db.collection('usuarios').doc(solicitacao.alunaId),
          {
            'planoId': solicitacao.planoDestinoId,
            'atualizadoEm': Timestamp.fromDate(agora),
          },
          SetOptions(merge: true),
        );
      }

      transaction.update(solicitacaoRef, {
        'status': status,
        'respostaAdmin': respostaAdmin,
        'respondidoEm': Timestamp.fromDate(agora),
        'respondidoPor': adminId,
      });
    });
  }

  int _calcularCreditosDisponiveis(int aulasPorMes, int aulasRealizadas) {
    final restantes = aulasPorMes - aulasRealizadas;
    return restantes > 0 ? restantes : 0;
  }
}
