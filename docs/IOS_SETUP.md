# Setup iOS

## Estado atual do projeto

- Scaffold iOS recriado no repositório via Flutter.
- Bundle identifier atual do app iOS: `com.fenixpoledance.appPoleFenix`.
- O app já declara acesso à galeria no `Info.plist` e background mode para push remoto.
- O `Podfile` foi adicionado para permitir integração dos plugins Flutter no build iOS.
- O Firebase já foi configurado para Android e iOS com `lib/firebase_options.dart`.
- O arquivo `ios/Runner/GoogleService-Info.plist` foi gerado para o app iOS do projeto Firebase.

## O que ainda falta fora do Windows

1. Configurar assinatura Apple no Xcode ou no Codemagic.
2. Ativar Push Notifications e Background Modes no target `Runner` com uma conta Apple configurada.
3. Rodar `pod install` em ambiente macOS ou deixar o Codemagic executar essa etapa.
4. Testar o primeiro build iOS remoto e corrigir eventuais falhas de signing.

## Variáveis e segredos esperados no Codemagic

- Certificados e perfis Apple.
- Credenciais da App Store Connect.
- `GoogleService-Info.plist` como arquivo seguro ou variável de ambiente convertida em arquivo.

## Workflow versionado no repositório

- O arquivo `codemagic.yaml` já define o workflow `ios_preview`.
- Esse workflow roda `flutter pub get`, `flutter test`, gera APK Android de debug e compila iOS com `--no-codesign`.
- Ele é o primeiro build remoto viável sem Mac local e sem credenciais Apple.

## Observações

- A inicialização do app agora deve usar `DefaultFirebaseOptions.currentPlatform`.
- `GoogleService-Info.plist` e `google-services.json` não são segredos; o que deve permanecer protegido são credenciais Apple, contas de serviço e tokens de automação.