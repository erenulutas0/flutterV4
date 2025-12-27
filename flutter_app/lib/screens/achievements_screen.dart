import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  List<AchievementModel> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final achievements = await ProgressService.getAllAchievements();
    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Unlocked count
    final unlockedCount = _achievements.where((a) => a.unlocked).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Başarımlar'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppTheme.darkGradient,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header Stats
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$unlockedCount / ${_achievements.length}',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryPurple,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Unlocked',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _achievements.length,
                      itemBuilder: (context, index) {
                        final achievement = _achievements[index];
                        return _buildAchievementCard(achievement);
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAchievementCard(AchievementModel achievement) {
    final isUnlocked = achievement.unlocked;

    return GestureDetector(
      onTap: () => _showAchievementDetails(achievement),
      child: Container(
        decoration: BoxDecoration(
          color: isUnlocked 
              ? AppTheme.darkSurfaceVariant 
              : AppTheme.darkSurface.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: isUnlocked
              ? Border.all(color: AppTheme.primaryPurple.withOpacity(0.5), width: 1)
              : Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          boxShadow: isUnlocked
              ? [
                  BoxShadow(
                    color: AppTheme.primaryPurple.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isUnlocked
                    ? AppTheme.primaryPurple.withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
              ),
              child: Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: 32,
                  color: isUnlocked ? null : Colors.white.withOpacity(0.2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            
            // XP Reward
            if (!isUnlocked)
              Text(
                '${achievement.xpReward} XP',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 12,
                ),
              ),
            
            if (isUnlocked && achievement.unlockedAt != null)
              Text(
                DateFormat('dd MMM').format(achievement.unlockedAt!),
                style: const TextStyle(
                  color: AppTheme.primaryPurple,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAchievementDetails(AchievementModel achievement) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                achievement.icon,
                style: const TextStyle(fontSize: 64),
              ),
              const SizedBox(height: 16),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                achievement.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryPurple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+${achievement.xpReward} XP',
                  style: const TextStyle(
                    color: AppTheme.primaryPurple,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (achievement.unlocked && achievement.unlockedAt != null)
                Text(
                  'Kazanıldı: ${DateFormat('dd MMMM yyyy').format(achievement.unlockedAt!)}',
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
