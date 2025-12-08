"""
Model definitions for powerful language models with GPU support.
"""

AVAILABLE_MODELS = {
    # 7B parameter models (recommended for good coherence)
    "llama2-7b": {
        "name": "meta-llama/Llama-2-7b-hf",
        "description": "Llama 2 7B - Meta's Llama 2 with 7B parameters (requires HuggingFace auth)",
        "params": "~7B",
        "requires_auth": True,
    },
    "mistral-7b": {
        "name": "mistralai/Mistral-7B-v0.1",
        "description": "Mistral 7B - Mistral AI's 7B parameter model (highly coherent)",
        "params": "~7B",
        "requires_auth": False,
    },
    "phi-2": {
        "name": "microsoft/phi-2",
        "description": "Phi-2 - Microsoft's 2.7B parameter model (surprisingly coherent)",
        "params": "~2.7B",
        "requires_auth": False,
    },
    # 13B parameter models (best coherence, requires more GPU memory)
    "llama2-13b": {
        "name": "meta-llama/Llama-2-13b-hf",
        "description": "Llama 2 13B - Meta's Llama 2 with 13B parameters (requires HuggingFace auth)",
        "params": "~13B",
        "requires_auth": True,
    },
    # Alternative powerful models
    "falcon-7b": {
        "name": "tiiuae/falcon-7b",
        "description": "Falcon 7B - Technology Innovation Institute's 7B model",
        "params": "~7B",
        "requires_auth": False,
    },
    "qwen-7b": {
        "name": "Qwen/Qwen-7B",
        "description": "Qwen 7B - Alibaba's Qwen model with 7B parameters",
        "params": "~7B",
        "requires_auth": False,
    },
    # Smaller but still coherent options
    "gpt-neo-2.7b": {
        "name": "EleutherAI/gpt-neo-2.7B",
        "description": "GPT-Neo 2.7B - EleutherAI's GPT-Neo with 2.7B parameters",
        "params": "~2.7B",
        "requires_auth": False,
    },
    "opt-6.7b": {
        "name": "facebook/opt-6.7b",
        "description": "OPT 6.7B - Meta's Open Pre-trained Transformer with 6.7B parameters",
        "params": "~6.7B",
        "requires_auth": False,
    },
}


def get_model_info(model_key: str) -> dict:
    """
    Get information about a model.
    
    Args:
        model_key: Key from AVAILABLE_MODELS
    
    Returns:
        Dictionary with model information
    """
    if model_key not in AVAILABLE_MODELS:
        raise ValueError(f"Unknown model: {model_key}. Available: {list(AVAILABLE_MODELS.keys())}")
    return AVAILABLE_MODELS[model_key]


def list_models() -> None:
    """Print all available models."""
    print("\nAvailable Models (GPU Recommended):")
    print("=" * 70)
    for key, info in AVAILABLE_MODELS.items():
        auth_note = " (requires HuggingFace auth)" if info.get("requires_auth", False) else ""
        print(f"  {key:20s} - {info['description']}{auth_note}")
        print(f"  {'':20s}   Parameters: {info['params']}")
        print()

