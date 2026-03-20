import 'package:cloud_firestore/cloud_firestore.dart';

class Plano {
  final String id;
  final String nome;
  final String descricao;
  final double preco;
  final int aulasPorMes;
  final bool ativo;
  final DateTime criadoEm;
  final int aulasSemanais;
  final int duracaoDias;

  const Plano({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.preco,
    required this.aulasPorMes,
    required this.ativo,
    required this.criadoEm,
    this.aulasSemanais = 1,
    this.duracaoDias = 30,
  });

  double get valor => preco;
  int get quantidadeAulas => aulasPorMes;

  factory Plano.fromMap(Map<String, dynamic> mapa, String id) {
    return Plano(
      id: id,
      nome: mapa['nome'] as String,
      descricao: mapa['descricao'] as String,
      preco: (mapa['preco'] ?? mapa['valor'] as num? ?? 0).toDouble(),
      aulasPorMes:
          mapa['aulasPorMes'] as int? ?? mapa['quantidadeAulas'] as int? ?? 0,
      ativo: mapa['ativo'] as bool,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
      aulasSemanais: mapa['aulasSemanais'] as int? ?? 1,
      duracaoDias: mapa['duracaoDias'] as int? ?? 30,
    );
  }

  factory Plano.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final mapa = doc.data()!;
    return Plano(
      id: doc.id,
      nome: mapa['nome'] as String,
      descricao: mapa['descricao'] as String,
      preco: (mapa['preco'] ?? mapa['valor'] as num? ?? 0).toDouble(),
      aulasPorMes:
          mapa['aulasPorMes'] as int? ?? mapa['quantidadeAulas'] as int? ?? 0,
      ativo: mapa['ativo'] as bool,
      criadoEm: (mapa['criadoEm'] is Timestamp)
          ? (mapa['criadoEm'] as Timestamp).toDate()
          : DateTime.parse(mapa['criadoEm'] as String),
      aulasSemanais: mapa['aulasSemanais'] as int? ?? 1,
      duracaoDias: mapa['duracaoDias'] as int? ?? 30,
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
      'aulasSemanais': aulasSemanais,
      'duracaoDias': duracaoDias,
    };
  }

  Plano copyWith({
    String? id,
    String? nome,
    String? descricao,
    double? preco,
    int? aulasPorMes,
    bool? ativo,
    DateTime? criadoEm,
    int? aulasSemanais,
    int? duracaoDias,
  }) {
    return Plano(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      descricao: descricao ?? this.descricao,
      preco: preco ?? this.preco,
      aulasPorMes: aulasPorMes ?? this.aulasPorMes,
      ativo: ativo ?? this.ativo,
      criadoEm: criadoEm ?? this.criadoEm,
      aulasSemanais: aulasSemanais ?? this.aulasSemanais,
      duracaoDias: duracaoDias ?? this.duracaoDias,
    );
  }
}
