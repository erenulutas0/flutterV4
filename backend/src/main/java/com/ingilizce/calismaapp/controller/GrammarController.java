package com.ingilizce.calismaapp.controller;

import com.ingilizce.calismaapp.service.GrammarCheckService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * REST Controller for grammar checking functionality
 * Uses JLanguageTool for English grammar validation
 */
@RestController
@RequestMapping("/api/grammar")
@CrossOrigin(originPatterns = "*")
public class GrammarController {

    @Autowired
    private GrammarCheckService grammarCheckService;

    /**
     * Check grammar for a single sentence
     * 
     * @param request Map containing "sentence" key
     * @return Grammar check results with errors and suggestions
     * 
     *         Example request:
     *         {
     *         "sentence": "I goes to school"
     *         }
     * 
     *         Example response:
     *         {
     *         "hasErrors": true,
     *         "errorCount": 1,
     *         "errors": [
     *         {
     *         "message": "The verb 'goes' does not agree with the subject 'I'",
     *         "shortMessage": "Wrong verb form",
     *         "fromPos": 2,
     *         "toPos": 6,
     *         "suggestions": ["go"]
     *         }
     *         ]
     *         }
     */
    @PostMapping("/check")
    public ResponseEntity<Map<String, Object>> checkGrammar(@RequestBody Map<String, String> request) {
        try {
            String sentence = request.get("sentence");

            if (sentence == null || sentence.trim().isEmpty()) {
                Map<String, Object> errorResponse = new HashMap<>();
                errorResponse.put("hasErrors", false);
                errorResponse.put("errorCount", 0);
                errorResponse.put("errors", List.of());
                errorResponse.put("message", "Empty sentence provided");
                return ResponseEntity.badRequest().body(errorResponse);
            }

            Map<String, Object> result = grammarCheckService.checkGrammar(sentence);
            return ResponseEntity.ok(result);

        } catch (Exception e) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("hasErrors", false);
            errorResponse.put("errorCount", 0);
            errorResponse.put("errors", List.of());
            errorResponse.put("message", "Grammar check failed: " + e.getMessage());
            return ResponseEntity.internalServerError().body(errorResponse);
        }
    }

    /**
     * Check grammar for multiple sentences
     * 
     * @param request Map containing "sentences" array
     * @return Map of sentence to errors
     * 
     *         Example request:
     *         {
     *         "sentences": ["I goes to school", "She play tennis"]
     *         }
     * 
     *         Example response:
     *         {
     *         "I goes to school": [
     *         {
     *         "message": "Wrong verb form",
     *         "suggestions": ["go"]
     *         }
     *         ],
     *         "She play tennis": [
     *         {
     *         "message": "Wrong verb form",
     *         "suggestions": ["plays"]
     *         }
     *         ]
     *         }
     */
    @PostMapping("/check-multiple")
    public ResponseEntity<Map<String, List<Map<String, Object>>>> checkMultipleSentences(
            @RequestBody Map<String, List<String>> request) {
        try {
            List<String> sentences = request.get("sentences");

            if (sentences == null || sentences.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of());
            }

            Map<String, List<Map<String, Object>>> results = grammarCheckService.checkMultipleSentences(sentences);

            return ResponseEntity.ok(results);

        } catch (Exception e) {
            return ResponseEntity.internalServerError().body(Map.of());
        }
    }

    /**
     * Get grammar checker status
     * 
     * @return Status information
     */
    @GetMapping("/status")
    public ResponseEntity<Map<String, Object>> getStatus() {
        Map<String, Object> status = new HashMap<>();
        status.put("enabled", grammarCheckService.isEnabled());
        status.put("service", "JLanguageTool");
        status.put("language", "en-US");
        status.put("version", "6.4");
        return ResponseEntity.ok(status);
    }

    /**
     * Enable or disable grammar checking
     * 
     * @param request Map containing "enabled" boolean
     * @return Updated status
     */
    @PostMapping("/toggle")
    public ResponseEntity<Map<String, Object>> toggleGrammarCheck(@RequestBody Map<String, Boolean> request) {
        Boolean enabled = request.get("enabled");
        if (enabled != null) {
            grammarCheckService.setEnabled(enabled);
        }

        Map<String, Object> status = new HashMap<>();
        status.put("enabled", grammarCheckService.isEnabled());
        status.put("message", enabled ? "Grammar checking enabled" : "Grammar checking disabled");
        return ResponseEntity.ok(status);
    }
}
