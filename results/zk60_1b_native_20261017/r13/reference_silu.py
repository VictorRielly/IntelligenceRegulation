#!/usr/bin/env python3
"""Independent public int12 SiLU tables for the exact S2 registry members."""
import hashlib
import json
import math
from pathlib import Path
import re
import struct

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / 'working-tree/zkp-core/src/tables.rs'
text = SOURCE.read_text()
body = re.search(r'pub const SILU16_V3_MEMBERS:.*?=\s*\[(.*?)\];', text, re.S).group(1)
members = [(int(a), int(b)) for a, b in re.findall(r'\((-?\d+),\s*(-?\d+)\)', body)]
assert len(members) == 9
target = ROOT / 'working-tree/hashline/src/private_block/r13_vectors'
records = []
for e_in, e_out in members:
    words = []
    for gate in range(-2048, 2048):
        x = gate * 2.0 ** (e_in - 4)
        value = math.floor(x / (1 + math.exp(-x)) / 2.0 ** e_out + 0.5)
        words.append(max(-32767, min(32767, value)))
    raw = struct.pack('<4096h', *words)
    path = target / f'silu_{e_in}_{e_out}.bin'
    path.write_bytes(raw)
    records.append(dict(e_in=e_in, e_out=e_out, file=path.name,
                        sha256=hashlib.sha256(raw).hexdigest(), min=min(words), max=max(words)))
report = dict(scope='COUNTED independent public table values; not a native generator or proof',
              registry_source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              input_bits=12, entries_per_table=4096, tables=records)
(ROOT / 'silu_reference.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Generated {len(records)} tables, {len(records) * 4096} int16 words from the pinned registry.')
