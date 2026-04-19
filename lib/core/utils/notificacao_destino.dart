import '../constants/routes.dart';

String? rotaPorTipoNotificacao(String? tipo) {
  switch (tipo) {
    case 'movimento_conquistado':
      return Routes.minhaJornada;
    default:
      return null;
  }
}
