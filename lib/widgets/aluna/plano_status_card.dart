import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/assinatura.dart';
import '../../models/plano.dart';
import '../../core/utils/date_formatter.dart';

/// Card de status do plano/créditos da aluna.
class PlanoStatusCard extends StatelessWidget {
  final Assinatura? assinatura;
  final Plano? plano;

  const PlanoStatusCard({
    super.key,
    required this.assinatura,
    required this.plano,
  });

  @override
  Widget build(BuildContext context) {
    if (assinatura == null) {
      return _buildSemPlano(context);
    }

    return _buildComPlano(context);
  }

  Widget _buildSemPlano(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.credit_card_off_outlined,
                    color: Colors.white, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Sem plano ativo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Você não possui um plano ativo no momento.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Entre em contato com o estúdio para ativar seu plano.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComPlano(BuildContext context) {
    final assinaturaAtual = assinatura!;
    final diasParaRenovacao =
        assinaturaAtual.dataRenovacao.difference(DateTime.now()).inDays;
    final creditosBaixos = assinaturaAtual.creditosDisponiveis < 3;
    final proximoVencimento = diasParaRenovacao <= 7 && diasParaRenovacao >= 0;
    final vencida = diasParaRenovacao < 0;

    Color cardColor;
    Color cardColorEnd;
    if (vencida) {
      cardColor = const Color(0xFFC62828);
      cardColorEnd = AppColors.error;
    } else if (proximoVencimento || creditosBaixos) {
      cardColor = const Color(0xFFE65100);
      cardColorEnd = AppColors.warning;
    } else {
      cardColor = AppColors.primaryDark;
      cardColorEnd = AppColors.primary;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColorEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: cardColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_membership,
                        color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      plano?.nome ?? 'Meu Plano',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                _buildStatusBadge(vencida, proximoVencimento),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem(
                  context,
                  icon: Icons.fitness_center,
                  label: 'Créditos',
                  value: '${assinaturaAtual.creditosDisponiveis}',
                  alerta: creditosBaixos,
                ),
                _buildInfoItem(
                  context,
                  icon: Icons.calendar_today,
                  label: 'Renovação',
                  value: DateFormatter.data(assinaturaAtual.dataRenovacao),
                  alerta: proximoVencimento || vencida,
                ),
                if (plano != null)
                  _buildInfoItem(
                    context,
                    icon: Icons.star_outline,
                    label: 'Aulas/mês',
                    value: '${plano!.aulasPorMes}',
                  ),
              ],
            ),
            if (vencida || proximoVencimento || creditosBaixos) ...[
              const SizedBox(height: 12),
              _buildAlertMessage(
                  context, vencida, proximoVencimento, creditosBaixos),
            ],
            if (vencida || proximoVencimento) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.meuPlano),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(vencida ? 'Renovar agora' : 'Renovar plano'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
            if (creditosBaixos && !vencida && !proximoVencimento) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.meuPlano),
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Comprar mais créditos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool vencida, bool proximoVencimento) {
    String texto;
    Color cor;
    if (vencida) {
      texto = 'Vencido';
      cor = Colors.red.shade200;
    } else if (proximoVencimento) {
      texto = 'Vence em breve';
      cor = Colors.orange.shade200;
    } else {
      texto = 'Ativo';
      cor = Colors.green.shade200;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: cor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool alerta = false,
  }) {
    return Column(
      children: [
        Icon(icon, color: alerta ? Colors.yellow : Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: alerta ? Colors.yellow : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAlertMessage(
    BuildContext context,
    bool vencida,
    bool proximoVencimento,
    bool creditosBaixos,
  ) {
    String mensagem;
    if (vencida) {
      mensagem = '⚠️ Seu plano está vencido. Renove para continuar agendando.';
    } else if (proximoVencimento) {
      final dias = assinatura!.dataRenovacao.difference(DateTime.now()).inDays;
      mensagem =
          '⏰ Seu plano vence em $dias dia(s). Renove para não perder o acesso às aulas.';
    } else {
      mensagem =
          '🔶 Seus créditos estão baixos (${assinatura!.creditosDisponiveis} restantes).';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mensagem,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}
