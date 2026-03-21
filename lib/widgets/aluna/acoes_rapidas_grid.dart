import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/home_aluna_provider.dart';

/// Grade de ações rápidas na tela inicial da aluna.
class AcoesRapidasGrid extends StatelessWidget {
  const AcoesRapidasGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final temPlano =
        context.watch<HomeAlunaProvider>().assinatura != null;

    final acoes = [
      if (!temPlano)
        _AcaoRapida(
          icone: Icons.add_card,
          rotulo: 'Contratar Plano',
          cor: AppColors.success,
          rota: Routes.contratarPlano,
        ),
      _AcaoRapida(
        icone: Icons.schedule,
        rotulo: 'Meus Horários',
        cor: AppColors.primary,
        rota: Routes.meusHorarios,
      ),
      _AcaoRapida(
        icone: Icons.fitness_center,
        rotulo: 'Minhas Aulas',
        cor: AppColors.secondary,
        rota: Routes.minhasAulas,
      ),
      _AcaoRapida(
        icone: Icons.credit_card,
        rotulo: 'Meu Plano',
        cor: const Color(0xFF7B1FA2),
        rota: Routes.meuPlano,
      ),
      _AcaoRapida(
        icone: Icons.celebration_outlined,
        rotulo: 'Eventos',
        cor: const Color(0xFFE91E63),
        rota: Routes.eventos,
      ),
      _AcaoRapida(
        icone: Icons.person_outline,
        rotulo: 'Perfil',
        cor: const Color(0xFF00897B),
        rota: Routes.perfil,
      ),
      _AcaoRapida(
        icone: Icons.refresh,
        rotulo: 'Reposições',
        cor: const Color(0xFF1565C0),
        rota: Routes.minhasReposicoes,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ações Rápidas',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.0,
            ),
            itemCount: acoes.length,
            itemBuilder: (context, index) =>
                _AcaoRapidaButton(acao: acoes[index]),
          ),
        ],
      ),
    );
  }
}

class _AcaoRapida {
  final IconData icone;
  final String rotulo;
  final Color cor;
  final String rota;

  const _AcaoRapida({
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.rota,
  });
}

class _AcaoRapidaButton extends StatelessWidget {
  final _AcaoRapida acao;

  const _AcaoRapidaButton({required this.acao});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, acao.rota),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: acao.cor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: acao.cor.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: acao.cor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(acao.icone, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              acao.rotulo,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: acao.cor.withValues(alpha: 0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
