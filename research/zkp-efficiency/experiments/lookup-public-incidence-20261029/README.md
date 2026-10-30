# R13 exact-expression looked-column storage

Run `20261029T085649Z-193029f7`, cycle0139. Checkpoint 2026-10-29T09:12:05.812753+00:00.
No native proving improvement measured. This is a source-derived metadata,
synthetic differential and logical storage study, not an implemented Rust/GPU path.

The frozen R13 source (tree digest bb9eb212…, not a Git commit) has a new
`AccuracyIds::lookups` emitter. Unlike the earlier R9 census, full-byte pins
are emitted even when their coefficient is1. The public expression repeats;
its logical occurrence is still part of the admitted profile. The tested model
builds one private looked vector per exact `(domain,source,coefficient,constant)`
and retains an ordered index per original occurrence. Weighted histograms and
miss counts retain every occurrence; helpers retain the original pairs.
Prepared private values are reconstructed for every invocation and not retained
in the public Plan. Masks, openings and per-proof challenges are never cached.

| 8B T128 representative public class | Baseline looked MiB | Prepared MiB | Avoided MiB |
|---|---:|---:|---:|
| fE9, no DD |490.25|481.25|9.00|
| fE9, DD32 |463.25|460.25|3.00|
| fE12 or16, no DD |498.25|497.25|1.00|
| fE12 or16, DD32 |465.25|464.25|1.00|

Source `NATIVE_LAYOUT_CENSUS.json` public query totals agree for all six selected
classes. These are per-block logical looked-buffer bytes, excluding existing
A/H/M, codewords, scratch and new public plan metadata. Model-sized arrays were
never allocated. Precision is the source's representative BASE fixture:
q/k15, v16, pv12, score18, ao21, down20, up12, gate18. It is not an observed
8B layer calibration. Native derive's permitted v10..16 and pv12..16 sensitivity
is separate in `sensitivity-result.json`: aliases disappear when v<16; pv16
adds a Q-domain alias. Actual per-layer incidence and memory high-water are unknown.

The native source already prepares256 byte inverses once per proof. This
experiment does not rediscover that cache. It shares only exact source-vector
materialization within the same invocation. All A/H/M rows, helper planes,
fresh masks, PCS claims and logical schedule remain by construction. A proof
byte identity result remains untested. Profile-level alias deletion is a
different unimplemented protocol change and receives no speed credit.

Probe: 11,874checks, 1,872fixtures,
104helper cases and 14controls,
0.426626s / 18,864KiB RSS. Source/accounting audit:
237checks,4count-preserving source mutations and12pins,
0.003104s / 15,176KiB. Seed202610290139.
References are independent implementations by this researcher, not external
review. CPU-light checks pinned one nice19 worker,40sCPU/45salarm/50sparent,
256MiB address space,96MiB estimated memory. Two initial reader bugs and their
corrections are retained under `initial-*-failure/`. No foreign code executed.

Commands from research directory:

```
python3 experiments/lookup-public-incidence-20261029/run_bounded.py probe.py
python3 experiments/lookup-public-incidence-20261029/run_bounded.py audit.py
```

Baseline/elimination/new costs/ceiling/falsification are in hypothesis58 and
the handoff. Numeric end-to-end improvement is unknown: deleting a genuinely
exclusive fraction f gives at most1/(1-f), before costs. The saved byte fraction
is not f. The selected savings are small; whole-prover GPU and exclusive phase/
capacity telemetry remain ahead of this integration.

LIVE primary literature/GitHub search: Baloo, cq and its Halo2-PSE fork;
Plonky3 current release/components/caller obligations; Gryphes; zkLLM. No author
performance reproduced. Dates, license scope, observed versus inspected commit
coordinates and exact access blockers are in `sources-cycle.jsonl` and web logs.
Baloo is a newly assessed older technique here. Pairing/KZG/zk-cq linkage is
an architectural cost, not an existing native helper replacement.

New independently verified full-stack proofs/passes/positions:0/0/0.
Witness/proof/serialization/verification/startup/initial-prefill clocks and
startup fraction, steady-state/total-workload rates, proof latency/bytes:
unmeasured. Actual model context/accelerator:none. No long prefill, resident
model pass series or decode ran. Larger workloads are allowed; increasing
attention context can increase work quadratically. Private8B >=50proved
tokens/s onRTX5090 or another named high-endGPU remains unachieved.
