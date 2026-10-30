"""Exact signed-byte GEMMs for numerical replay, under the shared GPU guard.

For signed16 x: x = lo + 256*hi + 128, with signed-byte lo/hi.
For signed24 x: x = lo + 256*mid + 65536*hi + 32896.
Each int8 GEMM accumulates in int32 (K<=16384 => abs<=2^28); recombination
uses int64. The result is below2^44 and converts exactly to baseline float64.
This module changes only matrix execution, never rounding or range recording.
"""
import numpy as np


def split_words(x):
    x = np.asarray(x)
    if not np.isfinite(x).all() or not np.array_equal(x, np.floor(x)):
        raise ValueError('GPU integer matmul requires finite integer words')
    if x.size == 0 or x.min() < -(1 << 23) or x.max() >= 1 << 23:
        raise ValueError('GPU integer matmul input outside signed24')
    values = x.astype(np.int64)
    width = 2 if values.min() >= -32768 and values.max() <= 32767 else 3
    parts = [(((values >> (8 * i)) & 255) - 128).astype(np.int8) for i in range(width - 1)]
    parts.append((values >> (8 * (width - 1))).astype(np.int8))
    offset = 128 * sum(1 << (8 * i) for i in range(width - 1))
    return parts, offset


def configure():
    import torch
    if not torch.cuda.is_available():
        raise RuntimeError('CUDA is unavailable; GPU work requires the guarded host launcher')
    torch.set_num_threads(2)
    total = torch.cuda.get_device_properties(0).total_memory
    # <=3GiB allocator budget leaves room below the project4GiB total limit
    # for the CUDA context/cuBLAS. The guard records total-device VRAM too.
    torch.cuda.set_per_process_memory_fraction(min(.4, 3 * (1 << 30) / total), 0)
    torch.cuda.reset_peak_memory_stats(0)
    return torch


class IntegerMat:
    def __init__(self, words):
        import torch
        words = np.asarray(words)
        if words.ndim != 2 or words.dtype != np.dtype('int8') or np.any(words == -128):
            raise ValueError('GPU weights must be a symmetric int8 matrix')
        self.inner, self.outputs = words.shape
        if not 0 < self.inner <= 16384 or not 0 < self.outputs <= 16384:
            raise ValueError('GPU matrix dimensions outside the audited class')
        self.padded_inner = (self.inner + 31) // 32 * 32
        self.padded_outputs = (self.outputs + 31) // 32 * 32
        padded = np.zeros((self.padded_inner, self.padded_outputs), dtype=np.int8)
        padded[:self.inner, :self.outputs] = words
        self.words = torch.from_numpy(padded).to('cuda')
        self.column_sum = self.words.sum(0, dtype=torch.int64)

    def __call__(self, x):
        import torch
        shape = x.shape
        if shape[-1] != self.inner:
            raise ValueError('GPU matrix input dimension differs')
        flat = x.reshape(-1, shape[-1])
        parts, offset = split_words(flat)
        rows = len(flat)
        padded_rows = (rows + 31) // 32 * 32
        out = torch.zeros((padded_rows, self.padded_outputs), dtype=torch.int64, device='cuda')
        for index, piece in enumerate(parts):
            padded = np.zeros((padded_rows, self.padded_inner), dtype=np.int8)
            padded[:rows, :self.inner] = piece
            operand = torch.from_numpy(padded).to('cuda')
            partial = torch._int_mm(operand, self.words)
            out.add_(partial.to(torch.int64), alpha=1 << (8 * index))
        out.add_(self.column_sum, alpha=offset)
        return out[:rows, :self.outputs].cpu().numpy().astype(np.float64).reshape(*shape[:-1], self.outputs)


def prepare(model):
    for site, matrix in list(model.int.items()):
        model.int[site] = IntegerMat(matrix.m)
    return model
