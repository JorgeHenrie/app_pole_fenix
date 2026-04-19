import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa um item da timeline de avisos do estúdio.
class Evento {
  final String id;
  final String titulo;
  final String descricao;
  final DateTime dataHora;
  final String categoria;
  final String? local;
  final String? imagemUrl;
  final String? imagemStoragePath;
  final bool publicado;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;

  const Evento({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataHora,
    required this.categoria,
    this.local,
    this.imagemUrl,
    this.imagemStoragePath,
    required this.publicado,
    required this.criadoEm,
    this.atualizadoEm,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is DateTime) return valor;
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  factory Evento.fromMap(Map<String, dynamic> mapa, String id) {
    return Evento(
      id: id,
      titulo: mapa['titulo'] as String? ?? '',
      descricao: mapa['descricao'] as String? ?? '',
      dataHora: _parseDate(mapa['dataHora'] ?? mapa['criadoEm']),
      categoria: mapa['categoria'] as String? ?? 'aviso',
      local: mapa['local'] as String?,
      imagemUrl: mapa['imagemUrl'] as String?,
      imagemStoragePath: mapa['imagemStoragePath'] as String?,
      publicado: mapa['publicado'] as bool? ?? true,
      criadoEm: _parseDate(mapa['criadoEm']),
      atualizadoEm: _parseDateNullable(mapa['atualizadoEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'dataHora': Timestamp.fromDate(dataHora),
      'categoria': categoria,
      'local': local,
      'imagemUrl': imagemUrl,
      'imagemStoragePath': imagemStoragePath,
      'publicado': publicado,
      'criadoEm': Timestamp.fromDate(criadoEm),
      'atualizadoEm':
          atualizadoEm != null ? Timestamp.fromDate(atualizadoEm!) : null,
    };
  }

  Evento copyWith({
    String? id,
    String? titulo,
    String? descricao,
    DateTime? dataHora,
    String? categoria,
    String? local,
    String? imagemUrl,
    String? imagemStoragePath,
    bool? publicado,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return Evento(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      dataHora: dataHora ?? this.dataHora,
      categoria: categoria ?? this.categoria,
      local: local ?? this.local,
      imagemUrl: imagemUrl ?? this.imagemUrl,
      imagemStoragePath: imagemStoragePath ?? this.imagemStoragePath,
      publicado: publicado ?? this.publicado,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
