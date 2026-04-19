import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/assinatura.dart';
import '../../models/plano.dart';
import '../../models/solicitacao_migracao_plano.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../providers/plano_provider.dart';
import '../../repositories/solicitacao_migracao_plano_repository.dart';
import '../../widgets/aluna/aluna_drawer.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela de planos da aluna, com detalhes, documentos e solicitação de migração.
class MeuPlanoScreen extends StatefulWidget {
  const MeuPlanoScreen({super.key});

  @override
  State<MeuPlanoScreen> createState() => _MeuPlanoScreenState();
}

class _MeuPlanoScreenState extends State<MeuPlanoScreen> {
  static const String _chavePixMigracao = '04792088240';

  final SolicitacaoMigracaoPlanoRepository _migracaoRepo =
      SolicitacaoMigracaoPlanoRepository();

  String? _planoExpandidoId;
  String? _planoSolicitandoId;
  bool _carregandoSolicitacoes = false;
  SolicitacaoMigracaoPlano? _solicitacaoPendente;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeProvider = context.read<HomeAlunaProvider>();
      final planoProvider = context.read<PlanoProvider>();
      final usuario = context.read<AuthProvider>().usuario;

      if (homeProvider.assinatura == null && !homeProvider.carregando) {
        if (usuario != null) {
          homeProvider.carregarDados(usuario.id);
        }
      }

      if (!planoProvider.carregando && planoProvider.planos.isEmpty) {
        planoProvider.carregarPlanos();
      }

      if (usuario != null) {
        _carregarSolicitacaoPendente(usuario.id);
      }
    });
  }

  Future<void> _carregarSolicitacaoPendente(String alunaId) async {
    setState(() => _carregandoSolicitacoes = true);

    SolicitacaoMigracaoPlano? solicitacao;
    try {
      solicitacao = await _migracaoRepo.buscarPendentePorAluna(alunaId);
    } catch (_) {
      solicitacao = null;
    }

    if (!mounted) return;
    setState(() {
      _solicitacaoPendente = solicitacao;
      _carregandoSolicitacoes = false;
    });
  }

  Future<void> _recarregarDados() async {
    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    await Future.wait([
      context.read<HomeAlunaProvider>().carregarDados(usuario.id),
      context.read<PlanoProvider>().carregarPlanos(),
      _carregarSolicitacaoPendente(usuario.id),
    ]);
  }

  Future<void> _baixarContrato(
    Assinatura assinatura,
    Plano plano,
    String nomeAluna,
  ) async {
    final doc = pw.Document();
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          pw.Center(
            child: pw.Text(
              'CONTRATO DE PRESTAÇÃO DE SERVIÇOS',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child:
                pw.Text('Fênix Pole Dance', style: pw.TextStyle(fontSize: 13)),
          ),
          pw.Divider(),
          pw.SizedBox(height: 16),
          pw.Text('DADOS DA CONTRATANTE',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Nome: $nomeAluna'),
          pw.SizedBox(height: 16),
          pw.Text('PLANO CONTRATADO',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Plano: ${plano.nome}'),
          pw.Text('Descrição: ${plano.descricao}'),
          pw.Text('Valor Mensal: ${currencyFormat.format(plano.preco)}'),
          pw.Text('Aulas por mês: ${plano.aulasPorMes} aulas'),
          pw.Text('Aulas por semana: ${plano.aulasSemanais} aula(s)'),
          pw.SizedBox(height: 16),
          pw.Text('VIGÊNCIA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Início: ${DateFormatter.data(assinatura.dataInicio)}'),
          pw.Text('Renovação: ${DateFormatter.data(assinatura.dataRenovacao)}'),
          pw.Text('Status: ${assinatura.status.toUpperCase()}'),
          pw.SizedBox(height: 20),
          pw.Text('CLÁUSULAS CONTRATUAIS',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            '1. A contratante se compromete ao pagamento pontual da '
            'mensalidade conforme o plano escolhido.\n'
            '2. O pagamento deve ser efetuado até o dia 10 de cada mês '
            'sob pena de suspensão do acesso às aulas.\n'
            '3. Cancelamentos de aulas devem ser realizados com no mínimo '
            '2 horas de antecedência.\n'
            '4. Faltas sem aviso prévio não geram direito a reposição.\n'
            '5. O Fênix Pole Dance reserva-se o direito de alterar horários '
            'com aviso prévio de 48 horas.\n'
            '6. O contrato se renova automaticamente ao fim do ciclo do plano.\n'
            '7. Para cancelamento do contrato, deve-se notificar o estúdio '
            'com 15 dias de antecedência.',
            style: const pw.TextStyle(lineSpacing: 4),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Gerado em: ${DateFormatter.data(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> _solicitarMigracao({
    required Assinatura assinaturaAtual,
    required Plano planoAtual,
    required Plano planoDestino,
    required String nomeAluna,
  }) async {
    if (_solicitacaoPendente != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você já possui uma solicitação de migração aguardando análise.',
          ),
        ),
      );
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
        var pixCopiado = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Migrar para',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    planoDestino.nome,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogInfo('Plano atual', planoAtual.nome),
                        _buildDialogInfo('Novo plano', planoDestino.nome),
                        _buildDialogInfo(
                          'Valor mensal',
                          moeda.format(planoDestino.preco),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chave Pix (CPF)',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primaryLight.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _chavePixMigracao,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              const ClipboardData(text: _chavePixMigracao),
                            );
                            setDialogState(() => pixCopiado = true);
                          },
                          icon: Icon(
                            pixCopiado
                                ? Icons.check_rounded
                                : Icons.copy_outlined,
                            size: 18,
                          ),
                          label: Text(pixCopiado ? 'Copiado' : 'Copiar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Voltar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Solicitar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmar != true) return;

    final usuario = context.read<AuthProvider>().usuario;
    if (usuario == null) return;

    setState(() => _planoSolicitandoId = planoDestino.id);

    try {
      final solicitacao = SolicitacaoMigracaoPlano(
        id: '',
        alunaId: usuario.id,
        alunaNome: nomeAluna,
        assinaturaId: assinaturaAtual.id,
        planoAtualId: planoAtual.id,
        planoAtualNome: planoAtual.nome,
        planoDestinoId: planoDestino.id,
        planoDestinoNome: planoDestino.nome,
        valorPlanoDestino: planoDestino.preco,
        chavePix: _chavePixMigracao,
        status: 'pendente',
        solicitadoEm: DateTime.now(),
      );

      await _migracaoRepo.criar(solicitacao);
      await _carregarSolicitacaoPendente(usuario.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Solicitação de migração para ${planoDestino.nome} enviada.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      final mensagem = e.message.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao solicitar migração: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _planoSolicitandoId = null);
      }
    }
  }

  Widget _buildDialogInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarTermoAceite() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          child: const _TermoAceiteContent(),
        ),
      ),
    );
  }

  List<Plano> _ordenarPlanos(List<Plano> planos, Plano? planoAtual) {
    final lista = [...planos];

    if (planoAtual != null &&
        !lista.any((plano) => plano.id == planoAtual.id)) {
      lista.add(planoAtual);
    }

    lista.sort((a, b) {
      if (planoAtual != null) {
        if (a.id == planoAtual.id) return -1;
        if (b.id == planoAtual.id) return 1;
      }

      final porPreco = a.preco.compareTo(b.preco);
      if (porPreco != 0) return porPreco;
      return a.nome.compareTo(b.nome);
    });

    return lista;
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Planos'),
      ),
      body: Consumer3<HomeAlunaProvider, AuthProvider, PlanoProvider>(
        builder: (context, homeProvider, authProvider, planoProvider, _) {
          if (homeProvider.carregando ||
              _carregandoSolicitacoes ||
              (planoProvider.carregando && planoProvider.planos.isEmpty)) {
            return const LoadingIndicator();
          }

          final assinatura = homeProvider.assinatura;
          final planoAtual = homeProvider.plano;
          final nomeAluna = authProvider.usuario?.nome ?? 'Aluna';

          if (assinatura == null || planoAtual == null) {
            return _buildSemPlano(planoProvider.erro);
          }

          final planos = _ordenarPlanos(planoProvider.planos, planoAtual);

          return RefreshIndicator(
            onRefresh: _recarregarDados,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (planoProvider.erro != null) ...[
                  _buildErroPlanos(planoProvider.erro!),
                  const SizedBox(height: 16),
                ],
                if (_solicitacaoPendente != null) ...[
                  _buildSolicitacaoPendenteBanner(_solicitacaoPendente!),
                  const SizedBox(height: 16),
                ],
                ...planos.map(
                  (plano) {
                    final ativo = plano.id == planoAtual.id;
                    final expandido = _planoExpandidoId == plano.id;
                    final pendenteMesmoPlano =
                        _solicitacaoPendente?.planoDestinoId == plano.id;
                    final possuiSolicitacaoPendente =
                        _solicitacaoPendente != null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildPlanoCardExpansivel(
                        assinaturaAtual: assinatura,
                        planoAtual: planoAtual,
                        plano: plano,
                        ativo: ativo,
                        expandido: expandido,
                        pendenteMesmoPlano: pendenteMesmoPlano,
                        possuiSolicitacaoPendente: possuiSolicitacaoPendente,
                        nomeAluna: nomeAluna,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSemPlano(String? erro) {
    return ListView(
      padding: const EdgeInsets.all(32),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        if (erro != null) ...[
          _buildErroPlanos(erro),
          const SizedBox(height: 24),
        ],
        const SizedBox(height: 80),
        Icon(
          Icons.credit_card_off_outlined,
          size: 64,
          color: Colors.grey.shade400,
        ),
        const SizedBox(height: 16),
        Text(
          'Nenhum plano ativo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Quando houver uma assinatura ativa, seus planos aparecerão aqui.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildErroPlanos(String mensagem) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              mensagem,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => context.read<PlanoProvider>().carregarPlanos(),
            child: const Text('Tentar de novo'),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitacaoPendenteBanner(
    SolicitacaoMigracaoPlano solicitacao,
  ) {
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitação de migração em análise',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Destino: ${solicitacao.planoDestinoNome} • ${moeda.format(solicitacao.valorPlanoDestino)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Assim que o admin aprovar, este plano passa a valer no seu acesso.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanoCardExpansivel({
    required Assinatura assinaturaAtual,
    required Plano planoAtual,
    required Plano plano,
    required bool ativo,
    required bool expandido,
    required bool pendenteMesmoPlano,
    required bool possuiSolicitacaoPendente,
    required String nomeAluna,
  }) {
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    final tituloAcao = pendenteMesmoPlano
        ? 'Solicitado'
        : possuiSolicitacaoPendente
            ? 'Aguardando'
            : 'Migrar';

    final acaoDesabilitada = ativo || possuiSolicitacaoPendente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              setState(() {
                _planoExpandidoId = expandido ? null : plano.id;
              });
            },
            child: Ink(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: ativo
                      ? [AppColors.primaryDark, AppColors.accentCocoa]
                      : [
                          const Color(0xFF6C2436),
                          const Color(0xFF8B4D5D),
                        ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: ativo ? 0.12 : 0.22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark
                        .withValues(alpha: ativo ? 0.14 : 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.workspace_premium_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          plano.nome,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (ativo)
                        _buildStatusChip(
                          assinaturaAtual.estaAtiva
                              ? 'PLANO ATUAL'
                              : assinaturaAtual.status.toUpperCase(),
                        )
                      else
                        FilledButton(
                          onPressed: acaoDesabilitada ||
                                  _planoSolicitandoId == plano.id
                              ? null
                              : () => _solicitarMigracao(
                                    assinaturaAtual: assinaturaAtual,
                                    planoAtual: planoAtual,
                                    planoDestino: plano,
                                    nomeAluna: nomeAluna,
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            disabledBackgroundColor:
                                Colors.white.withValues(alpha: 0.26),
                            disabledForegroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: _planoSolicitandoId == plano.id
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryDark,
                                  ),
                                )
                              : Text(
                                  tituloAcao,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${currencyFormat.format(plano.preco)}/mês',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plano.descricao,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(
                        expandido
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        expandido
                            ? 'Toque para recolher detalhes'
                            : 'Toque para ver detalhes',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState:
              expandido ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildConteudoExpandido(
              assinaturaAtual: assinaturaAtual,
              planoAtual: planoAtual,
              planoExibido: plano,
              ativo: ativo,
              pendenteMesmoPlano: pendenteMesmoPlano,
              possuiSolicitacaoPendente: possuiSolicitacaoPendente,
              nomeAluna: nomeAluna,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildConteudoExpandido({
    required Assinatura assinaturaAtual,
    required Plano planoAtual,
    required Plano planoExibido,
    required bool ativo,
    required bool pendenteMesmoPlano,
    required bool possuiSolicitacaoPendente,
    required String nomeAluna,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ativo ? 'Detalhes do plano atual' : 'Detalhes deste plano',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Divider(height: 24),
            if (ativo) ...[
              _buildDetalheItem(
                Icons.fitness_center,
                'Aulas por mês',
                '${planoExibido.aulasPorMes} aulas',
              ),
              _buildDetalheItem(
                Icons.today,
                'Aulas por semana',
                '${planoExibido.aulasSemanais} aula(s)',
              ),
              _buildDetalheItem(
                Icons.stars_outlined,
                'Créditos disponíveis',
                '${assinaturaAtual.creditosDisponiveis}',
              ),
              _buildDetalheItem(
                Icons.check_circle_outline,
                'Aulas realizadas',
                '${assinaturaAtual.aulasRealizadas}',
              ),
              _buildDetalheItem(
                Icons.event,
                'Início',
                DateFormatter.data(assinaturaAtual.dataInicio),
              ),
              _buildDetalheItem(
                Icons.autorenew,
                'Próxima renovação',
                DateFormatter.data(assinaturaAtual.dataRenovacao),
              ),
              const SizedBox(height: 18),
              _buildAcoes(assinaturaAtual, planoExibido, nomeAluna),
            ] else ...[
              _buildDetalheItem(
                Icons.fitness_center,
                'Aulas por mês',
                '${planoExibido.aulasPorMes} aulas',
              ),
              _buildDetalheItem(
                Icons.date_range_outlined,
                'Aulas por semana',
                '${planoExibido.aulasSemanais} aula(s)',
              ),
              _buildDetalheItem(
                Icons.calendar_month_outlined,
                'Ciclo do plano',
                '${planoExibido.duracaoDias} dias',
              ),
              _buildDetalheItem(
                Icons.credit_card_outlined,
                'Valor mensal',
                NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                    .format(planoExibido.preco),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryLight.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  pendenteMesmoPlano
                      ? 'Sua solicitação para este plano já foi enviada e está aguardando análise do admin.'
                      : possuiSolicitacaoPendente
                          ? 'Existe outra solicitação em análise. Aguarde a resposta do admin para pedir uma nova migração.'
                          : 'Ao migrar, a chave Pix será copiada e o pedido seguirá para aprovação do admin antes da troca do plano.',
                  style: const TextStyle(
                    height: 1.4,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: possuiSolicitacaoPendente ||
                          _planoSolicitandoId == planoExibido.id
                      ? null
                      : () => _solicitarMigracao(
                            assinaturaAtual: assinaturaAtual,
                            planoAtual: planoAtual,
                            planoDestino: planoExibido,
                            nomeAluna: nomeAluna,
                          ),
                  icon: _planoSolicitandoId == planoExibido.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.swap_horiz_rounded),
                  label: Text(
                    pendenteMesmoPlano
                        ? 'Solicitação enviada'
                        : possuiSolicitacaoPendente
                            ? 'Aguardando análise do admin'
                            : 'Migrar para este plano',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetalheItem(IconData icone, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAcoes(Assinatura assinatura, Plano plano, String nomeAluna) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Documentos',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _baixarContrato(assinatura, plano, nomeAluna),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Baixar Contrato (PDF)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.primary),
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _mostrarTermoAceite,
          icon: const Icon(Icons.description_outlined),
          label: const Text('Termo de Aceite'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.secondary),
            foregroundColor: AppColors.secondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }
}

class _TermoAceiteContent extends StatelessWidget {
  const _TermoAceiteContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Text(
          'Termo de Aceite das Condições',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Fênix Pole Dance',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const Divider(height: 32),
        _buildSecao(
          context,
          '1. Riscos da Atividade',
          'Ao praticar pole dance, a aluna declara estar ciente de que a '
              'modalidade envolve exercícios físicos de intensidade variada '
              'realizados com o uso de um vertical. A prática requer coordenação '
              'motora, força e flexibilidade. A aluna que apresentar qualquer '
              'limitação física ou condição médica deve consultar um profissional '
              'de saúde antes de iniciar as aulas.',
        ),
        _buildSecao(
          context,
          '2. Responsabilidade Pessoal',
          'A aluna se responsabiliza por praticar dentro dos seus limites, não '
              'forçar movimentos além da sua capacidade e comunicar à instrutora '
              'qualquer desconforto ou lesão. O estúdio não se responsabiliza por '
              'acidentes decorrentes de negligência ou desobediência às orientações '
              'das instrutoras.',
        ),
        _buildSecao(
          context,
          '3. Uso das Instalações',
          'É obrigatório o uso de roupas adequadas para a prática do pole dance '
              '(shorts e top). O uso de cremes, loções ou hidratantes nas mãos '
              'e pernas no dia da aula é proibido, pois compromete a aderência '
              'ao vertical. Os cabelos devem estar presos durante toda a prática.',
        ),
        _buildSecao(
          context,
          '4. Cancelamentos e Faltas',
          'Cancelamentos devem ser comunicados com pelo menos 2 horas de '
              'antecedência pelo aplicativo ou contato direto com o estúdio. '
              'Faltas sem aviso não geram direito a reposição. A aluna tem '
              'direito a reposição de aulas canceladas dentro do prazo conforme '
              'a disponibilidade.',
        ),
        _buildSecao(
          context,
          '5. Uso de Imagem',
          'O estúdio Fênix Pole Dance pode registrar fotos e vídeos das aulas '
              'para fins de divulgação nas redes sociais. Caso a aluna não '
              'autorize o uso de sua imagem, deve comunicar formalmente ao '
              'estúdio por escrito.',
        ),
        _buildSecao(
          context,
          '6. Pagamentos e Renovação',
          'O valor do plano deve ser pago mensalmente até o dia 10. O atraso '
              'no pagamento resultará na suspensão do acesso às aulas até a '
              'regularização. O plano é renovado automaticamente ao fim do ciclo do plano.',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ao contratar o plano, a aluna declara ter lido e '
                  'aceito todos os termos acima.',
                  style:
                      const TextStyle(fontSize: 13, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSecao(BuildContext context, String titulo, String conteudo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(conteudo, style: const TextStyle(height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }
}
