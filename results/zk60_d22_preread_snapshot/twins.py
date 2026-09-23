"""The tagged twins against their legacy originals, in the snapshot.

The snapshot's toy path calls the NEW `*_tagged` / `*_keyed` entry points
with `HashTag::legacy()` (key `None`), where main at `4751b93` called the
legacy functions.  For each pair this prints the unified diff of the two
function bodies (legacy -> tagged), so the reader can check that, with
every key `None`, the tagged body performs the same draws in the same order,
the same transcript operations and the same hashing as the original.

    python3 results/zk60_d22_preread_snapshot/twins.py [--snapshot DIR]
"""
from __future__ import annotations

import argparse
import difflib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from items import items  # noqa: E402

PAIRS = [
    ("hashline/src/zk.rs", "fn mask_commit#0", "fn mask_commit_tagged#0"),
    ("hashline/src/zk.rs", "fn mask_verify#0", "fn mask_verify_tagged#0"),
    ("hashline/src/zk.rs", "fn pcs_hash_column#0", "fn pcs_hash_column_keyed#0"),
    ("hashline/src/pcs.rs", "fn commit_zk_owned#0", "fn commit_zk_owned_tagged#0"),
    ("zkp-core/src/pcs.rs", "fn commit_zk_owned_with#0", "fn commit_zk_owned_with_tag#0"),
    ("zkp-core/src/pcs.rs", "fn verify_zk#0", "fn verify_zk_tagged#0"),
    ("zkp-core/src/pcs.rs", "fn hash_column#0", "fn hash_column_keyed#0"),
    ("zkp-core/src/pcs.rs", "fn hash_columns#0", "fn hash_columns_keyed#0"),
    ("zkp-core/src/pcs.rs", "fn salt_leaf#0", "fn salt_leaf_keyed#0"),
    ("zkp-core/src/merkle.rs", "fn hash_pair#0", "fn hash_pair_keyed#0"),
    ("zkp-core/src/merkle.rs", "impl MerkleTree::fn build#0", "impl MerkleTree::fn build_keyed#0"),
    ("zkp-core/src/merkle.rs", "impl MerkleTree::fn verify_path#0", "impl MerkleTree::fn verify_path_keyed#0"),
    ("zkp-core/src/transcript.rs", "impl Transcript::fn new#0", "impl Transcript::fn new_tagged#0"),
]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--snapshot", default="/tmp/claude-1000/d22-snapshot")
    a = ap.parse_args()
    cache = {}
    for path, legacy, tagged in PAIRS:
        if path not in cache:
            cache[path] = items(open(os.path.join(a.snapshot, path)).read())
        it = cache[path]
        lt, tt = it[legacy][0], it[tagged][0]
        d = list(difflib.unified_diff(lt.splitlines(), tt.splitlines(),
                                      fromfile=f"{path} {legacy}",
                                      tofile=f"{path} {tagged}", lineterm="", n=1))
        print(f"################ {path}: {legacy} -> {tagged}  "
              f"({len(lt.splitlines())} -> {len(tt.splitlines())} lines)")
        print("\n".join(d))
        print()


if __name__ == "__main__":
    main()
