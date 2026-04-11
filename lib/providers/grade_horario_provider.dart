import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/aula.dart';
import '../models/assinatura.dart';
import '../models/grade_horario.dart';
import '../models/horario_fixo.dart';
import '../models/reposicao.dart';
import '../repositories/aula_repository.dart';
import '../repositories/grade_horario_repository.dart';
import '../repositories/horario_fixo_repository.dart';
import '../repositories/reposicao_repository.dart';

/// Representa uma ocorrência específica de um slot da grade do estúdio.
class SlotDia {
  final GradeHorario gradeHorario;
  final DateTime dataHora;
  final List<String> nomesMatriculados;

  const SlotDia({
    required this.gradeHorario,
    required this.dataHora,
    required this.nomesMatriculados,
  });

  int get ocupados => nomesMatriculados.length;
  int get vagasDisponiveis => gradeHorario.capacidadeMaxima - ocupados;
  bool get temVaga => vagasDisponiveis > 0;
}

class ResultadoCancelamentoAula {
  final String? erro;
  final bool criouReposicao;

  const ResultadoCancelamentoAula({
    this.erro,
    this.criouReposicao = false,
  });

  bool get sucesso => erro == null;
}

/// Provider responsável pela grade de horários do estúdio e agendamento de reposições.
class GradeHorarioProvider extends ChangeNotifier {
  final AulaRepository _aulaRepo = AulaRepository();
  final GradeHorarioRepository _gradeRepo = GradeHorarioRepository();
  final ReposicaoRepository _reposicaoRepo = ReposicaoRepository();
  final HorarioFixoRepository _horarioFixoRepo = HorarioFixoRepository();

  List<SlotDia> _slots = [];
  List<Reposicao> _reposicoesPendentes = [];
  Set<String> _slotsComAulaFixaDaAluna = {};
  String? _primeiroNomeAluna;

  /// Horários fixos da aluna carregados para verificar inscrição nos slots.
  List<HorarioFixo> _horariosDaAluna = [];
  bool _carregando = false;
  String? _erro;

  List<SlotDia> get slots => List.unmodifiable(_slots);
  List<Reposicao> get reposicoesPendentes =>
      List.unmodifiable(_reposicoesPendentes);
  bool get carregando => _carregando;
  String? get erro => _erro;
  bool get temReposicaoPendente => _reposicoesPendentes.isNotEmpty;

  /// Carrega a grade do estúdio e as reposições pendentes da aluna.
  ///
  /// [assinatura] define o limite da data de busca (dataRenovacao).
  /// Se não informado, usa os próximos 14 dias.
  Future<void> carregar(
    String alunaId, {
    Assinatura? assinatura,
    String? nomeAluna,
  }) async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      final resultados = await Future.wait([
        _gradeRepo.listarAtivos(),
        _reposicaoRepo.buscarPendentesPorAluna(alunaId),
        _horarioFixoRepo.buscarPorAluna(alunaId),
      ]);

      final grade = resultados[0] as List<GradeHorario>;
      _reposicoesPendentes = resultados[1] as List<Reposicao>;
      _horariosDaAluna = resultados[2] as List<HorarioFixo>;

      final nomeInformado = nomeAluna?.trim() ?? '';
      if (nomeInformado.isNotEmpty) {
        _primeiroNomeAluna = nomeInformado.split(' ').first;
      } else {
        final alunaDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(alunaId)
            .get();
        final nomeBuscado = alunaDoc.data()?['nome'] as String? ?? '';
        _primeiroNomeAluna = nomeBuscado.trim().split(' ').first;
      }

      final agora = DateTime.now();
      // Limita ao período do contrato vigente ou próximos 14 dias
      final contrato = assinatura?.dataRenovacao;
      final limite = (contrato != null && contrato.isAfter(agora))
          ? contrato
          : agora.add(const Duration(days: 14));

      // Início da semana atual (segunda-feira) — garante que dias já passados
      // desta semana (ex.: terça quando hoje é quarta) também sejam gerados.
      final inicioSemana =
          DateTime(agora.year, agora.month, agora.day - (agora.weekday - 1));

      _slotsComAulaFixaDaAluna = await _buscarSlotsComAulaFixaDaAluna(
        alunaId: alunaId,
        inicio: inicioSemana,
        limite: limite,
      );

      grade.sort((a, b) {
        final d = a.diaSemana.compareTo(b.diaSemana);
        return d != 0 ? d : a.horario.compareTo(b.horario);
      });

      final nomesFixosPorSlot =
          await _gradeRepo.buscarNomesFixosPorSlots(grade);
      final nomesReposicoesPorSlot =
          await _gradeRepo.buscarNomesReposicoesPorPeriodo(
        gradeHorarioIds: grade.map((g) => g.id),
        inicio: inicioSemana,
        limite: limite,
      );

      final slots = <SlotDia>[];

      for (final g in grade) {
        final chave = '${g.diaSemana}_${g.horario}';
        final nomesFixos = nomesFixosPorSlot[chave] ?? [];
        // Começa do início da semana para incluir dias já passados desta semana
        DateTime cursor = _proximaOcorrencia(g.diaSemana, inicioSemana);

        while (cursor.isBefore(limite) || _mesmoDia(cursor, limite)) {
          final partes = _extrairHorarioInicio(g.horario);
          final dataHora = DateTime(
            cursor.year,
            cursor.month,
            cursor.day,
            partes.$1,
            partes.$2,
          );

          // Inclui todos os slots da semana atual (mesmo passados) e futuros
          if (!dataHora.isBefore(inicioSemana)) {
            final nomesRepo =
                nomesReposicoesPorSlot[_chaveReposicaoSlot(g.id, dataHora)] ??
                    const <String>[];
            final todos = [...nomesFixos, ...nomesRepo];
            final slotKey = _chaveSlot(g.diaSemana, g.horario, dataHora);

            if (_deveOcultarAlunaNoSlot(g, dataHora, agora, slotKey)) {
              final primeiroNome = _primeiroNomeAluna?.toLowerCase();
              if (primeiroNome != null && primeiroNome.isNotEmpty) {
                todos.removeWhere(
                  (nome) => nome.trim().toLowerCase() == primeiroNome,
                );
              }
            }

            slots.add(SlotDia(
              gradeHorario: g,
              dataHora: dataHora,
              nomesMatriculados: todos.take(g.capacidadeMaxima).toList(),
            ));
          }

          cursor = cursor.add(const Duration(days: 7));
        }
      }

      slots.sort((a, b) => a.dataHora.compareTo(b.dataHora));
      _slots = slots;
    } catch (e) {
      _erro = 'Erro ao carregar grade de horários.';
      debugPrint('GradeHorarioProvider.carregar: $e');
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<Set<String>> _buscarSlotsComAulaFixaDaAluna({
    required String alunaId,
    required DateTime inicio,
    required DateTime limite,
  }) async {
    final aulas = await _aulaRepo.buscarPorAlunaNoPeriodo(
      alunaId,
      inicio: inicio,
      limite: limite,
    );

    final horariosPorId = {
      for (final horario in _horariosDaAluna) horario.id: horario,
    };

    final slotsAtivos = <String>{};
    final slotsCancelados = <String>{};

    for (final aula in aulas) {
      if (aula.horarioFixoId == null) continue;

      final horario = horariosPorId[aula.horarioFixoId!];
      if (horario == null) continue;
      if (aula.dataHora.isBefore(inicio)) continue;
      if (aula.dataHora.isAfter(limite)) continue;

      final slotKey =
          _chaveSlot(horario.diaSemana, horario.horario, aula.dataHora);
      if (aula.status == 'cancelada') {
        slotsCancelados.add(slotKey);
        slotsAtivos.remove(slotKey);
        continue;
      }

      if (!slotsCancelados.contains(slotKey)) {
        slotsAtivos.add(slotKey);
      }
    }

    return slotsAtivos;
  }

  bool _deveOcultarAlunaNoSlot(
    GradeHorario grade,
    DateTime dataHora,
    DateTime agora,
    String slotKey,
  ) {
    final ehHorarioDaAluna = _horariosDaAluna.any(
      (h) => h.diaSemana == grade.diaSemana && h.horario == grade.horario,
    );

    if (!ehHorarioDaAluna) return false;
    return !_slotsComAulaFixaDaAluna.contains(slotKey);
  }

  /// Retorna true se a aluna pode agendar uma reposição neste slot.
  bool podeAgendar(SlotDia slot) {
    if (_reposicoesPendentes.isEmpty) return false;
    if (!slot.temVaga) return false;
    if (!_podeEntrarNoSlot(slot.dataHora)) return false;
    return _reposicoesPendentes.any((r) =>
        !r.expirou &&
        (r.expiraEm == null || slot.dataHora.isBefore(r.expiraEm!)));
  }

  /// Retorna a primeira reposição pendente válida para este slot.
  Reposicao? reposicaoParaSlot(SlotDia slot) {
    return _reposicoesPendentes
        .where((r) =>
            !r.expirou &&
            (r.expiraEm == null || slot.dataHora.isBefore(r.expiraEm!)))
        .firstOrNull;
  }

  /// Agenda uma reposição no slot indicado.
  Future<bool> agendarReposicao({
    required Reposicao reposicao,
    required SlotDia slot,
    required String nomeAluna,
  }) async {
    try {
      await _reposicaoRepo.agendar(
        reposicao.id,
        slot.dataHora,
        slot.gradeHorario.id,
      );
      _reposicoesPendentes.removeWhere((r) => r.id == reposicao.id);
      final idx = _slots.indexWhere((s) =>
          s.gradeHorario.id == slot.gradeHorario.id &&
          s.dataHora == slot.dataHora);
      if (idx >= 0) {
        final s = _slots[idx];
        _slots[idx] = SlotDia(
          gradeHorario: s.gradeHorario,
          dataHora: s.dataHora,
          nomesMatriculados: [
            ...s.nomesMatriculados,
            nomeAluna.trim().split(' ').first,
          ],
        );
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('GradeHorarioProvider.agendarReposicao: $e');
      return false;
    }
  }

  /// Encontra a próxima ocorrência de um dia da semana a partir de [from].
  static DateTime _proximaOcorrencia(int diaSemana, DateTime from) {
    // GradeHorario.diaSemana: 1=Segunda...7=Domingo (igual a DateTime.weekday)
    var data = DateTime(from.year, from.month, from.day);
    while (data.weekday != diaSemana) {
      data = data.add(const Duration(days: 1));
    }
    return data;
  }

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Retorna true se a aluna tem um horário fixo que corresponde a este slot.
  bool alunaEstaInscrita(SlotDia slot) {
    final horario = horarioFixoParaSlot(slot);
    return horario != null;
  }

  /// Retorna o HorarioFixo da aluna para este slot, se existir.
  HorarioFixo? horarioFixoParaSlot(SlotDia slot) {
    final horario = _horariosDaAluna
        .where((h) =>
            h.diaSemana == slot.gradeHorario.diaSemana &&
            h.horario == slot.gradeHorario.horario)
        .firstOrNull;

    if (horario == null) return null;

    final slotKey = _chaveSlot(
      slot.gradeHorario.diaSemana,
      slot.gradeHorario.horario,
      slot.dataHora,
    );

    return _slotsComAulaFixaDaAluna.contains(slotKey) ? horario : null;
  }

  /// Cancela uma ocorrência específica da aula da aluna e cria uma Reposição
  /// pendente. O cancelamento só é permitido para hoje ou datas futuras.
  /// Retorna null em caso de sucesso, ou uma mensagem de erro.
  Future<ResultadoCancelamentoAula> cancelarAulaECriarReposicao({
    required SlotDia slot,
    required String alunaId,
    required String motivo,
  }) async {
    final agora = DateTime.now();
    // Impede cancelamento de aulas cujo horário já passou completamente
    if (slot.dataHora.isBefore(agora)) {
      return const ResultadoCancelamentoAula(
        erro: 'Não é possível cancelar aulas passadas.',
      );
    }

    final horarioFixo = horarioFixoParaSlot(slot);
    if (horarioFixo == null) {
      return const ResultadoCancelamentoAula(
        erro: 'Horário fixo não encontrado.',
      );
    }

    final dentroDoPrazo = slot.dataHora.difference(agora).inHours >= 2;

    try {
      final aulaExistente = await _aulaRepo.buscarPorHorarioFixoEDataHora(
        horarioFixo.id,
        slot.dataHora,
      );

      if (aulaExistente?.status == 'cancelada') {
        return const ResultadoCancelamentoAula(
          erro: 'Esta aula já foi cancelada.',
        );
      }

      final batch = FirebaseFirestore.instance.batch();

      final aulaRef = FirebaseFirestore.instance.collection('aulas').doc(
          aulaExistente?.id ??
              FirebaseFirestore.instance.collection('aulas').doc().id);

      final dadosCancelamento = {
        'status': 'cancelada',
        'motivoCancelamento': motivo,
        'origemCancelamento': 'aluna',
        'dataCancelamento': agora.toIso8601String(),
        'dentroDosPrazo': dentroDoPrazo,
      };

      if (aulaExistente != null) {
        batch.update(aulaRef, dadosCancelamento);
      } else {
        batch.set(aulaRef, {
          'alunaId': alunaId,
          'horarioFixoId': horarioFixo.id,
          'dataHora': slot.dataHora.toIso8601String(),
          'modalidade': slot.gradeHorario.modalidade,
          ...dadosCancelamento,
          'criadaEm': agora.toIso8601String(),
        });
      }

      DateTime? expira;
      DocumentReference<Map<String, dynamic>>? reposicaoRef;
      if (dentroDoPrazo) {
        expira = DateTime(agora.year, agora.month + 1, agora.day);
        reposicaoRef =
            FirebaseFirestore.instance.collection('reposicoes').doc();
        batch.set(reposicaoRef, {
          'aulaOriginalId': aulaRef.id,
          'alunaId': alunaId,
          'novaDataHora': null,
          'novoHorarioId': null,
          'status': 'pendente',
          'motivoOriginal': motivo,
          'atestadoValidado': null,
          'criadaEm': Timestamp.fromDate(agora),
          'expiraEm': Timestamp.fromDate(expira),
          'agendadaEm': null,
          'realizadaEm': null,
        });
      }

      await batch.commit();

      // Atualiza estado local: remove o nome da aluna do slot
      final idx = _slots.indexWhere((s) =>
          s.gradeHorario.id == slot.gradeHorario.id &&
          s.dataHora == slot.dataHora);
      if (idx >= 0) {
        final s = _slots[idx];
        final primeiroNome = _primeiroNomeAluna?.toLowerCase();
        if (primeiroNome != null && primeiroNome.isNotEmpty) {
          _slots[idx] = SlotDia(
            gradeHorario: s.gradeHorario,
            dataHora: s.dataHora,
            nomesMatriculados: s.nomesMatriculados
                .where((n) => n.toLowerCase() != primeiroNome)
                .toList(),
          );
        }
      }
      final slotKey = _chaveSlot(
        slot.gradeHorario.diaSemana,
        slot.gradeHorario.horario,
        slot.dataHora,
      );
      _slotsComAulaFixaDaAluna.remove(slotKey);

      if (dentroDoPrazo && reposicaoRef != null && expira != null) {
        _reposicoesPendentes = [
          ..._reposicoesPendentes,
          Reposicao(
            id: reposicaoRef.id,
            aulaOriginalId: aulaRef.id,
            alunaId: alunaId,
            status: 'pendente',
            motivoOriginal: motivo,
            criadaEm: agora,
            expiraEm: expira,
          ),
        ];
      }

      notifyListeners();
      return ResultadoCancelamentoAula(criouReposicao: dentroDoPrazo);
    } catch (e) {
      debugPrint('GradeHorarioProvider.cancelarAulaECriarReposicao: $e');
      return const ResultadoCancelamentoAula(
        erro: 'Erro ao cancelar. Tente novamente.',
      );
    }
  }

  void limpar() {
    _slots = [];
    _reposicoesPendentes = [];
    _horariosDaAluna = [];
    _slotsComAulaFixaDaAluna = {};
    _primeiroNomeAluna = null;
    _erro = null;
    notifyListeners();
  }

  static (int, int) _extrairHorarioInicio(String horario) {
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(horario);
    if (match == null) return (0, 0);
    return (
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
    );
  }

  static bool _podeEntrarNoSlot(DateTime dataHoraInicio) {
    // Permite agendar reposição até o horário de início da aula.
    return DateTime.now().isBefore(dataHoraInicio);
  }

  static String _chaveSlot(int diaSemana, String horario, DateTime dataHora) {
    return '$diaSemana|$horario|${dataHora.toIso8601String()}';
  }

  static String _chaveReposicaoSlot(String gradeHorarioId, DateTime dataHora) {
    return '$gradeHorarioId|${dataHora.toIso8601String()}';
  }
}
