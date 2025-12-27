package com.ingilizce.calismaapp.service;

import com.ingilizce.calismaapp.entity.Word;
import com.ingilizce.calismaapp.repository.WordRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import org.springframework.transaction.annotation.Transactional;

/**
 * Spaced Repetition System (SRS) Service
 * Implements SuperMemo SM-2 algorithm for optimal learning intervals
 */
@Service
public class SRSService {

    private static final Logger logger = LoggerFactory.getLogger(SRSService.class);

    @Autowired
    private WordRepository wordRepository;

    @Autowired
    private ProgressService progressService;

    // SM-2 Algorithm Constants
    private static final double MIN_EASE_FACTOR = 1.3;
    private static final int INITIAL_INTERVAL = 1; // days
    private static final int SECOND_INTERVAL = 6; // days

    /**
     * Get all words that need review today or earlier
     * 
     * @return List of words to review
     */
    public List<Word> getWordsForReview() {
        LocalDate today = LocalDate.now();
        logger.info("Getting words for review (today: {})", today);

        // Find words where next_review_date <= today
        List<Word> reviewWords = wordRepository.findByNextReviewDateLessThanEqual(today);
        logger.info("Found {} words for review", reviewWords.size());

        return reviewWords;
    }

    /**
     * Submit a review result and calculate next review date
     * 
     * @param wordId  The word being reviewed
     * @param quality Quality of recall (0-5)
     *                0: Complete blackout
     *                1: Incorrect response, correct one remembered
     *                2: Incorrect response, correct one seemed easy to recall
     *                3: Correct response, but required significant difficulty
     *                4: Correct response, after some hesitation
     *                5: Perfect response
     * @return Updated word
     */
    @Transactional
    public Word submitReview(Long wordId, int quality) {
        if (quality < 0 || quality > 5) {
            throw new IllegalArgumentException("Quality must be between 0 and 5");
        }

        Word word = wordRepository.findById(wordId)
                .orElseThrow(() -> new RuntimeException("Word not found: " + wordId));

        logger.info("Submitting review for word '{}' with quality {}", word.getEnglishWord(), quality);

        // Initialize if first review
        if (word.getReviewCount() == null || word.getReviewCount() == 0) {
            initializeWordForSRS(word);
        }

        // Update review count
        int reviewCount = word.getReviewCount() + 1;
        word.setReviewCount(reviewCount);

        // Update last review date
        word.setLastReviewDate(LocalDate.now());

        // Calculate new ease factor using SM-2 algorithm
        double easeFactor = calculateEaseFactor(word.getEaseFactor(), quality);
        word.setEaseFactor(easeFactor);

        // Calculate next review interval
        int interval = calculateInterval(reviewCount, easeFactor, quality);

        // Set next review date
        LocalDate nextReviewDate = LocalDate.now().plusDays(interval);
        word.setNextReviewDate(nextReviewDate);

        logger.info("Updated word '{}': reviewCount={}, easeFactor={}, interval={} days, nextReview={}",
                word.getEnglishWord(), reviewCount, easeFactor, interval, nextReviewDate);

        Word savedWord = wordRepository.save(word);

        // Award XP based on quality
        int xpEarned = 0;
        switch (quality) {
            case 5:
                xpEarned = 5;
                break; // Easy
            case 4:
                xpEarned = 4;
                break; // Good
            case 3:
                xpEarned = 2;
                break; // Hard
            default:
                xpEarned = 1;
                break; // Again (Teselli puanı)
        }

        progressService.awardXp(xpEarned, "Review: " + word.getEnglishWord() + " (Quality: " + quality + ")");
        progressService.updateStreak(); // Update daily streak

        return savedWord;
    }

    /**
     * Calculate new ease factor using SM-2 algorithm
     * EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
     */
    private double calculateEaseFactor(Double currentEF, int quality) {
        double ef = (currentEF != null) ? currentEF : 2.5;

        // SM-2 formula
        ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));

        // Ensure EF doesn't go below minimum
        if (ef < MIN_EASE_FACTOR) {
            ef = MIN_EASE_FACTOR;
        }

        return Math.round(ef * 100.0) / 100.0; // Round to 2 decimal places
    }

    /**
     * Calculate interval until next review
     */
    private int calculateInterval(int reviewCount, double easeFactor, int quality) {
        // If quality < 3, reset to beginning
        if (quality < 3) {
            return INITIAL_INTERVAL;
        }

        // First review
        if (reviewCount == 1) {
            return INITIAL_INTERVAL;
        }

        // Second review
        if (reviewCount == 2) {
            return SECOND_INTERVAL;
        }

        // Subsequent reviews: multiply previous interval by ease factor
        // For simplicity, we'll use a formula: interval = 6 * (EF ^ (n-2))
        int interval = (int) Math.round(SECOND_INTERVAL * Math.pow(easeFactor, reviewCount - 2));

        return interval;
    }

    /**
     * Initialize SRS for a newly added word
     * 
     * @param word The new word
     */
    public void initializeWordForSRS(Word word) {
        if (word.getNextReviewDate() == null) {
            word.setNextReviewDate(LocalDate.now().plusDays(INITIAL_INTERVAL));
        }
        if (word.getReviewCount() == null) {
            word.setReviewCount(0);
        }
        if (word.getEaseFactor() == null) {
            word.setEaseFactor(2.5);
        }

        logger.info("Initialized SRS for word '{}': nextReview={}",
                word.getEnglishWord(), word.getNextReviewDate());
    }

    /**
     * Get SRS statistics
     * 
     * @return Map of statistics
     */
    public java.util.Map<String, Object> getStats() {
        java.util.Map<String, Object> stats = new java.util.HashMap<>();

        LocalDate today = LocalDate.now();

        // Words due today
        List<Word> dueToday = wordRepository.findByNextReviewDateLessThanEqual(today);
        stats.put("dueToday", dueToday.size());

        // Total words
        long totalWords = wordRepository.count();
        stats.put("totalWords", totalWords);

        // Words reviewed (review_count > 0)
        List<Word> reviewedWords = wordRepository.findByReviewCountGreaterThan(0);
        stats.put("reviewedWords", reviewedWords.size());

        logger.info("SRS Stats: dueToday={}, totalWords={}, reviewedWords={}",
                dueToday.size(), totalWords, reviewedWords.size());

        return stats;
    }
}
