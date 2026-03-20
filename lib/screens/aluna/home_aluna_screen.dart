import 'package:flutter/material.dart';

/// Tela inicial da aluna.
class HomeAlunaScreen extends StatelessWidget {
  const HomeAlunaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: const Center(child: Text('Home da Aluna')),
    );
  }
}
