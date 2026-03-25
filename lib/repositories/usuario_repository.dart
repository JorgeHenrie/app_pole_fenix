import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/usuario.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações de dados de usuárias.
class UsuarioRepository {
  static const String _colecao = 'usuarios';
  final FirestoreService _firestore = FirestoreService();

  /// Busca uma usuária pelo id.
  Future<Usuario?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return Usuario.fromMap(doc.data()!, doc.id);
  }

  /// Cria um novo documento de usuária no Firestore usando o UID como id.
  Future<void> criar(Usuario usuario) async {
    await FirebaseFirestore.instance
        .collection(_colecao)
        .doc(usuario.id)
        .set(usuario.toMap());
  }

  /// Salva ou atualiza os dados de uma usuária.
  Future<void> salvar(Usuario usuario) async {
    await _firestore.atualizar(
      colecao: _colecao,
      id: usuario.id,
      dados: usuario.toMap(),
    );
  }

  /// Busca uma usuária pelo e-mail.
  Future<Usuario?> buscarPorEmail(String email) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return null;
    final doc = querySnapshot.docs.first;
    return Usuario.fromMap(doc.data(), doc.id);
  }

  /// Retorna lista de alunas com cadastro pendente de aprovação.
  Future<List<Usuario>> buscarPendentes() async {
    final snap = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('tipoUsuario', isEqualTo: 'aluna')
        .where('statusCadastro', isEqualTo: 'pendente')
        .orderBy('dataCadastro', descending: true)
        .get();
    return snap.docs.map((d) => Usuario.fromMap(d.data(), d.id)).toList();
  }

  /// Aprova o cadastro de uma aluna, criando a assinatura e o horário fixo atomicamente.
  /// Retorna o ID do documento horario_fixo criado.
  Future<String> aprovarComPlano({
    required String alunaId,
    required String adminId,
    required String planoId,
    required int aulasPorMes,
    required int duracaoDias,
    required int diaSemana,
    required String horario,
    required String modalidade,
  }) async {
    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    final agora = DateTime.now();
    final dataRenovacao = agora.add(Duration(days: duracaoDias));

    // 1. Aprovar usuário
    batch.update(db.collection(_colecao).doc(alunaId), {
      'statusCadastro': 'aprovado',
      'dataAprovacao': Timestamp.fromDate(agora),
      'aprovadoPor': adminId,
      'motivoRejeicao': null,
    });

    // 2. Criar assinatura
    final assinaturaRef = db.collection('assinaturas').doc();
    batch.set(assinaturaRef, {
      'alunaId': alunaId,
      'planoId': planoId,
      'status': 'ativa',
      'creditosDisponiveis': aulasPorMes,
      'aulasRealizadas': 0,
      'reposicoesDisponiveis': 0,
      'horarioFixoIds': [],
      'dataInicio': Timestamp.fromDate(agora),
      'dataRenovacao': Timestamp.fromDate(dataRenovacao),
      'dataCancelamento': null,
    });

    // 3. Criar horário fixo
    final horarioRef = db.collection('horarios_fixos').doc();
    batch.set(horarioRef, {
      'alunaId': alunaId,
      'assinaturaId': assinaturaRef.id,
      'diaSemana': diaSemana,
      'horario': horario,
      'modalidade': modalidade,
      'ativo': true,
      'criadoEm': Timestamp.fromDate(agora),
      'desativadoEm': null,
      'motivoDesativacao': null,
    });

    // 4. Atualizar assinatura com o id do horário fixo
    batch.update(assinaturaRef, {
      'horarioFixoIds': [horarioRef.id],
    });

    await batch.commit();
    return horarioRef.id;
  }

  /// Rejeita o cadastro de uma aluna com motivo opcional.
  Future<void> rejeitar(String alunaId, String adminId, String? motivo) async {
    await FirebaseFirestore.instance.collection(_colecao).doc(alunaId).update({
      'statusCadastro': 'rejeitado',
      'dataAprovacao': DateTime.now().toIso8601String(),
      'aprovadoPor': adminId,
      'motivoRejeicao': motivo,
    });
  }
}
