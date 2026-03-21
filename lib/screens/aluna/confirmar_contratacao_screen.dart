import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../models/assinatura.dart';
import '../../models/grade_horario.dart';
import '../../models/horario_fixo.dart';
import '../../models/plano.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/assinatura_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../services/geracao_aulas_service.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/dialogs/erro_dialog.dart';

/// Tela de confirmação de contratação do plano.
class ConfirmarContratacaoScreen extends StatefulWidget {
  final Plano plano;
  final List<GradeHorario> horariosEscolhidos;

  const ConfirmarContratacaoScreen({
    super.key,
    required this.plano,
    required this.horariosEscolhidos,
  });

  @override
  State<ConfirmarContratacaoScreen> createState() =>
      _ConfirmarContratacaoScreenState();
}

class _ConfirmarContratacaoScreenState
    extends State<ConfirmarContratacaoScreen> {
  final AssinaturaRepository _assinaturaRepo = AssinaturaRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();
  final GeracaoAulasService _geracaoService = GeracaoAulasService();

  bool _aceitoTermos = false;
  bool _carregando = false;

  static const _diasSemana = {
    1: 'Segunda',
    2: 'Terça',
    3: 'Quarta',
    4: 'Quinta',
    5: 'Sexta',
    6: 'Sábado',
    7: 'Domingo',
  };

  Future<void> _confirmarContratacao() async {
    setState(() => _carregando = true);

    try {
      final usuario = context.read<AuthProvider>().usuario!;
      const uuid = Uuid();
      final agora = DateTime.now();

      // 1. Criar Assinatura
      final assinatura = Assinatura(
        id: uuid.v4(),
        alunaId: usuario.id,
        planoId: widget.plano.id,
        status: 'ativa',
        creditosDisponiveis: widget.plano.aulasPorMes,
        dataInicio: agora,
        dataRenovacao: agora.add(Duration(days: widget.plano.duracaoDias)),
        horarioFixoIds: const [],
        aulasRealizadas: 0,
        reposicoesDisponiveis: 0,
      );

      await _assinaturaRepo.criar(assinatura);

      // 2. Criar Horários Fixos e gerar aulas
      final List<String> horarioFixoIds = [];

      for (final gradeHorario in widget.horariosEscolhidos) {
        final horarioFixoData = HorarioFixo(
          id: '',
          alunaId: usuario.id,
          assinaturaId: assinatura.id,
          diaSemana: gradeHorario.diaSemana,
          horario: gradeHorario.horario,
          modalidade: gradeHorario.modalidade,
          ativo: true,
          criadoEm: agora,
        );

        final horarioFixoId = await _horarioFixoRepo.criar(horarioFixoData);
        final horarioFixo = horarioFixoData.copyWith(id: horarioFixoId);
        horarioFixoIds.add(horarioFixoId);

        // 3. Gerar aulas automaticamente para as próximas 4 semanas
        await _geracaoService.gerarAulasParaHorarioFixo(
          horarioFixo,
          semanas: 4,
        );
      }

      // 4. Atualizar assinatura com IDs dos horários fixos
      final assinaturaAtualizada = assinatura.copyWith(
        horarioFixoIds: horarioFixoIds,
      );
      await _assinaturaRepo.salvar(assinaturaAtualizada);

      // 5. Navegar para tela de sucesso
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(
          Routes.sucessoContratacao,
          arguments: {'horarios': widget.horariosEscolhidos},
        );
      }
    } catch (e) {
      if (mounted) {
        await ErroDialog.mostrar(
          context: context,
          mensagem: 'Erro ao processar contratação: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final headlineStyle =
        textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Confirmar Contratação')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo do plano
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Plano Selecionado', style: headlineStyle),
                    const SizedBox(height: 8),
                    Text(widget.plano.nome,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('${widget.plano.aulasPorMes} aulas/mês',
                        style: const TextStyle(
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      'R\$ ${widget.plano.preco.toStringAsFixed(2)}/mês',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Horários selecionados
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Seus Horários Fixos', style: headlineStyle),
                    const SizedBox(height: 8),
                    ...widget.horariosEscolhidos.map(
                      (h) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today,
                            color: AppColors.primary),
                        title: Text(
                          '${_diasSemana[h.diaSemana] ?? ''} às ${h.horario}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(h.modalidade),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Checkbox de aceite
            CheckboxListTile(
              value: _aceitoTermos,
              onChanged: (v) =>
                  setState(() => _aceitoTermos = v ?? false),
              title: const Text('Concordo com os termos e condições'),
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: 24),

            // Botão confirmar
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                texto: 'Confirmar Contratação',
                onPressed:
                    _aceitoTermos && !_carregando ? _confirmarContratacao : null,
                carregando: _carregando,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
