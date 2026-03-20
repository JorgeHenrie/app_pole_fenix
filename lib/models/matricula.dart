/// Modelo que representa a matrícula de uma aluna em uma aula.
class Matricula {
  final String id;
  final String alunaId;
  final String aulaId;
  final String status; // 'confirmada', 'cancelada', 'realizada'
  final DateTime criadaEm;
  final DateTime? canceladaEm;

  const Matricula({
    required this.id,
    required this.alunaId,
    required this.aulaId,
    required this.status,
    required this.criadaEm,
    this.canceladaEm,
  });

  factory Matricula.fromMap(Map<String, dynamic> mapa, String id) {
    return Matricula(
      id: id,
      alunaId: mapa['alunaId'] as String,
      aulaId: mapa['aulaId'] as String,
      status: mapa['status'] as String,
      criadaEm: DateTime.parse(mapa['criadaEm'] as String),
      canceladaEm: mapa['canceladaEm'] != null
          ? DateTime.parse(mapa['canceladaEm'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'aulaId': aulaId,
      'status': status,
      'criadaEm': criadaEm.toIso8601String(),
      'canceladaEm': canceladaEm?.toIso8601String(),
    };
  }

  bool get estaConfirmada => status == 'confirmada';
}
