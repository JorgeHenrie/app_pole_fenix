import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Serviço responsável pelas notificações push via Firebase Messaging.
class MessagingService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  bool get suportaPush {
    if (kIsWeb) return true;

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Solicita permissão para receber notificações (iOS/Web).
  Future<void> solicitarPermissao() async {
    if (!suportaPush) return;

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Retorna o token FCM do dispositivo atual.
  Future<String?> obterToken() async {
    if (!suportaPush) return null;
    return _messaging.getToken();
  }

  /// Escuta mudanças no token FCM do dispositivo atual.
  StreamSubscription<String> escutarAtualizacaoToken(
    void Function(String token) handler,
  ) {
    if (!suportaPush) {
      return const Stream<String>.empty().listen(handler);
    }

    return _messaging.onTokenRefresh.listen(handler);
  }

  StreamSubscription<RemoteMessage> escutarAberturaNotificacao(
    void Function(RemoteMessage mensagem) handler,
  ) {
    if (!suportaPush) {
      return const Stream<RemoteMessage>.empty().listen(handler);
    }

    return FirebaseMessaging.onMessageOpenedApp.listen(handler);
  }

  Future<RemoteMessage?> obterMensagemInicial() async {
    if (!suportaPush) return null;
    return _messaging.getInitialMessage();
  }

  /// Configura handler para mensagens recebidas em primeiro plano.
  void configurarMensagemEmPrimeiroPlano(
    void Function(RemoteMessage mensagem) handler,
  ) {
    if (!suportaPush) return;
    FirebaseMessaging.onMessage.listen(handler);
  }
}
