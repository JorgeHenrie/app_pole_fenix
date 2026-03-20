/// Modelo que representa uma notificação enviada a uma usuária.
class Notificacao {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensagem;
  final String tipo; // 'aula', 'pagamento', 'evento', 'sistema'
  final bool lida;
  final DateTime criadaEm;

  const Notificacao({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    required this.lida,
    required this.criadaEm,
  });

  factory Notificacao.fromMap(Map<String, dynamic> mapa, String id) {
    return Notificacao(
      id: id,
      usuarioId: mapa['usuarioId'] as String,
      titulo: mapa['titulo'] as String,
      mensagem: mapa['mensagem'] as String,
      tipo: mapa['tipo'] as String,
      lida: mapa['lida'] as bool,
      criadaEm: DateTime.parse(mapa['criadaEm'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'titulo': titulo,
      'mensagem': mensagem,
      'tipo': tipo,
      'lida': lida,
      'criadaEm': criadaEm.toIso8601String(),
    };
  }

  Notificacao copyWith({
    String? usuarioId,
    String? titulo,
    String? mensagem,
    String? tipo,
    bool? lida,
    DateTime? criadaEm,
  }) {
    return Notificacao(
      id: id,
      usuarioId: usuarioId ?? this.usuarioId,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo ?? this.tipo,
      lida: lida ?? this.lida,
      criadaEm: criadaEm ?? this.criadaEm,
    );
  }
}
