# English Learning App - Flutter Web + Spring Boot

A comprehensive English learning application with video call features, chatbot, and vocabulary practice.

## Features

- 📚 Vocabulary learning with spaced repetition
- 💬 AI-powered chatbot for conversation practice
- 📞 Video call functionality with WebRTC
- 🎯 Matchmaking system for practice partners
- 🔊 Text-to-Speech (Piper TTS) integration
- 🎨 Modern Flutter web UI

## Tech Stack

- **Frontend**: Flutter Web
- **Backend**: Spring Boot
- **Database**: PostgreSQL
- **Cache**: Redis
- **AI**: Ollama (Qwen2.5:32b)
- **Video**: WebRTC
- **Containerization**: Docker & Docker Compose

## Prerequisites

- Docker & Docker Compose
- Flutter SDK (for local development)
- Java 17+ (for local backend development)
- PostgreSQL (for local development)
- Redis (for local development)
- Ollama (for AI chatbot)

## Setup

### 1. Clone the repository

```bash
git clone https://github.com/erenulutas0/flutterV4.git
cd flutterV4
```

### 2. Environment Configuration

Copy `.env.example` to `.env` and configure your settings:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:
- Database credentials
- Ollama API URL
- Piper TTS path (if using Windows)

### 3. Run with Docker Compose

```bash
docker-compose up -d
```

This will start:
- PostgreSQL on port 5432
- Redis on port 6379
- Spring Boot backend on port 8082
- Flutter web frontend on port 8080

### 4. Access the Application

- Frontend: http://localhost:8080
- Backend API: http://localhost:8082

## Development

### Backend Development

```bash
cd backend
./mvnw spring-boot:run
```

### Frontend Development

```bash
cd flutter_app
flutter run -d chrome
```

## Configuration

### Environment Variables

The application uses environment variables for sensitive configuration:

- `POSTGRES_USER`: PostgreSQL username (default: postgres)
- `POSTGRES_PASSWORD`: PostgreSQL password
- `LANGCHAIN4J_OLLAMA_CHAT_MODEL_BASE_URL`: Ollama API URL
- `LANGCHAIN4J_OLLAMA_CHAT_MODEL_MODEL_NAME`: Ollama model name
- `PIPER_TTS_PATH`: Path to Piper TTS executable

### Docker Compose

All services are configured in `docker-compose.yml`. Environment variables can be set in `.env` file or passed directly to docker-compose.

## Project Structure

```
.
├── backend/              # Spring Boot backend
│   ├── src/
│   └── Dockerfile
├── flutter_app/         # Flutter web frontend
│   ├── lib/
│   ├── web/
│   └── Dockerfile
├── docker-compose.yml   # Docker Compose configuration
├── .env.example        # Environment variables template
└── README.md
```

## Features in Detail

### Video Call System
- WebRTC-based peer-to-peer video calls
- Matchmaking system for finding practice partners
- Real-time signaling via Socket.io

### AI Chatbot
- Powered by Ollama (Qwen2.5:32b)
- Context-aware conversations
- English practice scenarios

### Vocabulary Learning
- Spaced repetition algorithm
- Word definitions and examples
- Sentence practice

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please open an issue on GitHub.


