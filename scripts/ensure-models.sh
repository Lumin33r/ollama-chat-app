#!/bin/bash
REQUIRED_MODELS=("llama2" "mistral")

for model in "${REQUIRED_MODELS[@]}"; do
    echo "Checking model: $model"
    if ! docker exec ollama-service ollama list | grep -q "$model"; then
        echo "📦 Pulling $model..."
        docker exec ollama-service ollama pull "$model"
    else
        echo "✅ $model already available"
    fi
done
