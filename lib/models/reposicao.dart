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

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  factory Reposicao.fromMap(Map<String, dynamic> mapa, String id) {
    return Reposicao(
      id: id,
      aulaOriginalId: mapa['aulaOriginalId'] as String,
      alunaId: mapa['alunaId'] as String,
      novaDataHora: _parseDateNullable(mapa['novaDataHora']),
      novoHorarioId: mapa['novoHorarioId'] as String?,
      status: mapa['status'] as String,
      motivoOriginal: mapa['motivoOriginal'] as String,
      atestadoValidado: mapa['atestadoValidado'] as bool?,
      criadaEm: _parseDate(mapa['criadaEm']),
      expiraEm: _parseDateNullable(mapa['expiraEm']),
      agendadaEm: _parseDateNullable(mapa['agendadaEm']),
      realizadaEm: _parseDateNullable(mapa['realizadaEm']),
    );
  }

  factory Reposicao.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    return Reposicao(
      id: doc.id,
      aulaOriginalId: mapa['aulaOriginalId'] as String,
      alunaId: mapa['alunaId'] as String,
      novaDataHora: _parseDateNullable(mapa['novaDataHora']),
      novoHorarioId: mapa['novoHorarioId'] as String?,
      status: mapa['status'] as String,
      motivoOriginal: mapa['motivoOriginal'] as String,
      atestadoValidado: mapa['atestadoValidado'] as bool?,
      criadaEm: _parseDate(mapa['criadaEm']),
      expiraEm: _parseDateNullable(mapa['expiraEm']),
      agendadaEm: _parseDateNullable(mapa['agendadaEm']),
      realizadaEm: _parseDateNullable(mapa['realizadaEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aulaOriginalId': aulaOriginalId,
      'alunaId': alunaId,
      'novaDataHora':
          novaDataHora != null ? Timestamp.fromDate(novaDataHora!) : null,
      'novoHorarioId': novoHorarioId,
      'status': status,
      'motivoOriginal': motivoOriginal,
      'atestadoValidado': atestadoValidado,
      'criadaEm': Timestamp.fromDate(criadaEm),
      'expiraEm': expiraEm != null ? Timestamp.fromDate(expiraEm!) : null,
      'agendadaEm': agendadaEm != null ? Timestamp.fromDate(agendadaEm!) : null,
      'realizadaEm':
          realizadaEm != null ? Timestamp.fromDate(realizadaEm!) : null,
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
