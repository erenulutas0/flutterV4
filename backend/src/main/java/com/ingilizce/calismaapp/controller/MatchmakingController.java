package com.ingilizce.calismaapp.controller;

import com.corundumstudio.socketio.SocketIOClient;
import com.corundumstudio.socketio.SocketIOServer;
import com.ingilizce.calismaapp.service.MatchmakingService;
import com.ingilizce.calismaapp.service.MatchmakingService.MatchInfo;
import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Component
public class MatchmakingController {
    
    @Autowired
    private SocketIOServer socketIOServer;
    
    @Autowired
    private MatchmakingService matchmakingService;
    
    // userId -> client mapping
    private final Map<String, SocketIOClient> userIdToClient = new ConcurrentHashMap<>();
    
    @PostConstruct
    public void startSocketIOServer() {
        // Event listener'ları manuel olarak ekle
        socketIOServer.addConnectListener(client -> {
            System.out.println("=== CLIENT CONNECTED ===");
            System.out.println("Session ID: " + client.getSessionId());
            System.out.println("Remote Address: " + client.getRemoteAddress());
        });
        
        socketIOServer.addDisconnectListener(client -> {
            String userId = client.get("userId");
            if (userId != null) {
                System.out.println("Client disconnected: " + userId);
                
                // Eğer aktif bir eşleşme varsa, diğer kullanıcıya bildir
                MatchInfo match = matchmakingService.getMatch(userId);
                if (match != null) {
                    String matchedUserId = match.user1.equals(userId) ? match.user2 : match.user1;
                    SocketIOClient matchedClient = userIdToClient.get(matchedUserId);
                    if (matchedClient != null) {
                        // Room'dan çıkar
                        matchedClient.leaveRoom(match.roomId);
                        // call_ended event'i gönder
                        matchedClient.sendEvent("call_ended");
                        System.out.println("Sent call_ended to matched user: " + matchedUserId + " in room: " + match.roomId);
                    }
                    // Eşleşmeyi sonlandır
                    matchmakingService.endMatch(userId);
                }
                
                matchmakingService.leaveQueue(userId);
                userIdToClient.remove(userId); // Client'ı map'ten kaldır
            } else {
                System.out.println("Client disconnected: " + client.getSessionId() + " (userId not set)");
            }
        });
        
        // join_queue event listener
        socketIOServer.addEventListener("join_queue", Map.class, (client, data, ackRequest) -> {
            System.out.println("=== join_queue event received ===");
            System.out.println("Data: " + data);
            System.out.println("Client SessionId: " + client.getSessionId());
            
            String userId = null;
            if (data.get("userId") != null) {
                userId = data.get("userId").toString();
            }
            
            if (userId == null || userId.isEmpty()) {
                userId = client.getSessionId().toString();
            }
            
            System.out.println("User ID: " + userId);
            
            client.set("userId", userId);
            userIdToClient.put(userId, client); // Client mapping'i ekle
            
            MatchInfo match = matchmakingService.joinQueue(userId);
            
            System.out.println("Match result: " + (match != null ? "FOUND" : "WAITING"));
            System.out.println("Queue size: " + matchmakingService.getQueueSize());
            
            Map<String, Object> response = new HashMap<>();
            
            if (match != null) {
                // Eşleşme bulundu!
                System.out.println("Match found! Room: " + match.roomId);
                String matchedUserId = match.user1.equals(userId) ? match.user2 : match.user1;
                
                // Rolleri belirle: user1 caller (arayan), user2 callee (aranan)
                // user1 (kuyrukta bekleyen) caller olur, user2 (yeni gelen) callee olur
                String callerUserId = match.user1; // İlk kuyruğa giren
                String calleeUserId = match.user2; // İkinci gelen
                
                // Caller'a (user1) bildir
                Map<String, Object> response1 = new HashMap<>();
                response1.put("status", "matched");
                response1.put("roomId", match.roomId);
                response1.put("matchedUserId", matchedUserId);
                String role1 = callerUserId.equals(userId) ? "caller" : "callee";
                response1.put("role", role1);
                System.out.println("DEBUG: response1 map contents: " + response1);
                System.out.println("DEBUG: response1.get('role'): " + response1.get("role"));
                client.sendEvent("match_found", response1);
                System.out.println("Sent match_found event to user: " + userId + " with role: " + role1 + " (callerUserId: " + callerUserId + ", userId: " + userId + ")");
                
                // Callee'ye (user2) bildir
                SocketIOClient matchedClient = userIdToClient.get(matchedUserId);
                if (matchedClient != null) {
                    Map<String, Object> response2 = new HashMap<>();
                    response2.put("status", "matched");
                    response2.put("roomId", match.roomId);
                    response2.put("matchedUserId", userId);
                    String role2 = calleeUserId.equals(matchedUserId) ? "callee" : "caller";
                    response2.put("role", role2);
                    System.out.println("DEBUG: response2 map contents: " + response2);
                    System.out.println("DEBUG: response2.get('role'): " + response2.get("role"));
                    matchedClient.sendEvent("match_found", response2);
                    System.out.println("Sent match_found event to user: " + matchedUserId + " with role: " + role2 + " (calleeUserId: " + calleeUserId + ", matchedUserId: " + matchedUserId + ")");
                } else {
                    System.out.println("WARNING: Matched client not found for userId: " + matchedUserId);
                }
            } else {
                // Kuyrukta bekliyor
                response.put("status", "waiting");
                response.put("queueSize", matchmakingService.getQueueSize());
                client.sendEvent("queue_status", response);
                System.out.println("Sent queue_status event to client");
            }
        });
        
        // leave_queue event listener
        socketIOServer.addEventListener("leave_queue", String.class, (client, data, ackRequest) -> {
            String userId = client.get("userId");
            if (userId != null) {
                matchmakingService.leaveQueue(userId);
            }
        });
        
        // join_room event listener
        socketIOServer.addEventListener("join_room", Map.class, (client, data, ackRequest) -> {
            String roomId = (String) data.get("roomId");
            String userId = client.get("userId");
            
            if (roomId != null && userId != null) {
                client.joinRoom(roomId);
                System.out.println("User " + userId + " joined room " + roomId);
            }
        });
        
        // WebRTC offer event listener
        socketIOServer.addEventListener("webrtc_offer", Map.class, (client, data, ackRequest) -> {
            System.out.println("=== WebRTC OFFER EVENT RECEIVED ===");
            System.out.println("Raw data: " + data);
            System.out.println("Data type: " + (data != null ? data.getClass().getName() : "null"));
            
            String roomId = (String) data.get("roomId");
            String userId = client.get("userId");
            
            System.out.println("WebRTC offer received from " + userId + " in room " + roomId);
            
            Object offerObj = data.get("offer");
            System.out.println("Offer object: " + offerObj);
            System.out.println("Offer type: " + (offerObj != null ? offerObj.getClass().getName() : "null"));
            
            // Offer'ı diğer kullanıcıya ilet
            Map<String, Object> offerData = new HashMap<>();
            offerData.put("offer", offerObj);
            offerData.put("from", userId);
            
            System.out.println("Sending offer to room: " + roomId);
            socketIOServer.getRoomOperations(roomId).sendEvent("webrtc_offer", offerData);
            System.out.println("Offer sent to room: " + roomId);
        });
        
        // WebRTC answer event listener
        socketIOServer.addEventListener("webrtc_answer", Map.class, (client, data, ackRequest) -> {
            System.out.println("=== WebRTC ANSWER EVENT RECEIVED ===");
            System.out.println("Raw data: " + data);
            
            String roomId = (String) data.get("roomId");
            String userId = client.get("userId");
            
            System.out.println("WebRTC answer received from " + userId + " in room " + roomId);
            
            Object answerObj = data.get("answer");
            System.out.println("Answer object: " + answerObj);
            
            // Answer'ı diğer kullanıcıya ilet
            Map<String, Object> answerData = new HashMap<>();
            answerData.put("answer", answerObj);
            answerData.put("from", userId);
            
            System.out.println("Sending answer to room: " + roomId);
            socketIOServer.getRoomOperations(roomId).sendEvent("webrtc_answer", answerData);
            System.out.println("Answer sent to room: " + roomId);
        });
        
        // WebRTC ICE candidate event listener
        socketIOServer.addEventListener("webrtc_ice_candidate", Map.class, (client, data, ackRequest) -> {
            String roomId = (String) data.get("roomId");
            String userId = client.get("userId");
            
            Object candidateObj = data.get("candidate");
            
            // ICE candidate'ı diğer kullanıcıya ilet
            Map<String, Object> candidateData = new HashMap<>();
            candidateData.put("candidate", candidateObj);
            candidateData.put("from", userId);
            
            socketIOServer.getRoomOperations(roomId).sendEvent("webrtc_ice_candidate", candidateData);
        });
        
        // end_call event listener
        socketIOServer.addEventListener("end_call", Map.class, (client, data, ackRequest) -> {
            String roomId = (String) data.get("roomId");
            String userId = client.get("userId");
            
            if (userId != null) {
                matchmakingService.endMatch(userId);
                
                // Diğer kullanıcıya bildir
                socketIOServer.getRoomOperations(roomId).sendEvent("call_ended");
                System.out.println("Call ended by user " + userId + " in room " + roomId);
            }
        });
        
        socketIOServer.start();
        System.out.println("Socket.IO server started on port 9092");
    }
    
    @PreDestroy
    public void stopSocketIOServer() {
        socketIOServer.stop();
    }
    
    // Tüm event listener'lar PostConstruct'ta manuel olarak ekleniyor
}

