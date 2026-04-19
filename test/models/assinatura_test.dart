import 'package:app_pole_fenix/models/assinatura.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fimDoCiclo usa o fim do dia da renovacao', () {
    final assinatura = Assinatura(
      id: 'ass-1',
      alunaId: 'alu-1',
      planoId: 'plano-1',
      status: 'ativa',
      creditosDisponiveis: 8,
      dataInicio: DateTime(2026, 4, 1, 9, 30),
      dataRenovacao: DateTime(2026, 4, 30, 9, 30),
    );

    expect(
      assinatura.fimDoCiclo,
      DateTime(2026, 4, 30, 23, 59, 59, 999),
    );
  });
}
