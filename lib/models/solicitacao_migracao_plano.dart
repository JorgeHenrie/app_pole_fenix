import 'package:cloud_firestore/cloud_firestore.dart';

class SolicitacaoMigracaoPlano {
  final String id;
  final String alunaId;
  final String alunaNome;
  final String assinaturaId;
  final String planoAtualId;
  final String planoAtualNome;
  final String planoDestinoId;
  final String planoDestinoNome;
  final double valorPlanoDestino;
  final String chavePix;
  final String status;
  final DateTime solicitadoEm;
  final String? respostaAdmin;
  final DateTime? respondidoEm;
  final String? respondidoPor;

  const SolicitacaoMigracaoPlano({
    required this.id,
    required this.alunaId,
    required this.alunaNome,
    required this.assinaturaId,
    required this.planoAtualId,
    required this.planoAtualNome,
    required this.planoDestinoId,
    required this.planoDestinoNome,
    required this.valorPlanoDestino,
    required this.chavePix,
    required this.status,
    required this.solicitadoEm,
    this.respostaAdmin,
    this.respondidoEm,
    this.respondidoPor,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  static double _parseDouble(dynamic valor) {
    if (valor is num) return valor.toDouble();
    if (valor is String) return double.tryParse(valor) ?? 0;
    return 0;
  }

  factory SolicitacaoMigracaoPlano.fromMap(
    Map<String, dynamic> mapa,
    String id,
  ) {
    return SolicitacaoMigracaoPlano(
      id: id,
      alunaId: mapa['alunaId'] as String? ?? '',
      alunaNome: mapa['alunaNome'] as String? ?? 'Aluna',
      assinaturaId: mapa['assinaturaId'] as String? ?? '',
      planoAtualId: mapa['planoAtualId'] as String? ?? '',
      planoAtualNome: mapa['planoAtualNome'] as String? ?? 'Plano atual',
      planoDestinoId: mapa['planoDestinoId'] as String? ?? '',
      planoDestinoNome: mapa['planoDestinoNome'] as String? ?? 'Novo plano',
      valorPlanoDestino: _parseDouble(mapa['valorPlanoDestino']),
      chavePix: mapa['chavePix'] as String? ?? '',
      status: mapa['status'] as String? ?? 'pendente',
      solicitadoEm: _parseDate(mapa['solicitadoEm']),
      respostaAdmin: mapa['respostaAdmin'] as String?,
      respondidoEm: _parseDateNullable(mapa['respondidoEm']),
      respondidoPor: mapa['respondidoPor'] as String?,
    );
  }

  factory SolicitacaoMigracaoPlano.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return SolicitacaoMigracaoPlano.fromMap(doc.data()!, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'alunaNome': alunaNome,
      'assinaturaId': assinaturaId,
      'planoAtualId': planoAtualId,
      'planoAtualNome': planoAtualNome,
      'planoDestinoId': planoDestinoId,
      'planoDestinoNome': planoDestinoNome,
      'valorPlanoDestino': valorPlanoDestino,
      'chavePix': chavePix,
      'status': status,
      'solicitadoEm': Timestamp.fromDate(solicitadoEm),
      'respostaAdmin': respostaAdmin,
      'respondidoEm':
          respondidoEm != null ? Timestamp.fromDate(respondidoEm!) : null,
      'respondidoPor': respondidoPor,
    };
  }

  SolicitacaoMigracaoPlano copyWith({
    String? id,
    String? alunaId,
    String? alunaNome,
    String? assinaturaId,
    String? planoAtualId,
    String? planoAtualNome,
    String? planoDestinoId,
    String? planoDestinoNome,
    double? valorPlanoDestino,
    String? chavePix,
    String? status,
    DateTime? solicitadoEm,
    String? respostaAdmin,
    DateTime? respondidoEm,
    String? respondidoPor,
  }) {
    return SolicitacaoMigracaoPlano(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      alunaNome: alunaNome ?? this.alunaNome,
      assinaturaId: assinaturaId ?? this.assinaturaId,
      planoAtualId: planoAtualId ?? this.planoAtualId,
      planoAtualNome: planoAtualNome ?? this.planoAtualNome,
      planoDestinoId: planoDestinoId ?? this.planoDestinoId,
      planoDestinoNome: planoDestinoNome ?? this.planoDestinoNome,
      valorPlanoDestino: valorPlanoDestino ?? this.valorPlanoDestino,
      chavePix: chavePix ?? this.chavePix,
      status: status ?? this.status,
      solicitadoEm: solicitadoEm ?? this.solicitadoEm,
      respostaAdmin: respostaAdmin ?? this.respostaAdmin,
      respondidoEm: respondidoEm ?? this.respondidoEm,
      respondidoPor: respondidoPor ?? this.respondidoPor,
    );
  }
}
