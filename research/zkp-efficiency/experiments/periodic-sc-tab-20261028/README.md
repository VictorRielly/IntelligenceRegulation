# Periodic public SC_TAB descriptor

Cycle 0128, run `20261028T215649Z-43c1f18d`, 2026-10-28 UTC.
**Synthetic algebra and source counts only. No proving gain measured.**

Current native SC_TAB builds three length-L public vectors by repeating 256
freshly encoded U8/exp/act rows. The candidate keeps those 256 rows, ignores
the leading constant MSB axes during binding, and folds only the final eight
axes. It uses the same full cube, original table order and polynomial. All
six private multiplicity/helper factors, equality, support and pad-zero work
remain. This is per-call arithmetic reuse, never reused blinding or challenges.

Reproduce from the research directory:

```text
python3 -B experiments/periodic-sc-tab-20261028/run_bounded.py probe.py
python3 -B experiments/periodic-sc-tab-20261028/run_bounded.py audit.py
python3 -B experiments/periodic-sc-tab-20261028/run_bounded.py artifact_audit.py
```

The runner pins one allowed CPU, nice 19, 45-second CPU/alarm, 50-second parent
timeout, 256 MiB AS and a 96 MiB estimated memory budget. No dependencies,
native build, GPU or downloaded code executes. Hardware/commands/hashes are
retained. The copied local `field.py` and heterogeneous `driver.py` were read
before reuse; their original experiment is cycle 0039. Earlier cycle 0040's
grouped work and cycle 0127's public-prefix result remain in the durable queue;
this slot uses the native ClosureRounds path, not a grouped fallback.

`probe.py` passes 50,042 checks over six complete synthetic SC_TAB fixtures,
dimensions n=8/9/10, 54 rounds, 216 round coordinates, 64 independently
evaluated original-cube terminals and 48 extension-polynomial comparisons.
Every restricted public row is compared to dense folding. n=13/14 tests are
public-descriptor-only, with full Fp2 original-cube terminal checks and a zero
leading challenge; no full native T128 run follows from these fixtures.
Twenty-four control instances cover wrong axes, dropped Fp2 coordinates,
missing extension selectors, malformed cube/length/state/index/point/family,
stale beta/gamma, zero-filled lifted tables, lifted byte indices and a forged
padded helper/multiplicity that vanishes without the required pad term.

`reference.py` independently implements integer-coordinate encoding,
schoolbook tuple Fp2 multiplication, original-cube prefix sums and an expanded
monomial polynomial. It never calls candidate readers/folds. Both algorithms
are researcher-authored. No external or native prover independently verified
this experiment. SC_TAB has degree 3 and one native extension round; the
second modeled extension is adapter stress only. Native CFS/terminal 0/1
refusals are source-audited obligations, not implemented test controls here.

Final model: 3.977046 s, 16,400 KiB RSS. Source audit: 64 checks,
0.011229 s, 15,840 KiB RSS. These clocks include checking and do not compare
native performance. Initial narrower passing result is preserved in
`initial-before-extra-controls/`; later runs added coverage or removed two
tautological refusal assertions from the control count, not timing selection.

At pinned R12 T128 L=16,384, three public vectors contain 49,152 Fp2 words
(786,432 B); descriptors contain 768 words (12,288 B), saving 774,144 B logical
initial payload. Public folds fall 49,149 -> 765, removing 48,384 lerps.
The enclosing 11-table initial payload is 2,883,584 -> 2,109,440 B by source
count, not native capacity or measured peak. Round endpoint calls stay
98,298 for the public factors, and generic polynomial evaluation work stays.
18 constant-axis bind-state updates are added. Exp/act source products fall
32,768 -> 512; the previous tiling candidate already obtained that arithmetic
count but retained the expansion and extra copy reads. These are alternatives,
not additive savings. No downstream public clone exists to eliminate.

For 32 sequential block/argument calls the removed payload is cumulatively
24,772,608 B and removed public lerps 1,548,288; neither is a simultaneous
peak or an elapsed saving. Prove and each verification are separate calls.
R12 T32/T64 use n13; T128 n14. R13 LOW+h24/per-group tables and unregistered
T512 are excluded. Terminal evaluation can use only the low eight point
coordinates, but every extension selector remains; immutable verifier
evaluation may add short scratch/copy work. No verifier clock is measured.

Added costs: fresh 256-row construction, metadata, typed dispatch, endpoint
indexing/checks, binding state and heterogeneous builder/ClosureRounds/census/
capture/verifier integration. Dense private/equality/support storage remains.
No source-product count predicts instructions, DRAM traffic or GPU occupancy.
With unknown affected critical-path fraction f, free deletion is bounded by
1/(1-f); the real candidate deletes only part and adds costs. Any mismatch or
negligible exclusive phase/enclosing regression falsifies usefulness.

`candidate-periodic.rs` is an **uncompiled, unapplied sketch**. It does not
adapt native Tab or ClosureRounds. Owner must review every enum match, exact
full-cube validation, fresh encoding, six private terms and pad lists,
terminal ordering/selection, CFS/RNG/transcript/refusals, golden bytes, claims,
PCS, independently verified full receipts and current privacy gates. First
measure exclusive constructor/public-fold/SC_TAB/enclosing shares under the
shared build/heavy locks. Do not build here or infer GPU incidence.

Nine source records and eleven native LIVE batches are retained in
`source-records.jsonl` and `web-live/`. Known contemporary sumcheck/SP1 sources
were refreshed; the original CMT 2011 paper was newly read for its public
wiring/preprocessing boundary. The bounded-space verifier paper is parked:
its exponential-space-parameter prover bound is not a practical native speed
method. Dates, declared licenses, inspected/exposed commit distinctions,
429/cache-miss/404 blockers and prior-URL counts are explicit. No author
benchmark was reproduced. `hypotheses.json` retains all 41 prior candidates,
refines 1/41 and adds 42; top owner priorities remain whole-prover GPU/resident
workloads, DD-context/fidelity scaling and complete phase/capacity clocks.

New independently verified full-stack proofs/passes/positions: 0/0/0.
Actual model context/accelerator: none. Witness/proof/serialization/verification,
startup/prefill/startup fraction, latency/bytes, steady and total-workload
rates are unmeasured. No long prefill, resident series or decode ran. Larger
workloads remain allowed; attention can grow quadratically. Private 8B at
>=50 proved tokens/s on RTX 5090 or another named high-end GPU is unachieved.

Next local: inspect current CFS/extension source and prior masked-driver work
for a bounded original-mask-basis/terminal/refusal differential at this exact
slot, avoiding duplicate work. Owner native exclusive clocks take priority.
Main/Claude reviews/integrates; this research lane does not merge.
