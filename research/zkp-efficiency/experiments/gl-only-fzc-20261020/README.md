# Host-free BASE GL-only derivation — cycle 0099

Run `20261020T071854Z-1076bec1`, 2026-10-20 UTC.
**No proving speed improvement measured. No native build, GPU or proof ran.**

Question: can the raw-round-zero BASE GL derivation remove repeated endpoint
arithmetic without the prior full pair's host pad preparation? Yes at the
Python algebra/source-call level. Whether it is faster remains unknown.
This is the highest locally testable hypothesis; the top three require
owner GPU/heavy measurements unavailable in this research lane.

The pinned active source calls `fzs_derived_at` at lo and hi in phase 1b.
The candidate evaluates GL at lo and evaluates its homogeneous part on the
shared difference, then reconstructs hi = lo + difference. It computes the
three GL clauses over base-field scalars under the existing BASE flag;
mu, results, shared derived tables and global stores keep both extension
coordinates. PL and all non-BASE cases retain the literal existing path.
No host preparation, Rust API/parameter layout change, buffer, barrier or
private-value scan is added. Existing BASE eligibility is not broadened.
Only raw && !FOLD round zero can use the adapter; later rounds keep stored
and folded derived tables and existing paths. Fresh randomness and every
private owner/opening remain as before.

The independent schoolbook quotient-field oracle evaluates the original
SC_FZC polynomial and direct Boolean-weight MLE from original tables, rather
than the candidate's scalar formulas or in-place fold. The final run passes
**36 fixtures, 144 rounds, 2,372 checks, 15 negative controls and 90 partial
source-cost cases**. Seed `2026102099`; cube entries 8/16/32; support on/off;
0/1/3/8/11 public nonzero pad weights; base and extension A; modular edges;
Kh randomly chosen from 2^{9,10,12,15,16}. All helpers/coefficient/challenge
coordinates can be extension-valued. Canonical round bytes, original-table
final evaluations, final derived values, final original polynomial and high
stores match. Only 18 first rounds dispatch BASE. Synthetic hash challenges
are not native Fiat–Shamir, and arbitrary tables are not transformer witnesses.
A cube entry count is not a token context. Three supplemental PL-only
imaginary-input probes establish algebraic preservation, not new eligibility.

Controls catch BASE on each of the eight GL-used extension inputs, an
extension difference, BASE after extension folding, lost imaginary results,
constants wrongly included in the homogeneous difference, omitted high
reconstruction and stale/zero mu_pad. PL-only extension operands remain exact.
Source validation passes 223 checks, including eight current native hashes.
The initial run is retained; the final run adds explicit final-derived and
original-polynomial checks. No downloaded code or dependency ran.

At illustrative L=2^21 entries, support on, k=11 nonzero public pad weights:

| Variant | Counted base products | Counted adds + subs | Logical shared reads |
|---|---:|---:|---:|
| Current literal endpoints | 111,149,056 | 423,624,704 | 912 MiB |
| This GL-only candidate | 96,468,992 | 326,107,136 | 656 MiB |
| Prior full prepared BASE pair | 67,108,864 | 76,546,048 | 304 MiB |

GL-only saves 14,680,064 products, 97,517,568 additions/subtractions and
256 MiB logical shared operand reads versus literal; its absolute savings
are independent of pad support in this partial source model. The full pair
saves more source work but adds k fresh host Fp2 preweights and parameter
staging (11 / at most 176 bytes here). For zero support they coincide.
GL-only adds **zero** preweights and parameter bytes. All variants retain
both high/low stores; global/capacity saving and new barriers are zero.
These are precompiler primitive calls and logical reads after assumed dead
code elimination, not instructions, physical traffic, bandwidth or timing.
The compiler may already eliminate work in the existing BASE instantiation.
Register/branch/code-size/occupancy effects still require native measurement.

If f is the unknown exclusive fraction spent in this raw-derived phase,
even removing the whole phase permits at most 1/(1-f) enclosing speedup.
This candidate removes part. No numeric GPU/model ceiling can be justified
without f and complete workload clocks. Do not transfer the carried CPU
phase mix or the old one-block softmax bottleneck to a high-end GPU forecast.

Integration seam: `fzs_impl<...,BASE>` raw && !FOLD phase1b in the pinned
`ops/zkp-mvp/gpu-zerocheck/hashline/src/gpu/fzc_kernels.cu:855`.
`candidate_gl_only.cuh` is an uncompiled sketch. It returns lo, dif AND hi;
keep both global stores and all shared writes/barriers. No host patch needed.
Existing host BASE gating remains at cuda.rs:4300 and next==0 at :4628.
Inspect/compile only in the owner's lane with shared build/heavy locks.
Run literal / GL-only / full-pair A/B with ptxas registers/spills, actual
raw/BASE incidence and public pad counts, exclusive phase and enclosing
clocks, masked-round/next-challenge/receipt identity, fresh independent
verification, strict-GPU/refusal/CS/H-1 and current privacy gates. Reject
any mismatch, broadened eligibility, absent compiler savings or enclosing
regression. This research lane does not merge.

Commands from research root:

```text
python3 experiments/gl-only-fzc-20261020/run_bounded.py probe.py
python3 experiments/gl-only-fzc-20261020/run_bounded.py validate.py
```

Final algebra/cost leaf: one CPU thread/core0, nice19, **2.415 s / 17,012 KiB
RSS**, Intel Core Ultra9 185H / WSL2. Each leaf has 59-second CPU/alarm,
60-second parent timeout and 512 MiB address-space caps. This is synthetic
CPU execution time, not any proof clock. Commands, seeds, case dimensions,
source/code hashes, hardware, limits and logs retained.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context and accelerator: none. New witness/proof/serialization/
verification clocks, startup fraction, steady-state and total-workload proved
rates: **unmeasured**. No long-context prefill, resident-model pass or decode
ran. Carried non-DD CPU8B T128/L32 one16-thread pass, GPU off: 478.737 s =
0.267370 positions/s; prove_run393.785 includes witness98.348/load17.595;
seal84.824 overlaps; receipt922,711,264B; fresh verify42.709+load13.681s;
recheck34.395+load10.739s. Not rerun/reverified. Carried startup, steady
slope and isolated serialization unknown. D33's frozen R7 TinyLlamaT32
privacy acceptance is not extended. R9 DD soundness accepted with N-r9-a/b;
DD privacy gate still owed; T128478.7->474.9s is explicitly a noisy null.
Complete private8B >=50 proved tokens/s on5090/another named high-end GPU
remains unachieved. Larger workloads allowed; attention may grow quadratically.
No mask/opening reuse or privacy weakening is proposed.

Six LIVE primary records appended571->577. Newly assessed older
[sumcheck non-malleability](https://eprint.iacr.org/2026/335) is PCS/compiler
specific and supplies no native opening-reuse authority. Newly assessed
[TenseUp](https://eprint.iacr.org/2026/2435) has an October10 update in the
[primary index](https://eprint.iacr.org/2026/); page/PDF fetches fail, so
geometry/constants/security remain unassessed. Refreshed DeepProve, NanoZK,
SP1 and October zkLLMPoT distinguish public setup, all-layer coverage,
operator clocks and GPU projections. Exact URLs/dates/commit/license/access
limits in source-records.json; no author performance reproduced. DeepProve's
custom license was inspected, not assumed permissive; no external code used.

Ranked queue: owner complete GPU + verified resident1/2/4/8 passes; DD larger
contexts after T128 null; actual peak/raw/BASE/phase telemetry; this GL-only
versus full-pair native choice; prior public loader; capacity-gated arena;
retained negative findings. Full14-entry queue in hypotheses.json.
Next local: census the Rust construction of public pad-weight descriptors and
existing raw/BASE/SUPP gates, to establish reachable k without private-value
scans or telemetry. This can determine whether the simpler adapter is relevant
before more algebraic refinement. Owner compiler/phase results take priority;
source counts cannot substitute for native timing. Next owner: the three-arm native A/B described above.
Only research excluding runtime written; no production/Git/build/GPU/install/
external message/write/purchase/escalation. Reports imply no external delivery.
