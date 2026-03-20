/// Modelo que representa um pagamento realizado por uma aluna.
class Pagamento {
  final String id;
  final String alunaId;
  final String? assinaturaId;
  final double valor;
  final String metodo; // 'pix', 'cartao', 'dinheiro'
  final String status; // 'pendente', 'confirmado', 'cancelado'
  final DateTime criadoEm;
  final DateTime? confirmadoEm;
  final String? comprovante;

  const Pagamento({
    required this.id,
    required this.alunaId,
    this.assinaturaId,
    required this.valor,
    required this.metodo,
    required this.status,
    required this.criadoEm,
    this.confirmadoEm,
    this.comprovante,
  });

  factory Pagamento.fromMap(Map<String, dynamic> mapa, String id) {
    return Pagamento(
      id: id,
      alunaId: mapa['alunaId'] as String,
      assinaturaId: mapa['assinaturaId'] as String?,
      valor: (mapa['valor'] as num).toDouble(),
      metodo: mapa['metodo'] as String,
      status: mapa['status'] as String,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
      confirmadoEm: mapa['confirmadoEm'] != null
          ? DateTime.parse(mapa['confirmadoEm'] as String)
          : null,
      comprovante: mapa['comprovante'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'assinaturaId': assinaturaId,
      'valor': valor,
      'metodo': metodo,
      'status': status,
      'criadoEm': criadoEm.toIso8601String(),
      'confirmadoEm': confirmadoEm?.toIso8601String(),
      'comprovante': comprovante,
    };
  }

  bool get estaConfirmado => status == 'confirmado';
}
