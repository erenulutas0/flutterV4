package com.ingilizce.calismaapp.service;

import org.springframework.stereotype.Service;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class MatchmakingService {
    
    // Kullanıcıları bekleyen kuyruk
    private final Queue<String> waitingQueue = new LinkedList<>();
    
    // Aktif eşleşmeler: userId -> matchedUserId
    private final Map<String, String> activeMatches = new ConcurrentHashMap<>();
    
    // Eşleşme bilgileri: roomId -> {user1, user2}
    private final Map<String, MatchInfo> matchRooms = new ConcurrentHashMap<>();
    
    public static class MatchInfo {
        public String user1;
        public String user2;
        public String roomId;
        public long createdAt;
        
        public MatchInfo(String user1, String user2, String roomId) {
            this.user1 = user1;
            this.user2 = user2;
            this.roomId = roomId;
            this.createdAt = System.currentTimeMillis();
        }
    }
    
    /**
     * Kullanıcıyı eşleşme kuyruğuna ekler
     * @param userId Kullanıcı ID'si
     * @return Eğer eşleşme bulunduysa MatchInfo, yoksa null
     */
    public synchronized MatchInfo joinQueue(String userId) {
        // Eğer kullanıcı zaten eşleşmişse, mevcut eşleşmeyi döndür
        if (activeMatches.containsKey(userId)) {
            String matchedUserId = activeMatches.get(userId);
            String roomId = generateRoomId(userId, matchedUserId);
            return matchRooms.get(roomId);
        }
        
        // Kuyrukta bekleyen biri var mı?
        if (!waitingQueue.isEmpty()) {
            String matchedUserId = waitingQueue.poll();
            String roomId = generateRoomId(userId, matchedUserId);
            
            MatchInfo match = new MatchInfo(userId, matchedUserId, roomId);
            matchRooms.put(roomId, match);
            activeMatches.put(userId, matchedUserId);
            activeMatches.put(matchedUserId, userId);
            
            return match;
        }
        
        // Kuyrukta kimse yoksa, kullanıcıyı kuyruğa ekle
        waitingQueue.offer(userId);
        return null;
    }
    
    /**
     * Kullanıcıyı kuyruktan çıkarır
     */
    public synchronized void leaveQueue(String userId) {
        waitingQueue.remove(userId);
        activeMatches.remove(userId);
        
        // Eşleşmeyi temizle
        matchRooms.entrySet().removeIf(entry -> 
            entry.getValue().user1.equals(userId) || entry.getValue().user2.equals(userId)
        );
    }
    
    /**
     * Eşleşme bilgisini getirir
     */
    public MatchInfo getMatch(String userId) {
        String matchedUserId = activeMatches.get(userId);
        if (matchedUserId == null) {
            return null;
        }
        
        String roomId = generateRoomId(userId, matchedUserId);
        return matchRooms.get(roomId);
    }
    
    /**
     * Eşleşmeyi sonlandırır
     */
    public synchronized void endMatch(String userId) {
        String matchedUserId = activeMatches.remove(userId);
        if (matchedUserId != null) {
            activeMatches.remove(matchedUserId);
            String roomId = generateRoomId(userId, matchedUserId);
            matchRooms.remove(roomId);
        }
    }
    
    /**
     * Room ID oluşturur (her zaman aynı sırada)
     */
    private String generateRoomId(String user1, String user2) {
        // Alfabetik sıralama ile tutarlı room ID
        String[] users = {user1, user2};
        Arrays.sort(users);
        return "room_" + users[0] + "_" + users[1];
    }
    
    /**
     * Kuyruk durumunu getirir
     */
    public int getQueueSize() {
        return waitingQueue.size();
    }
}

