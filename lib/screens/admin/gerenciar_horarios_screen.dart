import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/helpers.dart';
import '../../models/grade_horario.dart';
import '../../models/usuario.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../repositories/usuario_repository.dart';
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
    final diasComHorarios = _grade.map((g) => g.diaSemana).toSet().toList()
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
                      return _DiaExpansionSection(
                        dia: _diasSemana[dia] ?? 'Dia $dia',
                        horarios: horariosHoje,
                        ocupacao: _ocupacao,
                        onToggle: (g) async {
                          await _gradeRepo.ativarDesativar(g.id, !g.ativo);
                          _carregarDados();
                        },
                        onEdit: (g) => _mostrarEdicao(g),
                        onVerAlunas: (g) => _mostrarAlunas(g),
                        onExcluir: (g) => _confirmarExcluirHorario(context, g),
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

  Future<void> _mostrarAlunas(GradeHorario grade) async {
    final diasNome = _diasSemana[grade.diaSemana] ?? 'Dia ${grade.diaSemana}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AlunasSlotSheet(
        titulo: '$diasNome • ${grade.horario}',
        subtitulo:
            grade.instrutora != null && grade.instrutora!.trim().isNotEmpty
                ? '${grade.modalidade} • ${grade.instrutora}'
                : grade.modalidade,
        diaSemana: grade.diaSemana,
        horario: grade.horario,
      ),
    );
  }

  void _confirmarExcluirHorario(
      BuildContext context, GradeHorario grade) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir horário'),
        content: Text(
            'Tem certeza que deseja excluir o horário "${grade.horario} • ${grade.modalidade}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await _gradeRepo.excluir(grade.id);
      _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Horário excluído com sucesso!'),
              backgroundColor: AppColors.success),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _DiaExpansionSection extends StatelessWidget {
  final String dia;
  final List<GradeHorario> horarios;
  final Map<String, int> ocupacao;
  final void Function(GradeHorario) onToggle;
  final void Function(GradeHorario) onEdit;
  final void Function(GradeHorario) onVerAlunas;
  final void Function(GradeHorario) onExcluir;

  _DiaExpansionSection({
    required this.dia,
    required this.horarios,
    required this.ocupacao,
    required this.onToggle,
    required this.onEdit,
    required this.onVerAlunas,
    required this.onExcluir,
    Key? key,
  }) : super(key: key);

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
        initiallyExpanded: false,
        children: horarios.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Nenhum horário cadastrado para este dia.'),
                ),
              ]
            : horarios
                .map((h) => _HorarioSlotCard(
                      grade: h,
                      vagas: ocupacao['${h.diaSemana}_${h.horario}'] ?? 0,
                      onToggle: () => onToggle(h),
                      onEdit: () => onEdit(h),
                      onVerAlunas: () => onVerAlunas(h),
                      onExcluir: () => onExcluir(h),
                    ))
                .toList(),
      ),
    );
  }
}

class _HorarioSlotCard extends StatelessWidget {
  final GradeHorario grade;
  final int vagas;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onVerAlunas;
  final VoidCallback onExcluir;

  const _HorarioSlotCard({
    required this.grade,
    required this.vagas,
    required this.onToggle,
    required this.onEdit,
    required this.onVerAlunas,
    required this.onExcluir,
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
        onTap: onVerAlunas,
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
              ? [
                  if (grade.instrutora != null &&
                      grade.instrutora!.trim().isNotEmpty)
                    'Instrutora: ${grade.instrutora}',
                  '$vagas/${grade.capacidadeMaxima} vagas ocupadas ($disponivel disponível)',
                ].join('\n')
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
                  onTap: onVerAlunas,
                  child: const ListTile(
                    leading: Icon(Icons.group_outlined),
                    title: Text('Ver alunas'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
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
                      grade.ativo ? Icons.visibility_off : Icons.visibility,
                    ),
                    title: Text(grade.ativo ? 'Desativar' : 'Ativar'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  onTap: onExcluir,
                  child: const ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title: Text('Excluir', style: TextStyle(color: Colors.red)),
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

class _AlunasSlotSheet extends StatefulWidget {
  final String titulo;
  final String subtitulo;
  final int diaSemana;
  final String horario;

  const _AlunasSlotSheet({
    required this.titulo,
    required this.subtitulo,
    required this.diaSemana,
    required this.horario,
  });

  @override
  State<_AlunasSlotSheet> createState() => _AlunasSlotSheetState();
}

class _AlunasSlotSheetState extends State<_AlunasSlotSheet> {
  final HorarioFixoRepository _horarioRepo = HorarioFixoRepository();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();

  // Par (aluna, horarioFixoId) para poder desativar o vínculo
  List<({Usuario aluna, String horarioFixoId})> _entradas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (mounted) setState(() => _carregando = true);
    try {
      final horarios = await _horarioRepo.buscarPorDiaHorario(
        widget.diaSemana,
        widget.horario,
      );
      final entradas = <({Usuario aluna, String horarioFixoId})>[];
      for (final h in horarios) {
        final aluna = await _usuarioRepo.buscarPorId(h.alunaId);
        if (aluna != null) entradas.add((aluna: aluna, horarioFixoId: h.id));
      }
      if (mounted) setState(() => _entradas = entradas);
    } catch (_) {
      // ignora erro silenciosamente
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _confirmarRemocao(
      BuildContext context, Usuario aluna, String horarioFixoId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover aluna'),
        content: Text(
          'Deseja remover ${aluna.nome} deste horário?\nO horário fixo dela será desativado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _horarioRepo.desativar(
          horarioFixoId, 'Removido pelo administrador');
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${aluna.nome} removida deste horário.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                widget.titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.subtitulo,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              if (_carregando)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (_entradas.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.group_off_outlined,
                            size: 56, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma aluna cadastrada neste horário',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  '${_entradas.length} ${_entradas.length == 1 ? 'aluna' : 'alunas'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    itemCount: _entradas.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final aluna = _entradas[i].aluna;
                      final horarioFixoId = _entradas[i].horarioFixoId;
                      final iniciais = Helpers.iniciais(aluna.nome);
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary,
                          backgroundImage: aluna.fotoUrl != null
                              ? NetworkImage(aluna.fotoUrl!)
                              : null,
                          child: aluna.fotoUrl == null
                              ? Text(
                                  iniciais,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                )
                              : null,
                        ),
                        title: Text(
                          aluna.nome,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: aluna.telefone != null
                            ? Text(aluna.telefone!)
                            : Text(
                                aluna.email,
                                style: const TextStyle(fontSize: 12),
                              ),
                        trailing: IconButton(
                          icon: const Icon(Icons.person_remove_outlined,
                              color: AppColors.error),
                          tooltip: 'Remover aluna',
                          onPressed: () =>
                              _confirmarRemocao(context, aluna, horarioFixoId),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
  int _diaSemana = 1;
  int _capacidade = 3;
  bool _processando = false;
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _modalidadeController = TextEditingController();
  final TextEditingController _instrutoraController = TextEditingController();

  final _diasSemana = const {
    1: 'Segunda-feira',
    2: 'Terça-feira',
    3: 'Quarta-feira',
    4: 'Quinta-feira',
    5: 'Sexta-feira',
    6: 'Sábado',
    7: 'Domingo',
  };

  String? _normalizarHorario(String valor) {
    final digitos = valor.replaceAll(RegExp(r'\D'), '');
    if (digitos.length != 4) return null;

    final hora = int.tryParse(digitos.substring(0, 2));
    final minuto = int.tryParse(digitos.substring(2, 4));
    if (hora == null || minuto == null) return null;
    if (hora < 0 || hora > 23 || minuto < 0 || minuto > 59) return null;

    final horaFormatada = hora.toString().padLeft(2, '0');
    final minutoFormatado = minuto.toString().padLeft(2, '0');
    return '$horaFormatada:$minutoFormatado';
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.gradeExistente != null) {
      final g = widget.gradeExistente!;
      _diaSemana = g.diaSemana;
      _capacidade = g.capacidadeMaxima;
      _horarioController.text = g.horario;
      _modalidadeController.text = g.modalidade;
      _instrutoraController.text = g.instrutora ?? '';
    } else {
      _capacidade = 3;
    }
  }

  @override
  void dispose() {
    _horarioController.dispose();
    _modalidadeController.dispose();
    _instrutoraController.dispose();
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
              initialValue: _diaSemana,
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
              keyboardType: TextInputType.number,
              inputFormatters: const [_HorarioInputFormatter()],
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
            TextField(
              controller: _instrutoraController,
              decoration: const InputDecoration(
                labelText: 'Instrutora (opcional)',
                border: OutlineInputBorder(),
                hintText: 'Ex.: Barbara',
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
                  final horarioNormalizado =
                      _normalizarHorario(_horarioController.text);
                  if (horarioNormalizado == null) {
                    _mostrarErro('Informe um horário válido no formato HH:mm.');
                    return;
                  }

                  if (_modalidadeController.text.trim().isEmpty) {
                    _mostrarErro('Informe a modalidade.');
                    return;
                  }

                  setState(() => _processando = true);
                  final grade = GradeHorario(
                    id: widget.gradeExistente?.id ?? '',
                    diaSemana: _diaSemana,
                    horario: horarioNormalizado,
                    capacidadeMaxima: _capacidade,
                    modalidade: _modalidadeController.text.trim(),
                    instrutora: _instrutoraController.text.trim().isEmpty
                        ? null
                        : _instrutoraController.text.trim(),
                    ativo: widget.gradeExistente?.ativo ?? true,
                    criadoEm: widget.gradeExistente?.criadoEm ?? DateTime.now(),
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

class _HorarioInputFormatter extends TextInputFormatter {
  const _HorarioInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitos = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limitados = digitos.length > 4 ? digitos.substring(0, 4) : digitos;

    String textoFormatado;
    if (limitados.length <= 2) {
      textoFormatado = limitados;
    } else {
      textoFormatado = '${limitados.substring(0, 2)}:${limitados.substring(2)}';
    }

    return TextEditingValue(
      text: textoFormatado,
      selection: TextSelection.collapsed(offset: textoFormatado.length),
    );
  }
}
