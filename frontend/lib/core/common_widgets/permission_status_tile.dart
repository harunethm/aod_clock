import 'package:flutter/material.dart';

/// One row: what the permission is for, whether it's granted, and a button
/// to fix it if not. Used for every manual grant this app needs — none of
/// them have a normal runtime-permission dialog, they're all deep links to
/// a system settings screen.
class PermissionStatusTile extends StatelessWidget {
  const PermissionStatusTile({
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.onGrant,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool? granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) {
    final isGranted = granted ?? false;
    return ListTile(
      leading: Icon(
        isGranted ? Icons.check_circle : Icons.error_outline,
        color: isGranted ? Colors.greenAccent : Colors.orangeAccent,
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isGranted
          ? null
          : TextButton(onPressed: onGrant, child: const Text('Grant')),
    );
  }
}
