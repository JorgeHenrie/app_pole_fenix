import 'package:flutter/material.dart';

/// Tela de gerenciamento de horários (admin).
class GerenciarHorariosScreen extends StatelessWidget {
  const GerenciarHorariosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Horários')),
      body: const Center(child: Text('Tela de Gerenciamento de Horários')),
    );
  }
}
