"""A shorter Merkle path is accepted by `verify_path` as written.

Mirrors zkp-core/src/merkle.rs:56-63 (fold however many siblings are handed
in) and zkp-core/src/pcs.rs:1018 (leaf = salt_leaf(hash_column(col), salt)),
with SHA-256 standing in for BLAKE3: the point is structural (leaf and inner
node are the same function on the same 64 bytes), not about the hash.

Honest tree of 8 salted leaves, except that the depth-2 node at position 1 is
PLANTED: its left child is the digest of an alternative column `c`, its right
child is a genuine leaf.  Then:
  - index 1 opens to its genuine column with a 3-entry path, AND to `c` with
    a 2-entry path;
  - index 5 (= 1 mod 4) also opens to `c` with a 2-entry path;
  - index 2 (the planted left child) can no longer be opened at all;
  - with the length check `len(path) == depth`, every short opening is refused.
"""
import hashlib
import os


def h(*parts: bytes) -> bytes:
    return hashlib.sha256(b"".join(parts)).digest()


def hash_pair(a, b):
    return h(a, b)


def salt_leaf(col_digest, salt):
    return h(col_digest, salt)


def hash_column(col: bytes):
    return h(col)


def verify_path(root, idx, leaf, path, depth=None):
    if depth is not None and len(path) != depth:
        return False
    cur = leaf
    for sib in path:
        cur = hash_pair(cur, sib) if idx & 1 == 0 else hash_pair(sib, cur)
        idx >>= 1
    return cur == root


def build(leaves):
    levels = [leaves]
    while len(levels[-1]) > 1:
        p = levels[-1]
        levels.append([hash_pair(p[i], p[i + 1]) for i in range(0, len(p), 2)])
    return levels


def path(levels, idx):
    out = []
    for lvl in levels[:-1]:
        out.append(lvl[idx ^ 1])
        idx >>= 1
    return out


ROWS = 7  # 56-byte columns: not 64, as the lane's guard requires
cols = [os.urandom(8 * ROWS) for _ in range(8)]
salts = [os.urandom(32) for _ in range(8)]
leaves = [salt_leaf(hash_column(c), s) for c, s in zip(cols, salts)]

alt = os.urandom(8 * ROWS)          # the alternative column
leaves[2] = hash_column(alt)        # planted: leaf 2 := digest of `alt`
levels = build(leaves)
root = levels[-1][0]
planted = levels[1][1]              # = H(hash_column(alt) || leaves[3])
assert planted == salt_leaf(hash_column(alt), leaves[3])

results = {}
# genuine, full-depth opening of index 1
results["index 1, genuine column, 3-entry path"] = verify_path(
    root, 1, salt_leaf(hash_column(cols[1]), salts[1]), path(levels, 1))
# short opening of index 1 and of index 5 to the alternative column
short = [levels[1][0], levels[2][1]]
for j in (1, 5):
    results[f"index {j}, ALTERNATIVE column, 2-entry path"] = verify_path(
        root, j, salt_leaf(hash_column(alt), leaves[3]), short)
# index 2 is dead at full depth
results["index 2, genuine column, 3-entry path"] = verify_path(
    root, 2, salt_leaf(hash_column(cols[2]), salts[2]), path(levels, 2))
# the one-line fix
for j in (1, 5):
    results[f"index {j}, ALTERNATIVE column, 2-entry path, length checked"] = verify_path(
        root, j, salt_leaf(hash_column(alt), leaves[3]), short, depth=3)

for k, v in results.items():
    print(f"{'ACCEPTED' if v else 'refused '}  {k}")

assert results["index 1, genuine column, 3-entry path"]
assert results["index 1, ALTERNATIVE column, 2-entry path"]
assert results["index 5, ALTERNATIVE column, 2-entry path"]
assert not results["index 2, genuine column, 3-entry path"]
assert not results["index 1, ALTERNATIVE column, 2-entry path, length checked"]
assert not results["index 5, ALTERNATIVE column, 2-entry path, length checked"]
print("OK: index 1 opens two ways without the length check, one way with it")
