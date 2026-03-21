import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/plano.dart';
import '../../providers/plano_provider.dart';
import '../../widgets/cards/plano_card.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela de listagem dos planos disponíveis para contratação.
class ContratarPlanoScreen extends StatefulWidget {
  const ContratarPlanoScreen({super.key});

  @override
  State<ContratarPlanoScreen> createState() => _ContratarPlanoScreenState();
}

class _ContratarPlanoScreenState extends State<ContratarPlanoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlanoProvider>().carregarPlanos();
    });
  }

  void _selecionarPlano(Plano plano) {
    Navigator.pushNamed(
      context,
      Routes.selecionarHorarios,
      arguments: plano,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PlanoProvider>(
      builder: (context, planoProvider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(title: const Text('Escolha seu Plano')),
          body: planoProvider.carregando
              ? const LoadingIndicator()
              : planoProvider.erro != null
                  ? _buildErroState(planoProvider)
                  : _buildContent(planoProvider),
        );
      },
    );
  }

  Widget _buildContent(PlanoProvider planoProvider) {
    if (planoProvider.planos.isEmpty) {
      return const Center(
        child: Text('Nenhum plano disponível no momento.'),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Escolha o plano ideal para você',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Text(
              'Horários fixos semanais, aulas agendadas automaticamente.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: planoProvider.planos.length,
            itemBuilder: (context, index) {
              final plano = planoProvider.planos[index];
              return PlanoCard(
                plano: plano,
                onSelecionar: () => _selecionarPlano(plano),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErroState(PlanoProvider planoProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline,
                size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              planoProvider.erro!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () =>
                  context.read<PlanoProvider>().carregarPlanos(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
