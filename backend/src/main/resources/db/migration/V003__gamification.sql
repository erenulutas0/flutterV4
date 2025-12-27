-- Migration 003: Gamification System
-- Description: Creates tables for user profiles, badges, and friendships

-- User Profiles Table
CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(100),
    total_xp INT DEFAULT 0,
    level INT DEFAULT 1,
    streak_days INT DEFAULT 0,
    last_activity_date DATE,
    avatar_url VARCHAR(255),
    bio TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Badges Table
CREATE TABLE IF NOT EXISTS badges (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    description TEXT,
    icon_name VARCHAR(50),
    xp_required INT DEFAULT 0,
    category VARCHAR(20),
    rarity VARCHAR(20) DEFAULT 'common',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User Badges Junction Table
CREATE TABLE IF NOT EXISTS user_badges (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES user_profiles(id) ON DELETE CASCADE,
    badge_id BIGINT REFERENCES badges(id) ON DELETE CASCADE,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, badge_id)
);

-- Friendships Table
CREATE TABLE IF NOT EXISTS friendships (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES user_profiles(id) ON DELETE CASCADE,
    friend_id BIGINT REFERENCES user_profiles(id) ON DELETE CASCADE,
    status VARCHAR(20) CHECK (status IN ('pending', 'accepted', 'blocked', 'rejected')) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, friend_id)
);

-- Weekly Scores for Leaderboard
CREATE TABLE IF NOT EXISTS weekly_scores (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES user_profiles(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL,
    weekly_xp INT DEFAULT 0,
    league VARCHAR(20) DEFAULT 'bronze',
    rank INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, week_start_date)
);

-- XP History for analytics
CREATE TABLE IF NOT EXISTS xp_transactions (
    id SERIAL PRIMARY KEY,
    user_id BIGINT REFERENCES user_profiles(id) ON DELETE CASCADE,
    amount INT NOT NULL,
    reason VARCHAR(100),
    source VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_user_profiles_xp ON user_profiles(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_level ON user_profiles(level DESC);
CREATE INDEX IF NOT EXISTS idx_user_profiles_streak ON user_profiles(streak_days DESC);
CREATE INDEX IF NOT EXISTS idx_friendships_user ON friendships(user_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON friendships(friend_id, status);
CREATE INDEX IF NOT EXISTS idx_weekly_scores_week ON weekly_scores(week_start_date, weekly_xp DESC);
CREATE INDEX IF NOT EXISTS idx_xp_transactions_user ON xp_transactions(user_id, created_at DESC);

-- Insert default badges
INSERT INTO badges (name, description, icon_name, xp_required, category, rarity) VALUES
('İlk Adım', 'İlk kelimeni öğrendin! 🌱', 'first_word', 0, 'learning', 'common'),
('Hızlı Başlangıç', '5 kelime öğrendin!', 'fast_start', 50, 'learning', 'common'),
('Kelime Avcısı', '25 kelime öğrendin! 📚', 'word_hunter', 250, 'learning', 'uncommon'),
('Kelime Uzmanı', '100 kelime öğrendin!', 'word_expert', 1000, 'learning', 'rare'),
('Kelime Dehası', '500 kelime öğrendin! 🧠', 'word_genius', 5000, 'learning', 'epic'),

('7 Günlük Ateş', '7 gün üst üste çalıştın! 🔥', 'week_streak', 0, 'streak', 'uncommon'),
('Kararlı', '30 gün streak!', 'determined', 0, 'streak', 'rare'),
('Efsane', '100 gün streak! 🏆', 'legendary', 0, 'streak', 'legendary'),

('Konuşkan', '10 AI konuşması yaptın 💬', 'chatty', 150, 'social', 'common'),
('Sosyal Kelebek', 'İlk arkadaşını ekledin!', 'social_butterfly', 0, 'social', 'common'),
('Video Yıldızı', '5 video call yaptın! 📞', 'video_star', 100, 'social', 'uncommon'),

('Tekrar Ustası', '50 kelime tekrarladın! 🎯', 'review_master', 250, 'review', 'uncommon'),
('Mükemmeliyetçi', '20 kelimeyi %100 doğru tekrarladın!', 'perfectionist', 400, 'review', 'rare'),

('Telaffuz Yıldızı', '10 kelimeyi %90+ telaffuz ettiniz! 🌟', 'pronunciation_star', 200, 'pronunciation', 'uncommon')
ON CONFLICT DO NOTHING;

-- Create default user (for testing)
INSERT INTO user_profiles (username, email, total_xp, level)
VALUES ('demo_user', 'demo@vocabmaster.com', 0, 1)
ON CONFLICT (username) DO NOTHING;

-- Comments
COMMENT ON TABLE user_profiles IS 'User profiles with gamification data';
COMMENT ON TABLE badges IS 'Achievement badges that users can earn';
COMMENT ON TABLE user_badges IS 'Junction table for users and their earned badges';
COMMENT ON TABLE friendships IS 'User friendship relationships';
COMMENT ON TABLE weekly_scores IS 'Weekly XP scores for leaderboard';
COMMENT ON TABLE xp_transactions IS 'History of XP gains and losses';
