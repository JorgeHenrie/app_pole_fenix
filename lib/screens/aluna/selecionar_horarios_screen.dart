import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/grade_horario.dart';
import '../../models/plano.dart';
import '../../repositories/grade_horario_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../widgets/aluna/horario_selecao_card.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';

/// Par de GradeHorario com sua ocupação atual.
class _GradeComOcupacao {
  final GradeHorario grade;
  final int vagasOcupadas;

  _GradeComOcupacao({required this.grade, required this.vagasOcupadas});

  int get vagasDisponiveis => grade.capacidadeMaxima - vagasOcupadas;
  bool get lotado => vagasDisponiveis <= 0;
}

/// Tela de seleção de horários fixos após escolha do plano.
class SelecionarHorariosScreen extends StatefulWidget {
  final Plano plano;

  const SelecionarHorariosScreen({super.key, required this.plano});

  @override
  State<SelecionarHorariosScreen> createState() =>
      _SelecionarHorariosScreenState();
}

class _SelecionarHorariosScreenState
    extends State<SelecionarHorariosScreen> {
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();

  List<_GradeComOcupacao> _grade = [];
  final Set<String> _selecionados = {};
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
    _carregarGrade();
  }

  Future<void> _carregarGrade() async {
    setState(() => _carregando = true);
    try {
      final ativos = await _gradeRepo.listarAtivos();
      final List<_GradeComOcupacao> lista = [];
      for (final g in ativos) {
        final ocupacao = await _horarioFixoRepo.contarOcupacao(
          g.diaSemana,
          g.horario,
        );
        lista.add(_GradeComOcupacao(grade: g, vagasOcupadas: ocupacao));
      }
      if (mounted) {
        setState(() => _grade = lista);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar horários')),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _toggleSelecao(_GradeComOcupacao item) {
    final id = item.grade.id;
    if (_selecionados.contains(id)) {
      setState(() => _selecionados.remove(id));
      return;
    }
    if (item.lotado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este horário está lotado')),
      );
      return;
    }
    if (_selecionados.length >= widget.plano.aulasSemanais) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecione apenas ${widget.plano.aulasSemanais} horário(s) para este plano',
          ),
        ),
      );
      return;
    }
    setState(() => _selecionados.add(id));
  }

  void _confirmarHorarios() {
    final selecionados = _grade
        .where((item) => _selecionados.contains(item.grade.id))
        .map((item) => item.grade)
        .toList();

    Navigator.pushNamed(
      context,
      Routes.confirmarContratacao,
      arguments: {'plano': widget.plano, 'horarios': selecionados},
    );
  }

  @override
  Widget build(BuildContext context) {
    final diasComHorarios = _grade
        .map((item) => item.grade.diaSemana)
        .toSet()
        .toList()
      ..sort();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Selecione seus Horários')),
      body: _carregando
          ? const LoadingIndicator()
          : Column(
              children: [
                // Header
                Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Plano: ${widget.plano.nome}',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Selecione ${widget.plano.aulasSemanais} horário(s) fixo(s)',
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_selecionados.length}/${widget.plano.aulasSemanais} selecionado(s)',
                          style: TextStyle(
                            color: _selecionados.length ==
                                    widget.plano.aulasSemanais
                                ? AppColors.success
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Lista de horários agrupada por dia
                Expanded(
                  child: _grade.isEmpty
                      ? const Center(
                          child: Text('Nenhum horário disponível.'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 8),
                          itemCount: diasComHorarios.length,
                          itemBuilder: (context, index) {
                            final dia = diasComHorarios[index];
                            final horariosNoDia = _grade
                                .where((item) => item.grade.diaSemana == dia)
                                .toList()
                              ..sort((a, b) =>
                                  a.grade.horario.compareTo(b.grade.horario));

                            return ExpansionTile(
                              initiallyExpanded: true,
                              title: Text(
                                _diasSemana[dia] ?? 'Dia $dia',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              children: horariosNoDia.map((item) {
                                return HorarioSelecaoCard(
                                  gradeHorario: item.grade,
                                  vagasOcupadas: item.vagasOcupadas,
                                  selecionado:
                                      _selecionados.contains(item.grade.id),
                                  onTap: () => _toggleSelecao(item),
                                );
                              }).toList(),
                            );
                          },
                        ),
                ),
                // Botão confirmar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      texto: 'Confirmar Horários',
                      onPressed:
                          _selecionados.length == widget.plano.aulasSemanais
                              ? _confirmarHorarios
                              : null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
