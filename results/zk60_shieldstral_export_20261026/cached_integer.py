"""Cache the original float64 column blocks; preserve every integer operation.

The baseline Mat converts the same three large int8 matrices for every item.
This adapter retains those exact converted blocks for the lifetime of one layer.
It uses the same output-column boundaries and the same float64 matrix products.
No range check, quantizer, table, or model parameter is changed.
"""
import numpy as np


class CachedMat:
    def __init__(self, original):
        if not original.big:
            raise ValueError('only large baseline matrices need a cache')
        self.inner, self.outputs = original.m.shape
        self.blocks = [(c, original.m[:, c:c + original.BLOCK].astype(np.float64))
                       for c in range(0, self.outputs, original.BLOCK)]

    def __call__(self, x):
        shape = x.shape
        if shape[-1] != self.inner:
            raise ValueError('cached matrix input dimension differs')
        flat = x.reshape(-1, shape[-1])
        out = np.empty((len(flat), self.outputs), dtype=np.float64)
        for column, block in self.blocks:
            out[:, column:column + block.shape[1]] = flat @ block
        return out.reshape(*shape[:-1], self.outputs)


def prepare(model):
    """Cache one layer only, after any explicit calibration amendment."""
    for name, matrix in list(model.int.items()):
        if getattr(matrix, 'big', False):
            model.int[name] = CachedMat(matrix)
    return model
