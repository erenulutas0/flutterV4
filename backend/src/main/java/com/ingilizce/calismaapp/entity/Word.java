package com.ingilizce.calismaapp.entity;

import jakarta.persistence.*;
import com.fasterxml.jackson.annotation.JsonManagedReference;
import java.time.LocalDate;
import java.util.List;
import java.util.ArrayList;

@Entity
@Table(name = "words")
public class Word {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String englishWord;

    @Column
    private String turkishMeaning;

    @Column(nullable = false)
    private LocalDate learnedDate;

    @Column
    private String notes;

    @Column
    private String difficulty;

    // SRS (Spaced Repetition System) Fields
    @Column(name = "next_review_date")
    private LocalDate nextReviewDate;

    @Column(name = "review_count")
    private Integer reviewCount = 0;

    @Column(name = "ease_factor")
    private Double easeFactor = 2.5;

    @Column(name = "last_review_date")
    private LocalDate lastReviewDate;

    @OneToMany(mappedBy = "word", cascade = CascadeType.ALL, fetch = FetchType.EAGER)
    @JsonManagedReference
    private List<Sentence> sentences = new ArrayList<>();

    // Constructors
    public Word() {
    }

    public Word(String englishWord, String turkishMeaning, LocalDate learnedDate) {
        this.englishWord = englishWord;
        this.turkishMeaning = turkishMeaning;
        this.learnedDate = learnedDate;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getEnglishWord() {
        return englishWord;
    }

    public void setEnglishWord(String englishWord) {
        this.englishWord = englishWord;
    }

    public String getTurkishMeaning() {
        return turkishMeaning;
    }

    public void setTurkishMeaning(String turkishMeaning) {
        this.turkishMeaning = turkishMeaning;
    }

    public LocalDate getLearnedDate() {
        return learnedDate;
    }

    public void setLearnedDate(LocalDate learnedDate) {
        this.learnedDate = learnedDate;
    }

    public String getNotes() {
        return notes;
    }

    public void setNotes(String notes) {
        this.notes = notes;
    }

    public List<Sentence> getSentences() {
        return sentences;
    }

    public void setSentences(List<Sentence> sentences) {
        this.sentences = sentences;
    }

    public void addSentence(Sentence sentence) {
        sentences.add(sentence);
        sentence.setWord(this);
    }

    public void removeSentence(Sentence sentence) {
        sentences.remove(sentence);
        sentence.setWord(null);
    }

    public String getDifficulty() {
        return difficulty;
    }

    public void setDifficulty(String difficulty) {
        this.difficulty = difficulty;
    }

    // SRS Getters and Setters
    public LocalDate getNextReviewDate() {
        return nextReviewDate;
    }

    public void setNextReviewDate(LocalDate nextReviewDate) {
        this.nextReviewDate = nextReviewDate;
    }

    public Integer getReviewCount() {
        return reviewCount;
    }

    public void setReviewCount(Integer reviewCount) {
        this.reviewCount = reviewCount;
    }

    public Double getEaseFactor() {
        return easeFactor;
    }

    public void setEaseFactor(Double easeFactor) {
        this.easeFactor = easeFactor;
    }

    public LocalDate getLastReviewDate() {
        return lastReviewDate;
    }

    public void setLastReviewDate(LocalDate lastReviewDate) {
        this.lastReviewDate = lastReviewDate;
    }
}
