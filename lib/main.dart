import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/home_aluna_provider.dart';
import 'providers/horario_fixo_provider.dart';
import 'providers/plano_provider.dart';
import 'providers/reposicao_provider.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => HomeAlunaProvider()),
        ChangeNotifierProvider(create: (_) => HorarioFixoProvider()),
        ChangeNotifierProvider(create: (_) => ReposicaoProvider()),
        ChangeNotifierProvider(create: (_) => PlanoProvider()),
      ],
      child: const App(),
    ),
  );
}
