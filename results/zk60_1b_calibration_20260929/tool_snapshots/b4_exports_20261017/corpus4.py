#!/usr/bin/env python3
"""Lane B4: a second text domain for calibration and held-out evaluation —
FineWeb-Edu (HuggingFaceFW/fineweb-edu, local parquet shard, no network).

Source on this box: /home/victor/models/fineweb-edu/sample/10BT/000_00000.parquet
(726,000 documents in 726 row groups of 1,000; HF download metadata: revision
87f09149ef4734204d70ed1d046ddc9ca3f2b8f9, sha256 b1ba7b2c...e871). The directory
holds NO licence file; the public dataset card states ODC-By 1.0 and use subject
to the Common Crawl terms of use (recorded, not verified offline).

Calibration documents come from row group 0, held-out documents from row group 1
(disjoint documents). Each sequence is [BOS] + the first T-1 tokens of one
document; documents shorter than T-1 tokens are skipped. Every sequence's
document id, url, row group / row and a digest of its token ids are recorded.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

PARQUET = Path("/home/victor/models/fineweb-edu/sample/10BT/000_00000.parquet")
PARQUET_SHA256 = "b1ba7b2ce4cb5ea6ef42dca40263eabb85f37700d01693a68e9b30a31d78e871"
HF_REVISION = "87f09149ef4734204d70ed1d046ddc9ca3f2b8f9"
DATASET = "HuggingFaceFW/fineweb-edu (sample/10BT, shard 000_00000)"
LICENCE_NOTE = ("no licence file in /home/victor/models/fineweb-edu; the public dataset card states ODC-By 1.0 "
                "and use subject to the Common Crawl terms of use (recorded, not verified offline)")
ROW_GROUP = {"calib": 0, "heldout": 1}


def fineweb_sequences(tok, which: str, T: int, n: int):
    import pyarrow.parquet as pq
    f = pq.ParquetFile(PARQUET)
    rg = ROW_GROUP[which]
    tab = f.read_row_group(rg, columns=["text", "id", "url"]).to_pydict()
    seqs, meta = [], []
    for row, (text, did, url) in enumerate(zip(tab["text"], tab["id"], tab["url"])):
        if len(seqs) >= n:
            break
        ids = tok.encode(text[:8 * T + 2000], bos=False)
        if len(ids) < T - 1 + 8:          # keep a margin away from the character cut
            continue
        chunk = [1] + ids[:T - 1]
        seqs.append(chunk)
        meta.append({"source": "fineweb-edu", "domain": "fineweb-edu", "doc_id": did, "url": url,
                     "row_group": rg, "row": row,
                     "sha256": hashlib.sha256(",".join(map(str, chunk)).encode()).hexdigest()[:16]})
    return seqs, meta
