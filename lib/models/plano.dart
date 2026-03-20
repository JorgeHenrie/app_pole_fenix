/// Modelo que representa um plano de assinatura disponível no estúdio.
class Plano {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final int aulasPorMes;
  final bool ativo;
  final DateTime criadoEm;

  const Plano({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.aulasPorMes,
    required this.ativo,
    required this.criadoEm,
  });

  factory Plano.fromMap(Map<String, dynamic> mapa, String id) {
    return Plano(
      id: id,
      nome: mapa['nome'] as String,
      descricao: mapa['descricao'] as String,
      preco: (mapa['preco'] as num).toDouble(),
      aulasPorMes: mapa['aulasPorMes'] as int,
      ativo: mapa['ativo'] as bool,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'preco': preco,
      'aulasPorMes': aulasPorMes,
      'ativo': ativo,
      'criadoEm': criadoEm.toIso8601String(),
    };
  }
}
