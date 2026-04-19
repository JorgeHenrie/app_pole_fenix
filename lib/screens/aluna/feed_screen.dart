import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../models/evento.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/evento_repository.dart';
import '../../widgets/aluna/aluna_drawer.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/studio_feed_widgets.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  static const String _nomeStudio = 'Fênix Pole Dance';

  final EventoRepository _repo = EventoRepository();

  bool _carregando = true;
  String? _erro;
  List<Evento> _posts = [];

  @override
  void initState() {
    super.initState();
    _carregarPosts();
  }

  Future<void> _carregarPosts() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final posts = await _repo.listarPublicados();
      if (!mounted) return;
      setState(() => _posts = posts);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _erro = 'Nao foi possivel carregar o feed agora. Tente novamente.';
      });
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = context.watch<AuthProvider>().usuario;

    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: const AlunaDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text('Feed'),
        actions: [
          IconButton(
            onPressed: _carregarPosts,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _erro != null
              ? StudioFeedErrorState(
                  mensagem: _erro!,
                  onTentarNovamente: _carregarPosts,
                )
              : RefreshIndicator(
                  onRefresh: _carregarPosts,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      StudioFeedSectionHeader(
                        titulo: 'Destaques',
                        subtitulo: _posts.isEmpty
                            ? 'Ainda sem publicações recentes'
                            : '${_posts.length} publicação(ões) recente(s)',
                        icone: Icons.auto_awesome_rounded,
                      ),
                      const SizedBox(height: 14),
                      StudioFeedHighlightsRow(
                        posts: _posts,
                        nomeStudio: _nomeStudio,
                      ),
                      const SizedBox(height: 18),
                      const StudioFeedSectionHeader(
                        titulo: 'Feed',
                        subtitulo: 'Acompanhe as novidades da turma',
                        icone: Icons.dynamic_feed_rounded,
                      ),
                      const SizedBox(height: 14),
                      const StudioFeedComposerCard(
                        nomeStudio: _nomeStudio,
                        placeholder: 'Acompanhe as novidades da turma...',
                      ),
                      const SizedBox(height: 16),
                      if (_posts.isEmpty)
                        const StudioFeedEmptyState(
                          titulo: 'Nenhuma publicação ainda',
                          descricao:
                              'Quando o estúdio publicar uma novidade, ela vai aparecer aqui no feed.',
                        )
                      else
                        ..._posts.map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StudioFeedPostCard(
                              key: ValueKey(post.id),
                              post: post,
                              nomeAutor: _nomeStudio,
                              badge: 'ESCOLA',
                              badgeColor: AppColors.accentCocoa,
                              usuarioId: usuarioLogado?.id,
                              nomeUsuario: usuarioLogado?.nome,
                              podeModerarComentarios:
                                  usuarioLogado?.tipoUsuario == 'admin',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
