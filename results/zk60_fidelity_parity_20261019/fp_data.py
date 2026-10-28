#!/usr/bin/env python3
"""Evaluation corpora for the fidelity parity lane (both models, any T).

* fineweb  — FineWeb-Edu sample/10BT shard 000_00000 (the calibration lanes'
             local copy), row group 3: disjoint from the lanes' calibration
             (row group 0) and held-out (row group 1) documents. One sequence
             per document: [BOS] + the first T-1 tokens.
* wikitext — WikiText-2 raw TEST split (data/wikitext2/test.parquet, pinned
             revision): "\\n\\n".join(rows) tokenized once, cut into
             non-overlapping windows of T-1 tokens, n windows evenly spaced
             over the split, each [BOS] + window.
* lambada  — LAMBADA (OpenAI version) TEST (data/lambada_openai/en_test.parquet):
             context = text up to the last space, continuation = " " + last
             word (lm-eval-harness split: continuation tokens = enc(whole)[len(enc(ctx)):]).
             Sequence = [BOS] + the last tokens of the context that fit + the
             continuation, right-padded to T by repeating its own tokens (causal:
             padding never reaches a scored position). A seeded random sample
             of n items. Accuracy = every continuation token is the argmax
             (greedy match); the context is LEFT-TRUNCATED to fit T (flagged).

Downloaded parquet files are read with the user site-packages path only
(scripts live outside data/). Calibration/fidelity data only.
"""

from __future__ import annotations

import hashlib
import site
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
FW_PARQUET = Path("/home/victor/models/fineweb-edu/sample/10BT/000_00000.parquet")
FW_SHA256 = "b1ba7b2ce4cb5ea6ef42dca40263eabb85f37700d01693a68e9b30a31d78e871"
WT_PARQUET = DATA / "wikitext2" / "test.parquet"
WT_SHA256 = "5f1bea067869d04849c0f975a2b29c4ff47d867f484f5010ea5e861eab246d91"
WV_PARQUET = DATA / "wikitext2" / "validation.parquet"      # calibration only (never evaluated)
WV_SHA256 = "204929b7ff9d6184953f867dedb860e40aa69c078fc1e54b3baaa8fb28511c4c"
LB_PARQUET = DATA / "lambada_openai" / "en_test.parquet"
LB_SHA256 = "99d8a9e54cda761c6340ddd4fa6feda7f846ffb0e716afa52968dea75495eea7"
FW_ROW_GROUP = 3
LAMBADA_SEED = 20261019


def _pq():
    up = site.getusersitepackages()
    if up not in sys.path:
        sys.path.append(up)
    import pyarrow.parquet as pq
    return pq


def _sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


class Tok:
    """encode(text) -> ids without BOS; .bos; .name; .sha256"""

    def __init__(self, model: str):
        if model == "llama3-8b":
            from tokenizers import Tokenizer
            p = Path("/home/victor/IntelligenceRegulation/local-models/zk60-llama3-8b/tokenizer.json")
            self.tk = Tokenizer.from_file(str(p))
            self.bos, self.name, self.sha256 = 128000, "llama3 tokenizer.json", _sha(p)
            self._enc = lambda s: self.tk.encode(s, add_special_tokens=False).ids
        else:
            sys.path.insert(0, "/home/victor/IntelligenceRegulation/results/zk60_1b_calibration_20260929")
            from spm_bpe import SpmBpe
            p = Path("/home/victor/models/tinyllama-1.1b-chat-fe8a4ea1/tokenizer.model")
            self.tk = SpmBpe(p)
            self.bos, self.name, self.sha256 = 1, "TinyLlama tokenizer.model (spm_bpe.py)", _sha(p)
            self._enc = lambda s: self.tk.encode(s, bos=False)

    def encode(self, s: str):
        return list(self._enc(s))


def fineweb(tok: Tok, T: int, n: int, row_group: int = FW_ROW_GROUP):
    pq = _pq()
    tab = pq.ParquetFile(FW_PARQUET).read_row_group(row_group, columns=["text", "id"]).to_pydict()
    seqs, meta = [], []
    for row, (text, did) in enumerate(zip(tab["text"], tab["id"])):
        if len(seqs) >= n:
            break
        ids = tok.encode(text[:8 * T + 2000])
        if len(ids) < T - 1 + 8:
            continue
        seqs.append([tok.bos] + ids[:T - 1])
        meta.append({"corpus": "fineweb", "doc_id": did, "row_group": row_group, "row": row})
    assert len(seqs) == n, f"fineweb: only {len(seqs)} documents"
    mask = np.ones((n, T - 1), dtype=bool)
    return seqs, meta, mask


def wikitext(tok: Tok, T: int, n: int, path: Path = WT_PARQUET):
    pq = _pq()
    rows = pq.read_table(path).to_pydict()["text"]
    ids = tok.encode("\n\n".join(rows))
    w = T - 1
    nwin = len(ids) // w
    pick = np.unique(np.linspace(0, nwin - 1, n).round().astype(int))
    assert len(pick) == n
    seqs = [[tok.bos] + ids[i * w:(i + 1) * w] for i in pick]
    meta = [{"corpus": "wikitext", "window": int(i), "windows_total": int(nwin), "tokens_total": len(ids)} for i in pick]
    return seqs, meta, np.ones((n, T - 1), dtype=bool)


def lambada(tok: Tok, T: int, n: int, off: int = 0):
    pq = _pq()
    texts = pq.read_table(LB_PARQUET).to_pydict()["text"]
    rng = np.random.default_rng(LAMBADA_SEED)
    order = rng.permutation(len(texts))[off:off + n]
    seqs, meta = [], []
    mask = np.zeros((n, T - 1), dtype=bool)
    for k, i in enumerate(order):
        text = texts[i]
        cut = text.rfind(" ")
        ctx, cont = text[:cut], text[cut:]
        whole = tok.encode(ctx + cont)
        ce = tok.encode(ctx)
        cn = whole[len(ce):]
        if not cn:      # tokenization merged across the boundary: fall back to separate encodings
            cn = tok.encode(cont)
        room = T - 1 - len(cn)
        tail = ce[-room:] if len(ce) > room else ce
        body = tail + cn
        seq = [tok.bos] + body
        pad = (body * (T // max(1, len(body)) + 2))[:T - len(seq)]
        seq = seq + pad
        j0 = 1 + len(tail)                      # first continuation token index in seq
        mask[k, j0 - 1:j0 - 1 + len(cn)] = True  # prediction positions j-1
        seqs.append(seq)
        meta.append({"corpus": "lambada", "item": int(i), "cont_tokens": len(cn), "ctx_tokens": len(ce),
                     "truncated": len(ce) > room, "cont_pos": [j0 - 1, j0 - 1 + len(cn)]})
    return seqs, meta, mask


def build(model: str, T: int, spec: str):
    """spec 'fineweb:128,wikitext:128,lambada:1000' -> ids (N, T) int64, meta list, mask (N, T-1), info."""
    tok = Tok(model)
    seqs, meta, masks = [], [], []
    info = {"tokenizer": tok.name, "tokenizer_sha256": tok.sha256, "T": T, "spec": spec, "corpora": {}}
    for part in spec.split(","):
        name, n = part.split(":")
        off = 0
        if "@" in n:            # lambada:N@OFF = items OFF..OFF+N-1 of the seeded order (chunked runs)
            n, off = n.split("@")
            off = int(off)
        n = int(n)
        fn = {"fineweb": fineweb, "wikitext": wikitext, "lambada": lambda t, T_, n_: lambada(t, T_, n_, off),
              "fwcal": lambda t, T_, n_: fineweb(t, T_, n_, row_group=0),
              "wtval": lambda t, T_, n_: wikitext(t, T_, n_, path=WV_PARQUET)}[name]
        s, m, k = fn(tok, T, n)
        assert all(len(x) == T for x in s)
        seqs += s
        meta += m
        masks.append(k)
        src = {"fineweb": (FW_PARQUET, FW_SHA256), "fwcal": (FW_PARQUET, FW_SHA256), "wikitext": (WT_PARQUET, WT_SHA256),
               "wtval": (WV_PARQUET, WV_SHA256),
               "lambada": (LB_PARQUET, LB_SHA256)}[name]
        info["corpora"][name] = {"n": n, "offset": off, "source": str(src[0]), "sha256_expected": src[1]}
        if name == "lambada":
            info["corpora"][name]["truncated_items"] = int(sum(x["truncated"] for x in m))
    for name, c in info["corpora"].items():
        got = _sha(Path(c["source"])) if name not in ("fineweb", "fwcal") else FW_SHA256   # the shard was pinned by lane B4
        assert got == c["sha256_expected"], f"{name}: source sha256 mismatch"
    ids = np.array(seqs, dtype=np.int64)
    info["ids_sha256"] = hashlib.sha256(ids.tobytes()).hexdigest()
    return ids, meta, np.concatenate(masks), info
