import 'package:flutter/material.dart';

import '../../models/plano.dart';

/// Card de administração de plano.
class PlanoAdminCard extends StatelessWidget {
  final Plano plano;
  final VoidCallback onEditar;
  final VoidCallback onToggleAtivo;
  final VoidCallback onDeletar;

  const PlanoAdminCard({
    super.key,
    required this.plano,
    required this.onEditar,
    required this.onToggleAtivo,
    required this.onDeletar,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header com nome e status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plano.ativo ? Colors.green[50] : Colors.grey[200],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plano.nome,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plano.descricao,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    plano.ativo ? 'ATIVO' : 'INATIVO',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: plano.ativo ? Colors.green : Colors.grey,
                ),
              ],
            ),
          ),

          // Detalhes do plano
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildInfo(
                        Icons.attach_money,
                        'Valor',
                        'R\$ ${plano.preco.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      child: _buildInfo(
                        Icons.calendar_today,
                        'Aulas/Mês',
                        '${plano.aulasPorMes}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfo(
                        Icons.repeat,
                        'Por Semana',
                        '${plano.aulasSemanais}x',
                      ),
                    ),
                    Expanded(
                      child: _buildInfo(
                        Icons.timer,
                        'Duração',
                        '${plano.duracaoDias} dias',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Botões de ação
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onEditar,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton.icon(
                  onPressed: onToggleAtivo,
                  icon: Icon(
                    plano.ativo ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                  ),
                  label: Text(plano.ativo ? 'Desativar' : 'Ativar'),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        plano.ativo ? Colors.orange : Colors.green,
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: TextButton.icon(
                  onPressed: onDeletar,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Excluir'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
