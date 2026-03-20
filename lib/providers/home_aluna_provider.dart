import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/assinatura.dart';
import '../models/aula.dart';
import '../models/evento.dart';
import '../models/plano.dart';
import '../repositories/assinatura_repository.dart';
import '../repositories/evento_repository.dart';

/// Provider responsável pelos dados da tela inicial da aluna.
class HomeAlunaProvider extends ChangeNotifier {
  final AssinaturaRepository _assinaturaRepository = AssinaturaRepository();
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
      await Future.wait([
        _carregarAssinatura(alunaId),
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
      final matriculasSnap = await FirebaseFirestore.instance
          .collection('matriculas')
          .where('alunaId', isEqualTo: alunaId)
          .where('status', isEqualTo: 'confirmada')
          .get();

      if (matriculasSnap.docs.isEmpty) {
        _proximasAulas = [];
        return;
      }

      final aulaIds = matriculasSnap.docs
          .map((d) => d.data()['aulaId'] as String)
          .toSet()
          .toList();

      final agora = DateTime.now();
      final List<Aula> aulas = [];

      // Consultas em lotes de 10: Firestore limita whereIn a 10 valores por query
      for (int i = 0; i < aulaIds.length; i += 10) {
        final lote = aulaIds.sublist(i, min(i + 10, aulaIds.length));
        final aulasSnap = await FirebaseFirestore.instance
            .collection('aulas')
            .where(FieldPath.documentId, whereIn: lote)
            .where('status', isEqualTo: 'agendada')
            .get();

        for (final doc in aulasSnap.docs) {
          final aula = Aula.fromMap(doc.data(), doc.id);
          if (aula.dataHora.isAfter(agora)) {
            aulas.add(aula);
          }
        }
      }

      aulas.sort((a, b) => a.dataHora.compareTo(b.dataHora));
      _proximasAulas = aulas.take(3).toList();
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
