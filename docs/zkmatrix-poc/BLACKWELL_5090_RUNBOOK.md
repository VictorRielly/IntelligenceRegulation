# The RTX 5090 runbook — what must be true before the first number

Status: LIVE, written 2026-09-04 (orchestrator, Claude). Victor has an
RTX 5090 available for these experiments. This page is what has to be
true before it produces a number anyone should believe, what it is
expected to buy, and what it does NOT settle.

Companion to `U_PERF3_SIXTY_TOKENS_PLAN.md` (Track E, the hardware
factor) and `TARGET_CONTRACT.md` (the power bound, §3 below).

---

## 1. What the 5090 is worth here, counted

This workload is bound by memory bandwidth, so that is the number that
matters:

| part | bandwidth | VRAM | vs the measured laptop part |
|---|---:|---:|---:|
| RTX 4070 Laptop (every measurement to date) | 256 GB/s | 8 GB | 1.0x |
| **RTX 5090** | **1792 GB/s** | **32 GB** | **7.0x** |
| H100 PCIe | 2000 GB/s | 80 GB | 7.8x |
| H100 SXM | 3350 GB/s | 80 GB | 13.1x |

So a 5090 is **0.90x an H100 PCIe and 0.53x an H100 SXM** on the
dominant term. Applying that to the plan's 8B cells, with the
**corrected 9.41x statement divisor** (attention 2.87x, ZK P1 **2.78x
as MEASURED ON A GPU by lane AI** — not the 1.047x measured on a CPU —
and the range facts 1.18x):

| 8B prefill, honest statement, one 5090 | today's divisor (9.41x) | with lever L8 landed (4.40x) |
|---|---:|---:|
| by scaled constants [MODEL] | 3.0-14.8 | 6.5-31.6 |
| at the counted spec-sheet floor [COUNTED] | **8.0-22.7** | **17.0-48.6** |

**THE HONEST READ, REVISED 2026-09-04: a 5090 does not reach 60 tok/s,
even with the ZK surcharge recovered.** The same composition on an H100
SXM gives 31.8-90.9 at the floor, which does contain 60. So the two
machines have different jobs, and this is clearer than the first
version of this page suggested:

* **The 5090 is the development and validation machine.** It settles
  the hardware factor, it settles the card-size prediction in §6 on
  day one, and with >= 64 GB of host RAM it brings the 32-layer 8B
  full-model pass home from the Mac. All of that is necessary.
* **The headline claim still wants the H100.** Renting it at the END,
  once the levers have landed and the 5090 has told us where we are,
  remains the plan — and this correction makes that rental more
  clearly necessary rather than less.

## 2. THE AMDAHL WARNING — the board buys ~1.4x, not 7x, today

The measured 8B GPU pass is 95.5 s, of which **56-63 s is HOST work**
(the plane -> Fp conversions and their pageable upload, the encode NTT,
the opening's chunked re-encode, and the Merkle levels + serialization
of a 1.23 GB proof). A 7x faster device speeds only the other 33-40 s:

    device 33-40 s / 7  =  4.7-5.7 s
    host   56-63 s      =  unchanged
    total               =  61-69 s  ->  7.5-8.5 tok/s (from 5.36)

**UPDATED 2026-09-04, lane AJ rung 4 — the warning stands but the item
has a name now.** AJ built and gated all four host items and measured
the 8B pass before and after: **88.90 -> 86.00 s, 1.034x**, proof
byte-identical. The plan's B1 item had conflated the upload (13.05 s,
AJ's, fixed) with the plane -> Fp CONVERSION, which is host work in
`layer.rs` — `prove_layer_v3` building `w_data` and `a_data` element by
element with `Fp::from_i64`, **~29 s of the 8B pass and the single
largest host item in it**. B4 was wrong outright: serialization is
0.03 s and runs outside the prove clock. Pinned staging does not raise
the h2d rate on this box.

AJ's own projection, and it is the sentence that matters for this page:
the parts a faster device shrinks are ~1.0 s of a 2.50 s layer; the
parts it does not touch are the ~1.2 s of `layer.rs` conversion and
folds. **On a device 4x faster the host share becomes ~70% of the
layer. The `layer.rs` item is what decides whether the 5090 buys 1.4x
or 4x.**

So: **do not schedule the headline measurement pass before the
`layer.rs` conversion lands** — the number would be a measurement of
our marshalling code, not of the hardware. The card-size test in §6 is
the exception: it needs no code and should be run on day one.

## 3. Blockers to clear BEFORE the board arrives

The WSL box as it stands today is not Blackwell-ready. Checked
2026-09-04:

| item | today | needed | why |
|---|---|---|---|
| driver | 566.14 | **>= 570** | Blackwell consumer parts are not supported by the 56x branch |
| CUDA toolkit in `/home/victor/cuda-root` | NVRTC **12.1** (`libnvrtc-builtins.so.12.1`) | **>= 12.8** | `sm_120` codegen lands in CUDA 12.8 |
| `cudarc` feature | `cuda-12040` | matched to the installed toolkit | `hashline/Cargo.toml` |
| `arch_str` in `hashline/src/gpu/cuda.rs` | table stops at `(9, 0) => "compute_90"` | add `(12, 0) => "compute_120"` (and `(10, 0) => "compute_100"` for datacenter Blackwell) | the RTX 5090 is compute capability **12.0**; unmatched, it falls through to a generic-PTX compile that JITs but gets no Blackwell codegen |
| host system RAM | 15 GB | **>= 64 GB** | the 8B CPU pass peaks at 14.0 GB and the full-layer statement adds more; this ceiling is the ONLY reason the 32-layer 8B pass has to run on the Mac |

**Do NOT upgrade the toolkit while lanes are running.**
`/home/victor/cuda-root` is shared by every worktree; replacing it under
a live lane breaks its builds and invalidates its in-flight runs.
Schedule the upgrade for a quiet box, and re-run the floors afterwards
(§4) before trusting any number taken on the new toolkit — including on
the old 4070.

The `arch_str` arm is owned by whichever lane owns `gpu/cuda.rs` (lane
AJ in round 14); it must not be edited from the orchestrator's checkout.

## 4. Day-one procedure — byte gates before timings

The discipline that makes this project's numbers mean anything is that
a proof is byte-identical across devices. A new device is exactly when
that gets tested, so:

1. Build both binaries on the new box.
2. Run `scripts/floors_round13_merge.sh <scratch-dir>` — it carries the
   four gates' exact commands, reference sha256 prefixes and byte counts
   for both binaries. **All eight must be byte-identical to the
   references.** A digest that moves on new hardware is a Blackwell
   codegen difference and it is a bug, not a hardware finding; stop and
   report it before taking a single timing.
3. Only then take timings, and only on a quiesced box, p95 over >= 20
   warm runs, labelled `[5090-BOX]` `[QUIET]` `[MEASURED]`.

## 5. The power cap and the contract

`TARGET_CONTRACT.md` §3 sets the seconds-per-proof headline on "one
consumer GPU of **at most 450 W**". The RTX 5090's TDP is **575 W**, so
a stock-clocked result does not satisfy our own contract as written.

The fix is deliberate, not a workaround: **power-limit the card to 450 W
(`nvidia-smi -pl 450`) and record that it was capped.** These parts are
pushed hard at stock and give up relatively little at that cap. Take the
contract number capped; an uncapped number may also be recorded, clearly
labelled, as an out-of-contract data point. The alternative — amending
the contract's power bound — is a Victor ruling and should not be made
silently by whoever happens to run the benchmark.

## 6. What the 5090 settles, and what it does not

**A SECOND, CHEAPER THING IT SETTLES — measured 2026-09-04 (lane AI).**
The 8B ZK pass on the 8 GB laptop part proves **layer 0 in 4.36 s and
layers 1-31 in 8.42 s each**, because under WSL `cuMemAlloc` is served
from HOST memory rather than failing, so the 1,392 MB of zero-check
tables are paged. The pass reported **8,585 MB of VRAM on an 8,188 MB
card** — it is already spilling. A third pool drain written to force
real VRAM killed layer 0 outright, so this is a card-size fact and not
a code fact.

**PREDICTION, NOT MEASURED: a 16 GB+ board gives 32 x 4.36 ~= 140 s
instead of 265 s with NO code change** — a free ~1.9x on the private 8B
pass. The 5090's 32 GB settles this on day one, and it is the single
cheapest result the hardware step can produce. Run the private 8B pass
(`pass 32 512 --zk --seed 1 --profile v3`, `HL_GPU=1`) early and
compare the per-layer times against 4.36 / 8.42 s before anything else.

**Settles:**
- The plan's largest [MODEL] term. Every desktop and H100 column is the
  laptop row divided by a factor nobody has run; this is the first real
  point on that curve.
- Whether the kernel work is aimed correctly — the difference between
  landing at 8 tok/s and 40 tok/s decides what happens next.
- **It brings the 32-layer 8B full-model pass home from the Mac** (Track
  A item A3), given >= 64 GB of host RAM, which is the plan's most
  valuable single measurement.

**Does not settle:**
- The headline claim as ruled names "one H100" (Victor, 2026-09-04). A
  5090 number is not that claim.
- **THE H100 DECISION IS DEFERRED, DELIBERATELY**, until the host wall
  has landed and a real 5090 number exists. At that point the remaining
  gap to 60 tok/s is known: if it is ~1.5x, rent an H100 for a day and
  the claim is done; if it is ~6x, more kernel work comes first. That is
  a far better-informed decision than the one available today, and
  waiting costs nothing.
- A commercial note worth weighing when the time comes: a claim measured
  on a consumer 5090 may be worth MORE than one measured on an H100,
  because it is the machine a customer might actually own. If so, the
  contract's 450 W cap (§5) is the right frame and the H100 rental
  becomes optional rather than necessary.
