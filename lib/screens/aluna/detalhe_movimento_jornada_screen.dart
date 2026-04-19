import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../models/jornada_movimento.dart';
import '../../models/movimento_pole.dart';
import '../../repositories/jornada_movimento_repository.dart';

const _fotoPadraoJornadaAsset = 'assets/images/teste3.jpg';

class DetalheMovimentoJornadaScreen extends StatefulWidget {
  final JornadaMovimento jornada;

  const DetalheMovimentoJornadaScreen({
    super.key,
    required this.jornada,
  });

  @override
  State<DetalheMovimentoJornadaScreen> createState() =>
      _DetalheMovimentoJornadaScreenState();
}

class _DetalheMovimentoJornadaScreenState
    extends State<DetalheMovimentoJornadaScreen> {
  final JornadaMovimentoRepository _repo = JornadaMovimentoRepository();
  final ImagePicker _picker = ImagePicker();
  final PageController _pageController = PageController();

  late JornadaMovimento _jornada;
  bool _processando = false;
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    _jornada = widget.jornada;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  FotoJornadaMovimento? get _fotoAtual {
    if (_jornada.fotos.isEmpty) return null;
    final indice = _paginaAtual.clamp(0, _jornada.fotos.length - 1);
    return _jornada.fotos[indice];
  }

  Future<void> _selecionarFoto({FotoJornadaMovimento? substituir}) async {
    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1600,
    );
    if (imagem == null || !mounted) return;

    setState(() => _processando = true);

    try {
      final arquivo = File(imagem.path);
      final atualizada = substituir == null
          ? await _repo.adicionarFoto(jornada: _jornada, arquivo: arquivo)
          : await _repo.substituirFoto(
              jornada: _jornada,
              fotoAnterior: substituir,
              novoArquivo: arquivo,
            );

      if (!mounted) return;

      setState(() {
        _jornada = atualizada;
        if (substituir == null && atualizada.fotos.isNotEmpty) {
          _paginaAtual = atualizada.fotos.length - 1;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients || !mounted || _jornada.fotos.isEmpty) {
          return;
        }
        _pageController.animateToPage(
          _paginaAtual,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            substituir == null
                ? 'Foto adicionada à sua conquista.'
                : 'Foto atualizada com sucesso.',
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
        SnackBar(content: Text('Erro ao salvar foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _removerFotoAtual() async {
    final foto = _fotoAtual;
    if (foto == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover foto?'),
        content: const Text(
          'Deseja remover a foto exibida desta conquista?',
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

    if (confirmar != true || !mounted) return;

    setState(() => _processando = true);

    try {
      final atualizada = await _repo.removerFoto(jornada: _jornada, foto: foto);
      if (!mounted) return;

      setState(() {
        _jornada = atualizada;
        if (_jornada.fotos.isEmpty) {
          _paginaAtual = 0;
        } else if (_paginaAtual >= _jornada.fotos.length) {
          _paginaAtual = _jornada.fotos.length - 1;
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_pageController.hasClients || !mounted || _jornada.fotos.isEmpty) {
          return;
        }
        _pageController.jumpToPage(_paginaAtual);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto removida da conquista.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao remover foto: $e')),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _trocarFotoAtual() async {
    final foto = _fotoAtual;
    if (foto == null) {
      await _selecionarFoto();
      return;
    }

    await _selecionarFoto(substituir: foto);
  }

  String _descricaoPrincipal() {
    switch (_jornada.movimentoCategoria) {
      case CategoriaMovimentoPole.movimentoEstatico:
        return '${_jornada.movimentoNome} marca presença, linha e controle corporal. Nos movimentos estáticos, o corpo sustenta a forma com elegância e firmeza, revelando potência e consciência em cada detalhe.';
      case CategoriaMovimentoPole.giros:
        return '${_jornada.movimentoNome} celebra fluidez, ritmo e precisão. Os giros trazem leveza visual, domínio de entrada e saída e uma sensação bonita de continuidade no pole.';
      case CategoriaMovimentoPole.combos:
        return '${_jornada.movimentoNome} mostra conexão entre técnica e repertório. Nos combos, você costura movimentos em sequência com memória corporal, intenção e presença de cena.';
    }
  }

  String _descricaoSecundaria() {
    final descricao = _jornada.nivel.descricao.trim();
    if (descricao.isNotEmpty) return descricao;
    return 'Essa conquista faz parte do nível ${_jornada.nivel.label.toLowerCase()} da sua jornada.';
  }

  @override
  Widget build(BuildContext context) {
    final fotoAtual = _fotoAtual;
    final podeAdicionar = _jornada.fotos.length < 2;
    final labelQuantidadeFotos = _jornada.fotos.isEmpty
        ? 'foto padrão pronta'
        : '${_jornada.fotos.length}/2 fotos';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Conquista'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
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
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu registro visual',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aqui você pode guardar, renovar e organizar as fotos dessa conquista.',
                  style: TextStyle(
                    color: Colors.white70,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                _GaleriaDetalheJornada(
                  fotos: _jornada.fotos,
                  pageController: _pageController,
                  paginaAtual: _paginaAtual,
                  onPageChanged: (pagina) {
                    setState(() => _paginaAtual = pagina);
                  },
                  processando: _processando,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
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
                      child: Text(
                        _jornada.movimentoNome,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
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
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _InfoTagDetalhe(
                      label: _jornada.movimentoCategoria.label,
                      color: _jornada.movimentoCategoria.cor,
                    ),
                    _InfoTagDetalhe(
                      label: _jornada.nivel.label,
                      color: _jornada.nivel.cor,
                    ),
                    _InfoTagDetalhe(
                      label: labelQuantidadeFotos,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sobre essa conquista',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _descricaoPrincipal(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _descricaoSecundaria(),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (podeAdicionar)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _processando ? null : () => _selecionarFoto(),
                      icon: _processando
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        _jornada.fotos.isEmpty
                            ? 'Trocar pela sua foto'
                            : 'Adicionar segunda foto',
                      ),
                    ),
                  ),
                if (podeAdicionar) const SizedBox(height: 12),
                if (fotoAtual != null)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _processando ? null : _trocarFotoAtual,
                          icon: const Icon(Icons.autorenew_rounded),
                          label: const Text('Trocar foto atual'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _processando ? null : _removerFotoAtual,
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Remover'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GaleriaDetalheJornada extends StatelessWidget {
  final List<FotoJornadaMovimento> fotos;
  final PageController pageController;
  final int paginaAtual;
  final ValueChanged<int> onPageChanged;
  final bool processando;

  const _GaleriaDetalheJornada({
    required this.fotos,
    required this.pageController,
    required this.paginaAtual,
    required this.onPageChanged,
    required this.processando,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        height: 340,
        color: Colors.white.withValues(alpha: 0.08),
        child: fotos.isEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _fotoPadraoJornadaAsset,
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.06),
                          Colors.black.withValues(alpha: 0.5),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  if (processando)
                    const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  else
                    Positioned(
                      left: 18,
                      right: 18,
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.34),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Foto inicial do movimento',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Escolha a sua para substituir esse visual padrão.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            : Stack(
                children: [
                  PageView.builder(
                    controller: pageController,
                    itemCount: fotos.length,
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, index) {
                      final foto = fotos[index];
                      return Image.network(
                        foto.url,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.black12,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                          );
                        },
                      );
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.34),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${paginaAtual + 1}/${fotos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (fotos.length > 1)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 14,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          fotos.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: index == paginaAtual ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index == paginaAtual
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
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

class _InfoTagDetalhe extends StatelessWidget {
  final String label;
  final Color color;

  const _InfoTagDetalhe({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
