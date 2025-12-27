package com.ingilizce.calismaapp.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "user_progress")
public class UserProgress {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id")
    private Long userId = 1L; // Default user for now

    @Column(name = "total_xp")
    private Integer totalXp = 0;

    @Column(name = "level")
    private Integer level = 1;

    @Column(name = "current_streak")
    private Integer currentStreak = 0;

    @Column(name = "longest_streak")
    private Integer longestStreak = 0;

    @Column(name = "last_activity_date")
    private LocalDate lastActivityDate;

    @Column(name = "created_at")
    private LocalDateTime createdAt;

    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    // Constructors
    public UserProgress() {
        this.createdAt = LocalDateTime.now();
        this.updatedAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public Integer getTotalXp() {
        return totalXp;
    }

    public void setTotalXp(Integer totalXp) {
        this.totalXp = totalXp;
        this.updatedAt = LocalDateTime.now();
    }

    public Integer getLevel() {
        return level;
    }

    public void setLevel(Integer level) {
        this.level = level;
        this.updatedAt = LocalDateTime.now();
    }

    public Integer getCurrentStreak() {
        return currentStreak;
    }

    public void setCurrentStreak(Integer currentStreak) {
        this.currentStreak = currentStreak;
        this.updatedAt = LocalDateTime.now();
    }

    public Integer getLongestStreak() {
        return longestStreak;
    }

    public void setLongestStreak(Integer longestStreak) {
        this.longestStreak = longestStreak;
        this.updatedAt = LocalDateTime.now();
    }

    public LocalDate getLastActivityDate() {
        return lastActivityDate;
    }

    public void setLastActivityDate(LocalDate lastActivityDate) {
        this.lastActivityDate = lastActivityDate;
        this.updatedAt = LocalDateTime.now();
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    /**
     * Add XP and check for level up
     * 
     * @param xp Amount of XP to add
     * @return true if leveled up
     */
    public boolean addXp(int xp) {
        int oldLevel = this.level;
        this.totalXp += xp;

        // Calculate new level based on XP
        int newLevel = calculateLevel(this.totalXp);
        this.level = newLevel;

        this.updatedAt = LocalDateTime.now();

        return newLevel > oldLevel;
    }

    /**
     * Calculate level from total XP
     * Level formula: Level increases every 100 XP initially, then scales
     */
    private int calculateLevel(int xp) {
        if (xp < 100)
            return 1;
        if (xp < 250)
            return 2;
        if (xp < 500)
            return 3;
        if (xp < 1000)
            return 4;
        if (xp < 2000)
            return 5;
        if (xp < 3500)
            return 6;
        if (xp < 5500)
            return 7;
        if (xp < 8000)
            return 8;
        if (xp < 11000)
            return 9;
        if (xp < 15000)
            return 10;

        // Beyond level 10: +5000 XP per level
        return 10 + ((xp - 15000) / 5000);
    }

    /**
     * Get XP required for next level
     */
    public int getXpForNextLevel() {
        int currentLevelXp = getXpForLevel(this.level);
        int nextLevelXp = getXpForLevel(this.level + 1);
        return nextLevelXp - currentLevelXp;
    }

    /**
     * Get XP progress towards next level (0.0 to 1.0)
     */
    public double getLevelProgress() {
        int currentLevelXp = getXpForLevel(this.level);
        int nextLevelXp = getXpForLevel(this.level + 1);
        int xpInCurrentLevel = this.totalXp - currentLevelXp;
        int xpNeededForLevel = nextLevelXp - currentLevelXp;

        return (double) xpInCurrentLevel / xpNeededForLevel;
    }

    /**
     * Get minimum XP required for a specific level
     */
    private int getXpForLevel(int level) {
        if (level <= 1)
            return 0;
        if (level == 2)
            return 100;
        if (level == 3)
            return 250;
        if (level == 4)
            return 500;
        if (level == 5)
            return 1000;
        if (level == 6)
            return 2000;
        if (level == 7)
            return 3500;
        if (level == 8)
            return 5500;
        if (level == 9)
            return 8000;
        if (level == 10)
            return 11000;
        if (level == 11)
            return 15000;

        // Beyond level 11: +5000 XP per level
        return 15000 + ((level - 11) * 5000);
    }
}
