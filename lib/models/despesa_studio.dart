import 'package:cloud_firestore/cloud_firestore.dart';

class DespesaStudio {
  final String id;
  final String categoria;
  final String descricao;
  final double valor;
  final DateTime dataReferencia;
  final DateTime criadoEm;

  const DespesaStudio({
    required this.id,
    required this.categoria,
    required this.descricao,
    required this.valor,
    required this.dataReferencia,
    required this.criadoEm,
  });

  factory DespesaStudio.fromMap(Map<String, dynamic> mapa, String id) {
    DateTime parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    return DespesaStudio(
      id: id,
      categoria: mapa['categoria'] as String? ?? 'outros',
      descricao: mapa['descricao'] as String? ?? '',
      valor: (mapa['valor'] as num? ?? 0).toDouble(),
      dataReferencia: parseDate(mapa['dataReferencia']),
      criadoEm: parseDate(mapa['criadoEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoria': categoria,
      'descricao': descricao,
      'valor': valor,
      'dataReferencia': Timestamp.fromDate(dataReferencia),
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }
}
