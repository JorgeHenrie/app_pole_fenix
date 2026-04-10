import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/constants/routes.dart';
import 'models/grade_horario.dart';
import 'models/plano.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/cadastro_screen.dart';
import 'screens/auth/recuperar_senha_screen.dart';
import 'screens/auth/aguardando_aprovacao_screen.dart';
import 'screens/aluna/home_aluna_screen.dart';
import 'screens/aluna/notificacoes_screen.dart';
import 'screens/aluna/agendar_aula_screen.dart';
import 'screens/aluna/minhas_aulas_screen.dart';
import 'screens/aluna/meu_plano_screen.dart';
import 'screens/aluna/eventos_screen.dart';
import 'screens/aluna/perfil_screen.dart';
import 'screens/aluna/meus_horarios_screen.dart';
import 'screens/aluna/minhas_reposicoes_screen.dart';
import 'screens/aluna/contratar_plano_screen.dart';
import 'screens/aluna/selecionar_horarios_screen.dart';
import 'screens/aluna/confirmar_contratacao_screen.dart';
import 'screens/aluna/sucesso_contratacao_screen.dart';
import 'screens/admin/home_admin_screen.dart';
import 'screens/admin/gerenciar_horarios_screen.dart';
import 'screens/admin/gerenciar_alunas_screen.dart';
import 'screens/admin/pagamentos_screen.dart';
import 'screens/admin/visualizar_ocupacao_screen.dart';
import 'screens/admin/gerenciar_planos_screen.dart';
import 'screens/admin/aprovar_cadastros_screen.dart';
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (context) => const SplashScreen(),
        Routes.login: (context) => const LoginScreen(),
        Routes.cadastro: (context) => const CadastroScreen(),
        Routes.recuperarSenha: (context) => const RecuperarSenhaScreen(),
        Routes.aguardandoAprovacao: (context) =>
            const AguardandoAprovacaoScreen(),
        Routes.homeAluna: (context) => const HomeAlunaScreen(),
        Routes.agendarAula: (context) => const AgendarAulaScreen(),
        Routes.minhasAulas: (context) => const MinhasAulasScreen(),
        Routes.meuPlano: (context) => const MeuPlanoScreen(),
        Routes.perfil: (context) => const PerfilScreen(),
        Routes.eventos: (context) => const EventosScreen(),
        Routes.homeAdmin: (context) => const HomeAdminScreen(),
        Routes.gerenciarHorarios: (context) => const GerenciarHorariosScreen(),
        Routes.gerenciarAlunas: (context) => const GerenciarAlunasScreen(),
        Routes.pagamentos: (context) => const PagamentosScreen(),
        Routes.meusHorarios: (context) => const MeusHorariosScreen(),
        Routes.minhasReposicoes: (context) => const MinhasReposicoesScreen(),
        // Contratação de plano
        Routes.contratarPlano: (context) => const ContratarPlanoScreen(),
        Routes.selecionarHorarios: (context) {
          final plano = ModalRoute.of(context)!.settings.arguments as Plano;
          return SelecionarHorariosScreen(plano: plano);
        },
        Routes.confirmarContratacao: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return ConfirmarContratacaoScreen(
            plano: args['plano'] as Plano,
            horariosEscolhidos: (args['horarios'] as List).cast<GradeHorario>(),
          );
        },
        Routes.sucessoContratacao: (context) {
          final args = ModalRoute.of(context)!.settings.arguments
              as Map<String, dynamic>;
          return SucessoContratacaoScreen(
            horarios: (args['horarios'] as List).cast<GradeHorario>(),
          );
        },
        // Admin – ocupação
        Routes.visualizarOcupacao: (context) =>
            const VisualizarOcupacaoScreen(),
        Routes.gerenciarPlanos: (context) => const GerenciarPlanosScreen(),
        Routes.aprovarCadastros: (context) => const AprovarCadastrosScreen(),
        Routes.aprovarSolicitacoes: (context) =>
            const AprovarSolicitacoesScreen(),
        Routes.validarAtestados: (context) => const ValidarAtestadosScreen(),
        Routes.notificacoes: (context) => const NotificacoesScreen(),
      },
    );
  }
}
