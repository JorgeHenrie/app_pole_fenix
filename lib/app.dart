import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/routes.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cadastro_screen.dart';
import 'screens/auth/recuperar_senha_screen.dart';
import 'screens/aluna/home_aluna_screen.dart';
import 'screens/aluna/agendar_aula_screen.dart';
import 'screens/aluna/minhas_aulas_screen.dart';
import 'screens/aluna/meu_plano_screen.dart';
import 'screens/aluna/eventos_screen.dart';
import 'screens/aluna/perfil_screen.dart';
import 'screens/aluna/meus_horarios_screen.dart';
import 'screens/aluna/minhas_reposicoes_screen.dart';
import 'screens/admin/home_admin_screen.dart';
import 'screens/admin/gerenciar_horarios_screen.dart';
import 'screens/admin/gerenciar_aulas_screen.dart';
import 'screens/admin/gerenciar_alunas_screen.dart';
import 'screens/admin/pagamentos_screen.dart';
import 'screens/admin/eventos_admin_screen.dart';
import 'screens/admin/aprovar_solicitacoes_screen.dart';
import 'screens/admin/validar_atestados_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fênix Pole Dance',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (context) => const SplashScreen(),
        Routes.login: (context) => const LoginScreen(),
        Routes.cadastro: (context) => const CadastroScreen(),
        Routes.recuperarSenha: (context) => const RecuperarSenhaScreen(),
        Routes.homeAluna: (context) => const HomeAlunaScreen(),
        Routes.agendarAula: (context) => const AgendarAulaScreen(),
        Routes.minhasAulas: (context) => const MinhasAulasScreen(),
        Routes.meuPlano: (context) => const MeuPlanoScreen(),
        Routes.perfil: (context) => const PerfilScreen(),
        Routes.eventos: (context) => const EventosScreen(),
        Routes.homeAdmin: (context) => const HomeAdminScreen(),
        Routes.gerenciarHorarios: (context) => const GerenciarHorariosScreen(),
        Routes.gerenciarAulas: (context) => const GerenciarAulasScreen(),
        Routes.gerenciarAlunas: (context) => const GerenciarAlunasScreen(),
        Routes.pagamentos: (context) => const PagamentosScreen(),
        Routes.eventosAdmin: (context) => const EventosAdminScreen(),
        Routes.meusHorarios: (context) => const MeusHorariosScreen(),
        Routes.minhasReposicoes: (context) => const MinhasReposicoesScreen(),
        Routes.aprovarSolicitacoes: (context) =>
            const AprovarSolicitacoesScreen(),
        Routes.validarAtestados: (context) => const ValidarAtestadosScreen(),
      },
    );
  }
}
