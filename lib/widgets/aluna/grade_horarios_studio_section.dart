import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/reposicao.dart';
import '../../providers/auth_provider.dart';
import '../../providers/grade_horario_provider.dart';

/// Seção de calendário de horários do estúdio na tela inicial da aluna.
/// Mostra seletor de semana + lista de slots do dia selecionado (estilo agenda).
class GradeHorariosStudioSection extends StatefulWidget {
  const GradeHorariosStudioSection({super.key});

  @override
  State<GradeHorariosStudioSection> createState() =>
      _GradeHorariosStudioSectionState();
}

class _GradeHorariosStudioSectionState
    extends State<GradeHorariosStudioSection> {
  DateTime _diaSelecionado = DateTime.now();
  late DateTime _inicioSemanaBase;

  static const int _limiteHome = 3;
  static const int _paginaInicial = 10000;
  int _pageAtual = _paginaInicial;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _inicioSemanaBase = _calcularInicioSemana(DateTime.now());
    _pageController = PageController(initialPage: _paginaInicial);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Segunda-feira da semana que contém [data].
  DateTime _calcularInicioSemana(DateTime data) {
    final diff = data.weekday - 1; // weekday: 1=segunda ... 7=domingo
    return DateTime(data.year, data.month, data.day - diff);
  }

  void _semanaAnterior() {
    _pageController.animateToPage(
      _pageAtual - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _proximaSemana() {
    _pageController.animateToPage(
      _pageAtual + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int page) {
    final offset = page - _paginaInicial;
    final novoInicio = _inicioSemanaBase.add(Duration(days: offset * 7));
    setState(() {
      _pageAtual = page;
      _diaSelecionado =
          novoInicio.add(Duration(days: _diaSelecionado.weekday - 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, GradeHorarioProvider>(
      builder: (context, authProvider, gradeProvider, _) {
        final nomeAluna = authProvider.usuario?.nome ?? '';

        // Slots do dia selecionado
        final slotsDoDia = gradeProvider.slots.where((s) {
          return s.dataHora.year == _diaSelecionado.year &&
              s.dataHora.month == _diaSelecionado.month &&
              s.dataHora.day == _diaSelecionado.day;
        }).toList()
          ..sort((a, b) => a.dataHora.compareTo(b.dataHora));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Banner reposição pendente ──────────────────────────
            if (gradeProvider.temReposicaoPendente)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _BannerReposicao(
                  quantidade: gradeProvider.reposicoesPendentes.length,
                  expiraEm: gradeProvider.reposicoesPendentes
                      .map((r) => r.expiraEm)
                      .whereType<DateTime>()
                      .fold<DateTime?>(null,
                          (min, d) => min == null || d.isBefore(min) ? d : min),
                ),
              ),

            // ── Cabeçalho calendário (mês + setas) ────────────────
            Container(
              color: AppColors.surface,
              child: Column(
                children: [
                  // Mês e navegação
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _semanaAnterior,
                          color: AppColors.primary,
                        ),
                        Column(
                          children: [
                            Text(
                              DateFormat('MMMM', 'pt_BR')
                                  .format(_diaSelecionado)
                                  .toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    letterSpacing: 1,
                                  ),
                            ),
                            Text(
                              _diaSelecionado.year.toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _proximaSemana,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  // Faixa de dias da semana (PageView para swipe nativo)
                  SizedBox(
                    height: 72,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: _onPageChanged,
                      itemBuilder: (context, page) {
                        final offset = page - _paginaInicial;
                        final inicioSemana =
                            _inicioSemanaBase.add(Duration(days: offset * 7));
                        final dias = List.generate(
                            7, (i) => inicioSemana.add(Duration(days: i)));
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: dias.map((dia) {
                              final eHoje = _eHoje(dia);
                              final diaPassado = _diaJaPassou(dia);
                              final eSelecionado =
                                  _mesmoDia(dia, _diaSelecionado);
                              final temSlot = gradeProvider.slots.any((s) =>
                                  s.dataHora.year == dia.year &&
                                  s.dataHora.month == dia.month &&
                                  s.dataHora.day == dia.day);

                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _diaSelecionado = dia),
                                child: Container(
                                  width: 42,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: eSelecionado
                                        ? AppColors.primary
                                        : diaPassado
                                            ? Colors.grey
                                                .withValues(alpha: 0.08)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        _abrevDia(dia.weekday),
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: eSelecionado
                                              ? Colors.white
                                              : diaPassado
                                                  ? AppColors.grey
                                                  : AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        dia.day.toString(),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: eSelecionado
                                              ? Colors.white
                                              : eHoje
                                                  ? AppColors.primary
                                                  : diaPassado
                                                      ? AppColors.grey
                                                      : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: temSlot
                                              ? (eSelecionado
                                                  ? Colors.white
                                                      .withValues(alpha: 0.8)
                                                  : diaPassado
                                                      ? AppColors.grey
                                                          .withValues(
                                                              alpha: 0.5)
                                                      : AppColors.secondary)
                                              : Colors.transparent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 8),
                  const Divider(height: 1),
                ],
              ),
            ),

            // ── Label do dia selecionado + botão Ver todos ────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _labelDia(_diaSelecionado),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  if (slotsDoDia.isNotEmpty)
                    TextButton(
                      onPressed: () => _abrirTodosDoDia(
                        context,
                        gradeProvider,
                        slotsDoDia,
                        nomeAluna,
                        authProvider.usuario?.id ?? '',
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        'Ver todos',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Corpo: loading / vazio / lista ────────────────────
            if (gradeProvider.carregando && gradeProvider.slots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (gradeProvider.erro != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _CardErro(mensagem: gradeProvider.erro!),
              )
            else if (slotsDoDia.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _CardSemAula(),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _Timeline(
                  slots: slotsDoDia.take(_limiteHome).toList(),
                  nomeAluna: nomeAluna,
                  podeAgendar: gradeProvider.podeAgendar,
                  reposicaoParaSlot: gradeProvider.reposicaoParaSlot,
                  alunaInscrita: gradeProvider.alunaEstaInscrita,
                  onAgendar: (slot, rep) => _confirmarAgendamento(
                    context,
                    gradeProvider,
                    slot,
                    rep,
                    nomeAluna,
                  ),
                  onCancelar: (slot) => _confirmarCancelamento(
                    context,
                    gradeProvider,
                    slot,
                    authProvider.usuario?.id ?? '',
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmarCancelamento(
    BuildContext context,
    GradeHorarioProvider gradeProvider,
    SlotDia slot,
    String alunaId,
  ) async {
    final dentroDoPrazo = slot.dataHora.difference(DateTime.now()).inHours >= 2;
    final ehReposicaoAgendada =
        gradeProvider.slotTemReposicaoAgendadaDaAluna(slot);
    final hora = DateFormat('HH:mm').format(slot.dataHora);
    final df = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar aula'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icone: Icons.calendar_today,
              texto: _capitalize(df.format(slot.dataHora)),
            ),
            const SizedBox(height: 6),
            _InfoRow(icone: Icons.access_time, texto: hora),
            const SizedBox(height: 6),
            _InfoRow(
                icone: Icons.fitness_center,
                texto: slot.gradeHorario.modalidade),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dentroDoPrazo
                          ? (ehReposicaoAgendada
                              ? 'Você poderá cancelar esta reposição e reagendá-la em outro horário disponível.'
                              : 'Você poderá remarcar esta aula em outro horário disponível.')
                          : (ehReposicaoAgendada
                              ? 'Cancelamentos com menos de 2 horas farão você perder esta reposição.'
                              : 'Cancelamentos com menos de 2 horas não geram reposição.'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.cancel_outlined, size: 16),
            label: const Text('Confirmar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    final resultado = await gradeProvider.cancelarAulaECriarReposicao(
      slot: slot,
      alunaId: alunaId,
      motivo: 'Cancelamento solicitado pela aluna',
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultado.erro ??
              resultado.mensagemSucesso ??
              (resultado.criouReposicao
                  ? 'Aula cancelada! A reposição ficou disponível até o fim do ciclo do seu plano.'
                  : 'Aula cancelada. Você perdeu o crédito desta aula.'),
        ),
        backgroundColor: resultado.erro != null
            ? AppColors.error
            : (resultado.criouReposicao
                ? AppColors.success
                : AppColors.warning),
      ),
    );
  }

  Future<void> _confirmarAgendamento(
    BuildContext context,
    GradeHorarioProvider gradeProvider,
    SlotDia slot,
    Reposicao reposicao,
    String nomeAluna,
  ) async {
    if (_aulaJaComecou(slot.dataHora)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Essa aula ja foi realizada.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (!_podeEntrarNaAula(slot.dataHora)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('O agendamento encerra no horário de início da aula.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final df = DateFormat("EEEE, dd 'de' MMMM", 'pt_BR');
    final hora = DateFormat('HH:mm').format(slot.dataHora);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agendar reposição'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoRow(
              icone: Icons.calendar_today,
              texto: _capitalize(df.format(slot.dataHora)),
            ),
            const SizedBox(height: 6),
            _InfoRow(icone: Icons.access_time, texto: hora),
            const SizedBox(height: 6),
            _InfoRow(
              icone: Icons.fitness_center,
              texto: slot.gradeHorario.modalidade,
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icone: Icons.people_outline,
              texto:
                  '${slot.vagasDisponiveis} vaga${slot.vagasDisponiveis == 1 ? '' : 's'} disponível',
            ),
            if (slot.vagasDisponiveis == 1) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Última vaga disponível!',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !context.mounted) return;

    final sucesso = await gradeProvider.agendarReposicao(
      reposicao: reposicao,
      slot: slot,
      nomeAluna: nomeAluna,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sucesso
            ? 'Reposição agendada para $hora!'
            : 'Erro ao agendar. Tente novamente.'),
        backgroundColor: sucesso ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _abrirTodosDoDia(
    BuildContext context,
    GradeHorarioProvider gradeProvider,
    List<SlotDia> todos,
    String nomeAluna,
    String alunaId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheetTodosDoDia(
        dia: _diaSelecionado,
        slots: todos,
        nomeAluna: nomeAluna,
        podeAgendar: gradeProvider.podeAgendar,
        reposicaoParaSlot: gradeProvider.reposicaoParaSlot,
        alunaInscrita: gradeProvider.alunaEstaInscrita,
        onAgendar: (slot, rep) {
          Navigator.pop(context);
          _confirmarAgendamento(context, gradeProvider, slot, rep, nomeAluna);
        },
        onCancelar: (slot) {
          Navigator.pop(context);
          _confirmarCancelamento(context, gradeProvider, slot, alunaId);
        },
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  static bool _eHoje(DateTime d) {
    final agora = DateTime.now();
    return d.year == agora.year && d.month == agora.month && d.day == agora.day;
  }

  static bool _diaJaPassou(DateTime d) {
    final hoje = DateTime.now();
    final data = DateTime(d.year, d.month, d.day);
    final baseHoje = DateTime(hoje.year, hoje.month, hoje.day);
    return data.isBefore(baseHoje);
  }

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _abrevDia(int weekday) {
    const nomes = {
      1: 'SEG',
      2: 'TER',
      3: 'QUA',
      4: 'QUI',
      5: 'SEX',
      6: 'SÁB',
      7: 'DOM',
    };
    return nomes[weekday] ?? '';
  }

  String _labelDia(DateTime d) {
    if (_eHoje(d)) {
      return 'Hoje · ${DateFormat("dd 'de' MMMM", 'pt_BR').format(d)}';
    }
    final amanha = DateTime.now().add(const Duration(days: 1));
    if (_mesmoDia(d, amanha)) {
      return 'Amanhã · ${DateFormat("dd 'de' MMMM", 'pt_BR').format(d)}';
    }
    return _capitalize(DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(d));
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Timeline de slots do dia ─────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final List<SlotDia> slots;
  final String nomeAluna;
  final bool Function(SlotDia) podeAgendar;
  final Reposicao? Function(SlotDia) reposicaoParaSlot;
  final void Function(SlotDia, Reposicao) onAgendar;
  final bool Function(SlotDia) alunaInscrita;
  final void Function(SlotDia) onCancelar;

  const _Timeline({
    required this.slots,
    required this.nomeAluna,
    required this.podeAgendar,
    required this.reposicaoParaSlot,
    required this.onAgendar,
    required this.alunaInscrita,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < slots.length; i++) ...[
          _SlotTimeline(
            slot: slots[i],
            podeAgendar: podeAgendar(slots[i]),
            reposicao: reposicaoParaSlot(slots[i]),
            onAgendar: onAgendar,
            isLast: i == slots.length - 1,
            alunaInscrita: alunaInscrita(slots[i]),
            onCancelar: onCancelar,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SlotTimeline extends StatelessWidget {
  final SlotDia slot;
  final bool podeAgendar;
  final Reposicao? reposicao;
  final void Function(SlotDia, Reposicao) onAgendar;
  final bool isLast;
  final bool alunaInscrita;
  final void Function(SlotDia) onCancelar;

  const _SlotTimeline({
    required this.slot,
    required this.podeAgendar,
    required this.reposicao,
    required this.onAgendar,
    required this.isLast,
    required this.alunaInscrita,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final hora = DateFormat('HH:mm').format(slot.dataHora);
    final esgotado = !slot.temVaga;
    final aulaRealizada = _aulaJaComecou(slot.dataHora);

    // Cor do card baseada na modalidade (alterna entre variações)
    final corCard = aulaRealizada
        ? Colors.grey.shade100
        : esgotado
            ? Colors.grey.shade200
            : (slot.gradeHorario.diaSemana % 2 == 0
                ? AppColors.primaryLight.withValues(alpha: 0.15)
                : AppColors.secondary.withValues(alpha: 0.12));

    final corAccent = aulaRealizada
        ? AppColors.grey
        : esgotado
            ? Colors.grey
            : (slot.gradeHorario.diaSemana % 2 == 0
                ? AppColors.primary
                : AppColors.secondary);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Coluna de hora + linha ──────────────────────────
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Text(
                  hora,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: aulaRealizada
                        ? AppColors.grey
                        : esgotado
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: isLast
                        ? const SizedBox.shrink()
                        : Container(
                            width: 1,
                            color: Colors.grey.shade300,
                          ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Ponto na linha do tempo ─────────────────────────
          Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: aulaRealizada
                      ? Colors.grey.shade400
                      : esgotado
                          ? Colors.grey.shade400
                          : corAccent,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),

          const SizedBox(width: 10),

          // ── Card do slot ────────────────────────────────────
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: corCard,
                borderRadius: BorderRadius.circular(12),
                border: Border(
                  left: BorderSide(color: corAccent, width: 4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome da modalidade e vagas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            slot.gradeHorario.modalidade,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: aulaRealizada
                                  ? AppColors.greyDark
                                  : esgotado
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (aulaRealizada)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.grey.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'REALIZADA',
                              style: TextStyle(
                                color: AppColors.greyDark,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (esgotado)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'LOTADO',
                              style: TextStyle(
                                color: AppColors.error,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Horário e duração
                    Text(
                      '$hora · ${slot.gradeHorario.horario}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Alunas e vagas
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14,
                            color: aulaRealizada
                                ? Colors.grey
                                : esgotado
                                    ? Colors.grey
                                    : AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          '${slot.ocupados}/${slot.gradeHorario.capacidadeMaxima}',
                          style: TextStyle(
                            fontSize: 12,
                            color: aulaRealizada
                                ? Colors.grey
                                : esgotado
                                    ? Colors.grey
                                    : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          aulaRealizada
                              ? 'Aula realizada'
                              : esgotado
                                  ? 'Sem vagas'
                                  : 'Restam ${slot.vagasDisponiveis} vaga${slot.vagasDisponiveis == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: aulaRealizada
                                ? AppColors.greyDark
                                : esgotado
                                    ? AppColors.error
                                    : slot.vagasDisponiveis == 1
                                        ? AppColors.warning
                                        : AppColors.success,
                          ),
                        ),
                      ],
                    ),

                    // Nomes das alunas matriculadas
                    if (slot.nomesMatriculados.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        slot.nomesMatriculados.join(' · '),
                        style: TextStyle(
                          fontSize: 11,
                          color: aulaRealizada
                              ? Colors.grey.shade600
                              : esgotado
                                  ? Colors.grey.shade500
                                  : corAccent.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],

                    // Botão de cancelar (aluna inscrita, aula não passou)
                    if (alunaInscrita && !aulaRealizada) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => onCancelar(slot),
                          icon: const Icon(Icons.cancel_outlined, size: 14),
                          label: const Text('Cancelar aula'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],

                    // Botão de agendar reposição
                    if (!aulaRealizada && podeAgendar && reposicao != null) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: ElevatedButton.icon(
                          onPressed: () => onAgendar(slot, reposicao!),
                          icon: const Icon(Icons.add_circle_outline, size: 14),
                          label: const Text('Agendar reposição'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: corAccent,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _BannerReposicao extends StatelessWidget {
  final int quantidade;
  final DateTime? expiraEm;

  const _BannerReposicao({required this.quantidade, this.expiraEm});

  @override
  Widget build(BuildContext context) {
    final prazo =
        expiraEm != null ? DateFormat('dd/MM/yyyy').format(expiraEm!) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quantidade == 1
                  ? 'Você tem 1 reposição pendente${prazo != null ? ' · até $prazo' : ''}'
                  : 'Você tem $quantidade reposições pendentes${prazo != null ? ' · até $prazo' : ''}',
              style: const TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSemAula extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.event_available_outlined,
              size: 40, color: Colors.grey.shade400),
          const SizedBox(height: 8),
          Text(
            'Nenhum horário neste dia',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _CardErro extends StatelessWidget {
  final String mensagem;
  const _CardErro({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icone;
  final String texto;
  const _InfoRow({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: const TextStyle(fontSize: 13))),
      ],
    );
  }
}

// ─── Bottom Sheet: todos os horários do dia ───────────────────────────────────

class _BottomSheetTodosDoDia extends StatelessWidget {
  final DateTime dia;
  final List<SlotDia> slots;
  final String nomeAluna;
  final bool Function(SlotDia) podeAgendar;
  final Reposicao? Function(SlotDia) reposicaoParaSlot;
  final bool Function(SlotDia) alunaInscrita;
  final void Function(SlotDia, Reposicao) onAgendar;
  final void Function(SlotDia) onCancelar;

  const _BottomSheetTodosDoDia({
    required this.dia,
    required this.slots,
    required this.nomeAluna,
    required this.podeAgendar,
    required this.reposicaoParaSlot,
    required this.alunaInscrita,
    required this.onAgendar,
    required this.onCancelar,
  });

  @override
  Widget build(BuildContext context) {
    final labelDia = _capitalize(
      DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(dia),
    );
    final total = slots.length;
    final diaPassado = DateTime(dia.year, dia.month, dia.day).isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Alça de arrastar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Título
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          labelDia,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          diaPassado
                              ? '$total aula${total == 1 ? '' : 's'} realizada${total == 1 ? '' : 's'} neste dia'
                              : '$total horário${total == 1 ? '' : 's'} disponível${total == 1 ? '' : 'is'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),

            const Divider(),

            // Lista rolável de todos os slots
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: slots.length,
                itemBuilder: (_, i) => _SlotTimeline(
                  slot: slots[i],
                  podeAgendar: podeAgendar(slots[i]),
                  reposicao: reposicaoParaSlot(slots[i]),
                  alunaInscrita: alunaInscrita(slots[i]),
                  onAgendar: onAgendar,
                  onCancelar: onCancelar,
                  isLast: i == slots.length - 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Retorna true a partir do horário de início da aula.
bool _aulaJaComecou(DateTime inicio) {
  return !DateTime.now().isBefore(inicio);
}

bool _podeEntrarNaAula(DateTime inicio) {
  // Permite agendar até o horário de início da aula.
  return DateTime.now().isBefore(inicio);
}
