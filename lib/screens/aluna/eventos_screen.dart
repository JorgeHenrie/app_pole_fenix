import 'package:flutter/material.dart';

/// Tela de eventos do estúdio para a aluna.
class EventosScreen extends StatelessWidget {
  const EventosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventos')),
      body: const Center(child: Text('Tela de Eventos')),
    );
  }
}
