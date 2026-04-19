import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AvisoTimelineHelper {
  static const List<String> categorias = [
    'aviso',
    'comunicado',
    'evento',
    'workshop',
    'novidade',
  ];

  static String label(String categoria) {
    switch (categoria) {
      case 'comunicado':
        return 'Comunicado';
      case 'evento':
        return 'Evento';
      case 'workshop':
        return 'Workshop';
      case 'novidade':
        return 'Novidade';
      case 'aviso':
      default:
        return 'Aviso';
    }
  }

  static Color color(String categoria) {
    switch (categoria) {
      case 'comunicado':
        return AppColors.info;
      case 'evento':
        return AppColors.secondary;
      case 'workshop':
        return AppColors.accentCaramel;
      case 'novidade':
        return AppColors.accentCocoa;
      case 'aviso':
      default:
        return AppColors.primary;
    }
  }

  static IconData icon(String categoria) {
    switch (categoria) {
      case 'comunicado':
        return Icons.campaign_outlined;
      case 'evento':
        return Icons.event_available_outlined;
      case 'workshop':
        return Icons.auto_awesome_outlined;
      case 'novidade':
        return Icons.new_releases_outlined;
      case 'aviso':
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
