#!/bin/bash
# RunPod'da Ollama API testi

echo "=== 1. Yüklü Modeller ==="
ollama list

echo ""
echo "=== 2. Ollama API Test (localhost) ==="
curl -s http://localhost:11434/api/tags | python3 -m json.tool 2>/dev/null || curl -s http://localhost:11434/api/tags

echo ""
echo "=== 3. Proxy URL Test (dışarıdan) ==="
echo "Browser'da şu URL'yi açın:"
echo "https://10hzcwap2o5n8e-11434.proxy.runpod.net/api/tags"
echo ""
echo "Veya terminal'den:"
curl -s https://10hzcwap2o5n8e-11434.proxy.runpod.net/api/tags | head -c 500

echo ""
echo ""
echo "=== 4. Model Adı Kontrolü ==="
echo "Model adı tam olarak 'qwen2.5:32b' olmalı (büyük/küçük harf duyarlı)"

