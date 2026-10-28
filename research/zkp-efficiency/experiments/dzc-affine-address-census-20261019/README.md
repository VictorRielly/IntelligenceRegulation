# D address translation census: a rejected shortcut and a small remaining option

Cycle 0083 — `20261019T151854Z-4f2eec2a`, 2026-10-19 UTC.

**No speed improvement found.** Replacing each repeated helper's raw-input
map with one translated pointer is incorrect in all nine non-reference
instances. The two families need at least two and three independently shifted
raw pointers respectively. This rejects single translations, not general
affine maps. We stopped before implementing that invalid lowering.

Example: template 3's reference raw slots are `[18,19,20,21,88,89]`; the next
instance reads `[22,23,24,25,90,91]`. The required shifts are
`[4,4,4,4,2,2]`. Using +4 throughout reads helper endpoints 92/93 instead of
90/91. Template 6 has an additional exceptional pair in group 14, so a
two-pointer shortcut also fails there. The full naive translation eventually
requests slot 124 from an array of 118 endpoints; no invalid native pointer
was executed.

The narrower parameter/base option is exact in this census: seven Fp2
parameters and two canonical base scalars per repeated call use uniform typed
offsets. Keeping raw and scratch maps could remove 99 u16 index requests
(198 bytes) from 634, leaving 436 bytes. It adds 18 nonzero pointer shifts
across the nine non-reference calls. The existing helper argument count
can stay unchanged by adjusting the parameter/base pointers at each call.
This is an interpreted address plan and cost proposal; no new Rust/CUDA
kernel or measured traffic/runtime result exists.

| Logical row accounting | Bytes |
|---|---:|
| Original scalar-call graph | 4,320 |
| Previous unique groups | 8,528 |
| Previous shared templates | 9,162 |
| Proposed partial parameter/base translation | 8,964 |

The 198-byte difference is 2.16% of the shared arm's logical requested
bytes, not a speed prediction or a DRAM measurement. Scratch stays 208 bytes.
The same 1,167-node graph executes 884 field primitives: 272 add, 209 sub,
331 mul, 72 base. All 59 tables, folds and finals remain; original folds add
118 Fp2 reads, 59 writes and 59 each add/sub/mul outside these row totals.
No field work is eliminated. Code size, stack, compiler specialization,
register allocation, pointer arithmetic and physical cache/DRAM costs remain
unknown for the partial option. The previous shared-template timing loss
remains valid evidence against promoting grouped execution.

`run.py` uses only copied public DAG/maps and Python's standard library.
The reference evaluates the original SSA DAG directly. A separately driven
candidate interprets shared topology, scratch and translated source addresses.
Exact lineage and initialization checks pass 2,888 assertions across the
original and partial plans. Thirty-three arbitrary synthetic fixtures
(24 random, eight boundary, one zero), seed 2026101983, agree on 165
coefficients per candidate arm. The incorrect but in-bounds group-4 raw
translation changes all 24 random and seven of eight boundary fixtures;
all-zero values fail to expose it. Eight control categories pass, including
typed-byte confusion, stale instance, raw bounds and scratch aliases.

Independent `audit.py` derives address matrices directly from captured maps,
checks the minimum translation groups and derives byte accounting from the
graph/cuts. Its 187 checks and three controls pass. It also compares 36 new
synthetic fixtures / 180 coefficients against the prior compiled scalar
kernel using unchanged native Goldilocks Fp2 source. This oracle and its
source are copied under `oracle/`, checked against the previous artifact
manifest. A wrong extension polynomial changes 35/36 fixtures. This does not
repeat the previous whole-D/catalog/fold/final/proof tests.

Run serially from the research directory:

```bash
python3 experiments/dzc-affine-address-census-20261019/run.py
python3 experiments/dzc-affine-address-census-20261019/audit.py
python3 experiments/dzc-affine-address-census-20261019/validate.py
```

Main: 0.254043 s / 18,980 KiB RSS; independent audit: 0.098289 s /
20,532 KiB. One nice-19 Core Ultra 9 185H CPU0, WSL2, Python 3.10.12.
Both cap CPU/wall at 59 seconds and address space at 512 MiB. No build,
GPU, dependency installation or foreign code execution. The reused local
oracle was compiled in cycle 0082 with rustc 1.97.1 / LLVM 22.1.6; it is
not a new compiler benchmark. Two initial harness/control assertion failures
and their corrections are retained in `initial-harness-failure.txt`.

Baseline / removed work / added cost / ceiling: compared with previous
shared maps, the partial proposal removes only parameter/base index requests,
adds call-site pointer adjustments, and removes no field/table/fold/proof
work. End-to-end gain is unknown. Carried owner R6/b7 8B CPU diagnostic:
T128, 32 blocks, one 16-thread pass, GPU off; total 471.580 s, proof region
370.137 s including witness 94.021 s and block loading 17.408 s; sealing
101.279 s; D 44.833 s; receipt 922,711,264 bytes. Deleting ALL D for free
bounds this diagnostic at 1.105058× or 0.271428→0.299944 diagnostic
positions/s. The candidate affects a strict subset. Fresh verification
34.587 s plus loading 11.599 s; recheck 32.311+9.903 s. Serialization,
startup fraction and steady slope are unisolated; sealing is recurring
input work, not public startup. No receipt was reverified by this researcher.
All 20 carried source/evidence pins recheck; separate T32 next-token clocks
remain in `target-accounting.json`.

Seven LIVE primary records append 448→455: new MLIR/older Polygeist
legality work and artifact, new older BatchZK scheduling lead; refreshed
super-sumcheck, efficient-sumcheck and October zkLLMPoT v2. Source dates,
actual/declared license scope, inspected Polygeist commit, stale-history
limits and fetch failures are recorded in `source-records.json`. No external
performance reproduced. See [search assessment](search-notes.md).

Native seam: pinned GPU-lane `hashline/src/private_block/argument.rs:1551`
(`SC_DZC`) through `zkp-core/src/sumcheck/rounds.rs::SumcheckRounds`.
Research seam: `translated_plan` / `partial-address-plan.json` replacing
parameter/base loads in the prior `grouping.py::emit`, preserving raw/scratch
maps. ABI remains `driven(raw,params,bases,out)`: 118 Fp2 endpoints, 129
proof-local Fp2 parameters, 36 canonical u64 parameters, five coefficients.
All proof-local values must be rebound per attempt/layer; R8 per-layer
calibration is not permission to reuse a stale pack. Actual admission,
challenge/alpha/g_u8 provenance, mask/RNG/refusal behavior, PCS/finals,
independent receipt verification, joint privacy and enclosing clocks remain
owner gates. No extra opening or private randomness reuse. Main/Claude
reviews any integration; no production patch or merge.

The uniform-raw idea is eliminated. Partial translation is low priority;
the next local experiment should classify public setup lifetimes across the
current sealing/restart path, respecting prior suffix-cache negatives.
Owner whole-prover GPU and independently verified resident 1/2/4/8-pass
measurements remain first. D30 remains a separate unbuilt profile and D32's
float-fidelity direction stands. Full ranking: `hypotheses.json`.

New target proofs / complete-model passes / positions: **0 / 0 / 0**,
device none. Target context, steady/total rates, startup fraction and witness,
proof, serialization and verification clocks unmeasured. No long-context
prefill, resident pass series or decode ran. Larger workloads remain allowed;
attention may grow quadratically. The complete private 8B / ≥50 proved
positions/s GPU target remains unchanged and unachieved.
