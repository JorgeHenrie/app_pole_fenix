import 'package:uuid/uuid.dart';
import '../models/aula.dart';
import '../models/horario_fixo.dart';
import '../repositories/aula_repository.dart';

class GeracaoAulasService {
  final AulaRepository _aulaRepository = AulaRepository();

  /// Gera aulas para um horário fixo nas próximas [semanas] semanas.
  Future<void> gerarAulasParaHorarioFixo(
    HorarioFixo horarioFixo, {
    int semanas = 4,
  }) async {
    final proximas = calcularProximasOcorrencias(
      horarioFixo.diaSemana,
      horarioFixo.horario,
      semanas: semanas,
    );

    for (final dataHora in proximas) {
      final jaExiste = await _aulaRepository.aulaJaExiste(
        horarioFixo.id,
        dataHora,
      );
      if (!jaExiste) {
        final aula = Aula(
          id: const Uuid().v4(),
          alunaId: horarioFixo.alunaId,
          horarioFixoId: horarioFixo.id,
          dataHora: dataHora,
          modalidade: horarioFixo.modalidade,
          status: 'agendada',
          dentroDosPrazo: true,
          criadaEm: DateTime.now(),
        );
        await _aulaRepository.criar(aula);
      }
    }
  }

  /// Calcula as próximas [semanas] ocorrências de um dia da semana a partir de hoje.
  /// [diaSemana] segue a convenção Dart: 1=Segunda ... 7=Domingo.
  /// [horario] no formato "HH:mm".
  List<DateTime> calcularProximasOcorrencias(
    int diaSemana,
    String horario, {
    int semanas = 4,
  }) {
    final partes = horario.split(':');
    final hora = int.parse(partes[0]);
    final minuto = int.parse(partes[1]);

    final agora = DateTime.now();
    var atual = agora;
    while (atual.weekday != diaSemana) {
      atual = atual.add(const Duration(days: 1));
    }
    final primeiraOcorrencia = DateTime(
      atual.year, atual.month, atual.day, hora, minuto,
    );
    DateTime inicio = primeiraOcorrencia;
    if (inicio.isBefore(agora)) {
      inicio = inicio.add(const Duration(days: 7));
    }

    final ocorrencias = <DateTime>[];
    for (int i = 0; i < semanas; i++) {
      ocorrencias.add(inicio.add(Duration(days: 7 * i)));
    }
    return ocorrencias;
  }

  /// Retorna a próxima ocorrência de um dia/horário.
  DateTime calcularProximaOcorrencia(int diaSemana, String horario) {
    return calcularProximasOcorrencias(diaSemana, horario, semanas: 1).first;
  }
}
