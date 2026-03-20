import 'package:flutter/material.dart';
import '../../models/aula.dart';
import '../../core/utils/date_formatter.dart';

/// Card com informações resumidas de uma aula.
class AulaCard extends StatelessWidget {
  final Aula aula;
  final VoidCallback? onTap;

  const AulaCard({super.key, required this.aula, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.fitness_center),
        title: Text(aula.titulo),
        subtitle: Text(DateFormatter.dataHora(aula.dataHora)),
        trailing: Text(
          '${aula.vagasDisponiveis} vaga(s)',
          style: TextStyle(
            color: aula.temVaga ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
