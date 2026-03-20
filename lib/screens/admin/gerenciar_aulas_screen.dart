import 'package:flutter/material.dart';

/// Tela de gerenciamento de aulas (admin).
class GerenciarAulasScreen extends StatelessWidget {
  const GerenciarAulasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Aulas')),
      body: const Center(child: Text('Tela de Gerenciamento de Aulas')),
    );
  }
}
