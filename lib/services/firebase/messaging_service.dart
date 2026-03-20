import 'package:firebase_messaging/firebase_messaging.dart';

/// Serviço responsável pelas notificações push via Firebase Messaging.
class MessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Solicita permissão para receber notificações (iOS/Web).
  Future<void> solicitarPermissao() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Retorna o token FCM do dispositivo atual.
  Future<String?> obterToken() async {
    return _messaging.getToken();
  }

  /// Configura handler para mensagens recebidas em primeiro plano.
  void configurarMensagemEmPrimeiroPlano(
    void Function(RemoteMessage mensagem) handler,
  ) {
    FirebaseMessaging.onMessage.listen(handler);
  }
}
