import requests
import json
from typing import List, Dict, Optional

class OllamaConnector:
    def __init__(self, base_url: str = "http://localhost:11434"):
        self.base_url = base_url
        self.api_url = f"{base_url}/api"
        print(f"🔗 OllamaConnector initialized with base_url: {base_url}")

        # Test connection
        try:
            self._test_connection()
        except Exception as e:
            print(f"⚠️  Warning: Could not connect to Ollama: {e}")

    def _test_connection(self):
        """Test if Ollama is accessible"""
        response = requests.get(f"{self.api_url}/tags", timeout=5)
        response.raise_for_status()
        print(f"✅ Successfully connected to Ollama at {self.base_url}")

    def list_models(self) -> List[str]:
        """List available models"""
        try:
            response = requests.get(f"{self.api_url}/tags", timeout=5)
            response.raise_for_status()
            models = response.json().get("models", [])
            model_names = [model["name"] for model in models]
            print(f"📦 Found {len(model_names)} models: {model_names}")
            return model_names
        except requests.exceptions.RequestException as e:
            print(f"❌ Error listing models: {e}")
            raise Exception(f"Cannot connect to Ollama at {self.base_url}. Is it running?")

    def chat(
        self,
        message: str,
        model: str = "llama2",
        context: Optional[List[Dict]] = None
    ) -> str:
        """
        Send a chat message to Ollama

        Args:
            message: User's message
            model: Model name (default: llama2)
            context: Previous conversation messages

        Returns:
            String response from the model
        """
        try:
            # Build messages array
            messages = []

            # Add context if provided
            if context:
                for msg in context:
                    messages.append({
                        "role": msg.get("role", "user"),
                        "content": msg.get("content", "")
                    })

            # Add current message
            messages.append({
                "role": "user",
                "content": message
            })

            # Call Ollama API
            payload = {
                "model": model,
                "messages": messages,
                "stream": False
            }

            print(f"📤 Sending to Ollama: {self.api_url}/chat")
            print(f"📦 Model: {model}, Messages: {len(messages)}")

            response = requests.post(
                f"{self.api_url}/chat",
                json=payload,
                timeout=120
            )

            response.raise_for_status()

            result = response.json()
            content = result.get("message", {}).get("content", "No response")

            print(f"✅ Received response ({len(content)} chars)")

            return content

        except requests.exceptions.ConnectionError:
            error_msg = f"Cannot connect to Ollama at {self.base_url}. Is the service running?"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
        except requests.exceptions.Timeout:
            error_msg = "Ollama request timed out (>120s)"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
        except requests.exceptions.HTTPError as e:
            error_msg = f"Ollama API error: {e.response.status_code} - {e.response.text}"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
        except Exception as e:
            error_msg = f"Error communicating with Ollama: {str(e)}"
            print(f"❌ {error_msg}")
            raise Exception(error_msg)
