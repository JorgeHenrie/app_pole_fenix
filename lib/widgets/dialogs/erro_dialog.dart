import 'package:flutter/material.dart';

/// Diálogo de exibição de erros ao usuário.
class ErroDialog extends StatelessWidget {
  final String titulo;
  final String mensagem;

  const ErroDialog({
    super.key,
    this.titulo = 'Erro',
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Text(titulo),
        ],
      ),
      content: Text(mensagem),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    );
  }

  /// Exibe o diálogo de erro.
  static Future<void> mostrar({
    required BuildContext context,
    String titulo = 'Erro',
    required String mensagem,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ErroDialog(titulo: titulo, mensagem: mensagem),
    );
  }
}
