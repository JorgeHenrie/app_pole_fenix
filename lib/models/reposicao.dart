import 'package:cloud_firestore/cloud_firestore.dart';

class Reposicao {
  final String id;
  final String aulaOriginalId;
  final String alunaId;
  final DateTime? novaDataHora;
  final String? novoHorarioId;
  final String status;
  final String motivoOriginal;
  final bool? atestadoValidado;
  final DateTime criadaEm;
  final DateTime? expiraEm;
  final DateTime? agendadaEm;
  final DateTime? realizadaEm;

  const Reposicao({
    required this.id,
    required this.aulaOriginalId,
    required this.alunaId,
    this.novaDataHora,
    this.novoHorarioId,
    required this.status,
    required this.motivoOriginal,
    this.atestadoValidado,
    required this.criadaEm,
    this.expiraEm,
    this.agendadaEm,
    this.realizadaEm,
  });

  bool get expirou {
    if (expiraEm == null) return false;
    return DateTime.now().isAfter(expiraEm!);
  }

  int get diasRestantes {
    if (expiraEm == null) return 0;
    final diff = expiraEm!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  factory Reposicao.fromMap(Map<String, dynamic> mapa, String id) {
    return Reposicao(
      id: id,
      aulaOriginalId: mapa['aulaOriginalId'] as String,
      alunaId: mapa['alunaId'] as String,
      novaDataHora: mapa['novaDataHora'] != null
          ? DateTime.parse(mapa['novaDataHora'] as String)
          : null,
      novoHorarioId: mapa['novoHorarioId'] as String?,
      status: mapa['status'] as String,
      motivoOriginal: mapa['motivoOriginal'] as String,
      atestadoValidado: mapa['atestadoValidado'] as bool?,
      criadaEm: DateTime.parse(mapa['criadaEm'] as String),
      expiraEm: mapa['expiraEm'] != null
          ? DateTime.parse(mapa['expiraEm'] as String)
          : null,
      agendadaEm: mapa['agendadaEm'] != null
          ? DateTime.parse(mapa['agendadaEm'] as String)
          : null,
      realizadaEm: mapa['realizadaEm'] != null
          ? DateTime.parse(mapa['realizadaEm'] as String)
          : null,
    );
  }

  factory Reposicao.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    return Reposicao(
      id: doc.id,
      aulaOriginalId: mapa['aulaOriginalId'] as String,
      alunaId: mapa['alunaId'] as String,
      novaDataHora: mapa['novaDataHora'] != null
          ? (mapa['novaDataHora'] as Timestamp).toDate()
          : null,
      novoHorarioId: mapa['novoHorarioId'] as String?,
      status: mapa['status'] as String,
      motivoOriginal: mapa['motivoOriginal'] as String,
      atestadoValidado: mapa['atestadoValidado'] as bool?,
      criadaEm: (mapa['criadaEm'] as Timestamp).toDate(),
      expiraEm: mapa['expiraEm'] != null
          ? (mapa['expiraEm'] as Timestamp).toDate()
          : null,
      agendadaEm: mapa['agendadaEm'] != null
          ? (mapa['agendadaEm'] as Timestamp).toDate()
          : null,
      realizadaEm: mapa['realizadaEm'] != null
          ? (mapa['realizadaEm'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aulaOriginalId': aulaOriginalId,
      'alunaId': alunaId,
      'novaDataHora': novaDataHora?.toIso8601String(),
      'novoHorarioId': novoHorarioId,
      'status': status,
      'motivoOriginal': motivoOriginal,
      'atestadoValidado': atestadoValidado,
      'criadaEm': criadaEm.toIso8601String(),
      'expiraEm': expiraEm?.toIso8601String(),
      'agendadaEm': agendadaEm?.toIso8601String(),
      'realizadaEm': realizadaEm?.toIso8601String(),
    };
  }

  Reposicao copyWith({
    String? id,
    String? aulaOriginalId,
    String? alunaId,
    DateTime? novaDataHora,
    String? novoHorarioId,
    String? status,
    String? motivoOriginal,
    bool? atestadoValidado,
    DateTime? criadaEm,
    DateTime? expiraEm,
    DateTime? agendadaEm,
    DateTime? realizadaEm,
  }) {
    return Reposicao(
      id: id ?? this.id,
      aulaOriginalId: aulaOriginalId ?? this.aulaOriginalId,
      alunaId: alunaId ?? this.alunaId,
      novaDataHora: novaDataHora ?? this.novaDataHora,
      novoHorarioId: novoHorarioId ?? this.novoHorarioId,
      status: status ?? this.status,
      motivoOriginal: motivoOriginal ?? this.motivoOriginal,
      atestadoValidado: atestadoValidado ?? this.atestadoValidado,
      criadaEm: criadaEm ?? this.criadaEm,
      expiraEm: expiraEm ?? this.expiraEm,
      agendadaEm: agendadaEm ?? this.agendadaEm,
      realizadaEm: realizadaEm ?? this.realizadaEm,
    );
  }
}
