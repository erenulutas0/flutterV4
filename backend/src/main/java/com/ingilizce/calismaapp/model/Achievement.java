package com.ingilizce.calismaapp.model;

/**
 * Achievement definitions for gamification
 * Each achievement has a code, title, description, and XP reward
 */
public enum Achievement {
    // Word Learning Achievements
    FIRST_WORD("FIRST_WORD", "İlk Kelime 🎯", "İlk kelimeni öğrendin!", 10),
    WORD_COLLECTOR_10("WORD_10", "Kelime Koleksiyoncusu 📚", "10 kelime öğrendin!", 50),
    WORD_COLLECTOR_25("WORD_25", "Kelime Meraklısı 📖", "25 kelime öğrendin!", 75),
    WORD_COLLECTOR_50("WORD_50", "Kelime Ustası 🎓", "50 kelime öğrendin!", 100),
    WORD_COLLECTOR_100("WORD_100", "Kelime Dehası 🧠", "100 kelime öğrendin!", 200),
    WORD_COLLECTOR_250("WORD_250", "Kelime Profesörü 👨‍🏫", "250 kelime öğrendin!", 500),
    WORD_COLLECTOR_500("WORD_500", "Kelime Efsanesi 🏆", "500 kelime öğrendin!", 1000),

    // Streak Achievements
    STREAK_3("STREAK_3", "3 Günlük Seri 🔥", "3 gün üst üste çalıştın!", 30),
    STREAK_7("STREAK_7", "Haftalık Seri 🌟", "7 gün üst üste çalıştın!", 70),
    STREAK_14("STREAK_14", "İki Haftalık Seri ⭐", "14 gün üst üste çalıştın!", 140),
    STREAK_30("STREAK_30", "Aylık Seri 💎", "30 gün üst üste çalıştın!", 300),
    STREAK_100("STREAK_100", "Yüzlük Seri 👑", "100 gün üst üste çalıştın!", 1000),

    // Review Achievements
    FIRST_REVIEW("FIRST_REVIEW", "İlk Tekrar ♻️", "İlk kelime tekrarını yaptın!", 10),
    REVIEW_MASTER_10("REVIEW_10", "Tekrar Ustası 🎯", "10 kelime tekrar ettin!", 30),
    REVIEW_MASTER_50("REVIEW_50", "Tekrar Şampiyonu 🏅", "50 kelime tekrar ettin!", 100),
    REVIEW_MASTER_100("REVIEW_100", "Tekrar Efsanesi 🌟", "100 kelime tekrar ettin!", 200),
    PERFECT_REVIEW("PERFECT_REVIEW", "Mükemmel Tekrar ✨", "Bir oturumda tüm kelimeleri 'Kolay' ile geçtin!", 50),

    // Time-based Achievements
    EARLY_BIRD("EARLY_BIRD", "Erken Kuş 🌅", "Sabah 8'den önce çalıştın!", 20),
    NIGHT_OWL("NIGHT_OWL", "Gece Kuşu 🦉", "Gece 11'den sonra çalıştın!", 20),
    WEEKEND_WARRIOR("WEEKEND_WARRIOR", "Hafta Sonu Savaşçısı 💪", "Hafta sonu çalıştın!", 25),

    // Special Achievements
    SPEED_LEARNER("SPEED_LEARNER", "Hızlı Öğrenen ⚡", "Bir günde 10 kelime öğrendin!", 50),
    DEDICATED_LEARNER("DEDICATED_LEARNER", "Azimli Öğrenci 🎖️", "Bir günde 5 review yaptın!", 40),
    LEVEL_5("LEVEL_5", "Seviye 5 🌟", "5. seviyeye ulaştın!", 100),
    LEVEL_10("LEVEL_10", "Seviye 10 💫", "10. seviyeye ulaştın!", 250),
    LEVEL_20("LEVEL_20", "Seviye 20 ✨", "20. seviyeye ulaştın!", 500);

    private final String code;
    private final String title;
    private final String description;
    private final int xpReward;

    Achievement(String code, String title, String description, int xpReward) {
        this.code = code;
        this.title = title;
        this.description = description;
        this.xpReward = xpReward;
    }

    public String getCode() {
        return code;
    }

    public String getTitle() {
        return title;
    }

    public String getDescription() {
        return description;
    }

    public int getXpReward() {
        return xpReward;
    }

    /**
     * Get achievement by code
     */
    public static Achievement fromCode(String code) {
        for (Achievement achievement : values()) {
            if (achievement.code.equals(code)) {
                return achievement;
            }
        }
        return null;
    }

    /**
     * Get achievement icon (emoji)
     */
    public String getIcon() {
        // Extract emoji from title
        String[] parts = title.split(" ");
        if (parts.length > 0) {
            String lastPart = parts[parts.length - 1];
            // Check if it's an emoji (simple check)
            if (lastPart.length() <= 2 && !lastPart.matches("[a-zA-Z0-9]+")) {
                return lastPart;
            }
        }
        return "🏆"; // Default icon
    }
}
