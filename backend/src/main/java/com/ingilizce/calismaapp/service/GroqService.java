package com.ingilizce.calismaapp.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
public class GroqService {

    private static final Logger logger = LoggerFactory.getLogger(GroqService.class);

    @Value("${groq.api.key}")
    private String apiKey;

    @Value("${groq.api.url}")
    private String apiUrl;

    @Value("${groq.api.model}")
    private String model;

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper;

    public GroqService() {
        this.objectMapper = new ObjectMapper();
        this.restTemplate = createInsecureRestTemplate();
        logger.info("GroqService initialized with SSL-bypassing RestTemplate");
    }

    private RestTemplate createInsecureRestTemplate() {
        try {
            // Trust all certificates
            javax.net.ssl.TrustManager[] trustAllCerts = new javax.net.ssl.TrustManager[] {
                    new javax.net.ssl.X509TrustManager() {
                        public java.security.cert.X509Certificate[] getAcceptedIssuers() {
                            return null;
                        }

                        public void checkClientTrusted(
                                java.security.cert.X509Certificate[] certs, String authType) {
                        }

                        public void checkServerTrusted(
                                java.security.cert.X509Certificate[] certs, String authType) {
                        }
                    }
            };

            // Install the all-trusting trust manager
            javax.net.ssl.SSLContext sc = javax.net.ssl.SSLContext.getInstance("TLS");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());

            org.springframework.http.client.SimpleClientHttpRequestFactory factory = new org.springframework.http.client.SimpleClientHttpRequestFactory() {
                @Override
                protected java.net.HttpURLConnection openConnection(java.net.URL url, java.net.Proxy proxy)
                        throws java.io.IOException {
                    java.net.HttpURLConnection connection = super.openConnection(url, proxy);
                    if (connection instanceof javax.net.ssl.HttpsURLConnection) {
                        ((javax.net.ssl.HttpsURLConnection) connection).setSSLSocketFactory(sc.getSocketFactory());
                        ((javax.net.ssl.HttpsURLConnection) connection)
                                .setHostnameVerifier((hostname, session) -> true);
                    }
                    return connection;
                }
            };

            factory.setConnectTimeout(60000); // 60 seconds
            factory.setReadTimeout(60000); // 60 seconds

            return new RestTemplate(factory);
        } catch (Exception e) {
            logger.error("Failed to create SSL bypassing RestTemplate", e);
            return new RestTemplate();
        }
    }

    /**
     * Send a completion request to Groq API
     * 
     * @param messages     List of messages (role, content)
     * @param jsonResponse If true, enforces JSON object response format
     * @return Content string from the response
     */
    public String chatCompletion(List<Map<String, String>> messages, boolean jsonResponse) {
        logger.info("Groq Request - Model: {}, URL: {}, Key present: {}", model, apiUrl,
                (apiKey != null && !apiKey.isEmpty()));

        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.set("Authorization", "Bearer " + apiKey);

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", model);
            requestBody.put("messages", messages);
            // Pratik modunda cümle üretirken çeşitlilik için temperature yüksek olmalı
            // JSON formatı genelde bozulmaz, gerekirse 0.6-0.8 arası iyidir
            requestBody.put("temperature", 0.7);

            if (jsonResponse) {
                Map<String, String> responseFormat = new HashMap<>();
                responseFormat.put("type", "json_object");
                requestBody.put("response_format", responseFormat);
            }

            HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

            logger.info("Sending request to Groq...");
            ResponseEntity<Map> response = restTemplate.postForEntity(apiUrl, entity, Map.class);
            logger.info("Groq Response Status: {}", response.getStatusCode());

            if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
                Map body = response.getBody();
                List choices = (List) body.get("choices");
                if (choices != null && !choices.isEmpty()) {
                    Map choice = (Map) choices.get(0);
                    Map message = (Map) choice.get("message");
                    return (String) message.get("content");
                }
            }
        } catch (org.springframework.web.client.HttpClientErrorException
                | org.springframework.web.client.HttpServerErrorException e) {
            logger.error("Groq API Error: Status={}, Body={}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new RuntimeException("Groq API Error: " + e.getResponseBodyAsString());
        } catch (Exception e) {
            logger.error("Error calling Groq API", e);
            throw new RuntimeException("Failed to communicate with AI service: " + e.getMessage());
        }
        return null;
    }
}
