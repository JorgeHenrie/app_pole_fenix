import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/usuario.dart';

/// Cache local mínimo para restaurar a última sessão autenticada do app.
class SessionCacheService {
  static const String _usuarioKey = 'sessao_usuario';

  Future<void> salvarUsuario(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    final dados = <String, dynamic>{
      'id': usuario.id,
      ...usuario.toMap(),
    };

    await prefs.setString(_usuarioKey, jsonEncode(dados));
  }

  Future<Usuario?> carregarUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    final bruto = prefs.getString(_usuarioKey);
    if (bruto == null || bruto.isEmpty) return null;

    try {
      final mapa = jsonDecode(bruto);
      if (mapa is! Map<String, dynamic>) {
        await prefs.remove(_usuarioKey);
        return null;
      }

      final id = mapa['id'] as String?;
      if (id == null || id.isEmpty) {
        await prefs.remove(_usuarioKey);
        return null;
      }

      final dados = Map<String, dynamic>.from(mapa)..remove('id');
      return Usuario.fromMap(dados, id);
    } catch (e) {
      debugPrint('SessionCacheService.carregarUsuario: $e');
      await prefs.remove(_usuarioKey);
      return null;
    }
  }

  Future<void> limparUsuario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usuarioKey);
  }
}
