import 'package:flutter/material.dart';

/// Tela de controle de pagamentos (admin).
class PagamentosScreen extends StatelessWidget {
  const PagamentosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamentos')),
      body: const Center(child: Text('Tela de Pagamentos')),
    );
  }
}
