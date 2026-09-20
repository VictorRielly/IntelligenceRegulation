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
| A1 zero-witness proves and verifies from bytes | DONE | `results/zk60_block125m_lane/partA-run1.log:113` |
| A2 constants + boundary assertions | DONE | `…partA-run1.log:114` |
| A3 receipt length equal; two proofs differ | DONE | `…partA-run1.log:115-116` |
| A4 whole module filter green, before and after | DONE | before: `partA-baseline.log:116` 36 passed / 0 failed / 1 ignored; after: `partA-run1.log:118` 40 passed / 0 failed / 1 ignored |
| B1 model module | PENDING | |
| B2 toy reproduces exactly | PENDING | |
| B3 rung + 125M beside the memo | PENDING | |
| B4 pad-table recount | PENDING | |

## Commands run (every one, with its log)

The Rust command, in full, is always this one (one call, output appended to a
log under `results/zk60_block125m_lane/`, read narrowly afterwards):

```
flock -w 540 /tmp/zk-build.lock env CARGO_TARGET_DIR=/home/victor/wt-zk60-attention-compile/hashline/target \
  CARGO_PROFILE_RELEASE_LTO=false CARGO_PROFILE_RELEASE_CODEGEN_UNITS=8 \
  /home/victor/.cargo/bin/cargo test --release --offline -j 2 \
  --manifest-path /home/victor/wt-zk60-block125m/hashline/Cargo.toml --lib private_block -- --test-threads=1
```

| # | Command | Log | Result |
|---|---|---|---|
| 1 | the Rust command above, BEFORE any edit (baseline) | `results/zk60_block125m_lane/partA-baseline.log` | 36 passed, 0 failed, 1 ignored, 81 filtered out, 18.31 s |
| 2 | the same, with `zero_witness_tests.rs` registered | `results/zk60_block125m_lane/partA-run1.log` | 40 passed, 0 failed, 1 ignored, 81 filtered out, 19.81 s — compiled and passed on the first attempt, no fix needed |

## Findings

**A-F1 (PART A, the headline).** The all-zero hidden input is a valid witness
of the toy profile IN THE CODE, not only on paper: `witness::build` accepts
it, the honest prover produces a receipt, and that receipt verifies typed,
after a byte round trip, and through `verify_bytes`. **No refusal, nothing to
report as a failure.** The block output of the zero input is itself zero
(every stage annihilates), so the output endpoint commits a zero plane.

**A-F2.** The two boundary values the check found are reproduced exactly by
the module's own witness, and are now asserted with their limits:

| fact | plane(s) | value at the zero input | the limit it sits against | headroom |
|---|---|---:|---|---:|
| softmax remainder complement `sigma_s` | `A_SG0 + 256·A_SG1` | **16,383** | `sigma < 1 << WRHO_S = 16,384`, EXCLUSIVE (`witness.rs:298`) | **0** |
| softmax quotient `p` | `A_P` | **512** | `0 ..= 1 << F_P = 512`, INCLUSIVE (`witness.rs:298`) | **0** |

Both are asserted twice over: the value equals the boundary, and one more
would fall outside — so a one-bit change in `WRHO_S` or `F_E`, or turning the
inclusive quotient bound exclusive, fails this test rather than silently
invalidating the fixed input of the privacy argument.

**A-F3.** The two constants are asserted at their sources: `NORM_CEPS == 1`
(`layout.rs:54`), with `isqrt(NORM_CEPS) == 1` and the norm denominator
positive; and `exp[0] == 2^F_E` — not merely for this fixture, but as a
CONSTRUCTOR REFUSAL: `AttentionPublic::new` is shown to reject a statement
whose `exp[0]` is 0 (`private_block.rs:138`), which is what stops an
adversarially chosen public statement from destroying the fixed input.

**A-F4.** The receipt length does not move with the hidden input: the zero
witness's frame and the fixture witness's frame are both exactly 2,816,472 B,
and two proofs of the same zero witness differ in their bytes while both
verify (fresh OS randomness per attempt; the endpoint roots differ too, and
neither receipt verifies under the other attempt's endpoint policy).

Nothing is written outside this worktree, and no witness value, salt or
private plane appears in any evidence file: counts, sizes, booleans and
digests only. A zero-witness proof that verifies is a PRECONDITION for the
privacy argument, not a privacy result.
