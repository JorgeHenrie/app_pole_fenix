import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../models/usuario.dart';

// ─── Dados da planilha ──────────────────────────────────────────────────────

class _DadoImport {
  final String nome;
  final int? mensalidade; // 160 ou 250
  final int? vencimentoDia; // dia do mês
  final NivelAluna nivel;

  const _DadoImport({
    required this.nome,
    this.mensalidade,
    this.vencimentoDia,
    required this.nivel,
  });

  int get aulasPorMes => mensalidade == 250 ? 8 : 4;

  /// E-mail placeholder gerado: nome normalizado + @fenixpole.local
  String get emailPlaceholder {
    final normalizado = nome
        .toLowerCase()
        .replaceAll(RegExp(r'[àáâãä]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$normalizado@fenixpole.local';
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'nivel': nivel.valor,
        'mensalidade': mensalidade,
        'vencimentoDia': vencimentoDia,
        'aulasPorMes': aulasPorMes,
      };
}

const _dadosPlanilha = [
  _DadoImport(nome: 'Seldra',      mensalidade: 250, vencimentoDia: 2,  nivel: NivelAluna.interI),
  _DadoImport(nome: 'Senny',       mensalidade: 250, vencimentoDia: 12, nivel: NivelAluna.interI),
  _DadoImport(nome: 'Barbara',     mensalidade: 250, vencimentoDia: 12, nivel: NivelAluna.basico),
  _DadoImport(nome: 'Thaynara',    mensalidade: 250, vencimentoDia: 5,  nivel: NivelAluna.interII),
  _DadoImport(nome: 'Maria',       mensalidade: 160, vencimentoDia: 11, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Kelly',       mensalidade: 160, vencimentoDia: 12, nivel: NivelAluna.basico),
  _DadoImport(nome: 'Leila',       mensalidade: 160, vencimentoDia: 16, nivel: NivelAluna.basico),
  _DadoImport(nome: 'Gislene',     mensalidade: 160, vencimentoDia: 14, nivel: NivelAluna.basico),
  _DadoImport(nome: 'Bruna',       mensalidade: null, vencimentoDia: null, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Vivian',      mensalidade: null, vencimentoDia: null, nivel: NivelAluna.interI),
  _DadoImport(nome: 'Samilly',     mensalidade: 160, vencimentoDia: 16, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Zo',          mensalidade: 160, vencimentoDia: 17, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Ana Claudia', mensalidade: 160, vencimentoDia: 19, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Larissa',     mensalidade: 160, vencimentoDia: 18, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Geovana',     mensalidade: 160, vencimentoDia: 27, nivel: NivelAluna.iniciante),
  _DadoImport(nome: 'Kevilly',     mensalidade: 250, vencimentoDia: 27, nivel: NivelAluna.iniciante),
];

// ─── Tela ────────────────────────────────────────────────────────────────────

class ImportarAlunasScreen extends StatefulWidget {
  const ImportarAlunasScreen({super.key});

  @override
  State<ImportarAlunasScreen> createState() => _ImportarAlunasScreenState();
}

enum _StatusItem { aguardando, importando, ok, erro }

class _ImportarAlunasScreenState extends State<ImportarAlunasScreen> {
  bool _importando = false;
  bool _concluido = false;
  final Map<int, _StatusItem> _status = {
    for (int i = 0; i < _dadosPlanilha.length; i++) i: _StatusItem.aguardando,
  };
  final Map<int, String> _erros = {};

  Future<void> _confirmarEImportar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar importação'),
        content: const Text(
          'Serão criadas contas no Firebase Auth com e-mail temporário '
          '(nome@fenixpole.local) e senha padrão Fenix@2026.\n\n'
          'As alunas alterarão o e-mail e a senha no primeiro acesso.\n\n'
          'Execute APENAS UMA VEZ para evitar duplicatas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    setState(() {
      _importando = true;
      _concluido = false;
      _erros.clear();
      for (int i = 0; i < _dadosPlanilha.length; i++) {
        _status[i] = _StatusItem.importando;
      }
    });

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('criarContasImportadas');

      final resultado = await callable.call({
        'alunas': _dadosPlanilha.map((d) => d.toMap()).toList(),
      });

      final resultados =
          (resultado.data['resultados'] as List).cast<Map<String, dynamic>>();

      for (int i = 0; i < _dadosPlanilha.length; i++) {
        final r = resultados[i];
        setState(() {
          if (r['ok'] == true) {
            _status[i] = _StatusItem.ok;
          } else {
            _status[i] = _StatusItem.erro;
            _erros[i] = r['erro'] as String? ?? 'Erro desconhecido';
          }
        });
      }
    } catch (e) {
      setState(() {
        for (int i = 0; i < _dadosPlanilha.length; i++) {
          if (_status[i] == _StatusItem.importando) {
            _status[i] = _StatusItem.erro;
            _erros[i] = e.toString();
          }
        }
      });
    } finally {
      setState(() {
        _importando = false;
        _concluido = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOk = _status.values.where((s) => s == _StatusItem.ok).length;
    final totalErro = _status.values.where((s) => s == _StatusItem.erro).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Importar Alunas da Planilha')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Execute APENAS UMA VEZ.\n'
                    'E-mail temporário: nome@fenixpole.local  |  Senha: Fenix@2026\n'
                    'A aluna atualiza seus dados no primeiro acesso.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (_concluido)
            Container(
              width: double.infinity,
              color: totalErro == 0 ? Colors.green.shade50 : Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                totalErro == 0
                    ? '✅ $totalOk contas criadas com sucesso!'
                    : '⚠ $totalOk criadas, $totalErro com erro.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _dadosPlanilha.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final dado = _dadosPlanilha[i];
                final st = _status[i]!;
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: _StatusIcon(st),
                    title: Text(dado.nome,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dado.mensalidade != null
                              ? 'R\$ ${dado.mensalidade},00 · '
                                  '${dado.aulasPorMes}x/mês · '
                                  'vence dia ${dado.vencimentoDia}'
                              : 'Sem plano',
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          dado.emailPlaceholder,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        if (st == _StatusItem.erro && _erros.containsKey(i))
                          Text(
                            _erros[i]!,
                            style: const TextStyle(fontSize: 11, color: Colors.red),
                          ),
                      ],
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: dado.nivel.cor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: dado.nivel.cor, width: 0.8),
                      ),
                      child: Text(
                        dado.nivel.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: dado.nivel.cor,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_importando || _concluido) ? null : _confirmarEImportar,
                  icon: _importando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.upload),
                  label: Text(_importando
                      ? 'Criando contas...'
                      : _concluido
                          ? 'Importação concluída'
                          : 'Criar ${_dadosPlanilha.length} contas'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final _StatusItem status;
  const _StatusIcon(this.status);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _StatusItem.aguardando:
        return const Icon(Icons.radio_button_unchecked, color: Colors.grey);
      case _StatusItem.importando:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case _StatusItem.ok:
        return const Icon(Icons.check_circle, color: Colors.green);
      case _StatusItem.erro:
        return const Icon(Icons.error, color: Colors.red);
    }
  }
}
