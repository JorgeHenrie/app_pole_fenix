import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/assinatura.dart';
import '../../models/horario_fixo.dart';
import '../../models/usuario.dart';
import '../../repositories/assinatura_repository.dart';
import '../../repositories/horario_fixo_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class GerenciarAlunasScreen extends StatefulWidget {
  const GerenciarAlunasScreen({super.key});

  @override
  State<GerenciarAlunasScreen> createState() => _GerenciarAlunasScreenState();
}

class _GerenciarAlunasScreenState extends State<GerenciarAlunasScreen> {
  final AssinaturaRepository _assinaturaRepo = AssinaturaRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();

  List<Usuario> _alunas = [];
  List<Usuario> _alunasFiltradas = [];
  bool _carregando = false;
  final _buscaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carregarAlunas();
    _buscaController.addListener(_filtrar);
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _carregarAlunas() async {
    setState(() => _carregando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('tipoUsuario', isEqualTo: 'aluna')
          .where('ativo', isEqualTo: true)
          .orderBy('nome')
          .get();
      final alunas =
          snap.docs.map((d) => Usuario.fromMap(d.data(), d.id)).toList();
      setState(() {
        _alunas = alunas;
        _alunasFiltradas = alunas;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar alunas')),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  void _filtrar() {
    final termo = _buscaController.text.toLowerCase();
    setState(() {
      _alunasFiltradas = _alunas
          .where((a) =>
              a.nome.toLowerCase().contains(termo) ||
              a.email.toLowerCase().contains(termo))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Gerenciar Alunas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregarAlunas,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _buscaController,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou email...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _carregando
                ? const LoadingIndicator()
                : _alunasFiltradas.isEmpty
                    ? Center(
                        child: Text(
                          _buscaController.text.isEmpty
                              ? 'Nenhuma aluna cadastrada'
                              : 'Nenhuma aluna encontrada',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _carregarAlunas,
                        child: ListView.builder(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _alunasFiltradas.length,
                          itemBuilder: (context, index) => _AlunaCard(
                            aluna: _alunasFiltradas[index],
                            onTap: () =>
                                _mostrarDetalhes(_alunasFiltradas[index]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDetalhes(Usuario aluna) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AlunaDetalhesSheet(
        aluna: aluna,
        assinaturaRepo: _assinaturaRepo,
        horarioFixoRepo: _horarioFixoRepo,
      ),
    );
  }
}

class _AlunaCard extends StatelessWidget {
  final Usuario aluna;
  final VoidCallback onTap;

  const _AlunaCard({required this.aluna, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final iniciais = aluna.nome
        .trim()
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join('');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          backgroundImage:
              aluna.fotoUrl != null ? NetworkImage(aluna.fotoUrl!) : null,
          child: aluna.fotoUrl == null
              ? Text(
                  iniciais,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          aluna.nome,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(aluna.email),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AlunaDetalhesSheet extends StatefulWidget {
  final Usuario aluna;
  final AssinaturaRepository assinaturaRepo;
  final HorarioFixoRepository horarioFixoRepo;

  const _AlunaDetalhesSheet({
    required this.aluna,
    required this.assinaturaRepo,
    required this.horarioFixoRepo,
  });

  @override
  State<_AlunaDetalhesSheet> createState() => _AlunaDetalhesSheetState();
}

class _AlunaDetalhesSheetState extends State<_AlunaDetalhesSheet> {
  Assinatura? _assinatura;
  List<HorarioFixo> _horarios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final results = await Future.wait([
        widget.assinaturaRepo.buscarAtivaDeAluna(widget.aluna.id),
        widget.horarioFixoRepo.buscarPorAluna(widget.aluna.id),
      ]);
      setState(() {
        _assinatura = results[0] as Assinatura?;
        _horarios = results[1] as List<HorarioFixo>;
        _carregando = false;
      });
    } catch (_) {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (context, controller) => Padding(
        padding: const EdgeInsets.all(16),
        child: _carregando
            ? const LoadingIndicator()
            : ListView(
                controller: controller,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.primary,
                        backgroundImage: widget.aluna.fotoUrl != null
                            ? NetworkImage(widget.aluna.fotoUrl!)
                            : null,
                        child: widget.aluna.fotoUrl == null
                            ? Text(
                                widget.aluna.nome
                                    .trim()
                                    .split(' ')
                                    .take(2)
                                    .map((p) =>
                                        p.isNotEmpty ? p[0].toUpperCase() : '')
                                    .join(''),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.aluna.nome,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.aluna.email,
                              style: const TextStyle(
                                  color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Assinatura',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_assinatura == null)
                    const Text('Sem assinatura ativa',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            _InfoRow(
                                'Status',
                                _assinatura!.status.toUpperCase()),
                            _InfoRow('Créditos',
                                '${_assinatura!.creditosDisponiveis}'),
                            _InfoRow('Aulas realizadas',
                                '${_assinatura!.aulasRealizadas}'),
                            _InfoRow('Reposições disponíveis',
                                '${_assinatura!.reposicoesDisponiveis}'),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Horários Fixos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_horarios.isEmpty)
                    const Text('Nenhum horário fixo cadastrado',
                        style: TextStyle(color: AppColors.textSecondary))
                  else
                    ..._horarios.map((h) => Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.schedule,
                                color: AppColors.primary),
                            title: Text(h.diaSemanaTexto),
                            subtitle:
                                Text('${h.horario} • ${h.modalidade}'),
                            trailing: h.ativo
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : const Icon(Icons.cancel,
                                    color: Colors.red),
                          ),
                        )),
                ],
              ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
