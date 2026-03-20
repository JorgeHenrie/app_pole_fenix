import 'package:flutter/material.dart';

/// Widget exibido quando uma lista está vazia.
class EmptyState extends StatelessWidget {
  final String mensagem;
  final IconData icone;

  const EmptyState({
    super.key,
    required this.mensagem,
    this.icone = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icone, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            mensagem,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
