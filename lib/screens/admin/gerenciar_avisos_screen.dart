import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/aviso_timeline_helper.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/evento.dart';
import '../../repositories/evento_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class GerenciarAvisosScreen extends StatefulWidget {
  const GerenciarAvisosScreen({super.key});

  @override
  State<GerenciarAvisosScreen> createState() => _GerenciarAvisosScreenState();
}

class _GerenciarAvisosScreenState extends State<GerenciarAvisosScreen> {
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

        await _repo.criarComImagem(
          evento: aviso,
          imagem: resultado.imagemArquivo!,
        );
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
                ? 'Aviso publicado com sucesso.'
                : 'Aviso atualizado com sucesso.',
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
                ? 'Aviso ocultado da timeline.'
                : 'Aviso publicado para as alunas.',
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
        const SnackBar(content: Text('Aviso removido.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao excluir aviso: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Timeline de Avisos'),
        actions: [
          IconButton(
            onPressed: _carregarAvisos,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _carregando ? null : _abrirFormulario,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Novo aviso'),
      ),
      body: _carregando
          ? const LoadingIndicator()
          : RefreshIndicator(
              onRefresh: _carregarAvisos,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _ResumoAvisosCard(
                    total: _avisos.length,
                    publicados: publicados,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (valor) => setState(() => _busca = valor),
                    decoration: InputDecoration(
                      hintText: 'Buscar aviso, evento ou workshop',
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
                    const _EstadoVazioAvisos()
                  else
                    ...avisosFiltrados.map(
                      (aviso) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _AvisoAdminCard(
                          aviso: aviso,
                          onEditar: () => _abrirFormulario(aviso),
                          onAlternarPublicacao: () =>
                              _alternarPublicacao(aviso),
                          onExcluir: () => _excluirAviso(aviso),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ResumoAvisosCard extends StatelessWidget {
  final int total;
  final int publicados;

  const _ResumoAvisosCard({required this.total, required this.publicados});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mural visual do estúdio',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cadastre imagens e textos para alimentar automaticamente a timeline das alunas.',
            style: TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ResumoAvisoPill(titulo: 'Total cadastrados', valor: '$total'),
              _ResumoAvisoPill(titulo: 'Publicados', valor: '$publicados'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResumoAvisoPill extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ResumoAvisoPill({required this.titulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
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
          Text(titulo, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _EstadoVazioAvisos extends StatelessWidget {
  const _EstadoVazioAvisos();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 52,
            color: AppColors.primaryLight,
          ),
          SizedBox(height: 14),
          Text(
            'Nenhum aviso cadastrado',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Crie o primeiro conteúdo visual para aparecer na timeline das alunas.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AvisoAdminCard extends StatelessWidget {
  final Evento aviso;
  final VoidCallback onEditar;
  final VoidCallback onAlternarPublicacao;
  final VoidCallback onExcluir;

  const _AvisoAdminCard({
    required this.aviso,
    required this.onEditar,
    required this.onAlternarPublicacao,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final categoriaColor = AvisoTimelineHelper.color(aviso.categoria);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onEditar,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: aviso.imagemUrl != null && aviso.imagemUrl!.isNotEmpty
                    ? Image.network(
                        aviso.imagemUrl!,
                        width: 92,
                        height: 92,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _PlaceholderAvisoImagem(
                          categoria: aviso.categoria,
                        ),
                      )
                    : _PlaceholderAvisoImagem(categoria: aviso.categoria),
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
                            aviso.titulo,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (valor) {
                            if (valor == 'editar') onEditar();
                            if (valor == 'publicar') onAlternarPublicacao();
                            if (valor == 'excluir') onExcluir();
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                            PopupMenuItem(
                              value: 'publicar',
                              child: Text(
                                aviso.publicado ? 'Despublicar' : 'Publicar',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'excluir',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _BadgeAvisoAdmin(
                          label: AvisoTimelineHelper.label(aviso.categoria),
                          color: categoriaColor,
                        ),
                        _BadgeAvisoAdmin(
                          label: DateFormatter.data(aviso.dataHora),
                          color: AppColors.secondary,
                        ),
                        _BadgeAvisoAdmin(
                          label: aviso.publicado ? 'Publicado' : 'Rascunho',
                          color: aviso.publicado
                              ? AppColors.success
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      aviso.descricao,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    if (aviso.local != null &&
                        aviso.local!.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              aviso.local!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
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
      ),
    );
  }
}

class _PlaceholderAvisoImagem extends StatelessWidget {
  final String categoria;

  const _PlaceholderAvisoImagem({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final color = AvisoTimelineHelper.color(categoria);

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        AvisoTimelineHelper.icon(categoria),
        color: Colors.white,
      ),
    );
  }
}

class _BadgeAvisoAdmin extends StatelessWidget {
  final String label;
  final Color color;

  const _BadgeAvisoAdmin({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
  String? _erroImagem;

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
      _erroImagem = null;
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

    if (_imagemArquivo == null &&
        (widget.aviso?.imagemUrl == null || widget.aviso!.imagemUrl!.isEmpty)) {
      setState(() => _erroImagem = 'Selecione uma imagem para o aviso.');
      return;
    }

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
                    widget.aviso == null ? 'Novo aviso' : 'Editar aviso',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Crie um card visual para a timeline automática das alunas.',
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
                            ? 'Escolher imagem'
                            : 'Trocar imagem',
                      ),
                    ),
                  ),
                  if (_erroImagem != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _erroImagem!,
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
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
