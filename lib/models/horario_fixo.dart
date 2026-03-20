import 'package:cloud_firestore/cloud_firestore.dart';

class HorarioFixo {
  final String id;
  final String alunaId;
  final String assinaturaId;
  final int diaSemana;
  final String horario;
  final String modalidade;
  final bool ativo;
  final DateTime criadoEm;
  final DateTime? desativadoEm;
  final String? motivoDesativacao;

  const HorarioFixo({
    required this.id,
    required this.alunaId,
    required this.assinaturaId,
    required this.diaSemana,
    required this.horario,
    required this.modalidade,
    required this.ativo,
    required this.criadoEm,
    this.desativadoEm,
    this.motivoDesativacao,
  });

  String get diaSemanaTexto {
    const nomes = {
      1: 'Segunda',
      2: 'Terça',
      3: 'Quarta',
      4: 'Quinta',
      5: 'Sexta',
      6: 'Sábado',
      7: 'Domingo',
    };
    return nomes[diaSemana] ?? '';
  }

  factory HorarioFixo.fromMap(Map<String, dynamic> mapa, String id) {
    return HorarioFixo(
      id: id,
      alunaId: mapa['alunaId'] as String,
      assinaturaId: mapa['assinaturaId'] as String,
      diaSemana: mapa['diaSemana'] as int,
      horario: mapa['horario'] as String,
      modalidade: mapa['modalidade'] as String,
      ativo: mapa['ativo'] as bool,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
      desativadoEm: mapa['desativadoEm'] != null
          ? DateTime.parse(mapa['desativadoEm'] as String)
          : null,
      motivoDesativacao: mapa['motivoDesativacao'] as String?,
    );
  }

  factory HorarioFixo.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    return HorarioFixo(
      id: doc.id,
      alunaId: mapa['alunaId'] as String,
      assinaturaId: mapa['assinaturaId'] as String,
      diaSemana: mapa['diaSemana'] as int,
      horario: mapa['horario'] as String,
      modalidade: mapa['modalidade'] as String,
      ativo: mapa['ativo'] as bool,
      criadoEm: (mapa['criadoEm'] as Timestamp).toDate(),
      desativadoEm: mapa['desativadoEm'] != null
          ? (mapa['desativadoEm'] as Timestamp).toDate()
          : null,
      motivoDesativacao: mapa['motivoDesativacao'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'assinaturaId': assinaturaId,
      'diaSemana': diaSemana,
      'horario': horario,
      'modalidade': modalidade,
      'ativo': ativo,
      'criadoEm': criadoEm.toIso8601String(),
      'desativadoEm': desativadoEm?.toIso8601String(),
      'motivoDesativacao': motivoDesativacao,
    };
  }

  HorarioFixo copyWith({
    String? id,
    String? alunaId,
    String? assinaturaId,
    int? diaSemana,
    String? horario,
    String? modalidade,
    bool? ativo,
    DateTime? criadoEm,
    DateTime? desativadoEm,
    String? motivoDesativacao,
  }) {
    return HorarioFixo(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      assinaturaId: assinaturaId ?? this.assinaturaId,
      diaSemana: diaSemana ?? this.diaSemana,
      horario: horario ?? this.horario,
      modalidade: modalidade ?? this.modalidade,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
      desativadoEm: desativadoEm ?? this.desativadoEm,
      motivoDesativacao: motivoDesativacao ?? this.motivoDesativacao,
    );
  }
}
