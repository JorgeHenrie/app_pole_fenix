import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/aula.dart';
import '../../models/grade_horario.dart';
import '../../models/horario_fixo.dart';
import '../../models/reposicao.dart';
import '../../models/solicitacao_mudanca_horario.dart';
import '../../providers/auth_provider.dart';
import '../../providers/horario_fixo_provider.dart';
import '../../repositories/aula_repository.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/reposicao_repository.dart';
import '../../repositories/solicitacao_mudanca_horario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class MeusHorariosScreen extends StatefulWidget {
  const MeusHorariosScreen({super.key});

  @override
  State<MeusHorariosScreen> createState() => _MeusHorariosScreenState();
}

class _MeusHorariosScreenState extends State<MeusHorariosScreen> {
  final AulaRepository _aulaRepository = AulaRepository();
  List<Aula> _proximasAulas = [];
  bool _carregandoAulas = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarDados());
  }

  Future<void> _carregarDados() async {
    final authProvider = context.read<AuthProvider>();
    final horarioProvider = context.read<HorarioFixoProvider>();
    final usuario = authProvider.usuario;
    if (usuario == null) return;

    await horarioProvider.carregarHorariosDeAluna(usuario.id);
    await _carregarProximasAulas(usuario.id);
  }

  Future<void> _carregarProximasAulas(String alunaId) async {
    setState(() => _carregandoAulas = true);
    try {
      final aulas =
          await _aulaRepository.buscarProximasPorAluna(alunaId, limite: 8);
      setState(() => _proximasAulas = aulas);
    } catch (e) {
      // ignore
    } finally {
      setState(() => _carregandoAulas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meus Horários'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      body: Consumer<HorarioFixoProvider>(
        builder: (context, provider, _) {
          if (provider.carregando) return const LoadingIndicator();
          return RefreshIndicator(
            onRefresh: _carregarDados,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHorariosRecorrentes(provider),
                  const SizedBox(height: 24),
                  _buildProximasAulas(provider.horariosFixos),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorariosRecorrentes(HorarioFixoProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meus Horários Recorrentes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (provider.horariosFixos.isEmpty)
          _buildEmptyHorarios()
        else
          ...provider.horariosFixos.map((h) => _HorarioFixoCard(
                horario: h,
                onSolicitarMudanca: () => _mostrarSolicitarMudanca(h),
              )),
      ],
    );
  }

  Widget _buildEmptyHorarios() {
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
          Icon(Icons.schedule, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'Você não possui horários fixos cadastrados',
            style: TextStyle(color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Entre em contato com o estúdio para definir seus horários.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProximasAulas(List<HorarioFixo> horariosFixos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Próximas Aulas',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (_carregandoAulas)
          const Center(child: CircularProgressIndicator())
        else if (_proximasAulas.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              'Nenhuma aula agendada nas próximas semanas.',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          )
        else
          ..._proximasAulas.map((aula) => _AulaAgendadaCard(
                aula: aula,
                onCancelar: () => _mostrarCancelarAula(aula),
              )),
      ],
    );
  }

  Future<void> _mostrarCancelarAula(Aula aula) async {
    await showDialog(
      context: context,
      builder: (ctx) => _CancelarAulaDialog(
        aula: aula,
        onConfirmar: (motivo) async {
          final dentroDosPrazo = aula.podeSerCancelada;
          await _aulaRepository.cancelarAula(aula.id, motivo, dentroDosPrazo);
          if (dentroDosPrazo) {
            final usuario = context.read<AuthProvider>().usuario;
            if (usuario != null) {
              final reposicao = Reposicao(
                id: '',
                aulaOriginalId: aula.id,
                alunaId: usuario.id,
                status: 'pendente',
                motivoOriginal: 'Cancelamento',
                criadaEm: DateTime.now(),
                expiraEm: DateTime.now().add(const Duration(days: 30)),
              );
              await ReposicaoRepository().criar(reposicao);
            }
          }
          if (mounted) {
            final usuario = context.read<AuthProvider>().usuario;
            if (usuario != null) {
              await _carregarProximasAulas(usuario.id);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  dentroDosPrazo
                      ? 'Aula cancelada. Você tem direito a reposição!'
                      : 'Aula cancelada. Você perdeu o crédito desta aula.',
                ),
                backgroundColor: dentroDosPrazo ? Colors.green : Colors.orange,
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _mostrarSolicitarMudanca(HorarioFixo horario) async {
    await showDialog(
      context: context,
      builder: (ctx) => _SolicitarMudancaDialog(horarioAtual: horario),
    );
  }
}

/// Gera as próximas [semanas] ocorrências para uma lista de horários fixos,
/// ordenadas por data crescente.
List<({DateTime data, HorarioFixo horario})> _gerarProximasOcorrencias(
  List<HorarioFixo> horarios, {
  int semanas = 4,
}) {
  final result = <({DateTime data, HorarioFixo horario})>[];
  for (final h in horarios) {
    DateTime proxima = _proximaOcorrencia(h.diaSemana, h.horario);
    for (int i = 0; i < semanas; i++) {
      result.add((data: proxima, horario: h));
      proxima = proxima.add(const Duration(days: 7));
    }
  }
  result.sort((a, b) => a.data.compareTo(b.data));
  return result;
}

/// Calcula a próxima data de ocorrência de um horário fixo.
/// Se hoje é o dia e o horário ainda não passou, retorna hoje.
/// Caso contrário, retorna a próxima ocorrência na semana seguinte.
DateTime _proximaOcorrencia(int diaSemana, String horario) {
  final agora = DateTime.now();
  final partes = horario.split(':');
  final hora = int.parse(partes[0]);
  final minuto = int.parse(partes[1]);

  // quantos dias até o próximo diaSemana (0 = hoje)
  final int diasAte = (diaSemana - agora.weekday) % 7;

  DateTime candidato = DateTime(
    agora.year,
    agora.month,
    agora.day + diasAte,
    hora,
    minuto,
  );

  // se o horário de hoje já passou, vai para a semana seguinte
  if (candidato.isBefore(agora)) {
    candidato = candidato.add(const Duration(days: 7));
  }

  return candidato;
}

class _HorarioFixoCard extends StatelessWidget {
  final HorarioFixo horario;
  final VoidCallback onSolicitarMudanca;

  const _HorarioFixoCard({
    required this.horario,
    required this.onSolicitarMudanca,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule,
                  color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horario.diaSemanaTexto,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Próxima: ${DateFormatter.data(_proximaOcorrencia(horario.diaSemana, horario.horario))}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${horario.horario} • ${horario.modalidade}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onSolicitarMudanca,
              child: const Text('Mudar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OcorrenciaFixaCard extends StatelessWidget {
  final DateTime data;
  final HorarioFixo horario;

  const _OcorrenciaFixaCard({required this.data, required this.horario});

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final isHoje = data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;
    final cor = isHoje ? AppColors.secondary : AppColors.primary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: cor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    horario.horario,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: cor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHoje
                        ? 'HOJE'
                        : '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 10,
                      color: cor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    horario.modalidade,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${horario.diaSemanaTexto} • ${DateFormatter.data(data)}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'agendada',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AulaAgendadaCard extends StatelessWidget {
  final Aula aula;
  final VoidCallback onCancelar;

  const _AulaAgendadaCard({required this.aula, required this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final podeCancelar = aula.podeSerCancelada;
    final isHoje = _isHoje(aula.dataHora);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isHoje
                    ? AppColors.secondary.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormatter.hora(aula.dataHora),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isHoje ? AppColors.secondary : AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isHoje ? 'HOJE' : DateFormatter.data(aula.dataHora),
                    style: TextStyle(
                      fontSize: 9,
                      color: isHoje
                          ? AppColors.secondary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aula.modalidade,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _StatusBadge(status: aula.status),
                ],
              ),
            ),
            if (aula.status == 'agendada')
              TextButton(
                onPressed: podeCancelar ? onCancelar : null,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
                child: const Text('Cancelar'),
              ),
          ],
        ),
      ),
    );
  }

  bool _isHoje(DateTime data) {
    final agora = DateTime.now();
    return data.year == agora.year &&
        data.month == agora.month &&
        data.day == agora.day;
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String texto;
    switch (status) {
      case 'agendada':
        bg = Colors.green.shade50;
        fg = Colors.green.shade700;
        texto = 'Agendada';
        break;
      case 'cancelada':
        bg = Colors.red.shade50;
        fg = Colors.red.shade700;
        texto = 'Cancelada';
        break;
      case 'realizada':
        bg = Colors.blue.shade50;
        fg = Colors.blue.shade700;
        texto = 'Realizada';
        break;
      case 'falta':
        bg = Colors.orange.shade50;
        fg = Colors.orange.shade700;
        texto = 'Falta';
        break;
      default:
        bg = Colors.grey.shade50;
        fg = Colors.grey.shade700;
        texto = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _CancelarAulaDialog extends StatefulWidget {
  final Aula aula;
  final Future<void> Function(String motivo) onConfirmar;
  const _CancelarAulaDialog({required this.aula, required this.onConfirmar});

  @override
  State<_CancelarAulaDialog> createState() => _CancelarAulaDialogState();
}

class _CancelarAulaDialogState extends State<_CancelarAulaDialog> {
  final _motivoController = TextEditingController();
  bool _entendeuPerda = false;
  bool _processando = false;

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dentroDosPrazo = widget.aula.podeSerCancelada;
    return AlertDialog(
      title: const Text('Cancelar Aula'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Data: ${DateFormatter.dataHora(widget.aula.dataHora)}'),
            Text('Modalidade: ${widget.aula.modalidade}'),
            const SizedBox(height: 16),
            if (dentroDosPrazo)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✅ Você pode cancelar com direito a reposição!',
                  style: TextStyle(color: Colors.green),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '⚠️ Atenção! Você está cancelando com menos de 2 horas de antecedência e perderá essa aula.',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Checkbox(
                        value: _entendeuPerda,
                        onChanged: (v) =>
                            setState(() => _entendeuPerda = v ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Entendo que perderei esta aula',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Voltar'),
        ),
        ElevatedButton(
          onPressed: (!dentroDosPrazo && !_entendeuPerda) || _processando
              ? null
              : () async {
                  setState(() => _processando = true);
                  await widget.onConfirmar(_motivoController.text);
                  if (mounted) Navigator.pop(context);
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: _processando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(dentroDosPrazo
                  ? 'Confirmar Cancelamento'
                  : 'Cancelar Mesmo Assim'),
        ),
      ],
    );
  }
}

class _SolicitarMudancaDialog extends StatefulWidget {
  final HorarioFixo horarioAtual;
  const _SolicitarMudancaDialog({required this.horarioAtual});

  @override
  State<_SolicitarMudancaDialog> createState() =>
      _SolicitarMudancaDialogState();
}

class _SolicitarMudancaDialogState extends State<_SolicitarMudancaDialog> {
  final _motivoController = TextEditingController();
  int? _novoDiaSemana;
  String? _novoHorario;
  bool _processando = false;
  List<GradeHorario> _horariosDisponiveis = [];
  bool _carregandoGrade = false;

  @override
  void initState() {
    super.initState();
    _carregarGrade();
  }

  Future<void> _carregarGrade() async {
    setState(() => _carregandoGrade = true);
    try {
      final grade = await GradeHorarioRepository().listarAtivos();
      setState(() => _horariosDisponiveis = grade);
    } catch (_) {}
    setState(() => _carregandoGrade = false);
  }

  @override
  void dispose() {
    _motivoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const diasSemana = {
      1: 'Segunda-feira',
      2: 'Terça-feira',
      3: 'Quarta-feira',
      4: 'Quinta-feira',
      5: 'Sexta-feira',
      6: 'Sábado',
      7: 'Domingo',
    };

    final diasComHorarios =
        _horariosDisponiveis.map((h) => h.diaSemana).toSet().toList()..sort();

    final horariosParaDia = _novoDiaSemana != null
        ? _horariosDisponiveis
            .where((h) => h.diaSemana == _novoDiaSemana)
            .toList()
        : <GradeHorario>[];

    return AlertDialog(
      title: const Text('Solicitar Mudança de Horário'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horário atual: ${widget.horarioAtual.diaSemanaTexto} às ${widget.horarioAtual.horario}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            const Text('Novo dia da semana:'),
            const SizedBox(height: 8),
            if (_carregandoGrade)
              const CircularProgressIndicator()
            else
              DropdownButtonFormField<int>(
                value: _novoDiaSemana,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Selecione o dia'),
                items: diasComHorarios
                    .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(diasSemana[d] ?? 'Dia $d'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _novoDiaSemana = v;
                  _novoHorario = null;
                }),
              ),
            if (_novoDiaSemana != null) ...[
              const SizedBox(height: 12),
              const Text('Novo horário:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _novoHorario,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                hint: const Text('Selecione o horário'),
                items: horariosParaDia
                    .map((h) => DropdownMenuItem(
                          value: h.horario,
                          child: Text(h.horario),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _novoHorario = v),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo da mudança (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
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
          onPressed: (_novoDiaSemana == null ||
                  _novoHorario == null ||
                  _processando)
              ? null
              : () async {
                  setState(() => _processando = true);
                  try {
                    final usuario = context.read<AuthProvider>().usuario;
                    if (usuario != null) {
                      final solicitacao = SolicitacaoMudancaHorario(
                        id: '',
                        alunaId: usuario.id,
                        horarioFixoAntigoId: widget.horarioAtual.id,
                        novoDiaSemana: _novoDiaSemana!,
                        novoHorario: _novoHorario!,
                        motivo: _motivoController.text,
                        status: 'pendente',
                        solicitadoEm: DateTime.now(),
                      );
                      await SolicitacaoMudancaHorarioRepository()
                          .criar(solicitacao);
                    }
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('Solicitação enviada! Aguarde aprovação.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => _processando = false);
                  }
                },
          child: _processando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar Solicitação'),
        ),
      ],
    );
  }
}
