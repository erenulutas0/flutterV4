package com.ingilizce.calismaapp.controller;

import com.ingilizce.calismaapp.entity.Word;
import com.ingilizce.calismaapp.service.SRSService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

/**
 * REST Controller for Spaced Repetition System (SRS)
 */
@RestController
@RequestMapping("/api/srs")
@CrossOrigin(originPatterns = "*")
public class SRSController {

    @Autowired
    private SRSService srsService;

    /**
     * Get words that need review today
     * 
     * @return List of words to review
     */
    @GetMapping("/review-words")
    public ResponseEntity<List<Word>> getReviewWords() {
        try {
            List<Word> words = srsService.getWordsForReview();
            return ResponseEntity.ok(words);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Submit a review result
     * 
     * @param request Map containing wordId and quality
     * @return Updated word
     * 
     *         Example request:
     *         {
     *         "wordId": 123,
     *         "quality": 4
     *         }
     */
    @PostMapping("/submit-review")
    public ResponseEntity<Word> submitReview(@RequestBody Map<String, Object> request) {
        try {
            Long wordId = Long.valueOf(request.get("wordId").toString());
            int quality = Integer.parseInt(request.get("quality").toString());

            Word updatedWord = srsService.submitReview(wordId, quality);
            return ResponseEntity.ok(updatedWord);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }

    /**
     * Get SRS statistics
     * 
     * @return Statistics map
     * 
     *         Example response:
     *         {
     *         "dueToday": 5,
     *         "totalWords": 100,
     *         "reviewedWords": 80
     *         }
     */
    @GetMapping("/stats")
    public ResponseEntity<Map<String, Object>> getStats() {
        try {
            Map<String, Object> stats = srsService.getStats();
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().build();
        }
    }
}
