import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../widgets/aluna/acoes_rapidas_grid.dart';
import '../../widgets/aluna/eventos_section.dart';
import '../../widgets/aluna/plano_status_card.dart';
import '../../widgets/aluna/proximas_aulas_section.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela inicial da aluna com dashboard completo.
class HomeAlunaScreen extends StatefulWidget {
  const HomeAlunaScreen({super.key});

  @override
  State<HomeAlunaScreen> createState() => _HomeAlunaScreenState();
}

class _HomeAlunaScreenState extends State<HomeAlunaScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
  }

  Future<void> _carregarDados() async {
    final authProvider = context.read<AuthProvider>();
    final homeProvider = context.read<HomeAlunaProvider>();
    final usuario = authProvider.usuario;
    if (usuario != null) {
      await homeProvider.carregarDados(usuario.id);
    }
  }

  Future<void> _logout() async {
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Sair'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
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
        final primeiroNome = nomeAluna.trim().split(' ').first;
        final iniciais = Helpers.iniciais(nomeAluna);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text('Olá, $primeiroNome 👋'),
            actions: [
              // Avatar
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => Navigator.pushNamed(context, Routes.perfil),
                  child: CircleAvatar(
                    radius: 18,
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
                              fontSize: 13,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              // Logout
              IconButton(
                icon: const Icon(Icons.logout_outlined),
                tooltip: 'Sair',
                onPressed: _logout,
              ),
            ],
          ),
          body: homeProvider.carregando
              ? const LoadingIndicator()
              : homeProvider.erro != null
                  ? _buildErroState(homeProvider)
                  : RefreshIndicator(
                      onRefresh: _carregarDados,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            // Status do plano
                            PlanoStatusCard(
                              assinatura: homeProvider.assinatura,
                              plano: homeProvider.plano,
                            ),
                            const SizedBox(height: 24),
                            // Próximas aulas
                            ProximasAulasSection(
                              aulas: homeProvider.proximasAulas,
                            ),
                            const SizedBox(height: 24),
                            // Eventos próximos
                            EventosSection(
                              eventos: homeProvider.proximosEventos,
                            ),
                            const SizedBox(height: 24),
                            // Ações rápidas
                            const AcoesRapidasGrid(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildErroState(HomeAlunaProvider homeProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              homeProvider.erro!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _carregarDados,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

}
