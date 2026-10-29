import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../models/app_user.dart';
import '../theme/ambient_backdrop.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass.dart';
import '../widgets/glass_page.dart';
import '../widgets/state_views.dart';

/// Development-only sign-in: pick one of the seeded users. The server issues a
/// bearer token; there is no password because this is not real authentication.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.api, required this.onSignedIn});

  final ApiClient api;
  final ValueChanged<Session> onSignedIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  List<AppUser>? _users;
  ApiException? _error;
  String? _signingIn;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _users = null;
      _error = null;
    });
    try {
      final users = await widget.api.devUsers();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _signIn(AppUser user) async {
    setState(() => _signingIn = user.email);
    try {
      widget.onSignedIn(await widget.api.signIn(user.email));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _signingIn = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AmbientBackdrop(
        child: BackdropGroup(child: SafeArea(child: _body(theme))),
      ),
    );
  }

  Widget _body(ThemeData theme) {
    if (_error != null) return ErrorView(message: _error!.message, onRetry: _load);
    final users = _users;
    if (users == null) return const LoadingView(message: 'Loading test accounts…');
    if (users.isEmpty) {
      return Center(
        child: EmptyView(
          icon: Icons.group_off_outlined,
          title: 'No seeded users',
          message: 'Run bin/rails db:seed in the backend, then try again.',
          action: FilledButton.tonal(onPressed: _load, child: const Text('Try again')),
        ),
      );
    }

    final byOrganization = <String, List<AppUser>>{};
    for (final user in users) {
      byOrganization.putIfAbsent(user.organizationName, () => []).add(user);
    }

    final scheme = theme.colorScheme;
    var row = 0;
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24).add(centeringInsets(constraints.maxWidth)),
        children: [
          Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(colors: GlassTheme.accentSweep),
                boxShadow: [BoxShadow(color: GlassTheme.accentSweep.first.withValues(alpha: 0.45), blurRadius: 28)],
              ),
              child: SizedBox(
                width: 76,
                height: 76,
                child: Icon(Icons.auto_awesome, size: 34, color: scheme.onPrimary),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Meeting → Action',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text(
            'Turn meeting notes into action items you review and own.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 28),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sign in as a test user', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Development sign-in. Each organization only sees its own meetings and actions.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                for (final entry in byOrganization.entries) ...[
                  const SizedBox(height: 18),
                  Text(
                    entry.key.toUpperCase(),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  for (final user in entry.value)
                    Entrance(
                      index: row++,
                      child: _UserRow(
                        user: user,
                        signingIn: _signingIn == user.email,
                        onTap: _signingIn == null ? () => _signIn(user) : null,
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'API: ${widget.api.baseUrl}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.user, required this.signingIn, required this.onTap});

  final AppUser user;
  final bool signingIn;
  final VoidCallback? onTap;

  /// A stable accent per organization, so people from the same one match.
  static const _accents = [Color(0xFF5B6CFF), Color(0xFF14A3AD), Color(0xFFB45CF0), Color(0xFFE5764F)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = _accents[user.organizationName.codeUnits.fold(0, (a, b) => a + b) % _accents.length];
    return ListTile(
      key: Key('sign-in-${user.email}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.white, 0.35)!],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          user.name.characters.first,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      title: Text(user.name, style: theme.textTheme.titleMedium),
      subtitle: Text(user.email),
      trailing: signingIn
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : Icon(Icons.chevron_right, color: theme.colorScheme.outline),
      onTap: onTap,
    );
  }
}
