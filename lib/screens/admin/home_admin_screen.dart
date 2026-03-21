import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Tela inicial do administrador.
class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    final nome = usuario?.nome.split(' ').first ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Painel Admin – $nome'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            tooltip: 'Sair',
            onPressed: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(Routes.login);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, 'Horários e Agendamentos'),
          _buildMenuCard(
            context,
            icon: Icons.schedule,
            title: 'Gerenciar Grade de Horários',
            subtitle: 'Criar e editar horários do estúdio',
            color: AppColors.primary,
            rota: Routes.gerenciarHorarios,
          ),
          _buildMenuCard(
            context,
            icon: Icons.people,
            title: 'Gerenciar Alunas',
            subtitle: 'Ver alunas, horários fixos e assinaturas',
            color: AppColors.secondary,
            rota: Routes.gerenciarAlunas,
          ),
          _buildMenuCard(
            context,
            icon: Icons.bar_chart,
            title: 'Ocupação de Horários',
            subtitle: 'Ver alunas inscritas em cada horário',
            color: const Color(0xFF00695C),
            rota: Routes.visualizarOcupacao,
          ),
          _buildMenuCard(
            context,
            icon: Icons.swap_horiz,
            title: 'Aprovar Solicitações',
            subtitle: 'Aprovar mudanças de horário fixo',
            color: const Color(0xFF7B1FA2),
            rota: Routes.aprovarSolicitacoes,
          ),
          _buildMenuCard(
            context,
            icon: Icons.medical_services,
            title: 'Validar Atestados',
            subtitle: 'Validar atestados médicos de faltas',
            color: AppColors.warning,
            rota: Routes.validarAtestados,
          ),
          const SizedBox(height: 8),
          _buildSectionTitle(context, 'Gestão'),
          _buildMenuCard(
            context,
            icon: Icons.fitness_center,
            title: 'Gerenciar Aulas',
            subtitle: 'Ver e editar aulas agendadas',
            color: const Color(0xFF00897B),
            rota: Routes.gerenciarAulas,
          ),
          _buildMenuCard(
            context,
            icon: Icons.payment,
            title: 'Pagamentos',
            subtitle: 'Controle de pagamentos e assinaturas',
            color: const Color(0xFF1565C0),
            rota: Routes.pagamentos,
          ),
          _buildMenuCard(
            context,
            icon: Icons.celebration,
            title: 'Eventos',
            subtitle: 'Publicar e gerenciar eventos',
            color: const Color(0xFFE91E63),
            rota: Routes.eventosAdmin,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String titulo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        titulo,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String rota,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.pushNamed(context, rota),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
      ),
    );
  }
}
