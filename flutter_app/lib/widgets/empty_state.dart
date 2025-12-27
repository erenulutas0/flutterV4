import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Empty state widget for displaying when there's no data
/// 
/// Usage:
/// ```dart
/// EmptyState(
///   icon: Icons.inbox_outlined,
///   title: 'No items yet',
///   message: 'Start by adding your first item!',
///   actionText: 'Add Item',
///   onAction: () => _showAddDialog(),
/// )
/// ```
class EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionText;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionText,
    this.onAction,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with subtle animation
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            
            // Optional action button
            if (actionText != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionText!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specialized empty state for words
class EmptyWordsState extends StatelessWidget {
  final VoidCallback? onAddWord;

  const EmptyWordsState({
    super.key,
    this.onAddWord,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.menu_book_outlined,
      iconColor: AppTheme.primaryPurple,
      title: 'Henüz kelime eklemedin!',
      message: '🦉 Owen seninle ilk kelimeni öğrenmek için sabırsızlanıyor!\n\nYukarıdaki formu kullanarak hemen başlayabilirsin.',
      actionText: onAddWord != null ? 'İlk Kelimeni Ekle' : null,
      onAction: onAddWord,
    );
  }
}

/// Specialized empty state for sentences
class EmptySentencesState extends StatelessWidget {
  final VoidCallback? onAddSentence;

  const EmptySentencesState({
    super.key,
    this.onAddSentence,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.speaker_notes_off,
      iconColor: AppTheme.accentGreen,
      title: 'Henüz cümle eklemedin!',
      message: '🦉 Owen: "Hadi birlikte ilk cümleni kuralım!\nÖğrendiğin kelimeleri cümleler içinde kullanmak çok önemli."',
      actionText: onAddSentence != null ? 'İlk Cümleni Ekle' : null,
      onAction: onAddSentence,
    );
  }
}

/// Specialized empty state for practice
class EmptyPracticeState extends StatelessWidget {
  const EmptyPracticeState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.psychology_outlined,
      iconColor: AppTheme.accentOrange,
      title: 'Pratik için kelime yok!',
      message: '🦉 Owen: "Önce birkaç kelime öğrenmen gerekiyor.\nSonra birlikte pratik yaparız!"',
    );
  }
}

/// Specialized empty state for reviews (SRS)
class EmptyReviewsState extends StatelessWidget {
  const EmptyReviewsState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.celebration_outlined,
      iconColor: AppTheme.accentGreen,
      title: 'Tebrikler! 🎉',
      message: 'Bugün için tüm tekrarlarını tamamladın!\n\n🦉 Owen seninle gurur duyuyor. Yarın yeni kelimeler seni bekliyor!',
    );
  }
}
