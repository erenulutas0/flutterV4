import 'package:flutter/material.dart';
import '../models/word.dart';
import '../services/srs_service.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({Key? key}) : super(key: key);

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  List<Word> reviewWords = [];
  int currentIndex = 0;
  bool isLoading = true;
  bool showAnswer = false;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadReviewWords();
  }

  Future<void> _loadReviewWords() async {
    setState(() => isLoading = true);
    
    final words = await SRSService.getReviewWords();
    
    setState(() {
      reviewWords = words;
      isLoading = false;
    });
  }

  void _flipCard() {
    setState(() {
      showAnswer = !showAnswer;
    });
  }

  Future<void> _submitQuality(int quality) async {
    if (isSubmitting || currentIndex >= reviewWords.length) return;

    setState(() => isSubmitting = true);

    final currentWord = reviewWords[currentIndex];
    await SRSService.submitReview(currentWord.id!, quality);

    setState(() {
      isSubmitting = false;
      showAnswer = false;
      
      if (currentIndex < reviewWords.length - 1) {
        currentIndex++;
      } else {
        // Review tamamlandı
        _showCompletionDialog();
      }
    });
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.celebration, color: Colors.amber, size: 32),
            SizedBox(width: 12),
            Text('Tebrikler!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bugünün tekrarlarını tamamladınız! 🎉',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Text(
              '${reviewWords.length} kelime tekrar edildi',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dialog'u kapat
              Navigator.of(context).pop(); // Review screen'i kapat
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kelime Tekrarı'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (reviewWords.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Kelime Tekrarı'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 24),
              const Text(
                'Bugün tekrar edilecek kelime yok!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Harika iş çıkarıyorsunuz! 🎉',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ana Sayfaya Dön'),
              ),
            ],
          ),
        ),
      );
    }

    final currentWord = reviewWords[currentIndex];
    final progress = (currentIndex + 1) / reviewWords.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Tekrar (${currentIndex + 1}/${reviewWords.length})'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: _flipCard,
                child: Card(
                  margin: const EdgeInsets.all(24),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          showAnswer ? Icons.translate : Icons.abc,
                          size: 48,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          showAnswer
                              ? currentWord.turkishMeaning
                              : currentWord.englishWord,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          showAnswer ? 'Türkçe Anlamı' : 'İngilizce Kelime',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (!showAnswer) ...[
                          const SizedBox(height: 32),
                          const Text(
                            'Kartı çevirmek için dokunun',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (showAnswer) _buildQualityButtons(),
        ],
      ),
    );
  }

  Widget _buildQualityButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ne kadar iyi hatırladınız?',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QualityButton(
                  label: 'Hiç\nBilmedim',
                  quality: 0,
                  color: Colors.red,
                  onPressed: () => _submitQuality(0),
                  isSubmitting: isSubmitting,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  label: 'Zor',
                  quality: 2,
                  color: Colors.orange,
                  onPressed: () => _submitQuality(2),
                  isSubmitting: isSubmitting,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  label: 'İyi',
                  quality: 4,
                  color: Colors.lightGreen,
                  onPressed: () => _submitQuality(4),
                  isSubmitting: isSubmitting,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QualityButton(
                  label: 'Kolay',
                  quality: 5,
                  color: Colors.green,
                  onPressed: () => _submitQuality(5),
                  isSubmitting: isSubmitting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QualityButton extends StatelessWidget {
  final String label;
  final int quality;
  final Color color;
  final VoidCallback onPressed;
  final bool isSubmitting;

  const _QualityButton({
    required this.label,
    required this.quality,
    required this.color,
    required this.onPressed,
    required this.isSubmitting,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isSubmitting ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
