import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/notificacao.dart';
import '../../providers/auth_provider.dart';

/// Tela de notificações da aluna.
class NotificacoesScreen extends StatelessWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
      ),
      body: usuario == null
          ? const SizedBox.shrink()
          : _NotificacoesList(alunaId: usuario.id),
    );
  }
}

class _NotificacoesList extends StatelessWidget {
  final String alunaId;
  const _NotificacoesList({required this.alunaId});

  @override
  Widget build(BuildContext context) {
    // Placeholder — substituir por stream/provider de notificações futuramente.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 72,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          const Text(
            'Nenhuma notificação por enquanto.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
