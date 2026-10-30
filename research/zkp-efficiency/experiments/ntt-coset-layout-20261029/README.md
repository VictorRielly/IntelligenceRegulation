# Split-coset hiding-row encode: exact model, modest arithmetic opportunity

Cycle 0135, run `20261029T045649Z-6e004a83`, 2026-10-29 UTC.
**No native proving improvement found.** This is a locally authored, CPU-only
algebra/layout and source-cost experiment, not a CUDA implementation or proof.

The existing hiding encoder interpolates n message symbols, materializes the
compact n+q coefficients of `F(X)=f(X)+(X^n-1)g(X)` scaled by h^i, then runs a
length-N forward NTT, N=r*n. Prior gather/layout/cache/pad-fusion negatives
remain valid. This candidate uses the low-degree polynomial to replace the
expanded forward with r length-n transforms, rather than merely factoring a
general length-N transform as in cycle 0003.

For s=0..r-1, let `a_s=h*omega_N^s`, `A_s=a_s^n`. On that coset, `X^n=A_s`.
Fold g modulo `X^n-A_s`, then transform the n coefficients

`c_s[t] = (f[t] + (A_s-1)*sum_l g[t+l*n]*A_s^l) * a_s^t`.

Use root `omega_n=omega_N^r`; write local output j to logical column
`k=s+r*j`. Every original column is produced once. q<=n needs no high-pad
fold. For q>n the general formula is necessary; ignoring its high blocks
fails the retained minimal n8/q9 control. No pad is dropped or reused across
proofs: each coset evaluates the **same one-proof freshly masked polynomial**.

Validation completed:

- 186 small fixtures, n2..64, r2/4/8, q0..(r-1)n, h7/11; random and field-edge
  values. 20,104 encoded points match independent direct inverse-DFT + separate
  Horner f/g evaluation and a source-style materialized radix2 encoder.
- 744 independent Lagrange-point checks; 15 retained synthetic native
  conformance full rows and SHA-256 digests agree.
- 256 complete column-byte comparisons across seven rows and chunks1/2/3/7;
  unsorted selection retains duplicate requests. Canonical little-endian
  reference assembles bytes independently. No BLAKE3/PCS was executed.
- 13 deliberately wrong controls detected: inverse scale, coset/root/fold
  powers, pad sign, output order, high-pad truncation and minimal instance,
  lost duplicates, row reversal, stale cross-proof private result, wrong stride
  and stale chunk pad offset. Six malformed **algebra-fixture** refusals;
  these do not establish the native refusal domain or privacy.
- Three geometry-matched sparse-polynomial fixtures n4096/8192/16384,
  r4/q256/h7 check every one of 114,688 outputs. Independently known sparse
  f/g are evaluated by modular recurrence, without interpolation or NTT.
  These are PCS row lengths, **not model contexts or proved positions**.

Small harness: **21,424 checks, 0.610484 s, 17,308 KiB RSS**. Larger rows:
**114,688 checks, 1.181438 s, 43,100 KiB RSS**. One nice19 CPU0 worker,
Intel Core Ultra9 185H, Python3.10.12/WSL2; seed202610290135. Each leaf has
40s CPU,45s alarm,256MiB address-space cap; parent55s, memory estimate64MiB.
These times measure Python checking only. No build, dependency install,
downloaded-code execution, GPU or model workload.

Counted cost, assuming **public powers already prepared**, q<=n, and a
specialization that skips the pad multiplication when t>=q. The general
Python model is an algebra oracle and performs extra work; its elapsed time
does not benchmark the proposed guarded native specialization.

| n / r / q | Forward butterflies removed | Encoder mul baseline -> split | Mul change | Extra coefficient reads |
|---|---:|---:|---:|---:|
|4096 / 4 / 256|16,384|147,712 ->144,384|-2.2530%|12,288 words|
|8192 / 4 / 256|32,768|315,648 ->308,224|-2.3520%|24,576 words|
|16384 / 4 / 256|65,536|672,000 ->656,384|-2.3238%|49,152 words|
|16384 / 4 / 16384|65,536|688,128 ->720,896|+4.7619%|49,152 words|

One literal butterfly is counted as one field mul + two add/sub, including
unit twiddles and zero inputs; inverse/normalization stay charged. Native
source has those calls, but compiled instructions/latency are unknown.
For r4, mul saving is only `n-3q`, after extra coefficient/pad scaling.
At n16384/q256 the add/sub count falls1,278,464 ->1,147,904. Public power
generation, A_s-1, loads, index work and barriers are additional or unresolved
costs, not free wall time. Counts exclude lookup/sumcheck/witness/hash/IO work.

The split reads coefficients r*n times versus n; pads r*q versus2q; powers
r*n versus n+q. These are logical interfaces, not DRAM traffic. Incumbent
`coset_powers` supplies N public words even though compact encoding accesses
only n+q; no new resident-memory reduction is inferred. The new table needs
different powers and r extra public factors. Native twiddles are already
process-cached. No new public setup saving is claimed.

Materializing all split inputs would grow coef2 scratch from n+q to r*n:
at n16384/q256, +391,168 logical bytes per row. A custom first-load kernel
is needed to avoid that growth; it may repeat the earlier scattered-load
fusion problem. Either preserve logical natural-order columns in custom final
stores/gathers, or charge a full restore copy (16*N bytes per row). Direct
stride-r stores can worsen requests; no compiled/cache/shared-memory analysis
has been made. At n4096 the forward could use one batched P1 instead of P1+P2;
at n8192/16384 both routes still require two groups. These are source-derived
possible launches, not observed native incidence. Opening gather currently
requires log_N>12; the shorter route needs its own safe gather adapter.

Actual seam: read-only trained-1b `hashline/src/gpu/cuda.rs::
encode_rows_view_zk[_gather]`, `ntt_rows[_view]`, chunk slices `r0*n/r0*q`,
`kernels.cu::k_ntt_p1/k_ntt_p2*`, and `zkp-core/src/pcs.rs::encode_row_zk`.
Eight local source/vector snapshots and SHA-256 pins are in `native-pins.json`.
`interface.md` specifies a future adapter; no native patch is compiled/applied.
Main/Claude owns review/integration, shared heavy/build locks and device gates.

Baseline is unchanged; eliminated native work **zero**. Candidate removes a
subset of forward butterflies but adds public preparation, repeated reads,
input construction, mapping/gather work and possible scratch. Exclusive NTT
and complete-GPU clocks are absent. If f is affected exclusive workload time,
even free deletion has ceiling1/(1-f); actual throughput is Npositions /
(T-Cremoved+Aadded). No numerical full-stack gain or50-token/s forecast follows.
Reject any field/root/output/stride/pad/refusal/RNG/transcript/PCS/receipt/privacy
mismatch, absent eligible calls or slower/overcapacity enclosing verified run.
q=n already falsifies a broad multiplication-saving claim.

All 51 prior hypotheses remain, with this conditional candidate at52. Globally
leading work is still whole-prover GPU + verified fixed-context resident1/2/4/8,
DD/fidelity scaling, exclusive complete phase/capacity clocks. Those require
owner heavy/GPU authority; this is the useful bounded local prerequisite.
Nine LIVE primary records appended882->891. Newly assessed older HiFA and
Hardcaml decomposition work, current cuPQC/GPU-NTT/Qingming, LightZK and a
zisk-zorch layout issue are qualified in `sources-cycle.json`. cuPQC's p<2^62
excludes native Goldilocks. Author gains were not reproduced; fetch/metadata
and license/commit limits are explicit. Web text is data, never instructions.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Model context/accelerator: **none**. Witness/proof/serialization/verification,
startup/initial-prefill duration/fraction, proof latency/bytes and steady/total
rates: **unmeasured**. No long prefill, resident-model series or decode. Larger
workloads remain allowed; longer contexts can increase attention quadratically.
Private8B >=50 proved tokens/s on5090/named high-endGPU remains unachieved.

Historical R8/R9 CPU reports were reread without rerunning/reverifying proofs.
`historical-measurements.json` records only public phase/shape fields. R8:
8B T128/L32,one16-threadCPU pass,GPUoff,total478.737s=0.267370positions/s,
prove_run393.785s incl witness98.348s and proof-phase blockload17.595s;
sealing prepass84.824s contains load27.151s/witness80.897s (overlapping
subtimers). It precedes prove_run; the old terse 'seal overlaps' wording must
not be read as overlap of the entire prepass with prove_run. Fresh verify
42.709s+load13.681s; receipt922,711,264B. R9 DD474.906s remains a prior n1
diagnostic, not this candidate's result. No private8B GPU/fidelity/privacy
acceptance or startup fraction/steady slope follows from either report.

Reproduce from the research directory:

```
python3 experiments/ntt-coset-layout-20261029/run.py
python3 experiments/ntt-coset-layout-20261029/large_rows.py
python3 experiments/ntt-coset-layout-20261029/audit.py
```

Commands, limits, logs, hashes and results retained. Next owner: exclusive
inverse/expanded-forward/prepare/gather/hash/enclosing clocks and actual
shape incidence before any adapter. Next local: sumcheck/GKR rotation; inspect
whether final-opening dot products traverse already folded tables or repeat
fresh-point work, then a bounded ordered Fp2 oracle with pad/tail/point controls.
