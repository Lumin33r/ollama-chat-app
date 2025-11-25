from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import traceback

app = Flask(__name__)
CORS(app)

# Get Ollama host from environment variable
OLLAMA_HOST = os.getenv('OLLAMA_HOST', 'localhost')
OLLAMA_PORT = os.getenv('OLLAMA_PORT', '11434')

print(f"🤖 Connecting to Ollama at {OLLAMA_HOST}:{OLLAMA_PORT}")

# Try to import OllamaConnector
try:
    from ollama_connector import OllamaConnector
    ollama = OllamaConnector(base_url=f"http://{OLLAMA_HOST}:{OLLAMA_PORT}")
    print("✅ OllamaConnector initialized successfully")
except ImportError as e:
    print(f"❌ Error importing OllamaConnector: {e}")
    print("⚠️  Running without OllamaConnector - creating stub")
    ollama = None
except Exception as e:
    print(f"❌ Error initializing OllamaConnector: {e}")
    ollama = None

@app.route('/')
def index():
    """Root endpoint"""
    return jsonify({
        "message": "Ollama Chat API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "health": "/health",
            "chat": "/api/chat (POST)",
            "models": "/api/models (GET)"
        }
    }), 200

@app.route('/health')
def health_check():
    """Health check endpoint"""
    try:
        if ollama is None:
            return jsonify({
                "status": "unhealthy",
                "ollama_connected": False,
                "error": "Ollama connector not initialized"
            }), 503
        
        # Check if Ollama is accessible
        models = ollama.list_models()
        return jsonify({
            "status": "healthy",
            "ollama_connected": True,
            "ollama_host": f"{OLLAMA_HOST}:{OLLAMA_PORT}",
            "models_available": len(models) if models else 0
        }), 200
    except Exception as e:
        return jsonify({
            "status": "degraded",
            "ollama_connected": False,
            "error": str(e)
        }), 503

@app.route('/api/models', methods=['GET'])
def list_models():
    """List available Ollama models"""
    try:
        if ollama is None:
            return jsonify({
                "error": "Ollama connector not initialized",
                "models": []
            }), 503
        
        models = ollama.list_models()
        return jsonify({
            "models": models,
            "count": len(models)
        }), 200
    except Exception as e:
        print(f"❌ Error listing models: {str(e)}")
        traceback.print_exc()
        return jsonify({
            "error": str(e),
            "models": []
        }), 500

@app.route('/api/chat', methods=['POST'])
def chat():
    """Chat endpoint - send message to Ollama"""
    try:
        if ollama is None:
            return jsonify({
                "error": "Ollama connector not initialized"
            }), 503
        
        data = request.json
        
        # Validate request
        if not data:
            return jsonify({
                "error": "No JSON data provided"
            }), 400
        
        prompt = data.get('prompt', '')
        model = data.get('model', 'llama2')
        conversation_id = data.get('conversation_id', 'default')
        context = data.get('messages', [])
        
        if not prompt:
            return jsonify({
                "error": "Prompt is required"
            }), 400
        
        print(f"💬 Chat request - Model: {model}, Prompt: {prompt[:50]}...")
        
        # Call Ollama
        response = ollama.chat(
            message=prompt,
            model=model,
            context=context
        )
        
        print(f"✅ Got response: {response[:100]}...")
        
        return jsonify({
            "response": response,
            "conversation_id": conversation_id,
            "model": model
        }), 200
    
    except Exception as e:
        print(f"❌ Error in chat endpoint: {str(e)}")
        traceback.print_exc()
        
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({
        "error": "Not Found",
        "message": "The requested endpoint does not exist",
        "available_endpoints": {
            "root": "/ (GET)",
            "health": "/health (GET)",
            "chat": "/api/chat (POST)",
            "models": "/api/models (GET)"
        }
    }), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    return jsonify({
        "error": "Internal Server Error",
        "message": str(error)
    }), 500

if __name__ == '__main__':
    print("=" * 60)
    print("🚀 Starting Flask server...")
    print(f"📡 Ollama host: {OLLAMA_HOST}:{OLLAMA_PORT}")
    print(f"🔌 Listening on: 0.0.0.0:8000")
    print("=" * 60)
    app.run(host='0.0.0.0', port=8000, debug=True)
