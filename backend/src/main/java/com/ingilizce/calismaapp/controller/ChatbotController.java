package com.ingilizce.calismaapp.controller;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ingilizce.calismaapp.dto.PracticeSentence;
import com.ingilizce.calismaapp.service.ChatbotService;
import com.ingilizce.calismaapp.service.WordService;
import com.ingilizce.calismaapp.service.GrammarCheckService;
import com.ingilizce.calismaapp.entity.Word;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.time.Duration;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

@RestController
@RequestMapping("/api/chatbot")
public class ChatbotController {

    @Autowired
    private ChatbotService chatbotService;

    @Autowired
    private WordService wordService;

    @Autowired(required = false)
    private RedisTemplate<String, Object> redisTemplate;

    @Autowired(required = false)
    private GrammarCheckService grammarCheckService;

    @Value("${cache.sentences.ttl:604800}") // Default: 7 days
    private long cacheTtlSeconds;

    private final ObjectMapper objectMapper;
    private static final String CACHE_KEY_PREFIX = "sentences:";

    public ChatbotController() {
        this.objectMapper = new ObjectMapper();
        // Ignore unknown properties (LLM bazen farklı field isimleri kullanabilir)
        this.objectMapper.configure(com.fasterxml.jackson.databind.DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES,
                false);
    }

    @PostMapping("/generate-sentences")
    public ResponseEntity<Map<String, Object>> generateSentences(@RequestBody Map<String, Object> request) {
        String word = (String) request.get("word");
        @SuppressWarnings("unchecked")
        List<String> levels = request.get("levels") != null ? (List<String>) request.get("levels")
                : java.util.Arrays.asList("B1");
        @SuppressWarnings("unchecked")
        List<String> lengths = request.get("lengths") != null ? (List<String>) request.get("lengths")
                : java.util.Arrays.asList("medium");
        boolean checkGrammar = request.get("checkGrammar") != null &&
                Boolean.parseBoolean(request.get("checkGrammar").toString());

        if (word == null || word.trim().isEmpty()) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Please provide a word");
            return ResponseEntity.badRequest().body(error);
        }

        // Validate levels and lengths
        List<String> validLevels = java.util.Arrays.asList("A1", "A2", "B1", "B2", "C1", "C2");
        List<String> validLengths = java.util.Arrays.asList("short", "medium", "long");
        levels = levels.stream().filter(validLevels::contains).collect(Collectors.toList());
        lengths = lengths.stream().filter(validLengths::contains).collect(Collectors.toList());

        if (levels.isEmpty())
            levels = java.util.Arrays.asList("B1");
        if (lengths.isEmpty())
            lengths = java.util.Arrays.asList("medium");

        String normalizedWord = word.trim().toLowerCase();
        String cacheKey = CACHE_KEY_PREFIX + normalizedWord + ":" + String.join(",", levels) + ":"
                + String.join(",", lengths);

        try {
            // Redis cache kontrolü (DISABLED for randomness)
            if (redisTemplate != null && false) {
                @SuppressWarnings("unchecked")
                Map<String, Object> cachedData = (Map<String, Object>) redisTemplate.opsForValue().get(cacheKey);
                if (cachedData != null) {
                    System.out.println("Cache HIT for word: " + normalizedWord);
                    return ResponseEntity.ok(cachedData);
                }
                System.out.println("Cache MISS for word: " + normalizedWord);
            }

            // Tüm kombinasyonları tek bir prompt'ta belirtip, LLM'den hepsini birden
            // üretmesini iste
            // Bu yaklaşım çok daha hızlıdır çünkü tek bir istek yapılır
            StringBuilder levelLengthInfo = new StringBuilder();
            levelLengthInfo.append("Generate 5 diverse sentences total, covering these combinations:\n");
            for (String level : levels) {
                for (String length : lengths) {
                    levelLengthInfo.append(String.format("- Level: %s, Length: %s\n", level, length));
                }
            }
            levelLengthInfo.append(
                    "Distribute the 5 sentences across these combinations. Make sentences diverse and cover different meanings if the word has multiple meanings.");

            String message = String.format("Target word: '%s'.\n%s", normalizedWord, levelLengthInfo.toString());

            String jsonResponse = chatbotService.generateSentences(message);

            // JSON'u temizle (markdown code blocks varsa kaldır)
            jsonResponse = jsonResponse.trim();
            jsonResponse = jsonResponse.replaceAll("```json", "").replaceAll("```", "").trim();

            // LLM bazen açıklama metni ekliyor, JSON array'i bul (ilk [ karakterinden
            // başla)
            int arrayStartIndex = jsonResponse.indexOf('[');
            if (arrayStartIndex > 0) {
                // Array'den önce metin var, onu kaldır
                jsonResponse = jsonResponse.substring(arrayStartIndex);
            }

            // Array'in sonunu bul (son ] karakterine kadar)
            int arrayEndIndex = jsonResponse.lastIndexOf(']');
            if (arrayEndIndex > 0 && arrayEndIndex < jsonResponse.length() - 1) {
                // Array'den sonra metin var, onu kaldır
                jsonResponse = jsonResponse.substring(0, arrayEndIndex + 1);
            }

            jsonResponse = jsonResponse.trim();

            // LLM bazen yanlış field name kullanabilir, düzelt
            jsonResponse = jsonResponse.replaceAll("\"turkishTransliteration\"", "\"turkishTranslation\"");
            jsonResponse = jsonResponse.replaceAll("\"turkish_translation\"", "\"turkishTranslation\"");
            jsonResponse = jsonResponse.replaceAll("\"turkish\"", "\"turkishTranslation\"");

            List<PracticeSentence> allSentences = new ArrayList<>();
            try {
                // Önce JSON'un array mi object mi olduğunu kontrol et
                Object parsed = objectMapper.readValue(jsonResponse, Object.class);

                if (parsed instanceof List) {
                    // Array ise direkt parse et
                    allSentences = objectMapper.readValue(
                            jsonResponse,
                            new TypeReference<List<PracticeSentence>>() {
                            });
                } else if (parsed instanceof Map) {
                    // Object ise, içinde "sentences" veya benzer bir key var mı kontrol et
                    @SuppressWarnings("unchecked")
                    Map<String, Object> map = (Map<String, Object>) parsed;

                    // "sentences" key'i varsa onu kullan
                    if (map.containsKey("sentences") && map.get("sentences") instanceof List) {
                        allSentences = objectMapper.convertValue(
                                map.get("sentences"),
                                new TypeReference<List<PracticeSentence>>() {
                                });
                    } else {
                        // Tek bir object ise, onu array'e çevir
                        try {
                            PracticeSentence single = objectMapper.convertValue(parsed, PracticeSentence.class);
                            allSentences.add(single);
                        } catch (Exception ex) {
                            System.err.println("Could not parse as single PracticeSentence: " + ex.getMessage());
                            throw new RuntimeException(
                                    "LLM returned unexpected JSON format. Expected array or object with 'sentences' key.",
                                    ex);
                        }
                    }
                } else {
                    throw new RuntimeException("LLM returned unexpected JSON format. Expected array or object.");
                }
            } catch (Exception e) {
                System.err.println("Error parsing JSON: " + e.getMessage());
                System.err.println("JSON response (first 500 chars): " +
                        (jsonResponse.length() > 500 ? jsonResponse.substring(0, 500) + "..." : jsonResponse));
                throw new RuntimeException("Failed to parse LLM response: " + e.getMessage(), e);
            }

            // Toplam 5 cümle olacak şekilde sınırla (eğer fazla varsa)
            if (allSentences.size() > 5) {
                allSentences = allSentences.subList(0, 5);
            }

            // LanguageTool ile gramer kontrolü (opsiyonel)
            if (checkGrammar && grammarCheckService != null && grammarCheckService.isEnabled()) {
                List<String> englishSentences = allSentences.stream()
                        .map(PracticeSentence::englishSentence)
                        .collect(Collectors.toList());

                Map<String, List<Map<String, Object>>> grammarErrors = grammarCheckService
                        .checkMultipleSentences(englishSentences);

                if (!grammarErrors.isEmpty()) {
                    System.out.println("Grammar errors found for " + grammarErrors.size() + " sentences");
                }
            }

            // Frontend'e İngilizce cümleleri ve Türkçe çevirilerini gönder
            List<String> sentences = allSentences.stream()
                    .map(PracticeSentence::englishSentence)
                    .collect(Collectors.toList());

            List<String> translations = allSentences.stream()
                    .map(ps -> ps.turkishFullTranslation() != null ? ps.turkishFullTranslation() : "")
                    .collect(Collectors.toList());

            // Redis'e cache'le (sentences ve translations birlikte)
            Map<String, Object> result = new HashMap<>();
            result.put("sentences", sentences);
            result.put("translations", translations);
            result.put("count", sentences.size());
            result.put("cached", false);

            if (redisTemplate != null && false) {
                try {
                    redisTemplate.opsForValue().set(
                            cacheKey,
                            result,
                            Duration.ofSeconds(cacheTtlSeconds));
                    System.out.println(
                            "Cached sentences for word: " + normalizedWord + " (TTL: " + cacheTtlSeconds + "s)");
                } catch (Exception e) {
                    System.err.println("Failed to cache sentences: " + e.getMessage());
                    // Cache hatası olsa bile devam et
                }
            }

            // Debug için structured data'yı da logla
            System.out
                    .println("Generated " + allSentences.size() + " structured sentences for word: " + normalizedWord);
            for (PracticeSentence ps : allSentences) {
                System.out.println("  - " + ps.englishSentence() + " → " + ps.turkishTranslation());
            }

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("Error generating sentences: " + e.getMessage());
            System.err.println("Response was: " + (e.getMessage().contains("Response") ? "" : ""));
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to generate sentences: " + e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }

    @PostMapping("/check-translation")
    public ResponseEntity<Map<String, Object>> checkTranslation(@RequestBody Map<String, String> request) {
        String direction = request.getOrDefault("direction", "EN_TO_TR"); // EN_TO_TR or TR_TO_EN
        String userTranslation = request.get("userTranslation");

        if (userTranslation == null) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Please provide translation");
            return ResponseEntity.badRequest().body(error);
        }

        try {
            String response;

            if ("TR_TO_EN".equals(direction)) {
                // User translating from Turkish to English
                String turkishSentence = request.get("turkishSentence");
                String englishRef = request.get("englishSentence"); // Optional reference

                if (turkishSentence == null) {
                    Map<String, Object> error = new HashMap<>();
                    error.put("error", "Turkish sentence is required for TR_TO_EN direction");
                    return ResponseEntity.badRequest().body(error);
                }

                System.out.println("Checking TR->EN translation:");
                System.out.println("Turkish Source: " + turkishSentence);
                System.out.println("User English: " + userTranslation);

                String combinedMessage = "Turkish sentence: " + turkishSentence + ". User's English translation: "
                        + userTranslation + ".";
                if (englishRef != null) {
                    combinedMessage += " (Reference/Target English: " + englishRef + ")";
                }
                combinedMessage += " Evaluate this translation generously. Return ONLY JSON.";

                response = chatbotService.checkEnglishTranslation(combinedMessage);

            } else {
                // Default: EN_TO_TR (English to Turkish)
                String englishSentence = request.get("englishSentence");

                if (englishSentence == null) {
                    Map<String, Object> error = new HashMap<>();
                    error.put("error", "English sentence is required for EN_TO_TR direction");
                    return ResponseEntity.badRequest().body(error);
                }

                System.out.println("Checking EN->TR translation:");
                System.out.println("English Source: " + englishSentence);
                System.out.println("User Turkish: " + userTranslation);

                String combinedMessage = "English sentence: " + englishSentence + ". User's Turkish translation: "
                        + userTranslation + ". Evaluate this translation generously. Return ONLY JSON.";

                response = chatbotService.checkTranslation(combinedMessage);
            }

            System.out.println("Chatbot response: " + response);

            // Parse JSON response
            Map<String, Object> result = parseJsonResponse(response);

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("Error checking translation: " + e.getMessage());
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to check translation: " + e.getMessage());
            error.put("details", e.getClass().getSimpleName());
            return ResponseEntity.internalServerError().body(error);
        }
    }

    private Map<String, Object> parseJsonResponse(String response) {
        Map<String, Object> result = new HashMap<>();

        try {
            // Clean response - remove markdown code blocks if present
            response = response.trim();
            response = response.replaceAll("```json", "").replaceAll("```", "").trim();

            // Try to extract JSON object
            int jsonStart = response.indexOf("{");
            int jsonEnd = response.lastIndexOf("}") + 1;

            if (jsonStart >= 0 && jsonEnd > jsonStart) {
                String jsonStr = response.substring(jsonStart, jsonEnd);

                // Parse isCorrect
                Pattern isCorrectPattern = Pattern.compile("\"isCorrect\"\\s*:\\s*(true|false)");
                Matcher isCorrectMatcher = isCorrectPattern.matcher(jsonStr);
                if (isCorrectMatcher.find()) {
                    result.put("isCorrect", Boolean.parseBoolean(isCorrectMatcher.group(1)));
                } else {
                    result.put("isCorrect", false);
                }

                // Extract correctTranslation
                Pattern correctPattern = Pattern.compile("\"correctTranslation\"\\s*:\\s*\"([^\"]+)\"");
                Matcher correctMatcher = correctPattern.matcher(jsonStr);
                if (correctMatcher.find()) {
                    result.put("correctTranslation", correctMatcher.group(1));
                } else {
                    result.put("correctTranslation", "");
                }

                // Extract feedback
                Pattern feedbackPattern = Pattern.compile("\"feedback\"\\s*:\\s*\"([^\"]+)\"");
                Matcher feedbackMatcher = feedbackPattern.matcher(jsonStr);
                if (feedbackMatcher.find()) {
                    result.put("feedback", feedbackMatcher.group(1));
                } else {
                    result.put("feedback", "Çeviri kontrol edildi.");
                }
            } else {
                // If no JSON found, try to infer from text
                boolean isCorrect = response.toLowerCase().contains("\"isCorrect\":true") ||
                        response.toLowerCase().contains("doğru") ||
                        (!response.toLowerCase().contains("incorrect") &&
                                !response.toLowerCase().contains("yanlış") &&
                                !response.toLowerCase().contains("\"isCorrect\":false"));

                result.put("isCorrect", isCorrect);
                result.put("correctTranslation", "");
                result.put("feedback", response);
            }
        } catch (Exception e) {
            // Fallback
            result.put("isCorrect", false);
            result.put("correctTranslation", "");
            result.put("feedback", "Çeviri kontrol edilemedi: " + e.getMessage());
        }

        return result;
    }

    @PostMapping("/save-to-today")
    @SuppressWarnings("unchecked")
    public ResponseEntity<Map<String, Object>> saveToToday(@RequestBody Map<String, Object> request) {
        try {
            String englishWord = (String) request.get("englishWord");
            List<String> meanings = request.get("meanings") != null
                    ? (List<String>) request.get("meanings")
                    : new ArrayList<>();
            List<String> sentences = request.get("sentences") != null
                    ? (List<String>) request.get("sentences")
                    : new ArrayList<>();

            if (englishWord == null || englishWord.trim().isEmpty()) {
                Map<String, Object> error = new HashMap<>();
                error.put("error", "English word is required");
                return ResponseEntity.badRequest().body(error);
            }

            // Create word with today's date
            Word word = new Word();
            word.setEnglishWord(englishWord.trim());

            // Combine all meanings into Turkish meaning
            String turkishMeaning = meanings != null && !meanings.isEmpty()
                    ? String.join(", ", meanings)
                    : "";
            word.setTurkishMeaning(turkishMeaning);
            word.setLearnedDate(LocalDate.now());
            word.setDifficulty("medium");

            // Save word first
            Word savedWord = wordService.saveWord(word);

            // Add sentences if provided
            if (sentences != null && !sentences.isEmpty()) {
                for (String sentenceStr : sentences) {
                    // Sentences now only contain English text (no Turkish translation in
                    // parentheses)
                    String englishSentence = sentenceStr.trim();

                    wordService.addSentence(
                            savedWord.getId(),
                            englishSentence,
                            "", // No Turkish translation stored anymore
                            "medium");
                }
            }

            // Reload word with sentences
            savedWord = wordService.getWordById(savedWord.getId()).orElse(savedWord);

            Map<String, Object> result = new HashMap<>();
            result.put("success", true);
            result.put("word", savedWord);
            result.put("message", "Kelime ve cümleler bugünkü tarihe başarıyla eklendi.");

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to save word: " + e.getMessage());
            e.printStackTrace();
            return ResponseEntity.internalServerError().body(error);
        }
    }

    @PostMapping("/chat")
    public ResponseEntity<Map<String, Object>> chat(@RequestBody Map<String, String> request) {
        String message = request.get("message");

        if (message == null || message.trim().isEmpty()) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Please provide a message");
            return ResponseEntity.badRequest().body(error);
        }

        try {
            String response = chatbotService.chat(message.trim());

            Map<String, Object> result = new HashMap<>();
            result.put("response", response);
            result.put("timestamp", System.currentTimeMillis());

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("Error in chat: " + e.getMessage());
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to get response: " + e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }

    @PostMapping("/speaking-test/generate-questions")
    public ResponseEntity<Map<String, Object>> generateSpeakingTestQuestions(@RequestBody Map<String, String> request) {
        String testType = request.get("testType"); // "IELTS" or "TOEFL"
        String part = request.get("part"); // "part1", "part2", "part3" for IELTS, "task1", "task2", etc. for TOEFL

        if (testType == null || part == null) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Please provide testType and part");
            return ResponseEntity.badRequest().body(error);
        }

        try {
            String message = String.format("Generate %s Speaking test questions for %s. Return ONLY JSON.", testType,
                    part);
            String response = chatbotService.generateSpeakingTestQuestions(message);

            // Parse JSON response
            response = response.trim();
            response = response.replaceAll("```json", "").replaceAll("```", "").trim();

            Map<String, Object> result = objectMapper.readValue(response, new TypeReference<Map<String, Object>>() {
            });

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("Error generating speaking test questions: " + e.getMessage());
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to generate questions: " + e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }

    @PostMapping("/speaking-test/evaluate")
    public ResponseEntity<Map<String, Object>> evaluateSpeakingTest(@RequestBody Map<String, String> request) {
        String testType = request.get("testType"); // "IELTS" or "TOEFL"
        String question = request.get("question");
        String response = request.get("response");

        if (testType == null || question == null || response == null) {
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Please provide testType, question, and response");
            return ResponseEntity.badRequest().body(error);
        }

        try {
            String message = String.format(
                    "Evaluate this %s Speaking test response. Question: %s. Candidate's response: %s. Return ONLY JSON.",
                    testType, question, response);
            String llmResponse = chatbotService.evaluateSpeakingTest(message);

            // Parse JSON response
            llmResponse = llmResponse.trim();
            llmResponse = llmResponse.replaceAll("```json", "").replaceAll("```", "").trim();

            Map<String, Object> result = objectMapper.readValue(llmResponse, new TypeReference<Map<String, Object>>() {
            });

            return ResponseEntity.ok(result);
        } catch (Exception e) {
            System.err.println("Error evaluating speaking test: " + e.getMessage());
            e.printStackTrace();
            Map<String, Object> error = new HashMap<>();
            error.put("error", "Failed to evaluate response: " + e.getMessage());
            return ResponseEntity.internalServerError().body(error);
        }
    }
}
