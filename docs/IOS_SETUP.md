# Setup iOS

## Estado atual do projeto

- Scaffold iOS recriado no repositório via Flutter.
- Bundle identifier atual do app iOS: `com.fenixpoledance.appPoleFenix`.
- O app já declara acesso à galeria no `Info.plist` e background mode para push remoto.
- O `Podfile` foi adicionado para permitir integração dos plugins Flutter no build iOS.

## O que ainda falta fora do Windows

1. Cadastrar o app iOS no Firebase com o bundle identifier `com.fenixpoledance.appPoleFenix`.
2. Obter o arquivo `GoogleService-Info.plist` do Firebase para o app iOS.
3. Configurar assinatura Apple no Xcode ou no Codemagic.
4. Ativar Push Notifications e Background Modes no target `Runner`.
5. Rodar `pod install` em ambiente macOS ou deixar o Codemagic executar essa etapa.

## Variáveis e segredos esperados no Codemagic

- Certificados e perfis Apple.
- Credenciais da App Store Connect.
- `GoogleService-Info.plist` como arquivo seguro ou variável de ambiente convertida em arquivo.

## Observações

- A inicialização atual do Firebase continua usando `Firebase.initializeApp()` sem `firebase_options.dart`.
- Isso funciona com `google-services.json` no Android e exigirá `GoogleService-Info.plist` no iOS.