import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grade_horario_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../widgets/aluna/aluna_drawer.dart';
import '../../widgets/aluna/eventos_section.dart';
import '../../widgets/aluna/grade_horarios_studio_section.dart';
import '../../widgets/aluna/plano_status_card.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/notificacao_action_button.dart';

/// Tela inicial da aluna com dashboard completo.
class HomeAlunaScreen extends StatefulWidget {
  const HomeAlunaScreen({super.key});

  @override
  State<HomeAlunaScreen> createState() => _HomeAlunaScreenState();
}

class _HomeAlunaScreenState extends State<HomeAlunaScreen> {
  bool _dadosCarregados = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final usuario = context.watch<AuthProvider>().usuario;
    if (usuario != null && !_dadosCarregados) {
      _dadosCarregados = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final homeProvider = context.read<HomeAlunaProvider>();
        final gradeProvider = context.read<GradeHorarioProvider>();
        await homeProvider.carregarDados(usuario.id);
        if (mounted) {
          gradeProvider.carregar(
            usuario.id,
            assinatura: homeProvider.assinatura,
          );
        }
      });
    }
  }

  Future<void> _carregarDados() async {
    final authProvider = context.read<AuthProvider>();
    final homeProvider = context.read<HomeAlunaProvider>();
    final gradeProvider = context.read<GradeHorarioProvider>();
    final usuario = authProvider.usuario;
    if (usuario != null) {
      await homeProvider.carregarDados(usuario.id);
      if (mounted) {
        gradeProvider.carregar(usuario.id, assinatura: homeProvider.assinatura);
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

        return Scaffold(
          backgroundColor: AppColors.background,
          drawer: const AlunaDrawer(),
          appBar: AppBar(
            title: Text('Olá, $primeiroNome 👋'),
            actions: [
              const NotificacaoActionButton(),
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
                            // Grade de horários do estúdio
                            const GradeHorariosStudioSection(),
                            const SizedBox(height: 24),
                            // Eventos próximos
                            EventosSection(
                              eventos: homeProvider.proximosEventos,
                            ),
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
