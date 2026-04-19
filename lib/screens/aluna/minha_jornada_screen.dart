import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/jornada_movimento.dart';
import '../../models/movimento_pole.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/jornada_movimento_repository.dart';
import '../../widgets/common/loading_indicator.dart';
import 'detalhe_movimento_jornada_screen.dart';

const _fotoPadraoJornadaAsset = 'assets/images/teste3.jpg';

class MinhaJornadaScreen extends StatefulWidget {
  const MinhaJornadaScreen({super.key});

  @override
  State<MinhaJornadaScreen> createState() => _MinhaJornadaScreenState();
}

class _MinhaJornadaScreenState extends State<MinhaJornadaScreen> {
  final JornadaMovimentoRepository _repo = JornadaMovimentoRepository();
  final ImagePicker _picker = ImagePicker();

  bool _carregando = false;
  final Set<String> _acoesEmAndamento = <String>{};
  List<JornadaMovimento> _jornada = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarJornada();
    });
  }

  Future<void> _carregarJornada() async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _carregando = true);
    try {
      final jornada = await _repo.listarPorAluna(usuario.id);
      if (!mounted) return;
      setState(() => _jornada = jornada);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar sua jornada: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _adicionarPrimeiraFoto(JornadaMovimento jornada) async {
    if (jornada.fotos.isNotEmpty) return;

    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1400,
    );
    if (imagem == null || !mounted) return;

    final chave = 'upload:${jornada.id}';
    _setAcao(chave, true);

    try {
      final atualizada = await _repo.adicionarFoto(
        jornada: jornada,
        arquivo: File(imagem.path),
      );
      _atualizarJornada(atualizada);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Primeira foto adicionada à sua jornada.'),
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
        SnackBar(content: Text('Erro ao enviar foto: $e')),
      );
    } finally {
      if (mounted) _setAcao(chave, false);
    }
  }

  void _setAcao(String chave, bool ativa) {
    setState(() {
      if (ativa) {
        _acoesEmAndamento.add(chave);
      } else {
        _acoesEmAndamento.remove(chave);
      }
    });
  }

  bool _estaProcessando(String chave) => _acoesEmAndamento.contains(chave);

  void _atualizarJornada(JornadaMovimento itemAtualizado) {
    final indice = _jornada.indexWhere((item) => item.id == itemAtualizado.id);
    if (indice == -1) return;

    final atualizada = [..._jornada];
    atualizada[indice] = itemAtualizado;
    atualizada.sort((a, b) {
      final porNivel = a.nivel.ordem.compareTo(b.nivel.ordem);
      if (porNivel != 0) return porNivel;
      final porData = b.liberadoEm.compareTo(a.liberadoEm);
      if (porData != 0) return porData;
      return a.movimentoNome.compareTo(b.movimentoNome);
    });

    setState(() => _jornada = atualizada);
  }

  Future<void> _abrirDetalhe(JornadaMovimento jornada) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DetalheMovimentoJornadaScreen(jornada: jornada),
      ),
    );

    if (!mounted) return;
    await _carregarJornada();
  }

  @override
  Widget build(BuildContext context) {
    final totalFotos = _jornada.fold<int>(
      0,
      (total, item) => total + item.fotos.length,
    );

    final grupos = _agruparPorNivel(_jornada);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Minha Jornada'),
        actions: [
          IconButton(
            onPressed: _carregarJornada,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregarJornada,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _ResumoMinhaJornadaCard(
                    totalMovimentos: _jornada.length,
                    totalFotos: totalFotos,
                  ),
                  const SizedBox(height: 16),
                  if (_jornada.isEmpty)
                    const _EstadoVazioMinhaJornada()
                  else
                    ...grupos.map((grupo) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _SecaoNivelMinhaJornada(
                          nivel: grupo.nivel,
                          itens: grupo.itens,
                          estaProcessando: _estaProcessando,
                          onAdicionarPrimeiraFoto: _adicionarPrimeiraFoto,
                          onAbrirDetalhe: _abrirDetalhe,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }

  List<_GrupoJornadaPorNivel> _agruparPorNivel(List<JornadaMovimento> jornada) {
    final grupos = <String, List<JornadaMovimento>>{};
    final niveis = <String, NivelDificuldadeMovimento>{};

    for (final item in jornada) {
      grupos.putIfAbsent(item.nivel.id, () => []).add(item);
      niveis[item.nivel.id] = item.nivel;
    }

    final resultado = grupos.entries
        .map(
          (entry) => _GrupoJornadaPorNivel(
            nivel: niveis[entry.key]!,
            itens: entry.value,
          ),
        )
        .toList()
      ..sort((a, b) {
        final porOrdem = a.nivel.ordem.compareTo(b.nivel.ordem);
        if (porOrdem != 0) return porOrdem;
        return a.nivel.label.compareTo(b.nivel.label);
      });

    return resultado;
  }
}

class _GrupoJornadaPorNivel {
  final NivelDificuldadeMovimento nivel;
  final List<JornadaMovimento> itens;

  const _GrupoJornadaPorNivel({
    required this.nivel,
    required this.itens,
  });
}

class _ResumoMinhaJornadaCard extends StatelessWidget {
  final int totalMovimentos;
  final int totalFotos;

  const _ResumoMinhaJornadaCard({
    required this.totalMovimentos,
    required this.totalFotos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.accentCocoa,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seu repertório conquistado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cada movimento registrado aqui representa uma etapa concreta da sua evolução no pole.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ResumoMiniCard(
                titulo: 'Movimentos',
                valor: '$totalMovimentos',
              ),
              _ResumoMiniCard(
                titulo: 'Fotos registradas',
                valor: '$totalFotos',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumoMiniCard extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ResumoMiniCard({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

class _EstadoVazioMinhaJornada extends StatelessWidget {
  const _EstadoVazioMinhaJornada();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 34,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sua jornada começa aqui',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Quando o estúdio liberar os movimentos que você já domina, eles aparecerão nesta área para você acompanhar e registrar sua evolução.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecaoNivelMinhaJornada extends StatelessWidget {
  final NivelDificuldadeMovimento nivel;
  final List<JornadaMovimento> itens;
  final bool Function(String chave) estaProcessando;
  final Future<void> Function(JornadaMovimento jornada) onAdicionarPrimeiraFoto;
  final Future<void> Function(JornadaMovimento jornada) onAbrirDetalhe;

  const _SecaoNivelMinhaJornada({
    required this.nivel,
    required this.itens,
    required this.estaProcessando,
    required this.onAdicionarPrimeiraFoto,
    required this.onAbrirDetalhe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: nivel.cor.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: nivel.cor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  nivel.label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${itens.length} conquista(s)',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            nivel.descricao,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          ...itens.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CardMovimentoJornada(
                jornada: item,
                uploadando: estaProcessando('upload:${item.id}'),
                onAdicionarPrimeiraFoto: () => onAdicionarPrimeiraFoto(item),
                onTap: () => onAbrirDetalhe(item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardMovimentoJornada extends StatelessWidget {
  final JornadaMovimento jornada;
  final bool uploadando;
  final VoidCallback onAdicionarPrimeiraFoto;
  final VoidCallback onTap;

  const _CardMovimentoJornada({
    required this.jornada,
    required this.uploadando,
    required this.onAdicionarPrimeiraFoto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border(
              left: BorderSide(color: jornada.nivel.cor, width: 6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PreviewFotosJornada(
                  jornada: jornada,
                  uploadando: uploadando,
                  onAdicionarPrimeiraFoto: onAdicionarPrimeiraFoto,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              jornada.movimentoNome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Conquistado',
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        jornada.movimentoCategoria.label.toUpperCase(),
                        style: TextStyle(
                          color: jornada.movimentoCategoria.cor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
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

class _PreviewFotosJornada extends StatelessWidget {
  final JornadaMovimento jornada;
  final bool uploadando;
  final VoidCallback onAdicionarPrimeiraFoto;

  const _PreviewFotosJornada({
    required this.jornada,
    required this.uploadando,
    required this.onAdicionarPrimeiraFoto,
  });

  @override
  Widget build(BuildContext context) {
    if (jornada.fotos.isEmpty) {
      return InkWell(
        onTap: uploadando ? null : onAdicionarPrimeiraFoto,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.3),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _fotoPadraoJornadaAsset,
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.42),
                      ],
                    ),
                  ),
                ),
                if (uploadando)
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Adicionar',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (jornada.fotos.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.network(
          jornada.fotos.first.url,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
        ),
      );
    }

    return _CarrosselFotosCompacto(fotos: jornada.fotos.take(2).toList());
  }
}

class _CarrosselFotosCompacto extends StatefulWidget {
  final List<FotoJornadaMovimento> fotos;

  const _CarrosselFotosCompacto({required this.fotos});

  @override
  State<_CarrosselFotosCompacto> createState() =>
      _CarrosselFotosCompactoState();
}

class _CarrosselFotosCompactoState extends State<_CarrosselFotosCompacto> {
  late final PageController _controller;
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: 84,
        height: 84,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.fotos.length,
              onPageChanged: (pagina) => setState(() => _paginaAtual = pagina),
              itemBuilder: (context, index) {
                return Image.network(
                  widget.fotos[index].url,
                  fit: BoxFit.cover,
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 6,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.fotos.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _paginaAtual ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: index == _paginaAtual
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
