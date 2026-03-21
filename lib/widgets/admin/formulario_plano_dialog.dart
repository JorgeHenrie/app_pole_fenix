import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/plano.dart';
import '../../repositories/plano_repository.dart';
import '../common/custom_button.dart';

/// Bottom sheet para criar ou editar um plano.
class FormularioPlanoDialog extends StatefulWidget {
  final Plano? plano;

  const FormularioPlanoDialog({super.key, this.plano});

  @override
  State<FormularioPlanoDialog> createState() => _FormularioPlanoDialogState();
}

class _FormularioPlanoDialogState extends State<FormularioPlanoDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nomeController;
  late TextEditingController _descricaoController;
  late TextEditingController _valorController;
  late TextEditingController _quantidadeAulasController;
  late TextEditingController _aulasSemanaisController;
  late TextEditingController _duracaoDiasController;

  bool _ativo = true;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();

    final plano = widget.plano;

    _nomeController = TextEditingController(text: plano?.nome ?? '');
    _descricaoController =
        TextEditingController(text: plano?.descricao ?? '');
    _valorController = TextEditingController(
      text: plano != null ? plano.preco.toStringAsFixed(2) : '',
    );
    _quantidadeAulasController = TextEditingController(
      text: plano?.aulasPorMes.toString() ?? '',
    );
    _aulasSemanaisController = TextEditingController(
      text: plano?.aulasSemanais.toString() ?? '',
    );
    _duracaoDiasController = TextEditingController(
      text: plano?.duracaoDias.toString() ?? '30',
    );

    _ativo = plano?.ativo ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final isEdicao = widget.plano != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdicao ? 'Editar Plano' : 'Novo Plano',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // Nome
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Plano *',
                  hintText: 'Ex: 4 Aulas/Mês',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v?.isEmpty == true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // Descrição
              TextFormField(
                controller: _descricaoController,
                decoration: const InputDecoration(
                  labelText: 'Descrição *',
                  hintText: 'Ex: Ideal para iniciantes',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (v) =>
                    v?.isEmpty == true ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),

              // Valor
              TextFormField(
                controller: _valorController,
                decoration: const InputDecoration(
                  labelText: 'Valor (R\$) *',
                  hintText: '160.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v?.isEmpty == true) return 'Campo obrigatório';
                  if (double.tryParse(v!) == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Quantidade de aulas e aulas/semana
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantidadeAulasController,
                      decoration: const InputDecoration(
                        labelText: 'Aulas/Mês *',
                        hintText: '4',
                        prefixIcon: Icon(Icons.calendar_month),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Obrigatório';
                        if (int.tryParse(v!) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _aulasSemanaisController,
                      decoration: const InputDecoration(
                        labelText: 'Aulas/Semana *',
                        hintText: '1',
                        prefixIcon: Icon(Icons.repeat),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v?.isEmpty == true) return 'Obrigatório';
                        if (int.tryParse(v!) == null) return 'Inválido';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Duração em dias
              TextFormField(
                controller: _duracaoDiasController,
                decoration: const InputDecoration(
                  labelText: 'Duração (dias) *',
                  hintText: '30',
                  prefixIcon: Icon(Icons.timer),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v?.isEmpty == true) return 'Campo obrigatório';
                  if (int.tryParse(v!) == null) return 'Valor inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Switch Ativo/Inativo
              SwitchListTile(
                title: const Text('Plano Ativo'),
                subtitle: Text(
                  _ativo
                      ? 'Alunas podem contratar este plano'
                      : 'Plano não aparecerá para contratação',
                ),
                value: _ativo,
                onChanged: (v) => setState(() => _ativo = v),
              ),

              const SizedBox(height: 24),

              // Botões
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _carregando ? null : () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton(
                      texto: isEdicao ? 'Salvar' : 'Criar',
                      onPressed: _salvar,
                      carregando: _carregando,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _carregando = true);

    try {
      final plano = Plano(
        id: widget.plano?.id ?? const Uuid().v4(),
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim(),
        preco: double.parse(_valorController.text.trim()),
        aulasPorMes: int.parse(_quantidadeAulasController.text.trim()),
        aulasSemanais: int.parse(_aulasSemanaisController.text.trim()),
        duracaoDias: int.parse(_duracaoDiasController.text.trim()),
        ativo: _ativo,
        criadoEm: widget.plano?.criadoEm ?? DateTime.now(),
      );

      if (widget.plano == null) {
        await PlanoRepository().criar(plano);
      } else {
        await PlanoRepository().atualizar(plano);
      }

      if (mounted) Navigator.pop(context, plano);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar plano: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _quantidadeAulasController.dispose();
    _aulasSemanaisController.dispose();
    _duracaoDiasController.dispose();
    super.dispose();
  }
}
