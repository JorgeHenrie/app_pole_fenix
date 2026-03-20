import 'package:flutter/material.dart';
import '../../models/evento.dart';
import '../../core/utils/date_formatter.dart';

/// Card com informações resumidas de um evento.
class EventoCard extends StatelessWidget {
  final Evento evento;
  final VoidCallback? onTap;

  const EventoCard({super.key, required this.evento, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.event),
        title: Text(evento.titulo),
        subtitle: Text(DateFormatter.dataHora(evento.dataHora)),
        trailing: evento.local != null
            ? const Icon(Icons.location_on_outlined)
            : null,
      ),
    );
  }
}
