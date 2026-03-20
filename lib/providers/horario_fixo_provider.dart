import 'package:flutter/foundation.dart';
import '../models/horario_fixo.dart';
import '../repositories/horario_fixo_repository.dart';
import '../services/geracao_aulas_service.dart';

class HorarioFixoProvider extends ChangeNotifier {
  final HorarioFixoRepository _repository = HorarioFixoRepository();
  final GeracaoAulasService _geracaoService = GeracaoAulasService();

  List<HorarioFixo> _horariosFixos = [];
  bool _carregando = false;
  String? _erro;

  List<HorarioFixo> get horariosFixos => List.unmodifiable(_horariosFixos);
  bool get carregando => _carregando;
  String? get erro => _erro;

  Future<void> carregarHorariosDeAluna(String alunaId) async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      _horariosFixos = await _repository.buscarPorAluna(alunaId);
    } catch (e) {
      _erro = 'Erro ao carregar horários.';
      debugPrint('HorarioFixoProvider.carregarHorariosDeAluna: $e');
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<bool> criarHorarioFixo(HorarioFixo horario) async {
    try {
      final id = await _repository.criar(horario);
      final horarioComId = horario.copyWith(id: id);
      await _geracaoService.gerarAulasParaHorarioFixo(horarioComId);
      _horariosFixos = [..._horariosFixos, horarioComId];
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HorarioFixoProvider.criarHorarioFixo: $e');
      return false;
    }
  }

  Future<bool> desativarHorario(String id, String motivo) async {
    try {
      await _repository.desativar(id, motivo);
      _horariosFixos = _horariosFixos.map((h) {
        if (h.id == id) return h.copyWith(ativo: false);
        return h;
      }).toList();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('HorarioFixoProvider.desativarHorario: $e');
      return false;
    }
  }

  void limpar() {
    _horariosFixos = [];
    _erro = null;
    notifyListeners();
  }
}
