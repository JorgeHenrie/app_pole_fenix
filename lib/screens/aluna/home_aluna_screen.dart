import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/jornada_movimento.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grade_horario_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../repositories/jornada_movimento_repository.dart';
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
        await homeProvider.carregarDados(
          usuario.id,
          tarefaParalela: (assinatura) => gradeProvider.carregar(
            usuario.id,
            assinatura: assinatura,
            nomeAluna: usuario.nome,
          ),
        );
      });
    }
  }

  Future<void> _carregarDados() async {
    final authProvider = context.read<AuthProvider>();
    final homeProvider = context.read<HomeAlunaProvider>();
    final gradeProvider = context.read<GradeHorarioProvider>();
    final usuario = authProvider.usuario;
    if (usuario != null) {
      await homeProvider.carregarDados(
        usuario.id,
        tarefaParalela: (assinatura) => gradeProvider.carregar(
          usuario.id,
          assinatura: assinatura,
          nomeAluna: usuario.nome,
        ),
      );
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
            title: Text('Olá, $primeiroNome'),
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
                              nivelAluna: usuario?.nivel,
                            ),
                            const SizedBox(height: 16),
                            if (usuario != null)
                              _MinhaJornadaPreviewCard(usuarioId: usuario.id),
                            const SizedBox(height: 24),
                            // Grade de horários do estúdio
                            const GradeHorariosStudioSection(),
                            if (AppConstants.muralEstudioHabilitado) ...[
                              const SizedBox(height: 24),
                              EventosSection(
                                eventos: homeProvider.proximosEventos,
                              ),
                            ],
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

class _MinhaJornadaPreviewCard extends StatelessWidget {
  final String usuarioId;

  const _MinhaJornadaPreviewCard({required this.usuarioId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<List<JornadaMovimento>>(
        future: JornadaMovimentoRepository().listarPorAluna(usuarioId),
        builder: (context, snapshot) {
          final jornada = snapshot.data ?? const <JornadaMovimento>[];
          final total = jornada.length;

          return InkWell(
            onTap: () => Navigator.pushNamed(context, Routes.minhaJornada),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primaryDark,
                          AppColors.accentCocoa,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.auto_graph_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Minha Jornada',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          total == 0
                              ? 'Acompanhe os movimentos que você já domina e registre sua evolução.'
                              : 'Você já conquistou $total movimento(s). Toque para ver sua evolução.',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
