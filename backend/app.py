from flask import Flask, request, jsonify
from flask_cors import CORS
import os
from ollama_connector import OllamaConnector

app = Flask(__name__)
CORS(app)

# Get Ollama host from environment (Docker service name or localhost)
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost')
OLLAMA_PORT = os.getenv('OLLAMA_PORT', '11434')

print(f"🤖 Connecting to Ollama at {OLLAMA_HOST}:{OLLAMA_PORT}")

ollama = OllamaConnector(
    base_url=f"http://{OLLAMA_HOST}:{OLLAMA_PORT}"
)

@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

@app.route('/chat', methods=['POST'])
def chat():
    try:
        data = request.json
        prompt = data.get('prompt', '')
        session_id = data.get('session_id', 'default')

        if not prompt:
            return jsonify({"error": "Prompt is required"}), 400

        response = ollama.generate_response(prompt, session_id)
        return jsonify({"response": response, "session_id": session_id})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=False)
