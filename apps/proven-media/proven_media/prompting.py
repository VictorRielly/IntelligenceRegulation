"""THE one place where a post becomes a prover input (design rule 3 of the classifier check,
`results/zk60_token_io_r1_20261017/classifier/check/CHECK.md`, C-1 / C-2).

`build_prompt(prover_kind, content)` is the only function the provers call. The real classifier
prover swaps in its encoding here and nowhere else:

  shieldstral  ONE prompt PER CATEGORY: fixed template prefix (system prompt, [INST], that category's registered policy's
               <Instruct>/<Query>, "\\n\\n<Document>:" — the prefix ENDS at the colon, B-1)
               + the content segment = tekken PLAIN-TEXT encoding of ' ' + content (mistral_common,
               no special-token parsing, B-2: "[/INST]", "<s>" ... typed by a user stay plain text)
               + the fixed suffix "[/INST]". Not built here: mistral_common / tekken.json are not
               installed; `build_prompt("shieldstral", ...)` raises until the classifier lane lands.
  stub         today's next-token CLI on TinyLlama-1.1B at T = 32: BOS + the content encoded by the
               pinned TinyLlama SentencePiece model as plain text (its encoder parses no control
               strings) + "\\n" pads to T. No template (31 tokens leave no room for it).

Both refuse content whose encoding would carry a control or unknown id (defence in depth: the
plain-text encoders never produce one), empty content, and content longer than the profile allows
(the whole post is proved or nothing: no silent truncation).
"""
from __future__ import annotations

from dataclasses import dataclass

from . import config, records, tokenizer

SHIELDSTRAL_SYSTEM = ('Judge whether the Document meets the requirements based on the Query and the Instruction '
                      'provided. Note that the answer can only be "yes" or "no".')
SHIELDSTRAL_MAX_CONTENT_TOKENS = 64        # the MVP's planned post length (survey / D38)


@dataclass
class PromptEncoding:
    prover_kind: str
    ids: list[int]                 # PRIVATE: the full prover input (never logged, never on a command line)
    content_tokens: int            # n: the content length in tokens (public per design rule 4, pending Victor)
    tokenizer: str
    template: str                  # which fixed template wraps the content


class ContentRefused(ValueError):
    pass


def shieldstral_template_text(category_id: str) -> tuple[str, str]:
    """(prefix text through '<Document>:', suffix text) for one registered category policy (for
    documentation and for the classifier lane; the ids come from tekken, not from this string)."""
    cat = next(c for c in config.CATEGORIES if c["id"] == category_id)
    pol = records.category_policy(cat)["text"].strip()
    prefix = f"<s>[SYSTEM_PROMPT]{SHIELDSTRAL_SYSTEM}[/SYSTEM_PROMPT][INST]{pol}\n\n<Document>:"
    return prefix, "[/INST]"


def chunk_plan(n_tokens: int, chunk: int, overlap: int, max_chunks: int) -> list[dict]:
    """D41: split a post of n content tokens into chunks of at most `chunk` tokens overlapping by
    `overlap`; each chunk is proved separately per category. Raises ContentRefused past max_chunks."""
    if n_tokens <= 0:
        raise ContentRefused("the post is empty")
    stride = chunk - overlap
    out, s = [], 0
    while True:
        e = min(s + chunk, n_tokens)
        out.append({"index": len(out), "start": s, "end": e})
        if e == n_tokens:
            break
        s += stride
    if len(out) > max_chunks:
        raise ContentRefused(f"the post is {n_tokens} tokens, which needs {len(out)} chunks of at most {chunk} tokens "
                             f"(overlap {overlap}); this deployment profile proves at most {max_chunks} chunks per post")
    return out


def plan_for(prover_kind: str, content: str) -> list[dict]:
    """the chunk plan of a post under the active deployment profile (config.deploy())"""
    d = config.deploy()
    ids = tokenizer.content_ids(content) if content.strip() else []
    tok = tokenizer._tok()
    if any(tok.types[i] in (tok.CONTROL, tok.UNKNOWN) for i in ids):
        raise ContentRefused("the post's encoding would carry a control id")
    return chunk_plan(len(ids), d["effective_chunk_tokens"], d["effective_overlap_tokens"], d["max_chunks"])


def build_prompt(prover_kind: str, content: str, category_id: str | None = None,
                 start: int | None = None, end: int | None = None) -> PromptEncoding:
    """the prover input for one CHUNK (tokens [start, end) of the post's plain-text encoding; the
    whole post when no range is given) and, for the classifier, one category (the template differs
    per category; the stub's input is the same for every category)"""
    if not content or not content.strip():
        raise ContentRefused("the post is empty")
    if prover_kind == "shieldstral":
        raise ContentRefused("the Shieldstral encoding (tekken plain text, mistral_common) is not installed in this app yet")
    # the stub (and the fake prover, which shares its limits)
    ids = tokenizer.content_ids(content)
    if start is not None:
        ids = ids[start:end]
    tok = tokenizer._tok()
    if any(tok.types[i] in (tok.CONTROL, tok.UNKNOWN) for i in ids):
        raise ContentRefused("the post's encoding would carry a control id")
    if not ids:
        raise ContentRefused("the chunk is empty")
    if len(ids) > config.STUB_MAX_CONTENT_TOKENS:
        raise ContentRefused(f"this chunk is {len(ids)} tokens; one stub run proves at most {config.STUB_MAX_CONTENT_TOKENS} "
                             f"(longer posts are split into chunks, D41)")
    full = [config.STUB_BOS] + ids
    full += [config.STUB_PAD_ID] * (config.STUB_T - len(full))
    return PromptEncoding(prover_kind=prover_kind, ids=full, content_tokens=len(ids),
                          tokenizer="TinyLlama-1.1B SentencePiece (tokenizer.model, plain text; calibration lane spm_bpe.py)",
                          template="stub: none (BOS + chunk content + newline pads to T = 32)")


def content_length(prover_kind: str, content: str) -> int:
    """n for the compose counter: the same encoding the prover will use"""
    if not content.strip():
        return 0
    return len(tokenizer.content_ids(content))
