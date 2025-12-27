package com.ingilizce.calismaapp;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import com.ingilizce.calismaapp.util.SSLUtils;

@SpringBootApplication
public class CalismaAppApplication {

    public static void main(String[] args) {
        SSLUtils.disableSSLVerification();
        SpringApplication.run(CalismaAppApplication.class, args);
    }

}
