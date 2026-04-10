import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/notificacao_provider.dart';

class NotificacaoActionButton extends StatelessWidget {
  const NotificacaoActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificacaoProvider>(
      builder: (context, notificacaoProvider, _) {
        final total = notificacaoProvider.naoLidas;
        final badge = total > 99 ? '99+' : '$total';

        return IconButton(
          tooltip: 'Notificações',
          onPressed: () => Navigator.pushNamed(context, Routes.notificacoes),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined),
              if (total > 0)
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    constraints: const BoxConstraints(minWidth: 18),
                    child: Text(
                      badge,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
