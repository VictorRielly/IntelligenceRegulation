#!/usr/bin/env python3
"""Pure-Python BLAKE3 in plain hash mode (32-byte output).

This is the reference algorithm (the BLAKE3 paper, section 2, and the
official `reference_impl`), restricted to what the hashline transcript
needs: unkeyed hashing (key = IV, no KEYED_HASH / DERIVE_KEY flags) of an
arbitrary-length input, 32 bytes out. Multi-chunk inputs (> 1024 bytes)
build the binary tree exactly as the reference does: the left subtree
takes the largest power-of-two number of chunks that leaves at least one
byte for the right subtree; every parent node is compressed with the IV
as chaining value, counter 0, block length 64 and the PARENT flag; the
final node carries ROOT.

Only `blake3_hash(data) -> bytes` is exported. It exists so the
transcript replay in `zk60_transcript_replay.py` runs with no third-party
wheel; `tests/test_zk60_transcript_replay.py` cross-checks it against the
`blake3` wheel on random inputs of lengths 0..5000.
"""
import struct

IV = (
    0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
    0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
)
MSG_PERMUTATION = (2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8)
CHUNK_START = 1 << 0
CHUNK_END = 1 << 1
PARENT = 1 << 2
ROOT = 1 << 3
BLOCK_LEN = 64
CHUNK_LEN = 1024
_M32 = 0xFFFFFFFF
_BLOCK_STRUCT = struct.Struct("<16I")
_OUT_STRUCT = struct.Struct("<8I")


def _rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & _M32


def _g(s, a, b, c, d, mx, my):
    s[a] = (s[a] + s[b] + mx) & _M32
    s[d] = _rotr(s[d] ^ s[a], 16)
    s[c] = (s[c] + s[d]) & _M32
    s[b] = _rotr(s[b] ^ s[c], 12)
    s[a] = (s[a] + s[b] + my) & _M32
    s[d] = _rotr(s[d] ^ s[a], 8)
    s[c] = (s[c] + s[d]) & _M32
    s[b] = _rotr(s[b] ^ s[c], 7)


def _round(s, m):
    # columns
    _g(s, 0, 4, 8, 12, m[0], m[1])
    _g(s, 1, 5, 9, 13, m[2], m[3])
    _g(s, 2, 6, 10, 14, m[4], m[5])
    _g(s, 3, 7, 11, 15, m[6], m[7])
    # diagonals
    _g(s, 0, 5, 10, 15, m[8], m[9])
    _g(s, 1, 6, 11, 12, m[10], m[11])
    _g(s, 2, 7, 8, 13, m[12], m[13])
    _g(s, 3, 4, 9, 14, m[14], m[15])


def compress(cv, block_words, counter, block_len, flags):
    """The BLAKE3 compression function; returns the 16 output words."""
    s = [
        cv[0], cv[1], cv[2], cv[3], cv[4], cv[5], cv[6], cv[7],
        IV[0], IV[1], IV[2], IV[3],
        counter & _M32, (counter >> 32) & _M32, block_len, flags,
    ]
    m = list(block_words)
    for r in range(7):
        _round(s, m)
        if r < 6:
            m = [m[p] for p in MSG_PERMUTATION]
    for i in range(8):
        s[i] ^= s[i + 8]
        s[i + 8] ^= cv[i]
    return s


def _chunk_cv(data, chunk_counter, extra_flags):
    """Chaining value of one chunk (0..1024 bytes); `extra_flags` is ROOT or 0."""
    cv = list(IV)
    n_blocks = max(1, (len(data) + BLOCK_LEN - 1) // BLOCK_LEN)
    for i in range(n_blocks):
        blk = data[i * BLOCK_LEN:(i + 1) * BLOCK_LEN]
        blen = len(blk)
        if blen < BLOCK_LEN:
            blk = blk + bytes(BLOCK_LEN - blen)
        flags = 0
        if i == 0:
            flags |= CHUNK_START
        if i == n_blocks - 1:
            flags |= CHUNK_END | extra_flags
        cv = compress(cv, _BLOCK_STRUCT.unpack(blk), chunk_counter, blen, flags)[:8]
    return cv


def _subtree_cv(data, chunk_counter, is_root):
    if len(data) <= CHUNK_LEN:
        return _chunk_cv(data, chunk_counter, ROOT if is_root else 0)
    full_chunks = (len(data) - 1) // CHUNK_LEN
    left_chunks = 1 << (full_chunks.bit_length() - 1)  # largest power of two <= full_chunks
    left_len = left_chunks * CHUNK_LEN
    left = _subtree_cv(data[:left_len], chunk_counter, False)
    right = _subtree_cv(data[left_len:], chunk_counter + left_chunks, False)
    return compress(list(IV), left + right, 0, BLOCK_LEN, PARENT | (ROOT if is_root else 0))[:8]


def blake3_hash(data):
    """32-byte BLAKE3 hash of `data` (bytes-like), plain hash mode."""
    return _OUT_STRUCT.pack(*_subtree_cv(bytes(data), 0, True))


if __name__ == "__main__":
    import sys
    payload = sys.stdin.buffer.read() if len(sys.argv) < 2 else open(sys.argv[1], "rb").read()
    print(blake3_hash(payload).hex())
