import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';

/// Tela de login do app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _obscurecerSenha = true;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    await authProvider.login(
      _emailController.text.trim(),
      _senhaController.text,
    );

    if (!mounted) return;

    if (authProvider.estaAutenticado && authProvider.usuario != null) {
      final usuario = authProvider.usuario!;
      if (usuario.tipoUsuario == 'admin') {
        Navigator.of(context).pushReplacementNamed(Routes.homeAdmin);
        return;
      }
      // Conta desativada (aluna excluída pelo admin)
      if (!usuario.ativo) {
        await authProvider.logout();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Sua conta foi desativada. Entre em contato com o estúdio.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }
      // Verifica status do cadastro da aluna
      if (usuario.statusCadastro == 'pendente') {
        Navigator.of(context).pushReplacementNamed(Routes.aguardandoAprovacao);
        return;
      }
      if (usuario.statusCadastro == 'rejeitado') {
        await authProvider.logout();
        if (!mounted) return;
        final motivo = usuario.motivoRejeicao?.isNotEmpty == true
            ? usuario.motivoRejeicao!
            : 'Entre em contato com o estúdio.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cadastro rejeitado: $motivo'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      Navigator.of(context).pushReplacementNamed(Routes.homeAluna);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/teste3.jpg',
            fit: BoxFit.cover,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.72),
                  AppColors.primary.withValues(alpha: 0.58),
                  Colors.black.withValues(alpha: 0.34),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 430),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/Logo.png',
                            height: 112,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          decoration: BoxDecoration(
                            color: AppColors.surface.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.primaryLight.withValues(
                                alpha: 0.36,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Acesse sua conta',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Entre para acompanhar aulas, plano e avisos do estúdio.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 22),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'E-mail',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: Validators.email,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _senhaController,
                                obscureText: _obscurecerSenha,
                                decoration: InputDecoration(
                                  labelText: 'Senha',
                                  prefixIcon: const Icon(Icons.lock_outlined),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurecerSenha
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurecerSenha = !_obscurecerSenha,
                                    ),
                                  ),
                                ),
                                validator: Validators.senha,
                              ),
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context)
                                      .pushNamed(Routes.recuperarSenha),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                  ),
                                  child: const Text('Esqueci minha senha'),
                                ),
                              ),
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  if (auth.erro == null) {
                                    return const SizedBox(height: 12);
                                  }

                                  return Container(
                                    margin: const EdgeInsets.only(
                                      top: 6,
                                      bottom: 14,
                                    ),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      auth.erro!,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              ),
                              Consumer<AuthProvider>(
                                builder: (context, auth, _) {
                                  return ElevatedButton(
                                    onPressed: auth.carregando ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: auth.carregando
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text(
                                            'Entrar',
                                            style: TextStyle(fontSize: 16),
                                          ),
                                  );
                                },
                              ),
                              const SizedBox(height: 18),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Não tem uma conta?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(context)
                                        .pushNamed(Routes.cadastro),
                                    child: const Text(
                                      'Criar conta',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
