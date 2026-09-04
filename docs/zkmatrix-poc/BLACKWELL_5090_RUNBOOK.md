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
dominant term. Applying that to the plan's 8B cells, with the 3.55x
statement divisor (attention + ZK P1 + the range facts):

| 8B prefill, honest statement, one 5090 | tok/s |
|---|---:|
| by scaled constants [MODEL] | **8-39** |
| at the counted spec-sheet floor [COUNTED] | **21-60** |

**60 tok/s sits exactly at the top edge of the floor band.** It is
reachable on a 5090 only if the kernels land essentially at the
spec-sheet floor; an H100 SXM carries ~1.9x more headroom (40-113 at
the floor). Treat the 5090 as sufficient to do all the work and
marginal for the headline claim — see §6.

## 2. THE AMDAHL WARNING — the board buys ~1.4x, not 7x, today

The measured 8B GPU pass is 95.5 s, of which **56-63 s is HOST work**
(the plane -> Fp conversions and their pageable upload, the encode NTT,
the opening's chunked re-encode, and the Merkle levels + serialization
of a 1.23 GB proof). A 7x faster device speeds only the other 33-40 s:

    device 33-40 s / 7  =  4.7-5.7 s
    host   56-63 s      =  unchanged
    total               =  61-69 s  ->  7.5-8.5 tok/s (from 5.36)

**So the host wall (lane AJ, round 14) must land BEFORE the board is
worth its bandwidth.** On a 5090 the unfixed host share would be ~90%
of the wall. Do not schedule the headline measurement pass before AJ
closes; the number would be a measurement of our marshalling code, not
of the hardware.

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
