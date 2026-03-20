/// Validações de formulário utilizadas em todo o app.
class Validators {
  /// Valida se o campo não está vazio.
  static String? obrigatorio(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo é obrigatório';
    }
    return null;
  }

  /// Valida formato de e-mail.
  static String? email(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo é obrigatório';
    }
    final regex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,}$');
    if (!regex.hasMatch(valor.trim())) {
      return 'E-mail inválido';
    }
    return null;
  }

  /// Valida tamanho mínimo de senha.
  static String? senha(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Este campo é obrigatório';
    }
    if (valor.length < 6) {
      return 'A senha deve ter pelo menos 6 caracteres';
    }
    return null;
  }

  /// Valida número de telefone brasileiro.
  static String? telefone(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Este campo é obrigatório';
    }
    final digits = valor.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10 || digits.length > 11) {
      return 'Telefone inválido';
    }
    return null;
  }
}
