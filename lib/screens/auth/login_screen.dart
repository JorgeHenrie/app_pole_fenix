import 'package:flutter/material.dart';

/// Tela de login do app.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: const Center(child: Text('Tela de Login')),
    );
  }
}
