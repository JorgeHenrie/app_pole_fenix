import 'package:cloud_firestore/cloud_firestore.dart';

class Aula {
  final String id;
  final String alunaId;
  final String? horarioFixoId;
  final DateTime dataHora;
  final String modalidade;
  final String status; // 'agendada', 'cancelada', 'realizada', 'falta'
  final String? motivoCancelamento;
  final DateTime? dataCancelamento;
  final bool dentroDosPrazo;
  final DateTime criadaEm;
  final String? titulo;
  final int? duracaoMinutos;
  final int? capacidadeMaxima;
  final int? vagasOcupadas;
  final String? instrutora;

  const Aula({
    required this.id,
    required this.alunaId,
    this.horarioFixoId,
    required this.dataHora,
    required this.modalidade,
    required this.status,
    this.motivoCancelamento,
    this.dataCancelamento,
    this.dentroDosPrazo = true,
    required this.criadaEm,
    this.titulo,
    this.duracaoMinutos,
    this.capacidadeMaxima,
    this.vagasOcupadas,
    this.instrutora,
  });

  bool get podeSerCancelada =>
      dataHora.difference(DateTime.now()).inHours >= 2;

  Duration get tempoAteCancelamento => dataHora.difference(DateTime.now());

  int get vagasDisponiveis =>
      (capacidadeMaxima ?? 0) - (vagasOcupadas ?? 0);

  bool get temVaga => vagasDisponiveis > 0;

  factory Aula.fromMap(Map<String, dynamic> mapa, String id) {
    return Aula(
      id: id,
      alunaId: mapa['alunaId'] as String? ?? '',
      horarioFixoId: mapa['horarioFixoId'] as String?,
      dataHora: DateTime.parse(mapa['dataHora'] as String),
      modalidade: mapa['modalidade'] as String? ?? '',
      status: mapa['status'] as String,
      motivoCancelamento: mapa['motivoCancelamento'] as String?,
      dataCancelamento: mapa['dataCancelamento'] != null
          ? DateTime.parse(mapa['dataCancelamento'] as String)
          : null,
      dentroDosPrazo: mapa['dentroDosPrazo'] as bool? ?? true,
      criadaEm: DateTime.parse(mapa['criadaEm'] as String),
      titulo: mapa['titulo'] as String?,
      duracaoMinutos: mapa['duracaoMinutos'] as int?,
      capacidadeMaxima: mapa['capacidadeMaxima'] as int?,
      vagasOcupadas: mapa['vagasOcupadas'] as int?,
      instrutora: mapa['instrutora'] as String?,
    );
  }

  factory Aula.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    return Aula(
      id: doc.id,
      alunaId: mapa['alunaId'] as String? ?? '',
      horarioFixoId: mapa['horarioFixoId'] as String?,
      dataHora: (mapa['dataHora'] is Timestamp)
          ? (mapa['dataHora'] as Timestamp).toDate()
          : DateTime.parse(mapa['dataHora'] as String),
      modalidade: mapa['modalidade'] as String? ?? '',
      status: mapa['status'] as String,
      motivoCancelamento: mapa['motivoCancelamento'] as String?,
      dataCancelamento: mapa['dataCancelamento'] != null
          ? (mapa['dataCancelamento'] is Timestamp
              ? (mapa['dataCancelamento'] as Timestamp).toDate()
              : DateTime.parse(mapa['dataCancelamento'] as String))
          : null,
      dentroDosPrazo: mapa['dentroDosPrazo'] as bool? ?? true,
      criadaEm: (mapa['criadaEm'] is Timestamp)
          ? (mapa['criadaEm'] as Timestamp).toDate()
          : DateTime.parse(mapa['criadaEm'] as String),
      titulo: mapa['titulo'] as String?,
      duracaoMinutos: mapa['duracaoMinutos'] as int?,
      capacidadeMaxima: mapa['capacidadeMaxima'] as int?,
      vagasOcupadas: mapa['vagasOcupadas'] as int?,
      instrutora: mapa['instrutora'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'horarioFixoId': horarioFixoId,
      'dataHora': dataHora.toIso8601String(),
      'modalidade': modalidade,
      'status': status,
      'motivoCancelamento': motivoCancelamento,
      'dataCancelamento': dataCancelamento?.toIso8601String(),
      'dentroDosPrazo': dentroDosPrazo,
      'criadaEm': criadaEm.toIso8601String(),
      'titulo': titulo,
      'duracaoMinutos': duracaoMinutos,
      'capacidadeMaxima': capacidadeMaxima,
      'vagasOcupadas': vagasOcupadas,
      'instrutora': instrutora,
    };
  }

  Aula copyWith({
    String? id,
    String? alunaId,
    String? horarioFixoId,
    DateTime? dataHora,
    String? modalidade,
    String? status,
    String? motivoCancelamento,
    DateTime? dataCancelamento,
    bool? dentroDosPrazo,
    DateTime? criadaEm,
    String? titulo,
    int? duracaoMinutos,
    int? capacidadeMaxima,
    int? vagasOcupadas,
    String? instrutora,
  }) {
    return Aula(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      horarioFixoId: horarioFixoId ?? this.horarioFixoId,
      dataHora: dataHora ?? this.dataHora,
      modalidade: modalidade ?? this.modalidade,
      status: status ?? this.status,
      motivoCancelamento: motivoCancelamento ?? this.motivoCancelamento,
      dataCancelamento: dataCancelamento ?? this.dataCancelamento,
      dentroDosPrazo: dentroDosPrazo ?? this.dentroDosPrazo,
      criadaEm: criadaEm ?? this.criadaEm,
      titulo: titulo ?? this.titulo,
      duracaoMinutos: duracaoMinutos ?? this.duracaoMinutos,
      capacidadeMaxima: capacidadeMaxima ?? this.capacidadeMaxima,
      vagasOcupadas: vagasOcupadas ?? this.vagasOcupadas,
      instrutora: instrutora ?? this.instrutora,
    );
  }
}
