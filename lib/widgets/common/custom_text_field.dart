import 'package:flutter/material.dart';

/// Campo de texto personalizado com validação integrada.
class CustomTextField extends StatelessWidget {
  final String rotulo;
  final String? dica;
  final TextEditingController? controller;
  final String? Function(String?)? validador;
  final bool obscureText;
  final TextInputType tipoTeclado;
  final Widget? sufixo;

  const CustomTextField({
    super.key,
    required this.rotulo,
    this.dica,
    this.controller,
    this.validador,
    this.obscureText = false,
    this.tipoTeclado = TextInputType.text,
    this.sufixo,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: tipoTeclado,
      validator: validador,
      decoration: InputDecoration(
        labelText: rotulo,
        hintText: dica,
        suffixIcon: sufixo,
      ),
    );
  }
}
