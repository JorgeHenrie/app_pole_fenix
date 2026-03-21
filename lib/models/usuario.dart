import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa uma usuária (aluna ou administradora) do app.
class Usuario {
  final String id;
  final String nome;
  final String email;
  final String tipoUsuario; // 'aluna' ou 'admin'
  final String? telefone;
  final DateTime dataCadastro;
  final bool ativo;
  final String? fotoUrl;
  final DateTime? atualizadoEm;

  // Campos de aprovação de cadastro
  final String statusCadastro; // 'pendente', 'aprovado', 'rejeitado'
  final DateTime? dataAprovacao;
  final String? aprovadoPor; // ID do admin que aprovou/rejeitou
  final String? motivoRejeicao;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipoUsuario,
    this.telefone,
    required this.dataCadastro,
    this.ativo = true,
    this.fotoUrl,
    this.atualizadoEm,
    this.statusCadastro = 'aprovado',
    this.dataAprovacao,
    this.aprovadoPor,
    this.motivoRejeicao,
  });

  factory Usuario.fromMap(Map<String, dynamic> mapa, String id) {
    DateTime _parseDateTime(dynamic valor) {
      if (valor is Timestamp) return valor.toDate();
      if (valor is String) return DateTime.parse(valor);
      return DateTime.now();
    }

    DateTime? _parseDateTimeOptional(dynamic valor) {
      if (valor == null) return null;
      if (valor is Timestamp) return valor.toDate();
      if (valor is String) return DateTime.parse(valor);
      return null;
    }

    return Usuario(
      id: id,
      nome: mapa['nome'] as String? ?? '',
      email: mapa['email'] as String? ?? '',
      tipoUsuario: mapa['tipoUsuario'] as String? ??
          mapa['perfil'] as String? ??
          'aluna',
      telefone: mapa['telefone'] as String?,
      dataCadastro:
          _parseDateTime(mapa['dataCadastro'] ?? mapa['criadoEm']),
      ativo: mapa['ativo'] as bool? ?? true,
      fotoUrl: mapa['fotoUrl'] as String?,
      atualizadoEm: _parseDateTimeOptional(mapa['atualizadoEm']),
      // Defaults to 'aprovado' for backward compatibility with existing users
      statusCadastro: mapa['statusCadastro'] as String? ?? 'aprovado',
      dataAprovacao: _parseDateTimeOptional(mapa['dataAprovacao']),
      aprovadoPor: mapa['aprovadoPor'] as String?,
      motivoRejeicao: mapa['motivoRejeicao'] as String?,
    );
  }

  factory Usuario.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return Usuario.fromMap(doc.data()!, doc.id);
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'tipoUsuario': tipoUsuario,
      'telefone': telefone,
      'dataCadastro': dataCadastro.toIso8601String(),
      'ativo': ativo,
      'fotoUrl': fotoUrl,
      'atualizadoEm': atualizadoEm?.toIso8601String(),
      'statusCadastro': statusCadastro,
      'dataAprovacao': dataAprovacao?.toIso8601String(),
      'aprovadoPor': aprovadoPor,
      'motivoRejeicao': motivoRejeicao,
    };
  }

  Usuario copyWith({
    String? nome,
    String? email,
    String? tipoUsuario,
    String? telefone,
    bool? ativo,
    String? fotoUrl,
    DateTime? atualizadoEm,
    String? statusCadastro,
    DateTime? dataAprovacao,
    String? aprovadoPor,
    String? motivoRejeicao,
  }) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      tipoUsuario: tipoUsuario ?? this.tipoUsuario,
      telefone: telefone ?? this.telefone,
      dataCadastro: dataCadastro,
      ativo: ativo ?? this.ativo,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
      statusCadastro: statusCadastro ?? this.statusCadastro,
      dataAprovacao: dataAprovacao ?? this.dataAprovacao,
      aprovadoPor: aprovadoPor ?? this.aprovadoPor,
      motivoRejeicao: motivoRejeicao ?? this.motivoRejeicao,
    );
  }
}
