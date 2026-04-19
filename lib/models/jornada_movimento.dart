import 'package:cloud_firestore/cloud_firestore.dart';

import 'movimento_pole.dart';

class FotoJornadaMovimento {
  final String url;
  final String caminhoStorage;
  final DateTime enviadaEm;

  const FotoJornadaMovimento({
    required this.url,
    required this.caminhoStorage,
    required this.enviadaEm,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  factory FotoJornadaMovimento.fromMap(Map<String, dynamic> mapa) {
    return FotoJornadaMovimento(
      url: mapa['url'] as String? ?? '',
      caminhoStorage: mapa['caminhoStorage'] as String? ?? '',
      enviadaEm: _parseDate(mapa['enviadaEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'caminhoStorage': caminhoStorage,
      'enviadaEm': Timestamp.fromDate(enviadaEm),
    };
  }
}

class JornadaMovimento {
  final String id;
  final String alunaId;
  final String alunaNome;
  final String movimentoId;
  final String movimentoNome;
  final CategoriaMovimentoPole movimentoCategoria;
  final NivelDificuldadeMovimento nivel;
  final String liberadoPor;
  final DateTime liberadoEm;
  final List<FotoJornadaMovimento> fotos;

  const JornadaMovimento({
    required this.id,
    required this.alunaId,
    required this.alunaNome,
    required this.movimentoId,
    required this.movimentoNome,
    required this.movimentoCategoria,
    required this.nivel,
    required this.liberadoPor,
    required this.liberadoEm,
    this.fotos = const [],
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  factory JornadaMovimento.fromMap(Map<String, dynamic> mapa, String id) {
    final fotos = (mapa['fotos'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FotoJornadaMovimento.fromMap)
        .toList();

    return JornadaMovimento(
      id: id,
      alunaId: mapa['alunaId'] as String? ?? '',
      alunaNome: mapa['alunaNome'] as String? ?? 'Aluna',
      movimentoId: mapa['movimentoId'] as String? ?? '',
      movimentoNome: mapa['movimentoNome'] as String? ?? '',
      movimentoCategoria: CategoriaMovimentoPole.fromValor(
        mapa['movimentoCategoria']?.toString() ??
            mapa['movimentoDescricao']?.toString(),
      ),
      nivel: NivelDificuldadeMovimento.fromEmbedded(
        id: mapa['nivelId']?.toString() ?? mapa['nivel']?.toString(),
        label: mapa['nivelNome']?.toString(),
        descricao: mapa['nivelDescricao']?.toString(),
        ordem: NivelDificuldadeMovimento.parseOrdem(mapa['nivelOrdem']),
        corHex: mapa['nivelCor']?.toString(),
        ativo: mapa['nivelAtivo'] as bool?,
      ),
      liberadoPor: mapa['liberadoPor'] as String? ?? '',
      liberadoEm: _parseDate(mapa['liberadoEm']),
      fotos: fotos,
    );
  }

  factory JornadaMovimento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return JornadaMovimento.fromMap(doc.data()!, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'alunaId': alunaId,
      'alunaNome': alunaNome,
      'movimentoId': movimentoId,
      'movimentoNome': movimentoNome,
      'movimentoCategoria': movimentoCategoria.valor,
      ...nivel.toEmbeddedMap(),
      'liberadoPor': liberadoPor,
      'liberadoEm': Timestamp.fromDate(liberadoEm),
      'fotos': fotos.map((foto) => foto.toMap()).toList(),
    };
  }

  JornadaMovimento copyWith({
    String? id,
    String? alunaId,
    String? alunaNome,
    String? movimentoId,
    String? movimentoNome,
    CategoriaMovimentoPole? movimentoCategoria,
    NivelDificuldadeMovimento? nivel,
    String? liberadoPor,
    DateTime? liberadoEm,
    List<FotoJornadaMovimento>? fotos,
  }) {
    return JornadaMovimento(
      id: id ?? this.id,
      alunaId: alunaId ?? this.alunaId,
      alunaNome: alunaNome ?? this.alunaNome,
      movimentoId: movimentoId ?? this.movimentoId,
      movimentoNome: movimentoNome ?? this.movimentoNome,
      movimentoCategoria: movimentoCategoria ?? this.movimentoCategoria,
      nivel: nivel ?? this.nivel,
      liberadoPor: liberadoPor ?? this.liberadoPor,
      liberadoEm: liberadoEm ?? this.liberadoEm,
      fotos: fotos ?? this.fotos,
    );
  }
}
