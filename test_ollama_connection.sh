#!/bin/bash
# RunPod'da Ollama bağlantısını test et

echo "=== Pod IP Check ==="
hostname -I
ip addr show | grep "inet " | grep -v "127.0.0.1"

echo ""
echo "=== Ollama Local Test ==="
curl -s http://localhost:11434/api/tags | head -c 200

echo ""
echo ""
echo "=== Port 11434 Status ==="
ss -tuln | grep 11434

