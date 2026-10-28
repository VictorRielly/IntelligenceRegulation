"""Pinned, layer-streamed BF16 checkpoint interface for the isolated port.

The entire safetensors file and the tied tensor are hashed before use. Reads use
pread, so file-backed mappings cannot accumulate outside the declared RSS budget.
Opening a checkpoint belongs inside a guarded calibration leaf, never a test import.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import struct
import numpy as np
from shieldstral_geometry import D, FF, HEADS, KV_HEADS, HEAD_DIM, LAYERS, VOCAB, MODEL, TIED

SNAPSHOT = Path('/home/victor/models/shieldstral-1.0-3b/snapshot-003ec7e2')


def read_exact(fd, size, offset):
    out = bytearray(size)
    view = memoryview(out)
    read = 0
    while read < size:
        n = os.preadv(fd, [view[read:]], offset + read)
        if n <= 0:
            raise OSError('short checkpoint read')
        read += n
    return out


def hash_range(fd, offset, size):
    h = hashlib.sha256()
    for start in range(0, size, 1 << 20):
        h.update(read_exact(fd, min(1 << 20, size - start), offset + start))
    return h.hexdigest()


class TensorRef:
    def __init__(self, ck, name, meta):
        if meta['dtype'] != 'BF16':
            raise ValueError(f'{name}: expected BF16')
        self.ck, self.name = ck, name
        self.shape = tuple(meta['shape'])
        self.start, self.end = meta['data_offsets']
        self.data_start = ck.base
        self.shard = ck.path
        if self.end - self.start != 2 * math.prod(self.shape) or not 0 <= self.start < self.end <= ck.size - ck.base:
            raise ValueError(f'{name}: invalid tensor extent')

    def read_bytes(self, max_bytes=None):
        n = self.end - self.start
        if max_bytes is not None and n > max_bytes:
            raise ValueError('tensor exceeds requested byte cap')
        return read_exact(self.ck.fd, n, self.ck.base + self.start)

    def bf16_rows(self):
        return BF16Rows(self)


class BF16Rows:
    def __init__(self, ref):
        if len(ref.shape) != 2:
            raise ValueError('row reader requires a matrix')
        self.ref, self.shape = ref, ref.shape

    def __getitem__(self, key):
        ref, (rows, width) = self.ref, self.shape
        if isinstance(key, slice):
            start, stop, step = key.indices(rows)
            if step != 1:
                return self[np.arange(start, stop, step)]
            raw = read_exact(ref.ck.fd, max(0, stop - start) * width * 2,
                             ref.ck.base + ref.start + start * width * 2)
            return np.frombuffer(raw, dtype='<u2').reshape(max(0, stop - start), width)
        ids = np.asarray(key)
        if ids.dtype.kind not in 'iu' or np.any(ids < 0) or np.any(ids >= rows):
            raise ValueError('invalid token row index')
        out = np.empty((ids.size, width), dtype='<u2')
        for j, row in enumerate(ids.reshape(-1)):
            raw = read_exact(ref.ck.fd, width * 2, ref.ck.base + ref.start + int(row) * width * 2)
            out[j] = np.frombuffer(raw, dtype='<u2')
        return out.reshape(*ids.shape, width)


class Checkpoint:
    def __init__(self, snapshot=SNAPSHOT):
        self.path = Path(snapshot)/'model.safetensors'
        self.fd = os.open(self.path, os.O_RDONLY)
        try:
            self.size = os.fstat(self.fd).st_size
            if hash_range(self.fd, 0, self.size) != MODEL['sha256']:
                raise ValueError('Shieldstral safetensors SHA256 differs from model pin')
            length = struct.unpack('<Q', read_exact(self.fd, 8, 0))[0]
            if not 2 <= length <= min(64 << 20, self.size - 8):
                raise ValueError('invalid safetensors header extent')
            header = json.loads(read_exact(self.fd, length, 8))
            self.base = 8 + length
            prefix = 'language_model.'
            self.refs = {name[len(prefix):]: TensorRef(self, name, meta)
                         for name, meta in header.items() if name.startswith(prefix)}
            tied = self.refs['model.embed_tokens.weight']
            if tied.shape != (VOCAB, D) or hash_range(self.fd, self.base + tied.start, tied.end - tied.start) != TIED['sha256']:
                raise ValueError('tied embedding tensor shape or SHA256 differs from pin')
            if 'lm_head.weight' in self.refs:
                raise ValueError('expected tied head, found a separate lm_head')
            self.refs['lm_head.weight'] = tied
            self.config = {'layers': LAYERS}
            if self.refs['model.norm.weight'].shape != (D,):
                raise ValueError('final norm width mismatch')
            for layer in range(LAYERS):
                self.layer(layer)  # validate every matrix before calibration starts
        except Exception:
            os.close(self.fd)
            self.fd = None
            raise

    def layer(self, index):
        if type(index) is not int or not 0 <= index < LAYERS:
            raise ValueError('invalid layer')
        shapes = {'input_layernorm.weight': (D,), 'post_attention_layernorm.weight': (D,),
                  'self_attn.q_proj.weight': (HEADS * HEAD_DIM, D),
                  'self_attn.k_proj.weight': (KV_HEADS * HEAD_DIM, D),
                  'self_attn.v_proj.weight': (KV_HEADS * HEAD_DIM, D),
                  'self_attn.o_proj.weight': (D, HEADS * HEAD_DIM),
                  'mlp.gate_proj.weight': (FF, D), 'mlp.up_proj.weight': (FF, D),
                  'mlp.down_proj.weight': (D, FF)}
        out = {name: self.refs[f'model.layers.{index}.{name}'] for name in shapes}
        if any(out[name].shape != shape for name, shape in shapes.items()):
            raise ValueError(f'layer {index}: decoder geometry mismatch')
        return out

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None
