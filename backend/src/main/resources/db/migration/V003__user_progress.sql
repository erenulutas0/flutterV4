-- V003: User Progress and Achievements
-- Created: 2024-12-25
-- Description: Add user progress tracking, XP, levels, streaks, and achievements

-- User Progress Table
CREATE TABLE IF NOT EXISTS user_progress (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT DEFAULT 1, -- Default user for now (multi-user support later)
    total_xp INT DEFAULT 0,
    level INT DEFAULT 1,
    current_streak INT DEFAULT 0,
    longest_streak INT DEFAULT 0,
    last_activity_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Achievements Table
CREATE TABLE IF NOT EXISTS user_achievements (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT DEFAULT 1,
    achievement_code VARCHAR(50) NOT NULL,
    unlocked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, achievement_code)
);

-- Insert default user progress
INSERT INTO user_progress (user_id, total_xp, level, current_streak, longest_streak)
VALUES (1, 0, 1, 0, 0)
ON CONFLICT DO NOTHING;

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_code ON user_achievements(achievement_code);

-- Add XP tracking to words (optional, for future analytics)
ALTER TABLE words ADD COLUMN IF NOT EXISTS xp_earned INT DEFAULT 5;

-- Add review quality tracking to word_reviews (already exists, just ensuring)
-- ALTER TABLE word_reviews ADD COLUMN IF NOT EXISTS quality INT; -- Already exists

COMMENT ON TABLE user_progress IS 'Tracks user XP, level, and streak information';
COMMENT ON TABLE user_achievements IS 'Tracks unlocked achievements per user';
