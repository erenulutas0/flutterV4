package com.ingilizce.calismaapp.repository;

import com.ingilizce.calismaapp.entity.UserProgress;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserProgressRepository extends JpaRepository<UserProgress, Long> {

    Optional<UserProgress> findByUserId(Long userId);

    // For leaderboard (future)
    // List<UserProgress> findTop10ByOrderByTotalXpDesc();
}
