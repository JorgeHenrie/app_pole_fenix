import 'package:cloud_firestore/cloud_firestore.dart';

class EventoComentario {
  final String id;
  final String autorId;
  final String autorNome;
  final String texto;
  final DateTime criadoEm;

  const EventoComentario({
    required this.id,
    required this.autorId,
    required this.autorNome,
    required this.texto,
    required this.criadoEm,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is DateTime) return valor;
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  factory EventoComentario.fromMap(Map<String, dynamic> mapa, String id) {
    return EventoComentario(
      id: id,
      autorId: mapa['autorId'] as String? ?? '',
      autorNome: mapa['autorNome'] as String? ?? '',
      texto: mapa['texto'] as String? ?? '',
      criadoEm: _parseDate(mapa['criadoEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autorId': autorId,
      'autorNome': autorNome,
      'texto': texto,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
