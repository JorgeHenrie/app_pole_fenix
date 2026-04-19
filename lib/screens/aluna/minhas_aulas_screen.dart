import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/aula.dart';
import '../../models/reposicao.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/aula_repository.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/reposicao_repository.dart';
import '../../widgets/aluna/aluna_drawer.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela com o histórico completo de aulas da aluna.
class MinhasAulasScreen extends StatefulWidget {
  const MinhasAulasScreen({super.key});

  @override
  State<MinhasAulasScreen> createState() => _MinhasAulasScreenState();
}

class _MinhasAulasScreenState extends State<MinhasAulasScreen> {
  final AulaRepository _aulaRepository = AulaRepository();
  final ReposicaoRepository _reposicaoRepository = ReposicaoRepository();
  final GradeHorarioRepository _gradeHorarioRepository =
      GradeHorarioRepository();

  List<_HistoricoAulaRealizada> _aulas = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarAulas());
  }

  Future<void> _carregarAulas() async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        _aulaRepository.buscarHistoricoPorAluna(usuario.id),
        _reposicaoRepository.buscarPorAluna(usuario.id),
      ]);

      final aulas = resultados[0] as List<Aula>;
      final reposicoes = resultados[1] as List<Reposicao>;

      final historico = await _montarHistoricoRealizado(aulas, reposicoes);
      setState(() => _aulas = historico);
    } catch (e, stack) {
      debugPrint('[MinhasAulas] Erro: $e\n$stack');
      setState(() => _erro = 'Erro ao carregar aulas. Tente novamente.');
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<List<_HistoricoAulaRealizada>> _montarHistoricoRealizado(
    List<Aula> aulas,
    List<Reposicao> reposicoes,
  ) async {
    final agora = DateTime.now();
    final historico = <_HistoricoAulaRealizada>[];

    final aulasRealizadas = aulas.where((aula) => aula.status == 'realizada');
    for (final aula in aulasRealizadas) {
      historico.add(
        _HistoricoAulaRealizada(
          id: aula.id,
          modalidade: aula.titulo ?? aula.modalidade,
          dataHora: aula.dataHora,
          origem: _OrigemAula.plano,
        ),
      );
    }

    final reposicoesConcluidas = reposicoes.where(
      (reposicao) =>
          reposicao.novaDataHora != null &&
          (reposicao.status == 'realizada' ||
              (reposicao.status == 'agendada' &&
                  !agora.isBefore(reposicao.novaDataHora!))),
    );

    final horarioIds = reposicoesConcluidas
        .map((reposicao) => reposicao.novoHorarioId)
        .whereType<String>()
        .toSet();

    final modalidadesPorHorarioId = <String, String>{};
    await Future.wait(horarioIds.map((horarioId) async {
      final grade = await _gradeHorarioRepository.buscarPorId(horarioId);
      if (grade != null) {
        modalidadesPorHorarioId[horarioId] = grade.modalidade;
      }
    }));

    for (final reposicao in reposicoesConcluidas) {
      final dataHora = reposicao.novaDataHora!;
      historico.add(
        _HistoricoAulaRealizada(
          id: reposicao.id,
          modalidade:
              modalidadesPorHorarioId[reposicao.novoHorarioId] ?? 'Reposição',
          dataHora: dataHora,
          origem: _OrigemAula.reposicao,
        ),
      );
    }

    historico.sort((a, b) => b.dataHora.compareTo(a.dataHora));
    return historico;
  }

  int get _aulasRealizadas => _aulas.length;
  int get _aulasPlano =>
      _aulas.where((a) => a.origem == _OrigemAula.plano).length;
  int get _reposicoesRealizadas =>
      _aulas.where((a) => a.origem == _OrigemAula.reposicao).length;

  Map<String, List<_HistoricoAulaRealizada>> get _aulasPorMes {
    final mapa = <String, List<_HistoricoAulaRealizada>>{};
    for (final aula in _aulas) {
      final chave = DateFormatter.mesAno(aula.dataHora);
      mapa.putIfAbsent(chave, () => []).add(aula);
    }
    return mapa;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AlunaDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Minhas Aulas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarAulas,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _erro != null
              ? _buildErro()
              : RefreshIndicator(
                  onRefresh: _carregarAulas,
                  child: _aulas.isEmpty ? _buildVazio() : _buildConteudo(),
                ),
    );
  }

  Widget _buildErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _carregarAulas,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aula realizada encontrada',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    final porMes = _aulasPorMes;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildResumo(),
          const SizedBox(height: 24),
          ...porMes.entries.map((e) => _buildGrupoMes(e.key, e.value)),
        ],
      ),
    );
  }

  Widget _buildResumo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
              child: _buildStat('Realizadas', _aulasRealizadas.toString())),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(child: _buildStat('Plano', _aulasPlano.toString())),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(
              child:
                  _buildStat('Reposições', _reposicoesRealizadas.toString())),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String valor) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildGrupoMes(String mes, List<_HistoricoAulaRealizada> aulas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            mes.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
          ),
        ),
        ...aulas.map((aula) => _AulaHistoricoCard(aula: aula)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _AulaHistoricoCard extends StatelessWidget {
  final _HistoricoAulaRealizada aula;

  const _AulaHistoricoCard({required this.aula});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, label) = _origemInfo(aula.origem);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: cor.withValues(alpha: 0.12),
          child: Icon(icone, color: cor, size: 20),
        ),
        title: Text(
          aula.modalidade,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${DateFormatter.data(aula.dataHora)} às ${DateFormatter.hora(aula.dataHora)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  (Color, IconData, String) _origemInfo(_OrigemAula origem) {
    return switch (origem) {
      _OrigemAula.plano => (
          AppColors.success,
          Icons.check_circle_outline,
          'Plano'
        ),
      _OrigemAula.reposicao => (AppColors.info, Icons.refresh, 'Reposição'),
    };
  }
}

enum _OrigemAula { plano, reposicao }

class _HistoricoAulaRealizada {
  final String id;
  final String modalidade;
  final DateTime dataHora;
  final _OrigemAula origem;

  const _HistoricoAulaRealizada({
    required this.id,
    required this.modalidade,
    required this.dataHora,
    required this.origem,
  });
}
