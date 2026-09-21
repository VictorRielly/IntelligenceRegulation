#!/usr/bin/env python3
"""The function-by-function re-reading of `4751b93`, machine-checked.

  python3 results/zk60_native_d22_repin/reread.py > reread.txt

For every Rust item the toy private block's prover or verifier reaches in a
file `4751b93` touches, this prints the item's line range at `4751b93^` and
at `4751b93` and whether its bytes moved. An item is located by its
definition line and ends at the next top-level item, which is what the
files' formatting makes reliable: every definition this port cares about
starts in column 0.

It decides nothing. A byte-identical body means the port still describes
the code; a moved body is a body a human must read. The verdicts live in
`docs/zkmatrix-poc/ZK60_NATIVE_D22_REPIN_4751B93.md`.
"""
from __future__ import annotations

import hashlib
import re
import subprocess

MAIN = "/home/victor/IntelligenceRegulation"
OLD, NEW = "4751b93^", "4751b93"

# The zk.rs items the toy private block reaches, from the `use` lines of
# hashline/src/private_block{,/protocol,/argument,/wire}.rs and
# hashline/src/private_seam.rs, plus everything those items call inside
# zk.rs.  (`ZkRng` is a re-export of zkp-core's, which 4751b93 does not
# touch.)
ZK_ITEMS = [
    "pub const MASK_LOG_MSG",
    "pub const MASK_LOG_DOM",
    "pub const MASK_Q",
    "pub struct MaskCommit",
    "pub struct MaskFunctional",
    "pub struct MaskOpening",
    "impl MaskOpening",
    "fn encode_coeffs_coset",
    "pub fn mask_commit",
    "fn combined_weights",
    "fn weight_polys",
    "fn poly_mul_512",
    "pub fn mask_open",
    "pub fn mask_verify",
    "fn pcs_hash_column",
    "fn mask_challenge",
    "pub(crate) fn masked_prove",
    "pub(crate) fn extension",
]

# The hashline/src/pcs.rs items the toy path reaches.  Everything else it
# uses from `pcs` is a re-export of zkp-core's (`pub use zkp_core::pcs::*`).
PCS_ITEMS = [
    "pub fn commit",
    "pub fn open",
    "pub fn commit_zk",
    "pub fn commit_zk_owned",
    "pub type Store",
    "pub type Committed",
    "pub type CommittedZk",
]

# The layer.rs items zk.rs imports, so that a change to one of them could
# reach the mask commitment through zk.rs's own `use`.
LAYER_ITEMS = [
    "pub const TAG_SILU",
    "pub const TAG_INT8",
    "pub fn tag_range",
    "pub struct Statement",
    "pub struct Layout",
    "pub const LOG_WBLOCK",
]

TOP = re.compile(
    r"^(pub |pub\(crate\) )?(fn |const |static |struct |enum |impl |trait |type |mod |use |#\[)")


def text(commit: str, path: str) -> list[str]:
    p = subprocess.run(["git", "--no-pager", "-C", MAIN, "show", f"{commit}:{path}"],
                       capture_output=True, check=True)
    return p.stdout.decode().splitlines(keepends=True)


LEAD_IN = re.compile(r"^\s*$|^///|^//!|^//|^#\[")


def item(lines: list[str], head: str):
    """(first line number, body) of the top-level item whose definition line
    starts with `head`; the body runs to the next top-level definition, less
    any blank line, doc comment or attribute at the end of that range, which
    belongs to the NEXT item and not to this one."""
    for i, line in enumerate(lines):
        if line.startswith(head) and (len(line) == len(head) or not line[len(head)].isalnum()):
            j = i + 1
            while j < len(lines) and not TOP.match(lines[j]):
                j += 1
            while j - 1 > i and LEAD_IN.match(lines[j - 1]):
                j -= 1
            return i + 1, "".join(lines[i:j])
    return None, None


def report(path: str, items: list[str]) -> None:
    old, new = text(OLD, path), text(NEW, path)
    print("=" * 96)
    print(f"{path}")
    print(f"  {OLD:<10s} {len(old):5d} lines  sha256 {hashlib.sha256(''.join(old).encode()).hexdigest()}")
    print(f"  {NEW:<10s} {len(new):5d} lines  sha256 {hashlib.sha256(''.join(new).encode()).hexdigest()}")
    moved = 0
    for head in items:
        lo, bo = item(old, head)
        ln, bn = item(new, head)
        if bo is None or bn is None:
            print(f"  !! {head}: NOT FOUND ({OLD}: {lo}, {NEW}: {ln})")
            moved += 1
            continue
        same = bo == bn
        moved += 0 if same else 1
        print(f"  {'identical' if same else 'CHANGED  '}  {head:<28s} "
              f"{path.rsplit('/', 1)[-1]}:{lo} -> :{ln}   {len(bo.splitlines())} lines")
    print(f"  --> {moved} of {len(items)} items on the toy path changed")


if __name__ == "__main__":
    report("hashline/src/zk.rs", ZK_ITEMS)
    report("hashline/src/pcs.rs", PCS_ITEMS)
    report("hashline/src/layer.rs", LAYER_ITEMS)
    # The whole-prefix check: everything in zk.rs above the first hunk.
    old, new = text(OLD, "hashline/src/zk.rs"), text(NEW, "hashline/src/zk.rs")
    pre_o = hashlib.sha256("".join(old[:2274]).encode()).hexdigest()
    pre_n = hashlib.sha256("".join(new[:2274]).encode()).hexdigest()
    print("=" * 96)
    print("zk.rs lines 1-2274 (everything above the first hunk, and every ported item):")
    print(f"  {OLD}: {pre_o}")
    print(f"  {NEW}: {pre_n}")
    print(f"  {'IDENTICAL' if pre_o == pre_n else 'DIFFERENT'}")
