import 'package:flutter/material.dart';

/// Tela para agendamento de aula.
class AgendarAulaScreen extends StatelessWidget {
  const AgendarAulaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar Aula')),
      body: const Center(child: Text('Tela de Agendamento de Aula')),
    );
  }
}
