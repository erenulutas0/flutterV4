package com.ingilizce.calismaapp.service;

import com.ingilizce.calismaapp.entity.UserAchievement;
import com.ingilizce.calismaapp.entity.UserProgress;
import com.ingilizce.calismaapp.model.Achievement;
import com.ingilizce.calismaapp.repository.UserAchievementRepository;
import com.ingilizce.calismaapp.repository.UserProgressRepository;
import com.ingilizce.calismaapp.repository.WordRepository;
import com.ingilizce.calismaapp.repository.WordReviewRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class ProgressService {

    private static final Logger logger = LoggerFactory.getLogger(ProgressService.class);
    private static final Long DEFAULT_USER_ID = 1L;

    @Autowired
    private UserProgressRepository progressRepository;

    @Autowired
    private UserAchievementRepository achievementRepository;

    @Autowired
    private WordRepository wordRepository;

    @Autowired
    private WordReviewRepository reviewRepository;

    /**
     * Get or create user progress
     */
    public UserProgress getUserProgress() {
        return progressRepository.findByUserId(DEFAULT_USER_ID)
                .orElseGet(() -> {
                    UserProgress progress = new UserProgress();
                    progress.setUserId(DEFAULT_USER_ID);
                    return progressRepository.save(progress);
                });
    }

    /**
     * Award XP to user
     * 
     * @param xp     Amount of XP to award
     * @param reason Reason for XP (for logging)
     * @return List of newly unlocked achievements
     */
    @Transactional
    public List<Achievement> awardXp(int xp, String reason) {
        logger.info("Awarding {} XP for: {}", xp, reason);

        UserProgress progress = getUserProgress();
        boolean leveledUp = progress.addXp(xp);
        progressRepository.save(progress);

        if (leveledUp) {
            logger.info("User leveled up to level {}!", progress.getLevel());
        }

        // Check for new achievements
        return checkAndUnlockAchievements();
    }

    /**
     * Update streak (call this daily or on activity)
     */
    @Transactional
    public void updateStreak() {
        UserProgress progress = getUserProgress();
        LocalDate today = LocalDate.now();
        LocalDate lastActivity = progress.getLastActivityDate();

        if (lastActivity == null) {
            // First activity
            progress.setCurrentStreak(1);
            progress.setLongestStreak(1);
        } else if (lastActivity.equals(today)) {
            // Already counted today
            return;
        } else if (lastActivity.equals(today.minusDays(1))) {
            // Consecutive day
            int newStreak = progress.getCurrentStreak() + 1;
            progress.setCurrentStreak(newStreak);

            if (newStreak > progress.getLongestStreak()) {
                progress.setLongestStreak(newStreak);
            }
        } else {
            // Streak broken
            progress.setCurrentStreak(1);
        }

        progress.setLastActivityDate(today);
        progressRepository.save(progress);

        logger.info("Streak updated: current={}, longest={}",
                progress.getCurrentStreak(), progress.getLongestStreak());
    }

    /**
     * Check and unlock achievements
     * 
     * @return List of newly unlocked achievements
     */
    @Transactional
    public List<Achievement> checkAndUnlockAchievements() {
        List<Achievement> newlyUnlocked = new ArrayList<>();

        UserProgress progress = getUserProgress();
        long wordCount = wordRepository.count();
        long reviewCount = reviewRepository.count();
        int currentStreak = progress.getCurrentStreak();
        int level = progress.getLevel();

        // Word count achievements
        checkAchievement(Achievement.FIRST_WORD, wordCount >= 1, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_10, wordCount >= 10, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_25, wordCount >= 25, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_50, wordCount >= 50, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_100, wordCount >= 100, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_250, wordCount >= 250, newlyUnlocked);
        checkAchievement(Achievement.WORD_COLLECTOR_500, wordCount >= 500, newlyUnlocked);

        // Review achievements
        checkAchievement(Achievement.FIRST_REVIEW, reviewCount >= 1, newlyUnlocked);
        checkAchievement(Achievement.REVIEW_MASTER_10, reviewCount >= 10, newlyUnlocked);
        checkAchievement(Achievement.REVIEW_MASTER_50, reviewCount >= 50, newlyUnlocked);
        checkAchievement(Achievement.REVIEW_MASTER_100, reviewCount >= 100, newlyUnlocked);

        // Streak achievements
        checkAchievement(Achievement.STREAK_3, currentStreak >= 3, newlyUnlocked);
        checkAchievement(Achievement.STREAK_7, currentStreak >= 7, newlyUnlocked);
        checkAchievement(Achievement.STREAK_14, currentStreak >= 14, newlyUnlocked);
        checkAchievement(Achievement.STREAK_30, currentStreak >= 30, newlyUnlocked);
        checkAchievement(Achievement.STREAK_100, currentStreak >= 100, newlyUnlocked);

        // Level achievements
        checkAchievement(Achievement.LEVEL_5, level >= 5, newlyUnlocked);
        checkAchievement(Achievement.LEVEL_10, level >= 10, newlyUnlocked);
        checkAchievement(Achievement.LEVEL_20, level >= 20, newlyUnlocked);

        // Time-based achievements (check current time)
        LocalTime now = LocalTime.now();
        if (now.isBefore(LocalTime.of(8, 0))) {
            checkAchievement(Achievement.EARLY_BIRD, true, newlyUnlocked);
        }
        if (now.isAfter(LocalTime.of(23, 0))) {
            checkAchievement(Achievement.NIGHT_OWL, true, newlyUnlocked);
        }

        // Award XP for newly unlocked achievements
        for (Achievement achievement : newlyUnlocked) {
            progress.addXp(achievement.getXpReward());
            logger.info("Achievement unlocked: {} (+{} XP)",
                    achievement.getTitle(), achievement.getXpReward());
        }

        if (!newlyUnlocked.isEmpty()) {
            progressRepository.save(progress);
        }

        return newlyUnlocked;
    }

    /**
     * Helper method to check and unlock a single achievement
     */
    private void checkAchievement(Achievement achievement, boolean condition, List<Achievement> newlyUnlocked) {
        if (condition && !isAchievementUnlocked(achievement)) {
            unlockAchievement(achievement);
            newlyUnlocked.add(achievement);
        }
    }

    /**
     * Check if achievement is already unlocked
     */
    public boolean isAchievementUnlocked(Achievement achievement) {
        return achievementRepository.existsByUserIdAndAchievementCode(
                DEFAULT_USER_ID, achievement.getCode());
    }

    /**
     * Unlock an achievement
     */
    @Transactional
    public void unlockAchievement(Achievement achievement) {
        if (!isAchievementUnlocked(achievement)) {
            UserAchievement userAchievement = new UserAchievement(
                    DEFAULT_USER_ID, achievement.getCode());
            achievementRepository.save(userAchievement);
            logger.info("Unlocked achievement: {}", achievement.getCode());
        }
    }

    /**
     * Get all unlocked achievements
     */
    public List<Map<String, Object>> getUnlockedAchievements() {
        List<UserAchievement> userAchievements = achievementRepository.findByUserId(DEFAULT_USER_ID);
        List<Map<String, Object>> result = new ArrayList<>();

        for (UserAchievement ua : userAchievements) {
            Achievement achievement = Achievement.fromCode(ua.getAchievementCode());
            if (achievement != null) {
                Map<String, Object> map = new HashMap<>();
                map.put("code", achievement.getCode());
                map.put("title", achievement.getTitle());
                map.put("description", achievement.getDescription());
                map.put("xpReward", achievement.getXpReward());
                map.put("icon", achievement.getIcon());
                map.put("unlockedAt", ua.getUnlockedAt());
                result.add(map);
            }
        }

        return result;
    }

    /**
     * Get all achievements (locked and unlocked)
     */
    public List<Map<String, Object>> getAllAchievements() {
        List<Map<String, Object>> result = new ArrayList<>();

        for (Achievement achievement : Achievement.values()) {
            Map<String, Object> map = new HashMap<>();
            map.put("code", achievement.getCode());
            map.put("title", achievement.getTitle());
            map.put("description", achievement.getDescription());
            map.put("xpReward", achievement.getXpReward());
            map.put("icon", achievement.getIcon());
            map.put("unlocked", isAchievementUnlocked(achievement));
            result.add(map);
        }

        return result;
    }

    /**
     * Get progress stats
     */
    public Map<String, Object> getStats() {
        UserProgress progress = getUserProgress();

        Map<String, Object> stats = new HashMap<>();
        stats.put("totalXp", progress.getTotalXp());
        stats.put("level", progress.getLevel());
        stats.put("currentStreak", progress.getCurrentStreak());
        stats.put("longestStreak", progress.getLongestStreak());
        stats.put("xpForNextLevel", progress.getXpForNextLevel());
        stats.put("levelProgress", progress.getLevelProgress());
        stats.put("lastActivityDate", progress.getLastActivityDate());

        // Achievement count
        long unlockedCount = achievementRepository.findByUserId(DEFAULT_USER_ID).size();
        long totalCount = Achievement.values().length;
        stats.put("achievementsUnlocked", unlockedCount);
        stats.put("achievementsTotal", totalCount);

        return stats;
    }
}
