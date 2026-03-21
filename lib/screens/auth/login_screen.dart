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
      // Verifica status do cadastro da aluna
      if (usuario.statusCadastro == 'pendente') {
        Navigator.of(context)
            .pushReplacementNamed(Routes.aguardandoAprovacao);
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                // Logo / Título
                const Icon(
                  Icons.self_improvement,
                  size: 80,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Fênix Pole Dance',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Faça login para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 48),
                // Campo de e-mail
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
                // Campo de senha
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
                      onPressed: () =>
                          setState(() => _obscurecerSenha = !_obscurecerSenha),
                    ),
                  ),
                  validator: Validators.senha,
                ),
                const SizedBox(height: 8),
                // Link "Esqueci minha senha"
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Routes.recuperarSenha),
                    child: const Text('Esqueci minha senha'),
                  ),
                ),
                const SizedBox(height: 8),
                // Mensagem de erro
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.erro != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          auth.erro!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                // Botão Entrar
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return ElevatedButton(
                      onPressed: auth.carregando ? null : _login,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                const SizedBox(height: 24),
                // Link "Criar conta"
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Não tem uma conta?'),
                    TextButton(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(Routes.cadastro),
                      child: const Text('Criar conta'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
