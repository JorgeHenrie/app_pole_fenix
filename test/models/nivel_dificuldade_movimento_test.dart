import 'package:app_pole_fenix/models/movimento_pole.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mantem compatibilidade com nivel legado basico', () {
    final nivel = NivelDificuldadeMovimento.fromValor('basico');

    expect(nivel.id, 'basico');
    expect(nivel.label, 'Básico');
    expect(nivel.descricao, 'Movimentos do básico.');
    expect(nivel.ordem, 1);
  });

  test('le nivel customizado com descricao e ordem próprias', () {
    final nivel = NivelDificuldadeMovimento.fromEmbedded(
      id: 'master',
      label: 'Master',
      descricao: 'Movimentos de alta complexidade e acabamento fino.',
      ordem: 7,
      corHex: '#123456',
      ativo: false,
    );

    expect(nivel.id, 'master');
    expect(nivel.label, 'Master');
    expect(
      nivel.descricao,
      'Movimentos de alta complexidade e acabamento fino.',
    );
    expect(nivel.ordem, 7);
    expect(nivel.corHex, '#123456');
    expect(nivel.ativo, isFalse);
  });
}
