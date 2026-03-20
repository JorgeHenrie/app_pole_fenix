/// Modelo que representa a assinatura ativa de uma aluna.
class Assinatura {
  final String id;
  final String alunaId;
  final String planoId;
  final String status; // 'ativa', 'suspensa', 'cancelada'
  final int creditosDisponiveis;
  final DateTime dataInicio;
  final DateTime dataRenovacao;
  final DateTime? dataCancelamento;

  const Assinatura({
    required this.id,
    required this.alunaId,
    required this.planoId,
    required this.status,
    required this.creditosDisponiveis,
    required this.dataInicio,
    required this.dataRenovacao,
    this.dataCancelamento,
  });

  factory Assinatura.fromMap(Map<String, dynamic> mapa, String id) {
    return Assinatura(
      id: id,
      alunaId: mapa['alunaId'] as String,
      planoId: mapa['planoId'] as String,
      status: mapa['status'] as String,
      creditosDisponiveis: mapa['creditosDisponiveis'] as int,
      dataInicio: DateTime.parse(mapa['dataInicio'] as String),
      dataRenovacao: DateTime.parse(mapa['dataRenovacao'] as String),
      dataCancelamento: mapa['dataCancelamento'] != null
          ? DateTime.parse(mapa['dataCancelamento'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'planoId': planoId,
      'status': status,
      'creditosDisponiveis': creditosDisponiveis,
      'dataInicio': dataInicio.toIso8601String(),
      'dataRenovacao': dataRenovacao.toIso8601String(),
      'dataCancelamento': dataCancelamento?.toIso8601String(),
    };
  }

  bool get estaAtiva => status == 'ativa';
}
