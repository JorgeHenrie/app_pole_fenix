import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/aula.dart';
import '../../models/reposicao.dart';
import '../../repositories/reposicao_repository.dart';
import '../../widgets/common/loading_indicator.dart';

class ValidarAtestadosScreen extends StatefulWidget {
  const ValidarAtestadosScreen({super.key});

  @override
  State<ValidarAtestadosScreen> createState() => _ValidarAtestadosScreenState();
}

class _ValidarAtestadosScreenState extends State<ValidarAtestadosScreen> {
  final ReposicaoRepository _reposicaoRepo = ReposicaoRepository();

  List<Aula> _faltasComAtestado = [];
  bool _carregando = false;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erroCarregamento = null;
    });
    try {
      final snap = await FirebaseFirestore.instance
          .collection('aulas')
          .where('status', isEqualTo: 'falta')
          .where('atestadoPendente', isEqualTo: true)
          .get();
      if (!mounted) return;
      setState(() {
        _faltasComAtestado =
            snap.docs.map((d) => Aula.fromMap(d.data(), d.id)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroCarregamento = 'Nao foi possivel carregar os atestados pendentes.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar atestados: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Future<void> _aprovar(Aula aula) async {
    try {
      await FirebaseFirestore.instance.collection('aulas').doc(aula.id).update({
        'atestadoPendente': false,
        'atestadoValidado': true,
      });
      final reposicao = Reposicao(
        id: '',
        aulaOriginalId: aula.id,
        alunaId: aula.alunaId,
        status: 'pendente',
        motivoOriginal: 'Falta com atestado',
        atestadoValidado: true,
        criadaEm: DateTime.now(),
        expiraEm: DateTime.now().add(const Duration(days: 30)),
      );
      await _reposicaoRepo.criar(reposicao);
      if (mounted) {
        setState(() {
          _faltasComAtestado.removeWhere((item) => item.id == aula.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Atestado aprovado! Reposição criada para a aluna.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao aprovar atestado')),
        );
      }
    }
  }

  Future<void> _rejeitar(Aula aula) async {
    try {
      await FirebaseFirestore.instance.collection('aulas').doc(aula.id).update({
        'atestadoPendente': false,
        'atestadoValidado': false,
      });
      if (mounted) {
        setState(() {
          _faltasComAtestado.removeWhere((item) => item.id == aula.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Atestado rejeitado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao rejeitar atestado: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Validar Atestados'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _carregar,
          ),
        ],
      ),
      body: _carregando
          ? const LoadingIndicator()
          : _erroCarregamento != null && _faltasComAtestado.isEmpty
              ? _buildEstadoErro()
              : _faltasComAtestado.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.medical_services_outlined,
                              size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhum atestado pendente',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _faltasComAtestado.length,
                        itemBuilder: (context, index) {
                          final aula = _faltasComAtestado[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.medical_services,
                                          color: AppColors.warning),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Atestado Pendente',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Aluna: ${aula.alunaId}'),
                                  Text(
                                      'Aula: ${DateFormatter.dataHora(aula.dataHora)}'),
                                  Text('Modalidade: ${aula.modalidade}'),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _rejeitar(aula),
                                          icon: const Icon(Icons.close,
                                              color: AppColors.error),
                                          label: const Text('Rejeitar',
                                              style: TextStyle(
                                                  color: AppColors.error)),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                                color: AppColors.error),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () => _aprovar(aula),
                                          icon: const Icon(Icons.check),
                                          label: const Text('Aprovar'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }

  Widget _buildEstadoErro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _erroCarregamento ?? 'Erro ao carregar atestados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
