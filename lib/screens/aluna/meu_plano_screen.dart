import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/assinatura.dart';
import '../../models/plano.dart';
import '../../providers/auth_provider.dart';
import '../../providers/home_aluna_provider.dart';
import '../../widgets/common/loading_indicator.dart';

/// Tela com detalhes do plano da aluna, contrato PDF e termo de aceite.
class MeuPlanoScreen extends StatefulWidget {
  const MeuPlanoScreen({super.key});

  @override
  State<MeuPlanoScreen> createState() => _MeuPlanoScreenState();
}

class _MeuPlanoScreenState extends State<MeuPlanoScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<HomeAlunaProvider>();
      if (provider.assinatura == null && !provider.carregando) {
        final usuario = context.read<AuthProvider>().usuario;
        if (usuario != null) provider.carregarDados(usuario.id);
      }
    });
  }

  Future<void> _baixarContrato(
      Assinatura assinatura, Plano plano, String nomeAluna) async {
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
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text('Fênix Pole Dance',
                style: pw.TextStyle(fontSize: 13)),
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
          pw.Text(
              'Valor Mensal: ${currencyFormat.format(plano.preco)}'),
          pw.Text('Aulas por mês: ${plano.aulasPorMes} aulas'),
          pw.Text('Aulas por semana: ${plano.aulasSemanais} aula(s)'),
          pw.SizedBox(height: 16),
          pw.Text('VIGÊNCIA',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Início: ${DateFormatter.data(assinatura.dataInicio)}'),
          pw.Text(
              'Renovação: ${DateFormatter.data(assinatura.dataRenovacao)}'),
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
            '6. O contrato se renova automaticamente a cada 30 dias.\n'
            '7. Para cancelamento do contrato, deve-se notificar o estúdio '
            'com 15 dias de antecedência.',
            style: const pw.TextStyle(lineSpacing: 4),
          ),
          pw.SizedBox(height: 32),
          pw.Text(
            'Gerado em: ${DateFormatter.data(DateTime.now())}',
            style: pw.TextStyle(
                fontSize: 10, color: PdfColors.grey),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
        onLayout: (_) async => doc.save());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Meu Plano')),
      body: Consumer2<HomeAlunaProvider, AuthProvider>(
        builder: (context, homeProvider, authProvider, _) {
          if (homeProvider.carregando) return const LoadingIndicator();

          final assinatura = homeProvider.assinatura;
          final plano = homeProvider.plano;

          if (assinatura == null || plano == null) {
            return _buildSemPlano();
          }

          final nomeAluna =
              authProvider.usuario?.nome ?? 'Aluna';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(assinatura, plano),
                const SizedBox(height: 16),
                _buildDetalhesCard(assinatura, plano),
                const SizedBox(height: 24),
                _buildAcoes(assinatura, plano, nomeAluna),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSemPlano() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.credit_card_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Nenhum plano ativo',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(Assinatura assinatura, Plano plano) {
    final ativa = assinatura.estaAtiva;
    final currencyFormat =
        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ativa
              ? [AppColors.primary, AppColors.primaryLight]
              : [Colors.grey.shade600, Colors.grey.shade400],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium,
                  color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plano.nome,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  ativa
                      ? 'ATIVO'
                      : assinatura.status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
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
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            plano.descricao,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalhesCard(Assinatura assinatura, Plano plano) {
    return Card(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Detalhes do Plano',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(height: 24),
            _buildDetalheItem(Icons.fitness_center, 'Aulas por mês',
                '${plano.aulasPorMes} aulas'),
            _buildDetalheItem(Icons.today, 'Aulas por semana',
                '${plano.aulasSemanais} aula(s)'),
            _buildDetalheItem(Icons.stars_outlined, 'Créditos disponíveis',
                '${assinatura.creditosDisponiveis}'),
            _buildDetalheItem(Icons.check_circle_outline,
                'Aulas realizadas', '${assinatura.aulasRealizadas}'),
            _buildDetalheItem(Icons.event, 'Início',
                DateFormatter.data(assinatura.dataInicio)),
            _buildDetalheItem(Icons.autorenew, 'Próxima renovação',
                DateFormatter.data(assinatura.dataRenovacao)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalheItem(
      IconData icone, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary)),
          ),
          Text(valor,
              style:
                  const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildAcoes(
      Assinatura assinatura, Plano plano, String nomeAluna) {
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
          onPressed: () =>
              _baixarContrato(assinatura, plano, nomeAluna),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Baixar Contrato (PDF)'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.primary),
            foregroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
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
                borderRadius: BorderRadius.circular(10)),
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
              'regularização. O plano é renovado automaticamente a cada 30 dias.',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2)),
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
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSecao(
      BuildContext context, String titulo, String conteudo) {
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
          Text(conteudo,
              style: const TextStyle(height: 1.6, fontSize: 14)),
        ],
      ),
    );
  }
}
