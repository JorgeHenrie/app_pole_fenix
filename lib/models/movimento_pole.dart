import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class NivelDificuldadeMovimento {
  final String id;
  final String label;
  final String descricao;
  final int ordem;
  final String corHex;
  final bool ativo;

  const NivelDificuldadeMovimento({
    required this.id,
    required this.label,
    required this.descricao,
    required this.ordem,
    required this.corHex,
    this.ativo = true,
  });

  String get valor => id;
  Color get cor => _parseHexColor(corHex);

  static final List<NivelDificuldadeMovimento> padroes = [
    const NivelDificuldadeMovimento(
      id: 'iniciante',
      label: 'Iniciante',
      descricao:
          'Movimentos iniciais para construir base, confiança e consciência corporal.',
      ordem: 0,
      corHex: '#4E8C7A',
    ),
    const NivelDificuldadeMovimento(
      id: 'basico',
      label: 'Básico',
      descricao: 'Movimentos do básico.',
      ordem: 1,
      corHex: '#3C6E9F',
    ),
    const NivelDificuldadeMovimento(
      id: 'intermediario',
      label: 'Intermediário',
      descricao: 'Movimentos intermediários.',
      ordem: 2,
      corHex: '#B26A2E',
    ),
    const NivelDificuldadeMovimento(
      id: 'avancado',
      label: 'Avançado',
      descricao:
          'Movimentos avançados, com maior exigência técnica e refinamento.',
      ordem: 3,
      corHex: '#7A3042',
    ),
  ];

  static List<NivelDificuldadeMovimento> get values =>
      List.unmodifiable(padroes);

  static Map<String, NivelDificuldadeMovimento> get _padroesPorId => {
        for (final nivel in padroes) nivel.id: nivel,
      };

  factory NivelDificuldadeMovimento.fromMap(
    Map<String, dynamic> mapa,
    String id,
  ) {
    return fromEmbedded(
      id: id,
      label: mapa['nome']?.toString() ?? mapa['label']?.toString(),
      descricao: mapa['descricao']?.toString(),
      ordem: parseOrdem(mapa['ordem']),
      corHex: mapa['corHex']?.toString(),
      ativo: mapa['ativo'] as bool?,
    );
  }

  static NivelDificuldadeMovimento fromValor(String? valor) {
    return fromEmbedded(id: valor);
  }

  static NivelDificuldadeMovimento fromEmbedded({
    String? id,
    String? label,
    String? descricao,
    int? ordem,
    String? corHex,
    bool? ativo,
  }) {
    final idNormalizado = normalizarId(id ?? label);
    final legado = _padroesPorId[idNormalizado];
    final labelFinal =
        _textoLimpo(label) ?? legado?.label ?? _labelFromId(idNormalizado);
    final descricaoFinal = _textoLimpo(descricao) ??
        legado?.descricao ??
        'Movimentos do nível ${labelFinal.toLowerCase()}.';

    return NivelDificuldadeMovimento(
      id: idNormalizado.isEmpty ? (legado?.id ?? 'iniciante') : idNormalizado,
      label: labelFinal,
      descricao: descricaoFinal,
      ordem: ordem ?? legado?.ordem ?? 999,
      corHex: _normalizarCorHex(corHex) ??
          legado?.corHex ??
          _corHexPadrao(idNormalizado),
      ativo: ativo ?? legado?.ativo ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': label,
      'descricao': descricao,
      'ordem': ordem,
      'corHex': corHex,
      'ativo': ativo,
    };
  }

  Map<String, dynamic> toEmbeddedMap() {
    return {
      'nivel': id,
      'nivelId': id,
      'nivelNome': label,
      'nivelDescricao': descricao,
      'nivelOrdem': ordem,
      'nivelCor': corHex,
      'nivelAtivo': ativo,
    };
  }

  NivelDificuldadeMovimento copyWith({
    String? id,
    String? label,
    String? descricao,
    int? ordem,
    String? corHex,
    bool? ativo,
  }) {
    return NivelDificuldadeMovimento(
      id: id ?? this.id,
      label: label ?? this.label,
      descricao: descricao ?? this.descricao,
      ordem: ordem ?? this.ordem,
      corHex: corHex ?? this.corHex,
      ativo: ativo ?? this.ativo,
    );
  }

  static String normalizarId(String? valor) {
    if (valor == null) return '';

    final base = valor
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');

    return base
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static int? parseOrdem(dynamic valor) {
    if (valor is int) return valor;
    if (valor is num) return valor.toInt();
    if (valor is String) return int.tryParse(valor);
    return null;
  }

  static String? _textoLimpo(String? valor) {
    final texto = valor?.trim();
    if (texto == null || texto.isEmpty) return null;
    return texto;
  }

  static String _labelFromId(String id) {
    if (id.isEmpty) return 'Iniciante';

    return id
        .split('_')
        .where((parte) => parte.isNotEmpty)
        .map((parte) => parte[0].toUpperCase() + parte.substring(1))
        .join(' ');
  }

  static String? _normalizarCorHex(String? valor) {
    if (valor == null) return null;
    final base = valor.trim().replaceAll('#', '');
    if (base.length != 6) return null;
    return '#${base.toUpperCase()}';
  }

  static String _corHexPadrao(String id) {
    if (id.contains('inic')) return '#4E8C7A';
    if (id.contains('bas')) return '#3C6E9F';
    if (id.contains('inter')) return '#B26A2E';
    if (id.contains('avanc')) return '#7A3042';
    return '#D8C2A0';
  }

  static Color _parseHexColor(String valor) {
    final hex = valor.replaceAll('#', '');
    final buffer = StringBuffer();
    if (hex.length == 6) buffer.write('FF');
    buffer.write(hex);
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

enum CategoriaMovimentoPole {
  movimentoEstatico,
  giros,
  combos;

  String get valor {
    switch (this) {
      case CategoriaMovimentoPole.movimentoEstatico:
        return 'movimento_estatico';
      case CategoriaMovimentoPole.giros:
        return 'giros';
      case CategoriaMovimentoPole.combos:
        return 'combos';
    }
  }

  String get label {
    switch (this) {
      case CategoriaMovimentoPole.movimentoEstatico:
        return 'Movimento estático';
      case CategoriaMovimentoPole.giros:
        return 'Giros';
      case CategoriaMovimentoPole.combos:
        return 'Combos';
    }
  }

  Color get cor {
    switch (this) {
      case CategoriaMovimentoPole.movimentoEstatico:
        return const Color(0xFF8A6440);
      case CategoriaMovimentoPole.giros:
        return const Color(0xFF356D9A);
      case CategoriaMovimentoPole.combos:
        return const Color(0xFF8A4C5E);
    }
  }

  static CategoriaMovimentoPole fromValor(String? valor) {
    final normalizado = _normalizar(valor);

    if (normalizado.contains('combo')) {
      return CategoriaMovimentoPole.combos;
    }

    if (normalizado.contains('giro') || normalizado.contains('spin')) {
      return CategoriaMovimentoPole.giros;
    }

    if (normalizado.contains('estatico') || normalizado.contains('static')) {
      return CategoriaMovimentoPole.movimentoEstatico;
    }

    return CategoriaMovimentoPole.values.firstWhere(
      (categoria) => categoria.valor == normalizado,
      orElse: () => CategoriaMovimentoPole.movimentoEstatico,
    );
  }

  static String _normalizar(String? valor) {
    if (valor == null) return '';

    final base = valor
        .toLowerCase()
        .trim()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');

    return base
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

class MovimentoPole {
  final String id;
  final String nome;
  final CategoriaMovimentoPole categoria;
  final NivelDificuldadeMovimento nivel;
  final bool ativo;
  final String criadoPor;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;

  const MovimentoPole({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.nivel,
    required this.ativo,
    required this.criadoPor,
    required this.criadoEm,
    this.atualizadoEm,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic valor) {
    if (valor == null) return null;
    if (valor is Timestamp) return valor.toDate();
    if (valor is DateTime) return valor;
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  factory MovimentoPole.fromMap(Map<String, dynamic> mapa, String id) {
    return MovimentoPole(
      id: id,
      nome: mapa['nome'] as String? ?? '',
      categoria: CategoriaMovimentoPole.fromValor(
        mapa['categoria']?.toString() ?? mapa['descricao']?.toString(),
      ),
      nivel: NivelDificuldadeMovimento.fromEmbedded(
        id: mapa['nivelId']?.toString() ?? mapa['nivel']?.toString(),
        label: mapa['nivelNome']?.toString(),
        descricao: mapa['nivelDescricao']?.toString(),
        ordem: NivelDificuldadeMovimento.parseOrdem(mapa['nivelOrdem']),
        corHex: mapa['nivelCor']?.toString(),
        ativo: mapa['nivelAtivo'] as bool?,
      ),
      ativo: mapa['ativo'] as bool? ?? true,
      criadoPor: mapa['criadoPor'] as String? ?? '',
      criadoEm: _parseDate(mapa['criadoEm']),
      atualizadoEm: _parseDateNullable(mapa['atualizadoEm']),
    );
  }

  factory MovimentoPole.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return MovimentoPole.fromMap(doc.data()!, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'categoria': categoria.valor,
      ...nivel.toEmbeddedMap(),
      'ativo': ativo,
      'criadoPor': criadoPor,
      'criadoEm': Timestamp.fromDate(criadoEm),
      'atualizadoEm':
          atualizadoEm != null ? Timestamp.fromDate(atualizadoEm!) : null,
    };
  }

  MovimentoPole copyWith({
    String? id,
    String? nome,
    CategoriaMovimentoPole? categoria,
    NivelDificuldadeMovimento? nivel,
    bool? ativo,
    String? criadoPor,
    DateTime? criadoEm,
    DateTime? atualizadoEm,
  }) {
    return MovimentoPole(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      categoria: categoria ?? this.categoria,
      nivel: nivel ?? this.nivel,
      ativo: ativo ?? this.ativo,
      criadoPor: criadoPor ?? this.criadoPor,
      criadoEm: criadoEm ?? this.criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
