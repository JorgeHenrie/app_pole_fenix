import 'package:cloud_firestore/cloud_firestore.dart';

class GradeHorario {
  final String id;
  final int diaSemana;
  final String horario;
  final int capacidadeMaxima;
  final String modalidade;
  final bool ativo;
  final DateTime criadoEm;

  const GradeHorario({
    required this.id,
    required this.diaSemana,
    required this.horario,
    this.capacidadeMaxima = 3,
    required this.modalidade,
    required this.ativo,
    required this.criadoEm,
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

  factory GradeHorario.fromMap(Map<String, dynamic> mapa, String id) {
    return GradeHorario(
      id: id,
      diaSemana: mapa['diaSemana'] as int,
      horario: mapa['horario'] as String,
      capacidadeMaxima: mapa['capacidadeMaxima'] as int? ?? 3,
      modalidade: mapa['modalidade'] as String,
      ativo: mapa['ativo'] as bool,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
    );
  }

  factory GradeHorario.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    final rawCriadoEm = mapa['criadoEm'];
    final DateTime criadoEm;
    if (rawCriadoEm is Timestamp) {
      criadoEm = rawCriadoEm.toDate();
    } else if (rawCriadoEm is String) {
      criadoEm = DateTime.tryParse(rawCriadoEm) ?? DateTime.now();
    } else {
      criadoEm = DateTime.now();
    }
    return GradeHorario(
      id: doc.id,
      diaSemana: mapa['diaSemana'] as int,
      horario: mapa['horario'] as String,
      capacidadeMaxima: mapa['capacidadeMaxima'] as int? ?? 3,
      modalidade: mapa['modalidade'] as String,
      ativo: mapa['ativo'] as bool,
      criadoEm: criadoEm,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diaSemana': diaSemana,
      'horario': horario,
      'capacidadeMaxima': capacidadeMaxima,
      'modalidade': modalidade,
      'ativo': ativo,
      'criadoEm': Timestamp.fromDate(criadoEm),
    };
  }

  GradeHorario copyWith({
    String? id,
    int? diaSemana,
    String? horario,
    int? capacidadeMaxima,
    String? modalidade,
    bool? ativo,
    DateTime? criadoEm,
  }) {
    return GradeHorario(
      id: id ?? this.id,
      diaSemana: diaSemana ?? this.diaSemana,
      horario: horario ?? this.horario,
      capacidadeMaxima: capacidadeMaxima ?? this.capacidadeMaxima,
      modalidade: modalidade ?? this.modalidade,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
    );
  }
}
