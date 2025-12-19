# Flutter Web Dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy source code
COPY . .

# Build Flutter web app
RUN flutter build web --release

# Copy webrtc.js to build/web (Flutter build may not copy all web files)
# Remove old file first, then copy new one to ensure latest version
# Verify the copy worked
RUN rm -f build/web/webrtc.js && \
    cp web/webrtc.js build/web/webrtc.js && \
    ls -lh build/web/webrtc.js && \
    head -n 5 build/web/webrtc.js && \
    grep -n "constructor.*role" build/web/webrtc.js | head -1

# Production stage with nginx
FROM nginx:alpine

# Copy built web files
COPY --from=build /app/build/web /usr/share/nginx/html

# Overwrite webrtc.js with the latest version from build stage
COPY --from=build /app/build/web/webrtc.js /usr/share/nginx/html/webrtc.js

# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]


