"""Shieldstral geometry and public weight preparation for the A2 export.

No export/fidelity claim: this is the shared foundation for the calibration port.
The residual rotation uses THREE independent 1024-point Hadamard blocks, since
3072 is not a power of two. It preserves RMS and costs no new prover relation.
"""
import math
import numpy as np

D, FF, HEADS, KV_HEADS, HEAD_DIM, LAYERS, VOCAB = 3072, 9216, 32, 8, 128, 26, 131072
QUERY_WIDTH = HEADS * HEAD_DIM
MODEL = {"repo": "mistralai/Shieldstral-1.0-3B",
         "revision": "003ec7e2b0bab5f0e6307edbaf186fa5822b76f5",
         "sha256": "87753e30c8c321da478b83bbabebcd813cc9b3d0cee5c5b3d64349a8ee4172f7"}
TIED = {"tensor": "language_model.model.embed_tokens.weight",
        "sha256": "67a138c1c483b89874526ef523f5f0c30f161808076561730193d1de2093dd19"}
ROPE = {"rope_type": "yarn", "factor": 16.0, "original_max_position_embeddings": 16384,
        "beta_fast": 32.0, "beta_slow": 1.0, "mscale": 1.0, "mscale_all_dim": 1.0,
        "attention_factor": 1.0, "truncate": True}


def inverse_frequencies():
    dim, theta = HEAD_DIM, 1_000_000.0
    powers = theta ** (np.arange(0, dim, 2, dtype=np.float64) / dim)
    ext, inter = 1.0 / powers, 1.0 / (ROPE['factor'] * powers)
    def correction(n):
        return dim * math.log(ROPE['original_max_position_embeddings'] / (n * 2 * math.pi)) / (2 * math.log(theta))
    lo, hi = max(math.floor(correction(32)), 0), min(math.ceil(correction(1)), dim - 1)
    ramp = np.clip((np.arange(dim // 2, dtype=np.float64) - lo) / (hi - lo), 0, 1)
    extrap = 1 - ramp
    return inter * (1 - extrap) + ext * extrap


def rope_tables(tokens: int, bits: int | None = None):
    if type(tokens) is not int or not 1 <= tokens <= 16384:
        raise ValueError('positions >=16384 require the extra Llama-4 query scale')
    angles = np.arange(tokens, dtype=np.float64)[:, None] * inverse_frequencies()[None, :]
    tables = np.cos(angles), np.sin(angles)
    if bits is None:
        return tables
    if type(bits) is not int or not 0 <= bits <= 15:
        raise ValueError('unsupported RoPE precision')
    return tuple(np.floor(t * (1 << bits) + 0.5).astype(np.int64) for t in tables)


class Rotation:
    def __init__(self, n=D, seed=1, block=1024):
        if type(n) is not int or type(block) is not int or n < 1 or block < 1 or n % block or block & (block - 1):
            raise ValueError('rotation width must be a multiple of a power-of-two block')
        self.n, self.seed, self.block = n, seed, block
        self.sign = np.where(np.random.default_rng(seed).integers(0, 2, n) == 1, 1.0, -1.0)

    def _hadamard(self, x):
        x = np.asarray(x, dtype=np.float64)
        if x.shape[-1] != self.n:
            raise ValueError('rotation width mismatch')
        shape = x.shape
        y = x.reshape(-1, self.n // self.block, self.block).copy()
        step = 1
        while step < self.block:
            z = y.reshape(-1, self.n // self.block, self.block // (2 * step), 2, step)
            lo, hi = z[..., 0, :].copy(), z[..., 1, :].copy()
            z[..., 0, :], z[..., 1, :] = lo + hi, lo - hi
            step *= 2
        return y.reshape(shape) / math.sqrt(self.block)

    def fwd(self, x):
        return self._hadamard(np.asarray(x) * self.sign)

    def inv(self, x):
        return self._hadamard(x) * self.sign

    def metadata(self):
        import hashlib
        return {"kind": "block-hadamard", "width": self.n, "block_width": self.block,
                "blocks": self.n // self.block, "seed": self.seed,
                "sign_sha256": hashlib.sha256(self.sign.astype('<f8').tobytes()).hexdigest(),
                "rule": "R=blockdiag(H1024,H1024,H1024) diag(sign) / 32; x_rot=x R^T"}


def profile_model_fields(tokens):
    if tokens not in (128, 256):
        raise ValueError('R12 registers only Shieldstral T128 and T256')
    return {"model": MODEL.copy(), "geometry": f"shieldstral-3b-t{tokens}", "T": tokens,
            "rope_scaling": ROPE.copy(), "tied_embeddings": TIED.copy()}


def tied_source():
    return {"name": TIED['tensor'], "sha256": TIED['sha256']}
