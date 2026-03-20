import 'package:flutter/material.dart';

/// Tela de perfil da aluna.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: const Center(child: Text('Tela de Perfil')),
    );
  }
}
