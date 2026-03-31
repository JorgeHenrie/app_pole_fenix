import 'package:flutter_test/flutter_test.dart';
import 'package:app_pole_fenix/core/constants/app_constants.dart';
import 'package:app_pole_fenix/core/constants/routes.dart';
import 'package:app_pole_fenix/core/utils/validators.dart';
import 'package:app_pole_fenix/core/utils/helpers.dart';
import 'package:app_pole_fenix/models/aula.dart';

void main() {
  group('AppConstants', () {
    test('nome do app está correto', () {
      expect(AppConstants.appName, 'Fênix Pole Dance');
    });

    test('capacidade máxima de aula está configurada', () {
      expect(AppConstants.capacidadeMaximaAula, 3);
    });
  });

  group('Routes', () {
    test('rota splash é /', () {
      expect(Routes.splash, '/');
    });

    test('todas as rotas começam com /', () {
      expect(Routes.login.startsWith('/'), isTrue);
      expect(Routes.homeAluna.startsWith('/'), isTrue);
      expect(Routes.homeAdmin.startsWith('/'), isTrue);
    });
  });

  group('Validators', () {
    test('campo obrigatório vazio retorna erro', () {
      expect(Validators.obrigatorio(''), isNotNull);
      expect(Validators.obrigatorio(null), isNotNull);
    });

    test('campo obrigatório preenchido retorna null', () {
      expect(Validators.obrigatorio('valor'), isNull);
    });

    test('e-mail inválido retorna erro', () {
      expect(Validators.email('nao-é-email'), isNotNull);
      expect(Validators.email(''), isNotNull);
    });

    test('e-mail válido retorna null', () {
      expect(Validators.email('teste@exemplo.com'), isNull);
    });

    test('senha curta retorna erro', () {
      expect(Validators.senha('12345'), isNotNull);
    });

    test('senha válida retorna null', () {
      expect(Validators.senha('123456'), isNull);
    });
  });

  group('Helpers', () {
    test('iniciais de nome simples', () {
      expect(Helpers.iniciais('Ana'), 'A');
    });

    test('iniciais de nome completo', () {
      expect(Helpers.iniciais('Ana Silva'), 'AS');
    });

    test('capitalizar string', () {
      expect(Helpers.capitalizar('TESTE'), 'Teste');
    });
  });

  group('Aula', () {
    test('vagas disponíveis calculadas corretamente', () {
      final aula = Aula(
        id: '1',
        alunaId: 'aluna-1',
        titulo: 'Aula de Pole',
        modalidade: 'Pole Dance',
        dataHora: DateTime.now(),
        duracaoMinutos: 60,
        capacidadeMaxima: 3,
        vagasOcupadas: 1,
        status: 'agendada',
        criadaEm: DateTime.now(),
      );
      expect(aula.vagasDisponiveis, 2);
      expect(aula.temVaga, isTrue);
    });

    test('aula sem vagas detectada corretamente', () {
      final aula = Aula(
        id: '2',
        alunaId: 'aluna-1',
        titulo: 'Aula Lotada',
        modalidade: 'Pole Dance',
        dataHora: DateTime.now(),
        duracaoMinutos: 60,
        capacidadeMaxima: 3,
        vagasOcupadas: 3,
        status: 'agendada',
        criadaEm: DateTime.now(),
      );
      expect(aula.vagasDisponiveis, 0);
      expect(aula.temVaga, isFalse);
    });
  });
}
