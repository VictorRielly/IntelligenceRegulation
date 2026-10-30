"""Text-only Shieldstral input preparation, independent of proof availability.

The caller supplies a policy's fixed public token arrays. Candidate policies may
be checked with this library, but doing so does not register them or enable the
web prover. Short inputs use the native schema/3 trailing-pad convention.
"""
from __future__ import annotations

from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from .prompting import ContentRefused

TEKKEN_SHA256 = 'ceb11e85e44d7c91d051604d636d97b05aee59a907a0dc96a3c6e557d9634e18'
VOCABULARY = 131072
SPECIAL_TOKENS = 1000
PAD_ID = 11


class ShieldstralTextEncoder:
    """The pinned model's plain-text encoder: no parsing of user control strings."""

    def __init__(self, path: Path):
        raw = Path(path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != TEKKEN_SHA256:
            raise ContentRefused('the Shieldstral tokenizer differs from the model pin')
        # Construct from the same bytes that were hashed, without reopening the
        # path. Image configuration is irrelevant to this text-only encoder.
        from mistral_common.tokens.tokenizers.base import TokenizerVersion
        from mistral_common.tokens.tokenizers.tekken import Tekkenizer

        model = json.loads(raw)
        cfg = model['config']
        self._tokenizer = Tekkenizer(
            vocab=model['vocab'], special_tokens=model['special_tokens'],
            pattern=cfg['pattern'], vocab_size=cfg['default_vocab_size'],
            num_special_tokens=cfg['default_num_special_tokens'],
            version=TokenizerVersion(cfg['version']), name='shieldstral-text')
        if (self._tokenizer.n_words, self._tokenizer.num_special_tokens,
                self._tokenizer.bos_id) != (VOCABULARY, SPECIAL_TOKENS, 1):
            raise ContentRefused('unexpected Shieldstral tokenizer geometry')
        if model['special_tokens'][PAD_ID]['token_str'] != '<pad>':
            raise ContentRefused('unexpected Shieldstral pad token')

    def content_ids(self, text: str) -> tuple[int, ...]:
        if not isinstance(text, str) or not text.strip():
            raise ContentRefused('the post is empty')
        try:
            text.encode('utf-8', errors='strict')
        except UnicodeEncodeError:
            raise ContentRefused('the post is not valid Unicode') from None
        # The leading space belongs to the private content, exactly as in A1.
        ids = tuple(self._tokenizer.encode(' ' + text, bos=False, eos=False))
        if not ids or any(type(i) is not int or not SPECIAL_TOKENS <= i < VOCABULARY for i in ids):
            raise ContentRefused('the post encoding contains a forbidden token')
        return ids


@dataclass(frozen=True)
class CategoryTemplate:
    category: str
    policy_id: str
    prefix: tuple[int, ...]
    suffix: tuple[int, ...]
    context_tokens: int
    overlap: int
    max_chunks: int

    def __post_init__(self):
        if (self.category not in ('sexual', 'violence', 'hate') or type(self.policy_id) is not str
                or not self.policy_id or '\x00' in self.policy_id):
            raise ContentRefused('invalid classifier category or policy')
        if (type(self.prefix) is not tuple or type(self.suffix) is not tuple
                or not self.prefix or self.prefix[0] != 1 or self.suffix != (4,)
                or any(type(i) is not int or not 0 <= i < VOCABULARY for i in self.prefix + self.suffix)):
            raise ContentRefused('invalid public classifier template')
        if (type(self.context_tokens) is not int or self.context_tokens not in (128, 256)
                or type(self.overlap) is not int or not 0 <= self.overlap < self.chunk_size
                or type(self.max_chunks) is not int or self.max_chunks < 1):
            raise ContentRefused('invalid classifier chunk geometry')

    @property
    def chunk_size(self) -> int:
        return self.context_tokens - len(self.prefix) - len(self.suffix)

    def plan(self, total: int) -> list[dict]:
        if type(total) is not int or total < 1:
            raise ContentRefused('the post must contain at least one content token')
        if total < self.chunk_size:
            return [{'index': 0, 'start': 0, 'end': total}]
        size, stride = self.chunk_size, self.chunk_size - self.overlap
        # Full tail anchored at the end, matching the reviewed native CLI.
        last = total - size
        count = last // stride + 1 + bool(last % stride)
        if count > self.max_chunks:
            raise ContentRefused('the post exceeds this category\'s chunk limit')
        starts = list(range(0, last + 1, stride))
        if starts[-1] != last:
            starts.append(last)
        return [{'index': i, 'start': start, 'end': start + size}
                for i, start in enumerate(starts)]

    def prompt_ids(self, content_ids: tuple[int, ...], chunk: dict) -> tuple[int, ...]:
        if any(type(i) is not int or not SPECIAL_TOKENS <= i < VOCABULARY for i in content_ids):
            raise ContentRefused('the post encoding contains a forbidden token')
        plan = self.plan(len(content_ids))
        if not isinstance(chunk, dict) or any(type(chunk.get(k)) is not int for k in ('index', 'start', 'end')):
            raise ContentRefused('invalid classifier chunk bounds')
        i = chunk.get('index')
        if type(i) is not int or not 0 <= i < len(plan) or chunk != plan[i]:
            raise ContentRefused('the requested chunk differs from this category\'s native plan')
        prompt = self.prefix + tuple(content_ids[chunk['start']:chunk['end']]) + self.suffix
        return prompt + (PAD_ID,) * (self.context_tokens - len(prompt))


def category_plans(total: int, templates: tuple[CategoryTemplate, ...]) -> dict[str, list[dict]]:
    """Plan all three categories separately; failure in any category refuses the item."""
    if len(templates) != 3 or {t.category for t in templates} != {'sexual', 'violence', 'hate'}:
        raise ContentRefused('all three distinct classifier categories are required')
    if len({t.policy_id for t in templates}) != 3:
        raise ContentRefused('each category requires its own policy')
    return {t.category: t.plan(total) for t in templates}


def check_category_coverage(text: str, encoder: ShieldstralTextEncoder,
                            templates: tuple[CategoryTemplate, ...], statements: dict) -> int:
    """Count the actual post with its pinned encoder and check every category.

    Use the returned count for native label --expect-total. This check must
    accompany fresh verification and input-owner binding; it cannot replace them.
    """
    from .classifier_cli import R_C3_SCHEMA, check_statement_coverage
    from .provers import ProverError

    if not isinstance(encoder, ShieldstralTextEncoder):
        raise ContentRefused('whole-post coverage requires the pinned Shieldstral encoder')
    total = len(encoder.content_ids(text))
    plans = category_plans(total, templates)
    if not isinstance(statements, dict) or set(statements) != set(plans):
        raise ContentRefused('all three category proof sets are required')
    try:
        for template in templates:
            rows = statements[template.category]
            check_statement_coverage(rows, total, template.chunk_size, template.overlap,
                                     template.policy_id, R_C3_SCHEMA)
            for row in rows:
                n = row['content_length_n']
                length = len(template.prefix) + n + len(template.suffix)
                expected = {'T': template.context_tokens, 'item_length': length,
                            'pad_id': PAD_ID, 'pad_positions': template.context_tokens - length,
                            'verdict_row': length - 1}
                if (row.get('template_prefix_ids') != list(template.prefix)
                        or row.get('template_suffix_ids') != list(template.suffix)
                        or any(type(row.get(k)) is not int or row[k] != v for k, v in expected.items())):
                    raise ContentRefused('category template or short-content padding differs')
    except ProverError as error:
        raise ContentRefused(str(error)) from error
    return total
