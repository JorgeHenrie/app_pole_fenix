import 'package:flutter/material.dart';

/// Tela de cadastro de nova aluna.
class CadastroScreen extends StatelessWidget {
  const CadastroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar')),
      body: const Center(child: Text('Tela de Cadastro')),
    );
  }
}
