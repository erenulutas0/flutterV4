package com.ingilizce.calismaapp.util;

import javax.net.ssl.*;
import java.security.cert.X509Certificate;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class SSLUtils {

    private static final Logger logger = LoggerFactory.getLogger(SSLUtils.class);

    public static void disableSSLVerification() {
        try {
            logger.warn("Disabling SSL Verification for Development environment...");

            // Create a trust manager that does not validate certificate chains
            TrustManager[] trustAllCerts = new TrustManager[] {
                    new X509TrustManager() {
                        public X509Certificate[] getAcceptedIssuers() {
                            return null;
                        }

                        public void checkClientTrusted(X509Certificate[] certs, String authType) {
                        }

                        public void checkServerTrusted(X509Certificate[] certs, String authType) {
                        }
                    }
            };

            // Install the all-trusting trust manager
            SSLContext sc = SSLContext.getInstance("TLS");
            sc.init(null, trustAllCerts, new java.security.SecureRandom());
            HttpsURLConnection.setDefaultSSLSocketFactory(sc.getSocketFactory());

            // Create all-trusting host name verifier
            HostnameVerifier allHostsValid = (hostname, session) -> true;
            HttpsURLConnection.setDefaultHostnameVerifier(allHostsValid);

            logger.warn("SSL Verification DISABLED! This is unsafe for production.");
        } catch (Exception e) {
            logger.error("Failed to disable SSL verification", e);
        }
    }
}
