/// Modelo que representa um ajuste manual de crédito feito pelo admin.
class AjusteCredito {
  final String id;
  final String alunaId;
  final int quantidade; // positivo = adicionar, negativo = remover
  final String motivo;
  final String adminId;
  final DateTime criadoEm;

  const AjusteCredito({
    required this.id,
    required this.alunaId,
    required this.quantidade,
    required this.motivo,
    required this.adminId,
    required this.criadoEm,
  });

  factory AjusteCredito.fromMap(Map<String, dynamic> mapa, String id) {
    return AjusteCredito(
      id: id,
      alunaId: mapa['alunaId'] as String,
      quantidade: mapa['quantidade'] as int,
      motivo: mapa['motivo'] as String,
      adminId: mapa['adminId'] as String,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'quantidade': quantidade,
      'motivo': motivo,
      'adminId': adminId,
      'criadoEm': criadoEm.toIso8601String(),
    };
  }

  bool get eAdicao => quantidade > 0;
}
