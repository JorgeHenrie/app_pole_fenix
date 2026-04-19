import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/aviso_timeline_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/evento.dart';

class EventosSection extends StatelessWidget {
  final List<Evento> eventos;

  const EventosSection({super.key, required this.eventos});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mural do Estúdio',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, Routes.eventos),
                child: const Text('Ver tudo'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (eventos.isEmpty)
            _buildEmptyState(context)
          else
            _AvisosHomeCarousel(avisos: eventos),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 48,
            color: AppColors.primaryLight,
          ),
          SizedBox(height: 12),
          Text(
            'Nenhum aviso publicado',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvisosHomeCarousel extends StatefulWidget {
  final List<Evento> avisos;

  const _AvisosHomeCarousel({required this.avisos});

  @override
  State<_AvisosHomeCarousel> createState() => _AvisosHomeCarouselState();
}

class _AvisosHomeCarouselState extends State<_AvisosHomeCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _paginaAtual = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
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

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
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
      children: [
        SizedBox(
          height: 230,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.avisos.length,
            onPageChanged: (pagina) => setState(() => _paginaAtual = pagina),
            itemBuilder: (context, index) {
              final aviso = widget.avisos[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _AvisoHomeCard(aviso: aviso),
              );
            },
          ),
        ),
        if (widget.avisos.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.avisos.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == _paginaAtual ? 18 : 8,
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

class _AvisoHomeCard extends StatelessWidget {
  final Evento aviso;

  const _AvisoHomeCard({required this.aviso});

  @override
  Widget build(BuildContext context) {
    final categoriaColor = AvisoTimelineHelper.color(aviso.categoria);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => Navigator.pushNamed(
          context,
          Routes.eventos,
          arguments: {'avisoId': aviso.id},
        ),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (aviso.imagemUrl != null && aviso.imagemUrl!.isNotEmpty)
                  Image.network(
                    aviso.imagemUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _buildPlaceholder(categoriaColor),
                  )
                else
                  _buildPlaceholder(categoriaColor),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.56),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _PillOverlay(
                            label: AvisoTimelineHelper.label(aviso.categoria),
                            color: categoriaColor,
                          ),
                          _PillOverlay(
                            label: DateFormatter.data(aviso.dataHora),
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        aviso.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        aviso.descricao,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          height: 1.35,
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

  Widget _buildPlaceholder(Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          AvisoTimelineHelper.icon(aviso.categoria),
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

class _PillOverlay extends StatelessWidget {
  final String label;
  final Color color;

  const _PillOverlay({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
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
