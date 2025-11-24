#!/bin/bash
set -e

echo "🚀 Starting Ollama Chat App (Development Mode)"

# Start services
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

echo "⏳ Waiting for services to be healthy..."
sleep 10

# Pull required models
echo "📦 Ensuring Ollama models are available..."
docker exec ollama-service ollama pull llama2

echo "✅ Development environment ready!"
echo ""
echo "📊 Service URLs:"
echo "   Frontend:  http://localhost:3000"
echo "   Backend:   http://localhost:8000"
echo "   Ollama:    http://localhost:11434"
echo ""
echo "📝 View logs: docker-compose logs -f"
echo "🛑 Stop services: ./scripts/stop-dev.sh"
