/// Modelo que representa uma notificação enviada a uma usuária.
class Notificacao {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensagem;
  final String tipo; // 'aula', 'pagamento', 'evento', 'sistema'
  final String? referenciaId;
  final bool lida;
  final DateTime criadaEm;

  const Notificacao({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensagem,
    required this.tipo,
    this.referenciaId,
    required this.lida,
    required this.criadaEm,
  });

  factory Notificacao.fromMap(Map<String, dynamic> mapa, String id) {
    DateTime parseDate(dynamic valor) {
      if (valor is DateTime) return valor;
      if (valor != null && valor.runtimeType.toString() == 'Timestamp') {
        return valor.toDate() as DateTime;
      }
      if (valor is String) return DateTime.parse(valor);
      return DateTime.now();
    }

    return Notificacao(
      id: id,
      usuarioId: mapa['usuarioId'] as String,
      titulo: mapa['titulo'] as String,
      mensagem: mapa['mensagem'] as String,
      tipo: mapa['tipo'] as String,
      referenciaId: mapa['referenciaId'] as String?,
      lida: mapa['lida'] as bool? ?? false,
      criadaEm: parseDate(mapa['criadaEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'titulo': titulo,
      'mensagem': mensagem,
      'tipo': tipo,
      'referenciaId': referenciaId,
      'lida': lida,
      'criadaEm': criadaEm.toIso8601String(),
    };
  }

  Notificacao copyWith({
    String? usuarioId,
    String? titulo,
    String? mensagem,
    String? tipo,
    String? referenciaId,
    bool? lida,
    DateTime? criadaEm,
  }) {
    return Notificacao(
      id: id,
      usuarioId: usuarioId ?? this.usuarioId,
      titulo: titulo ?? this.titulo,
      mensagem: mensagem ?? this.mensagem,
      tipo: tipo ?? this.tipo,
      referenciaId: referenciaId ?? this.referenciaId,
      lida: lida ?? this.lida,
      criadaEm: criadaEm ?? this.criadaEm,
    );
  }
}
