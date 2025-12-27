import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word.dart';
import '../theme/app_theme.dart';
import '../providers/word_provider.dart';

class WordSentencesScreen extends StatefulWidget {
  final Word word;

  const WordSentencesScreen({
    super.key,
    required this.word,
  });

  @override
  State<WordSentencesScreen> createState() => _WordSentencesScreenState();
}

class _WordSentencesScreenState extends State<WordSentencesScreen> {
  // Provider'dan veri alacağımız için local word state'ine gerek yok
  final Map<int, bool> _showDefinitionMap = {}; // Her cümle için ayrı state

  @override
  void initState() {
    super.initState();
    // İlk açılışta güncel veriyi çekmesi için refresh tetikleyebiliriz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WordProvider>(context, listen: false).loadWordById(widget.word.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WordProvider>(
      builder: (context, provider, child) {
        // Kelimeyi provider'dan güncel haliyle bul
        // Eğer listede yoksa (örn: silinmişse veya hata varsa) widget.word (eski) kullan
        final word = provider.words.firstWhere(
          (w) => w.id == widget.word.id,
          orElse: () => widget.word,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('${word.englishWord} - Cümleler'),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: AppTheme.darkGradient,
                    ),
                  ),
                  child: word.sentences.isEmpty
                      ? Center(
                          child: Card(
                            color: AppTheme.darkSurface,
                            margin: const EdgeInsets.all(16),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.text_fields,
                                    size: 64,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Bu kelime için henüz cümle eklenmemiş.',
                                    style: TextStyle(color: AppTheme.textTertiary),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Cümleler listesi
                            ...word.sentences.map((sentence) => 
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildSentenceCard(context, sentence, word),
                              )
                            ).toList(),
                          ],
                        ),
                ),
        );
      },
    );
  }

  Widget _buildSentenceCard(BuildContext context, Sentence sentence, Word word) {
    final difficultyColor = _getDifficultyColor(sentence.difficulty ?? 'easy');

    return Card(
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: difficultyColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    (sentence.difficulty ?? 'easy').toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppTheme.accentRed),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: AppTheme.darkSurface,
                        title: const Text(
                          'Cümle Sil',
                          style: TextStyle(color: AppTheme.textPrimary),
                        ),
                        content: const Text(
                          'Bu cümleyi silmek istediğinizden emin misiniz?',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('İptal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentRed,
                            ),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final provider = Provider.of<WordProvider>(context, listen: false);
                      await provider.deleteSentenceFromWord(word.id, sentence.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cümle silindi'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                        // Provider güncellendiği için consumer otomatik yenilenir
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              sentence.sentence,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              sentence.translation,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            // Anlamı Göster butonu - her cümle kartında
            InkWell(
              onTap: () {
                setState(() {
                  _showDefinitionMap[sentence.id] = 
                      !(_showDefinitionMap[sentence.id] ?? false);
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.primaryPurple.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: AppTheme.primaryPurple,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Anlamı Göster',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryPurple,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      (_showDefinitionMap[sentence.id] ?? false)
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 18,
                      color: AppTheme.primaryPurple,
                    ),
                  ],
                ),
              ),
            ),
            // Kelime anlamı - göster/gizle
            if (_showDefinitionMap[sentence.id] ?? false) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      margin: const EdgeInsets.only(right: 12, top: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppTheme.purpleGradient,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        word.turkishMeaning,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return AppTheme.accentGreen;
      case 'medium':
        return AppTheme.accentOrange;
      case 'hard':
      case 'difficult':
        return AppTheme.accentRed;
      default:
        return AppTheme.gray600;
    }
  }
}
