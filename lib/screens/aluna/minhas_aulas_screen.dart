import 'package:flutter/material.dart';

/// Tela com as aulas agendadas da aluna.
class MinhasAulasScreen extends StatelessWidget {
  const MinhasAulasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Aulas')),
      body: const Center(child: Text('Tela de Minhas Aulas')),
    );
  }
}
