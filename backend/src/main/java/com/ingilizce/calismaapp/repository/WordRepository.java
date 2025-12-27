package com.ingilizce.calismaapp.repository;

import com.ingilizce.calismaapp.entity.Word;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDate;
import java.util.List;

@Repository
public interface WordRepository extends JpaRepository<Word, Long> {

    List<Word> findByLearnedDate(LocalDate date);

    @Query("SELECT w FROM Word w WHERE w.learnedDate BETWEEN :startDate AND :endDate ORDER BY w.learnedDate DESC")
    List<Word> findByDateRange(@Param("startDate") LocalDate startDate, @Param("endDate") LocalDate endDate);

    @Query("SELECT DISTINCT w.learnedDate FROM Word w ORDER BY w.learnedDate DESC")
    List<LocalDate> findAllDistinctDates();

    // SRS Queries
    List<Word> findByNextReviewDateLessThanEqual(LocalDate date);

    List<Word> findByReviewCountGreaterThan(int count);
}
