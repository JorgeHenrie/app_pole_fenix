import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/solicitacao_mudanca_horario.dart';
import '../../repositories/solicitacao_mudanca_horario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class AprovarSolicitacoesScreen extends StatefulWidget {
  const AprovarSolicitacoesScreen({super.key});

  @override
  State<AprovarSolicitacoesScreen> createState() =>
      _AprovarSolicitacoesScreenState();
}

class _AprovarSolicitacoesScreenState extends State<AprovarSolicitacoesScreen> {
  final SolicitacaoMudancaHorarioRepository _repo =
      SolicitacaoMudancaHorarioRepository();
  List<SolicitacaoMudancaHorario> _solicitacoes = [];
  bool _carregando = false;
  String? _erroCarregamento;

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
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final solicitacoes = await _repo.listarPendentes();
      if (!mounted) return;
      setState(() {
        _solicitacoes = solicitacoes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCarregamento =
            'Nao foi possivel carregar as solicitacoes pendentes.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar solicitacoes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Solicitações de Mudança'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _erroCarregamento != null && _solicitacoes.isEmpty
              ? _buildEstadoErro()
              : _solicitacoes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.task_alt,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma solicitação pendente',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _solicitacoes.length,
                        itemBuilder: (context, index) {
                          final solicitacao = _solicitacoes[index];
                          return _SolicitacaoCard(
                            solicitacao: solicitacao,
                            diasSemana: _diasSemana,
                            onResponder: (status, resposta) async {
                              try {
                                await _repo.responder(
                                  solicitacao.id,
                                  status,
                                  resposta,
                                  'admin',
                                );
                                if (!mounted) return;
                                setState(() {
                                  _solicitacoes.removeWhere(
                                      (item) => item.id == solicitacao.id);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      status == 'aprovada'
                                          ? 'Solicitacao aprovada.'
                                          : 'Solicitacao rejeitada.',
                                    ),
                                    backgroundColor: status == 'aprovada'
                                        ? Colors.green
                                        : AppColors.error,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Erro ao responder solicitacao: $e'),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEstadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _erroCarregamento ?? 'Erro ao carregar solicitacoes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SolicitacaoCard extends StatelessWidget {
  final SolicitacaoMudancaHorario solicitacao;
  final Map<int, String> diasSemana;
  final Future<void> Function(String status, String? resposta) onResponder;

  const _SolicitacaoCard({
    required this.solicitacao,
    required this.diasSemana,
    required this.onResponder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aluna: ${solicitacao.alunaId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Novo horário: ${diasSemana[solicitacao.novoDiaSemana] ?? 'Dia ${solicitacao.novoDiaSemana}'} às ${solicitacao.novoHorario}',
            ),
            if (solicitacao.motivo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Motivo: ${solicitacao.motivo}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              'Solicitado em: ${DateFormatter.data(solicitacao.solicitadoEm)}',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarResposta(context, 'rejeitada'),
                    icon: const Icon(Icons.close, color: AppColors.error),
                    label: const Text('Rejeitar',
                        style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarResposta(context, 'aprovada'),
                    icon: const Icon(Icons.check),
                    label: const Text('Aprovar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _mostrarResposta(BuildContext context, String status) async {
    final controller = TextEditingController();
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(status == 'aprovada'
            ? 'Aprovar Solicitação'
            : 'Rejeitar Solicitação'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: status == 'aprovada'
                ? 'Comentário (opcional)'
                : 'Motivo da rejeição (opcional)',
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      await onResponder(
          status, controller.text.isNotEmpty ? controller.text : null);
    }
    controller.dispose();
  }
}
