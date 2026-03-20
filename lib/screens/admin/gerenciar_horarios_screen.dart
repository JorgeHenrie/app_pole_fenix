import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/grade_horario.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class GerenciarHorariosScreen extends StatefulWidget {
  const GerenciarHorariosScreen({super.key});

  @override
  State<GerenciarHorariosScreen> createState() =>
      _GerenciarHorariosScreenState();
}

class _GerenciarHorariosScreenState extends State<GerenciarHorariosScreen> {
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();

  List<GradeHorario> _grade = [];
  Map<String, int> _ocupacao = {};
  bool _carregando = false;

  final _diasSemana = const {
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
      setState(() {
        _grade = grade;
        _ocupacao = ocupacao;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar horários')),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final diasComHorarios = _grade
        .map((g) => g.diaSemana)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gerenciar Horários'),
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
              ? _buildEmptyState()
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
                      return _DiaSection(
                        dia: _diasSemana[dia] ?? 'Dia $dia',
                        horarios: horariosHoje,
                        ocupacao: _ocupacao,
                        onToggle: (g) async {
                          await _gradeRepo.ativarDesativar(g.id, !g.ativo);
                          _carregarDados();
                        },
                        onEdit: (g) => _mostrarEdicao(g),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _mostrarCriacao,
        icon: const Icon(Icons.add),
        label: const Text('Novo Horário'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Nenhum horário cadastrado',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _mostrarCriacao,
            icon: const Icon(Icons.add),
            label: const Text('Criar primeiro horário'),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarCriacao() async {
    await showDialog(
      context: context,
      builder: (ctx) => _GradeHorarioDialog(
        onSalvar: (grade) async {
          await _gradeRepo.criar(grade);
          _carregarDados();
        },
      ),
    );
  }

  Future<void> _mostrarEdicao(GradeHorario grade) async {
    await showDialog(
      context: context,
      builder: (ctx) => _GradeHorarioDialog(
        gradeExistente: grade,
        onSalvar: (gradeAtualizado) async {
          await _gradeRepo.atualizar(gradeAtualizado);
          _carregarDados();
        },
      ),
    );
  }
}

class _DiaSection extends StatelessWidget {
  final String dia;
  final List<GradeHorario> horarios;
  final Map<String, int> ocupacao;
  final Function(GradeHorario) onToggle;
  final Function(GradeHorario) onEdit;

  const _DiaSection({
    required this.dia,
    required this.horarios,
    required this.ocupacao,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            dia,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
          ),
        ),
        ...horarios.map((h) => _HorarioSlotCard(
              grade: h,
              vagas: ocupacao['${h.diaSemana}_${h.horario}'] ?? 0,
              onToggle: () => onToggle(h),
              onEdit: () => onEdit(h),
            )),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _HorarioSlotCard extends StatelessWidget {
  final GradeHorario grade;
  final int vagas;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _HorarioSlotCard({
    required this.grade,
    required this.vagas,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final disponivel = grade.capacidadeMaxima - vagas;
    final percentual =
        grade.capacidadeMaxima > 0 ? vagas / grade.capacidadeMaxima : 0.0;

    Color cor;
    if (!grade.ativo) {
      cor = Colors.grey;
    } else if (percentual >= 1) {
      cor = AppColors.error;
    } else if (percentual >= 0.67) {
      cor = AppColors.warning;
    } else {
      cor = AppColors.success;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.schedule, color: cor),
        ),
        title: Text(
          '${grade.horario} • ${grade.modalidade}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          grade.ativo
              ? '$vagas/${grade.capacidadeMaxima} vagas ocupadas ($disponivel disponível)'
              : 'Desativado',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: cor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton(
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  onTap: onEdit,
                  child: const ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Editar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  onTap: onToggle,
                  child: ListTile(
                    leading: Icon(
                      grade.ativo
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    title: Text(grade.ativo ? 'Desativar' : 'Ativar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeHorarioDialog extends StatefulWidget {
  final GradeHorario? gradeExistente;
  final Future<void> Function(GradeHorario) onSalvar;

  const _GradeHorarioDialog({this.gradeExistente, required this.onSalvar});

  @override
  State<_GradeHorarioDialog> createState() => _GradeHorarioDialogState();
}

class _GradeHorarioDialogState extends State<_GradeHorarioDialog> {
  final _horarioController = TextEditingController();
  final _modalidadeController = TextEditingController();
  int _diaSemana = 1;
  int _capacidade = 3;
  bool _processando = false;

  final _diasSemana = const {
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
    if (widget.gradeExistente != null) {
      final g = widget.gradeExistente!;
      _diaSemana = g.diaSemana;
      _horarioController.text = g.horario;
      _capacidade = g.capacidadeMaxima;
      _modalidadeController.text = g.modalidade;
    } else {
      _modalidadeController.text = 'Pole Dance';
    }
  }

  @override
  void dispose() {
    _horarioController.dispose();
    _modalidadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.gradeExistente != null ? 'Editar Horário' : 'Novo Horário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: _diaSemana,
              decoration: const InputDecoration(
                labelText: 'Dia da Semana',
                border: OutlineInputBorder(),
              ),
              items: _diasSemana.entries
                  .map((e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _diaSemana = v!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _horarioController,
              decoration: const InputDecoration(
                labelText: 'Horário (HH:mm)',
                border: OutlineInputBorder(),
                hintText: '19:00',
              ),
              keyboardType: TextInputType.datetime,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modalidadeController,
              decoration: const InputDecoration(
                labelText: 'Modalidade',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Capacidade máxima: '),
                IconButton(
                  onPressed: _capacidade > 1
                      ? () => setState(() => _capacidade--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_capacidade',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _capacidade++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _processando
              ? null
              : () async {
                  if (_horarioController.text.isEmpty ||
                      _modalidadeController.text.isEmpty) {
                    return;
                  }
                  setState(() => _processando = true);
                  final grade = GradeHorario(
                    id: widget.gradeExistente?.id ?? '',
                    diaSemana: _diaSemana,
                    horario: _horarioController.text.trim(),
                    capacidadeMaxima: _capacidade,
                    modalidade: _modalidadeController.text.trim(),
                    ativo: widget.gradeExistente?.ativo ?? true,
                    criadoEm:
                        widget.gradeExistente?.criadoEm ?? DateTime.now(),
                  );
                  await widget.onSalvar(grade);
                  if (mounted) Navigator.pop(context);
                },
          child: _processando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }
}
