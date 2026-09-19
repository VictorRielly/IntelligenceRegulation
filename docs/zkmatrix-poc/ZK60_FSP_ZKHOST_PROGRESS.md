# FSP lane 3 — give the private prover lane AL's host fix

**Worktree** `/home/victor/wt-fsp-zkhost`, branch `fsp-zkhost`, from the
main-branch tip `ad0f50c`.
**Sole writer.** Files owned: `hashline/src/zk.rs`, `results/fsp3_*`, this
ledger. Everything else in this repository and every other worktree is
READ-ONLY for this lane. `hashline/src/gpu/*` and `hashline/src/ntt.rs`
belong to the second speed lane at `/home/victor/wt-fsp-l9`.

**What the lane is.** Lane AL (2026-09-04) took the PUBLIC 8B feed-forward
pass from 98.54 s to 58.40 s with two host-side changes in
`hashline/src/layer.rs` and no change to a single proof byte: a two-slot
host staging pool, and folding the matmul weight blocks straight off the
int8 planes instead of off a converted 64-bit copy. AL deliberately did not
touch `hashline/src/zk.rs`, which carries its own copy of the v3 prover
body with its own `w_data` / `a_data` allocations. This lane ports both,
behind environment switches in AL's style so the old arm stays in the
binary for the A/B and for rollback.

**The lane is strictly byte-preserving.** It changes HOW host buffers are
allocated, staged and folded — never WHAT is committed, in what order,
under what label, with what randomness. No transcript, mask-schedule,
endpoint or privacy-policy change is in scope. A change that moves any
frozen digest is a BUG: revert it, record it, move on. Never adjust a gate,
never re-freeze a digest.

**No privacy claim is made here.** The legacy `--zk` profile being sped up
is known to DISCLOSE private values (2026-09-08 finding, `START_HERE.md`
privacy correction). This lane neither repairs nor endorses it; it is the
machinery the repaired private feed-forward wraps, which is why its host
cost matters (see stage 1 below — the repaired path does run through the
body changed here).

Every number carries its shape, conditions and label: [MEASURED],
[COUNTED], [MODEL].

---

## Stages

| # | stage | status |
|---|---|---|
| 0 | Ledger, ownership, the two AL changes read in full | DONE |
| 1 | Does the repaired private FFN run through this body? | DONE |
| 2 | Baseline gates on the untouched tree | pending |
| 3 | Port the staging pool behind `HL_FSP_POOL` | pending |
| 4 | Port the int8-plane fold behind `HL_FSP_I8FOLD` | pending |
| 5 | A/B at 12 x 512 only, CPU and GPU binaries | pending |

Owed to a quiet window (NOT run by this lane, by instruction): the
Mistral-width (4096 / 14336) tamper battery through the GPU zero-knowledge
prover, and any 8B A/B. This lane runs the 12 x 512 (125M-class) fixtures
and nothing wider, on either processor.

---

## Reference: what lane AL actually did

Commits on this branch's history:

* `a885695` — RUNG 1, the pooled host staging buffer. 4-layer prove
  10.94 -> 8.78 s (1.25x), proof byte-identical. [MEASURED, lane AL]
* `a0a342b` — RUNG 2, the matmul folds read the int8 planes and the two
  passes become one. matmul g/u 0.66 -> 0.39 s, matmul d 0.36 -> 0.24 s,
  4-layer prove 10.97 -> 8.40 s (1.31x), proof byte-identical.
  [MEASURED, lane AL]
* Write-up `results/hashline_convert_gpu.md` sections 1-7; the 8B row is
  section 7 and `results/hashline_convert_r3.log`.

AL's finding, in one line: `vec![Fp::ZERO; w_len]` does not specialise to
`alloc_zeroed` for a user type, so every layer wrote 1.4 GB of zeros over
~344k first-touch page faults — 0.60 s per layer against 0.05 s for the
`Fp::from_i64` fill that immediately overwrote them.

AL's switches: `HL_AL_POOL=0` and `HL_AL_I8FOLD=0` (default ON).

**AL's helpers are private to `layer.rs`** — `mod hostbuf` (layer.rs:337)
and `fn fold_block_i8` (layer.rs:405) are both module-private, not
`pub(crate)`. Per this lane's ownership rules a visibility change in a file
this lane does not own is NOT allowed, so both are re-implemented inside
`zk.rs` with the same semantics and separate statics. Consequence worth
recording: the two pools are independent, so a process that ran both the
public and the private v3 prover would retire one buffer in each. In
practice a run uses one path or the other. **Suggested follow-up for the
owner of `layer.rs`:** promote `hostbuf` and `fold_block_i8` to
`pub(crate)` and delete the copies in `zk.rs`.

---

## Log

### 2026-09-19 — stage 0, ledger opened

Read: `ZK60_FIVE_SECOND_PLAN.md` sections 1.2, 1.4, 3, 6/Lane 3;
`results/hashline_convert_gpu.md` sections 1-5; AL's two commits;
`hashline/src/layer.rs` 330-430 and 1289-1640; `hashline/src/zk.rs`
2279-2900; `results/cl1_floors.sh`; `scripts/hashline_cl_gpu_gates.py`
95-175.

### 2026-09-19 — stage 1, does the repaired private FFN run through this body?

**YES.** The chain, with file:line:

* `hashline/src/zk.rs:4183-4184` — `#[path = "zk_ffn_fresh_poc.rs"] pub mod
  fresh_poc;`
* `hashline/src/zk_ffn_fresh_poc.rs:14-15` — `#[path =
  "zk_ffn_fresh_io.rs"] pub mod io;`
* `hashline/src/zk_ffn_fresh_io.rs:165` — `prepare()` calls
  `prepare_layer_zk_v3_inner(w, 32, &parameters(), &NttTables::new(16),
  &cfg, &mut tr, true, true, rng)`.
* `hashline/src/zk_ffn_fresh_poc.rs:104` — `prove()` calls
  `prove_layer_zk_v3_inner(..)`, which at `zk.rs:2284` is exactly
  `prepare_layer_zk_v3_inner(..)?.finish(ntt, tr)`.
* `hashline/src/zk.rs:2337` — `fn prepare_layer_zk_v3_inner(..)` is the
  body that carries the allocations this lane changes:
  `w_data` at `zk.rs:2416`, `a_data` at `zk.rs:2476`.

So the repaired private feed-forward and the legacy `--zk --profile v3`
prover share ONE prover body, and a host fix landed in it serves both. (The
plan's "around zk.rs:925-966" is stale; the current sites are 2416 and
2476.)

### 2026-09-19 — stage 1b, what the port must do differently from AL's

Read before writing anything. Three differences between `layer.rs`'s v3
body and `zk.rs`'s, each of which would have been a byte bug if ported
blind:

1. **The zk buffers are NOT exactly tiled by the fills.** AL's safety
   argument is that `LayoutV3`'s blocks tile `w_len` / `a_len` exactly, so
   every element is written before any is read. In `zk.rs` the buffers are
   LONGER than `LayoutV3`'s: `ZkLayoutV3` (zk.rs:2001-2052) appends, after
   `lay.a_len / a_n` rows, the CFS mask rows, the table rows, the table
   mask rows, the predicate row and (fresh-IO) the endpoint mask rows; and
   under P3 it appends the W mask rows after `lay.w_len / w_n`. Inside that
   tail, two writes are PARTIAL and rely on the surrounding zeros:
   * the table multiplicity rows, written `j in 0..t.size` out of `n`
     columns (`zk.rs:2500`);
   * the predicate slack row, written `i in 0..PRED_BITS` (16) out of `n`
     (`zk.rs:2518`).
   Therefore the port takes a pooled buffer and zeroes exactly the tail
   `[lay.a_len, zl.a_len)` (and `[lay.w_len, w_len_p3)` under P3),
   leaving only the provably tiled prefix unzeroed. That prefix is where
   essentially all the bytes are, so essentially all of AL's win is kept.
2. **`a_data` is MOVED into the commitment** (`pcs::commit_zk_owned`,
   `zk.rs:2537`), and under P3 `w_data` is too (`std::mem::take`,
   `zk.rs:2461`). The public path in `layer.rs` only borrows, so AL could
   give the buffer back at the end of the layer. Here the buffer lives
   inside `pcs::CommittedZk::data` (`zkp-core/src/pcs.rs:555`, a public
   field) until the opening, which happens in `PendingV3::finish`
   (`zk.rs:2306`) — also in `zk.rs`, so the pool return goes there, after
   `pcs::open_zk` and before the commitment is dropped.
3. **`h_data` stays as it is.** `zk.rs:2608` allocates `vec![Fp::ZERO;
   zl.h_len]` and, on the device helper path, leaves most of it zero on
   purpose — `pcs::commit_zk_device` documents that `host_data` "holds the
   host-known rows at their offsets and zeros elsewhere"
   (`hashline/src/pcs.rs:70-73`). Its zeros are load-bearing; pooling it
   would be a byte bug. AL did not touch the corresponding buffer either.
   Recorded, not changed.

Next step: stage 2, the baseline gates on the untouched tree.
