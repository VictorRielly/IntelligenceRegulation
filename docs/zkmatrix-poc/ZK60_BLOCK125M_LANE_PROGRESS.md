# Lane `zk60-private-block-125m` — progress ledger

Worktree `/home/victor/wt-zk60-block125m`, branch `zk60-private-block-125m`,
opened from the shared branch tip `73d3398` on 2026-09-20. ONE writer (this
delegated implementer). Everything else on the box is read-only for this lane.

Both parts are **purely additive**. The change list of
`ZK60_PRIVATE_BLOCK_125M_LAYOUT.md` §9 is NOT started (step S1 and everything
after it wait on Codex's answer to "who implements"); no shared constant is
touched.

## The two parts

| Part | What | Files |
|---|---|---|
| **A** (project id **U-4**) | the zero-witness acceptance test on the TOY profile as it is: the all-zero hidden input proves and the receipt verifies from bytes; the constants and the two range boundaries the paper trace rests on are asserted so a calibration change fails loudly | `hashline/src/private_block/zero_witness_tests.rs` (new) + ONE `mod` line in `hashline/src/private_block.rs` |
| **B** | an independent, shape-driven layout model in pure Python: padded domains, plane list, A/H/M totals, opening groups, slots and receipt bytes from a shape; reproduces the toy EXACTLY or it means nothing; then the rung and the 125M shape beside the memo's [COUNTED] figures | `scripts/zk60_private_block_layout_model.py`, `tests/test_zk60_private_block_layout_model.py` (both new) |

## Status

| Step | State | Evidence |
|---|---|---|
| A0 skeleton + ledger | DONE | this file, commit 1 |
| A1 zero-witness proves and verifies from bytes | PENDING | |
| A2 constants + boundary assertions | PENDING | |
| A3 receipt length equal; two proofs differ | PENDING | |
| A4 whole module filter green, before and after | PENDING | |
| B1 model module | PENDING | |
| B2 toy reproduces exactly | PENDING | |
| B3 rung + 125M beside the memo | PENDING | |
| B4 pad-table recount | PENDING | |

## Commands run (every one, with its log)

| # | Command (shape) | Log |
|---|---|---|
| | | |

## Findings

(none yet). Nothing is written outside this worktree, and no witness value,
salt or private plane appears in any evidence file: counts, sizes, booleans
and digests only.
