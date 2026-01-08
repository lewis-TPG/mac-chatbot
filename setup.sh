#!/bin/bash

# setup.sh

echo "Setting up Ollama Chat..."

# Install Ollama if not installed
if ! command -v ollama &> /dev/null; then
    echo "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "Ollama is already installed"
fi

# Start Ollama service
echo "Starting Ollama..."
brew services start ollama 2>/dev/null || ollama serve &

# Wait for Ollama to start
echo "Waiting for Ollama to start..."
sleep 3

# Check if Ollama is running
if curl -s http://localhost:11434/api/tags > /dev/null; then
    echo "✅ Ollama is running"
else
    echo "❌ Ollama failed to start. Trying to start manually..."
    pkill -f ollama
    ollama serve &
    sleep 2
fi

# Pull a default model if not present
echo "Checking for models..."
if ! ollama list | grep -q "llama3.2"; then
    echo "Downloading llama3.2 model..."
    ollama pull llama3.2
else
    echo "Model already downloaded"
fi

echo "✅ Setup complete!"
echo "Open the OllamaChat.xcodeproj and press Cmd+R to run"