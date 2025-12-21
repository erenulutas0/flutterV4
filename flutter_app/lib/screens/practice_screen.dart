import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/word_provider.dart';
import '../models/word.dart';
import '../theme/app_theme.dart';
import '../utils/backend_config.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final TextEditingController _wordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final Map<int, TextEditingController> _translationControllers = {};
  
  Word? _selectedWord;
  List<String> _generatedSentences = [];
  List<String> _aiTranslations = []; // Store AI translations separately
  List<TranslationResult> _translationResults = [];
  bool _isGenerating = false;
  bool _isSaving = false;
  String _selectedMode = 'select'; // 'select' or 'manual'
  String _searchQuery = '';
  Set<String> _selectedLevels = {'B1'}; // A1, A2, B1, B2, C1, C2
  Set<String> _selectedLengths = {'medium'}; // short, medium, long

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WordProvider>(context, listen: false);
      provider.loadAllWords();
    });
  }

  @override
  void dispose() {
    _wordController.dispose();
    _searchController.dispose();
    for (var controller in _translationControllers.values) {
      controller.dispose();
    }
    _translationControllers.clear();
    super.dispose();
  }

  Future<void> _generateSentences() async {
    if (_selectedWord == null && _wordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir kelime seçin veya yazın'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _generatedSentences = [];
      _aiTranslations = [];
      _translationResults = [];
    });

    try {
      final word = _selectedWord?.englishWord ?? _wordController.text.trim();
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/generate-sentences'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': word,
          'levels': _selectedLevels.toList(),
          'lengths': _selectedLengths.toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final sentences = (data['sentences'] as List)
            .map((s) => s.toString())
            .toList();
        
        // Get translations from backend (if available)
        List<String> translations = [];
        if (data['translations'] != null) {
          translations = (data['translations'] as List)
              .map((t) => t.toString())
              .toList();
        }
        
        setState(() {
          // Dispose old controllers
          for (var controller in _translationControllers.values) {
            controller.dispose();
          }
          _translationControllers.clear();
          
          _generatedSentences = sentences;
          _aiTranslations = translations; // Store AI translations but don't auto-fill
          _translationResults = List.generate(
            sentences.length,
            (index) {
              final controller = TextEditingController(); // Empty by default
              _translationControllers[index] = controller;
              return TranslationResult(
                sentence: sentences[index],
                userTranslation: '', // Empty by default
                isCorrect: null,
                feedback: '',
                correctTranslation: '',
                isChecking: false,
              );
            },
          );
        });
      } else {
        throw Exception('Failed to generate sentences');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveToToday() async {
    if (_generatedSentences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Önce cümle üretin'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    final word = _selectedWord?.englishWord ?? _wordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kelime bulunamadı'),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // No need to extract meanings from sentences anymore (they don't contain Turkish translations)
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/save-to-today'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'englishWord': word,
          'meanings': [], // Empty since sentences no longer contain Turkish translations
          'sentences': _generatedSentences,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Reload words
          final provider = Provider.of<WordProvider>(context, listen: false);
          provider.loadAllWords();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kelime ve cümleler bugünkü tarihe başarıyla eklendi!'),
                backgroundColor: AppTheme.accentGreen,
              ),
            );
          }
        } else {
          throw Exception(data['error'] ?? 'Kayıt başarısız');
        }
      } else {
        throw Exception('Failed to save: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _checkTranslation(int index, String userTranslation) async {
    if (userTranslation.trim().isEmpty) {
      return;
    }

    setState(() {
      _translationResults[index].isChecking = true;
      _translationResults[index].userTranslation = userTranslation;
    });

    try {
      final response = await http.post(
        Uri.parse('${BackendConfig.apiBaseUrl}/chatbot/check-translation'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'englishSentence': _generatedSentences[index],
          'userTranslation': userTranslation,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _translationResults[index].isCorrect = data['isCorrect'] as bool;
          _translationResults[index].feedback = data['feedback'] ?? '';
          _translationResults[index].correctTranslation = data['correctTranslation'] ?? '';
          _translationResults[index].isChecking = false;
        });
      } else {
        throw Exception('Failed to check translation');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: AppTheme.accentRed,
          ),
        );
        setState(() {
          _translationResults[index].isChecking = false;
        });
      }
    }
  }

  List<Word> get _filteredWords {
    final provider = Provider.of<WordProvider>(context);
    if (_searchQuery.isEmpty) {
      return provider.words;
    }
    return provider.words.where((word) {
      return word.englishWord.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          word.turkishMeaning.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pratik'),
        backgroundColor: AppTheme.darkSurface,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mode Selection
              Card(
                color: AppTheme.darkSurface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Kelimelerimden Seç'),
                          selected: _selectedMode == 'select',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedMode = 'select';
                                _selectedWord = null;
                                _wordController.clear();
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Manuel Giriş'),
                          selected: _selectedMode == 'manual',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedMode = 'manual';
                                _selectedWord = null;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Owen AI Info Card
              Card(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppTheme.purpleGradient,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.smart_toy, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Owen ile Pratik',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'AI ile cümle üret ve çevirini kontrol et',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Level and Length Selection
              Card(
                color: AppTheme.darkSurface,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seviye ve Uzunluk',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Level Selection
                      Text(
                        'Seviye:',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'].map((level) {
                          final isSelected = _selectedLevels.contains(level);
                          return ChoiceChip(
                            label: Text(level),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedLevels.add(level);
                                } else {
                                  _selectedLevels.remove(level);
                                  // En az bir seviye seçili olmalı
                                  if (_selectedLevels.isEmpty) {
                                    _selectedLevels.add('B1');
                                  }
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryPurple,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Length Selection
                      Text(
                        'Uzunluk:',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          {'value': 'short', 'label': 'Kısa (5-8 kelime)'},
                          {'value': 'medium', 'label': 'Orta (9-15 kelime)'},
                          {'value': 'long', 'label': 'Uzun (16+ kelime)'},
                        ].map((item) {
                          final isSelected = _selectedLengths.contains(item['value']);
                          return ChoiceChip(
                            label: Text(item['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedLengths.add(item['value']!);
                                } else {
                                  _selectedLengths.remove(item['value']);
                                  // En az bir uzunluk seçili olmalı
                                  if (_selectedLengths.isEmpty) {
                                    _selectedLengths.add('medium');
                                  }
                                }
                              });
                            },
                            selectedColor: AppTheme.primaryPurple,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textPrimary,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Word Selection or Manual Input
              if (_selectedMode == 'select') ...[
                // Search Bar
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Kelime Ara',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkSurfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                // Word List
                Consumer<WordProvider>(
                  builder: (context, wordProvider, _) {
                    if (wordProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final words = _filteredWords;
                    if (words.isEmpty) {
                      return Card(
                        color: AppTheme.darkSurface,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Kelime bulunamadı',
                            style: TextStyle(color: AppTheme.textSecondary),
                          ),
                        ),
                      );
                    }

                    return Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppTheme.darkSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        itemCount: words.length,
                        itemBuilder: (context, index) {
                          final word = words[index];
                          final isSelected = _selectedWord?.id == word.id;
                          return ListTile(
                            title: Text(
                              word.englishWord,
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text(
                              word.turkishMeaning,
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            selected: isSelected,
                            selectedTileColor: AppTheme.primaryPurple.withOpacity(0.2),
                            onTap: () {
                              setState(() {
                                _selectedWord = word;
                                _wordController.text = word.englishWord;
                              });
                            },
                            trailing: isSelected
                                ? const Icon(Icons.check_circle, color: AppTheme.primaryPurple)
                                : null,
                          );
                        },
                      ),
                    );
                  },
                ),
              ] else ...[
                // Manual Input
                TextField(
                  controller: _wordController,
                  style: const TextStyle(color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Kelime Girin',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.darkSurfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Generate Button
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateSentences,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.textPrimary,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(_isGenerating ? 'Owen cümle üretiyor...' : 'Owen ile Cümle Üret'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: AppTheme.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Generated Sentences
              if (_generatedSentences.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Cümleler (${_generatedSentences.length})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveToToday,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.textPrimary,
                              ),
                            )
                          : const Icon(Icons.add_circle),
                      label: Text(_isSaving ? 'Kaydediliyor...' : 'Bugün\'e Ekle'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        foregroundColor: AppTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...List.generate(_generatedSentences.length, (index) {
                  final result = _translationResults[index];
                  return _buildSentenceCard(index, result);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSentenceCard(int index, TranslationResult result) {
    final isCorrect = result.isCorrect;
    Color borderColor = AppTheme.gray700;
    Color backgroundColor = AppTheme.darkSurface;

    if (isCorrect == true) {
      borderColor = AppTheme.accentGreen;
      backgroundColor = AppTheme.accentGreen.withOpacity(0.1);
    } else if (isCorrect == false) {
      borderColor = AppTheme.accentRed;
      backgroundColor = AppTheme.accentRed.withOpacity(0.1);
    }

    return Card(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // English Sentence with Translate Button
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${index + 1}. ${result.sentence}',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Translate Button
                if (index < _aiTranslations.length && _aiTranslations[index].isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _translationControllers[index]?.text = _aiTranslations[index];
                        result.userTranslation = _aiTranslations[index];
                        // Reset result when AI translation is loaded
                        if (result.isCorrect != null) {
                          result.isCorrect = null;
                          result.feedback = '';
                          result.correctTranslation = '';
                          result.isChecking = false;
                        }
                      });
                    },
                    icon: const Icon(Icons.translate, size: 18),
                    label: const Text('Çevir'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
                if (isCorrect == true)
                  const Icon(Icons.check_circle, color: AppTheme.accentGreen)
                else if (isCorrect == false)
                  const Icon(Icons.cancel, color: AppTheme.accentRed),
              ],
            ),
            const SizedBox(height: 16),

            // Translation Input
            TextField(
              controller: _translationControllers[index],
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                labelText: 'Türkçe Çevirisi',
                labelStyle: const TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.darkSurfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _translationControllers[index]?.text.isNotEmpty == true && result.isCorrect == null
                    ? result.isChecking == true
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                          )
                        : IconButton(
                        icon: const Icon(Icons.check),
                        onPressed: () => _checkTranslation(index, _translationControllers[index]!.text),
                        color: AppTheme.primaryPurple,
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  result.userTranslation = value;
                  // Reset result when user changes translation
                  if (result.isCorrect != null) {
                    result.isCorrect = null;
                    result.feedback = '';
                    result.correctTranslation = '';
                    result.isChecking = false;
                  }
                });
              },
              onSubmitted: (value) {
                if (value.trim().isNotEmpty && result.isChecking != true) {
                  _checkTranslation(index, value);
                }
              },
              enabled: result.isChecking != true,
            ),

            // Feedback
            if (isCorrect != null) ...[
              const SizedBox(height: 12),
              if (isCorrect == false && result.correctTranslation.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doğru Çeviri:',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        result.correctTranslation,
                        style: const TextStyle(
                          color: AppTheme.accentGreen,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (result.feedback.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    result.feedback,
                    style: TextStyle(
                      color: isCorrect == true
                          ? AppTheme.accentGreen
                          : AppTheme.accentRed,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class TranslationResult {
  String sentence;
  String userTranslation;
  bool? isCorrect;
  String feedback;
  String correctTranslation;
  bool isChecking;

  TranslationResult({
    required this.sentence,
    required this.userTranslation,
    this.isCorrect,
    required this.feedback,
    this.correctTranslation = '',
    this.isChecking = false,
  });
}

