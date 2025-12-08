"""
Verification module for checking conversation integrity.
"""

from typing import List
try:
    from .chat import ConversationEntry
    from .model_activations import ModelWithActivations
except ImportError:
    # Allow running as standalone script
    from chat import ConversationEntry
    from model_activations import ModelWithActivations


def verify_conversation(model: ModelWithActivations, conversation_history: List[ConversationEntry]) -> bool:
    """
    Verify that all conversation entries came from the intended model by regenerating hashes.
    
    Args:
        model: The ModelWithActivations instance
        conversation_history: List of ConversationEntry objects to verify
    
    Returns:
        True if all entries verify correctly, False otherwise
    """
    if not conversation_history:
        print("No conversation history to verify.")
        return True
    
    print(f"Verifying {len(conversation_history)} conversation turns...\n")
    
    all_verified = True
    
    for i, entry in enumerate(conversation_history, 1):
        print(f"Turn {i}: Verifying...", end=" ", flush=True)
        
        # Regenerate hash with the same input and seed
        try:
            # Use a reasonable default max_length for verification
            regenerated_hash, regenerated_output = model.compute_sequential_hash(
                text=entry.input_text,
                seed=entry.seed,
                max_length=100  # Default max length
            )
            
            # Check if hash matches
            if regenerated_hash == entry.hash_value:
                print("✓ VERIFIED")
            else:
                print("✗ FAILED")
                print(f"  Expected: {entry.hash_value[:32]}...")
                print(f"  Got:      {regenerated_hash[:32]}...")
                all_verified = False
                
                # Also check if outputs match (they should if hash matches)
                if regenerated_output != entry.output_text:
                    print("  Warning: Outputs also differ!")
                    print(f"  Expected output: {entry.output_text[:100]}...")
                    print(f"  Got output:      {regenerated_output[:100]}...")
        except Exception as e:
            print(f"✗ ERROR: {e}")
            all_verified = False
    
    print("\n" + "=" * 60)
    if all_verified:
        print("✓ ALL CONVERSATION TURNS VERIFIED SUCCESSFULLY")
        print("All responses came from the intended model.")
    else:
        print("✗ VERIFICATION FAILED")
        print("Some responses may not have come from the intended model.")
    print("=" * 60)
    
    return all_verified

