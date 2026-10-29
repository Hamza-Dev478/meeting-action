import 'package:flutter/material.dart';

import 'glass.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator.adaptive(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.icon, required this.title, this.message, this.action, this.color});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  /// Accent for the icon badge; the primary colour when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassBadge(icon: icon, color: color, size: 72),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 6),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: EmptyView(
        icon: Icons.cloud_off_outlined,
        color: Theme.of(context).colorScheme.error,
        title: 'Something went wrong',
        message: message,
        action: onRetry == null ? null : FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
      ),
    );
  }
}

/// A compact glass message card used inside a screen (errors, progress, notices).
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.message,
    this.tone = BannerTone.info,
    this.actions = const [],
    this.leading,
    this.title,
  });

  final String message;
  final BannerTone tone;
  final List<Widget> actions;
  final Widget? leading;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (accent, icon) = switch (tone) {
      BannerTone.error => (scheme.error, Icons.error_outline),
      BannerTone.info => (scheme.primary, Icons.info_outline),
    };
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 8),
      tint: tone == BannerTone.error ? scheme.errorContainer.withValues(alpha: 0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading ?? GlassBadge(icon: icon, color: accent, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null) ...[
                        Text(title!, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                      ],
                      Text(message, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 8, children: actions),
            ),
        ],
      ),
    );
  }
}

enum BannerTone { info, error }
