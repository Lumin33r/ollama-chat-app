import requests
import json
from typing import Dict, Any

class OllamaConnector:
    def __init__(self, base_url="http://localhost:11434"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        print(f"🔗 OllamaConnector initialized: {base_url}")

    def generate_response(self, prompt: str, session_id: str = 'default') -> str:
        """Generate response from Ollama API"""
        try:
            payload = {
                "model": "llama2",  # Configure based on available models
                "prompt": prompt,
                "stream": False
            }

            response = requests.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=60
            )
            response.raise_for_status()

            result = response.json()
            return result.get('response', 'No response from model')

        except requests.exceptions.RequestException as e:
            raise Exception(f"Ollama API error: {str(e)}")
