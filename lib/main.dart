import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase (será configurado no próximo passo)
  // await Firebase.initializeApp();

  runApp(const App());
}
