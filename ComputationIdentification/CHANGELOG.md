# Changelog

## Version 0.1.0 - Package Release

### Added
- **Package Structure**: Converted to a proper Python package with `__init__.py`
- **Model Selection**: Support for multiple ~1B parameter models:
  - GPT-Neo 1.3B
  - GPT-2 XL
  - OPT 1.3B
  - BLOOM 1B1
  - Cerebras GPT 1.3B
- **Chat Interface**: Interactive chat interface with:
  - Model selection
  - Conversation history tracking
  - Random seed generation per turn
  - Hash computation and storage
- **Verification System**: Automatic verification at end of conversation:
  - Regenerates all hashes
  - Verifies all responses came from intended model
  - Reports verification status
- **Documentation**: 
  - Package README
  - Setup instructions
  - Usage examples

### Features
- Sequential hashing: `hash(input+seed) -> hash with each layer -> hash with output`
- Deterministic verification using stored seeds
- Conversation history with inputs, seeds, hashes, and outputs
- Standalone chat script for easy usage

### Files Added
- `__init__.py` - Package initialization
- `models.py` - Model definitions
- `chat.py` - Chat interface
- `verification.py` - Verification logic
- `main.py` - Main entry point
- `run_chat.py` - Standalone chat script
- `setup.py` - Package setup
- `PACKAGE_README.md` - Package documentation

