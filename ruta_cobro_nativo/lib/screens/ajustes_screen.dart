import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final profile = state.profile;
    final user = state.auth.currentUser;
    final locked = state.isLocked;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.surface,
                    backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                    child: user?.photoURL == null
                        ? Text(
                            ((profile?['name'] ?? user?.displayName ?? 'U') as String).isNotEmpty
                                ? ((profile?['name'] ?? user?.displayName ?? 'U') as String)[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?['name']?.toString() ?? user?.displayName ?? 'Usuario',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '', style: const TextStyle(color: AppTheme.muted, fontSize: 13)),
                        if (profile?['code'] != null) ...[
                          const SizedBox(height: 4),
                          Text('Código: ${profile!['code']}',
                              style: const TextStyle(color: AppTheme.amber, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (locked) ...[
            const SizedBox(height: 12),
            Card(
              color: AppTheme.red.withOpacity(0.12),
              child: const ListTile(
                leading: Icon(Icons.lock, color: AppTheme.red),
                title: Text('Membresía vencida'),
                subtitle: Text('Solo lectura. Renueva para seguir guardando.'),
              ),
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Recargar datos'),
            onTap: () => state.reload(),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de'),
            subtitle: const Text('RutaCobro RD · Flutter nativo v1.0'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppTheme.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: AppTheme.red)),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Salir de la cuenta?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Salir')),
                  ],
                ),
              );
              if (ok == true) await state.signOut();
            },
          ),
        ],
      ),
    );
  }
}
