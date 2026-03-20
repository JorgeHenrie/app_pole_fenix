/// Modelo que representa uma aula agendada no estúdio.
class Aula {
  final String id;
  final String titulo;
  final DateTime dataHora;
  final int duracaoMinutos;
  final int capacidadeMaxima;
  final int vagasOcupadas;
  final String? instrutora;
  final String status; // 'agendada', 'realizada', 'cancelada'
  final DateTime criadaEm;

  const Aula({
    required this.id,
    required this.titulo,
    required this.dataHora,
    required this.duracaoMinutos,
    required this.capacidadeMaxima,
    required this.vagasOcupadas,
    this.instrutora,
    required this.status,
    required this.criadaEm,
  });

  factory Aula.fromMap(Map<String, dynamic> mapa, String id) {
    return Aula(
      id: id,
      titulo: mapa['titulo'] as String,
      dataHora: DateTime.parse(mapa['dataHora'] as String),
      duracaoMinutos: mapa['duracaoMinutos'] as int,
      capacidadeMaxima: mapa['capacidadeMaxima'] as int,
      vagasOcupadas: mapa['vagasOcupadas'] as int,
      instrutora: mapa['instrutora'] as String?,
      status: mapa['status'] as String,
      criadaEm: DateTime.parse(mapa['criadaEm'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'dataHora': dataHora.toIso8601String(),
      'duracaoMinutos': duracaoMinutos,
      'capacidadeMaxima': capacidadeMaxima,
      'vagasOcupadas': vagasOcupadas,
      'instrutora': instrutora,
      'status': status,
      'criadaEm': criadaEm.toIso8601String(),
    };
  }

  int get vagasDisponiveis => capacidadeMaxima - vagasOcupadas;
  bool get temVaga => vagasDisponiveis > 0;
}
