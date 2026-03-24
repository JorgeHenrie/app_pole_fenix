import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/aula.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/aula_repository.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela com o histórico completo de aulas da aluna.
class MinhasAulasScreen extends StatefulWidget {
  const MinhasAulasScreen({super.key});

  @override
  State<MinhasAulasScreen> createState() => _MinhasAulasScreenState();
}

class _MinhasAulasScreenState extends State<MinhasAulasScreen> {
  final AulaRepository _aulaRepository = AulaRepository();
  List<Aula> _aulas = [];
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
      final aulas = await _aulaRepository.buscarHistoricoPorAluna(usuario.id);
      setState(() => _aulas = aulas);
    } catch (e) {
      setState(() => _erro = 'Erro ao carregar aulas. Tente novamente.');
    } finally {
      setState(() => _carregando = false);
    }
  }

  int get _aulasRealizadas =>
      _aulas.where((a) => a.status == 'realizada').length;
  int get _faltas => _aulas.where((a) => a.status == 'falta').length;

  Map<String, List<Aula>> get _aulasPorMes {
    final mapa = <String, List<Aula>>{};
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
      appBar: AppBar(
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
              'Nenhuma aula encontrada',
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
          Expanded(child: _buildStat('Total', _aulas.length.toString())),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(
              child: _buildStat('Realizadas', _aulasRealizadas.toString())),
          Container(width: 1, height: 48, color: Colors.white24),
          Expanded(child: _buildStat('Faltas', _faltas.toString())),
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

  Widget _buildGrupoMes(String mes, List<Aula> aulas) {
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
  final Aula aula;

  const _AulaHistoricoCard({required this.aula});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, label) = _statusInfo(aula.status);

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
          aula.titulo ?? aula.modalidade,
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
            if (aula.instrutora != null)
              Text(
                aula.instrutora!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
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

  (Color, IconData, String) _statusInfo(String status) {
    return switch (status) {
      'realizada' => (
          AppColors.success,
          Icons.check_circle_outline,
          'Realizada'
        ),
      'cancelada' => (AppColors.error, Icons.cancel_outlined, 'Cancelada'),
      'falta' => (AppColors.warning, Icons.warning_amber_outlined, 'Falta'),
      _ => (AppColors.info, Icons.schedule, 'Agendada'),
    };
  }
}
