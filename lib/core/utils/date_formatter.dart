import 'package:intl/intl.dart';

/// Utilitários para formatação de datas e horas.
class DateFormatter {
  static final DateFormat _dataCompleta = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final DateFormat _dataHora = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
  static final DateFormat _hora = DateFormat('HH:mm', 'pt_BR');
  static final DateFormat _mesAno = DateFormat('MMMM yyyy', 'pt_BR');

  /// Formata data no padrão dd/MM/yyyy.
  static String data(DateTime data) => _dataCompleta.format(data);

  /// Formata data e hora no padrão dd/MM/yyyy HH:mm.
  static String dataHora(DateTime data) => _dataHora.format(data);

  /// Formata apenas a hora no padrão HH:mm.
  static String hora(DateTime data) => _hora.format(data);

  /// Formata mês e ano (ex: "março 2025").
  static String mesAno(DateTime data) => _mesAno.format(data);

  /// Converte string dd/MM/yyyy para DateTime.
  static DateTime? parseData(String texto) {
    try {
      return _dataCompleta.parse(texto);
    } catch (_) {
      return null;
    }
  }
}
