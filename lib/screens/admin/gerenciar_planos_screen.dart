import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/plano.dart';
import '../../repositories/plano_repository.dart';
import '../../widgets/admin/formulario_plano_dialog.dart';
import '../../widgets/admin/plano_admin_card.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/dialogs/erro_dialog.dart';

/// Tela de administração de planos do estúdio.
class GerenciarPlanosScreen extends StatefulWidget {
  const GerenciarPlanosScreen({super.key});

  @override
  State<GerenciarPlanosScreen> createState() => _GerenciarPlanosScreenState();
}

class _GerenciarPlanosScreenState extends State<GerenciarPlanosScreen> {
  final PlanoRepository _planoRepository = PlanoRepository();

  List<Plano> _planos = [];
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    _carregarPlanos();
  }

  Future<void> _carregarPlanos() async {
    setState(() => _carregando = true);
    try {
      final planos = await _planoRepository.listarTodos();
      setState(() => _planos = planos);
    } catch (e) {
      if (mounted) {
        ErroDialog.mostrar(
          context: context,
          mensagem: 'Erro ao carregar planos: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _criarPlanosPadrao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Criar Planos Padrão?'),
        content: const Text(
          'Isso criará automaticamente os planos:\n\n'
          '• 4 Aulas/Mês - R\$ 160,00\n'
          '• 8 Aulas/Mês - R\$ 250,00\n\n'
          'Você poderá editá-los depois.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar Planos'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _carregando = true);

    try {
      final plano4 = Plano(
        id: const Uuid().v4(),
        nome: '4 Aulas/Mês',
        descricao: 'Ideal para iniciantes - 1x por semana',
        preco: 160.00,
        aulasPorMes: 4,
        aulasSemanais: 1,
        duracaoDias: 30,
        ativo: true,
        criadoEm: DateTime.now(),
      );

      await _planoRepository.criar(plano4);

      final plano8 = Plano(
        id: const Uuid().v4(),
        nome: '8 Aulas/Mês',
        descricao: 'Para quem quer evoluir - 2x por semana',
        preco: 250.00,
        aulasPorMes: 8,
        aulasSemanais: 2,
        duracaoDias: 30,
        ativo: true,
        criadoEm: DateTime.now(),
      );

      await _planoRepository.criar(plano8);

      await _carregarPlanos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Planos padrão criados com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErroDialog.mostrar(
          context: context,
          mensagem: 'Erro ao criar planos: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _criarNovoPlano() async {
    await _mostrarFormularioPlano(null);
  }

  Future<void> _editarPlano(Plano plano) async {
    await _mostrarFormularioPlano(plano);
  }

  Future<void> _mostrarFormularioPlano(Plano? planoExistente) async {
    final resultado = await showModalBottomSheet<Plano>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormularioPlanoDialog(
        plano: planoExistente,
      ),
    );

    if (resultado != null) {
      await _carregarPlanos();
    }
  }

  Future<void> _toggleAtivo(Plano plano) async {
    try {
      final planoAtualizado = plano.copyWith(ativo: !plano.ativo);
      await _planoRepository.atualizar(planoAtualizado);
      await _carregarPlanos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              planoAtualizado.ativo
                  ? '✅ Plano ativado'
                  : '⚠️ Plano desativado',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErroDialog.mostrar(
          context: context,
          mensagem: 'Erro ao atualizar plano: $e',
        );
      }
    }
  }

  Future<void> _confirmarDelecao(Plano plano) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir Plano?'),
        content: Text(
          "Tem certeza que deseja excluir o plano '${plano.nome}'?\n\n"
          'Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    try {
      await _planoRepository.deletar(plano.id);
      await _carregarPlanos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Plano excluído'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ErroDialog.mostrar(
          context: context,
          mensagem: 'Erro ao excluir plano: $e',
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.credit_card_off,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Nenhum plano cadastrado',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Crie planos para que as alunas possam contratar',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),
            CustomButton(
              texto: 'Criar Planos Padrão',
              onPressed: _criarPlanosPadrao,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _criarNovoPlano,
              child: const Text('Ou criar plano personalizado'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gerenciar Planos'),
        actions: [
          if (_planos.isEmpty && !_carregando)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Criar Planos Padrão',
              onPressed: _criarPlanosPadrao,
            ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_planos.length} plano(s) cadastrado(s)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _planos.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _planos.length,
                          itemBuilder: (context, index) {
                            final plano = _planos[index];
                            return PlanoAdminCard(
                              plano: plano,
                              onEditar: () => _editarPlano(plano),
                              onToggleAtivo: () => _toggleAtivo(plano),
                              onDeletar: () => _confirmarDelecao(plano),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _criarNovoPlano,
        icon: const Icon(Icons.add),
        label: const Text('Novo Plano'),
      ),
    );
  }
}
