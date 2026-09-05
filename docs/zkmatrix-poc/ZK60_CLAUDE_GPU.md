# CL1 — private commitments within a VRAM budget

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
