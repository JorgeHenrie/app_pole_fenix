import 'package:cloud_firestore/cloud_firestore.dart';

class SolicitacaoMudancaHorario {
  final String id;
  final String alunaId;
  final String horarioFixoAntigoId;
  final int novoDiaSemana;
  final String novoHorario;
  final String motivo;
  final String status;
  final String? respostaAdmin;
  final DateTime solicitadoEm;
  final DateTime? respondidoEm;
  final String? respondidoPor;

  const SolicitacaoMudancaHorario({
    required this.id,
    required this.alunaId,
    required this.horarioFixoAntigoId,
    required this.novoDiaSemana,
    required this.novoHorario,
    required this.motivo,
    required this.status,
    this.respostaAdmin,
    required this.solicitadoEm,
    this.respondidoEm,
    this.respondidoPor,
  });

  factory SolicitacaoMudancaHorario.fromMap(Map<String, dynamic> mapa, String id) {
    return SolicitacaoMudancaHorario(
      id: id,
      alunaId: mapa['alunaId'] as String,
      horarioFixoAntigoId: mapa['horarioFixoAntigoId'] as String,
      novoDiaSemana: mapa['novoDiaSemana'] as int,
      novoHorario: mapa['novoHorario'] as String,
      motivo: mapa['motivo'] as String,
      status: mapa['status'] as String,
      respostaAdmin: mapa['respostaAdmin'] as String?,
      solicitadoEm: DateTime.parse(mapa['solicitadoEm'] as String),
      respondidoEm: mapa['respondidoEm'] != null
          ? DateTime.parse(mapa['respondidoEm'] as String)
          : null,
      respondidoPor: mapa['respondidoPor'] as String?,
    );
  }

  factory SolicitacaoMudancaHorario.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final mapa = doc.data()!;
    return SolicitacaoMudancaHorario(
      id: doc.id,
      alunaId: mapa['alunaId'] as String,
      horarioFixoAntigoId: mapa['horarioFixoAntigoId'] as String,
      novoDiaSemana: mapa['novoDiaSemana'] as int,
      novoHorario: mapa['novoHorario'] as String,
      motivo: mapa['motivo'] as String,
      status: mapa['status'] as String,
      respostaAdmin: mapa['respostaAdmin'] as String?,
      solicitadoEm: (mapa['solicitadoEm'] as Timestamp).toDate(),
      respondidoEm: mapa['respondidoEm'] != null
          ? (mapa['respondidoEm'] as Timestamp).toDate()
          : null,
      respondidoPor: mapa['respondidoPor'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'horarioFixoAntigoId': horarioFixoAntigoId,
      'novoDiaSemana': novoDiaSemana,
      'novoHorario': novoHorario,
      'motivo': motivo,
      'status': status,
      'respostaAdmin': respostaAdmin,
      'solicitadoEm': solicitadoEm.toIso8601String(),
      'respondidoEm': respondidoEm?.toIso8601String(),
      'respondidoPor': respondidoPor,
    };
  }

  SolicitacaoMudancaHorario copyWith({
    String? id,
    String? alunaId,
    String? horarioFixoAntigoId,
    int? novoDiaSemana,
    String? novoHorario,
    String? motivo,
    String? status,
    String? respostaAdmin,
    DateTime? solicitadoEm,
    DateTime? respondidoEm,
    String? respondidoPor,
  }) {
    return SolicitacaoMudancaHorario(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      horarioFixoAntigoId: horarioFixoAntigoId ?? this.horarioFixoAntigoId,
      novoDiaSemana: novoDiaSemana ?? this.novoDiaSemana,
      novoHorario: novoHorario ?? this.novoHorario,
      motivo: motivo ?? this.motivo,
      status: status ?? this.status,
      respostaAdmin: respostaAdmin ?? this.respostaAdmin,
      solicitadoEm: solicitadoEm ?? this.solicitadoEm,
      respondidoEm: respondidoEm ?? this.respondidoEm,
      respondidoPor: respondidoPor ?? this.respondidoPor,
    );
  }
}
