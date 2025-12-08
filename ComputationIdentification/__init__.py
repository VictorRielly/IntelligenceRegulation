"""
Computation Identification Package

A package for identifying and verifying AI model computations using sequential hashing.
"""

try:
    from .model_activations import ModelWithActivations
    from .models import AVAILABLE_MODELS, get_model_info
    from .chat import ChatInterface
    from .verification import verify_conversation
except ImportError:
    # Fallback for direct imports
    from model_activations import ModelWithActivations
    from models import AVAILABLE_MODELS, get_model_info
    from chat import ChatInterface
    from verification import verify_conversation

__version__ = "0.1.0"
__all__ = [
    "ModelWithActivations",
    "AVAILABLE_MODELS",
    "get_model_info",
    "ChatInterface",
    "verify_conversation",
]

