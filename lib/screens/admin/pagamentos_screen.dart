import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../models/despesa_studio.dart';
import '../../models/plano.dart';
import '../../models/usuario.dart';
import '../../repositories/assinatura_repository.dart';
import '../../repositories/despesa_studio_repository.dart';
import '../../repositories/plano_repository.dart';
import '../../repositories/usuario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class PagamentosScreen extends StatefulWidget {
  const PagamentosScreen({super.key});

  @override
  State<PagamentosScreen> createState() => _PagamentosScreenState();
}

class _PagamentosScreenState extends State<PagamentosScreen> {
  final AssinaturaRepository _assinaturaRepo = AssinaturaRepository();
  final PlanoRepository _planoRepo = PlanoRepository();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();
  final DespesaStudioRepository _despesaRepo = DespesaStudioRepository();

  final DateTime _mesAtual =
      DateTime(DateTime.now().year, DateTime.now().month);

  bool _carregando = false;
  double _receitaMensal = 0;
  double _despesasMes = 0;
  int _totalAlunasAtivas = 0;
  List<_ResumoPlano> _resumoPlanos = [];
  List<DespesaStudio> _despesas = [];
  String? _despesaExcluindoId;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final assinaturas = await _assinaturaRepo.listarAtivas();
      final despesas = await _despesaRepo.listarDoMes(_mesAtual);

      final planoIds = assinaturas.map((item) => item.planoId).toSet().toList();
      final alunaIds = assinaturas.map((item) => item.alunaId).toSet().toList();

      final planos = await Future.wait(
        planoIds
            .map((id) async => MapEntry(id, await _planoRepo.buscarPorId(id))),
      );
      final alunas = await Future.wait(
        alunaIds.map(
            (id) async => MapEntry(id, await _usuarioRepo.buscarPorId(id))),
      );

      final planosMap = <String, Plano?>{
        for (final entry in planos) entry.key: entry.value
      };
      final alunasMap = <String, Usuario?>{
        for (final entry in alunas) entry.key: entry.value
      };
      final resumoPorPlano = <String, _ResumoPlano>{};
      final alunasAtivas = <String>{};
      double receita = 0;

      for (final assinatura in assinaturas) {
        final plano = planosMap[assinatura.planoId];
        final aluna = alunasMap[assinatura.alunaId];

        if (plano == null || aluna == null || !aluna.ativo) {
          continue;
        }

        alunasAtivas.add(aluna.id);
        receita += plano.preco;

        final resumo = resumoPorPlano.putIfAbsent(
          plano.id,
          () => _ResumoPlano(
            planoId: plano.id,
            nomePlano: plano.nome,
            valorPlano: plano.preco,
          ),
        );

        resumo.quantidadeAlunas += 1;
        resumo.faturamento += plano.preco;
        if (resumo.alunasPreview.length < 3) {
          resumo.alunasPreview.add(aluna.nome);
        }
      }

      final listaResumo = resumoPorPlano.values.toList()
        ..sort((a, b) => b.faturamento.compareTo(a.faturamento));

      final totalDespesas = despesas.fold<double>(
        0,
        (total, item) => total + item.valor,
      );

      if (!mounted) return;
      setState(() {
        _receitaMensal = receita;
        _despesasMes = totalDespesas;
        _totalAlunasAtivas = alunasAtivas.length;
        _resumoPlanos = listaResumo;
        _despesas = despesas;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar painel financeiro: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _abrirNovaDespesa() async {
    final despesa = await showDialog<DespesaStudio>(
      context: context,
      builder: (_) => const _DespesaDialog(),
    );

    if (despesa == null) return;

    try {
      await _despesaRepo.criar(despesa);
      await _carregarDados();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Despesa cadastrada com sucesso.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar despesa: $e')),
        );
      }
    }
  }

  Future<void> _confirmarExclusaoDespesa(DespesaStudio despesa) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir despesa'),
        content: Text(
          'Deseja excluir a despesa "${despesa.descricao.isEmpty ? _labelCategoria(despesa.categoria) : despesa.descricao}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await _excluirDespesa(despesa);
    }
  }

  Future<void> _excluirDespesa(DespesaStudio despesa) async {
    setState(() => _despesaExcluindoId = despesa.id);

    try {
      await _despesaRepo.excluir(despesa.id);

      if (!mounted) return;

      setState(() {
        _despesas.removeWhere((item) => item.id == despesa.id);
        _despesasMes = _despesas.fold<double>(
          0,
          (total, item) => total + item.valor,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Despesa excluida com sucesso.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir despesa: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _despesaExcluindoId = null);
      }
    }
  }

  String _moeda(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  String _mesLabel(DateTime data) {
    final texto = DateFormat.MMMM('pt_BR').format(data);
    final capitalizado = texto.isEmpty
        ? texto
        : '${texto[0].toUpperCase()}${texto.substring(1)}';
    return '$capitalizado ${data.year}';
  }

  Color _corCategoria(String categoria) {
    switch (categoria) {
      case 'aluguel':
        return AppColors.primary;
      case 'agua':
        return AppColors.info;
      case 'energia':
        return AppColors.warning;
      case 'internet':
        return AppColors.secondary;
      default:
        return AppColors.greyDark;
    }
  }

  String _labelCategoria(String categoria) {
    switch (categoria) {
      case 'aluguel':
        return 'Aluguel';
      case 'agua':
        return 'Água';
      case 'energia':
        return 'Energia';
      case 'internet':
        return 'Internet';
      default:
        return 'Outros';
    }
  }

  @override
  Widget build(BuildContext context) {
    final lucro = _receitaMensal - _despesasMes;
    final ticketMedio =
        _totalAlunasAtivas == 0 ? 0.0 : _receitaMensal / _totalAlunasAtivas;
    final margemLucro = _receitaMensal <= 0 ? 0.0 : lucro / _receitaMensal;
    final planoDestaque = _resumoPlanos.isEmpty ? null : _resumoPlanos.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Painel Financeiro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarDados,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirNovaDespesa,
        icon: const Icon(Icons.add_chart),
        label: const Text('Nova Despesa'),
      ),
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregarDados,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _PainelHeader(
                    titulo: 'Visão financeira do mês',
                    subtitulo: _mesLabel(_mesAtual),
                    receita: _moeda(_receitaMensal),
                    despesas: _moeda(_despesasMes),
                    lucro: _moeda(lucro),
                    status:
                        lucro >= 0 ? 'Operação saudável' : 'Atenção ao caixa',
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largura = constraints.maxWidth;
                      final crossAxisCount = largura >= 1100
                          ? 4
                          : largura >= 700
                              ? 2
                              : 1;

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: largura >= 1100
                            ? 2.35
                            : largura >= 700
                                ? 2.05
                                : 2.7,
                        children: [
                          _ResumoCard(
                            titulo: 'Receita mensal estimada',
                            valor: _moeda(_receitaMensal),
                            detalhe: 'Planos ativos das alunas',
                            cor: AppColors.success,
                            icone: Icons.trending_up,
                          ),
                          _ResumoCard(
                            titulo: 'Despesas do mês',
                            valor: _moeda(_despesasMes),
                            detalhe: '${_despesas.length} lançamento(s)',
                            cor: AppColors.warning,
                            icone: Icons.receipt_long,
                          ),
                          _ResumoCard(
                            titulo: 'Lucro estimado',
                            valor: _moeda(lucro),
                            detalhe: lucro >= 0
                                ? 'Receita menos despesas'
                                : 'Despesas acima da receita',
                            cor: lucro >= 0
                                ? AppColors.primary
                                : AppColors.error,
                            icone: lucro >= 0
                                ? Icons.account_balance_wallet
                                : Icons.trending_down,
                          ),
                          _ResumoCard(
                            titulo: 'Alunas ativas',
                            valor: '$_totalAlunasAtivas',
                            detalhe: 'Ticket médio ${_moeda(ticketMedio)}',
                            cor: AppColors.info,
                            icone: Icons.people_alt_outlined,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final largura = constraints.maxWidth;
                      final emDuasColunas = largura >= 950;

                      final blocoPlanos = Column(
                        children: [
                          _SecaoCard(
                            titulo: 'Quantidade de alunas por plano',
                            subtitulo:
                                'Distribuição e faturamento por plano ativo',
                            acao: _MetricPill(
                              label: '${_resumoPlanos.length} plano(s)',
                              color: AppColors.primary,
                            ),
                            child: _resumoPlanos.isEmpty
                                ? const _EstadoVazioSecao(
                                    mensagem:
                                        'Nenhuma assinatura ativa encontrada.',
                                  )
                                : Column(
                                    children: [
                                      if (planoDestaque != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 18),
                                          child: _PlanoDestaqueCard(
                                            resumo: planoDestaque,
                                            formatarMoeda: _moeda,
                                          ),
                                        ),
                                      ..._resumoPlanos.map(
                                        (resumo) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 14),
                                          child: _PlanoResumoBar(
                                            resumo: resumo,
                                            maxQuantidade: _resumoPlanos
                                                .first.quantidadeAlunas,
                                            formatarMoeda: _moeda,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );

                      final blocoResumoEDespesas = Column(
                        children: [
                          _SecaoCard(
                            titulo: 'Resumo executivo',
                            subtitulo:
                                'Leitura rápida de performance e margem do mês',
                            child: Column(
                              children: [
                                _InsightTile(
                                  titulo: 'Margem operacional',
                                  valor:
                                      '${(margemLucro * 100).clamp(-999, 999).toStringAsFixed(1)}%',
                                  detalhe: lucro >= 0
                                      ? 'Lucro sobre a receita estimada'
                                      : 'Resultado negativo no mês',
                                  color: lucro >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                  progress: margemLucro.isNaN
                                      ? 0
                                      : margemLucro.abs().clamp(0.0, 1.0),
                                ),
                                const SizedBox(height: 12),
                                _InsightTile(
                                  titulo: 'Ticket médio por aluna',
                                  valor: _moeda(ticketMedio),
                                  detalhe: 'Baseado nas alunas com plano ativo',
                                  color: AppColors.info,
                                  progress: _totalAlunasAtivas == 0
                                      ? 0
                                      : (ticketMedio /
                                              (_receitaMensal == 0
                                                  ? 1
                                                  : _receitaMensal))
                                          .clamp(0.0, 1.0),
                                ),
                                const SizedBox(height: 12),
                                _InsightTile(
                                  titulo: 'Comprometimento com despesas',
                                  valor: _receitaMensal == 0
                                      ? '0%'
                                      : '${((_despesasMes / _receitaMensal) * 100).clamp(0, 999).toStringAsFixed(1)}%',
                                  detalhe:
                                      'Percentual da receita usado para custos',
                                  color: AppColors.warning,
                                  progress: _receitaMensal == 0
                                      ? 0
                                      : (_despesasMes / _receitaMensal)
                                          .clamp(0.0, 1.0),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SecaoCard(
                            titulo: 'Despesas operacionais',
                            subtitulo:
                                'Aluguel, água, energia e demais custos do estúdio',
                            acao: TextButton.icon(
                              onPressed: _abrirNovaDespesa,
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Cadastrar'),
                            ),
                            child: _despesas.isEmpty
                                ? const _EstadoVazioSecao(
                                    mensagem:
                                        'Nenhuma despesa lançada neste mês.',
                                  )
                                : Column(
                                    children: _despesas
                                        .map(
                                          (despesa) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 10),
                                            child: _DespesaTile(
                                              despesa: despesa,
                                              corCategoria: _corCategoria(
                                                  despesa.categoria),
                                              categoriaLabel: _labelCategoria(
                                                  despesa.categoria),
                                              formatarMoeda: _moeda,
                                              onExcluir: () =>
                                                  _confirmarExclusaoDespesa(
                                                      despesa),
                                              excluindo: _despesaExcluindoId ==
                                                  despesa.id,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                          ),
                        ],
                      );

                      if (emDuasColunas) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: blocoPlanos),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: blocoResumoEDespesas),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          blocoPlanos,
                          const SizedBox(height: 16),
                          blocoResumoEDespesas,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

class _ResumoPlano {
  final String planoId;
  final String nomePlano;
  final double valorPlano;
  int quantidadeAlunas = 0;
  double faturamento = 0;
  final List<String> alunasPreview;

  _ResumoPlano({
    required this.planoId,
    required this.nomePlano,
    required this.valorPlano,
    List<String>? alunasPreview,
  }) : alunasPreview = alunasPreview ?? [];
}

class _PainelHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String receita;
  final String despesas;
  final String lucro;
  final String status;

  const _PainelHeader({
    required this.titulo,
    required this.subtitulo,
    required this.receita,
    required this.despesas,
    required this.lucro,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.secondary
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 52,
            bottom: -22,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitulo,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeaderStatusPill(status: status),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _HeaderMetric(label: 'Receita', valor: receita),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderMetric(label: 'Despesas', valor: despesas),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeaderMetric(label: 'Lucro', valor: lucro),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStatusPill extends StatelessWidget {
  final String status;

  const _HeaderStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        status,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String valor;

  const _HeaderMetric({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalhe;
  final Color cor;
  final IconData icone;

  const _ResumoCard({
    required this.titulo,
    required this.valor,
    required this.detalhe,
    required this.cor,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    valor,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detalhe,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecaoCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;
  final Widget? acao;

  const _SecaoCard({
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.acao,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitulo,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (acao != null) acao!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MetricPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _PlanoDestaqueCard extends StatelessWidget {
  final _ResumoPlano resumo;
  final String Function(double valor) formatarMoeda;

  const _PlanoDestaqueCard({
    required this.resumo,
    required this.formatarMoeda,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.10),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MetricPill(
              label: 'Plano em destaque', color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            resumo.nomePlano,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${resumo.quantidadeAlunas} aluna(s) ativas • ${formatarMoeda(resumo.faturamento)} no mês',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanoResumoBar extends StatelessWidget {
  final _ResumoPlano resumo;
  final int maxQuantidade;
  final String Function(double valor) formatarMoeda;

  const _PlanoResumoBar({
    required this.resumo,
    required this.maxQuantidade,
    required this.formatarMoeda,
  });

  @override
  Widget build(BuildContext context) {
    final fator =
        maxQuantidade == 0 ? 0.0 : resumo.quantidadeAlunas / maxQuantidade;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  resumo.nomePlano,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _MetricPill(
                label: '${resumo.quantidadeAlunas} aluna(s)',
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 10,
              color: AppColors.greyLight,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fator.clamp(0.0, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Plano ${formatarMoeda(resumo.valorPlano)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                formatarMoeda(resumo.faturamento),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (resumo.alunasPreview.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              resumo.alunasPreview.join(' • '),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final String titulo;
  final String valor;
  final String detalhe;
  final Color color;
  final double progress;

  const _InsightTile({
    required this.titulo,
    required this.valor,
    required this.detalhe,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                valor,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            detalhe,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DespesaTile extends StatelessWidget {
  final DespesaStudio despesa;
  final Color corCategoria;
  final String categoriaLabel;
  final String Function(double valor) formatarMoeda;
  final VoidCallback onExcluir;
  final bool excluindo;

  const _DespesaTile({
    required this.despesa,
    required this.corCategoria,
    required this.categoriaLabel,
    required this.formatarMoeda,
    required this.onExcluir,
    required this.excluindo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: corCategoria.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt, color: corCategoria, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        despesa.descricao.isEmpty
                            ? categoriaLabel
                            : despesa.descricao,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _MetricPill(label: categoriaLabel, color: corCategoria),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy').format(despesa.dataReferencia),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            formatarMoeda(despesa.valor),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            height: 40,
            child: excluindo
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    onPressed: onExcluir,
                    tooltip: 'Excluir despesa',
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazioSecao extends StatelessWidget {
  final String mensagem;

  const _EstadoVazioSecao({required this.mensagem});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 36,
              color: AppColors.grey.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
            Text(
              mensagem,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DespesaDialog extends StatefulWidget {
  const _DespesaDialog();

  @override
  State<_DespesaDialog> createState() => _DespesaDialogState();
}

class _DespesaDialogState extends State<_DespesaDialog> {
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  String _categoria = 'aluguel';
  bool _salvando = false;

  @override
  void dispose() {
    _descricaoController.dispose();
    _valorController.dispose();
    super.dispose();
  }

  double? _parseValor(String texto) {
    final normalizado = texto.replaceAll('.', '').replaceAll(',', '.').trim();
    return double.tryParse(normalizado);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cadastrar Despesa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _categoria,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'aluguel', child: Text('Aluguel')),
                DropdownMenuItem(value: 'agua', child: Text('Água')),
                DropdownMenuItem(value: 'energia', child: Text('Energia')),
                DropdownMenuItem(value: 'internet', child: Text('Internet')),
                DropdownMenuItem(value: 'outros', child: Text('Outros')),
              ],
              onChanged: (valor) {
                if (valor != null) {
                  setState(() => _categoria = valor);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descricaoController,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                border: OutlineInputBorder(),
                hintText: 'Ex.: aluguel do estúdio',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valorController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor',
                border: OutlineInputBorder(),
                hintText: '1500,00',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _salvando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _salvando
              ? null
              : () {
                  final valor = _parseValor(_valorController.text);
                  if (valor == null || valor <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe um valor válido.')),
                    );
                    return;
                  }

                  setState(() => _salvando = true);

                  final agora = DateTime.now();
                  Navigator.pop(
                    context,
                    DespesaStudio(
                      id: '',
                      categoria: _categoria,
                      descricao: _descricaoController.text.trim(),
                      valor: valor,
                      dataReferencia: agora,
                      criadoEm: agora,
                    ),
                  );
                },
          child: _salvando
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
