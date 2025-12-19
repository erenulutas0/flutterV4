#!/bin/bash
# RunPod'da Ollama durumunu kontrol etmek için

echo "=== Ollama Process Check ==="
ps aux | grep ollama | grep -v grep

echo ""
echo "=== Port 11434 Check ==="
ss -tuln | grep 11434 || netstat -tuln | grep 11434

echo ""
echo "=== Ollama API Test ==="
curl -s http://localhost:11434/api/tags || echo "Ollama API'ye erişilemiyor"

echo ""
echo "=== Environment Variables ==="
echo "OLLAMA_HOST: $OLLAMA_HOST"

echo ""
echo "=== Model List ==="
ollama list

