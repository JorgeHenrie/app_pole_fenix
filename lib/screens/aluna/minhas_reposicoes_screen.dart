import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/grade_horario.dart';
import '../../models/reposicao.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reposicao_provider.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class MinhasReposicoesScreen extends StatefulWidget {
  const MinhasReposicoesScreen({super.key});

  @override
  State<MinhasReposicoesScreen> createState() => _MinhasReposicoesScreenState();
}

class _MinhasReposicoesScreenState extends State<MinhasReposicoesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario != null) {
      await context.read<ReposicaoProvider>().carregarPorAluna(usuario.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Minhas Reposições'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Pendentes'),
            Tab(text: 'Agendadas'),
            Tab(text: 'Histórico'),
          ],
        ),
      ),
      body: Consumer<ReposicaoProvider>(
        builder: (context, provider, _) {
          if (provider.carregando) return const LoadingIndicator();
          return Column(
            children: [
              if (provider.quantidadePendentes > 0)
                _buildHeader(provider.quantidadePendentes),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLista(
                      provider.pendentes,
                      'Nenhuma reposição pendente',
                      Icons.check_circle_outline,
                      showAgendar: true,
                    ),
                    _buildLista(
                      provider.agendadas,
                      'Nenhuma reposição agendada',
                      Icons.event_available,
                    ),
                    _buildLista(
                      provider.historico,
                      'Nenhum histórico',
                      Icons.history,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int quantidade) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: AppColors.info.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.refresh, color: AppColors.info),
          const SizedBox(width: 12),
          Text(
            'Você tem $quantidade reposição(ões) disponível(is)',
            style: const TextStyle(
              color: AppColors.info,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLista(
    List<Reposicao> reposicoes,
    String mensagemVazio,
    IconData iconVazio, {
    bool showAgendar = false,
  }) {
    if (reposicoes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconVazio, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              mensagemVazio,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reposicoes.length,
        itemBuilder: (context, index) => _ReposicaoCard(
          reposicao: reposicoes[index],
          showAgendar: showAgendar,
          onAgendar: showAgendar
              ? () => _mostrarAgendarReposicao(reposicoes[index])
              : null,
        ),
      ),
    );
  }

  Future<void> _mostrarAgendarReposicao(Reposicao reposicao) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AgendarReposicaoSheet(
        reposicao: reposicao,
        onConfirmar: (dataHora, horarioId) async {
          final ok = await context.read<ReposicaoProvider>().agendarReposicao(
                reposicao.id,
                dataHora,
                horarioId,
              );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok ? 'Reposição agendada!' : 'Erro ao agendar.'),
                backgroundColor: ok ? Colors.green : Colors.red,
              ),
            );
          }
        },
      ),
    );
  }
}

class _ReposicaoCard extends StatelessWidget {
  final Reposicao reposicao;
  final bool showAgendar;
  final VoidCallback? onAgendar;

  const _ReposicaoCard({
    required this.reposicao,
    required this.showAgendar,
    this.onAgendar,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;
    switch (reposicao.status) {
      case 'pendente':
        statusColor = AppColors.info;
        statusText = 'Pendente';
        break;
      case 'agendada':
        statusColor = Colors.green;
        statusText = 'Agendada';
        break;
      case 'realizada':
        statusColor = Colors.blue;
        statusText = 'Realizada';
        break;
      case 'expirada':
        statusColor = Colors.red;
        statusText = 'Expirada';
        break;
      default:
        statusColor = Colors.grey;
        statusText = reposicao.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.refresh, color: AppColors.info, size: 20),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reposicao.motivoOriginal,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Criada em: ${DateFormatter.data(reposicao.criadaEm)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
            if (reposicao.expiraEm != null &&
                reposicao.status == 'pendente') ...[
              const SizedBox(height: 4),
              Text(
                reposicao.expirou
                    ? '❌ Expirada'
                    : '⏰ Expira em ${reposicao.diasRestantes} dia(s)',
                style: TextStyle(
                  color: reposicao.expirou ? Colors.red : Colors.orange,
                  fontSize: 13,
                ),
              ),
            ],
            if (reposicao.novaDataHora != null) ...[
              const SizedBox(height: 4),
              Text(
                'Agendada para: ${DateFormatter.dataHora(reposicao.novaDataHora!)}',
                style: const TextStyle(color: Colors.green, fontSize: 13),
              ),
            ],
            if (showAgendar && !reposicao.expirou) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onAgendar,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: const Text('Agendar Reposição'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AgendarReposicaoSheet extends StatefulWidget {
  final Reposicao reposicao;
  final Future<void> Function(DateTime dataHora, String horarioId) onConfirmar;

  const _AgendarReposicaoSheet({
    required this.reposicao,
    required this.onConfirmar,
  });

  @override
  State<_AgendarReposicaoSheet> createState() => _AgendarReposicaoSheetState();
}

class _AgendarReposicaoSheetState extends State<_AgendarReposicaoSheet> {
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();
  List<GradeHorario> _grade = [];
  bool _carregando = true;
  GradeHorario? _selecionado;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _carregarGrade();
  }

  Future<void> _carregarGrade() async {
    try {
      final grade = await _gradeRepo.listarAtivos();
      setState(() {
        _grade = grade;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Agendar Reposição',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Escolha um horário disponível:'),
          const SizedBox(height: 12),
          if (_carregando)
            const Center(child: CircularProgressIndicator())
          else if (_grade.isEmpty)
            const Text('Nenhum horário disponível.')
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _grade.length,
                itemBuilder: (context, index) {
                  final item = _grade[index];
                  final selected = _selecionado?.id == item.id;
                  return ListTile(
                    selected: selected,
                    selectedTileColor:
                        AppColors.primary.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    leading: const Icon(Icons.schedule),
                    title: Text(item.diaSemanaTexto),
                    subtitle: Text('${item.horario} • ${item.modalidade}'),
                    onTap: () => setState(() => _selecionado = item),
                    trailing: selected
                        ? const Icon(Icons.check_circle,
                            color: AppColors.primary)
                        : null,
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selecionado == null || _processando
                  ? null
                  : () async {
                      setState(() => _processando = true);
                      final agora = DateTime.now();
                      var data = agora;
                      while (data.weekday != _selecionado!.diaSemana) {
                        data = data.add(const Duration(days: 1));
                      }
                      final partes = _selecionado!.horario.split(':');
                      final dataHora = DateTime(
                        data.year,
                        data.month,
                        data.day,
                        int.parse(partes[0]),
                        int.parse(partes[1]),
                      );
                      await widget.onConfirmar(dataHora, _selecionado!.id);
                      if (mounted) Navigator.pop(context);
                    },
              child: _processando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Confirmar Agendamento'),
            ),
          ),
        ],
      ),
    );
  }
}
