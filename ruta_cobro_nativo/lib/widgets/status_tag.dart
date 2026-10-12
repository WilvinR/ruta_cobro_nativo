import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StatusTag extends StatelessWidget {
  final String status;
  const StatusTag({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status) {
      case 'Atrasado':
        bg = AppTheme.red.withOpacity(0.15);
        fg = AppTheme.red;
        break;
      case 'Vence hoy':
        bg = AppTheme.amber.withOpacity(0.15);
        fg = AppTheme.amber;
        break;
      case 'Liquidado':
        bg = AppTheme.green.withOpacity(0.15);
        fg = AppTheme.green;
        break;
      default:
        bg = AppTheme.blue.withOpacity(0.15);
        fg = AppTheme.blue;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
