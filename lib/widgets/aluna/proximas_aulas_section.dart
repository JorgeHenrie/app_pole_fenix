import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/aula.dart';

/// Seção de próximas aulas na tela inicial da aluna.
class ProximasAulasSection extends StatelessWidget {
  final List<Aula> aulas;

  const ProximasAulasSection({super.key, required this.aulas});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Próximas Aulas',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, Routes.minhasAulas),
                child: const Text('Ver todas'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (aulas.isEmpty)
            _buildEmptyState(context)
          else
            ...aulas.map((aula) => _AulaItemCard(aula: aula)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Você não tem aulas agendadas',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.pushNamed(context, Routes.meusHorarios),
            icon: const Icon(Icons.schedule, size: 18),
            label: const Text('Meus Horários'),
          ),
        ],
      ),
    );
  }
}

class _AulaItemCard extends StatelessWidget {
  final Aula aula;

  const _AulaItemCard({required this.aula});

  @override
  Widget build(BuildContext context) {
    final isHoje = _isHoje(aula.dataHora);
    final isAmanha = _isAmanha(aula.dataHora);

    String diaLabel;
    Color diaColor;
    if (isHoje) {
      diaLabel = 'HOJE';
      diaColor = AppColors.secondary;
    } else if (isAmanha) {
      diaLabel = 'AMANHÃ';
      diaColor = AppColors.primary;
    } else {
      diaLabel = DateFormatter.data(aula.dataHora);
      diaColor = AppColors.textSecondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Coluna de data/hora
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormatter.hora(aula.dataHora),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    diaLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: diaColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Informações da aula
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aula.titulo ?? aula.modalidade,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (aula.instrutora != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          aula.instrutora!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (aula.duracaoMinutos != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${aula.duracaoMinutos} min',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Badge de status
            _buildStatusBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        'Confirmada',
        style: TextStyle(
          color: Colors.green.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  bool _isHoje(DateTime data) {
    final agora = DateTime.now();
    return data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;
  }

  bool _isAmanha(DateTime data) {
    final amanha = DateTime.now().add(const Duration(days: 1));
    return data.year == amanha.year &&
        data.month == amanha.month &&
        data.day == amanha.day;
  }
}
