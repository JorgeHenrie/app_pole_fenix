import 'package:cloud_functions/cloud_functions.dart';

import '../../models/grade_horario.dart';

class AppFunctionsService {
  static const String _region = 'southamerica-east1';

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _region);

  Future<Map<String, int>> obterOcupacaoHorarios(
    List<String> gradeHorarioIds,
  ) async {
    try {
      final resultado = await _functions
          .httpsCallable('obterOcupacaoHorarios')
          .call({'gradeHorarioIds': gradeHorarioIds});

      final dados = resultado.data;
      if (dados is! Map) return {};

      final bruto = dados['ocupacaoPorGradeHorarioId'];
      if (bruto is! Map) return {};

      return bruto.map(
        (key, value) => MapEntry(
          key.toString(),
          value is num ? value.toInt() : 0,
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      throw StateError(_mensagemErro(
          e, 'Nao foi possivel consultar a ocupacao dos horarios.'));
    } catch (_) {
      throw StateError('Nao foi possivel consultar a ocupacao dos horarios.');
    }
  }

  Future<void> contratarPlano({
    required String planoId,
    required List<GradeHorario> horariosEscolhidos,
  }) async {
    final gradeHorarioIds = horariosEscolhidos
        .map((item) => item.id)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();

    if (gradeHorarioIds.isEmpty) {
      throw StateError('Selecione ao menos um horario para contratar o plano.');
    }

    try {
      await _functions.httpsCallable('contratarPlano').call({
        'planoId': planoId,
        'gradeHorarioIds': gradeHorarioIds,
      });
    } on FirebaseFunctionsException catch (e) {
      throw StateError(
          _mensagemErro(e, 'Nao foi possivel concluir a contratacao.'));
    } catch (_) {
      throw StateError('Nao foi possivel concluir a contratacao.');
    }
  }

  Future<int> sincronizarMinhasAulasPassadas() async {
    try {
      final resultado = await _functions
          .httpsCallable('sincronizarMinhasAulasPassadas')
          .call();
      final dados = resultado.data;
      if (dados is! Map) return 0;
      final baixas = dados['baixas'];
      return baixas is num ? baixas.toInt() : 0;
    } on FirebaseFunctionsException catch (e) {
      throw StateError(
          _mensagemErro(e, 'Nao foi possivel sincronizar as aulas passadas.'));
    } catch (_) {
      throw StateError('Nao foi possivel sincronizar as aulas passadas.');
    }
  }

  String _mensagemErro(FirebaseFunctionsException erro, String fallback) {
    final mensagem = erro.message?.trim();
    if (mensagem != null && mensagem.isNotEmpty) {
      return mensagem;
    }
    return fallback;
  }
}
