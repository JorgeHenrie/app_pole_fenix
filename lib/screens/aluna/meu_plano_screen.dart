import 'package:flutter/material.dart';

/// Tela com detalhes do plano da aluna.
class MeuPlanoScreen extends StatelessWidget {
  const MeuPlanoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meu Plano')),
      body: const Center(child: Text('Tela Meu Plano')),
    );
  }
}
