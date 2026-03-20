import 'package:flutter/material.dart';

/// Botão personalizado reutilizável do app.
class CustomButton extends StatelessWidget {
  final String texto;
  final VoidCallback? onPressed;
  final bool carregando;
  final bool contornado;

  const CustomButton({
    super.key,
    required this.texto,
    this.onPressed,
    this.carregando = false,
    this.contornado = false,
  });

  @override
  Widget build(BuildContext context) {
    if (contornado) {
      return OutlinedButton(
        onPressed: carregando ? null : onPressed,
        child: _buildChild(),
      );
    }
    return ElevatedButton(
      onPressed: carregando ? null : onPressed,
      child: _buildChild(),
    );
  }

  Widget _buildChild() {
    if (carregando) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Text(texto);
  }
}
