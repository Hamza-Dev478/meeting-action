import 'package:flutter/material.dart';

/// The exact excerpt from the notes that supports a suggestion or action.
class SourceQuote extends StatelessWidget {
  const SourceQuote(this.quote, {super.key});

  final String quote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withValues(alpha: 0.12), primary.withValues(alpha: 0.04)],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 18, color: primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'From the notes',
                  style: theme.textTheme.labelSmall?.copyWith(color: primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('“$quote”', style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
