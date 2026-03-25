import 'package:cloud_firestore/cloud_firestore.dart';

class Assinatura {
  final String id;
  final String alunaId;
  final String planoId;
  final String status; // 'ativa', 'suspensa', 'cancelada'
  final int creditosDisponiveis;
  final DateTime dataInicio;
  final DateTime dataRenovacao;
  final DateTime? dataCancelamento;
  final List<String> horarioFixoIds;
  final int aulasRealizadas;
  final int reposicoesDisponiveis;

  const Assinatura({
    required this.id,
    required this.alunaId,
    required this.planoId,
    required this.status,
    required this.creditosDisponiveis,
    required this.dataInicio,
    required this.dataRenovacao,
    this.dataCancelamento,
    this.horarioFixoIds = const [],
    this.aulasRealizadas = 0,
    this.reposicoesDisponiveis = 0,
  });

  int? get aulasRestantes =>
      creditosDisponiveis > 0 ? creditosDisponiveis : null;

  bool get estaAtiva => status == 'ativa';

  factory Assinatura.fromMap(Map<String, dynamic> mapa, String id) {
    DateTime _parseDate(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }

    DateTime? _parseDateNullable(dynamic raw) {
      if (raw == null) return null;
      if (raw is Timestamp) return raw.toDate();
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return Assinatura(
      id: id,
      alunaId: mapa['alunaId'] as String,
      planoId: mapa['planoId'] as String,
      status: mapa['status'] as String,
      creditosDisponiveis: mapa['creditosDisponiveis'] as int,
      dataInicio: _parseDate(mapa['dataInicio']),
      dataRenovacao: _parseDate(mapa['dataRenovacao']),
      dataCancelamento: _parseDateNullable(mapa['dataCancelamento']),
      horarioFixoIds:
          (mapa['horarioFixoIds'] as List<dynamic>?)?.cast<String>() ?? [],
      aulasRealizadas: mapa['aulasRealizadas'] as int? ?? 0,
      reposicoesDisponiveis: mapa['reposicoesDisponiveis'] as int? ?? 0,
    );
  }

  factory Assinatura.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final mapa = doc.data()!;
    return Assinatura(
      id: doc.id,
      alunaId: mapa['alunaId'] as String,
      planoId: mapa['planoId'] as String,
      status: mapa['status'] as String,
      creditosDisponiveis: mapa['creditosDisponiveis'] as int,
      dataInicio: (mapa['dataInicio'] is Timestamp)
          ? (mapa['dataInicio'] as Timestamp).toDate()
          : DateTime.parse(mapa['dataInicio'] as String),
      dataRenovacao: (mapa['dataRenovacao'] is Timestamp)
          ? (mapa['dataRenovacao'] as Timestamp).toDate()
          : DateTime.parse(mapa['dataRenovacao'] as String),
      dataCancelamento: mapa['dataCancelamento'] != null
          ? (mapa['dataCancelamento'] is Timestamp
              ? (mapa['dataCancelamento'] as Timestamp).toDate()
              : DateTime.parse(mapa['dataCancelamento'] as String))
          : null,
      horarioFixoIds:
          (mapa['horarioFixoIds'] as List<dynamic>?)?.cast<String>() ?? [],
      aulasRealizadas: mapa['aulasRealizadas'] as int? ?? 0,
      reposicoesDisponiveis: mapa['reposicoesDisponiveis'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'planoId': planoId,
      'status': status,
      'creditosDisponiveis': creditosDisponiveis,
      'dataInicio': Timestamp.fromDate(dataInicio),
      'dataRenovacao': Timestamp.fromDate(dataRenovacao),
      'dataCancelamento': dataCancelamento != null
          ? Timestamp.fromDate(dataCancelamento!)
          : null,
      'horarioFixoIds': horarioFixoIds,
      'aulasRealizadas': aulasRealizadas,
      'reposicoesDisponiveis': reposicoesDisponiveis,
    };
  }

  Assinatura copyWith({
    String? id,
    String? alunaId,
    String? planoId,
    String? status,
    int? creditosDisponiveis,
    DateTime? dataInicio,
    DateTime? dataRenovacao,
    DateTime? dataCancelamento,
    List<String>? horarioFixoIds,
    int? aulasRealizadas,
    int? reposicoesDisponiveis,
  }) {
    return Assinatura(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      planoId: planoId ?? this.planoId,
      status: status ?? this.status,
      creditosDisponiveis: creditosDisponiveis ?? this.creditosDisponiveis,
      dataInicio: dataInicio ?? this.dataInicio,
      dataRenovacao: dataRenovacao ?? this.dataRenovacao,
      dataCancelamento: dataCancelamento ?? this.dataCancelamento,
      horarioFixoIds: horarioFixoIds ?? this.horarioFixoIds,
      aulasRealizadas: aulasRealizadas ?? this.aulasRealizadas,
      reposicoesDisponiveis:
          reposicoesDisponiveis ?? this.reposicoesDisponiveis,
    );
  }
}
