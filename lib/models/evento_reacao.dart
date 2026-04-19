import 'package:cloud_firestore/cloud_firestore.dart';

enum TipoReacaoEvento {
  curtir,
  amar,
  fogo;

  String get valor {
    switch (this) {
      case TipoReacaoEvento.curtir:
        return 'curtir';
      case TipoReacaoEvento.amar:
        return 'amar';
      case TipoReacaoEvento.fogo:
        return 'fogo';
    }
  }

  static TipoReacaoEvento? fromValor(String? valor) {
    switch (valor) {
      case 'curtir':
        return TipoReacaoEvento.curtir;
      case 'amar':
        return TipoReacaoEvento.amar;
      case 'fogo':
        return TipoReacaoEvento.fogo;
      default:
        return null;
    }
  }
}

class EventoReacao {
  final String usuarioId;
  final String usuarioNome;
  final TipoReacaoEvento tipo;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;

  const EventoReacao({
    required this.usuarioId,
    required this.usuarioNome,
    required this.tipo,
    required this.criadoEm,
    this.atualizadoEm,
  });

  static DateTime _parseDate(dynamic valor) {
    if (valor is DateTime) return valor;
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor) ?? DateTime.now();
    return DateTime.now();
  }

  static DateTime? _parseDateNullable(dynamic valor) {
    if (valor == null) return null;
    if (valor is DateTime) return valor;
    if (valor is Timestamp) return valor.toDate();
    if (valor is String) return DateTime.tryParse(valor);
    return null;
  }

  factory EventoReacao.fromMap(Map<String, dynamic> mapa, String usuarioId) {
    return EventoReacao(
      usuarioId: usuarioId,
      usuarioNome: mapa['usuarioNome'] as String? ?? '',
      tipo: TipoReacaoEvento.fromValor(mapa['tipo'] as String?) ??
          TipoReacaoEvento.curtir,
      criadoEm: _parseDate(mapa['criadoEm']),
      atualizadoEm: _parseDateNullable(mapa['atualizadoEm']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuarioId': usuarioId,
      'usuarioNome': usuarioNome,
      'tipo': tipo.valor,
      'criadoEm': Timestamp.fromDate(criadoEm),
      'atualizadoEm':
          atualizadoEm != null ? Timestamp.fromDate(atualizadoEm!) : null,
    };
  }
}
