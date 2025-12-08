# Computation Identification Package

A Python package for identifying and verifying AI model computations using sequential hashing of activations.

## Features

- **Model Selection**: Choose from multiple ~1B parameter models
- **Chat Interface**: Interactive conversation with models
- **Hash Verification**: Verify that responses came from the intended model
- **Conversation History**: Track all inputs, seeds, and hashes

## Quick Start

### Installation

Make sure you have the virtual environment activated and dependencies installed:

```powershell
cd ComputationIdentification
.\venv\Scripts\Activate.ps1
```

### Running the Chat Interface

**Option 1: Run the chat interface**
```powershell
python chat.py
```

**Option 2: Run with a specific model**
```powershell
python chat.py mistral-7b
```

**Option 3: Run with GPU and quantization (for large models)**
```powershell
# 4-bit quantization (most memory efficient, recommended for 13B+ models)
python chat.py llama2-13b --4bit

# 8-bit quantization (good balance)
python chat.py mistral-7b --8bit

# Force CPU (if no GPU available)
python chat.py phi-2 --cpu
```

**Option 4: Use as a package**
```python
from ComputationIdentification.chat import run_chat_interface
run_chat_interface(model_key="mistral-7b", use_gpu=True, load_in_4bit=True)
```

## Available Models (GPU Recommended)

### Recommended Models (Best Coherence)

- `mistral-7b` - Mistral 7B (~7B params) - **Highly recommended for coherence**
- `llama2-7b` - Llama 2 7B (~7B params) - Requires HuggingFace auth
- `llama2-13b` - Llama 2 13B (~13B params) - Best coherence, requires 4-bit/8-bit on most GPUs
- `phi-2` - Microsoft Phi-2 (~2.7B params) - Surprisingly coherent for its size

### Alternative Models

- `falcon-7b` - Falcon 7B (~7B params)
- `qwen-7b` - Qwen 7B (~7B params)
- `gpt-neo-2.7b` - GPT-Neo 2.7B (~2.7B params)
- `opt-6.7b` - OPT 6.7B (~6.7B params)

## GPU Support

The package automatically uses GPU if available. For large models (13B+), use quantization:

```powershell
# 4-bit quantization (recommended for 13B models on 16GB GPU)
python run_chat.py llama2-13b --4bit

# 8-bit quantization (for 7B models on 8GB GPU)
python run_chat.py mistral-7b --8bit
```

**GPU Memory Requirements:**
- 7B models: ~14GB VRAM (full precision) or ~4-6GB (4-bit)
- 13B models: ~26GB VRAM (full precision) or ~7-9GB (4-bit)
- 2.7B models: ~6GB VRAM (full precision)

## Usage

### Chat Commands

- Type your message and press Enter to chat
- `quit` or `exit` - End conversation and verify all responses
- `history` - Show conversation history
- `clear` - Clear conversation history

### How It Works

1. **Input Processing**: When you send a message, the system:
   - Generates a random seed for that turn
   - Processes your input through the model
   - Captures activations from all layers
   - Computes a sequential hash: `hash(input+seed) -> hash with each layer -> hash with output`

2. **Storage**: Each conversation turn stores:
   - Your input text
   - The random seed used
   - The computed hash
   - The model's output

3. **Verification**: When you end the conversation:
   - All stored inputs are reprocessed with their original seeds
   - Hashes are regenerated
   - The system verifies that all hashes match
   - This confirms all responses came from the intended model

## Example

```
You: Hello, how are you?
Model: I'm doing well, thank you for asking! How can I help you today?

You: What is AI regulation?
Model: AI regulation refers to the laws, policies, and guidelines...

You: quit

[Verification runs automatically]
✓ ALL CONVERSATION TURNS VERIFIED SUCCESSFULLY
```

## Package Structure

```
ComputationIdentification/
├── __init__.py              # Package initialization
├── model_activations.py     # Core model wrapper with activation extraction
├── models.py                # Model definitions and selection
├── chat.py                  # Chat interface
├── verification.py          # Hash verification logic
├── main.py                  # Main entry point
└── run_chat.py             # Standalone chat script
```

## API Usage

```python
from ComputationIdentification import ModelWithActivations, ChatInterface

# Direct model usage
model = ModelWithActivations(model_name="EleutherAI/gpt-neo-1.3B")
hash_value, output = model.compute_sequential_hash("Hello", seed=42)

# Chat interface
chat = ChatInterface(model_key="gpt-neo-1.3b")
response = chat.chat("Hello!")
# Verify conversation
from ComputationIdentification import verify_conversation
verify_conversation(chat.model, chat.conversation_history)
```

## Notes

- First run will download the selected model (may take 10-30 minutes)
- Models are cached for subsequent runs
- Verification ensures computational integrity of all responses
- All hashes are deterministic given the same input and seed

