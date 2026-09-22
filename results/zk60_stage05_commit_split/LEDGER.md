# Stage 0.5 — where the hiding commitment's CPU time actually goes

**Opened 2026-09-22 13:09 PDT** on the review worktree
`/home/victor/wt-zk60-block125m-review` (branch
`zk60-private-block-125m-review`). Measurement only: **no production line
changes anywhere**, one new `#[cfg(test)]` module and this ledger.

## Why this exists

Ruling **DC-G(1)** of
`docs/zkmatrix-poc/ZK60_HIDING_COMMITMENT_ON_DEVICE_DISPOSITION.md`:

> **Stage 0.5, before any kernel: split the measured `A: commit` into encode
> and hash.** Compression counts say hashing dominates the count; nobody has
> measured whether it dominates the TIME. If the encode is the larger half,
> "encode on the device, hash on the host" needs no keyed kernel at all and
> the whole keyed-CUDA question moves down the list.

The count is not in dispute: §2.2 of the memo counts **112,066,560 of
112,590,844** compressions in the column digests [COUNTED]. A compression
count is not a second, and that is the whole point of this page. The device
plan's first kernel is scoped by the answer.

## The question, stated so it can be answered wrong

Per hiding commitment, the CPU does five things in this order
(`zkp_core::pcs::commit_zk_owned_with_tag`, `pcs.rs:769`):

1. draw the pad rows and the column salts (`ZkRng`);
2. build the coset powers;
3. **encode** every row (`encode_row_zk`: inverse NTT, pad splice, coset
   twist, forward NTT) into the `rows × nn` encoded matrix;
4. **hash** every encoded column into a leaf digest
   (`hash_columns_keyed`, which transposes 64 columns at a time into byte
   buffers and then BLAKE3s each);
5. salt the leaves and build the keyed Merkle tree.

Which of 3 and 4 is the larger number of seconds, at the 125M shape and at
rung-W14?

## Sections this ledger owes

- [ ] **1.** What was measured, and with which functions and parameters
- [ ] **2.** The table at rung-W14 (527 / 436 / 9 / 50 rows)
- [ ] **3.** The table at 125M (5,681 / 7,120 / 37 rows)
- [ ] **4.** Do the parts sum to the whole, and does the whole reproduce the
      prover's own phase clock (`A: commit` 3.076 s, `H: commit` 3.499 s)
- [ ] **5.** Keyed against unkeyed column hashing
- [ ] **6.** The answer in one sentence, and what it means for DC-G
- [ ] **7.** What this is NOT

## The rules this page is run under

- Every second is `[MEASURED, 3 runs, shared box, not quiesced]`, reported
  min / median / max over three repetitions inside one process.
- No extrapolation to another shape or another machine. No count is ever
  turned into a time.
- Synthetic random rows: the field arithmetic and the byte hashing cost the
  same on any values, so no witness and no private value is generated,
  logged or committed here.
- No GPU: `HL_GPU` is unset, the `gpu-cuda` feature is off, and a tagged
  profile's keyed column digest is never offered to the device hasher
  anyway (ruling T-8, `pcs.rs:781-785`).
