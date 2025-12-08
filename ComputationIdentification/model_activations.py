"""
Script for downloading and querying a model with intermediate activation extraction.

This script provides functionality to:
- Download a language model
- Query the model with text inputs
- Extract intermediate activations at any layer
"""

import torch
from transformers import AutoModelForCausalLM, AutoTokenizer
from typing import Dict, List, Optional, Tuple
import os
import hashlib
import numpy as np


class ModelWithActivations:
    """
    Wrapper class for a language model that allows extraction of intermediate activations.
    """
    
    def __init__(self, model_name: str = "EleutherAI/gpt-neo-1.3B", device: Optional[str] = None, 
                 use_gpu: bool = True, load_in_8bit: bool = False, load_in_4bit: bool = False):
        """
        Initialize the model and tokenizer with GPU support.
        
        Args:
            model_name: Hugging Face model identifier
            device: Device to load model on ('cuda', 'cpu', or None for auto-detection)
            use_gpu: Whether to prefer GPU (default: True)
            load_in_8bit: Load model in 8-bit mode for memory efficiency (requires bitsandbytes)
            load_in_4bit: Load model in 4-bit mode for memory efficiency (requires bitsandbytes)
        """
        self.model_name = model_name
        
        # Determine device
        if device:
            self.device = device
        elif use_gpu and torch.cuda.is_available():
            self.device = 'cuda'
            print(f"GPU available: {torch.cuda.get_device_name(0)}")
            print(f"GPU memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
        else:
            self.device = 'cpu'
            if use_gpu:
                print("Warning: GPU requested but not available. Using CPU.")
        
        print(f"Loading model: {model_name}")
        print(f"Using device: {self.device}")
        
        # Load tokenizer
        self.tokenizer = AutoTokenizer.from_pretrained(model_name)
        
        # Load model with optional quantization
        if load_in_8bit or load_in_4bit:
            try:
                from transformers import BitsAndBytesConfig
                quantization_config = BitsAndBytesConfig(
                    load_in_8bit=load_in_8bit,
                    load_in_4bit=load_in_4bit,
                )
                print(f"Loading model in {'8-bit' if load_in_8bit else '4-bit'} mode for memory efficiency...")
                self.model = AutoModelForCausalLM.from_pretrained(
                    model_name,
                    quantization_config=quantization_config,
                    device_map="auto" if self.device == 'cuda' else None,
                )
            except ImportError:
                print("Warning: bitsandbytes not available. Loading model normally.")
                print("Install with: pip install bitsandbytes")
                self.model = AutoModelForCausalLM.from_pretrained(model_name)
                if self.device == 'cuda':
                    self.model = self.model.to(self.device)
        else:
            self.model = AutoModelForCausalLM.from_pretrained(model_name)
            if self.device == 'cuda':
                self.model = self.model.to(self.device)
        
        self.model.eval()
        
        # Ensure tokenizer has padding token
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        
        # Storage for activations
        self.activations: Dict[int, torch.Tensor] = {}
        self.hooks: List = []
        
        param_count = sum(p.numel() for p in self.model.parameters())
        print(f"Model loaded successfully. Total parameters: {param_count:,}")
        
        if self.device == 'cuda':
            memory_allocated = torch.cuda.memory_allocated(0) / 1e9
            memory_reserved = torch.cuda.memory_reserved(0) / 1e9
            print(f"GPU memory allocated: {memory_allocated:.2f} GB")
            print(f"GPU memory reserved: {memory_reserved:.2f} GB")
    
    def _register_hooks(self, layer_indices: Optional[List[int]] = None):
        """
        Register forward hooks to capture activations at specified layers.
        
        Args:
            layer_indices: List of layer indices to capture. If None, captures all layers.
        """
        # Clear previous hooks and activations
        self._remove_hooks()
        self.activations.clear()
        
        # Get the transformer blocks (this works for GPT-style models)
        if hasattr(self.model, 'transformer') and hasattr(self.model.transformer, 'h'):
            layers = self.model.transformer.h
        elif hasattr(self.model, 'gpt_neox') and hasattr(self.model.gpt_neox, 'layers'):
            layers = self.model.gpt_neox.layers
        elif hasattr(self.model, 'model') and hasattr(self.model.model, 'layers'):
            layers = self.model.model.layers
        else:
            raise ValueError("Could not find transformer layers in model architecture")
        
        num_layers = len(layers)
        print(f"Found {num_layers} transformer layers")
        
        # If no specific layers requested, capture all
        if layer_indices is None:
            layer_indices = list(range(num_layers))
        
        def make_hook(layer_idx):
            def hook_fn(module, input, output):
                # Store the activation (output of the layer)
                # For transformer blocks, output is typically a tuple, we want the hidden states
                if isinstance(output, tuple):
                    self.activations[layer_idx] = output[0].detach().cpu()
                else:
                    self.activations[layer_idx] = output.detach().cpu()
            return hook_fn
        
        # Register hooks for specified layers
        for layer_idx in layer_indices:
            if 0 <= layer_idx < num_layers:
                hook = layers[layer_idx].register_forward_hook(make_hook(layer_idx))
                self.hooks.append(hook)
                print(f"Registered hook for layer {layer_idx}")
            else:
                print(f"Warning: Layer index {layer_idx} is out of range (0-{num_layers-1})")
    
    def _remove_hooks(self):
        """Remove all registered hooks."""
        for hook in self.hooks:
            hook.remove()
        self.hooks.clear()
    
    def query(self, 
              text: str, 
              max_length: int = 50,
              return_activations: bool = True,
              layer_indices: Optional[List[int]] = None) -> Tuple[str, Dict[int, torch.Tensor]]:
        """
        Query the model with text and optionally return intermediate activations.
        
        Args:
            text: Input text to process
            max_length: Maximum length of generated sequence
            return_activations: Whether to capture and return activations
            layer_indices: Specific layers to capture activations from (None = all layers)
        
        Returns:
            Tuple of (generated_text, activations_dict)
        """
        # Register hooks if activations are requested
        if return_activations:
            self._register_hooks(layer_indices)
        
        # Tokenize input
        inputs = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        # Generate with the model
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_length=max_length,
                do_sample=True,
                temperature=0.7,
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        # Decode the generated text
        generated_text = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Remove hooks after forward pass
        if return_activations:
            self._remove_hooks()
        
        return generated_text, self.activations.copy()
    
    def get_activations_for_input(self,
                                  text: str,
                                  layer_indices: Optional[List[int]] = None) -> Dict[int, torch.Tensor]:
        """
        Get activations for a given input without generating new text.
        Useful for analyzing how the model processes input.
        
        Args:
            text: Input text to process
            layer_indices: Specific layers to capture activations from (None = all layers)
        
        Returns:
            Dictionary mapping layer indices to activation tensors
        """
        # Register hooks
        self._register_hooks(layer_indices)
        
        # Tokenize input
        inputs = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        # Forward pass
        with torch.no_grad():
            _ = self.model(**inputs)
        
        # Remove hooks
        self._remove_hooks()
        
        return self.activations.copy()
    
    def get_num_layers(self) -> int:
        """Get the total number of transformer layers in the model."""
        if hasattr(self.model, 'transformer') and hasattr(self.model.transformer, 'h'):
            return len(self.model.transformer.h)
        elif hasattr(self.model, 'gpt_neox') and hasattr(self.model.gpt_neox, 'layers'):
            return len(self.model.gpt_neox.layers)
        elif hasattr(self.model, 'model') and hasattr(self.model.model, 'layers'):
            return len(self.model.model.layers)
        else:
            raise ValueError("Could not determine number of layers in model")
    
    def _tensor_to_bytes(self, tensor: torch.Tensor) -> bytes:
        """
        Convert a tensor to a deterministic byte representation.
        
        Args:
            tensor: PyTorch tensor to convert
        
        Returns:
            Bytes representation of the tensor
        """
        # Convert to numpy, then to bytes
        # Use a consistent dtype and ensure deterministic representation
        np_array = tensor.detach().cpu().numpy()
        # Convert to float32 for consistency and smaller size
        if np_array.dtype != np.float32:
            np_array = np_array.astype(np.float32)
        return np_array.tobytes()
    
    def compute_sequential_hash(self,
                                text: str,
                                seed: int = 42,
                                max_length: int = 50) -> str:
        """
        Compute a sequential hash by hashing input+seed with each layer's activations,
        then hashing the final hash with the output text.
        
        Args:
            text: Input text to process
            seed: Random seed for deterministic generation
            max_length: Maximum length of generated sequence
        
        Returns:
            Final hash as hexadecimal string
        """
        # Set seeds for reproducibility
        torch.manual_seed(seed)
        if torch.cuda.is_available():
            torch.cuda.manual_seed_all(seed)
        np.random.seed(seed)
        
        # Register hooks to capture all layers
        self._register_hooks(layer_indices=None)
        
        # Step 1: Hash input text with seed
        input_bytes = text.encode('utf-8')
        seed_bytes = str(seed).encode('utf-8')
        current_hash = hashlib.sha256(input_bytes + seed_bytes).digest()
        
        # Tokenize input
        inputs = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True)
        inputs = {k: v.to(self.device) for k, v in inputs.items()}
        
        # Forward pass to get activations (without generation yet)
        with torch.no_grad():
            _ = self.model(**inputs)
        
        # Store activations before generation (to avoid overwrites)
        stored_activations = {k: v.clone() for k, v in self.activations.items()}
        
        # Step 2: Hash with each layer's activations in order
        num_layers = self.get_num_layers()
        for layer_idx in range(num_layers):
            if layer_idx in stored_activations:
                activation_bytes = self._tensor_to_bytes(stored_activations[layer_idx])
                # Hash: previous_hash + layer_activations
                current_hash = hashlib.sha256(current_hash + activation_bytes).digest()
        
        # Step 3: Generate output text (deterministic with seed)
        with torch.no_grad():
            outputs = self.model.generate(
                **inputs,
                max_length=max_length,
                do_sample=False,  # Use greedy decoding for determinism
                pad_token_id=self.tokenizer.eos_token_id
            )
        
        # Decode the generated text
        generated_text = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        
        # Step 4: Hash the final hash with the output text
        output_bytes = generated_text.encode('utf-8')
        final_hash = hashlib.sha256(current_hash + output_bytes).digest()
        
        # Remove hooks
        self._remove_hooks()
        
        # Return as hexadecimal string
        return final_hash.hex(), generated_text


def download_model(model_name: str = "EleutherAI/gpt-neo-1.3B", 
                   cache_dir: Optional[str] = None) -> Tuple[AutoModelForCausalLM, AutoTokenizer]:
    """
    Download a 1B parameter model and return the model and tokenizer.
    
    Args:
        model_name: Hugging Face model identifier
        cache_dir: Directory to cache the model (None uses default Hugging Face cache)
    
    Returns:
        Tuple of (model, tokenizer)
    """
    print(f"Downloading model: {model_name}")
    print("This may take a few minutes on first run...")
    
    tokenizer = AutoTokenizer.from_pretrained(model_name, cache_dir=cache_dir)
    model = AutoModelForCausalLM.from_pretrained(model_name, cache_dir=cache_dir)
    
    # Ensure tokenizer has padding token
    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token
    
    print(f"Model downloaded successfully!")
    print(f"Total parameters: {sum(p.numel() for p in model.parameters()):,}")
    
    return model, tokenizer


# Example usage
if __name__ == "__main__":
    # Initialize the model wrapper
    print("=" * 60)
    print("Computing Sequential Hash")
    print("=" * 60)
    
    model_wrapper = ModelWithActivations(model_name="EleutherAI/gpt-neo-1.3B")
    
    # Compute sequential hash
    input_text = "The future of artificial intelligence"
    input_text2 = "The future of artificial intelligence"
    seed = 43
    final_hash, generated_text = model_wrapper.compute_sequential_hash(input_text, seed=seed, max_length=30)
    
    print(f"\nInput text: {input_text}")
    print(f"Seed: {seed}")
    print(f"\nFinal hash: {final_hash}")
    
    # Test: Run again with same input to verify determinism
    print("\n" + "=" * 60)
    print("Testing determinism (same input, same seed)...")
    print("=" * 60)
    final_hash2, generated_text2 = model_wrapper.compute_sequential_hash(input_text2, seed=seed, max_length=30)
    print(f"Second run hash: {final_hash2}")
    
    if final_hash == final_hash2:
        print("✓ Hashes match! The computation is deterministic.")
        print(f"Generated text1: {generated_text}")
        print(f"Generated text2: {generated_text2}")
    else:
        print("✗ Hashes differ! The computation is not deterministic.")
        print(f"Generated text1: {generated_text}")
        print(f"Generated text2: {generated_text2}")
    print("\n" + "=" * 60)
    print("Done!")
    print("=" * 60)

