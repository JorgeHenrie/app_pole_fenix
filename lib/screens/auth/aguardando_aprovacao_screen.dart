import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// Tela exibida quando o cadastro da aluna está aguardando aprovação do admin.
class AguardandoAprovacaoScreen extends StatelessWidget {
  const AguardandoAprovacaoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = context.read<AuthProvider>().usuario;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.hourglass_top_rounded,
                size: 80,
                color: AppColors.warning,
              ),
              const SizedBox(height: 24),
              Text(
                'Cadastro em Análise',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 16),
              if (usuario != null)
                Text(
                  'Olá, ${usuario.nome.split(' ').first}!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              const SizedBox(height: 12),
              Text(
                'Seu cadastro foi recebido com sucesso e está aguardando a aprovação do administrador.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Você receberá acesso ao app assim que seu cadastro for aprovado. Por favor, tente fazer login novamente em breve.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Verificar Aprovação'),
                onPressed: () async {
                  final authProvider = context.read<AuthProvider>();
                  final uid = authProvider.usuarioFirebase?.uid;
                  if (uid == null) return;
                  // Recarrega dados do usuário no Firestore
                  await authProvider.recarregarUsuario();
                  if (!context.mounted) return;
                  final u = authProvider.usuario;
                  if (u == null) return;
                  if (u.statusCadastro == 'aprovado') {
                    Navigator.of(context)
                        .pushReplacementNamed(Routes.homeAluna);
                  } else if (u.statusCadastro == 'rejeitado') {
                    await authProvider.logout();
                    if (!context.mounted) return;
                    Navigator.of(context)
                        .pushReplacementNamed(Routes.login);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Cadastro ainda aguardando aprovação.'),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Sair'),
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (!context.mounted) return;
                  Navigator.of(context)
                      .pushReplacementNamed(Routes.login);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
