import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sentence_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_skeleton.dart';
import '../services/grammar_service.dart';
import '../widgets/grammar_suggestion.dart';

class SentencesScreen extends StatefulWidget {
  const SentencesScreen({super.key});

  @override
  State<SentencesScreen> createState() => _SentencesScreenState();
}

class _SentencesScreenState extends State<SentencesScreen> {
  String _selectedDifficulty = 'all';
  final Map<String, bool> _showDefinitionMap = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<SentenceProvider>(context, listen: false);
      provider.loadAllSentences();
      provider.loadStats();
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cümleler'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: Consumer<SentenceProvider>(
          builder: (context, provider, _) {
            // Filtreleme mantığı: Hem zorluk hem arama metnine göre
            final filteredSentences = provider.sentences.where((s) {
              // Zorluk filtresi
              if (_selectedDifficulty != 'all' && 
                  s.difficulty.toLowerCase() != _selectedDifficulty) {
                return false;
              }
              
              // Arama filtresi
              if (_searchQuery.isNotEmpty) {
                final english = s.englishSentence.toLowerCase();
                final turkish = s.turkishTranslation.toLowerCase();
                return english.contains(_searchQuery) || turkish.contains(_searchQuery);
              }
              
              return true;
            }).toList();

            return Column(
              children: [
                // Stats Card
                if (provider.stats != null)
                  Card(
                    margin: const EdgeInsets.all(16),
                    color: AppTheme.darkSurface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Toplam',
                            provider.stats!['total']?.toString() ?? '0',
                            AppTheme.accentBlue,
                          ),
                          _buildStatItem(
                            'Kolay',
                            provider.stats!['easy']?.toString() ?? '0',
                            AppTheme.accentGreen,
                          ),
                          _buildStatItem(
                            'Orta',
                            provider.stats!['medium']?.toString() ?? '0',
                            AppTheme.accentOrange,
                          ),
                          _buildStatItem(
                            'Zor',
                            provider.stats!['hard']?.toString() ?? '0',
                            AppTheme.accentRed,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                // Arama Çubuğu
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Cümlelerde ara...',
                      hintStyle: const TextStyle(color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.darkSurfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                
                // Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Tümü')),
                      ButtonSegment(value: 'easy', label: Text('Kolay')),
                      ButtonSegment(value: 'medium', label: Text('Orta')),
                      ButtonSegment(value: 'hard', label: Text('Zor')),
                    ],
                    selected: {_selectedDifficulty},
                    onSelectionChanged: (Set<String> selected) {
                      setState(() {
                        _selectedDifficulty = selected.first;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppTheme.primaryPurple,
                      selectedForegroundColor: AppTheme.textPrimary,
                      backgroundColor: AppTheme.darkSurfaceVariant,
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sentences List
                Expanded(
                  child: provider.isLoading
                      ? ListView(
                          padding: const EdgeInsets.all(16),
                          children: const [
                            SentenceCardSkeleton(),
                            SentenceCardSkeleton(),
                            SentenceCardSkeleton(),
                          ],
                        )
                      : provider.error != null
                          ? Center(
                              child: Card(
                                color: AppTheme.darkSurface,
                                margin: const EdgeInsets.all(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: AppTheme.accentRed,
                                        size: 32,
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              'Bir hata oluştu',
                                              style: TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              provider.error!,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => provider.loadAllSentences(),
                                        child: const Text('Tekrar Dene'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          : filteredSentences.isEmpty
                              ? EmptySentencesState(
                                  onAddSentence: () => _showAddSentenceDialog(context),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredSentences.length,
                                  itemBuilder: (context, index) {
                                    final sentence = filteredSentences[index];
                                    return _buildSentenceCard(sentence, provider);
                                  },
                                ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSentenceDialog(context),
        backgroundColor: AppTheme.primaryPurple,
        child: const Icon(Icons.add, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSentenceCard(sentence, SentenceProvider provider) {
    final difficultyColor = _getDifficultyColor(sentence.difficulty);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
                    sentence.difficulty.toUpperCase(),
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
                        title: const Text('Cümle Sil', style: TextStyle(color: AppTheme.textPrimary)),
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
                    if (confirm == true) {
                      await provider.deleteSentence(sentence.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cümle silindi'),
                            backgroundColor: AppTheme.accentGreen,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // İngilizce cümle - kelime vurgulu
            _buildHighlightedSentence(sentence.englishSentence, sentence.word),
            const SizedBox(height: 8),
            Text(
              sentence.turkishTranslation,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            // Kelime anlamı bölümü - gizli/açık
            if (sentence.word != null) ...[
              const SizedBox(height: 12),
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
              if (_showDefinitionMap[sentence.id] ?? false) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceVariant.withOpacity(0.5),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sentence.word!,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sentence.wordTranslation ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHighlightedSentence(String sentence, String? word) {
    if (word == null || word.isEmpty) {
      return Text(
        sentence,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      );
    }

    // Kelimeyi cümlede bul ve vurgula (tam kelime eşleşmesi)
    final lowerSentence = sentence.toLowerCase();
    final lowerWord = word.toLowerCase().trim();
    
    // Regex ile kelime eşleşmesi bul (ek almış hallerini de kapsa - suffix)
    final regex = RegExp(r'\b' + RegExp.escape(lowerWord) + r'\w*\b', caseSensitive: false);
    final matches = regex.allMatches(lowerSentence);

    if (matches.isEmpty) {
      // Kelime bulunamadıysa normal göster
      return Text(
        sentence,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
        ),
      );
    }

    // Tüm eşleşmeleri vurgula - WidgetSpan kullanarak gradient arka plan ekle
    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Eşleşmeden önceki kısım
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: sentence.substring(lastIndex, match.start)));
      }
      
      // Vurgulanan kelime - gradient arka planlı kutu içinde
      final wordStart = match.start;
      final wordEnd = match.end;
      final wordText = sentence.substring(wordStart, wordEnd);
      
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF6B46C1),
                  Color(0xFF8B5CF6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryPurple.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              wordText,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
      
      lastIndex = match.end;
    }

    // Kalan kısmı ekle
    if (lastIndex < sentence.length) {
      spans.add(TextSpan(text: sentence.substring(lastIndex)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimary,
          height: 1.5,
        ),
        children: spans,
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
        return AppTheme.accentRed;
      default:
        return AppTheme.gray600;
    }
  }

  void _showAddSentenceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _AddSentenceDialog(
        provider: Provider.of<SentenceProvider>(context, listen: false),
      ),
    );
  }
}

/// Stateful dialog for adding sentences with grammar checking
class _AddSentenceDialog extends StatefulWidget {
  final SentenceProvider provider;

  const _AddSentenceDialog({required this.provider});

  @override
  State<_AddSentenceDialog> createState() => _AddSentenceDialogState();
}

class _AddSentenceDialogState extends State<_AddSentenceDialog> {
  final TextEditingController _englishController = TextEditingController();
  final TextEditingController _turkishController = TextEditingController();
  String _difficulty = 'easy';
  
  // Grammar checking state
  GrammarCheckResult? _grammarResult;
  bool _isCheckingGrammar = false;
  final GrammarDebouncer _debouncer = GrammarDebouncer(milliseconds: 1000);

  @override
  void initState() {
    super.initState();
    // Listen to English text changes for grammar checking
    _englishController.addListener(_onEnglishTextChanged);
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _englishController.dispose();
    _turkishController.dispose();
    super.dispose();
  }

  void _onEnglishTextChanged() {
    final text = _englishController.text.trim();
    
    if (text.isEmpty) {
      setState(() {
        _grammarResult = null;
        _isCheckingGrammar = false;
      });
      return;
    }

    // Show checking indicator
    setState(() {
      _isCheckingGrammar = true;
    });

    // Debounce the grammar check
    _debouncer.run(() async {
      final result = await GrammarService.checkGrammar(text);
      if (mounted) {
        setState(() {
          _grammarResult = result;
          _isCheckingGrammar = false;
        });
      }
    });
  }

  void _applySuggestion(GrammarError error, String suggestion) {
    final text = _englishController.text;
    final newText = text.substring(0, error.fromPos) +
        suggestion +
        text.substring(error.toPos);
    
    _englishController.text = newText;
    // Position cursor after the suggestion
    _englishController.selection = TextSelection.fromPosition(
      TextPosition(offset: error.fromPos + suggestion.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkSurface,
      title: const Text(
        'Yeni Cümle Ekle',
        style: TextStyle(color: AppTheme.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // English sentence field
            TextField(
              controller: _englishController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'İngilizce Cümle',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                helperText: 'Gramer kontrolü otomatik yapılacak',
                helperStyle: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 11,
                ),
              ),
              maxLines: 3,
              autofocus: true,
            ),
            
            // Grammar check indicator/results
            const SizedBox(height: 12),
            if (_isCheckingGrammar)
              const GrammarCheckingIndicator()
            else if (_grammarResult != null)
              if (_grammarResult!.hasErrors)
                GrammarCheckPanel(
                  result: _grammarResult!,
                  onApplySuggestion: _applySuggestion,
                )
              else if (_grammarResult!.message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.accentOrange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _grammarResult!.message!,
                          style: const TextStyle(color: AppTheme.accentOrange, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
                const GrammarCorrectIndicator(),
            
            const SizedBox(height: 16),
            
            // Turkish translation field
            TextField(
              controller: _turkishController,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Türkçe Çevirisi',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
              maxLines: 3,
            ),
            
            const SizedBox(height: 16),
            
            // Difficulty dropdown
            DropdownButtonFormField<String>(
              value: _difficulty,
              dropdownColor: AppTheme.darkSurfaceVariant,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Zorluk',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
              items: const [
                DropdownMenuItem(value: 'easy', child: Text('Kolay')),
                DropdownMenuItem(value: 'medium', child: Text('Orta')),
                DropdownMenuItem(value: 'hard', child: Text('Zor')),
              ],
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _englishController.text.isEmpty ||
                  _turkishController.text.isEmpty
              ? null
              : () async {
                  await widget.provider.addSentence(
                    englishSentence: _englishController.text,
                    turkishTranslation: _turkishController.text,
                    difficulty: _difficulty,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cümle eklendi!'),
                        backgroundColor: AppTheme.accentGreen,
                      ),
                    );
                  }
                },
          child: const Text('Ekle'),
        ),
      ],
    );
  }
}
