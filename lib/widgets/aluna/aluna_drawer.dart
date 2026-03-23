import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_aluna_provider.dart';

/// Drawer lateral com navegação rápida da aluna.
class AlunaDrawer extends StatelessWidget {
  const AlunaDrawer({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Deseja realmente sair do aplicativo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, HomeAlunaProvider>(
      builder: (context, authProvider, homeProvider, _) {
        final usuario = authProvider.usuario;
        final nomeAluna = usuario?.nome ?? 'Aluna';
        final iniciais = Helpers.iniciais(nomeAluna);
        final temPlano = homeProvider.assinatura != null;

        return Drawer(
          child: Column(
            children: [
              // Cabeçalho com dados do perfil
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                ),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  backgroundImage: usuario?.fotoUrl != null
                      ? NetworkImage(usuario!.fotoUrl!)
                      : null,
                  child: usuario?.fotoUrl == null
                      ? Text(
                          iniciais,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        )
                      : null,
                ),
                accountName: Text(
                  nomeAluna,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                accountEmail: Text(
                  usuario?.email ?? '',
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              // Itens de navegação
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (!temPlano)
                      _DrawerItem(
                        icone: Icons.add_card,
                        rotulo: 'Contratar Plano',
                        cor: AppColors.success,
                        rota: Routes.contratarPlano,
                      ),
                    _DrawerItem(
                      icone: Icons.schedule,
                      rotulo: 'Meus Horários',
                      cor: AppColors.primary,
                      rota: Routes.meusHorarios,
                    ),
                    _DrawerItem(
                      icone: Icons.fitness_center,
                      rotulo: 'Minhas Aulas',
                      cor: AppColors.secondary,
                      rota: Routes.minhasAulas,
                    ),
                    _DrawerItem(
                      icone: Icons.credit_card,
                      rotulo: 'Meu Plano',
                      cor: const Color(0xFF7B1FA2),
                      rota: Routes.meuPlano,
                    ),
                    _DrawerItem(
                      icone: Icons.celebration_outlined,
                      rotulo: 'Eventos',
                      cor: const Color(0xFFE91E63),
                      rota: Routes.eventos,
                    ),
                    _DrawerItem(
                      icone: Icons.person_outline,
                      rotulo: 'Meu Perfil',
                      cor: const Color(0xFF00897B),
                      rota: Routes.perfil,
                    ),
                    _DrawerItem(
                      icone: Icons.refresh,
                      rotulo: 'Reposições',
                      cor: const Color(0xFF1565C0),
                      rota: Routes.minhasReposicoes,
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Botão de sair
              ListTile(
                leading:
                    const Icon(Icons.logout_outlined, color: AppColors.error),
                title: const Text(
                  'Sair',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => _logout(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icone;
  final String rotulo;
  final Color cor;
  final String rota;

  const _DrawerItem({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.rota,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icone, color: cor, size: 20),
      ),
      title: Text(
        rotulo,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: () {
        Navigator.pop(context); // fecha o drawer
        Navigator.pushNamed(context, rota);
      },
    );
  }
}
