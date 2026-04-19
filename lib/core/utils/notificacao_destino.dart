import '../constants/routes.dart';

String? rotaPorTipoNotificacao(String? tipo) {
  switch (tipo) {
    case 'movimento_conquistado':
      return Routes.minhaJornada;
    case 'comentario_feed':
      return Routes.gerenciarAvisos;
    default:
      return null;
  }
}
