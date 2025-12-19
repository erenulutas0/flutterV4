package com.ingilizce.calismaapp.config;

import com.corundumstudio.socketio.SocketIOServer;
import com.corundumstudio.socketio.Configuration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;

@org.springframework.context.annotation.Configuration
public class SocketIOConfig {

    @Value("${server.port:8082}")
    private int serverPort;

    @Bean
    public SocketIOServer socketIOServer() {
        Configuration config = new Configuration();
        config.setHostname("0.0.0.0");
        config.setPort(9092); // Socket.io için ayrı port
        config.setAllowHeaders("*");
        config.setOrigin("*"); // CORS için
        
        return new SocketIOServer(config);
    }
}

