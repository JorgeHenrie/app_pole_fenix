import 'dart:io';

import 'package:uuid/uuid.dart';

import '../models/evento.dart';
import '../services/firebase/storage_service.dart';
import '../services/firebase/firestore_service.dart';

/// Repositório responsável pelas operações da timeline de avisos.
class EventoRepository {
  static const String _colecao = 'eventos';
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
}

class _ImagemAvisoUpload {
  final String url;
  final String caminhoStorage;

  const _ImagemAvisoUpload({
    required this.url,
    required this.caminhoStorage,
  });
}
