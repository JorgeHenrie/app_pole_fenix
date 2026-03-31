import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/validators.dart';

/// Tela exibida na primeira vez que uma aluna importada acessa o app.
/// Permite atualizar o e-mail real e definir uma senha pessoal.
class PrimeiroAcessoScreen extends StatefulWidget {
  const PrimeiroAcessoScreen({super.key});

  @override
  State<PrimeiroAcessoScreen> createState() => _PrimeiroAcessoScreenState();
}

class _PrimeiroAcessoScreenState extends State<PrimeiroAcessoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _confirmarSenhaController = TextEditingController();
  bool _obscurecerSenha = true;
  bool _obscurecerConfirmar = true;
  bool _salvando = false;

  @override
  void dispose() {
    _emailController.dispose();
    _senhaController.dispose();
    _confirmarSenhaController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _salvando = true);

    final novoEmail = _emailController.text.trim();
    final novaSenha = _senhaController.text;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() => _salvando = false);
      return;
    }

    try {
      // Atualiza senha primeiro (não invalida a sess\u00e3o)
      await user.updatePassword(novaSenha);

      // Atualiza e-mail no Auth
      await user.verifyBeforeUpdateEmail(novoEmail);

      // Atualiza Firestore imediatamente com o novo e-mail e remove a flag
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'email': novoEmail,
        'primeiroAcesso': false,
        'atualizadoEm': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Informa sobre a verifica\u00e7\u00e3o pendente e redireciona
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Verifique seu e-mail'),
          content: Text(
            'Enviamos um link de verificação para $novoEmail.\n\n'
            'Confirme o link e depois faça login com seu novo e-mail e senha.',
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                }
              },
              child: const Text('OK, vou verificar'),
            ),
          ],
        ),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.login);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String mensagem;
      switch (e.code) {
        case 'email-already-in-use':
          mensagem = 'Este e-mail já está cadastrado no app.';
          break;
        case 'invalid-email':
          mensagem = 'E-mail inválido.';
          break;
        case 'requires-recent-login':
          mensagem = 'Sessão expirada. Faça login novamente.';
          break;
        default:
          mensagem = e.message ?? 'Erro ao atualizar dados.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensagem), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),
                const Icon(
                  Icons.celebration_rounded,
                  size: 72,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Bem-vinda!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Para continuar, cadastre seu e-mail pessoal\ne crie uma senha para o app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Seu e-mail pessoal',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _senhaController,
                  obscureText: _obscurecerSenha,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurecerSenha
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscurecerSenha = !_obscurecerSenha),
                    ),
                  ),
                  validator: Validators.senha,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmarSenhaController,
                  obscureText: _obscurecerConfirmar,
                  decoration: InputDecoration(
                    labelText: 'Confirmar senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurecerConfirmar
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(
                          () => _obscurecerConfirmar = !_obscurecerConfirmar),
                    ),
                  ),
                  validator: (valor) {
                    if (valor == null || valor.isEmpty) {
                      return 'Confirme sua senha';
                    }
                    if (valor != _senhaController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _salvando ? null : _salvar,
                  child: _salvando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar e continuar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
