"""
Chat interface for interacting with models and storing conversation history.
"""

import random
from typing import List, Dict, Optional
try:
    from .model_activations import ModelWithActivations
    from .models import AVAILABLE_MODELS, get_model_info
except ImportError:
    # Allow running as standalone script
    from model_activations import ModelWithActivations
    from models import AVAILABLE_MODELS, get_model_info


class ConversationEntry:
    """Represents a single conversation turn."""
    
    def __init__(self, input_text: str, seed: int, hash_value: str, output_text: str):
        self.input_text = input_text
        self.seed = seed
        self.hash_value = hash_value
        self.output_text = output_text
    
    def to_dict(self) -> Dict:
        """Convert to dictionary."""
        return {
            "input": self.input_text,
            "seed": self.seed,
            "hash": self.hash_value,
            "output": self.output_text,
        }


class ChatInterface:
    """Chat interface for model interaction with hash verification."""
    
    def __init__(self, model_key: str, max_length: int = 100, device: Optional[str] = None,
                 use_gpu: bool = True, load_in_8bit: bool = False, load_in_4bit: bool = False):
        """
        Initialize the chat interface with GPU support.
        
        Args:
            model_key: Key from AVAILABLE_MODELS
            max_length: Maximum generation length
            device: Device to use ('cuda', 'cpu', or None for auto)
            use_gpu: Whether to prefer GPU (default: True)
            load_in_8bit: Load model in 8-bit mode for memory efficiency
            load_in_4bit: Load model in 4-bit mode for memory efficiency (most memory efficient)
        """
        if model_key not in AVAILABLE_MODELS:
            raise ValueError(f"Unknown model: {model_key}. Available: {list(AVAILABLE_MODELS.keys())}")
        
        model_info = get_model_info(model_key)
        self.model_key = model_key
        self.model_name = model_info["name"]
        self.max_length = max_length
        self.device = device
        
        print(f"\nInitializing model: {model_info['description']}")
        print(f"Model: {self.model_name}")
        print(f"Parameters: {model_info['params']}")
        
        # Check for authentication requirement
        if model_info.get("requires_auth", False):
            print("\n⚠️  This model requires HuggingFace authentication.")
            print("   Set your token with: huggingface-cli login")
            print("   Or set environment variable: HF_TOKEN=your_token")
        
        print("This may take a few minutes on first run...\n")
        
        # Initialize model with GPU support
        self.model = ModelWithActivations(
            model_name=self.model_name,
            device=device,
            use_gpu=use_gpu,
            load_in_8bit=load_in_8bit,
            load_in_4bit=load_in_4bit
        )
        
        # Conversation history
        self.conversation_history: List[ConversationEntry] = []
        
        print("Model ready! You can start chatting.\n")
    
    def chat(self, user_input: str) -> str:
        """
        Process a user input and return model response with hash.
        
        Args:
            user_input: User's input text
        
        Returns:
            Model's response text
        """
        # Generate random seed for this turn
        seed = random.randint(0, 2**31 - 1)
        
        # Compute hash and get response
        hash_value, output_text = self.model.compute_sequential_hash(
            text=user_input,
            seed=seed,
            max_length=self.max_length
        )
        
        # Store in conversation history
        entry = ConversationEntry(
            input_text=user_input,
            seed=seed,
            hash_value=hash_value,
            output_text=output_text
        )
        self.conversation_history.append(entry)
        
        return output_text
    
    def get_conversation_history(self) -> List[Dict]:
        """Get conversation history as list of dictionaries."""
        return [entry.to_dict() for entry in self.conversation_history]
    
    def print_conversation_summary(self):
        """Print a summary of the conversation."""
        print("\n" + "=" * 60)
        print("Conversation Summary")
        print("=" * 60)
        print(f"Total turns: {len(self.conversation_history)}")
        print(f"Model: {self.model_name}")
        print("\nConversation:")
        for i, entry in enumerate(self.conversation_history, 1):
            print(f"\nTurn {i}:")
            print(f"  Input:  {entry.input_text}")
            print(f"  Seed:    {entry.seed}")
            print(f"  Hash:    {entry.hash_value[:32]}...")
            print(f"  Output:  {entry.output_text[:100]}..." if len(entry.output_text) > 100 else f"  Output:  {entry.output_text}")
        print("=" * 60)


def run_chat_interface(model_key: Optional[str] = None, use_gpu: bool = True, 
                      load_in_8bit: bool = False, load_in_4bit: bool = False):
    """
    Run an interactive chat interface with GPU support.
    
    Args:
        model_key: Model to use (if None, will prompt for selection)
        use_gpu: Whether to prefer GPU (default: True)
        load_in_8bit: Load model in 8-bit mode for memory efficiency
        load_in_4bit: Load model in 4-bit mode for memory efficiency (recommended for 13B+ models)
    """
    # Model selection
    if model_key is None:
        print("\n" + "=" * 60)
        print("Model Selection")
        print("=" * 60)
        try:
            from .models import list_models
        except ImportError:
            from models import list_models
        list_models()
        
        while True:
            choice = input("\nEnter model key (or 'q' to quit): ").strip().lower()
            if choice == 'q':
                return
            if choice in AVAILABLE_MODELS:
                model_key = choice
                break
            print(f"Invalid choice. Please select from: {list(AVAILABLE_MODELS.keys())}")
    
    # Initialize chat interface
    try:
        chat = ChatInterface(
            model_key=model_key,
            use_gpu=use_gpu,
            load_in_8bit=load_in_8bit,
            load_in_4bit=load_in_4bit
        )
    except Exception as e:
        print(f"Error initializing model: {e}")
        import traceback
        traceback.print_exc()
        return
    
    # Chat loop
    print("\n" + "=" * 60)
    print("Chat Interface")
    print("=" * 60)
    print("Type your messages. Commands:")
    print("  'quit' or 'exit' - End conversation and verify")
    print("  'history' - Show conversation history")
    print("  'clear' - Clear conversation history")
    print("=" * 60 + "\n")
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if not user_input:
                continue
            
            # Handle commands
            if user_input.lower() in ['quit', 'exit']:
                break
            elif user_input.lower() == 'history':
                chat.print_conversation_summary()
                continue
            elif user_input.lower() == 'clear':
                chat.conversation_history.clear()
                print("Conversation history cleared.\n")
                continue
            
            # Get model response
            print("Model: ", end="", flush=True)
            response = chat.chat(user_input)
            print(response)
            print()  # Blank line for readability
            
        except KeyboardInterrupt:
            print("\n\nInterrupted by user.")
            break
        except Exception as e:
            print(f"Error: {e}\n")
    
    # End of conversation
    if chat.conversation_history:
        print("\n" + "=" * 60)
        print("End of Conversation")
        print("=" * 60)
        chat.print_conversation_summary()
        
        # Verify conversation
        print("\n" + "=" * 60)
        print("Verifying Conversation")
        print("=" * 60)
        try:
            from .verification import verify_conversation
        except ImportError:
            from verification import verify_conversation
        verify_conversation(chat.model, chat.conversation_history)
    else:
        print("\nNo conversation to verify.")


if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Run chat interface with GPU support")
    parser.add_argument("model_key", nargs="?", help="Model key to use (optional)")
    parser.add_argument("--cpu", action="store_true", help="Force CPU usage (disable GPU)")
    parser.add_argument("--8bit", action="store_true", dest="bit8", help="Load model in 8-bit mode (memory efficient)")
    parser.add_argument("--4bit", action="store_true", dest="bit4", help="Load model in 4-bit mode (most memory efficient)")
    
    args = parser.parse_args()
    
    model_key = args.model_key
    if model_key and model_key not in AVAILABLE_MODELS:
        print(f"Unknown model: {model_key}")
        print("\nAvailable models:")
        try:
            from .models import list_models
        except ImportError:
            from models import list_models
        list_models()
        exit(1)
    
    use_gpu = not args.cpu
    load_in_8bit = args.bit8
    load_in_4bit = args.bit4
    
    if load_in_4bit and load_in_8bit:
        print("Error: Cannot use both 4-bit and 8-bit quantization. Choose one.")
        exit(1)
    
    run_chat_interface(
        model_key=model_key,
        use_gpu=use_gpu,
        load_in_8bit=load_in_8bit,
        load_in_4bit=load_in_4bit
    )

