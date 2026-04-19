import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/grade_horario.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

const _filtroTodasInstrutoras = 'Todas';

class AgendaAdminScreen extends StatefulWidget {
  const AgendaAdminScreen({super.key});

  @override
  State<AgendaAdminScreen> createState() => _AgendaAdminScreenState();
}

class _AgendaAdminScreenState extends State<AgendaAdminScreen> {
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();

  late DateTime _diaSelecionado;
  late DateTime _inicioSemana;
  List<_AgendaAdminItem> _itens = [];
  bool _carregando = false;
  String? _erro;
  String _instrutoraSelecionada = _filtroTodasInstrutoras;
  bool _filtroInicialAplicado = false;

  @override
  void initState() {
    super.initState();
    final hoje = _inicioDoDia(DateTime.now());
    _diaSelecionado = hoje;
    _inicioSemana = _calcularInicioSemana(hoje);
    _carregarAgenda();
  }

  Future<void> _carregarAgenda() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final grade = await _gradeRepo.listarAtivos();
      final gradeDoDia = grade
          .where((item) => item.diaSemana == _diaSelecionado.weekday)
          .toList()
        ..sort((a, b) => _minutosInicio(a.horario).compareTo(
              _minutosInicio(b.horario),
            ));

      final itens = await Future.wait(
        gradeDoDia.map(_montarItemAgenda),
      );

      final instrutoras = _instrutorasDisponiveis(itens);
      final adminNome = context.read<AuthProvider>().usuario?.nome ?? '';
      var filtro = _instrutoraSelecionada;

      if (!_filtroInicialAplicado) {
        final sugerida = _sugerirFiltroInstrutora(adminNome, instrutoras);
        if (sugerida != null) {
          filtro = sugerida;
        }
        _filtroInicialAplicado = true;
      }

      if (filtro != _filtroTodasInstrutoras && !instrutoras.contains(filtro)) {
        filtro = _filtroTodasInstrutoras;
      }

      if (!mounted) return;
      setState(() {
        _itens = itens;
        _instrutoraSelecionada = filtro;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Nao foi possivel carregar a agenda agora. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<_AgendaAdminItem> _montarItemAgenda(GradeHorario grade) async {
    final dataHora = _dataHoraDoSlot(grade);
    final resultados = await Future.wait([
      _gradeRepo.buscarNomesFixosPorSlot(grade.diaSemana, grade.horario),
      _gradeRepo.buscarNomesReposicoesPorSlot(grade.id, dataHora),
    ]);

    final alunas = [
      ...resultados[0],
      ...resultados[1],
    ]
        .map((nome) => nome.trim())
        .where((nome) => nome.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return _AgendaAdminItem(
      grade: grade,
      dataHora: dataHora,
      alunas: alunas,
    );
  }

  List<String> _instrutorasDisponiveis(List<_AgendaAdminItem> itens) {
    return itens
        .map((item) => item.grade.instrutora?.trim())
        .whereType<String>()
        .where((nome) => nome.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  String? _sugerirFiltroInstrutora(String adminNome, List<String> instrutoras) {
    if (adminNome.trim().isEmpty || instrutoras.isEmpty) return null;

    final nomeCompleto = adminNome.trim().toLowerCase();
    final primeiroNome = nomeCompleto.split(' ').first;

    for (final instrutora in instrutoras) {
      final base = instrutora.toLowerCase();
      if (base == nomeCompleto || base.contains(primeiroNome)) {
        return instrutora;
      }
    }

    return null;
  }

  void _selecionarDia(DateTime dia) {
    setState(() => _diaSelecionado = _inicioDoDia(dia));
    _carregarAgenda();
  }

  void _irParaSemanaAnterior() {
    final novoDia = _diaSelecionado.subtract(const Duration(days: 7));
    setState(() {
      _diaSelecionado = novoDia;
      _inicioSemana = _calcularInicioSemana(novoDia);
    });
    _carregarAgenda();
  }

  void _irParaProximaSemana() {
    final novoDia = _diaSelecionado.add(const Duration(days: 7));
    setState(() {
      _diaSelecionado = novoDia;
      _inicioSemana = _calcularInicioSemana(novoDia);
    });
    _carregarAgenda();
  }

  void _abrirDetalhe(_AgendaAdminItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DetalheAulaSheet(item: item),
    );
  }

  DateTime _dataHoraDoSlot(GradeHorario grade) {
    final horario = _extrairHoraMinuto(grade.horario);
    return DateTime(
      _diaSelecionado.year,
      _diaSelecionado.month,
      _diaSelecionado.day,
      horario.$1,
      horario.$2,
    );
  }

  DateTime _inicioDoDia(DateTime data) {
    return DateTime(data.year, data.month, data.day);
  }

  DateTime _calcularInicioSemana(DateTime data) {
    return DateTime(data.year, data.month, data.day - (data.weekday - 1));
  }

  int _minutosInicio(String horario) {
    final base = _extrairHoraMinuto(horario);
    return base.$1 * 60 + base.$2;
  }

  (int, int) _extrairHoraMinuto(String horario) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(horario);
    if (match == null) return (0, 0);
    return (
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semana = List.generate(
      7,
      (index) => _inicioSemana.add(Duration(days: index)),
    );
    final instrutoras = _instrutorasDisponiveis(_itens);
    final itensFiltrados = _instrutoraSelecionada == _filtroTodasInstrutoras
        ? _itens
        : _itens
            .where((item) => item.grade.instrutora == _instrutoraSelecionada)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Agenda do Dia'),
        actions: [
          IconButton(
            onPressed: _carregarAgenda,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregarAgenda,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _SemanaSelector(
                    dias: semana,
                    diaSelecionado: _diaSelecionado,
                    onAnterior: _irParaSemanaAnterior,
                    onProxima: _irParaProximaSemana,
                    onSelecionar: _selecionarDia,
                  ),
                  if (instrutoras.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Filtrar por instrutora',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _filtroTodasInstrutoras,
                        ...instrutoras,
                      ].map((instrutora) {
                        return FilterChip(
                          selected: _instrutoraSelecionada == instrutora,
                          label: Text(instrutora),
                          onSelected: (_) {
                            setState(() => _instrutoraSelecionada = instrutora);
                          },
                          selectedColor:
                              AppColors.primaryLight.withValues(alpha: 0.28),
                          checkmarkColor: AppColors.primary,
                          side: BorderSide(
                            color: _instrutoraSelecionada == instrutora
                                ? AppColors.primary
                                : AppColors.greyLight,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  const SizedBox(height: 18),
                  if (_erro != null)
                    _AgendaInfoCard(
                      icon: Icons.wifi_tethering_error_rounded,
                      title: 'Nao foi possivel carregar a agenda',
                      message: _erro!,
                    )
                  else if (_itens.isEmpty)
                    const _AgendaInfoCard(
                      icon: Icons.event_busy_outlined,
                      title: 'Nenhuma aula prevista neste dia',
                      message:
                          'Quando houver horarios ativos para este dia da semana, eles aparecerao aqui com as alunas confirmadas.',
                    )
                  else if (itensFiltrados.isEmpty)
                    _AgendaInfoCard(
                      icon: Icons.filter_alt_off_rounded,
                      title: 'Nenhuma aula para este filtro',
                      message:
                          'Nao ha aulas de $_instrutoraSelecionada nesta data. Troque o filtro para visualizar as demais turmas.',
                    )
                  else ...[
                    Text(
                      'Aulas confirmadas (${itensFiltrados.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toque em uma aula para ver a lista completa de participantes de forma ampliada.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...itensFiltrados.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AulaAgendaCard(
                          item: item,
                          onTap: () => _abrirDetalhe(item),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _AgendaAdminItem {
  final GradeHorario grade;
  final DateTime dataHora;
  final List<String> alunas;

  const _AgendaAdminItem({
    required this.grade,
    required this.dataHora,
    required this.alunas,
  });

  int get ocupacao => alunas.length;
  bool get lotada => ocupacao >= grade.capacidadeMaxima;

  _AgendaStatus get status {
    final agora = DateTime.now();
    final fim = dataHora.add(
      const Duration(minutes: AppConstants.duracaoAulaPadrao),
    );

    if (fim.isBefore(agora)) return _AgendaStatus.encerrada;
    if (!dataHora.isAfter(agora) && fim.isAfter(agora)) {
      return _AgendaStatus.emAndamento;
    }
    return _AgendaStatus.proxima;
  }
}

enum _AgendaStatus { proxima, emAndamento, encerrada }

class _SemanaNavigationButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;

  const _SemanaNavigationButton({
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _SemanaSelector extends StatelessWidget {
  final List<DateTime> dias;
  final DateTime diaSelecionado;
  final VoidCallback onAnterior;
  final VoidCallback onProxima;
  final ValueChanged<DateTime> onSelecionar;

  const _SemanaSelector({
    required this.dias,
    required this.diaSelecionado,
    required this.onAnterior,
    required this.onProxima,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final tituloMes = Helpers.capitalizar(
      DateFormat("MMMM 'de' yyyy", 'pt_BR').format(diaSelecionado),
    );
    final tituloDia = Helpers.capitalizar(
      DateFormat("EEEE, dd 'de' MMMM", 'pt_BR').format(diaSelecionado),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SemanaNavigationButton(
                onPressed: onAnterior,
                icon: Icons.chevron_left_rounded,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      tituloMes,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tituloDia,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _SemanaNavigationButton(
                onPressed: onProxima,
                icon: Icons.chevron_right_rounded,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dias.map((dia) {
                  final selecionado = _mesmoDia(dia, diaSelecionado);
                  final hoje = _mesmoDia(dia, DateTime.now());
                  final rotuloDia = DateFormat('EEE', 'pt_BR')
                      .format(dia)
                      .replaceAll('.', '')
                      .toUpperCase();

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => onSelecionar(dia),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        width: 54,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? AppColors.primary
                              : hoje
                                  ? AppColors.primaryLight
                                      .withValues(alpha: 0.24)
                                  : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selecionado
                                ? AppColors.primaryDark.withValues(alpha: 0.28)
                                : hoje
                                    ? AppColors.primaryLight
                                        .withValues(alpha: 0.56)
                                    : AppColors.greyLight,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              rotuloDia,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: selecionado
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${dia.day}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: selecionado
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selecionado
                                    ? Colors.white
                                    : hoje
                                        ? AppColors.primary
                                        : Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static bool _mesmoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AgendaInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _AgendaInfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(icon, size: 56, color: AppColors.primaryLight),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AulaAgendaCard extends StatelessWidget {
  final _AgendaAdminItem item;
  final VoidCallback onTap;

  const _AulaAgendaCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = _statusVisual(item.status);
    final corBorda = item.lotada ? AppColors.warning : AppColors.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: corBorda.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 74,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    children: [
                      Text(
                        DateFormat('HH:mm').format(item.dataHora),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.grade.horario,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.grade.modalidade,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (item.grade.instrutora?.trim().isNotEmpty ==
                                    true) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Instrutora: ${item.grade.instrutora}',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaBadge(
                            icon: Icons.people_outline_rounded,
                            label:
                                '${item.ocupacao}/${item.grade.capacidadeMaxima} confirmadas',
                            color: item.lotada
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                          _MetaBadge(
                            icon: Icons.event_seat_outlined,
                            label: item.lotada
                                ? 'Turma lotada'
                                : '${item.grade.capacidadeMaxima - item.ocupacao} vaga(s)',
                            color: item.lotada
                                ? AppColors.warning
                                : AppColors.info,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _StatusVisual _statusVisual(_AgendaStatus status) {
    switch (status) {
      case _AgendaStatus.emAndamento:
        return const _StatusVisual(
          label: 'Em andamento',
          color: AppColors.success,
        );
      case _AgendaStatus.encerrada:
        return const _StatusVisual(
          label: 'Encerrada',
          color: AppColors.textSecondary,
        );
      case _AgendaStatus.proxima:
        return const _StatusVisual(
          label: 'Proxima',
          color: AppColors.primary,
        );
    }
  }
}

class _StatusVisual {
  final String label;
  final Color color;

  const _StatusVisual({required this.label, required this.color});
}

class _StatusBadge extends StatelessWidget {
  final _StatusVisual status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlunoChip extends StatelessWidget {
  final String nome;

  const _AlunoChip({required this.nome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              Helpers.iniciais(nome),
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            nome,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetalheAulaSheet extends StatelessWidget {
  final _AgendaAdminItem item;

  const _DetalheAulaSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = switch (item.status) {
      _AgendaStatus.proxima => 'Proxima aula do dia',
      _AgendaStatus.emAndamento => 'Aula em andamento',
      _AgendaStatus.encerrada => 'Aula encerrada',
    };

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  '${item.grade.modalidade} • ${item.grade.horario}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                if (item.grade.instrutora?.trim().isNotEmpty == true)
                  Text(
                    'Instrutora: ${item.grade.instrutora}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaBadge(
                      icon: Icons.schedule_rounded,
                      label: DateFormat('dd/MM HH:mm').format(item.dataHora),
                      color: AppColors.primary,
                    ),
                    _MetaBadge(
                      icon: Icons.info_outline_rounded,
                      label: status,
                      color: AppColors.secondary,
                    ),
                    _MetaBadge(
                      icon: Icons.people_outline_rounded,
                      label:
                          '${item.ocupacao}/${item.grade.capacidadeMaxima} alunas',
                      color:
                          item.lotada ? AppColors.warning : AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Participantes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                ),
                const SizedBox(height: 10),
                if (item.alunas.isEmpty)
                  const Text(
                    'Nenhuma aluna confirmada para esta aula.',
                    style: TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: item.alunas.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final nome = item.alunas[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary,
                            child: Text(
                              Helpers.iniciais(nome),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            nome,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text('Confirmada na turma'),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
