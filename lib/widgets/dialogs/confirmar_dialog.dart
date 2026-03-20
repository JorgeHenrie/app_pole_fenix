import 'package:flutter/material.dart';

/// Diálogo de confirmação genérico.
class ConfirmarDialog extends StatelessWidget {
  final String titulo;
  final String mensagem;
  final String textoBotaoConfirmar;
  final VoidCallback onConfirmar;

  const ConfirmarDialog({
    super.key,
    required this.titulo,
    required this.mensagem,
    this.textoBotaoConfirmar = 'Confirmar',
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(titulo),
      content: Text(mensagem),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirmar();
          },
          child: Text(textoBotaoConfirmar),
        ),
      ],
    );
  }

  /// Exibe o diálogo de confirmação.
  static Future<void> mostrar({
    required BuildContext context,
    required String titulo,
    required String mensagem,
    String textoBotaoConfirmar = 'Confirmar',
    required VoidCallback onConfirmar,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ConfirmarDialog(
        titulo: titulo,
        mensagem: mensagem,
        textoBotaoConfirmar: textoBotaoConfirmar,
        onConfirmar: onConfirmar,
      ),
    );
  }
}
