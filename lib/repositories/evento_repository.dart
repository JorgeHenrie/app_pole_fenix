import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/evento_comentario.dart';
import '../models/evento.dart';
import '../models/evento_reacao.dart';
import '../services/firebase/storage_service.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações da timeline de avisos.
class EventoRepository {
  static const String _colecao = 'eventos';
  static const String _subcolecaoComentarios = 'comentarios';
  static const String _subcolecaoReacoes = 'reacoes';

  final FirestoreService _firestore = FirestoreService();
  final StorageService _storage = StorageService();
  final Uuid _uuid = const Uuid();

  Future<List<Evento>> listarTodos() async {
    final snapshot = await _firestore.colecao(_colecao).get();
    final eventos = snapshot.docs
        .map((doc) => Evento.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return eventos;
  }

  /// Lista todos os avisos publicados, ordenados por data de exibição.
  Future<List<Evento>> listarPublicados({int? limite}) async {
    final snapshot = await _firestore
        .colecao(_colecao)
        .where('publicado', isEqualTo: true)
        .get();
    final eventos = snapshot.docs
        .map((doc) => Evento.fromMap(doc.data(), doc.id))
        .toList()
      ..sort((a, b) => b.dataHora.compareTo(a.dataHora));

    if (limite == null || limite >= eventos.length) {
      return eventos;
    }

    return eventos.take(limite).toList();
  }

  /// Cria um novo item sem imagem. Mantido por compatibilidade.
  Future<String> criar(Evento evento) async {
    return _firestore.adicionar(colecao: _colecao, dados: evento.toMap());
  }

  Future<String> criarComImagem({
    required Evento evento,
    required File imagem,
  }) async {
    final dadosImagem = await _uploadImagem(imagem);
    return _firestore.adicionar(
      colecao: _colecao,
      dados: evento
          .copyWith(
            imagemUrl: dadosImagem.url,
            imagemStoragePath: dadosImagem.caminhoStorage,
          )
          .toMap(),
    );
  }

  Future<void> atualizar(Evento evento) {
    return _firestore.atualizar(
      colecao: _colecao,
      id: evento.id,
      dados: evento.toMap(),
    );
  }

  Future<void> atualizarComImagem({
    required Evento evento,
    File? novaImagem,
  }) async {
    Evento atualizado = evento;
    String? caminhoAntigo;

    if (novaImagem != null) {
      final dadosImagem = await _uploadImagem(novaImagem);
      caminhoAntigo = evento.imagemStoragePath;
      atualizado = evento.copyWith(
        imagemUrl: dadosImagem.url,
        imagemStoragePath: dadosImagem.caminhoStorage,
      );
    }

    await _firestore.atualizar(
      colecao: _colecao,
      id: evento.id,
      dados: atualizado.toMap(),
    );

    if (caminhoAntigo != null && caminhoAntigo.trim().isNotEmpty) {
      try {
        await _storage.removerArquivo(caminhoAntigo);
      } catch (_) {
        // Mantém a atualização do aviso mesmo se a imagem antiga já não existir.
      }
    }
  }

  /// Remove um item pelo id. Mantido por compatibilidade.
  Future<void> remover(String id) async {
    await _firestore.remover(colecao: _colecao, id: id);
  }

  Future<void> removerComImagem(Evento evento) async {
    if (evento.imagemStoragePath != null &&
        evento.imagemStoragePath!.trim().isNotEmpty) {
      try {
        await _storage.removerArquivo(evento.imagemStoragePath!);
      } catch (_) {
        // A remoção do registro continua mesmo se o arquivo não existir mais.
      }
    }

    await _firestore.remover(colecao: _colecao, id: evento.id);
  }

  Stream<List<EventoReacao>> observarReacoes(String eventoId) {
    return _reacoesRef(eventoId).snapshots().map((snapshot) {
      final reacoes = snapshot.docs
          .map((doc) => EventoReacao.fromMap(doc.data(), doc.id))
          .toList()
        ..sort(
          (a, b) => (b.atualizadoEm ?? b.criadoEm)
              .compareTo(a.atualizadoEm ?? a.criadoEm),
        );
      return reacoes;
    });
  }

  Stream<List<EventoComentario>> observarComentarios(String eventoId) {
    return _comentariosRef(eventoId).orderBy('criadoEm').snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => EventoComentario.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> alternarReacao({
    required String eventoId,
    required String usuarioId,
    required String usuarioNome,
    required TipoReacaoEvento tipo,
  }) async {
    final nomeLimpo = usuarioNome.trim();
    if (nomeLimpo.isEmpty) {
      throw StateError('Nao foi possivel identificar o nome da usuaria.');
    }

    final ref = _reacoesRef(eventoId).doc(usuarioId);
    final snapshot = await ref.get();
    final atual = snapshot.exists
        ? EventoReacao.fromMap(snapshot.data()!, snapshot.id)
        : null;

    if (atual?.tipo == tipo) {
      await ref.delete();
      return;
    }

    final agora = DateTime.now();
    await ref.set(
      EventoReacao(
        usuarioId: usuarioId,
        usuarioNome: nomeLimpo,
        tipo: tipo,
        criadoEm: atual?.criadoEm ?? agora,
        atualizadoEm: atual == null ? null : agora,
      ).toMap(),
    );
  }

  Future<void> adicionarComentario({
    required String eventoId,
    required String autorId,
    required String autorNome,
    required String texto,
  }) async {
    final textoLimpo = texto.trim();
    final nomeLimpo = autorNome.trim();

    if (nomeLimpo.isEmpty) {
      throw StateError('Nao foi possivel identificar o nome da usuaria.');
    }

    if (textoLimpo.isEmpty) {
      throw StateError('Escreva um comentario antes de enviar.');
    }

    if (textoLimpo.length > 500) {
      throw StateError('O comentario pode ter no maximo 500 caracteres.');
    }

    await _comentariosRef(eventoId).add(
      EventoComentario(
        id: '',
        autorId: autorId,
        autorNome: nomeLimpo,
        texto: textoLimpo,
        criadoEm: DateTime.now(),
      ).toMap(),
    );
  }

  Future<void> removerComentario({
    required String eventoId,
    required String comentarioId,
  }) {
    return _comentariosRef(eventoId).doc(comentarioId).delete();
  }

  Future<_ImagemAvisoUpload> _uploadImagem(File imagem) async {
    final extensao = _extrairExtensao(imagem.path);
    final nomeArquivo = '${_uuid.v4()}.$extensao';
    final caminho = 'avisos_timeline/$nomeArquivo';
    final url = await _storage.uploadArquivo(arquivo: imagem, caminho: caminho);
    return _ImagemAvisoUpload(url: url, caminhoStorage: caminho);
  }

  String _extrairExtensao(String caminho) {
    final indice = caminho.lastIndexOf('.');
    if (indice == -1 || indice == caminho.length - 1) {
      return 'jpg';
    }

    return caminho.substring(indice + 1).toLowerCase();
  }

  CollectionReference<Map<String, dynamic>> _comentariosRef(String eventoId) {
    return _firestore.colecao('$_colecao/$eventoId/$_subcolecaoComentarios');
  }

  CollectionReference<Map<String, dynamic>> _reacoesRef(String eventoId) {
    return _firestore.colecao('$_colecao/$eventoId/$_subcolecaoReacoes');
  }
}

class _ImagemAvisoUpload {
  final String url;
  final String caminhoStorage;

  const _ImagemAvisoUpload({
    required this.url,
    required this.caminhoStorage,
  });
}
