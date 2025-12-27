-- Migration 002: Spaced Repetition System Fields
-- Description: Adds SRS-related fields to words and word_reviews tables

-- Add SRS fields to words table
ALTER TABLE words ADD COLUMN IF NOT EXISTS next_review_date DATE;
ALTER TABLE words ADD COLUMN IF NOT EXISTS review_count INT DEFAULT 0;
ALTER TABLE words ADD COLUMN IF NOT EXISTS ease_factor FLOAT DEFAULT 2.5;
ALTER TABLE words ADD COLUMN IF NOT EXISTS last_review_date DATE;

-- Add performance tracking to word_reviews
ALTER TABLE word_reviews ADD COLUMN IF NOT EXISTS was_correct BOOLEAN;
ALTER TABLE word_reviews ADD COLUMN IF NOT EXISTS response_time_seconds INT;

-- Add indexes for better performance
CREATE INDEX IF NOT EXISTS idx_words_next_review_date ON words(next_review_date);
CREATE INDEX IF NOT EXISTS idx_words_review_count ON words(review_count);
CREATE INDEX IF NOT EXISTS idx_word_reviews_was_correct ON word_reviews(was_correct);

-- Update existing words with initial review date (tomorrow)
UPDATE words 
SET next_review_date = CURRENT_DATE + INTERVAL '1 day'
WHERE next_review_date IS NULL;

COMMENT ON COLUMN words.next_review_date IS 'Next scheduled review date based on SRS algorithm';
COMMENT ON COLUMN words.review_count IS 'Number of times this word has been reviewed';
COMMENT ON COLUMN words.ease_factor IS 'SM-2 algorithm ease factor (default 2.5)';
COMMENT ON COLUMN words.last_review_date IS 'Last date this word was reviewed';
