/// Modelo que representa um evento do estúdio.
class Evento {
  final String id;
  final String titulo;
  final String descricao;
  final DateTime dataHora;
  final String? local;
  final String? imagemUrl;
  final bool publicado;
  final DateTime criadoEm;

  const Evento({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.dataHora,
    this.local,
    this.imagemUrl,
    required this.publicado,
    required this.criadoEm,
  });

  factory Evento.fromMap(Map<String, dynamic> mapa, String id) {
    return Evento(
      id: id,
      titulo: mapa['titulo'] as String,
      descricao: mapa['descricao'] as String,
      dataHora: DateTime.parse(mapa['dataHora'] as String),
      local: mapa['local'] as String?,
      imagemUrl: mapa['imagemUrl'] as String?,
      publicado: mapa['publicado'] as bool,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descricao': descricao,
      'dataHora': dataHora.toIso8601String(),
      'local': local,
      'imagemUrl': imagemUrl,
      'publicado': publicado,
      'criadoEm': criadoEm.toIso8601String(),
    };
  }
}
