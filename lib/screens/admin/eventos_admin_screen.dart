import 'package:flutter/material.dart';

/// Tela de gerenciamento de eventos (admin).
class EventosAdminScreen extends StatelessWidget {
  const EventosAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gerenciar Eventos')),
      body: const Center(child: Text('Tela de Gerenciamento de Eventos')),
    );
  }
}
