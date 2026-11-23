#!/usr/bin/env python3
"""xz-compress (python lzma, preset 6) every raw/traces/*.tsv into raw/traces/*.tsv.xz, check the round trip, delete the .tsv, print sizes and SHA-256 of the .xz files.

usage: compress_traces.py [RAW_DIR]
"""
import hashlib
import lzma
import sys
from pathlib import Path

raw = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / 'raw'
for f in sorted((raw / 'traces').glob('*.tsv')):
    data = f.read_bytes()
    out = f.with_name(f.name + '.xz')
    out.write_bytes(lzma.compress(data, preset=6))
    assert lzma.decompress(out.read_bytes()) == data, f
    f.unlink()
    print(out.name, len(data), '->', out.stat().st_size, hashlib.sha256(out.read_bytes()).hexdigest())
