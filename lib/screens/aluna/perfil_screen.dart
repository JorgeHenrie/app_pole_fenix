import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/helpers.dart';
import '../../models/assinatura.dart';
import '../../models/plano.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela de perfil da aluna com info pessoais, plano e timeline.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = context.read<HomeAlunaProvider>();
      if (homeProvider.assinatura == null && !homeProvider.carregando) {
        final usuario = context.read<AuthProvider>().usuario;
        if (usuario != null) homeProvider.carregarDados(usuario.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer2<AuthProvider, HomeAlunaProvider>(
        builder: (context, authProvider, homeProvider, _) {
          final usuario = authProvider.usuario;
          if (homeProvider.carregando || usuario == null) {
            return const LoadingIndicator();
          }
          return CustomScrollView(
            slivers: [
              _buildAppBar(context, usuario),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _InfoPessoalCard(usuario: usuario),
                      const SizedBox(height: 16),
                      if (homeProvider.assinatura != null &&
                          homeProvider.plano != null)
                        _PlanoCard(
                          assinatura: homeProvider.assinatura!,
                          plano: homeProvider.plano!,
                        ),
                      const SizedBox(height: 24),
                      _TimelineSection(
                        usuario: usuario,
                        assinatura: homeProvider.assinatura,
                        plano: homeProvider.plano,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, Usuario usuario) {
    final iniciais = Helpers.iniciais(usuario.nome);
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryDark, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.secondary,
                  backgroundImage: usuario.fotoUrl != null
                      ? NetworkImage(usuario.fotoUrl!)
                      : null,
                  child: usuario.fotoUrl == null
                      ? Text(
                          iniciais,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  usuario.nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Membro desde ${DateFormatter.mesAno(usuario.dataCadastro)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
      title: const Text(
        'Meu Perfil',
        style: TextStyle(color: Colors.white),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Card de informações pessoais
// ────────────────────────────────────────────────────────────
class _InfoPessoalCard extends StatelessWidget {
  final Usuario usuario;
  const _InfoPessoalCard({required this.usuario});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_outline,
                    color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Informações Pessoais',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const Divider(height: 20),
            _InfoRow(
              icone: Icons.badge_outlined,
              label: 'Nome',
              valor: usuario.nome,
            ),
            _InfoRow(
              icone: Icons.email_outlined,
              label: 'E-mail',
              valor: usuario.email,
            ),
            if (usuario.telefone != null && usuario.telefone!.isNotEmpty)
              _InfoRow(
                icone: Icons.phone_outlined,
                label: 'Telefone',
                valor: usuario.telefone!,
              ),
            _InfoRow(
              icone: Icons.calendar_today_outlined,
              label: 'Membro desde',
              valor: DateFormatter.data(usuario.dataCadastro),
            ),
            _InfoRow(
              icone: Icons.verified_outlined,
              label: 'Status',
              valor: _statusLabel(usuario.statusCadastro),
              corValor: _statusColor(usuario.statusCadastro),
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String s) => switch (s) {
        'aprovado' => 'Aprovada',
        'pendente' => 'Pendente',
        _ => 'Rejeitada',
      };

  Color _statusColor(String s) => switch (s) {
        'aprovado' => AppColors.success,
        'pendente' => AppColors.warning,
        _ => AppColors.error,
      };
}

class _InfoRow extends StatelessWidget {
  final IconData icone;
  final String label;
  final String valor;
  final Color? corValor;
  final bool isLast;

  const _InfoRow({
    required this.icone,
    required this.label,
    required this.valor,
    this.corValor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: corValor ?? AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Card do plano atual
// ────────────────────────────────────────────────────────────
class _PlanoCard extends StatelessWidget {
  final Assinatura assinatura;
  final Plano plano;
  const _PlanoCard({required this.assinatura, required this.plano});

  @override
  Widget build(BuildContext context) {
    final ativa = assinatura.estaAtiva;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ativa
              ? [
                  const Color(0xFF7B1FA2),
                  const Color(0xFFAB47BC),
                ]
              : [Colors.grey.shade600, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.workspace_premium,
                    color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    plano.nome,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    ativa ? 'ATIVO' : assinatura.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _PlanoStat(
                    label: 'Créditos',
                    valor: '${assinatura.creditosDisponiveis}'),
                _PlanoStat(
                    label: 'Realizadas',
                    valor: '${assinatura.aulasRealizadas}'),
                _PlanoStat(
                    label: 'Renovação',
                    valor: DateFormatter.data(assinatura.dataRenovacao)
                        .substring(0, 5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanoStat extends StatelessWidget {
  final String label;
  final String valor;
  const _PlanoStat({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// Timeline da jornada da aluna
// ────────────────────────────────────────────────────────────
class _TimelineSection extends StatelessWidget {
  final Usuario usuario;
  final Assinatura? assinatura;
  final Plano? plano;

  const _TimelineSection({
    required this.usuario,
    this.assinatura,
    this.plano,
  });

  List<_TimelineEvent> _buildEvents() {
    final events = <_TimelineEvent>[];

    events.add(_TimelineEvent(
      icone: Icons.star_rounded,
      cor: AppColors.secondary,
      titulo: 'Bem-vinda ao Fênix!',
      subtitulo: 'Cadastro realizado',
      data: DateFormatter.data(usuario.dataCadastro),
    ));

    if (usuario.dataAprovacao != null) {
      events.add(_TimelineEvent(
        icone: Icons.verified_rounded,
        cor: AppColors.success,
        titulo: 'Cadastro aprovado',
        subtitulo: 'Conta ativada pela admin',
        data: DateFormatter.data(usuario.dataAprovacao!),
      ));
    }

    if (assinatura != null && plano != null) {
      events.add(_TimelineEvent(
        icone: Icons.workspace_premium_rounded,
        cor: const Color(0xFF7B1FA2),
        titulo: 'Plano contratado',
        subtitulo: plano!.nome,
        data: DateFormatter.data(assinatura!.dataInicio),
      ));

      final realizadas = assinatura!.aulasRealizadas;
      if (realizadas >= 1) {
        events.add(_TimelineEvent(
          icone: Icons.fitness_center_rounded,
          cor: AppColors.primary,
          titulo: 'Primeira aula!',
          subtitulo: 'Parabéns pelo início da jornada',
          data: '',
        ));
      }
      if (realizadas >= 10) {
        events.add(_TimelineEvent(
          icone: Icons.emoji_events_rounded,
          cor: const Color(0xFFF57F17),
          titulo: '10 aulas concluídas 🎉',
          subtitulo: 'Você está arrasei!',
          data: '',
        ));
      }
      if (realizadas >= 25) {
        events.add(_TimelineEvent(
          icone: Icons.local_fire_department_rounded,
          cor: AppColors.error,
          titulo: '25 aulas concluídas 🔥',
          subtitulo: 'Dedicação total!',
          data: '',
        ));
      }
      if (realizadas >= 50) {
        events.add(_TimelineEvent(
          icone: Icons.military_tech_rounded,
          cor: AppColors.secondary,
          titulo: '50 aulas — Rainha do Pole! 👑',
          subtitulo: 'Conquista incrível!',
          data: '',
        ));
      }
    }

    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _buildEvents();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sua Jornada',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...events.asMap().entries.map(
              (e) => _TimelineItem(
                event: e.value,
                isLast: e.key == events.length - 1,
              ),
            ),
      ],
    );
  }
}

class _TimelineEvent {
  final IconData icone;
  final Color cor;
  final String titulo;
  final String subtitulo;
  final String data;

  const _TimelineEvent({
    required this.icone,
    required this.cor,
    required this.titulo,
    required this.subtitulo,
    required this.data,
  });
}

class _TimelineItem extends StatelessWidget {
  final _TimelineEvent event;
  final bool isLast;

  const _TimelineItem({required this.event, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha + ícone
          SizedBox(
            width: 48,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: event.cor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: event.cor.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: Icon(event.icone, color: event.cor, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            event.cor.withValues(alpha: 0.4),
                            event.cor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    event.titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (event.data.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.data,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
