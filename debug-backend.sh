#!/bin/bash

echo "🔍 Backend Debug Script"
echo "======================"
echo ""

cd ~/codeplatoon/projects/ollama-chat-app

echo "1. Checking backend files..."
if [ -f "backend/app.py" ]; then
    echo "   ✅ app.py exists"
else
    echo "   ❌ app.py missing!"
fi

if [ -f "backend/ollama_connector.py" ]; then
    echo "   ✅ ollama_connector.py exists"
else
    echo "   ❌ ollama_connector.py missing!"
fi

if [ -f "backend/Dockerfile" ]; then
    echo "   ✅ Dockerfile exists"
else
    echo "   ❌ Dockerfile missing!"
fi

if [ -f "backend/requirements.txt" ]; then
    echo "   ✅ requirements.txt exists"
else
    echo "   ❌ requirements.txt missing!"
fi

echo ""
echo "2. Checking Docker containers..."
docker ps -a | grep -E "ollama-backend|ollama-service" || echo "   ❌ No containers found"

echo ""
echo "3. Checking Docker images..."
docker images | grep ollama-chat-app

echo ""
echo "4. Checking port 8000..."
if sudo lsof -i :8000 > /dev/null 2>&1; then
    echo "   ⚠️  Port 8000 is in use:"
    sudo lsof -i :8000
else
    echo "   ✅ Port 8000 is available"
fi

echo ""
echo "5. Checking backend logs..."
if docker ps -a | grep -q ollama-backend; then
    echo "   Last 20 lines of backend logs:"
    docker logs ollama-backend --tail 20
else
    echo "   ❌ Backend container not found"
fi

echo ""
echo "6. Checking Ollama service..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "   ✅ Ollama service is accessible"
else
    echo "   ❌ Ollama service not accessible"
fi

echo ""
echo "======================"
echo "🔍 Debug complete"
