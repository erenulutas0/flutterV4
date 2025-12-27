package com.ingilizce.calismaapp.service;

import com.ingilizce.calismaapp.entity.Word;
import com.ingilizce.calismaapp.entity.Sentence;
import com.ingilizce.calismaapp.dto.CreateWordRequest;
import com.ingilizce.calismaapp.repository.WordRepository;
import com.ingilizce.calismaapp.repository.SentenceRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Service
public class WordService {

    @Autowired
    private WordRepository wordRepository;

    @Autowired
    private SentenceRepository sentenceRepository;

    @Autowired
    private ProgressService progressService;

    public List<Word> getAllWords() {
        return wordRepository.findAll();
    }

    public List<Word> getWordsByDate(LocalDate date) {
        return wordRepository.findByLearnedDate(date);
    }

    public List<Word> getWordsByDateRange(LocalDate startDate, LocalDate endDate) {
        return wordRepository.findByDateRange(startDate, endDate);
    }

    public List<LocalDate> getAllDistinctDates() {
        return wordRepository.findAllDistinctDates();
    }

    public Word saveWord(Word word) {
        boolean isNew = (word.getId() == null);
        Word savedWord = wordRepository.save(word);

        if (isNew) {
            progressService.awardXp(5, "New Word: " + word.getEnglishWord());
            progressService.updateStreak();
        }

        return savedWord;
    }

    public Word createWord(CreateWordRequest request) {
        System.out.println("Creating word with: " + request.getEnglish() + ", " + request.getTurkish() + ", "
                + request.getAddedDate());
        Word word = new Word();
        word.setEnglishWord(request.getEnglish());
        word.setTurkishMeaning(request.getTurkish());
        word.setLearnedDate(LocalDate.parse(request.getAddedDate()));
        word.setNotes(request.getNotes());
        if (request.getDifficulty() != null) {
            word.setDifficulty(request.getDifficulty());
        }
        return wordRepository.save(word);
    }

    public Optional<Word> getWordById(Long id) {
        return wordRepository.findById(id);
    }

    public void deleteWord(Long id) {
        wordRepository.deleteById(id);
    }

    public Word updateWord(Long id, Word wordDetails) {
        Optional<Word> optionalWord = wordRepository.findById(id);
        if (optionalWord.isPresent()) {
            Word word = optionalWord.get();
            word.setEnglishWord(wordDetails.getEnglishWord());
            word.setTurkishMeaning(wordDetails.getTurkishMeaning());
            word.setLearnedDate(wordDetails.getLearnedDate());
            word.setNotes(wordDetails.getNotes());
            return wordRepository.save(word);
        }
        return null;
    }

    // Sentence management methods
    public Word addSentence(Long wordId, String sentence, String translation, String difficulty) {
        Optional<Word> wordOpt = wordRepository.findById(wordId);
        if (wordOpt.isPresent()) {
            Word word = wordOpt.get();
            Sentence newSentence = new Sentence(sentence, translation, difficulty != null ? difficulty : "easy", word);
            word.addSentence(newSentence);
            progressService.awardXp(3, "New Sentence for: " + word.getEnglishWord());
            return wordRepository.save(word);
        }
        return null;
    }

    public Word deleteSentence(Long wordId, Long sentenceId) {
        Optional<Word> wordOpt = wordRepository.findById(wordId);
        Optional<Sentence> sentenceOpt = sentenceRepository.findById(sentenceId);

        if (wordOpt.isPresent() && sentenceOpt.isPresent()) {
            Word word = wordOpt.get();
            Sentence sentence = sentenceOpt.get();

            // Check if sentence belongs to the word
            if (sentence.getWord().getId().equals(wordId)) {
                word.removeSentence(sentence);
                sentenceRepository.delete(sentence);
                return wordRepository.save(word);
            }
        }
        return null;
    }
}
