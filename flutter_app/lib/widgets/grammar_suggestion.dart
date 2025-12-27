import 'package:flutter/material.dart';
import '../services/grammar_service.dart';
import '../theme/app_theme.dart';

/// Widget that displays grammar errors and suggestions
/// 
/// Usage:
/// ```dart
/// if (grammarResult.hasErrors)
///   ...grammarResult.errors.map((error) => 
///     GrammarSuggestion(
///       error: error,
///       onApplySuggestion: (suggestion) {
///         // Apply the suggestion to text
///       },
///     ),
///   ),
/// ```
class GrammarSuggestion extends StatelessWidget {
  final GrammarError error;
  final Function(String suggestion)? onApplySuggestion;
  final VoidCallback? onDismiss;

  const GrammarSuggestion({
    super.key,
    required this.error,
    this.onApplySuggestion,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrange.withOpacity(0.1),
        border: Border.all(
          color: AppTheme.accentOrange,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.accentOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error.displayMessage,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              if (onDismiss != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: AppTheme.textTertiary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onDismiss,
                ),
            ],
          ),
          
          // Full message if different from short message
          if (error.message.isNotEmpty && 
              error.message != error.shortMessage) ...[
            const SizedBox(height: 4),
            Text(
              error.message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          
          // Suggestions
          if (error.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Öneriler:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: error.suggestions.map((suggestion) {
                return _SuggestionChip(
                  suggestion: suggestion,
                  onTap: onApplySuggestion != null
                      ? () => onApplySuggestion!(suggestion)
                      : null,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Chip widget for individual suggestions
class _SuggestionChip extends StatelessWidget {
  final String suggestion;
  final VoidCallback? onTap;

  const _SuggestionChip({
    required this.suggestion,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.accentGreen.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.accentGreen.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              suggestion,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle_outline,
                size: 14,
                color: AppTheme.accentGreen,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact grammar indicator for text fields
/// Shows a small badge with error count
class GrammarIndicator extends StatelessWidget {
  final GrammarCheckResult? result;
  final VoidCallback? onTap;

  const GrammarIndicator({
    super.key,
    this.result,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (result == null || !result!.hasErrors) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accentOrange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.accentOrange,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: AppTheme.accentOrange,
            ),
            const SizedBox(width: 4),
            Text(
              '${result!.errorCount}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading indicator for grammar checking
class GrammarCheckingIndicator extends StatelessWidget {
  const GrammarCheckingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryPurple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                AppTheme.primaryPurple,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Kontrol ediliyor...',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Success indicator when grammar is correct
class GrammarCorrectIndicator extends StatelessWidget {
  const GrammarCorrectIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 14,
            color: AppTheme.accentGreen,
          ),
          const SizedBox(width: 6),
          const Text(
            'Gramer doğru!',
            style: TextStyle(
              color: AppTheme.accentGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full grammar check panel with all errors
class GrammarCheckPanel extends StatelessWidget {
  final GrammarCheckResult result;
  final Function(GrammarError error, String suggestion)? onApplySuggestion;
  final Function(GrammarError error)? onDismissError;

  const GrammarCheckPanel({
    super.key,
    required this.result,
    this.onApplySuggestion,
    this.onDismissError,
  });

  @override
  Widget build(BuildContext context) {
    if (!result.hasErrors) {
      return const GrammarCorrectIndicator();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(
                Icons.spellcheck,
                size: 16,
                color: AppTheme.accentOrange,
              ),
              const SizedBox(width: 6),
              Text(
                '${result.errorCount} gramer hatası bulundu',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Error list
        ...result.errors.map((error) {
          return GrammarSuggestion(
            error: error,
            onApplySuggestion: onApplySuggestion != null
                ? (suggestion) => onApplySuggestion!(error, suggestion)
                : null,
            onDismiss: onDismissError != null
                ? () => onDismissError!(error)
                : null,
          );
        }),
      ],
    );
  }
}
