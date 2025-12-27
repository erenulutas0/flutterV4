import 'package:flutter/material.dart';
import 'words_screen.dart';
import 'sentences_screen.dart';
import 'practice_screen.dart';
import 'chat_screen.dart';
import 'matchmaking_screen.dart';
import 'review_screen.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/srs_service.dart';
import '../services/progress_service.dart';
import '../services/offline_storage_service.dart';
import '../widgets/progress_widget.dart';
import '../screens/achievements_screen.dart';
import '../screens/stats_screen.dart';
import '../models/word.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomePage(),
    const WordsScreen(),
    const SentencesScreen(),
    const PracticeScreen(),
    const ChatScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Ana Sayfa',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Kelimeler',
          ),
          NavigationDestination(
            icon: Icon(Icons.text_fields_outlined),
            selectedIcon: Icon(Icons.text_fields),
            label: 'Cümleler',
          ),
          NavigationDestination(
            icon: Icon(Icons.school_outlined),
            selectedIcon: Icon(Icons.school),
            label: 'Pratik',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Konuş',
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ApiService _apiService = ApiService();
  List<Word> _allWords = [];
  List<Word> _recentWords = [];
  int _todayWordsCount = 0;
  int _totalWordsCount = 0;
  int _streakDays = 0;
  int _xp = 0;
  bool _isLoading = true;
  
  // SRS State
  int _reviewWordsCount = 0;
  
  // Progress State
  ProgressStats? _progressStats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<Word> allWords = [];
      List<Word> todayWords = [];
      bool isOnline = false;
      
      // İnternet kontrolü
      try {
        allWords = await _apiService.getAllWords();
        isOnline = true;
        
        // Online: Cache'e kaydet
        await OfflineStorageService.cacheWords(
          allWords.map((w) => w.toJson()).toList()
        );
      } catch (e) {
        print('API failed, using cache: $e');
        // Offline: Cache'den yükle
        final cachedWords = await OfflineStorageService.getCachedWords();
        allWords = cachedWords.map((json) => Word.fromJson(json)).toList();
      }
      
      // Bugün öğrenilen kelimeleri filtrele
      final today = DateTime.now();
      if (isOnline) {
        try {
          todayWords = await _apiService.getWordsByDate(today);
        } catch (e) {
          todayWords = allWords.where((w) => 
            w.learnedDate.year == today.year &&
            w.learnedDate.month == today.month &&
            w.learnedDate.day == today.day
          ).toList();
        }
      } else {
        // Cache'den filtrele
        todayWords = allWords.where((w) => 
          w.learnedDate.year == today.year &&
          w.learnedDate.month == today.month &&
          w.learnedDate.day == today.day
        ).toList();
      }
      
      // Pending kelimeleri de ekle
      final pendingWords = await OfflineStorageService.getPendingWords();
      for (var wordMap in pendingWords) {
        allWords.add(Word(
          id: wordMap['tempId'].hashCode,
          englishWord: wordMap['englishWord'],
          turkishMeaning: wordMap['turkishMeaning'],
          learnedDate: DateTime.parse(wordMap['learnedDate']),
          difficulty: wordMap['difficulty'] ?? 'easy',
          notes: wordMap['notes'],
          sentences: [],
        ));
        
        // Bugün eklenen pending kelimeler
        final wDate = DateTime.parse(wordMap['learnedDate']);
        if (wDate.year == today.year && wDate.month == today.month && wDate.day == today.day) {
          todayWords.add(Word(
            id: wordMap['tempId'].hashCode,
            englishWord: wordMap['englishWord'],
            turkishMeaning: wordMap['turkishMeaning'],
            learnedDate: wDate,
            difficulty: wordMap['difficulty'] ?? 'easy',
            notes: wordMap['notes'],
            sentences: [],
          ));
        }
      }
      
      // Son öğrenilen kelimeleri sırala (en yeni önce)
      final recentWords = List<Word>.from(allWords)
        ..sort((a, b) => b.learnedDate.compareTo(a.learnedDate));
      
      // Streak hesapla (ardışık günler)
      final streak = _calculateStreak(allWords);
      
      // XP hesapla (her kelime 5 XP)
      final xp = allWords.length * 5;
      
      // SRS: Review kelimelerini al (offline'da 0)
      int reviewCount = 0;
      ProgressStats? progressStats;
      try {
        final srsStats = await SRSService.getStats();
        reviewCount = srsStats?.dueToday ?? 0;
        progressStats = await ProgressService.getStats();
      } catch (e) {
        print('SRS/Progress failed: $e');
      }
      
      // İstatistikleri cache'e kaydet (online veya offline)
      await OfflineStorageService.cacheHomeStats(
        totalWords: allWords.length,
        todayWords: todayWords.length,
        streakDays: streak,
        xp: xp,
      );

      setState(() {
        _allWords = allWords;
        _recentWords = recentWords.take(4).toList();
        _todayWordsCount = todayWords.length;
        _totalWordsCount = allWords.length;
        _streakDays = streak;
        _xp = xp;
        _progressStats = progressStats;
        _reviewWordsCount = reviewCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading home data: $e');
      
      // Hata durumunda cache'den istatistikleri yükle
      final cachedStats = await OfflineStorageService.getCachedHomeStats();
      if (cachedStats != null) {
        setState(() {
          _totalWordsCount = cachedStats['totalWords'] ?? 0;
          _todayWordsCount = cachedStats['todayWords'] ?? 0;
          _streakDays = cachedStats['streakDays'] ?? 0;
          _xp = cachedStats['xp'] ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _calculateStreak(List<Word> words) {
    if (words.isEmpty) return 0;
    
    // Tarihleri sırala (en yeni önce) ve unique yap
    final dates = words.map((w) => DateTime(
      w.learnedDate.year,
      w.learnedDate.month,
      w.learnedDate.day,
    )).toSet().toList()..sort((a, b) => b.compareTo(a));
    
    if (dates.isEmpty) return 0;
    
    // Bugünün tarihini al
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    // Streak hesapla - bugünden geriye doğru ardışık günleri say
    int streak = 0;
    DateTime currentDate = todayDate;
    
    // Bugün veya dün kelime öğrenilmiş mi kontrol et
    bool hasTodayOrYesterday = dates.contains(todayDate) || 
                                dates.contains(todayDate.subtract(const Duration(days: 1)));
    
    if (!hasTodayOrYesterday) {
      return 0; // Bugün ve dün öğrenilmemişse streak yok
    }
    
    // Bugünden geriye doğru ardışık günleri say
    for (int i = 0; i < dates.length; i++) {
      final expectedDate = todayDate.subtract(Duration(days: streak));
      final dateToCheck = DateTime(
        expectedDate.year,
        expectedDate.month,
        expectedDate.day,
      );
      
      if (dates.any((d) => d.year == dateToCheck.year && 
                         d.month == dateToCheck.month && 
                         d.day == dateToCheck.day)) {
        streak++;
      } else {
        break;
      }
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.darkGradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Scrollable top section
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                const SizedBox(height: 20),
                // Minimalist Header - Logo ve Başlık
                Row(
                  children: [
                    // Modern Icon - Book + Spark combination (kutusuz)
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [
                          Color(0xFF8B5CF6),
                          Color(0xFF6B46C1),
                          Color(0xFF9333EA),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // VocabMaster Text
                    Text(
                      'VocabMaster',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                        letterSpacing: -1,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Daily Progress Card
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF6B46C1),
                        Color(0xFF1A1F2E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryPurple.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Merhaba! 👋',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Günlük Hedef',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            Text(
                              _isLoading 
                                ? 'Yükleniyor...' 
                                : '$_todayWordsCount / 10 kelime',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _isLoading ? 0.0 : (_todayWordsCount / 10).clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: AppTheme.darkSurfaceVariant,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Progress Widget (XP, Level, Streak)
                if (_progressStats != null)
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AchievementsScreen(),
                        ),
                      );
                    },
                    child: ProgressWidget(stats: _progressStats!),
                  ),
                if (_progressStats != null)
                  const SizedBox(height: 24),
                // SRS Review Card
                // SRS Review Card
                if (_reviewWordsCount > 0) ...[
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF059669),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReviewScreen()),
                          ).then((_) => _loadData()); // Refresh after review
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.replay_circle_filled,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Tekrar Zamanı! 🎯',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$_reviewWordsCount kelime tekrar edilmeyi bekliyor',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Action Buttons - Hierarchical Layout
                Column(
                  children: [
                    // Main Button - Full Width
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const WordsScreen()),
                          );
                        },
                        icon: const Icon(Icons.book),
                        label: const Text(
                          'Öğrenmeye Başla',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryPurple,
                          foregroundColor: AppTheme.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Secondary Buttons - Side by Side
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PracticeScreen()),
                              );
                            },
                            icon: const Icon(Icons.school),
                            label: const Text('Pratik Yap'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const SentencesScreen()),
                              );
                            },
                            icon: const Icon(Icons.text_fields),
                            label: const Text('İncele'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Eşleşme Butonu
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const MatchmakingScreen()),
                          );
                        },
                        icon: const Icon(Icons.video_call),
                        label: const Text(
                          'Eşleşme Başlat',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentBlue,
                          side: const BorderSide(color: AppTheme.accentBlue, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Statistics Section
                // Statistics Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İstatistiklerim',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StatsScreen(),
                          ),
                        );
                      },
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: AppTheme.primaryPurple,
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                  children: [
                    _buildStatCard(
                      _isLoading ? '...' : '$_totalWordsCount',
                      'Toplam\nKelime',
                      AppTheme.accentBlue,
                    ),
                    _buildStatCard(
                      _isLoading ? '...' : '$_streakDays',
                      'Seri\nGün',
                      AppTheme.accentGreen,
                    ),
                    _buildStatCard(
                      _isLoading ? '...' : '$_xp',
                      'XP',
                      AppTheme.primaryPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Recent Words Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Son Öğrenilen Kelimeler',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const WordsScreen()),
                        );
                      },
                      child: Text(
                        'Tümünü Gör >',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryPurple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Recent Words List - Inside scroll
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: AppTheme.darkSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _recentWords.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Henüz kelime öğrenilmemiş',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.all(8),
                              itemCount: _recentWords.length,
                              itemBuilder: (context, index) {
                                final word = _recentWords[index];
                                return _buildRecentWordItem(
                                  word.englishWord,
                                  word.turkishMeaning,
                                );
                              },
                            ),
                ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentWordItem(String word, String translation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppTheme.darkSurfaceVariant,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          word,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          translation,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.volume_up,
            color: AppTheme.primaryPurple,
            size: 20,
          ),
          onPressed: () {
            // Audio playback functionality
          },
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Card(
      color: AppTheme.darkSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                ),
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
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 11,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      color: AppTheme.darkSurface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // İkon - Sol tarafta
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppTheme.purpleGradient,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.textPrimary, size: 20),
              ),
              const SizedBox(width: 16),
              // Başlık ve açıklama - Sağ tarafta
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
