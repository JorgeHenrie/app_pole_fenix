import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/grade_horario.dart';
import '../../models/usuario.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../repositories/usuario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela admin para visualizar ocupação dos horários.
class VisualizarOcupacaoScreen extends StatefulWidget {
  const VisualizarOcupacaoScreen({super.key});

  @override
  State<VisualizarOcupacaoScreen> createState() =>
      _VisualizarOcupacaoScreenState();
}

class _VisualizarOcupacaoScreenState extends State<VisualizarOcupacaoScreen> {
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();

  List<GradeHorario> _grade = [];
  Map<String, int> _ocupacao = {};
  bool _carregando = false;

  static const _diasSemana = {
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    try {
      final grade = await _gradeRepo.listarTodos();
      final Map<String, int> ocupacao = {};
      for (final slot in grade) {
        final count = await _horarioFixoRepo.contarOcupacao(
          slot.diaSemana,
          slot.horario,
        );
        ocupacao['${slot.diaSemana}_${slot.horario}'] = count;
      }
      if (mounted) {
        setState(() {
          _grade = grade;
          _ocupacao = ocupacao;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar ocupação')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Color _corOcupacao(GradeHorario grade) {
    final ocupadas = _ocupacao['${grade.diaSemana}_${grade.horario}'] ?? 0;
    if (ocupadas == 0) return AppColors.success;
    if (ocupadas < grade.capacidadeMaxima) return AppColors.warning;
    return AppColors.error;
  }

  Future<void> _verAlunas(GradeHorario grade) async {
    showDialog(
      context: context,
      builder: (_) => const AlertDialog(
        title: Text('Carregando…'),
        content: SizedBox(
          height: 60,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final horarios = await _horarioFixoRepo.buscarPorDiaHorario(
        grade.diaSemana,
        grade.horario,
      );

      final List<Usuario> alunas = [];
      for (final h in horarios) {
        final aluna = await _usuarioRepo.buscarPorId(h.alunaId);
        if (aluna != null) alunas.add(aluna);
      }

      if (!mounted) return;
      Navigator.of(context).pop(); // fecha loading dialog

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            'Alunas — ${_diasSemana[grade.diaSemana] ?? ''} ${grade.horario}',
          ),
          content: alunas.isEmpty
              ? const Text('Nenhuma aluna neste horário.')
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView(
                    shrinkWrap: true,
                    children: alunas
                        .map(
                          (aluna) => ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              child: Text(
                                aluna.nome.isNotEmpty
                                    ? aluna.nome[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(aluna.nome),
                            subtitle: Text(aluna.email),
                          ),
                        )
                        .toList(),
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Fechar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao buscar alunas')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diasComHorarios = _grade.map((g) => g.diaSemana).toSet().toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ocupação de Horários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _grade.isEmpty
              ? const Center(
                  child: Text('Nenhum horário cadastrado.'),
                )
              : RefreshIndicator(
                  onRefresh: _carregarDados,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: diasComHorarios.length,
                    itemBuilder: (context, index) {
                      final dia = diasComHorarios[index];
                      final horariosHoje = _grade
                          .where((g) => g.diaSemana == dia)
                          .toList()
                        ..sort((a, b) => a.horario.compareTo(b.horario));

                      return _DiaOcupacaoExpansionSection(
                        dia: _diasSemana[dia] ?? 'Dia $dia',
                        horarios: horariosHoje,
                        ocupacao: _ocupacao,
                        corOcupacao: _corOcupacao,
                        onTapHorario: _verAlunas,
                      );
                    },
                  ),
                ),
    );
  }
}

class _DiaOcupacaoExpansionSection extends StatelessWidget {
  final String dia;
  final List<GradeHorario> horarios;
  final Map<String, int> ocupacao;
  final Color Function(GradeHorario) corOcupacao;
  final void Function(GradeHorario) onTapHorario;

  const _DiaOcupacaoExpansionSection({
    required this.dia,
    required this.horarios,
    required this.ocupacao,
    required this.corOcupacao,
    required this.onTapHorario,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      child: ExpansionTile(
        title: Text(
          dia,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        children: horarios.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum horário cadastrado para este dia.'),
                ),
              ]
            : horarios.map((grade) {
                final vagasOcupadas =
                    ocupacao['${grade.diaSemana}_${grade.horario}'] ?? 0;
                return Card(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: corOcupacao(grade),
                      foregroundColor: Colors.white,
                      child: Text(
                        '$vagasOcupadas/${grade.capacidadeMaxima}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      '${grade.horario} — ${grade.modalidade}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      vagasOcupadas >= grade.capacidadeMaxima
                          ? 'Lotado'
                          : '${grade.capacidadeMaxima - vagasOcupadas} vaga(s) disponível(is)',
                      style: TextStyle(
                        color: corOcupacao(grade),
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: AppColors.grey,
                    ),
                    onTap: () => onTapHorario(grade),
                  ),
                );
              }).toList(),
      ),
    );
  }
}
