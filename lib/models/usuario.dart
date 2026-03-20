/// Modelo que representa uma usuária (aluna ou administradora) do app.
class Usuario {
  final String id;
  final String nome;
  final String email;
  final String telefone;
  final String perfil; // 'aluna' ou 'admin'
  final String? fotoUrl;
  final DateTime criadoEm;
  final DateTime? atualizadoEm;

  const Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.perfil,
    this.fotoUrl,
    required this.criadoEm,
    this.atualizadoEm,
  });

  factory Usuario.fromMap(Map<String, dynamic> mapa, String id) {
    return Usuario(
      id: id,
      nome: mapa['nome'] as String,
      email: mapa['email'] as String,
      telefone: mapa['telefone'] as String,
      perfil: mapa['perfil'] as String,
      fotoUrl: mapa['fotoUrl'] as String?,
      criadoEm: DateTime.parse(mapa['criadoEm'] as String),
      atualizadoEm: mapa['atualizadoEm'] != null
          ? DateTime.parse(mapa['atualizadoEm'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'email': email,
      'telefone': telefone,
      'perfil': perfil,
      'fotoUrl': fotoUrl,
      'criadoEm': criadoEm.toIso8601String(),
      'atualizadoEm': atualizadoEm?.toIso8601String(),
    };
  }

  Usuario copyWith({
    String? nome,
    String? email,
    String? telefone,
    String? perfil,
    String? fotoUrl,
    DateTime? atualizadoEm,
  }) {
    return Usuario(
      id: id,
      nome: nome ?? this.nome,
      email: email ?? this.email,
      telefone: telefone ?? this.telefone,
      perfil: perfil ?? this.perfil,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm ?? this.atualizadoEm,
    );
  }
}
