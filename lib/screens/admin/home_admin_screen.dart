import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/usuario_repository.dart';

/// Tela inicial do administrador.
class HomeAdminScreen extends StatefulWidget {
  const HomeAdminScreen({super.key});

  @override
  State<HomeAdminScreen> createState() => _HomeAdminScreenState();
}

class _HomeAdminScreenState extends State<HomeAdminScreen> {
  final UsuarioRepository _usuarioRepo = UsuarioRepository();
  int _pendentesCount = 0;

  @override
  void initState() {
    super.initState();
    _carregarPendentes();
  }

  Future<void> _carregarPendentes() async {
    try {
      final pendentes = await _usuarioRepo.buscarPendentes();
      if (mounted) {
        setState(() => _pendentesCount = pendentes.length);
      }
    } catch (_) {}
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
            color: const Color(0xFFE65100),
            rota: Routes.aprovarCadastros,
            badge: _pendentesCount,
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
          _buildMenuCard(
            context,
            icon: Icons.credit_card,
            title: 'Gerenciar Planos',
            subtitle: 'Criar e editar planos de assinatura',
            color: const Color(0xFF2E7D32),
            rota: Routes.gerenciarPlanos,
          ),
          _buildMenuCard(
            context,
            icon: Icons.table_chart,
            title: 'Importar Alunas da Planilha',
            subtitle: 'Importação única dos dados do Excel',
            color: const Color(0xFF37474F),
            rota: Routes.importarAlunas,
          ),
          _buildSincronizarCard(context),
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

  Widget _buildSincronizarCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red.shade50,
      child: ListTile(
        onTap: () async {
          final confirmado = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Corrigir alunas excluídas'),
              content: const Text(
                'Isso irá bloquear o acesso ao app de todas as alunas que '
                'foram excluídas, desativar os horários fixos delas e '
                'cancelar suas assinaturas ativas.\n\n'
                'Deseja continuar?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Corrigir'),
                ),
              ],
            ),
          );
          if (confirmado != true || !context.mounted) return;

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const Center(child: CircularProgressIndicator()),
          );

          try {
            final fn =
                FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                    .httpsCallable('sincronizarInativas');
            final result = await fn.call();
            final corrigidas = result.data['corrigidas'] as int? ?? 0;

            if (context.mounted) {
              Navigator.of(context).pop(); // fecha loading
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content:
                      Text('$corrigidas aluna(s) corrigida(s) com sucesso.'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erro: $e')),
              );
            }
          }
        },
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.sync_problem, color: Colors.red),
        ),
        title: const Text('Corrigir Alunas Excluídas',
            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
        subtitle: const Text('Bloqueia acesso e libera horários das inativas',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right),
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
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () async {
          await Navigator.pushNamed(context, rota);
          // Atualiza o contador ao voltar da tela de aprovações
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
        subtitle: Text(subtitle,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
            const Icon(Icons.chevron_right, color: AppColors.grey),
          ],
        ),
      ),
    );
  }
}
