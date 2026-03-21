import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/usuario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela admin para aprovar ou rejeitar cadastros pendentes de alunas.
class AprovarCadastrosScreen extends StatefulWidget {
  const AprovarCadastrosScreen({super.key});

  @override
  State<AprovarCadastrosScreen> createState() =>
      _AprovarCadastrosScreenState();
}

class _AprovarCadastrosScreenState extends State<AprovarCadastrosScreen> {
  final UsuarioRepository _repo = UsuarioRepository();
  List<Usuario> _pendentes = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await _repo.buscarPendentes();
      setState(() => _pendentes = lista);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar cadastros pendentes')),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _aprovar(Usuario aluna) async {
    final adminId = context.read<AuthProvider>().usuario?.id ?? '';
    try {
      await _repo.aprovar(aluna.id, adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${aluna.nome} aprovada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao aprovar cadastro')),
        );
      }
    }
  }

  Future<void> _rejeitar(Usuario aluna) async {
    final motivoController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rejeitar ${aluna.nome}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe um motivo (opcional):'),
            const SizedBox(height: 12),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                hintText: 'Motivo da rejeição',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final adminId = context.read<AuthProvider>().usuario?.id ?? '';
    final motivo =
        motivoController.text.trim().isEmpty ? null : motivoController.text.trim();

    try {
      await _repo.rejeitar(aluna.id, adminId, motivo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cadastro de ${aluna.nome} rejeitado.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao rejeitar cadastro')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Aprovar Cadastros'),
            if (!_carregando && _pendentes.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_pendentes.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _pendentes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: Colors.green.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum cadastro pendente',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _carregar,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pendentes.length,
                    itemBuilder: (context, index) =>
                        _CadastroPendenteCard(
                      aluna: _pendentes[index],
                      onAprovar: () => _aprovar(_pendentes[index]),
                      onRejeitar: () => _rejeitar(_pendentes[index]),
                    ),
                  ),
                ),
    );
  }
}

class _CadastroPendenteCard extends StatelessWidget {
  final Usuario aluna;
  final VoidCallback onAprovar;
  final VoidCallback onRejeitar;

  const _CadastroPendenteCard({
    required this.aluna,
    required this.onAprovar,
    required this.onRejeitar,
  });

  @override
  Widget build(BuildContext context) {
    final iniciais = aluna.nome
        .trim()
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join('');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.warning,
                  child: Text(
                    iniciais,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aluna.nome,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        aluna.email,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Pendente',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (aluna.telefone != null && aluna.telefone!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.phone_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    aluna.telefone!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Cadastro: ${_formatarData(aluna.dataCadastro)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Rejeitar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed: onRejeitar,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprovar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onAprovar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/'
        '${data.year}';
  }
}
