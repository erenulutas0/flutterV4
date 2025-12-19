#!/bin/bash
# RunPod'da Ollama'nın 0.0.0.0:11434 üzerinde dinlediğini kontrol et

echo "=== Port 11434 Check (0.0.0.0 olmalı) ==="
ss -tuln | grep 11434

echo ""
echo "=== Ollama Process Check ==="
ps aux | grep ollama | grep -v grep

echo ""
echo "=== Ollama API Test (localhost) ==="
curl -s http://localhost:11434/api/tags | head -c 200

echo ""
echo ""
echo "=== Environment Variable ==="
echo "OLLAMA_HOST: $OLLAMA_HOST"

