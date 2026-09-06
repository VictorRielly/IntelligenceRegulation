# CL1 — private commitments within a VRAM budget

> **REVIEWERS — READ THE TIP, NOT `15eeda6`.** `ZK60_EXECUTION.md` pins this
> delivery at `15eeda6`, which was the tip when that note was written. **Rung 5
> landed afterwards (`1ab8dcc`) and CORRECTS rung 1's memory bound**: the
> resident peak is **13,491 MiB**, not the 12,142 MiB rung 1 first stated,
> because `drop` on a pooled buffer is a pool return and not a device free.
> Round 1's M1 had it right. A review pinned at `15eeda6` will read the wrong
> number, and it is wrong in the direction that would authorise a run it
> should refuse.


Lane: `zk60-cl1`, worktree `/home/victor/wt-zk60-cl1`, branched at `87c5338`.
Task: `ZK60_EXECUTION.md` §CL1.
OWNS: `hashline/src/gpu/`, `hashline/src/pcs.rs`, this file, new
`hashline/tests/zk60_gpu_commit.rs`.
READ-ONLY: `zk.rs` and `src/bin/hashline.rs` (C0 changed them) — any caller
change is PROPOSED here for Codex to integrate, not made.

**Rebased on the actual tree, as the brief requires.** AL's host allocation
fix and AO's L9 output pruning have both landed and are assumed present.

---

## Rung 1 — the allocation-lifetime table, and the bound derived BEFORE running it

### The subject

`gpu::cuda::dev_commit_zk_from` (`cuda.rs:2410`), the hiding commitment. Its
non-hiding twin is `dev_commit_from` (`cuda.rs:1664`). Everything below is
one commitment of ONE real-width W at Mistral shape, the shape that actually
failed on 2026-09-04.

Shape, taken from lane AM's own rung-3 mask-site dump (so this is the real
commitment, not a model): **`rows = 10,774`** (10,752 data + 21 block masks +
1 proximity row), **`n = 2^14 = 16,384`**, **`inv_rate = 4` so
`nn = 65,536`** (the log's "65536 Merkle leaves" confirms it), **`q = 256`**
pad symbols per row (the log's "256 pad symbols per row on the coset").
`Fp` is 8 bytes.

### Allocation lifetime

| # | buffer | size | born | dies | live through |
|---|---|---|---|---|---|
| 1 | `d_data` | `rows·n` = **1,346.8 MiB** | caller | returned in `DevCommit` | ALL |
| 2 | `d_coef` | `rows·n` = **1,346.8 MiB** | before fwd NTT | `drop` after `k_zk_pad_scale` | A, B |
| 3 | `d_pads` | `rows·q` = **21.0 MiB** | before pad/scale | end | B, C, D |
| 4 | `d_pows` | `nn` = **0.5 MiB** | before pad/scale | end | B, C, D |
| 5 | `d_coef2` | `rows·nn` = **5,387.0 MiB** | before pad/scale | `drop` after expand NTT | B, C |
| 6 | `d_enc` | `rows·nn` = **5,387.0 MiB** | before expand NTT | returned in `DevCommit` | C, D |

Phases: **A** forward NTT · **B** `k_zk_pad_scale` · **C** expand NTT ·
**D** `hash_cols`.

### Simultaneously live vs cumulative

**Simultaneously live** — this is the number that decides whether it runs:

| phase | live | bytes |
|---|---|---:|
| A | 1+2 | 2,693.5 MiB |
| B | 1+2+3+4+5 | 8,102.0 MiB |
| **C** | **1+3+4+5+6** | **12,142.3 MiB ← PEAK** |
| D | 1+3+4+6 | 6,755.3 MiB |

**Cumulative device traffic** is a different and much less interesting
number: **12,120.8 MiB** written across the three NTT/scale outputs, plus
1,368 MiB h2d (data + pads + pows) and 2 MiB d2h (leaves). Chunking does
**not** reduce traffic — it reduces only the peak. Any claim that chunking
"moves less data" would be false and is not made here.

### THE BOUND, AND IT MATCHES THE OBSERVED FAILURE EXACTLY

```
peak = [ rows·(n + q + 2·nn) + nn ] · 8 bytes
     = 12,142.3 MiB   on an 8,188 MiB card
```

And the largest SINGLE allocation is

```
rows · nn · 8 = 10,774 · 65,536 · 8 = 5,649,362,944 B = 5,387.0 MiB
```

**5,387.0 MiB is exactly the number in the 2026-09-04 failure** —
`cuMemAlloc(5387 MB): CUDA_ERROR_OUT_OF_MEMORY` — which identifies the
failing allocation as `d_coef2` (the first of the two `rows·nn` buffers to
be taken) and confirms this table against a real run rather than a model.

Note the second row of the story, which the failure message hides: even if
that allocation had succeeded, **phase C needs 12,142 MiB and the card has
8,188.** P3 at this width was never one allocation away from working. Note
also that **phase B at 8,102 MiB fits under 8,188 by 86 MiB** — which is
why the failure lands where it does and not earlier.

### CORRECTION to the bound above — it was LOW by 1,349 MiB, in the unsafe direction

**`drop(d_coef)` is NOT a device free.** `Pooled::drop` calls `pool_put`,
which retains the buffer (up to 64 buffers, with NO byte cap), and
`pool_take` only reuses a buffer on an **exact** length match
(`b.len() == len`). `d_coef` is `rows·n` and `d_enc` is `rows·nn`, so
`d_coef` can never be reused for `d_enc`: its memory is still resident when
`d_enc` is allocated. The phase table above treated the `drop` as a free and
so understated the peak.

```
corrected peak = [ rows·(2n + q + 2·nn) + nn ]·8 + leaves + twiddles
               = 13,491 MiB  (+ ~1 MiB twiddles)
```

**This reconciles with round 1's M1 count of 13,492 MiB** — derived
independently, by a different worker, from a pure planner
(`scripts/hashline_memory_plan.py`), and agreeing to within 1 MiB. M1 was
right and this document's first figure was wrong. It matters because a
memory bound that is 1.3 GB LOW is wrong in the direction that authorises a
run it should have refused.

The conclusion is unchanged and slightly strengthened: the resident hiding
commitment never fitted an 8,188 MiB card, and by a wider margin than rung 1
claimed.

### What chunking buys [DERIVED, not yet measured]

Row-chunked at the existing default `HL_GPU_CHUNK_ROWS=128`:

| buffer | resident | chunked |
|---|---:|---:|
| `d_data` (returned) | 1,346.8 | 1,346.8 |
| `d_coef` | 1,346.8 | 16.0 |
| `d_coef2` | 5,387.0 | 64.0 |
| `d_enc` | 5,387.0 | 64.0 |
| `d_pads` | 21.0 | 21.0 |
| `d_pows` | 0.5 | 0.5 |
| blake3 column state | — | 48.2 |
| leaves | — | 2.0 |
| **peak** | **12,142.3** | **1,562.5 MiB** |

**7.8x less peak VRAM, and it fits the 8 GB card with room to spare.**
`d_data` then dominates at 86% of the chunked peak, which is the next thing
to attack if it is ever needed (it need not be: 1,562 MiB is comfortable).

---

## The one thing the ZK path CANNOT borrow from the non-ZK path

The non-ZK `dev_commit_from` already does all of this. It computes
`chunked_now = rows·nn·8 > chunk_bytes()`, and — importantly — it ALSO falls
back to chunked when `Pooled::take` fails ("resident alloc failed"). It then
calls `commit_chunked`, which walks `chunk_plan`, encodes each row chunk
through `encode_rows_view`, and folds each chunk into a per-column blake3
state with `k_hash_cols_stream`, emitting leaves on the last chunk. That
streaming column hash is already byte-gated — lane AO's four chunked-forced
gates exercise exactly it.

**`dev_commit_zk_from` has none of that. It takes both `rows·nn` buffers
unconditionally and dies.** That asymmetry is the whole defect, and the
encode itself chunks cleanly: the forward NTT, `k_zk_pad_scale` and the
expand NTT are all ROW-LOCAL. Pads are per row (`pads[r0·q .. (r0+rc)·q]`);
`pows` is per column and shared. Nothing couples rows except the column
hash, and the column hash already streams.

**But the OPENING does not chunk, and this is the real design constraint.**
`dev_columns` (`cuda.rs:1774`) falls back to `columns_chunked` when
`DevCommit.enc` is `None` — and `columns_chunked` **re-encodes from
`dc.data` with the plain encode, no pads and no coset scaling.** For a
hiding commitment the encoded matrix is
`expand(pad_scale(ntt(data), pads, pows))`, so a plain re-encode returns the
WRONG columns. Today this is invisible because the ZK path always keeps
`enc: Some(..)`, so the fallback is never reached from a hiding commitment.

Therefore chunking the hiding commitment requires a **pad/coset-aware column
re-encode** as well. It is not optional and it is not a nicety: dropping
`enc` without it would silently produce wrong openings. The inputs all
survive — `CommittedZk` retains `pads`, and `pows` is recomputable from
`zk.coset` and `nn` — so this is tractable, but it is the one place where
CL1 is genuinely more than "mirror the non-ZK code".

---

## Rung 2 — THE PLAN, recorded before implementing (kept so the design can be judged against what shipped)

Smallest change consistent with the existing design:

1. `commit_zk_chunked` in `cuda.rs`, mirroring `commit_chunked`: per-chunk
   forward NTT → `k_zk_pad_scale` with the chunk's pad offset → expand NTT →
   `k_hash_cols_stream`. Same kernels, same pads, same coset powers, same
   order, so the leaves are bit-for-bit the resident path's.
2. `columns_chunked_zk`, the pad/coset-aware re-encode, so an `enc: None`
   hiding commitment opens correctly.
3. Route in `dev_commit_zk_from` exactly as the non-ZK twin routes: by size
   AND on allocation failure — **no silent CPU fallback**, and a diagnostic
   naming the budget and the shape when it chunks.
4. A `HL_ZK_CHUNK` style switch retaining the reference (resident) path
   until the gates pass, per the acceptance criteria.

Acceptance for rung 3 is CPU/GPU equality of **both** commitments and opened
columns on small shapes with forced chunking, varied rows, varied `q`, every
supported rate, plus the four frozen fixtures on both binaries.

---

## Rung 2 — implemented (commit `da845fa`)

`gpu/cuda.rs` gains `ntt_rows_view` (the NTT over a row-chunk view, same
kernels/launches/twiddles/scale), `encode_rows_view_zk` (one chunk of the
hiding encode: forward NTT → `k_zk_pad_scale` with the chunk's pad slice →
expand NTT), `commit_zk_chunked` (mirrors `commit_chunked`, folding each
chunk into the per-column blake3 state via `k_hash_cols_stream`), and
`columns_chunked_zk` (the pad/coset-aware opening that rung 1 showed was
mandatory). `DevCommit` carries a `ZkReenc { pads, pows, q }` so `dev_columns`
stays the single opening entry point.

`HL_ZK_CHUNK` — unset/`auto`: chunk by size AND on allocation failure, the
non-ZK path's own rule; `0`/`off`: the pre-CL1 resident path retained
byte-for-byte (the reference switch the acceptance criteria require);
`1`/`force`: always chunk, so small shapes exercise it in the gates.

**No silent CPU fallback and no privacy downgrade.** Chunking is a memory
decision *inside* the device path; the mode is announced under
`HL_GPU_VERBOSE`; the CPU body is still reached only on a real `Err`.

## Rung 3 — validation

**The oracle.** `dev_commit_zk_check_chunked` compares the chunked leaves AND
the chunked opening columns against the CPU's own `encode_row_zk` — not
against the device's resident path, so a bug shared by both device paths
could not hide. `hashline/tests/zk60_gpu_commit.rs` runs it over every
supported rate (`inv_rate` 2/4/8), ragged row counts that leave a short final
chunk (129/255/256/257/384/400), the degenerate single-chunk plan, varied pad
counts (`q_pad` 1/16/64/256) and wider shapes (`log_cols` 12 and 14).
**6/6 pass.**

**The negative control, which is what makes the other five mean anything.**
The same hiding commitment opened with the non-ZK `columns_chunked` must
DISAGREE with the CPU. It does, and the failure has exactly the predicted
shape: `bad_leaves = 0` (the commitment is still the correct chunked hiding
one) with `bad_cols` far above `rows` (only the opening is wrong). If that
test ever reports 0 bad columns, the positive tests prove nothing.

**The frozen fixtures, with chunking FORCED** — `HL_ZK_CHUNK=1`, `gpu: ON`
confirmed in every run:

| gate | digest | bytes | result |
|---|---|---:|---|
| `zk` | `021485e4f80ec695` | 87,228,528 | **unmoved** |
| `zkv3` | `40eb54795e023c77` | 87,697,008 | **unmoved** |

and the 12x512 `zk` gate really chunks — **4 and 5 chunks of ≤128 rows**
across its commitments — so the streaming column hash, the per-chunk pad
slicing and the chunked ZK opening are all exercised rather than degenerate.
The proof carries the opened columns, so a wrong `columns_chunked_zk` would
have moved the digest.

## Rung 4 — measurement: P3 IS ON THE DEVICE AT MISTRAL WIDTH

The shape that failed on 2026-09-04. One Mistral layer, `d 4096 / f 14336`,
T=512, same binary and seed, **one session, both arms on the GPU**, so mode
is the only variable [MEASURED, WSL-BOX, RTX 4070 8 GB, single run]:

| | P1 (public W) | P3 (private W) | cost of hiding |
|---|---:|---:|---:|
| PROVE | 3.453 s | **4.142 s** | **+20.0%** |
| proof | 40,186,228 B | 40,251,860 B | **+0.163%** |
| sha256 | `b5da6c38c77cf702` | `190e85a1d3bebdc3` | — |
| VRAM peak | 5,282 MB | **5,182 MB** | −100 MB |
| device commit | taken | **taken** (was DECLINED) | — |

**Both digests reproduce lane AM's rung-2 values exactly** (`b5da6c38..` /
40,186,228 B and `190e85a1..` / 40,251,860 B), and AM's P3 arm produced that
digest on the CPU fallback — so this is also a **CPU/GPU byte-identity gate
for the hiding commitment at real width**.

**What this retires.** Lane AM's rung 2 recorded "P3's structural cost at
Mistral width REMAINS UNMEASURED" and warned "DO NOT QUOTE 4.26 → 15.82 s AS
P3's SURCHARGE" because its P3 arm had fallen back to the CPU. **It is
measured now: +20.0% on prove, one axis, both arms on the device.** The old
3.71x was an artefact of the device decline, exactly as rung 2 suspected. The
same layer goes **15.82 s → 4.142 s = 3.82x** purely by getting onto the
device it could not previously fit on.

**Four layers, to check the peak does not accumulate**: 4.159 / 3.834 / 3.849
/ 3.977 s, and **VRAM peak is FLAT at 5,182 MB** across all four — the
per-layer drain holds, so the peak is a per-layer property, not a pass-length
one.

**NOT ESTABLISHED, and deliberately not run.** The 32-layer 8B P3 pass. The
brief says to stay at safe small shapes while the 5090 is unavailable, and
this box froze three times on 2026-09-04. The flat 4-layer peak makes it a
reasonable **[PREDICTION]** that an 8B P3 pass would now fit this 8 GB card
at ~5.2 GB — but that is a prediction, no 8B number is claimed here, and no
speedup is attributed to any part of the pass this lane did not change.

**One honest limit on the timings above**: single runs, not p95 over ≥20 on a
quiesced box, and this box is not quiesced-certified. The BYTE results are
exact and carry no such caveat; the seconds are indicative and are not a
headline. An ABBA repeat is the next thing to do.

**A consequence for the hardware plan.** Earlier today's board entry said the
16 GB+ board is what puts the full tier on the device. That is now too strong
*at Mistral width*: chunking puts it there on 8 GB. The bigger card is still
what the 8B pass and the fast tier's spill want; the full tier's commitment
is no longer the reason.

---

## CL1 status: rungs 1-4 delivered. Acceptance, checked against the brief

| criterion | evidence |
|---|---|
| documented peak bound | rung 1: `[rows·(n+q+2·nn)+nn]·8` = 12,142.3 MiB, derived before running, and its 5,387.0 MiB single allocation matches the observed `cuMemAlloc` failure exactly |
| unchanged deterministic artifacts | **12 byte gates green** (4 fixtures x CPU / GPU / GPU-with-chunking-forced), `results/cl1_floors.log` exit 0; plus both Mistral-width digests reproducing lane AM's rung-2 values |
| meaningful negative tests | the negative control: opening a hiding commitment with the non-ZK `columns_chunked` must and does disagree, with leaves right and columns wrong |
| forced-chunk CPU/GPU comparisons | `dev_commit_zk_check_chunked` over rates 2/4/8, ragged rows, one-chunk, `q_pad` 1-256, wider shapes — 6/6, against the CPU's `encode_row_zk` |
| honest before/after on named hardware | rung 4, RTX 4070 Laptop 8 GB, with the single-run caveat stated |
| gains attributed to the portion changed | the COMMITMENT, at one Mistral layer. No 8B number, no pass-level speedup claimed |
| reference switch retained | `HL_ZK_CHUNK=0` keeps the pre-CL1 resident path byte-for-byte |

**Files touched — all inside the lane's ownership**: `gpu/cuda.rs`,
`gpu/mod.rs` (one re-export), `tests/zk60_gpu_commit.rs`, this document,
`results/cl1_*`. **`zk.rs` and `src/bin/hashline.rs` were NOT touched**, as
the brief requires. `pcs.rs` is in the lane's ownership but needed no change
either: carrying the pads in `DevCommit` kept `dev_columns` the single
opening entry point, so the pcs-level opening code is untouched.

**Nothing is proposed for Codex to integrate** — there are no caller changes.
The one optional extra, if it is ever wanted: `dev_commit_zk_check_chunked`
could be surfaced as a `gpu-probe` subcommand the way
`dev_commit_check_chunked` is, but the test file already covers it and that
would require editing the CLI, which is read-only to this lane.

### What is now newly possible, and is a decision rather than a task

The 32-layer 8B P3 pass on the device. It was impossible before this lane
(the commitment could not be allocated); the 4-layer run shows the peak flat
at 5,182 MB, so it should now fit this 8 GB card. It is NOT run here because
the brief says to stay at safe small shapes while the 5090 is unavailable,
and this box froze three times on 2026-09-04. Whoever picks it up should
launch it detached under `flock /tmp/zk-heavy.lock` with a `.done` marker,
check `nvidia-smi` reads near 0 first, and grep the run header for `gpu: ON`
before believing any number in it.

### Two limits worth stating plainly

1. **The seconds are single runs on a box that is not quiesced-certified.**
   The byte results are exact; the timings are indicative. An ABBA repeat
   would firm up the +20.0%.
2. **`d_data` is now 86% of the chunked peak** (1,346.8 of 1,562.5 MiB). If a
   future shape needs more headroom, that buffer — not the encode scratch —
   is where it is.

---

## Rung 5 — the WHOLE-LAYER memory account, as `ZK60_STATUS.md` requires before scaling

`ZK60_STATUS.md`: *"M1's 13,492 MiB count is a single cold-pool P3
W-commitment component ... Pending attention/FFN states add overlapping
lifetime costs. Claude must account for those before scaling; nominal card
capacity does not authorize a large run."* This rung is that accounting.

### First: M1 was right and rung 1 was wrong

See the correction above. `drop` is a pool return, not a free; the resident
W commitment peaks at **13,491 MiB**, reconciling with M1's 13,492 to within
1 MiB by an independent route. Rung 1's 12,142 was low by 1,349 MiB.

### The overlap was the real killer, worse than any single allocation

There are **three** hiding commitments per layer, and the pool drain is
**after H**, not after each. Measured shapes at Mistral width (d 4096 /
f 14336, T=512), with each component's resident cost from M1's planner:

| commitment | rows | component peak (resident) | live + pool retained after it returns |
|---|---:|---:|---:|
| W | 10,774 | **13,492.0 MiB** | 6,733.8 live + 6,733.8 pool = **13,467.5** |
| A | 3,601 | 4,511.8 MiB | 2,250.6 + 2,250.6 = 4,501.2 |
| H | 3,033 | 3,800.7 MiB | 1,895.6 + 1,895.6 = 3,791.2 |

Because nothing is released until after H, **A commits on top of W's
retained 13,467 MiB**: ≈ **17,979 MiB before H or the zero-checks are even
reached**, on an 8,188 MiB card. So P3 at real width was never "one 5,387 MiB
allocation short". It was over budget by more than 2x, and the single failing
`cuMemAlloc` was just the first place that became visible.

### What the chunked path actually does — MEASURED, whole layer

All three hiding commitments now chunk (`HL_GPU_VERBOSE=1`, one Mistral
layer, P3, `gpu: ON`):

```
drain layer top: freed 0 pooled buffers
zk commit rows 10774 (5649 MB resident): CHUNKED (by size), 85 chunks
vram after commit W:    free 5486 / 8187 MiB   (used ~2701)   pool 4
zk commit rows  3601 (1888 MB resident): CHUNKED (by size), 29 chunks
vram after commit A:    free 5006 / 8187 MiB   (used ~3181)   pool 4
vram after dev_helpers: free 3246 / 8187 MiB   (used ~4941)   pool 6   <- max
zk commit rows  3033 (1590 MB resident): CHUNKED (by size), 24 chunks
drain after H: freed 6 pooled buffers
vram after helpers+H:   free 4750 / 8187 MiB   (used ~3437)   pool 0
vram after zcF:         free 3598 / 8187 MiB   (used ~4589)   pool 1
reported vram peak: 5182 MB
```

Three things worth naming:

1. **No `rows·nn` buffer is ever allocated any more**, so the pool cannot
   accumulate the 6.7 GB / 2.25 GB / 1.9 GB retentions that made the overlap
   fatal. The pool holds 4-6 small chunk buffers and drains to **0** after H.
2. **The peak is no longer the commitments.** The maximum observed in-flight
   usage is **~4,941 MiB after `dev_helpers`** — the helper/zero-check phase,
   not any commit. Whoever attacks memory next should start there, not here.
3. **Headroom on this card: 8,187 − 5,182 = 3,005 MiB, i.e. 37%.**

### Does this authorise a large run? Partly — and the honest answer is split

**For the FFN-only coverage that exists today: yes, and it is accounted.**
The per-layer peak is flat at 5,182 MB across a 4-layer run (4.159/3.834/
3.849/3.977 s, peak identical), the drain returns the pool to 0 each layer,
and 37% headroom remains. A 32-layer 8B P3 FFN pass is therefore a
**bounded, per-layer-constant** run at ~5.2 GB, not a gamble on nominal
capacity.

**For the pending attention/FFN states: NO, and it cannot be.** Those
relations are not written yet (the current pass reports
`"coverage":"ffn-only"`). I cannot account for the lifetime of state that
does not exist, and 37% headroom today is not a budget for it — the moment
attention state joins the same layer, this account is void and must be
redone. Nominal capacity does not authorise that run, exactly as
`ZK60_STATUS.md` says.

**So the run I flagged as "newly possible" is authorised only in its
FFN-only form**, still under the detached/`flock`/`.done`/`nvidia-smi`/
`gpu: ON` protocol, and it remains Victor's or Codex's call rather than
something this lane should do unasked while the 5090 is unavailable.

### One correction owed to the planner

`scripts/hashline_memory_plan.py` lists under `unaccounted`: *"Future
chunked hiding commitment: the current implementation still allocates both
full expanded buffers."* That is **no longer true** as of `da845fa` — with
`HL_ZK_CHUNK` unset the hiding commitment chunks by size and on allocation
failure, and allocates neither full `rows·nn` buffer. The planner still
correctly describes the RESIDENT path, which `HL_ZK_CHUNK=0` retains, so its
numbers stay valid for that mode and for the historical record. It is
Codex's file; this is a note, not an edit.

---

## CL4 correction to this document's own measurements — scope, stated precisely

CL4 found that `commit_zk_chunked` charged its own encode+hash wall to
`secs_ntt` while `dev_commit_zk_from` ALSO charged `t1.elapsed()`, which spans
that call. Every chunked commitment was counted twice in the device-side NTT
column. Fixed in `309d3f9`; at Mistral width the reported device-side ntt goes
**1.262 → 0.603 s**.

**What this does and does not invalidate, exactly:**

- **Rung 4's table is UNAFFECTED.** It quotes prove, verify, proof bytes, VRAM
  peak and whether the device commit was taken — none of which come from
  `secs_ntt`. The +20.0% surcharge, the byte-identical digests and the 5,182 MB
  peak all stand.
- **The `gpu device-side (summed)` lines quoted in rung 5's verbose trace and
  in any log written before `309d3f9` overstate `ntt`.** Read those as
  inflated; re-run for a corrected figure.
- **No timing improved.** Prove is 3.996 s against 4.142 s before, i.e.
  unchanged within this box's noise, and the proof is still 40,251,860 B. This
  is a measurement correction, and calling it anything else would be the exact
  error CL4's limits warn about.

I recorded in `309d3f9`'s message that the inflated figure appeared "including
ones in my own CL1 rung-4 write-up". That was itself slightly wrong — rung 4's
table never quoted a device-side NTT number. The correction's true scope is the
verbose traces, as above.

---

## Lane status, 2026-09-06 (round 7) — the queue is worked through; integration is Codex's call

Base: the lane merged the perf tip `9cf1372` as `25f8b6d` (Codex's verifier
hardening, public chain receipts, fixture repair; no lane-owned file
changed). Every commit below is pushed on `zk60-cl1`. Codex reviewed the
first two live (`c346236`, `9b24975`) and re-issued findings, which are
answered in place; the reviews are `ZK60_CL1_INTEGRATION_REVIEW.md`,
`ZK60_CL5_CL9_REVIEW.md`, `ZK60_CL8_CL10_REVIEW.md`.

| commit | task | what it settles | evidence |
|---|---|---|---|
| `c346236` | CL3/CL4 round-7 | raw allocations counted one by one (5 events / 240,704 B at the probe shape); pool reuse asserted in BYTES with a reuse-disabled negative control (ON fresh 3,162,112 B vs OFF 24,494,080 B, the identity exact); the oracle file fails closed WITHOUT the feature | 17 tests / 27 device cases; CPU target: `HL_GPU_REQUIRED=1` -> exit 101 with the reason, unset -> 0 cases |
| `9b24975` | CL3 planner | chunked/fallback are a pool SIMULATION (exact `take`, smallest-fitting `take_min`, `put`), each buffer once by capacity, `no_reuse_bound_bytes` beside it, return lifetimes from the source, warm pools as inventories | 25 tests; reconciles with the device counters to the byte |
| `1250115` | CL6 | chunk rows are a MEMORY knob: 128/256/512 prove 4.0-4.2 s with commits 0.62 s and re-encodes 0.57 s at every choice; VRAM 5,182 / 5,349 / 5,651 MB as the planner predicts; frozen fixture byte-identical at 128-1024; no selector promoted | `cl6_chunk_sweep.log`, 24 tool tests, 13 oracle cases |
| `3d5c90a` | CL7 | the hiding opening gets the fused, output-pruned last stage group: 0.575 -> 0.470 s on the three re-encodes (1.22x), 2.6% of the prove, byte-identical, VRAM unchanged; the next lever named, not taken | `cl7_reenc_ab.log`, 19 tests / 49 device cases |
| `64f3e54` | CL5 round-7 | rows gated before ranking; negative-Amdahl refused; cache state from the log; the matrix runner fail-closed (not re-executed) | 34 tests |
| `de911a0` | CL4 | the floors script's embedded parser could not run on Python 3.10 (Codex reproduced it); self-tested now; dirty-delta content hash in the identity block | `bash -n`, parser self-test |
| `4cda3da` | CL3 planner | an unreachable warm-pool fallback completes resident instead of inventing a refusal; the 64-buffer pool cap frees; oversize inventories refused | 27 tests |
| `15ddb8b` | CL11 | fourteen-check fail-closed 5090 preflight, the ladder, the three clocks; dry run on the laptop refuses for the right reasons and reproduces the 5,182 MB peak in `planner_margin` | 61 tests |
| `ded8dc4` | CL10 round-7 | separate P1/P3 opening layouts from the layout mirror; the whole 65,632 B delta derived (45,056 + 8,192 + 12,288 + 96); the identity cross-check replaced | 27 tests |
| `81abdda` | CL8 round-7 | the pending-memory tool imports the shared planner instead of copying its rules: chunk rounding mirrored (1,048,576 B not 8,192 at the review's case), invalid dimensions refused, raw buffers freed vs pooled scratch, bare row counts refused for explicit layouts, oversize reuse counted once; every builder reconciles with the planner at six shapes | 42 tests |
| `09742d8` | CL5 evidence | the hardened matrix runner re-executed: 15/15 exit 0, `gpu: ON`, ACCEPT, per-run digests; P1 cold == warm == nocache == the frozen `zkv3` digest, P0 == the frozen `v3` digest, P3 `be8d13cc..` — the same digest CL9's CPU process produced (a P3 CPU/GPU identity at 12x512); seconds inflated by an overlapping agent and not promoted | `cl5_matrix_r7.log`, `cl5_r7/` |
| `a1aa2b7` | CL9 round-7 | the order-dependent test primes its own namespace; separate-process cold/warm proof comparison (byte-identical, the frozen digest); the caller's real packing tied to the key; the ACTUAL `--p3 --wcache` refusal (exit 2, before any work) and a fresh uncached P3 ACCEPT; remaining key fields; 8 same-key writers x 12 keys — one verifying entry each, but 15 of 96 saves LOST to the shared `.wc.tmp` name (a `wcache.rs` defect, proposed fix: per-writer temp names) | 12 tests: full file, each alone, 8 threads, 1 thread |
| `82314a1` | CL4 | the floors gate's own `${SUMMARY:-{}}` appended a literal `}` and turned a green oracle run RED; quoted; three false-start logs archived (a self-deadlock on the build lock twice, then this) | `bash -n`, self-test through the same expansion |

**Final floors on the tip — `results/cl_round7_floors.log`, marker 0, HEAD
`82314a1`, dirty delta under `hashline/` empty (`e3b0c442..`), CPU binary
`93055aa6..` / 4,629,656 B, GPU binary `e7e1535b..` / 5,326,472 B:**
**ALL CL1 FLOORS GREEN** — 12/12 byte gates at full SHA-256 (four fixtures
x CPU / GPU / GPU with chunking forced, every GPU gate `gpu: ON`, every
proof ACCEPT), the crate suites at `--test-threads=2` (twenty `test result:
ok` lines, the 12 cache tests included), the oracle suite uncaptured on one
thread with **49 executed device cases** (floor 20), the missing-feature
refusal (CPU target under `HL_GPU_REQUIRED=1`: exit 101 with the reason) and
the zero-case status without it (exit 0). Codex's `3ff8d5f` (the FFN
disclosure diagnostic and the H1 fixture isolation) was merged AFTER this
run; it touches no lane-owned file and was validated by Codex's own 147-test
run on the perf branch.

### Suggestions brought to the table (for Codex / the integrator)

1. **The CPU/GPU byte gates and the oracle suite are green on the merged
   tree; integration of `zk60-cl1` is a review decision, not a build one.**
   Every lane-owned change is behind a retained reference switch
   (`HL_ZK_CHUNK=0`, `HL_ZK_FUSE_GATHER=0`, `HL_GPU_PRUNE_P2=0`).
2. **`pcs_compact` lib tests mutate a process-global configuration**;
   Codex's process isolation of the three H1 fixtures fixes the symptom.
   The cleaner fix is a `#[serial]`-style lock shared by every lib test that
   calls `pcs_compact::configure`, or a scoped-configure guard that restores
   the default on drop.
3. **A `LayerProofZk::size_breakdown()`** printed with the mask-site dump
   would turn CL10's derived bytes into printed ones (proposal in
   `ZK60_CLAUDE_ARTIFACTS.md` §7.5).
4. **`pass_zk` should print `wcache::report()`** like `pass_v3` does, so a ZK
   log carries its cache hits/misses without `HL_WCACHE_VERBOSE`.
5. **The next byte-preserving device lever** is the zero tail of the
   pad/scale output: `k_ntt_p1` with `n_src = n + q` over a `rmax x (n + q)`
   buffer drops ~30% of the hiding re-encode's AND the commit's remaining
   traffic (`ZK60_CLAUDE_RESIDENCY.md` §5). One measured bottleneck per
   commit, so it waits for its own task.
6. **The 32-layer 8B P3 pass on the device remains newly possible and
   deliberately not run** (rung 5): the CL6 sweep's flat 5,182 MB per-layer
   peak at chunk 128 is a fourth confirmation of the bound; the launch is
   still a safety decision above this lane.
