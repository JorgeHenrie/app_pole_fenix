import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/grade_horario.dart';

/// Card de seleção de horário com status de vagas.
class HorarioSelecaoCard extends StatelessWidget {
  final GradeHorario gradeHorario;
  final int vagasOcupadas;
  final bool selecionado;
  final VoidCallback onTap;

  const HorarioSelecaoCard({
    super.key,
    required this.gradeHorario,
    required this.vagasOcupadas,
    required this.selecionado,
    required this.onTap,
  });

  int get vagasDisponiveis => gradeHorario.capacidadeMaxima - vagasOcupadas;
  bool get lotado => vagasDisponiveis <= 0;

  Color get _corVagas {
    if (lotado) return AppColors.error;
    if (vagasOcupadas == 0) return AppColors.success;
    return AppColors.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: selecionado ? AppColors.primary.withValues(alpha: 0.08) : null,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: selecionado
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Checkbox(
          value: selecionado,
          onChanged: lotado ? null : (_) => onTap(),
          activeColor: AppColors.primary,
        ),
        title: Text(
          '${gradeHorario.horario} — ${gradeHorario.modalidade}',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: lotado ? AppColors.textSecondary : AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '$vagasOcupadas/${gradeHorario.capacidadeMaxima} vagas ocupadas',
          style: TextStyle(fontSize: 12, color: _corVagas),
        ),
        trailing: lotado
            ? Chip(
                label: const Text(
                  'LOTADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: AppColors.error,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              )
            : null,
        enabled: !lotado,
        onTap: lotado ? null : onTap,
      ),
    );
  }
}
