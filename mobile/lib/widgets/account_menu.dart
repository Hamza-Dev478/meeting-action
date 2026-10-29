import 'package:flutter/material.dart';

import '../app_scope.dart';
import 'glass.dart';

class AccountMenu extends StatelessWidget {
  const AccountMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final user = scope.user;
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      onSelected: (value) {
        if (value == 'sign-out') scope.onSignOut?.call();
      },
      itemBuilder: (context) => [
        if (user != null)
          PopupMenuItem<String>(
            enabled: false,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(user.name),
              subtitle: Text(user.organizationName),
            ),
          ),
        const PopupMenuItem<String>(value: 'sign-out', child: Text('Sign out')),
      ],
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: user == null
            ? const GlassBadge(icon: Icons.person_outline, size: 36)
            : GlassBadge(label: user.name.characters.first, size: 36),
      ),
    );
  }
}
