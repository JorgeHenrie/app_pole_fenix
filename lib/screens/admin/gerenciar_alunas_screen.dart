import 'package:flutter/material.dart';

/// Tela de gerenciamento de alunas (admin).
class GerenciarAlunasScreen extends StatelessWidget {
  const GerenciarAlunasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Alunas')),
      body: const Center(child: Text('Tela de Gerenciamento de Alunas')),
    );
  }
}
