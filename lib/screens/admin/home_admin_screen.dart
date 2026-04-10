import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/usuario_repository.dart';
import '../../widgets/common/notificacao_action_button.dart';

/// Tela inicial do administrador.
class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  final UsuarioRepository _usuarioRepo = UsuarioRepository();
  int _pendentesCount = 0;
  bool _falhaAoCarregarPendentes = false;

  @override
  void initState() {
    super.initState();
    _carregarPendentes();
  }

  Future<void> _carregarPendentes() async {
    try {
      final pendentes = await _usuarioRepo.buscarPendentes();
      if (mounted) {
        setState(() {
          _pendentesCount = pendentes.length;
          _falhaAoCarregarPendentes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _falhaAoCarregarPendentes = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar cadastros pendentes: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;
    final nome = usuario?.nome.split(' ').first ?? 'Admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Painel Admin – $nome'),
        actions: [
          const NotificacaoActionButton(),
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
          _buildMenuCardComBadge(
            context,
            icon: Icons.person_add_alt_1,
            title: 'Aprovar Cadastros',
            subtitle: 'Aprovar ou rejeitar novas alunas',
            color: AppColors.accentCaramel,
            rota: Routes.aprovarCadastros,
            badge: _pendentesCount,
            mostrarAviso: _falhaAoCarregarPendentes,
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
            color: AppColors.secondaryDark,
            rota: Routes.visualizarOcupacao,
          ),
          _buildMenuCard(
            context,
            icon: Icons.credit_card,
            title: 'Gerenciar Planos',
            subtitle: 'Criar e editar planos de assinatura',
            color: AppColors.accentCocoa,
            rota: Routes.gerenciarPlanos,
          ),
          const SizedBox(height: 8),
          _buildSectionTitle(context, 'Gestão'),
          _buildMenuCard(
            context,
            icon: Icons.swap_horiz,
            title: 'Solicitacoes de Mudanca',
            subtitle: 'Responder pedidos de troca de horario',
            color: AppColors.primaryDark,
            rota: Routes.aprovarSolicitacoes,
          ),
          _buildMenuCard(
            context,
            icon: Icons.medical_information_outlined,
            title: 'Validar Atestados',
            subtitle: 'Aprovar ou rejeitar faltas com atestado',
            color: AppColors.accentSand,
            rota: Routes.validarAtestados,
          ),
          _buildMenuCard(
            context,
            icon: Icons.payment,
            title: 'Pagamentos',
            subtitle: 'Controle de pagamentos e assinaturas',
            color: AppColors.secondary,
            rota: Routes.pagamentos,
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
    return _buildMenuCardComBadge(
      context,
      icon: icon,
      title: title,
      subtitle: subtitle,
      color: color,
      rota: rota,
      badge: 0,
    );
  }

  Widget _buildMenuCardComBadge(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String rota,
    required int badge,
    bool mostrarAviso = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () async {
          await Navigator.pushNamed(context, rota);
          if (rota == Routes.aprovarCadastros) {
            _carregarPendentes();
          }
        },
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
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (mostrarAviso)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.sync_problem_rounded,
                  color: AppColors.warning,
                ),
              ),
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}
