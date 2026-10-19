# Lazy D endpoint scheduling — cycle0078

Run `20261019T101854Z-3562a78f`, 2026-10-19 UTC. **A useful logical-lifetime improvement;
no native proving speedup measured.** At both current unpadded T128 catalogs,
constructing endpoints at first use lowers the complete polynomial-buffer
peak **129→77 Fp2 words (40.31%; 832 logical bytes per active row worker)**.
Both schedules release inputs and derived buffers after last use. Endpoint
construction's extra high-value temporary and the five-word round accumulator
are charged. This is not a physical register, RSS, VRAM or proof-clock result.
Never multiply per-worker savings by every row and call it VRAM.

The baseline is cycle77's pair-streamed coefficient path, with its 59 input
endpoint pairs materialized before arithmetic. The candidate schedules the
same source pairs on first public-indexed use, memoizes them for later uses,
and has exactly the same expression DAG up to node order. Both preserve all
original folds/finals, polynomial degree, samples and point-1 recovery.
Python retains its dictionary/graph/oracle values; its RSS does not realize
the modeled lifetime release. A native adapter must use static named locals
or another independently validated allocation, and demonstrate their release.

Run from the research directory:

```bash
python3 experiments/dzc-lazy-endpoints-20261019/run.py
python3 experiments/dzc-lazy-endpoints-20261019/audit.py
```

Each command pins one nice19 CPU thread, 59s CPU/wall and 512MiB address space.
Only the captured local Rust expression/catalog reference is compiled, one
codegen unit and opt-level0, no Cargo/dependency install/GPU job. Execution
arguments, exit status and clocks are retained. Seed `2026101978`, N2/8/32;
Intel Core Ultra9 185H CPU0, WSL2. Main 8.612566s,
RSS 47748KiB, compiler 138144KiB; independent audit
0.260665s/RSS 24352KiB. These are correctness-test
clocks, not an optimized baseline/candidate timing A/B.

Thirty fixtures pass: 1,950 candidate coefficients, 2,145 captured-Rust grid
and 390 off-grid values, 90 messages, 1,845 original cube finals, 30 final
relations, 30 remappings/aliases, 390 charged endpoint censuses and
value-independent traces; eight synthetic controls. Independent audit:
**221 checks**, DAG hashes, interval/direct-live-set peaks, public
source-index/read/difference census, all original fold/final contracts and
six unchanged live source pins. The captured Rust closure uses exactu128
field and Shape/Layout substitutes; independent Python clauses/direct-cube
checks agree. Synthetic alpha/g_u8 are fixture constants, not reusable
private proof setup. Generic padded/five-limb/partial-top/odd-helper tests
are algebra controls, not trained admission or actual workload proofs.

| Current unpadded catalog, per row pair | Eager | Lazy |
|---|---:|---:|
|Complete polynomial live peak, Fp2 words|129|77|
|Original endpoint reads|118|118|
|Original endpoint subtractions|59|59|
|Coefficient add/sub/mul/base calls|272/150/331/72|272/150/331/72|
|Original full tables/folds/finals|59|59|

All 34 denominators and17 helpers remain. Original folds are a separate
challenge-dependent pass:118 reads/59writes and59 each add/sub/mul per row.
Including endpoint construction and original folds gives331/268/390/72
add/sub/mul/base calls for BOTH schedules, excluding common round reduction,
sample conversion, plan and enclosing proof work. No full table is added or
removed. The actual catalog's modeled N=524288/19rounds at T128 is not the
synthetic test size and was never allocated or proved here.

Two negative controls constrain implementation: retaining endpoints to the
end makes the lazy peak136words, eliminating the129→77 advantage; omitting
memoization raises reads118→198 and differences59→99. At the lazy peak,
54 of77words are27 retained endpoint pairs,18derived and5accumulator. This
motivates the next question: accumulate each affine clause contribution when
its endpoint is first needed by helper/bilinear/host work, preserving alias
sums exactly once, instead of front-loading every affine source.

Baseline/eliminated/added/ceiling: eliminate early endpoint lifetimes only;
no arithmetic or table-read saving. Charge public dependency planning,
index/alias dispatch, compiler scheduling, scalar scratch and any eventual
spills. Actual8B D-time share and native enclosing gain are unknown;
`new_total = old_total - old_affected_D + new_D + all_integration_costs`.
Even deleting ALL D in the carried1.1B174.052s diagnostic caps at1.18113× /
0.868615 diagnostic positions/s; not an8B bound or this candidate's prediction.
Falsify on any sample/final/degree/transcript/RNG/refusal/privacy mismatch,
no lower complete native resource use, extra uncharged reads/recomputation,
value-dependent scheduling or enclosing regression.

Initial independent audit caught saved metadata shadowing (`ll` reused by
a baseline-lifetime loop). The arithmetic/traces were unaffected; the saved
lazy I/O metadata was wrong. Corrected, main/audit rerun; initial failing
source/logs retained under `initial-trace-metadata-shadowing/`.

Native seam: current `SC_DZC` / `SumcheckRounds`; candidate
`run.py::lazy_row(raw,p)` and prior plan/convert. No production edit.
[Unapplied handoff](../../handoffs/20261019-dzc-lazy-endpoints.md) lists native
actual-challenge, seeded-byte/RNG/refusal, extension/mask/PCS/final-opening,
fresh-verifier and joint-view privacy gates. D30's proposed dictionary is a
new profile; this current-catalog prototype does not implement or admit it.

LIVE source details: `source-records.json` and `web-search-log.json`.
New [Chimera](https://eprint.iacr.org/2026/1388) and
[Sluice](https://eprint.iacr.org/2026/1758) revisions explicitly datedOct16
were abstract-level inspections; PDFs403. Older
[linear-scan paper](https://web.cs.ucla.edu/~palsberg/course/cs132/linearscan.pdf)
and [2020 allocation paper](https://arxiv.org/abs/2011.05608), recmo's
Goldilocks wrapper/MIT file, current Plonky3 release and known GPU/cache
sources inspected. Exact license/date/commit scope and access failures saved;
no external implementation executed or claimed benchmark reproduced.

New target proofs/passes/positions **0/0/0**, device none. Steady/total target
rates, startup fraction and witness/proof/serialization/verification clocks
unmeasured. No prefill, resident-pass series or decode ran. Larger workloads
remain allowed; longer context can increase attention quadratically. No mask
or opening reuse/privacy weakening. Complete private8B >=50provedtokens/s on
5090/namedhigh-endGPU remains unchanged and unachieved. Carried owner clocks
are separate in `target-accounting.json` and `latest-owner-clocks.json`.
