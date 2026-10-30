"""The stub's tokenizer: TinyLlama ids, in process. Posts become prover inputs ONLY through
`prompting.build_prompt` (design rule 3); this module just wraps the encoder.

Uses the calibration lane's stdlib SentencePiece-BPE encoder (`spm_bpe.py`, imported read-only),
the same tokenizer the presenter demo decodes with. It encodes text as plain characters: a user's
"<s>", "</s>" or "[INST]" stays ordinary text (checked in the tests). The ids never leave the app
process except in a 0600 file under the private data root (never on a command line, never in a log).
"""
from __future__ import annotations

import sys
from functools import lru_cache

from . import config


@lru_cache(maxsize=1)
def _tok():
    sys.path.insert(0, str(config.SPM_BPE_DIR))
    from spm_bpe import SpmBpe  # noqa: E402

    return SpmBpe(config.TINYLLAMA_TOKENIZER)


def content_ids(text: str) -> list[int]:
    """the post's own token ids (no BOS, no padding)"""
    return _tok().encode(text, bos=False)


def count(text: str) -> int:
    return len(content_ids(text)) if text.strip() else 0


def decode(ids: list[int]) -> str:
    """token ids -> text (used to run the stub's placeholder labels on one chunk's own text)"""
    return _tok().decode([i for i in ids if i != config.STUB_BOS])
