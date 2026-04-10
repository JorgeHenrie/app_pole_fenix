import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/auth_provider.dart';
import 'providers/grade_horario_provider.dart';
import 'providers/home_aluna_provider.dart';
import 'providers/horario_fixo_provider.dart';
import 'providers/notificacao_provider.dart';
import 'providers/plano_provider.dart';
import 'providers/reposicao_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await initializeDateFormatting('pt_BR');
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeAlunaProvider()),
        ChangeNotifierProvider(create: (_) => HorarioFixoProvider()),
        ChangeNotifierProvider(create: (_) => ReposicaoProvider()),
        ChangeNotifierProvider(create: (_) => PlanoProvider()),
        ChangeNotifierProvider(create: (_) => GradeHorarioProvider()),
        ChangeNotifierProxyProvider<AuthProvider, NotificacaoProvider>(
          create: (_) => NotificacaoProvider(),
          update: (_, authProvider, notificacaoProvider) {
            final provider = notificacaoProvider ?? NotificacaoProvider();
            final usuario = authProvider.usuario;
            final usuarioId = usuario?.id;

            if (usuarioId == null) {
              provider.desconectar();
            } else {
              provider.conectar(
                usuarioId,
                tipoUsuario: usuario?.tipoUsuario ?? 'aluna',
              );
            }

            return provider;
          },
        ),
      ],
      child: const App(),
    ),
  );
}
