import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/jornada_movimento.dart';
import '../../models/movimento_pole.dart';
import '../../models/usuario.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/jornada_movimento_repository.dart';
import '../../repositories/movimento_pole_repository.dart';
import '../../repositories/nivel_dificuldade_movimento_repository.dart';
import '../../repositories/usuario_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class GerenciarJornadaScreen extends StatefulWidget {
  const GerenciarJornadaScreen({super.key});

  @override
  State<GerenciarJornadaScreen> createState() => _GerenciarJornadaScreenState();
}

class _GerenciarJornadaScreenState extends State<GerenciarJornadaScreen> {
  final MovimentoPoleRepository _movimentoRepo = MovimentoPoleRepository();
  final JornadaMovimentoRepository _jornadaRepo = JornadaMovimentoRepository();
  final NivelDificuldadeMovimentoRepository _nivelRepo =
      NivelDificuldadeMovimentoRepository();
  final UsuarioRepository _usuarioRepo = UsuarioRepository();

  bool _carregando = false;
  String _buscaMovimento = '';
  String _buscaAluna = '';
  List<MovimentoPole> _movimentos = [];
  List<NivelDificuldadeMovimento> _niveis = [];
  List<Usuario> _alunas = [];
  Map<String, int> _conquistasPorAluna = {};

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);

    try {
      final resultados = await Future.wait([
        _movimentoRepo.listarTodos(),
        _nivelRepo.listarTodos(),
        _usuarioRepo.listarAlunasAtivasAprovadas(),
        _jornadaRepo.listarTodas(),
      ]);

      final movimentos = resultados[0] as List<MovimentoPole>;
      final niveis = resultados[1] as List<NivelDificuldadeMovimento>;
      final alunas = resultados[2] as List<Usuario>;
      final jornadas = resultados[3] as List<JornadaMovimento>;
      final contagem = <String, int>{};

      for (final jornada in jornadas) {
        contagem[jornada.alunaId] = (contagem[jornada.alunaId] ?? 0) + 1;
      }

      if (!mounted) return;
      setState(() {
        _movimentos = movimentos;
        _niveis = niveis;
        _alunas = alunas;
        _conquistasPorAluna = contagem;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar jornada: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<bool> _abrirFormularioMovimento({
    BuildContext? targetContext,
    MovimentoPole? existente,
    NivelDificuldadeMovimento? nivelPreSelecionado,
    bool bloquearNivel = false,
  }) async {
    final currentContext = targetContext ?? context;
    final niveisDisponiveis = _niveis
        .where(
          (nivel) =>
              nivel.ativo ||
              nivel.id == existente?.nivel.id ||
              nivel.id == nivelPreSelecionado?.id,
        )
        .toList()
      ..sort((a, b) {
        final porOrdem = a.ordem.compareTo(b.ordem);
        if (porOrdem != 0) return porOrdem;
        return a.label.compareTo(b.label);
      });

    if (nivelPreSelecionado != null &&
        niveisDisponiveis.every(
          (nivel) => nivel.id != nivelPreSelecionado.id,
        )) {
      niveisDisponiveis.add(nivelPreSelecionado);
      niveisDisponiveis.sort((a, b) {
        final porOrdem = a.ordem.compareTo(b.ordem);
        if (porOrdem != 0) return porOrdem;
        return a.label.compareTo(b.label);
      });
    }

    if (niveisDisponiveis.isEmpty) {
      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('Cadastre ao menos um nível de dificuldade primeiro.'),
        ),
      );
      return false;
    }

    final resultado = await showModalBottomSheet<_FormularioMovimentoResultado>(
      context: currentContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioMovimentoSheet(
        movimento: existente,
        niveisDisponiveis: niveisDisponiveis,
        nivelInicial: nivelPreSelecionado,
        nivelBloqueado: bloquearNivel,
      ),
    );

    if (resultado == null) return false;

    final adminId = context.read<AuthProvider>().usuario?.id ?? '';

    try {
      if (existente == null) {
        final movimento = MovimentoPole(
          id: '',
          nome: resultado.nome,
          categoria: resultado.categoria,
          nivel: resultado.nivel,
          ativo: resultado.ativo,
          criadoPor: adminId,
          criadoEm: DateTime.now(),
        );

        await _movimentoRepo.criar(movimento);
      } else {
        final movimentoAtualizado = existente.copyWith(
          nome: resultado.nome,
          categoria: resultado.categoria,
          nivel: resultado.nivel,
          ativo: resultado.ativo,
          atualizadoEm: DateTime.now(),
        );

        await _movimentoRepo.atualizar(movimentoAtualizado);
        await _jornadaRepo.sincronizarMovimento(movimentoAtualizado);
      }

      if (mounted) {
        await _carregarDados();
      }
      if (!currentContext.mounted) return true;

      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(
          content: Text(
            existente == null
                ? 'Movimento cadastrado com sucesso.'
                : 'Movimento atualizado com sucesso.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      return true;
    } on StateError catch (e) {
      if (!currentContext.mounted) return false;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!currentContext.mounted) return false;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Erro ao salvar movimento: $e')),
      );
    }

    return false;
  }

  Future<bool> _excluirMovimento(
    MovimentoPole movimento, {
    BuildContext? targetContext,
  }) async {
    final currentContext = targetContext ?? context;
    final confirmar = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('Excluir movimento?'),
        content: Text(
          'Deseja excluir o movimento ${movimento.nome}?\n\n'
          'Se ele já estiver liberado para alguma aluna, a exclusão será bloqueada.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmar != true) return false;

    try {
      await _movimentoRepo.deletar(movimento.id);
      if (mounted) {
        await _carregarDados();
      }
      if (!currentContext.mounted) return true;

      ScaffoldMessenger.of(currentContext).showSnackBar(
        const SnackBar(
          content: Text('Movimento excluído.'),
          backgroundColor: AppColors.success,
        ),
      );
      return true;
    } on StateError catch (e) {
      if (!currentContext.mounted) return false;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!currentContext.mounted) return false;
      ScaffoldMessenger.of(currentContext).showSnackBar(
        SnackBar(content: Text('Erro ao excluir movimento: $e')),
      );
    }

    return false;
  }

  Future<void> _abrirJornadaAluna(Usuario aluna) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _JornadaAlunaSheet(
        aluna: aluna,
        movimentos: _movimentos,
        jornadaRepo: _jornadaRepo,
        onAtualizado: _carregarDados,
      ),
    );
  }

  Future<void> _abrirFormularioNivel([
    NivelDificuldadeMovimento? existente,
  ]) async {
    final resultado = await showModalBottomSheet<_FormularioNivelResultado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioNivelSheet(nivel: existente),
    );

    if (resultado == null) return;

    try {
      final nivel = (existente ??
              NivelDificuldadeMovimento.fromEmbedded(
                id: '',
                label: resultado.nome,
                descricao: resultado.descricao,
                ordem: resultado.ordem,
                ativo: resultado.ativo,
              ))
          .copyWith(
        label: resultado.nome,
        descricao: resultado.descricao,
        ordem: resultado.ordem,
        ativo: resultado.ativo,
      );

      await _nivelRepo.salvar(nivel);

      final nivelPersistido = nivel.copyWith(
        id: nivel.id.trim().isEmpty
            ? NivelDificuldadeMovimento.normalizarId(resultado.nome)
            : nivel.id,
      );

      await _movimentoRepo.sincronizarNivel(nivelPersistido);
      await _jornadaRepo.sincronizarNivel(nivelPersistido);
      await _carregarDados();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existente == null
                ? 'Nível cadastrado com sucesso.'
                : 'Nível atualizado com sucesso.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar nível: $e')),
      );
    }
  }

  Future<void> _abrirGerenciarNiveis() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GerenciarNiveisSheet(
        niveis: _niveis,
        onNovoNivel: () => _abrirFormularioNivel(),
        onEditarNivel: _abrirFormularioNivel,
      ),
    );
  }

  Future<void> _abrirMovimentosDoNivel(
    NivelDificuldadeMovimento nivel,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _MovimentosDoNivelScreen(
          nivelInicial: nivel,
          carregarMovimentos: _movimentoRepo.listarTodos,
          carregarNiveis: () => _nivelRepo.listarTodos(),
          onNovoMovimento: (context, nivelSelecionado) {
            return _abrirFormularioMovimento(
              targetContext: context,
              nivelPreSelecionado: nivelSelecionado,
              bloquearNivel: true,
            );
          },
          onEditarMovimento: (context, movimento) {
            return _abrirFormularioMovimento(
              targetContext: context,
              existente: movimento,
            );
          },
          onExcluirMovimento: (context, movimento) {
            return _excluirMovimento(
              movimento,
              targetContext: context,
            );
          },
        ),
      ),
    );

    if (!mounted) return;
    await _carregarDados();
  }

  List<_ResumoNivelMovimentos> _montarCardsNiveis() {
    final niveisPorId = <String, NivelDificuldadeMovimento>{
      for (final nivel in _niveis) nivel.id: nivel,
    };
    final movimentosPorNivel = <String, List<MovimentoPole>>{};

    for (final movimento in _movimentos) {
      niveisPorId.putIfAbsent(movimento.nivel.id, () => movimento.nivel);
      movimentosPorNivel.putIfAbsent(movimento.nivel.id, () => []).add(
            movimento,
          );
    }

    final termo = _buscaMovimento.trim().toLowerCase();
    final niveisOrdenados = niveisPorId.values.toList()
      ..sort((a, b) {
        final porOrdem = a.ordem.compareTo(b.ordem);
        if (porOrdem != 0) return porOrdem;
        return a.label.compareTo(b.label);
      });

    return niveisOrdenados.where((nivel) {
      final movimentosNivel =
          movimentosPorNivel[nivel.id] ?? const <MovimentoPole>[];
      if (termo.isEmpty) return true;

      final correspondeNivel = nivel.label.toLowerCase().contains(termo) ||
          nivel.descricao.toLowerCase().contains(termo);
      final correspondeMovimento = movimentosNivel.any(
        (movimento) =>
            movimento.nome.toLowerCase().contains(termo) ||
            movimento.categoria.label.toLowerCase().contains(termo),
      );

      return correspondeNivel || correspondeMovimento;
    }).map((nivel) {
      return _ResumoNivelMovimentos(
        nivel: nivel,
        movimentos: List<MovimentoPole>.unmodifiable(
          movimentosPorNivel[nivel.id] ?? const <MovimentoPole>[],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final niveisVisiveis = _montarCardsNiveis();

    final alunasFiltradas = _alunas.where((aluna) {
      final termo = _buscaAluna.trim().toLowerCase();
      if (termo.isEmpty) return true;
      return aluna.nome.toLowerCase().contains(termo) ||
          aluna.email.toLowerCase().contains(termo);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gerenciar Jornada'),
        actions: [
          IconButton(
            onPressed: _carregarDados,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _PainelResumoJornada(
                      totalMovimentos: _movimentos.length,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      tabs: [
                        Tab(text: 'Movimentos'),
                        Tab(text: 'Alunas'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAbaMovimentos(niveisVisiveis),
                        _buildAbaAlunas(alunasFiltradas),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAbaMovimentos(List<_ResumoNivelMovimentos> niveisVisiveis) {
    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (valor) => setState(() => _buscaMovimento = valor),
            decoration: InputDecoration(
              hintText: 'Buscar nível, descrição ou movimento',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _abrirGerenciarNiveis,
              icon: const Icon(Icons.layers_outlined),
              label: const Text('Gerenciar níveis'),
            ),
          ),
          const SizedBox(height: 16),
          if (niveisVisiveis.isEmpty)
            const _EstadoVazioJornada(
              icone: Icons.search_off_rounded,
              titulo: 'Nenhum nível encontrado',
              mensagem:
                  'Tente buscar por outro nome, descrição ou por um movimento já cadastrado.',
            )
          else
            ...niveisVisiveis.map(
              (resumo) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NivelJornadaCard(
                  nivel: resumo.nivel,
                  movimentos: resumo.movimentos,
                  onTap: () => _abrirMovimentosDoNivel(resumo.nivel),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAbaAlunas(List<Usuario> alunasFiltradas) {
    return RefreshIndicator(
      onRefresh: _carregarDados,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            onChanged: (valor) => setState(() => _buscaAluna = valor),
            decoration: InputDecoration(
              hintText: 'Buscar aluna por nome ou e-mail',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (alunasFiltradas.isEmpty)
            const _EstadoVazioJornada(
              icone: Icons.person_search_outlined,
              titulo: 'Nenhuma aluna encontrada',
              mensagem:
                  'Quando houver alunas aprovadas, você poderá liberar movimentos nesta área.',
            )
          else
            ...alunasFiltradas.map(
              (aluna) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _AlunaJornadaCard(
                  aluna: aluna,
                  quantidadeMovimentos: _conquistasPorAluna[aluna.id] ?? 0,
                  onTap: () => _abrirJornadaAluna(aluna),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PainelResumoJornada extends StatelessWidget {
  final int totalMovimentos;

  const _PainelResumoJornada({
    required this.totalMovimentos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.accentCocoa
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Jornada das alunas',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cadastre os movimentos da jornada e organize a evolução visual de cada aluna.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 18),
          _ResumoPill(
            titulo: 'Movimentos',
            valor: '$totalMovimentos',
          ),
        ],
      ),
    );
  }
}

class _ResumoPill extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ResumoPill({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            valor,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MovimentoAdminCard extends StatelessWidget {
  final MovimentoPole movimento;
  final VoidCallback onEditar;
  final VoidCallback onExcluir;

  const _MovimentoAdminCard({
    required this.movimento,
    required this.onEditar,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: movimento.nivel.cor.withValues(alpha: 0.16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: movimento.nivel.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_motion_outlined,
                  color: movimento.nivel.cor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movimento.nome,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _CategoriaBadge(categoria: movimento.categoria),
                        _NivelBadge(nivel: movimento.nivel),
                        _TagStatusMovimento(ativo: movimento.ativo),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (valor) {
                  if (valor == 'editar') onEditar();
                  if (valor == 'excluir') onExcluir();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'editar', child: Text('Editar')),
                  PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoriaBadge extends StatelessWidget {
  final CategoriaMovimentoPole categoria;

  const _CategoriaBadge({required this.categoria});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: categoria.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        categoria.label,
        style: TextStyle(
          color: categoria.cor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AlunaJornadaCard extends StatelessWidget {
  final Usuario aluna;
  final int quantidadeMovimentos;
  final VoidCallback onTap;

  const _AlunaJornadaCard({
    required this.aluna,
    required this.quantidadeMovimentos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iniciais = aluna.nome
        .trim()
        .split(' ')
        .take(2)
        .map((parte) => parte.isNotEmpty ? parte[0].toUpperCase() : '')
        .join();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary,
          backgroundImage:
              aluna.fotoUrl != null ? NetworkImage(aluna.fotoUrl!) : null,
          child: aluna.fotoUrl == null
              ? Text(
                  iniciais,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : null,
        ),
        title: Text(
          aluna.nome,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            quantidadeMovimentos == 0
                ? 'Nenhum movimento liberado ainda'
                : '$quantidadeMovimentos movimento(s) conquistado(s)',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EstadoVazioJornada extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String mensagem;

  const _EstadoVazioJornada({
    required this.icone,
    required this.titulo,
    required this.mensagem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icone, size: 54, color: AppColors.primaryLight),
          const SizedBox(height: 14),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            mensagem,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoNivelMovimentos {
  final NivelDificuldadeMovimento nivel;
  final List<MovimentoPole> movimentos;

  const _ResumoNivelMovimentos({
    required this.nivel,
    required this.movimentos,
  });
}

class _NivelJornadaCard extends StatelessWidget {
  final NivelDificuldadeMovimento nivel;
  final List<MovimentoPole> movimentos;
  final VoidCallback onTap;

  const _NivelJornadaCard({
    required this.nivel,
    required this.movimentos,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: nivel.cor.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: nivel.cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.layers_outlined, color: nivel.cor),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nivel.label,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          nivel.descricao,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _BadgeTexto(
                    texto: '${movimentos.length} movimento(s)',
                  ),
                  _BadgeTexto(texto: nivel.ativo ? 'Ativo' : 'Inativo'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovimentosDoNivelScreen extends StatefulWidget {
  final NivelDificuldadeMovimento nivelInicial;
  final Future<List<MovimentoPole>> Function() carregarMovimentos;
  final Future<List<NivelDificuldadeMovimento>> Function() carregarNiveis;
  final Future<bool> Function(
    BuildContext context,
    NivelDificuldadeMovimento nivel,
  ) onNovoMovimento;
  final Future<bool> Function(
    BuildContext context,
    MovimentoPole movimento,
  ) onEditarMovimento;
  final Future<bool> Function(
    BuildContext context,
    MovimentoPole movimento,
  ) onExcluirMovimento;

  const _MovimentosDoNivelScreen({
    required this.nivelInicial,
    required this.carregarMovimentos,
    required this.carregarNiveis,
    required this.onNovoMovimento,
    required this.onEditarMovimento,
    required this.onExcluirMovimento,
  });

  @override
  State<_MovimentosDoNivelScreen> createState() =>
      _MovimentosDoNivelScreenState();
}

class _MovimentosDoNivelScreenState extends State<_MovimentosDoNivelScreen> {
  bool _carregando = true;
  String _busca = '';
  late NivelDificuldadeMovimento _nivel;
  List<MovimentoPole> _movimentos = [];

  @override
  void initState() {
    super.initState();
    _nivel = widget.nivelInicial;
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);

    try {
      final resultados = await Future.wait([
        widget.carregarMovimentos(),
        widget.carregarNiveis(),
      ]);

      final movimentos = resultados[0] as List<MovimentoPole>;
      final niveis = resultados[1] as List<NivelDificuldadeMovimento>;

      var nivelAtual = _nivel;
      for (final item in niveis) {
        if (item.id == _nivel.id) {
          nivelAtual = item;
          break;
        }
      }

      final movimentosDoNivel = movimentos
          .where((movimento) => movimento.nivel.id == nivelAtual.id)
          .toList()
        ..sort((a, b) {
          final porAtivo = a.ativo == b.ativo ? 0 : (a.ativo ? -1 : 1);
          if (porAtivo != 0) return porAtivo;
          return a.nome.compareTo(b.nome);
        });

      if (!mounted) return;
      setState(() {
        _nivel = nivelAtual;
        _movimentos = movimentosDoNivel;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar movimentos do nível: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _novoMovimento() async {
    if (!_nivel.ativo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ative esse nível em Gerenciar níveis para cadastrar novos movimentos.',
          ),
        ),
      );
      return;
    }

    final alterou = await widget.onNovoMovimento(context, _nivel);
    if (!alterou) return;
    await _carregar();
  }

  Future<void> _editarMovimento(MovimentoPole movimento) async {
    final alterou = await widget.onEditarMovimento(context, movimento);
    if (!alterou) return;
    await _carregar();
  }

  Future<void> _excluirMovimento(MovimentoPole movimento) async {
    final alterou = await widget.onExcluirMovimento(context, movimento);
    if (!alterou) return;
    await _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final termo = _busca.trim().toLowerCase();
    final movimentosFiltrados = _movimentos.where((movimento) {
      if (termo.isEmpty) return true;
      return movimento.nome.toLowerCase().contains(termo) ||
          movimento.categoria.label.toLowerCase().contains(termo);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_nivel.label),
        actions: [
          IconButton(
            onPressed: _carregar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _nivel.ativo
          ? FloatingActionButton.extended(
              onPressed: _novoMovimento,
              backgroundColor: _nivel.cor,
              foregroundColor: Colors.white,
              elevation: 6,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Novo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _nivel.cor.withValues(alpha: 0.22),
                          _nivel.cor.withValues(alpha: 0.10),
                          Colors.white,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _nivel.cor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: _nivel.cor.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.auto_awesome_motion_outlined,
                                color: _nivel.cor,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Movimentos do ${_nivel.label}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _nivel.descricao,
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      height: 1.45,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _BadgeTexto(
                              texto: '${_movimentos.length} movimento(s)',
                            ),
                            _BadgeTexto(
                              texto: _nivel.ativo ? 'Ativo' : 'Inativo',
                            ),
                          ],
                        ),
                        if (!_nivel.ativo) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Esse nível está inativo. Ative-o para cadastrar novos movimentos aqui.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (valor) => setState(() => _busca = valor),
                    decoration: InputDecoration(
                      hintText:
                          'Buscar movimento ou categoria em ${_nivel.label}',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (movimentosFiltrados.isEmpty)
                    _EstadoVazioJornada(
                      icone: Icons.auto_awesome_motion_outlined,
                      titulo: _movimentos.isEmpty
                          ? 'Nenhum movimento neste nível'
                          : 'Nenhum movimento encontrado',
                      mensagem: _movimentos.isEmpty
                          ? 'Cadastre o primeiro movimento do nível ${_nivel.label.toLowerCase()}.'
                          : 'Tente buscar por outro nome ou categoria dentro deste nível.',
                    )
                  else
                    ...movimentosFiltrados.map(
                      (movimento) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MovimentoAdminCard(
                          movimento: movimento,
                          onEditar: () => _editarMovimento(movimento),
                          onExcluir: () => _excluirMovimento(movimento),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _NivelBadge extends StatelessWidget {
  final NivelDificuldadeMovimento nivel;

  const _NivelBadge({required this.nivel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: nivel.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        nivel.label,
        style: TextStyle(
          color: nivel.cor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TagStatusMovimento extends StatelessWidget {
  final bool ativo;

  const _TagStatusMovimento({required this.ativo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (ativo ? AppColors.success : AppColors.textSecondary)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        ativo ? 'Ativo' : 'Inativo',
        style: TextStyle(
          color: ativo ? AppColors.success : AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FormularioMovimentoResultado {
  final String nome;
  final CategoriaMovimentoPole categoria;
  final NivelDificuldadeMovimento nivel;
  final bool ativo;

  const _FormularioMovimentoResultado({
    required this.nome,
    required this.categoria,
    required this.nivel,
    required this.ativo,
  });
}

class _FormularioMovimentoSheet extends StatefulWidget {
  final MovimentoPole? movimento;
  final List<NivelDificuldadeMovimento> niveisDisponiveis;
  final NivelDificuldadeMovimento? nivelInicial;
  final bool nivelBloqueado;

  const _FormularioMovimentoSheet({
    this.movimento,
    required this.niveisDisponiveis,
    this.nivelInicial,
    this.nivelBloqueado = false,
  });

  @override
  State<_FormularioMovimentoSheet> createState() =>
      _FormularioMovimentoSheetState();
}

class _FormularioMovimentoSheetState extends State<_FormularioMovimentoSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late CategoriaMovimentoPole _categoria;
  late NivelDificuldadeMovimento _nivel;
  late bool _ativo;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.movimento?.nome ?? '');
    _categoria =
        widget.movimento?.categoria ?? CategoriaMovimentoPole.movimentoEstatico;
    _nivel = widget.movimento?.nivel ??
        widget.nivelInicial ??
        widget.niveisDisponiveis.first;
    _ativo = widget.movimento?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _FormularioMovimentoResultado(
        nome: _nomeController.text.trim(),
        categoria: _categoria,
        nivel: _nivel,
        ativo: _ativo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.movimento == null
                        ? 'Novo movimento'
                        : 'Editar movimento',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Cadastre o movimento com nome, categoria e nível para poder liberar na jornada das alunas.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do movimento',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe o nome do movimento.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CategoriaMovimentoPole>(
                    initialValue: _categoria,
                    items: CategoriaMovimentoPole.values
                        .map(
                          (categoria) => DropdownMenuItem(
                            value: categoria,
                            child: Text(categoria.label),
                          ),
                        )
                        .toList(),
                    onChanged: (valor) {
                      if (valor == null) return;
                      setState(() => _categoria = valor);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Categoria',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.nivelBloqueado)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Nível de dificuldade',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _nivel.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    DropdownButtonFormField<NivelDificuldadeMovimento>(
                      initialValue: _nivel,
                      items: widget.niveisDisponiveis
                          .map(
                            (nivel) => DropdownMenuItem(
                              value: nivel,
                              child: Text(nivel.label),
                            ),
                          )
                          .toList(),
                      onChanged: (valor) {
                        if (valor == null) return;
                        setState(() => _nivel = valor);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Nível de dificuldade',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _ativo,
                    onChanged: (valor) => setState(() => _ativo = valor),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Disponível para novas liberações'),
                    subtitle: const Text(
                      'Movimentos inativos ficam ocultos na hora de liberar para as alunas.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _salvar,
                          child: Text(
                            widget.movimento == null ? 'Cadastrar' : 'Salvar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GerenciarNiveisSheet extends StatelessWidget {
  final List<NivelDificuldadeMovimento> niveis;
  final Future<void> Function() onNovoNivel;
  final Future<void> Function(NivelDificuldadeMovimento nivel) onEditarNivel;

  const _GerenciarNiveisSheet({
    required this.niveis,
    required this.onNovoNivel,
    required this.onEditarNivel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.grey.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Níveis de dificuldade',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Cadastre os níveis que organizam a jornada e definem a descrição de cada grupo de movimentos.',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: onNovoNivel,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Novo'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: niveis.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) => _NivelAdminCard(
                      nivel: niveis[index],
                      onEditar: () => onEditarNivel(niveis[index]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NivelAdminCard extends StatelessWidget {
  final NivelDificuldadeMovimento nivel;
  final VoidCallback onEditar;

  const _NivelAdminCard({required this.nivel, required this.onEditar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: nivel.cor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: nivel.cor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.layers_outlined, color: nivel.cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nivel.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nivel.descricao,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _BadgeTexto(texto: 'Ordem ${nivel.ordem}'),
                    _BadgeTexto(texto: nivel.ativo ? 'Ativo' : 'Inativo'),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _BadgeTexto extends StatelessWidget {
  final String texto;

  const _BadgeTexto({required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _FormularioNivelResultado {
  final String nome;
  final String descricao;
  final int ordem;
  final bool ativo;

  const _FormularioNivelResultado({
    required this.nome,
    required this.descricao,
    required this.ordem,
    required this.ativo,
  });
}

class _FormularioNivelSheet extends StatefulWidget {
  final NivelDificuldadeMovimento? nivel;

  const _FormularioNivelSheet({this.nivel});

  @override
  State<_FormularioNivelSheet> createState() => _FormularioNivelSheetState();
}

class _FormularioNivelSheetState extends State<_FormularioNivelSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomeController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _ordemController;
  late bool _ativo;

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(text: widget.nivel?.label ?? '');
    _descricaoController =
        TextEditingController(text: widget.nivel?.descricao ?? '');
    _ordemController =
        TextEditingController(text: '${widget.nivel?.ordem ?? 0}');
    _ativo = widget.nivel?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _ordemController.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _FormularioNivelResultado(
        nome: _nomeController.text.trim(),
        descricao: _descricaoController.text.trim(),
        ordem: int.tryParse(_ordemController.text.trim()) ?? 0,
        ativo: _ativo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 24,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.nivel == null ? 'Novo nível' : 'Editar nível',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Defina o nome, a descrição e a ordem visual para agrupar os movimentos da jornada.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nomeController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do nível',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe o nome do nível.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descricaoController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descrição do nível',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe a descrição do nível.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _ordemController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ordem de exibição',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe a ordem.';
                      }
                      if (int.tryParse(valor.trim()) == null) {
                        return 'Informe um número válido.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _ativo,
                    onChanged: (valor) => setState(() => _ativo = valor),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nível disponível'),
                    subtitle: const Text(
                      'Níveis inativos deixam de aparecer no cadastro de novos movimentos.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancelar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _salvar,
                          child: Text(
                            widget.nivel == null ? 'Cadastrar' : 'Salvar',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JornadaAlunaSheet extends StatefulWidget {
  final Usuario aluna;
  final List<MovimentoPole> movimentos;
  final JornadaMovimentoRepository jornadaRepo;
  final Future<void> Function() onAtualizado;

  const _JornadaAlunaSheet({
    required this.aluna,
    required this.movimentos,
    required this.jornadaRepo,
    required this.onAtualizado,
  });

  @override
  State<_JornadaAlunaSheet> createState() => _JornadaAlunaSheetState();
}

class _JornadaAlunaSheetState extends State<_JornadaAlunaSheet> {
  bool _carregando = true;
  String _busca = '';
  String? _movimentoProcessandoId;
  List<JornadaMovimento> _jornada = [];

  @override
  void initState() {
    super.initState();
    _carregarJornada();
  }

  Future<void> _carregarJornada() async {
    setState(() => _carregando = true);

    try {
      final jornada = await widget.jornadaRepo.listarPorAluna(widget.aluna.id);
      if (!mounted) return;
      setState(() => _jornada = jornada);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar jornada da aluna: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _liberarMovimento(MovimentoPole movimento) async {
    final adminId = context.read<AuthProvider>().usuario?.id;
    if (adminId == null) return;

    setState(() => _movimentoProcessandoId = movimento.id);

    try {
      await widget.jornadaRepo.liberarParaAluna(
        aluna: widget.aluna,
        movimento: movimento,
        adminId: adminId,
      );
      await _carregarJornada();
      await widget.onAtualizado();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${movimento.nome} foi liberado para ${widget.aluna.nome}.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao liberar movimento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _movimentoProcessandoId = null);
      }
    }
  }

  Future<void> _removerMovimento(JornadaMovimento jornada) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover da jornada?'),
        content: Text(
          'Deseja remover ${jornada.movimentoNome} da jornada de ${widget.aluna.nome}?\n\n'
          'As fotos enviadas para esse movimento também serão removidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Remover'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _movimentoProcessandoId = jornada.movimentoId);

    try {
      await widget.jornadaRepo.removerDaAluna(jornada);
      await _carregarJornada();
      await widget.onAtualizado();
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${jornada.movimentoNome} foi removido da jornada da aluna.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover movimento: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _movimentoProcessandoId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final jornadaPorMovimento = {
      for (final item in _jornada) item.movimentoId: item,
    };

    final movimentosFiltrados = widget.movimentos.where((movimento) {
      if (!movimento.ativo && jornadaPorMovimento[movimento.id] == null) {
        return false;
      }

      final termo = _busca.trim().toLowerCase();
      if (termo.isEmpty) return true;
      return movimento.nome.toLowerCase().contains(termo) ||
          movimento.categoria.label.toLowerCase().contains(termo) ||
          movimento.nivel.label.toLowerCase().contains(termo);
    }).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Material(
        color: AppColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.92,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    children: [
                      Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.grey.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.aluna.nome,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_jornada.length} movimento(s) dominado(s)',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (valor) => setState(() => _busca = valor),
                        decoration: InputDecoration(
                          hintText: 'Buscar movimento, categoria ou nível',
                          prefixIcon: const Icon(Icons.search_rounded),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _carregando
                      ? const LoadingIndicator()
                      : movimentosFiltrados.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(20),
                              child: _EstadoVazioJornada(
                                icone: Icons.auto_awesome_motion_outlined,
                                titulo: 'Nenhum movimento disponível',
                                mensagem:
                                    'Cadastre movimentos ativos para liberar na jornada desta aluna.',
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              itemCount: movimentosFiltrados.length,
                              itemBuilder: (context, index) {
                                final movimento = movimentosFiltrados[index];
                                final jornada =
                                    jornadaPorMovimento[movimento.id];
                                final processando =
                                    _movimentoProcessandoId == movimento.id;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: movimento.nivel.cor
                                            .withValues(alpha: 0.14),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    movimento.nome,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Wrap(
                                                    spacing: 8,
                                                    runSpacing: 8,
                                                    children: [
                                                      _CategoriaBadge(
                                                        categoria:
                                                            movimento.categoria,
                                                      ),
                                                      _NivelBadge(
                                                        nivel: movimento.nivel,
                                                      ),
                                                      if (!movimento.ativo)
                                                        const _TagStatusMovimento(
                                                          ativo: false,
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (jornada != null)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.success
                                                      .withValues(alpha: 0.12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          999),
                                                ),
                                                child: const Text(
                                                  'Liberado',
                                                  style: TextStyle(
                                                    color: AppColors.success,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (jornada != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            'Liberado em ${DateFormatter.data(jornada.liberadoEm)}',
                                            style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (jornada.fotos.isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 10,
                                              runSpacing: 10,
                                              children: jornada.fotos
                                                  .map(
                                                    (foto) => ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                        14,
                                                      ),
                                                      child: Image.network(
                                                        foto.url,
                                                        width: 72,
                                                        height: 96,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                            ),
                                          ],
                                        ],
                                        const SizedBox(height: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: jornada == null
                                              ? FilledButton.icon(
                                                  onPressed: processando
                                                      ? null
                                                      : () => _liberarMovimento(
                                                            movimento,
                                                          ),
                                                  icon: processando
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: Colors.white,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons
                                                              .add_task_rounded,
                                                        ),
                                                  label: Text(
                                                    processando
                                                        ? 'Liberando'
                                                        : 'Liberar para a aluna',
                                                  ),
                                                )
                                              : OutlinedButton.icon(
                                                  onPressed: processando
                                                      ? null
                                                      : () => _removerMovimento(
                                                            jornada,
                                                          ),
                                                  icon: processando
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.delete_outline,
                                                        ),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                    foregroundColor:
                                                        AppColors.error,
                                                    side: const BorderSide(
                                                      color: AppColors.error,
                                                    ),
                                                  ),
                                                  label: Text(
                                                    processando
                                                        ? 'Removendo'
                                                        : 'Remover da jornada',
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
