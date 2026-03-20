import 'package:flutter/material.dart';

/// Tela inicial do administrador.
class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel Admin')),
      body: const Center(child: Text('Home do Administrador')),
    );
  }
}
