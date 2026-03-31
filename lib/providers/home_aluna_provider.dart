import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/assinatura.dart';
import '../models/aula.dart';
import '../models/evento.dart';
import '../models/plano.dart';
import '../repositories/assinatura_repository.dart';
import '../repositories/aula_repository.dart';
import '../repositories/evento_repository.dart';

/// Provider responsável pelos dados da tela inicial da aluna.
class HomeAlunaProvider extends ChangeNotifier {
  final AssinaturaRepository _assinaturaRepository = AssinaturaRepository();
  final AulaRepository _aulaRepository = AulaRepository();
  final EventoRepository _eventoRepository = EventoRepository();

  Assinatura? _assinatura;
  Plano? _plano;
  List<Aula> _proximasAulas = [];
  List<Evento> _proximosEventos = [];
  bool _carregando = false;
  String? _erro;

  Assinatura? get assinatura => _assinatura;
  Plano? get plano => _plano;
  List<Aula> get proximasAulas => List.unmodifiable(_proximasAulas);
  List<Evento> get proximosEventos => List.unmodifiable(_proximosEventos);
  bool get carregando => _carregando;
  String? get erro => _erro;

  /// Carrega todos os dados necessários para a tela inicial.
  Future<void> carregarDados(String alunaId) async {
    _carregando = true;
    _erro = null;
    notifyListeners();
    try {
      // 1. Carregar assinatura primeiro para ter o ID disponível.
      await _carregarAssinatura(alunaId);

      // 2. Dar baixa automática em aulas cujo horário já passou.
      //    Faz isso antes de carregar as próximas aulas para garantir
      //    que os créditos já aparecem atualizados.
      if (_assinatura != null && _assinatura!.estaAtiva) {
        final baixas = await _aulaRepository.darBaixaAulasPassadas(
          alunaId,
          _assinatura!.id,
        );
        // Recarregar assinatura para refletir os créditos descontados.
        if (baixas > 0) {
          await _carregarAssinatura(alunaId);
        }
      }

      // 3. Carregar demais dados em paralelo.
      await Future.wait([
        _carregarProximasAulas(alunaId),
        _carregarEventos(),
      ]);
    } catch (e) {
      _erro = 'Erro ao carregar dados. Tente novamente.';
      debugPrint('HomeAlunaProvider.carregarDados erro: $e');
    } finally {
      _carregando = false;
      notifyListeners();
    }
  }

  Future<void> _carregarAssinatura(String alunaId) async {
    try {
      _assinatura = await _assinaturaRepository.buscarAtivaDeAluna(alunaId);
      if (_assinatura != null) {
        final doc = await FirebaseFirestore.instance
            .collection('planos')
            .doc(_assinatura!.planoId)
            .get();
        if (doc.exists && doc.data() != null) {
          _plano = Plano.fromMap(doc.data()!, doc.id);
        }
      }
    } catch (e) {
      debugPrint('HomeAlunaProvider._carregarAssinatura erro: $e');
    }
  }

  Future<void> _carregarProximasAulas(String alunaId) async {
    try {
      _proximasAulas = await _aulaRepository.buscarProximasPorAluna(
        alunaId,
        limite: 3,
      );
    } catch (e) {
      debugPrint('HomeAlunaProvider._carregarProximasAulas erro: $e');
      _proximasAulas = [];
    }
  }

  Future<void> _carregarEventos() async {
    try {
      final todos = await _eventoRepository.listarPublicados();
      final agora = DateTime.now();
      _proximosEventos =
          todos.where((e) => e.dataHora.isAfter(agora)).take(3).toList();
    } catch (e) {
      debugPrint('HomeAlunaProvider._carregarEventos erro: $e');
      _proximosEventos = [];
    }
  }

  void limpar() {
    _assinatura = null;
    _plano = null;
    _proximasAulas = [];
    _proximosEventos = [];
    _erro = null;
    notifyListeners();
  }
}
