import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/date_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notificacao_provider.dart';

/// Tela de notificações da aluna.
class NotificacoesScreen extends StatelessWidget {
  const NotificacoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          Consumer<NotificacaoProvider>(
            builder: (context, notificacaoProvider, _) {
              if (notificacaoProvider.naoLidas == 0) {
                return const SizedBox.shrink();
              }

              return TextButton(
                onPressed: notificacaoProvider.marcarTodasComoLidas,
                child: const Text('Marcar todas'),
              );
            },
          ),
        ],
      ),
      body:
          usuario == null ? const SizedBox.shrink() : const _NotificacoesList(),
    );
  }
}

class _NotificacoesList extends StatelessWidget {
  const _NotificacoesList();

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificacaoProvider>(
      builder: (context, notificacaoProvider, _) {
        if (notificacaoProvider.carregando) {
          return const Center(child: CircularProgressIndicator());
        }

        final notificacoes = notificacaoProvider.notificacoes;
        if (notificacoes.isEmpty) {
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

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: notificacoes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final notificacao = notificacoes[index];
            final cor = _corPorTipo(notificacao.tipo);

            return Card(
              elevation: notificacao.lida ? 0 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: notificacao.lida
                      ? Colors.grey.shade200
                      : cor.withValues(alpha: 0.3),
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: notificacao.lida
                    ? null
                    : () => notificacaoProvider.marcarComoLida(notificacao.id),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            Icon(_iconePorTipo(notificacao.tipo), color: cor),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notificacao.titulo,
                                    style: TextStyle(
                                      fontWeight: notificacao.lida
                                          ? FontWeight.w600
                                          : FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (!notificacao.lida)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: cor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              notificacao.mensagem,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              DateFormatter.dataHora(notificacao.criadaEm),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  IconData _iconePorTipo(String tipo) {
    switch (tipo) {
      case 'cadastro_pendente':
        return Icons.person_add_alt_1_outlined;
      case 'migracao_plano_pendente':
        return Icons.swap_horiz_rounded;
      case 'migracao_plano_status':
        return Icons.credit_score_outlined;
      case 'cancelamento_tardio':
      case 'aula_cancelada':
      case 'lembrete_aula':
        return Icons.event_note_outlined;
      case 'renovacao_plano':
        return Icons.credit_card_outlined;
      case 'cadastro_status':
        return Icons.verified_user_outlined;
      case 'atestado':
        return Icons.medical_services_outlined;
      case 'horario':
        return Icons.schedule_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _corPorTipo(String tipo) {
    switch (tipo) {
      case 'cadastro_pendente':
        return Colors.deepOrange.shade700;
      case 'migracao_plano_pendente':
        return AppColors.warning;
      case 'migracao_plano_status':
        return AppColors.success;
      case 'cancelamento_tardio':
      case 'aula_cancelada':
        return AppColors.error;
      case 'lembrete_aula':
      case 'horario':
        return AppColors.primary;
      case 'renovacao_plano':
        return Colors.orange.shade700;
      case 'cadastro_status':
        return Colors.green.shade700;
      case 'atestado':
        return Colors.teal.shade700;
      default:
        return AppColors.textSecondary;
    }
  }
}
