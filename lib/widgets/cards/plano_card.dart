import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/plano.dart';
import '../common/custom_button.dart';

/// Card de exibição de plano na tela de contratação.
class PlanoCard extends StatelessWidget {
  final Plano plano;
  final VoidCallback onSelecionar;

  const PlanoCard({
    super.key,
    required this.plano,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Nome do plano
            Text(
              plano.nome,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Preço em destaque
            Text(
              'R\$ ${plano.preco.toStringAsFixed(2)}/mês',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Benefícios
            _buildBeneficio(
              context,
              Icons.fitness_center,
              '${plano.aulasPorMes} aulas por mês',
            ),
            const SizedBox(height: 6),
            _buildBeneficio(
              context,
              Icons.repeat,
              '${plano.aulasSemanais}x por semana',
            ),
            const SizedBox(height: 6),
            _buildBeneficio(
              context,
              Icons.calendar_today,
              '${plano.aulasSemanais} horário(s) fixo(s)',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                texto: 'Selecionar Plano',
                onPressed: onSelecionar,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBeneficio(BuildContext context, IconData icone, String texto) {
    return Row(
      children: [
        Icon(icone, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(texto, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
