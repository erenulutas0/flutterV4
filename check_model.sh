#!/bin/bash
# RunPod'da model kontrolü

echo "=== Yüklü Modeller ==="
ollama list

echo ""
echo "=== Ollama API Test ==="
curl -s http://localhost:11434/api/tags | python3 -m json.tool 2>/dev/null || curl -s http://localhost:11434/api/tags

echo ""
echo "=== Model Yükleme (eğer yoksa) ==="
echo "Eğer qwen2.5:32b yoksa, şu komutu çalıştırın:"
echo "ollama pull qwen2.5:32b"

