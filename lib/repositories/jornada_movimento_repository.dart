import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/jornada_movimento.dart';
import '../models/movimento_pole.dart';
import '../models/usuario.dart';
import '../services/firebase/firestore_service.dart';
import '../services/firebase/storage_service.dart';

class JornadaMovimentoRepository {
  static const String _colecao = 'jornada_movimentos';

  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();

  Future<List<JornadaMovimento>> listarTodas() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    final jornadas = snapshot.docs
        .map((doc) => JornadaMovimento.fromMap(doc.data(), doc.id))
        .toList();

    jornadas.sort((a, b) => a.alunaNome.compareTo(b.alunaNome));
    return jornadas;
  }

  Future<List<JornadaMovimento>> listarPorAluna(String alunaId) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('alunaId', isEqualTo: alunaId)
        .get();

    final jornadas = snapshot.docs
        .map((doc) => JornadaMovimento.fromMap(doc.data(), doc.id))
        .toList();

    jornadas.sort((a, b) {
      final porNivel = a.nivel.ordem.compareTo(b.nivel.ordem);
      if (porNivel != 0) return porNivel;
      final porData = b.liberadoEm.compareTo(a.liberadoEm);
      if (porData != 0) return porData;
      return a.movimentoNome.compareTo(b.movimentoNome);
    });

    return jornadas;
  }

  Future<JornadaMovimento?> buscarPorId(String id) async {
    final doc = await _firestore.buscarDocumento(colecao: _colecao, id: id);
    if (!doc.exists || doc.data() == null) return null;
    return JornadaMovimento.fromMap(doc.data()!, doc.id);
  }

  Future<void> liberarParaAluna({
    required Usuario aluna,
    required MovimentoPole movimento,
    required String adminId,
  }) async {
    final docId = '${aluna.id}_${movimento.id}';
    final ref = FirebaseFirestore.instance.collection(_colecao).doc(docId);
    final existente = await ref.get();

    if (existente.exists) {
      throw StateError('Esse movimento já está liberado para a aluna.');
    }

    final jornada = JornadaMovimento(
      id: docId,
      alunaId: aluna.id,
      alunaNome: aluna.nome,
      movimentoId: movimento.id,
      movimentoNome: movimento.nome,
      movimentoCategoria: movimento.categoria,
      nivel: movimento.nivel,
      liberadoPor: adminId,
      liberadoEm: DateTime.now(),
    );

    await ref.set(jornada.toMap());
  }

  Future<void> removerDaAluna(JornadaMovimento jornada) async {
    for (final foto in jornada.fotos) {
      if (foto.caminhoStorage.trim().isEmpty) continue;
      try {
        await _storage.removerArquivo(foto.caminhoStorage);
      } catch (_) {
        // Ignora falhas de remoção do arquivo antigo para não bloquear a limpeza.
      }
    }

    await _firestore.remover(colecao: _colecao, id: jornada.id);
  }

  Future<void> sincronizarMovimento(MovimentoPole movimento) async {
    final snapshot = await FirebaseFirestore.instance
        .collection(_colecao)
        .where('movimentoId', isEqualTo: movimento.id)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'movimentoNome': movimento.nome,
        'movimentoCategoria': movimento.categoria.valor,
        ...movimento.nivel.toEmbeddedMap(),
      });
    }

    await batch.commit();
  }

  Future<void> sincronizarNivel(NivelDificuldadeMovimento nivel) async {
    final snapshot =
        await FirebaseFirestore.instance.collection(_colecao).get();
    if (snapshot.docs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    var atualizou = false;

    for (final doc in snapshot.docs) {
      final jornada = JornadaMovimento.fromMap(doc.data(), doc.id);
      if (jornada.nivel.id != nivel.id) continue;
      batch.update(doc.reference, nivel.toEmbeddedMap());
      atualizou = true;
    }

    if (atualizou) {
      await batch.commit();
    }
  }

  Future<JornadaMovimento> adicionarFoto({
    required JornadaMovimento jornada,
    required File arquivo,
  }) async {
    if (jornada.fotos.length >= 2) {
      throw StateError('Cada movimento permite no máximo 2 fotos.');
    }

    final extensao = _extrairExtensao(arquivo.path);
    final nomeArquivo = '${_uuid.v4()}.$extensao';
    final caminho =
        'jornada_movimentos/${jornada.alunaId}/${jornada.movimentoId}/$nomeArquivo';
    final url =
        await _storage.uploadArquivo(arquivo: arquivo, caminho: caminho);

    final foto = FotoJornadaMovimento(
      url: url,
      caminhoStorage: caminho,
      enviadaEm: DateTime.now(),
    );

    final atualizada = jornada.copyWith(
      fotos: [...jornada.fotos, foto],
    );

    await _firestore.atualizar(
      colecao: _colecao,
      id: jornada.id,
      dados: {'fotos': atualizada.fotos.map((item) => item.toMap()).toList()},
    );

    return atualizada;
  }

  Future<JornadaMovimento> removerFoto({
    required JornadaMovimento jornada,
    required FotoJornadaMovimento foto,
  }) async {
    if (foto.caminhoStorage.trim().isNotEmpty) {
      try {
        await _storage.removerArquivo(foto.caminhoStorage);
      } catch (_) {
        // A remoção do registro no Firestore continua mesmo se o arquivo não existir mais.
      }
    }

    final fotosAtualizadas = jornada.fotos
        .where((item) => item.caminhoStorage != foto.caminhoStorage)
        .toList();

    await _firestore.atualizar(
      colecao: _colecao,
      id: jornada.id,
      dados: {
        'fotos': fotosAtualizadas.map((item) => item.toMap()).toList(),
      },
    );

    return jornada.copyWith(fotos: fotosAtualizadas);
  }

  Future<JornadaMovimento> substituirFoto({
    required JornadaMovimento jornada,
    required FotoJornadaMovimento fotoAnterior,
    required File novoArquivo,
  }) async {
    final indiceFoto = jornada.fotos.indexWhere(
      (item) => item.caminhoStorage == fotoAnterior.caminhoStorage,
    );

    if (indiceFoto == -1) {
      throw StateError('A foto selecionada não foi encontrada.');
    }

    final extensao = _extrairExtensao(novoArquivo.path);
    final nomeArquivo = '${_uuid.v4()}.$extensao';
    final caminho =
        'jornada_movimentos/${jornada.alunaId}/${jornada.movimentoId}/$nomeArquivo';
    final url =
        await _storage.uploadArquivo(arquivo: novoArquivo, caminho: caminho);

    final novaFoto = FotoJornadaMovimento(
      url: url,
      caminhoStorage: caminho,
      enviadaEm: DateTime.now(),
    );

    final fotosAtualizadas = [...jornada.fotos];
    fotosAtualizadas[indiceFoto] = novaFoto;

    await _firestore.atualizar(
      colecao: _colecao,
      id: jornada.id,
      dados: {
        'fotos': fotosAtualizadas.map((item) => item.toMap()).toList(),
      },
    );

    if (fotoAnterior.caminhoStorage.trim().isNotEmpty) {
      try {
        await _storage.removerArquivo(fotoAnterior.caminhoStorage);
      } catch (_) {
        // A substituição continua válida mesmo se o arquivo antigo já não existir.
      }
    }

    return jornada.copyWith(fotos: fotosAtualizadas);
  }

  String _extrairExtensao(String caminho) {
    final indice = caminho.lastIndexOf('.');
    if (indice == -1 || indice == caminho.length - 1) {
      return 'jpg';
    }

    return caminho.substring(indice + 1).toLowerCase();
  }
}
