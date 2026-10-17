#!/usr/bin/env python3
"""Fixed, local, public token corpus for calibration and held-out evaluation.

No network. Two DISJOINT source groups of public English text found on this
box: license texts under /usr/share/common-licenses and module docstrings of
the Python 3.10 standard library. Calibration and held-out sets use different
files, so no held-out sentence is seen during calibration.

Every sequence is [BOS] + (T - 1) consecutive tokens of one document stream.
The file list, token counts and a digest of every sequence are recorded by
the caller.
"""

from __future__ import annotations

import ast
import hashlib
from pathlib import Path

from spm_bpe import SpmBpe

LICENSES = Path("/usr/share/common-licenses")
STDLIB = Path("/usr/lib/python3.10")

CALIB_FILES = [LICENSES / "GPL-3", LICENSES / "GFDL-1.3", LICENSES / "MPL-2.0"]
CALIB_MODULES = ["argparse", "collections/__init__", "textwrap", "logging/__init__", "subprocess", "typing"]
HELDOUT_FILES = [LICENSES / "Apache-2.0", LICENSES / "LGPL-2.1", LICENSES / "Artistic"]
HELDOUT_MODULES = ["json/__init__", "pathlib", "functools", "dataclasses", "unittest/case", "shutil"]


def _docstrings(module: str) -> str:
    src = (STDLIB / f"{module}.py").read_text(encoding="utf-8")
    tree = ast.parse(src)
    parts = []
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)):
            doc = ast.get_docstring(node)
            if doc and len(doc) > 200:
                parts.append(doc)
    return "\n\n".join(parts)


def _texts(files, modules):
    out = []
    for f in files:
        out.append((str(f), f.read_text(encoding="utf-8", errors="replace")))
    for m in modules:
        out.append((f"python3.10 stdlib docstrings: {m}", _docstrings(m)))
    return out


def sequences(tok: SpmBpe, which: str, T: int, per_source: int):
    """Up to `per_source` sequences of length T from each source of the set."""
    files, modules = (CALIB_FILES, CALIB_MODULES) if which == "calib" else (HELDOUT_FILES, HELDOUT_MODULES)
    seqs, meta = [], []
    for name, text in _texts(files, modules):
        ids = tok.encode(text, bos=False)
        body = T - 1
        n = min(per_source, len(ids) // body)
        # spread the windows over the document instead of taking the head only
        stride = max(body, (len(ids) - body) // max(1, n))
        for k in range(n):
            chunk = [1] + ids[k * stride:k * stride + body]
            if len(chunk) == T:
                seqs.append(chunk)
                meta.append({"source": name, "offset": k * stride,
                             "sha256": hashlib.sha256(",".join(map(str, chunk)).encode()).hexdigest()[:16]})
    return seqs, meta
