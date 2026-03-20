import 'package:flutter/material.dart';
import '../../models/usuario.dart';
import '../../core/utils/helpers.dart';

/// Card com informações resumidas de uma aluna.
class AlunaCard extends StatelessWidget {
  final Usuario aluna;
  final VoidCallback? onTap;

  const AlunaCard({super.key, required this.aluna, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Text(Helpers.iniciais(aluna.nome)),
        ),
        title: Text(aluna.nome),
        subtitle: Text(aluna.email),
      ),
    );
  }
}
