# Prover-only PCS preparation — cycle 0146

Run `20261029T155649Z-9750c59b`, October 29, 2026. **Exact component candidate;
no native proving improvement measured.** Only synthetic values and public
source-derived metadata are used. The production patch is unapplied.

The native R13 `open_zk` calls `group_zclaims`, which materializes a full
column-weight vector per group. Its sole consumer, `zk_rhos`, ignores those
column vectors. They are required by the verifier. The candidate introduces
`group_zclaims_with_columns(claims, rows, log_cols, columns)`; the original
wrapper calls it with `true`, and only `open_zk` passes `false`. Row-weight
construction, ordered full keys, all assertions, member order and wants stay.

The initial repeated-grouping hypothesis was demoted: `zk_groups_for_record`
rebuilds everything in legacy FFN reporting, but the actual current private
block audit already uses `opening_groups_at` with compact public keys.
There is no `n_groups_zk` symbol in the inspected current call chain.
Prior split-Eq suffix caching and fresh mask-tail caching are distinct scopes;
this candidate retains no public or private cache across any call.

`native-pins.json` records 13 production/prior-model hashes. Four native
functions are extracted unchanged. Native field arithmetic is compiled;
Eq's Rayon iterator is adapted to a serial iterator with identical arithmetic.
The proposed native patch preserves the original Rayon source. The local
scripted Transcript generates deterministic full-field fixtures; it is **not**
Fiat–Shamir, an accepted RNG, or a security test of the native transcript.

Completed bounded probe:

- 162 small fixtures; 11,664 row entries compared;
  662,256 independent original-slice cube coefficients;
  2,754 scripted challenge draws and 59,328 synthetic folded values.
- Eight malformed cases panic in both arms; eight negative controls cover
  order, row coefficient, challenge consumption, changed value, verifier
  columns, input order, zero coefficient and the empty-claim boundary.
  Panic acceptance status is compared, not panic text or native error payloads.
- Four larger cases use the public R13 8B T128 A/H descriptor, group and
  row dimensions, DD off/on, with synthetic row placement, coefficients and
  points. They compare full grouped row arrays and extracted `zk_rhos`.
  They do not construct the actual private matrix or execute a native proof.
- Counting allocator confirms 133/142 fewer allocation calls and
  20,541,952/21,918,848 fewer cumulative requested bytes for A+H.
  Source accounting independently matches these exact deltas.

| Source-derived 8B T128, one core block | no DD | DD32 |
|---|---:|---:|
| A/H groups | 36 / 9 | 38 / 10 |
| Dense column-vector payload removed, summed across A then H | 11,796,480 B | 12,582,912 B |
| Eq builds removed | 44 | 47 |
| Native source Fp2 products removed | 1,092,008 | 1,165,730 |
| Nonempty allocation calls removed | 133 | 142 |

The payload sums are **not simultaneous peak memory savings**: A/H openings
are sequential. Temporary Eq/reversal requests contribute to the cumulative
allocator delta, not retained column payload. Native compiler elimination,
allocator capacity, physical traffic and whole-prover peak remain unknown.
No layer multiplier is applied. Boundary tables are counted separately in
`costs.json`; an internal boundary joins both neighboring sites once.

Large-case serial grouping + scripted rhos + drop median ratios are
2.197/1.616 (no-DD A/H) and 2.037/1.513 (DD A/H), three alternating samples
per arm on a shared CPU. Tiny five-group/eight-row helper ratios are much
larger and are not representative of model proving. All raw arrays remain
in `result.json`. Actual matrix folding, FS hashes, witness, encode, Merkle,
transfers, serialization and verification are outside these diagnostic clocks.

The target ceiling is `N/(T-C_exclusive_removed+A_added)`. For an exclusive
affected fraction f and native phase ratio k, speedup is
`1/((1-f)+f/k)`; even free removal is bounded by `1/(1-f)`. Neither f nor
native k is measured. The branch and empty Vec header are new costs; all
original private reads, row weights, fresh masks/pads/salts, openings and
schedule/refusal checks remain. No quantitative full-stack forecast follows.

Probe: 0.342152s, 38,356 KiB maximum RSS. Final compile: 1.830356s,
173,372 KiB RSS, Rust 1.75.0, opt-level1, one codegen unit. Each stage has
one CPU affinity, nice19, 40s CPU / 45s alarm / 50s parent timeout and
384 MiB address-space cap; estimate96 MiB probe / 320 MiB compile.
Compiler auxiliary thread count is not measured. No Cargo, installation,
GPU, native build or downloaded execution ran.

The first expanded unrolled fixture failed to compile with
`memory allocation of 2097152 bytes failed` under that cap. Code/logs are
retained in `failed-unrolled-sized/`. Compact parsed public descriptors
compiled under the same cap. The initial small-fixture pass is retained in
`initial-component-pass/`. An audit parser initially failed on generic native
function names; its failure is retained in `audit-parser-failure/`, then fixed.
No arithmetic failure occurred. The final audit checks 160 conditions,
13 pins, in-memory patch replay and unchanged verifier/refusal/consumer bodies.

Seven LIVE primary records append to sources.jsonl, with exact dates/URLs,
license scope and inspected/observed commit distinctions. Newly screened
FlexProofs amortizes all vector-index openings using a different commitment
architecture. The newly inspected older Hyrax implementation needs its column
tensor for an evaluation/dot proof; our omission does not transfer to it.
Plonky3's September packed-Eq PR supplies a related preparation technique and
reports its own small negative cases. Its October release and ITC batch
paper are refreshed. No author timing or theorem was reproduced.
`blockers.json` and `web01..12.json` retain failed fetches and exact provenance.

Reproduce sequentially from the research root, without setup:

```text
python3 -B experiments/composition-eq-scope-20261029/run_bounded.py prepare
python3 -B experiments/composition-eq-scope-20261029/run_bounded.py compile
python3 -B experiments/composition-eq-scope-20261029/run_bounded.py probe
python3 -B experiments/composition-eq-scope-20261029/run_bounded.py account
python3 -B experiments/composition-eq-scope-20261029/run_bounded.py audit
```

Seed202610290146, one Intel Core Ultra9 185H CPU worker; no GPU.
New independently verified full-stack proofs / model passes / proved positions:
**0 / 0 / 0**. Actual model context: none. Witness/proof/serialization/
verification clocks, startup/initial-prefill duration and fraction, proof
latency/bytes, steady-state and total-workload token rates: **unmeasured**.
No long-context prefill, resident-model pass series or decode ran. Larger
workloads remain permitted; dense attention can grow quadratically in context.
Private8B >=50 proved tokens/s on RTX5090 or another named high-endGPU remains
**unachieved**.

Next owner action: exclusive group/Eq/row-fold/open/enclosing clocks before
porting; then current-lock native bytes, refusal, RNG/transcript, PCS, privacy
and independently verified workload gates. Any mismatch, existing compiler
elimination, newly introduced column consumer or no enclosing benefit rejects
promotion. Next local rotation: memory traffic/GPU commitments; count actual
multi-rho row-fold scans and device chunk-of-four boundaries before proposing
any fusion. Main/Claude owns review and integration; no merge or heavy job queued.
