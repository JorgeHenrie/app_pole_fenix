import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Níveis de progressão das alunas.
enum NivelAluna {
  experimental,
  iniciante,
  basico,
  interI,
  interII,
  avancado;

  /// Rótulo exibido na UI.
  String get label {
    switch (this) {
      case NivelAluna.experimental:
        return 'EXPERIMENTAL';
      case NivelAluna.iniciante:
        return 'INICIANTE';
      case NivelAluna.basico:
        return 'BÁSICO';
      case NivelAluna.interI:
        return 'INTER I';
      case NivelAluna.interII:
        return 'INTER II';
      case NivelAluna.avancado:
        return 'AVANÇADO';
    }
  }

  /// Valor salvo no Firestore.
  String get valor {
    switch (this) {
      case NivelAluna.experimental:
        return 'experimental';
      case NivelAluna.iniciante:
        return 'iniciante';
      case NivelAluna.basico:
        return 'basico';
      case NivelAluna.interI:
        return 'inter_i';
      case NivelAluna.interII:
        return 'inter_ii';
      case NivelAluna.avancado:
        return 'avancado';
    }
  }

  /// Cor associada ao nível.
  Color get cor {
    switch (this) {
      case NivelAluna.experimental:
        return Colors.grey;
      case NivelAluna.iniciante:
        return Colors.teal;
      case NivelAluna.basico:
        return Colors.blue;
      case NivelAluna.interI:
        return Colors.orange;
      case NivelAluna.interII:
        return Colors.deepOrange;
      case NivelAluna.avancado:
        return Colors.purple;
    }
  }

  /// Constrói a partir do valor armazenado no Firestore.
  static NivelAluna? fromValor(String? valor) {
    if (valor == null) return null;
    return NivelAluna.values.firstWhere(
      (n) => n.valor == valor,
      orElse: () => NivelAluna.experimental,
    );
  }
}

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

  /// Plano escolhido pela aluna no cadastro (a ser confirmado pelo admin).
  final String? planoId;

  /// Nível de progressão da aluna.
  final NivelAluna? nivel;

  /// Indica que a aluna deve atualizar e-mail e senha no primeiro acesso.
  final bool primeiroAcesso;

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
    this.planoId,
    this.nivel,
    this.primeiroAcesso = false,
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
      dataCadastro: _parseDateTime(mapa['dataCadastro'] ?? mapa['criadoEm']),
      ativo: mapa['ativo'] as bool? ?? true,
      fotoUrl: mapa['fotoUrl'] as String?,
      atualizadoEm: _parseDateTimeOptional(mapa['atualizadoEm']),
      // Defaults to 'aprovado' for backward compatibility with existing users
      statusCadastro: mapa['statusCadastro'] as String? ?? 'aprovado',
      dataAprovacao: _parseDateTimeOptional(mapa['dataAprovacao']),
      aprovadoPor: mapa['aprovadoPor'] as String?,
      motivoRejeicao: mapa['motivoRejeicao'] as String?,
      planoId: mapa['planoId'] as String?,
      nivel: NivelAluna.fromValor(mapa['nivel'] as String?),
      primeiroAcesso: mapa['primeiroAcesso'] as bool? ?? false,
    );
  }

  factory Usuario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
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
      'planoId': planoId,
      'nivel': nivel?.valor,
      'primeiroAcesso': primeiroAcesso,
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
    String? planoId,
    NivelAluna? nivel,
    bool? primeiroAcesso,
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
      planoId: planoId ?? this.planoId,
      nivel: nivel ?? this.nivel,
      primeiroAcesso: primeiroAcesso ?? this.primeiroAcesso,
    );
  }
}
