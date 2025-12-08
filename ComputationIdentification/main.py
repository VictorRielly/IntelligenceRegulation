"""
Main entry point for the Computation Identification package.
"""

import sys
from .chat import run_chat_interface
from .models import list_models, AVAILABLE_MODELS


def main():
    """Main entry point."""
    if len(sys.argv) > 1:
        model_key = sys.argv[1]
        if model_key not in AVAILABLE_MODELS:
            print(f"Unknown model: {model_key}")
            print("\nAvailable models:")
            list_models()
            sys.exit(1)
    else:
        model_key = None
    
    run_chat_interface(model_key=model_key)


if __name__ == "__main__":
    main()

