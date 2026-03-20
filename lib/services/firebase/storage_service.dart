import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

/// Serviço responsável pelo upload e download de arquivos no Cloud Storage.
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Faz upload de um arquivo e retorna a URL de download.
  Future<String> uploadArquivo({
    required File arquivo,
    required String caminho,
  }) async {
    final ref = _storage.ref().child(caminho);
    final tarefa = await ref.putFile(arquivo);
    return tarefa.ref.getDownloadURL();
  }

  /// Remove um arquivo pelo caminho completo no Storage.
  Future<void> removerArquivo(String caminho) async {
    await _storage.ref().child(caminho).delete();
  }
}
