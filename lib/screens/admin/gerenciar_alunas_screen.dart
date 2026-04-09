import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../repositories/usuario_repository.dart';
import '../../core/utils/date_formatter.dart';
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
          .get();
      // Inclui apenas alunas aprovadas (ou sem campo, para compatibilidade)
      final alunas = snap.docs
          .map((d) => Usuario.fromMap(d.data(), d.id))
          .where((u) => u.statusCadastro == 'aprovado')
          .toList()
        ..sort((a, b) => a.nome.compareTo(b.nome));
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        onAlunaExcluida: _removerAlunaDaLista,
      ),
    );
  }

  void _removerAlunaDaLista(String alunaId) {
    setState(() {
      _alunas.removeWhere((aluna) => aluna.id == alunaId);
      _alunasFiltradas = _alunas.where((aluna) {
        final termo = _buscaController.text.toLowerCase();
        return aluna.nome.toLowerCase().contains(termo) ||
            aluna.email.toLowerCase().contains(termo);
      }).toList();
    });
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(aluna.email),
            if (aluna.nivel != null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: aluna.nivel!.cor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: aluna.nivel!.cor, width: 0.8),
                ),
                child: Text(
                  aluna.nivel!.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: aluna.nivel!.cor,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AlunaDetalhesSheet extends StatefulWidget {
  final Usuario aluna;
  final AssinaturaRepository assinaturaRepo;
  final HorarioFixoRepository horarioFixoRepo;
  final void Function(String alunaId) onAlunaExcluida;

  const _AlunaDetalhesSheet({
    required this.aluna,
    required this.assinaturaRepo,
    required this.horarioFixoRepo,
    required this.onAlunaExcluida,
  });

  @override
  State<_AlunaDetalhesSheet> createState() => _AlunaDetalhesSheetState();
}

class _AlunaDetalhesSheetState extends State<_AlunaDetalhesSheet> {
  Assinatura? _assinatura;
  List<HorarioFixo> _horarios = [];
  bool _carregando = true;
  late NivelAluna? _nivel;
  bool _salvandoNivel = false;
  bool _salvandoVencimento = false;
  final UsuarioRepository _usuarioRepo = UsuarioRepository();

  @override
  void initState() {
    super.initState();
    _nivel = widget.aluna.nivel;
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

  Future<void> _atualizarNivel(NivelAluna? novoNivel) async {
    setState(() => _salvandoNivel = true);
    try {
      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.aluna.id)
          .update({'nivel': novoNivel?.valor});
      setState(() => _nivel = novoNivel);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao salvar nível')),
        );
      }
    } finally {
      setState(() => _salvandoNivel = false);
    }
  }

  Future<void> _editarVencimento() async {
    if (_assinatura == null) return;
    final atual = _assinatura!.dataRenovacao;
    final novaData = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2099),
      locale: const Locale('pt', 'BR'),
    );
    if (novaData == null || !mounted) return;

    setState(() => _salvandoVencimento = true);
    try {
      await FirebaseFirestore.instance
          .collection('assinaturas')
          .doc(_assinatura!.id)
          .update({'dataRenovacao': Timestamp.fromDate(novaData)});
      setState(() {
        _assinatura = Assinatura(
          id: _assinatura!.id,
          alunaId: _assinatura!.alunaId,
          planoId: _assinatura!.planoId,
          status: _assinatura!.status,
          creditosDisponiveis: _assinatura!.creditosDisponiveis,
          dataInicio: _assinatura!.dataInicio,
          dataRenovacao: novaData,
          dataCancelamento: _assinatura!.dataCancelamento,
          horarioFixoIds: _assinatura!.horarioFixoIds,
          aulasRealizadas: _assinatura!.aulasRealizadas,
          reposicoesDisponiveis: _assinatura!.reposicoesDisponiveis,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data de vencimento atualizada!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      setState(() => _salvandoVencimento = false);
    }
  }

  Future<void> _excluirAluna() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir aluna'),
        content: Text(
          'Tem certeza que deseja excluir ${widget.aluna.nome}?\n\n'
          'O acesso dela ao app será bloqueado imediatamente e os horários fixos serão liberados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmado != true || !mounted) return;

    // Mostra loading enquanto processa
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fn = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('excluirAluna');
      await fn.call({'alunaId': widget.aluna.id});
      widget.onAlunaExcluida(widget.aluna.id);

      if (mounted) {
        Navigator.of(context).pop(); // fecha loading
        Navigator.of(context).pop(); // fecha o sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${widget.aluna.nome} foi removida e o acesso bloqueado.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // fecha loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir aluna: $e')),
        );
      }
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
                  // ── Nível da aluna ──────────────────────────────────
                  Row(
                    children: [
                      const Text(
                        'Nível',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (_salvandoNivel)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: NivelAluna.values.map((n) {
                      final selecionado = _nivel == n;
                      return ChoiceChip(
                        label: Text(n.label),
                        selected: selecionado,
                        selectedColor: n.cor.withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: selecionado ? n.cor : Colors.black87,
                          fontWeight:
                              selecionado ? FontWeight.bold : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: selecionado ? n.cor : Colors.grey.shade300,
                        ),
                        onSelected: _salvandoNivel
                            ? null
                            : (_) => _atualizarNivel(selecionado ? null : n),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        'Assinatura',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      if (_salvandoVencimento)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
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
                                'Status', _assinatura!.status.toUpperCase()),
                            _InfoRow('Créditos',
                                '${_assinatura!.creditosDisponiveis}'),
                            _InfoRow('Aulas realizadas',
                                '${_assinatura!.aulasRealizadas}'),
                            _InfoRow('Reposições disponíveis',
                                '${_assinatura!.reposicoesDisponiveis}'),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Vencimento',
                                  style:
                                      TextStyle(color: AppColors.textSecondary),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      DateFormatter.data(
                                          _assinatura!.dataRenovacao),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: _salvandoVencimento
                                          ? null
                                          : _editarVencimento,
                                      child: const Icon(
                                        Icons.edit_calendar_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                    ..._horarios.map((h) {
                      final proxima =
                          _proximaOcorrencia(h.diaSemana, h.horario);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: const Icon(Icons.schedule,
                              color: AppColors.primary),
                          title: Text(
                              '${h.diaSemanaTexto} às ${h.horario} • ${h.modalidade}'),
                          subtitle:
                              Text('Próxima: ${DateFormatter.data(proxima)}'),
                          trailing: h.ativo
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.cancel, color: Colors.red),
                        ),
                      );
                    }),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    onPressed: _excluirAluna,
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    label: const Text(
                      'Excluir aluna',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
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
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Calcula a próxima ocorrência de um horário fixo a partir de agora.
DateTime _proximaOcorrencia(int diaSemana, String horario) {
  final agora = DateTime.now();
  final partes = horario.split(':');
  final hora = int.parse(partes[0]);
  final minuto = int.parse(partes[1]);
  final int diasAte = (diaSemana - agora.weekday) % 7;
  DateTime candidato = DateTime(
    agora.year,
    agora.month,
    agora.day + diasAte,
    hora,
    minuto,
  );
  if (candidato.isBefore(agora)) {
    candidato = candidato.add(const Duration(days: 7));
  }
  return candidato;
}
