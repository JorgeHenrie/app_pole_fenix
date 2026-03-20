import 'package:flutter/material.dart';

/// Tela de recuperação de senha.
class RecuperarSenhaScreen extends StatelessWidget {
  const RecuperarSenhaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar Senha')),
      body: const Center(child: Text('Tela de Recuperação de Senha')),
    );
  }
}
