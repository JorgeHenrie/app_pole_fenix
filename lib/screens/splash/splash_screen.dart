import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';

/// Tela de splash exibida ao iniciar o app.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _verificarAutenticacao();
  }

  Future<void> _verificarAutenticacao() async {
    final authProvider = context.read<AuthProvider>();

    // Aguarda mínimo de 2 segundos e restauração da sessão concluída.
    await Future.wait([
      Future.delayed(const Duration(seconds: 2)),
      _aguardarSessaoInicializada(authProvider),
    ]);

    if (!mounted) return;

    if (authProvider.usuarioFirebase != null && authProvider.usuario == null) {
      await authProvider.recarregarUsuario();

      if (!mounted) return;

      if (authProvider.usuario == null) {
        await _aguardarUsuario(authProvider);
      }
    }

    if (authProvider.estaAutenticado) {
      if (!mounted) return;

      if (authProvider.usuario != null) {
        final usuario = authProvider.usuario!;
        if (usuario.tipoUsuario == 'admin') {
          Navigator.of(context).pushReplacementNamed(Routes.homeAdmin);
        } else if (usuario.statusCadastro == 'pendente') {
          Navigator.of(context)
              .pushReplacementNamed(Routes.aguardandoAprovacao);
        } else if (usuario.statusCadastro == 'rejeitado') {
          await authProvider.logout();
          if (mounted) {
            Navigator.of(context).pushReplacementNamed(Routes.login);
          }
        } else {
          Navigator.of(context).pushReplacementNamed(Routes.homeAluna);
        }
      } else {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    } else {
      Navigator.of(context).pushReplacementNamed(Routes.login);
    }
  }

  Future<void> _aguardarSessaoInicializada(AuthProvider authProvider) async {
    if (authProvider.sessaoInicializada) return;

    final completer = Completer<void>();
    void listener() {
      if (authProvider.sessaoInicializada) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    authProvider.addListener(listener);
    await completer.future;
    authProvider.removeListener(listener);
  }

  Future<void> _aguardarUsuario(AuthProvider authProvider) async {
    final completer = Completer<void>();
    void listener() {
      if (authProvider.usuario != null || !authProvider.estaAutenticado) {
        if (!completer.isCompleted) completer.complete();
      }
    }

    authProvider.addListener(listener);
    try {
      await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      debugPrint('SplashScreen: timeout ao aguardar dados do usuário');
    }
    authProvider.removeListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.local_fire_department_rounded,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Fênix Pole Dance',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
