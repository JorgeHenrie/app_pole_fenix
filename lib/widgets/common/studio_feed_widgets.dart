import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/aviso_timeline_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/evento_comentario.dart';
import '../../models/evento.dart';
import '../../models/evento_reacao.dart';
import '../../repositories/evento_repository.dart';

enum StudioFeedPostAction {
  editar,
  alternarPublicacao,
  excluir,
}

class StudioFeedSectionHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icone;

  const StudioFeedSectionHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1ECEB),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  AppColors.accentCocoa,
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StudioFeedHighlightsRow extends StatelessWidget {
  final List<Evento> posts;
  final String nomeStudio;
  final VoidCallback? onCriarTap;
  final ValueChanged<Evento>? onHighlightTap;

  const StudioFeedHighlightsRow({
    super.key,
    required this.posts,
    required this.nomeStudio,
    this.onCriarTap,
    this.onHighlightTap,
  });

  @override
  Widget build(BuildContext context) {
    final destaques = posts.take(4).toList();

    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _FeedHighlightBubble.adicionar(onTap: onCriarTap),
          ...List.generate(
            destaques.length,
            (index) {
              final post = destaques[index];
              return _FeedHighlightBubble.post(
                label: index == 0
                    ? _limitarRotulo(nomeStudio)
                    : _limitarRotulo(post.titulo),
                color: AvisoTimelineHelper.color(post.categoria),
                imagemUrl: post.imagemUrl,
                iniciais: _iniciais(index == 0 ? nomeStudio : post.titulo),
                onTap:
                    onHighlightTap == null ? null : () => onHighlightTap!(post),
              );
            },
          ),
        ],
      ),
    );
  }
}

class StudioFeedComposerCard extends StatelessWidget {
  final String nomeStudio;
  final String placeholder;
  final VoidCallback? onTap;
  final bool habilitado;

  const StudioFeedComposerCard({
    super.key,
    required this.nomeStudio,
    required this.placeholder,
    this.onTap,
    this.habilitado = false,
  });

  @override
  Widget build(BuildContext context) {
    final iniciais = _iniciais(nomeStudio);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentCocoa,
                child: Text(
                  iniciais,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  placeholder,
                  style: TextStyle(
                    color: habilitado
                        ? AppColors.textSecondary
                        : AppColors.textHint,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StudioFeedPostCard extends StatefulWidget {
  final Evento post;
  final String nomeAutor;
  final String badge;
  final Color badgeColor;
  final ValueChanged<StudioFeedPostAction>? onActionSelected;
  final String? usuarioId;
  final String? nomeUsuario;
  final bool podeModerarComentarios;

  const StudioFeedPostCard({
    super.key,
    required this.post,
    required this.nomeAutor,
    required this.badge,
    required this.badgeColor,
    this.onActionSelected,
    this.usuarioId,
    this.nomeUsuario,
    this.podeModerarComentarios = false,
  });

  @override
  State<StudioFeedPostCard> createState() => _StudioFeedPostCardState();
}

class _StudioFeedPostCardState extends State<StudioFeedPostCard> {
  final EventoRepository _repo = EventoRepository();

  late Stream<List<EventoReacao>> _reacoesStream;
  late Stream<List<EventoComentario>> _comentariosStream;

  @override
  void initState() {
    super.initState();
    _configurarStreams();
  }

  @override
  void didUpdateWidget(covariant StudioFeedPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _configurarStreams();
    }
  }

  void _configurarStreams() {
    _reacoesStream = _repo.observarReacoes(widget.post.id);
    _comentariosStream = _repo.observarComentarios(widget.post.id);
  }

  bool get _podeInteragir {
    return widget.usuarioId != null &&
        widget.usuarioId!.trim().isNotEmpty &&
        widget.nomeUsuario != null &&
        widget.nomeUsuario!.trim().isNotEmpty;
  }

  Future<void> _alternarReacao(TipoReacaoEvento tipo) async {
    if (!_podeInteragir) {
      _mostrarSnackBar('Nao foi possivel identificar a usuaria logada.');
      return;
    }

    try {
      await _repo.alternarReacao(
        eventoId: widget.post.id,
        usuarioId: widget.usuarioId!,
        usuarioNome: widget.nomeUsuario!,
        tipo: tipo,
      );
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _mostrarSnackBar(
          'As permissoes do feed ainda nao foram liberadas para reacoes.',
        );
        return;
      }
      _mostrarSnackBar('Nao foi possivel registrar sua reacao agora.');
    } on StateError catch (e) {
      _mostrarSnackBar(e.message);
    } catch (_) {
      _mostrarSnackBar('Nao foi possivel registrar sua reacao agora.');
    }
  }

  void _abrirComentarios() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FeedComentariosSheet(
        post: widget.post,
        repo: _repo,
        comentariosStream: _comentariosStream,
        usuarioId: widget.usuarioId,
        nomeUsuario: widget.nomeUsuario,
        podeModerarComentarios: widget.podeModerarComentarios,
      ),
    );
  }

  void _mostrarSnackBar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    final corCategoria = AvisoTimelineHelper.color(widget.post.categoria);
    final iniciais = _iniciais(widget.nomeAutor);
    final referenciaTempo = widget.post.atualizadoEm ?? widget.post.criadoEm;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 15,
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
              CircleAvatar(
                radius: 22,
                backgroundColor: corCategoria.withValues(alpha: 0.14),
                child: Text(
                  iniciais,
                  style: TextStyle(
                    color: corCategoria,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          widget.nomeAutor,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.badgeColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            widget.badge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: widget.badgeColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _tempoRelativo(referenciaTempo),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onActionSelected != null)
                PopupMenuButton<StudioFeedPostAction>(
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppColors.textSecondary,
                  ),
                  onSelected: widget.onActionSelected,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: StudioFeedPostAction.editar,
                      child: Text('Editar'),
                    ),
                    PopupMenuItem(
                      value: StudioFeedPostAction.alternarPublicacao,
                      child: Text(
                        widget.post.publicado ? 'Despublicar' : 'Publicar',
                      ),
                    ),
                    const PopupMenuItem(
                      value: StudioFeedPostAction.excluir,
                      child: Text('Excluir'),
                    ),
                  ],
                )
              else
                const Icon(
                  Icons.more_horiz_rounded,
                  color: AppColors.textHint,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            widget.post.titulo,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.post.descricao,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.55,
            ),
          ),
          if (widget.post.local != null &&
              widget.post.local!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.post.local!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.greyLight),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              _FeedReacoesBar(
                stream: _reacoesStream,
                usuarioId: widget.usuarioId,
                habilitado: _podeInteragir,
                onTap: _alternarReacao,
              ),
              _FeedComentariosButton(
                stream: _comentariosStream,
                onTap: _abrirComentarios,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StudioFeedEmptyState extends StatelessWidget {
  final String titulo;
  final String descricao;

  const StudioFeedEmptyState({
    super.key,
    required this.titulo,
    required this.descricao,
  });

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
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dynamic_feed_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
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
            descricao,
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

class StudioFeedErrorState extends StatelessWidget {
  final String mensagem;
  final Future<void> Function() onTentarNovamente;

  const StudioFeedErrorState({
    super.key,
    required this.mensagem,
    required this.onTentarNovamente,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 52,
              color: AppColors.error,
            ),
            const SizedBox(height: 14),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
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

class _FeedHighlightBubble extends StatelessWidget {
  final String label;
  final Color color;
  final String? imagemUrl;
  final String iniciais;
  final bool adicionar;
  final VoidCallback? onTap;

  const _FeedHighlightBubble._({
    required this.label,
    required this.color,
    required this.imagemUrl,
    required this.iniciais,
    required this.adicionar,
    required this.onTap,
  });

  factory _FeedHighlightBubble.adicionar({VoidCallback? onTap}) {
    return _FeedHighlightBubble._(
      label: 'Novo',
      color: AppColors.primaryLight,
      imagemUrl: null,
      iniciais: '+',
      adicionar: true,
      onTap: onTap,
    );
  }

  factory _FeedHighlightBubble.post({
    required String label,
    required Color color,
    required String? imagemUrl,
    required String iniciais,
    VoidCallback? onTap,
  }) {
    return _FeedHighlightBubble._(
      label: label,
      color: color,
      imagemUrl: imagemUrl,
      iniciais: iniciais,
      adicionar: false,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: adicionar
                        ? AppColors.primaryLight.withValues(alpha: 0.9)
                        : color.withValues(alpha: 0.65),
                    width: 1.6,
                  ),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: adicionar
                      ? Container(
                          color: Colors.white,
                          child: const Center(
                            child: Icon(
                              Icons.add,
                              color: AppColors.accentCocoa,
                              size: 28,
                            ),
                          ),
                        )
                      : imagemUrl != null && imagemUrl!.isNotEmpty
                          ? Image.network(
                              imagemUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _FeedHighlightFallback(
                                color: color,
                                iniciais: iniciais,
                              ),
                            )
                          : _FeedHighlightFallback(
                              color: color,
                              iniciais: iniciais,
                            ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 74,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedHighlightFallback extends StatelessWidget {
  final Color color;
  final String iniciais;

  const _FeedHighlightFallback({required this.color, required this.iniciais});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.16),
      child: Center(
        child: Text(
          iniciais,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
      ),
    );
  }
}

class _FeedReacoesBar extends StatelessWidget {
  final Stream<List<EventoReacao>> stream;
  final String? usuarioId;
  final bool habilitado;
  final ValueChanged<TipoReacaoEvento> onTap;

  const _FeedReacoesBar({
    required this.stream,
    required this.usuarioId,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventoReacao>>(
      stream: stream,
      builder: (context, snapshot) {
        final reacoes = snapshot.data ?? const <EventoReacao>[];
        EventoReacao? minhaReacao;
        for (final reacao in reacoes) {
          if (reacao.usuarioId == usuarioId) {
            minhaReacao = reacao;
            break;
          }
        }

        int contar(TipoReacaoEvento tipo) {
          return reacoes.where((reacao) => reacao.tipo == tipo).length;
        }

        final tipoSelecionado = minhaReacao?.tipo;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _FeedReactionButton(
              icon: tipoSelecionado == TipoReacaoEvento.curtir
                  ? Icons.thumb_up_alt_rounded
                  : Icons.thumb_up_alt_outlined,
              label: 'Curtir',
              total: contar(TipoReacaoEvento.curtir),
              ativo: tipoSelecionado == TipoReacaoEvento.curtir,
              corAtiva: const Color(0xFF2563EB),
              habilitado: habilitado,
              onTap: () => onTap(TipoReacaoEvento.curtir),
            ),
            _FeedReactionButton(
              icon: tipoSelecionado == TipoReacaoEvento.amar
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: 'Amei',
              total: contar(TipoReacaoEvento.amar),
              ativo: tipoSelecionado == TipoReacaoEvento.amar,
              corAtiva: const Color(0xFFD64545),
              habilitado: habilitado,
              onTap: () => onTap(TipoReacaoEvento.amar),
            ),
          ],
        );
      },
    );
  }
}

class _FeedReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int total;
  final bool ativo;
  final Color corAtiva;
  final bool habilitado;
  final VoidCallback onTap;

  const _FeedReactionButton({
    required this.icon,
    required this.label,
    required this.total,
    required this.ativo,
    required this.corAtiva,
    required this.habilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = ativo ? corAtiva : AppColors.textSecondary;

    return Material(
      color: ativo ? corAtiva.withValues(alpha: 0.12) : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: habilitado ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$total',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedComentariosButton extends StatelessWidget {
  final Stream<List<EventoComentario>> stream;
  final VoidCallback onTap;

  const _FeedComentariosButton({
    required this.stream,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<EventoComentario>>(
      stream: stream,
      builder: (context, snapshot) {
        final total = snapshot.data?.length ?? 0;

        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.mode_comment_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Comentar',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$total',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FeedComentariosSheet extends StatefulWidget {
  final Evento post;
  final EventoRepository repo;
  final Stream<List<EventoComentario>> comentariosStream;
  final String? usuarioId;
  final String? nomeUsuario;
  final bool podeModerarComentarios;

  const _FeedComentariosSheet({
    required this.post,
    required this.repo,
    required this.comentariosStream,
    required this.usuarioId,
    required this.nomeUsuario,
    required this.podeModerarComentarios,
  });

  @override
  State<_FeedComentariosSheet> createState() => _FeedComentariosSheetState();
}

class _FeedComentariosSheetState extends State<_FeedComentariosSheet> {
  final TextEditingController _controller = TextEditingController();

  bool _salvando = false;

  bool get _podeComentar {
    return widget.usuarioId != null &&
        widget.usuarioId!.trim().isNotEmpty &&
        widget.nomeUsuario != null &&
        widget.nomeUsuario!.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _enviarComentario() async {
    if (_salvando) return;

    if (!_podeComentar) {
      _mostrarSnackBar('Nao foi possivel identificar a usuaria logada.');
      return;
    }

    setState(() => _salvando = true);

    try {
      await widget.repo.adicionarComentario(
        eventoId: widget.post.id,
        autorId: widget.usuarioId!,
        autorNome: widget.nomeUsuario!,
        texto: _controller.text,
      );
      _controller.clear();
      FocusScope.of(context).unfocus();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        _mostrarSnackBar(
          'As permissoes do feed ainda nao foram liberadas para comentarios.',
        );
      } else {
        _mostrarSnackBar('Nao foi possivel enviar seu comentario agora.');
      }
    } on StateError catch (e) {
      _mostrarSnackBar(e.message);
    } catch (_) {
      _mostrarSnackBar('Nao foi possivel enviar seu comentario agora.');
    } finally {
      if (mounted) {
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _excluirComentario(EventoComentario comentario) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir comentário?'),
        content: const Text('Essa ação remove o comentário permanentemente.'),
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

    if (confirmar != true) return;

    try {
      await widget.repo.removerComentario(
        eventoId: widget.post.id,
        comentarioId: comentario.id,
      );
    } catch (_) {
      _mostrarSnackBar('Nao foi possivel excluir o comentario agora.');
    }
  }

  void _mostrarSnackBar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: FractionallySizedBox(
          heightFactor: 0.82,
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Comentários',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.post.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<List<EventoComentario>>(
                      stream: widget.comentariosStream,
                      builder: (context, snapshot) {
                        final comentarios =
                            snapshot.data ?? const <EventoComentario>[];

                        if (comentarios.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Ainda não há comentários. Seja a primeira a comentar.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: comentarios.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comentario = comentarios[index];
                            final podeExcluir = widget.podeModerarComentarios ||
                                comentario.autorId == widget.usuarioId;

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primaryLight,
                                    child: Text(
                                      _iniciais(comentario.autorNome),
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                comentario.autorNome,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _tempoRelativo(
                                                  comentario.criadoEm),
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (podeExcluir) ...[
                                              const SizedBox(width: 4),
                                              IconButton(
                                                onPressed: () =>
                                                    _excluirComentario(
                                                        comentario),
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 18,
                                                  color: AppColors.textHint,
                                                ),
                                                visualDensity:
                                                    VisualDensity.compact,
                                                splashRadius: 18,
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          comentario.texto,
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
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 500,
                          decoration: InputDecoration(
                            hintText: _podeComentar
                                ? 'Escreva um comentário...'
                                : 'Comentário indisponível',
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            counterText: '',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _podeComentar && !_salvando
                            ? _enviarComentario
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(54, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: _salvando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
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

String _iniciais(String valor) {
  final partes = valor
      .split(' ')
      .where((parte) => parte.trim().isNotEmpty)
      .take(2)
      .toList();
  if (partes.isEmpty) return 'F';

  return partes.map((parte) => parte[0].toUpperCase()).join();
}

String _limitarRotulo(String valor) {
  final limpo = valor.trim();
  if (limpo.length <= 12) return limpo;
  return '${limpo.substring(0, 12)}...';
}

String _tempoRelativo(DateTime dataHora) {
  final agora = DateTime.now();
  final diferenca = agora.difference(dataHora);

  if (diferenca.inMinutes < 1) return 'agora';
  if (diferenca.inMinutes < 60) return '${diferenca.inMinutes} min';
  if (diferenca.inHours < 24) return '${diferenca.inHours} h';
  if (diferenca.inDays < 7) return '${diferenca.inDays} d';
  return DateFormatter.data(dataHora);
}
