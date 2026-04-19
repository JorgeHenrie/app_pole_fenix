import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/aviso_timeline_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/evento.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/evento_repository.dart';
import '../../widgets/common/loading_indicator.dart';
import '../../widgets/common/studio_feed_widgets.dart';

class GerenciarAvisosScreen extends StatefulWidget {
  const GerenciarAvisosScreen({super.key});

  @override
  State<GerenciarAvisosScreen> createState() => _GerenciarAvisosScreenState();
}

class _GerenciarAvisosScreenState extends State<GerenciarAvisosScreen> {
  static const String _nomeStudio = 'Fênix Pole Dance';

  final EventoRepository _repo = EventoRepository();

  bool _carregando = false;
  String _busca = '';
  List<Evento> _avisos = [];

  @override
  void initState() {
    super.initState();
    _carregarAvisos();
  }

  Future<void> _carregarAvisos() async {
    setState(() => _carregando = true);

    try {
      final avisos = await _repo.listarTodos();
      if (!mounted) return;
      setState(() => _avisos = avisos);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar avisos: $e')),
      );
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirFormulario([Evento? existente]) async {
    final resultado = await showModalBottomSheet<_FormularioAvisoResultado>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioAvisoSheet(aviso: existente),
    );

    if (resultado == null) return;

    try {
      if (existente == null) {
        final aviso = Evento(
          id: '',
          titulo: resultado.titulo,
          descricao: resultado.descricao,
          dataHora: resultado.dataHora,
          categoria: resultado.categoria,
          local: resultado.local,
          imagemUrl: null,
          imagemStoragePath: null,
          publicado: resultado.publicado,
          criadoEm: DateTime.now(),
        );

        if (resultado.imagemArquivo != null) {
          await _repo.criarComImagem(
            evento: aviso,
            imagem: resultado.imagemArquivo!,
          );
        } else {
          await _repo.criar(aviso);
        }
      } else {
        final avisoAtualizado = existente.copyWith(
          titulo: resultado.titulo,
          descricao: resultado.descricao,
          dataHora: resultado.dataHora,
          categoria: resultado.categoria,
          local: resultado.local,
          publicado: resultado.publicado,
          atualizadoEm: DateTime.now(),
        );

        await _repo.atualizarComImagem(
          evento: avisoAtualizado,
          novaImagem: resultado.imagemArquivo,
        );
      }

      await _carregarAvisos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existente == null
                ? 'Post publicado com sucesso.'
                : 'Post atualizado com sucesso.',
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
        SnackBar(content: Text('Erro ao salvar aviso: $e')),
      );
    }
  }

  Future<void> _alternarPublicacao(Evento aviso) async {
    try {
      await _repo.atualizar(
        aviso.copyWith(
          publicado: !aviso.publicado,
          atualizadoEm: DateTime.now(),
        ),
      );
      await _carregarAvisos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            aviso.publicado
                ? 'Post ocultado do feed.'
                : 'Post publicado para as alunas.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar publicação: $e')),
      );
    }
  }

  Future<void> _excluirAviso(Evento aviso) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir aviso?'),
        content: Text(
          'Deseja excluir "${aviso.titulo}" da timeline? Essa ação remove a imagem cadastrada.',
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

    if (confirmar != true) return;

    try {
      await _repo.removerComImagem(aviso);
      await _carregarAvisos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post removido.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir post: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuarioLogado = context.watch<AuthProvider>().usuario;
    final avisosFiltrados = _avisos.where((aviso) {
      final termo = _busca.trim().toLowerCase();
      if (termo.isEmpty) return true;
      return aviso.titulo.toLowerCase().contains(termo) ||
          aviso.descricao.toLowerCase().contains(termo) ||
          AvisoTimelineHelper.label(aviso.categoria)
              .toLowerCase()
              .contains(termo);
    }).toList();

    final publicados = _avisos.where((item) => item.publicado).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            onPressed: _carregarAvisos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregarAvisos,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  StudioFeedSectionHeader(
                    titulo: 'Destaques',
                    subtitulo:
                        '$publicados publicado(s) • ${_avisos.length} post(s) no total',
                    icone: Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(height: 14),
                  StudioFeedHighlightsRow(
                    posts: _avisos,
                    nomeStudio: _nomeStudio,
                    onCriarTap: _abrirFormulario,
                    onHighlightTap: _abrirFormulario,
                  ),
                  const SizedBox(height: 18),
                  const StudioFeedSectionHeader(
                    titulo: 'Feed',
                    subtitulo: 'Compartilhe com a turma',
                    icone: Icons.dynamic_feed_rounded,
                  ),
                  const SizedBox(height: 14),
                  StudioFeedComposerCard(
                    nomeStudio: _nomeStudio,
                    placeholder: 'Compartilhe uma novidade com a turma...',
                    habilitado: true,
                    onTap: _abrirFormulario,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    onChanged: (valor) => setState(() => _busca = valor),
                    decoration: InputDecoration(
                      hintText: 'Buscar no feed',
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
                  if (avisosFiltrados.isEmpty)
                    const StudioFeedEmptyState(
                      titulo: 'Nenhum post cadastrado',
                      descricao:
                          'Crie o primeiro post para aparecer no feed das alunas.',
                    )
                  else
                    ...avisosFiltrados.map(
                      (aviso) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: StudioFeedPostCard(
                          key: ValueKey(aviso.id),
                          post: aviso,
                          nomeAutor: _nomeStudio,
                          badge: aviso.publicado ? 'ESCOLA' : 'RASCUNHO',
                          badgeColor: aviso.publicado
                              ? AppColors.accentCocoa
                              : AppColors.textHint,
                          usuarioId: usuarioLogado?.id,
                          nomeUsuario: usuarioLogado?.nome,
                          podeModerarComentarios:
                              usuarioLogado?.tipoUsuario == 'admin',
                          onActionSelected: (acao) {
                            switch (acao) {
                              case StudioFeedPostAction.editar:
                                _abrirFormulario(aviso);
                                break;
                              case StudioFeedPostAction.alternarPublicacao:
                                _alternarPublicacao(aviso);
                                break;
                              case StudioFeedPostAction.excluir:
                                _excluirAviso(aviso);
                                break;
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FormularioAvisoResultado {
  final String titulo;
  final String descricao;
  final String categoria;
  final DateTime dataHora;
  final String? local;
  final bool publicado;
  final File? imagemArquivo;

  const _FormularioAvisoResultado({
    required this.titulo,
    required this.descricao,
    required this.categoria,
    required this.dataHora,
    required this.local,
    required this.publicado,
    required this.imagemArquivo,
  });
}

class _FormularioAvisoSheet extends StatefulWidget {
  final Evento? aviso;

  const _FormularioAvisoSheet({this.aviso});

  @override
  State<_FormularioAvisoSheet> createState() => _FormularioAvisoSheetState();
}

class _FormularioAvisoSheetState extends State<_FormularioAvisoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _tituloController;
  late final TextEditingController _descricaoController;
  late final TextEditingController _localController;
  late DateTime _dataHora;
  late String _categoria;
  late bool _publicado;
  File? _imagemArquivo;

  @override
  void initState() {
    super.initState();
    _tituloController = TextEditingController(text: widget.aviso?.titulo ?? '');
    _descricaoController = TextEditingController(
      text: widget.aviso?.descricao ?? '',
    );
    _localController = TextEditingController(text: widget.aviso?.local ?? '');
    _dataHora = widget.aviso?.dataHora ?? DateTime.now();
    _categoria =
        widget.aviso?.categoria ?? AvisoTimelineHelper.categorias.first;
    _publicado = widget.aviso?.publicado ?? true;
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _localController.dispose();
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    final imagem = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 1800,
    );
    if (imagem == null) return;

    setState(() {
      _imagemArquivo = File(imagem.path);
    });
  }

  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataHora,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      locale: const Locale('pt', 'BR'),
    );

    if (data == null) return;

    setState(() {
      _dataHora = DateTime(
        data.year,
        data.month,
        data.day,
        _dataHora.hour,
        _dataHora.minute,
      );
    });
  }

  void _salvar() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      _FormularioAvisoResultado(
        titulo: _tituloController.text.trim(),
        descricao: _descricaoController.text.trim(),
        categoria: _categoria,
        dataHora: _dataHora,
        local: _localController.text.trim().isEmpty
            ? null
            : _localController.text.trim(),
        publicado: _publicado,
        imagemArquivo: _imagemArquivo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imagemUrlAtual = widget.aviso?.imagemUrl;

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
                    widget.aviso == null ? 'Novo post' : 'Editar post',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Publique um texto para o feed das alunas. A imagem é opcional.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: _imagemArquivo != null
                        ? Image.file(
                            _imagemArquivo!,
                            width: double.infinity,
                            height: 190,
                            fit: BoxFit.cover,
                          )
                        : imagemUrlAtual != null && imagemUrlAtual.isNotEmpty
                            ? Image.network(
                                imagemUrlAtual,
                                width: double.infinity,
                                height: 190,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: double.infinity,
                                height: 190,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.primary,
                                      AppColors.accentCocoa,
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.photo_library_outlined,
                                    color: Colors.white,
                                    size: 42,
                                  ),
                                ),
                              ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _selecionarImagem,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                        _imagemArquivo == null &&
                                (imagemUrlAtual == null ||
                                    imagemUrlAtual.isEmpty)
                            ? 'Adicionar imagem opcional'
                            : 'Trocar imagem',
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tituloController,
                    decoration: const InputDecoration(
                      labelText: 'Título',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Informe o título do aviso.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descricaoController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Descrição',
                      border: OutlineInputBorder(),
                    ),
                    validator: (valor) {
                      if (valor == null || valor.trim().isEmpty) {
                        return 'Escreva a descrição do aviso.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _categoria,
                    items: AvisoTimelineHelper.categorias
                        .map(
                          (categoria) => DropdownMenuItem(
                            value: categoria,
                            child: Text(AvisoTimelineHelper.label(categoria)),
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
                  InkWell(
                    onTap: _selecionarData,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.greyLight),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Data de exibição',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormatter.data(_dataHora),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _localController,
                    decoration: const InputDecoration(
                      labelText: 'Local ou observação opcional',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    value: _publicado,
                    onChanged: (valor) => setState(() => _publicado = valor),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publicado para as alunas'),
                    subtitle: const Text(
                      'Desative para deixar salvo como rascunho.',
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
                            widget.aviso == null ? 'Publicar' : 'Salvar',
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
