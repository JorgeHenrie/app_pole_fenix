import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/aviso_timeline_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/evento.dart';
import '../../repositories/evento_repository.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela da timeline de avisos do estúdio para a aluna.
class EventosScreen extends StatefulWidget {
  const EventosScreen({super.key});

  @override
  State<EventosScreen> createState() => _EventosScreenState();
}

class _EventosScreenState extends State<EventosScreen> {
  final EventoRepository _repo = EventoRepository();

  bool _carregando = true;
  String? _erro;
  List<Evento> _avisos = [];
  String? _avisoInicialId;
  bool _argumentosLidos = false;

  @override
  void initState() {
    super.initState();
    _carregarAvisos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argumentosLidos) return;

    final argumentos = ModalRoute.of(context)?.settings.arguments;
    if (argumentos is String && argumentos.trim().isNotEmpty) {
      _avisoInicialId = argumentos;
    } else if (argumentos is Map<String, dynamic>) {
      final avisoId = argumentos['avisoId'];
      if (avisoId is String && avisoId.trim().isNotEmpty) {
        _avisoInicialId = avisoId;
      }
    }

    _argumentosLidos = true;
  }

  Future<void> _carregarAvisos() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final avisos = await _repo.listarPublicados();
      if (!mounted) return;
      setState(() => _avisos = avisos);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Nao foi possivel carregar a timeline agora. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  int _indiceInicial() {
    if (_avisoInicialId == null) return 0;
    final indice = _avisos.indexWhere((aviso) => aviso.id == _avisoInicialId);
    return indice < 0 ? 0 : indice;
  }

  @override
  Widget build(BuildContext context) {
    final indiceInicial = _indiceInicial();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Timeline de Avisos'),
        actions: [
          IconButton(
            onPressed: _carregarAvisos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _erro != null
              ? _ErroTimeline(
                  mensagem: _erro!,
                  onTentarNovamente: _carregarAvisos,
                )
              : RefreshIndicator(
                  onRefresh: _carregarAvisos,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _CabecalhoTimeline(total: _avisos.length),
                      const SizedBox(height: 20),
                      if (_avisos.isEmpty)
                        const _TimelineVazia()
                      else ...[
                        _AvisosHeroCarousel(
                          key: ValueKey(
                            'hero-${_avisos.length}-$indiceInicial-${_avisoInicialId ?? ''}',
                          ),
                          avisos: _avisos,
                          initialPage: indiceInicial,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Todos os avisos',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Acompanhe eventos, comunicados, workshops e novidades publicadas pelo estúdio.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...List.generate(
                          _avisos.length,
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AvisoTimelineCard(
                              aviso: _avisos[index],
                              ultimo: index == _avisos.length - 1,
                              destaque: _avisos[index].id == _avisoInicialId,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _CabecalhoTimeline extends StatelessWidget {
  final int total;

  const _CabecalhoTimeline({required this.total});

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
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Atualizacao automatica do estúdio',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Seu mural visual de avisos',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            total == 0
                ? 'Quando o studio publicar novos avisos, eles vao aparecer aqui em formato de timeline.'
                : '$total aviso(s) publicado(s) para voce acompanhar em um so lugar.',
            style: const TextStyle(
              color: Colors.white70,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisosHeroCarousel extends StatefulWidget {
  final List<Evento> avisos;
  final int initialPage;

  const _AvisosHeroCarousel({
    super.key,
    required this.avisos,
    required this.initialPage,
  });

  @override
  State<_AvisosHeroCarousel> createState() => _AvisosHeroCarouselState();
}

class _AvisosHeroCarouselState extends State<_AvisosHeroCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  late int _paginaAtual;

  @override
  void initState() {
    super.initState();
    _paginaAtual = widget.initialPage;
    _pageController = PageController(
      viewportFraction: 0.9,
      initialPage: widget.initialPage,
    );
    _iniciarAutoPlay();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _iniciarAutoPlay() {
    _timer?.cancel();
    if (widget.avisos.length <= 1) return;

    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!_pageController.hasClients) return;
      final proximaPagina = (_paginaAtual + 1) % widget.avisos.length;
      _pageController.animateToPage(
        proximaPagina,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Destaques do momento',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 340,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.avisos.length,
            onPageChanged: (pagina) => setState(() => _paginaAtual = pagina),
            itemBuilder: (context, index) {
              final aviso = widget.avisos[index];
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _AvisoHeroCard(aviso: aviso),
              );
            },
          ),
        ),
        if (widget.avisos.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.avisos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _paginaAtual ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index == _paginaAtual
                      ? AppColors.primary
                      : AppColors.primaryLight.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AvisoHeroCard extends StatelessWidget {
  final Evento aviso;

  const _AvisoHeroCard({required this.aviso});

  @override
  Widget build(BuildContext context) {
    final categoriaColor = AvisoTimelineHelper.color(aviso.categoria);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (aviso.imagemUrl != null && aviso.imagemUrl!.isNotEmpty)
              Image.network(
                aviso.imagemUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _HeroPlaceholder(
                    cor: categoriaColor, categoria: aviso.categoria),
              )
            else
              _HeroPlaceholder(cor: categoriaColor, categoria: aviso.categoria),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.08),
                    Colors.black.withValues(alpha: 0.68),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroPill(
                        label: AvisoTimelineHelper.label(aviso.categoria),
                        color: categoriaColor,
                      ),
                      _HeroPill(
                        label: DateFormatter.dataHora(aviso.dataHora),
                        color: AppColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    aviso.titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 24,
                      height: 1.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    aviso.descricao,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.45,
                    ),
                  ),
                  if (aviso.local != null &&
                      aviso.local!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            aviso.local!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroPlaceholder extends StatelessWidget {
  final Color cor;
  final String categoria;

  const _HeroPlaceholder({required this.cor, required this.categoria});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cor, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          AvisoTimelineHelper.icon(categoria),
          size: 54,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final Color color;

  const _HeroPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _AvisoTimelineCard extends StatelessWidget {
  final Evento aviso;
  final bool ultimo;
  final bool destaque;

  const _AvisoTimelineCard({
    required this.aviso,
    required this.ultimo,
    required this.destaque,
  });

  @override
  Widget build(BuildContext context) {
    final categoriaColor = AvisoTimelineHelper.color(aviso.categoria);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: categoriaColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: categoriaColor.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.primaryLight.withValues(alpha: 0.38),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: destaque
                      ? categoriaColor.withValues(alpha: 0.4)
                      : AppColors.greyLight,
                ),
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
                  if (aviso.imagemUrl != null && aviso.imagemUrl!.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          aviso.imagemUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: categoriaColor.withValues(alpha: 0.12),
                            alignment: Alignment.center,
                            child: Icon(
                              AvisoTimelineHelper.icon(aviso.categoria),
                              color: categoriaColor,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaPill(
                              label: AvisoTimelineHelper.label(aviso.categoria),
                              color: categoriaColor,
                            ),
                            if (destaque)
                              const _MetaPill(
                                label: 'Em destaque',
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          aviso.titulo,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          aviso.descricao,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoLinha(
                          icon: Icons.schedule_rounded,
                          texto: DateFormatter.dataHora(aviso.dataHora),
                        ),
                        if (aviso.local != null &&
                            aviso.local!.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _InfoLinha(
                              icon: Icons.place_outlined,
                              texto: aviso.local!,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  final IconData icon;
  final String texto;

  const _InfoLinha({required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineVazia extends StatelessWidget {
  const _TimelineVazia();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 56,
            color: AppColors.primaryLight,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhum aviso publicado por enquanto',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Text(
            'Assim que o studio publicar um novo conteudo visual, ele aparecera aqui automaticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ErroTimeline extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onTentarNovamente;

  const _ErroTimeline({
    required this.mensagem,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.wifi_tethering_error_rounded,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onTentarNovamente,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
