# D zero-check affine aggregation — cycle 0074

Run `20261018T032105Z-8464ee28`, 2026-10-18 UTC. Synthetic CPU experiment;
**no native proving speedup, complete proof, GPU run or privacy acceptance**.

The captured `private_block/argument.rs::SC_DZC` has eleven batched clauses.
Their weighted sum is an affine form plus four weighted bilinear products:
`gamma_a*x`, `d*y`, `gamma_m*x1`, `dm*ym`. `candidate.py::prepare` constructs
the public coefficients after the proof's `mu` challenges. `linear` builds
one proof-local table; `combined` reads its folded value and evaluates the
four products. Helpers, padding, support gates and hosts remain the original
relations. An affine constant is included at every table entry and survives
folding. A whole-clause precomputed table is invalid off cube.

`clauses.rs.inc` is the exact current native Rust clause body, including
existing base-constant specialization and two shared norm subproducts.
Only the unused support read and comments between the clause construction
and batch are omitted. `shim.rs` supplies exact u128 modular substitutes;
this tests the Rust expression, not native field/PTX primitives. Eight native
source snapshots and hashes are in `source-pins.json`. No foreign source ran.

From this directory's parent research root:

```bash
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 python3 experiments/dzc-affine-aggregate-20261018/run.py
OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 python3 experiments/dzc-affine-aggregate-20261018/audit.py
python3 experiments/dzc-affine-aggregate-20261018/cost_audit.py
```

Each command pins CPU0, nice19, 59s CPU/alarm and 512MiB address space.
The first compiles only the tiny local shim with one codegen unit, no Cargo
or dependencies. Main seed2026101874, independent audit2026101875. Hardware:
one Intel Core Ultra9 185H CPU thread, WSL2; no GPU. Observed main3.024s,
RSS18,296KiB/compiler122,356KiB; audit0.499s/RSS16,104KiB; cost0.0006s.
These clocks describe the test harness, not proving speed.

Main passes96 fixtures: N2/4/16/64, support on/off, generic/base original
sources, 1/2/9 synthetic lookup descriptors, four/five norm limbs. Four is
the current trained case; five tests generic indexing and is **not** a
registered trained-shape claim. Bindings use toy A ids with synthetic extra
limbs; they are not the actual trained B/Ids map. 9,840 captured-clause and
9,840 enclosing polynomial comparisons, 1,968 folded-linear values, 6,240
direct-cube terminal values, 1,032 base constructor values and48 complete
base-contract corruption refusals pass. Eight negative/control checks and
two invariants pass. Independent24-fixture audit obtains1,536 linear and96
bilinear coefficients by native basis probes, then checks396 complete round
sums at unchanged declared degree4/5,24 native terminal values,24 fifth
differences and seven corruptions. No protocol/masking RNG was executed.

Four-limb native clause APIs per point:39add+15sub+15Fp2mul+23mul_base.
Candidate online:5add+8Fp2mul. Prepare9add+20sub+26mul_base; construction
33 general Fp2 products (or33 mixed products for completely base sources)
and34add per entry; all N-1 added folds are charged. Added capacity16N bytes
plus608B coefficients/constants/products. Original tables/finals/folds remain.
Construction reads33N sources; their actual representation, residency and
coalescing matter. Fold traffic48(N-1) and round reads32(N-1) are logical
counts, not DRAM measurements or measured peak-memory growth.

`cost-result.json` follows native `ClosureRounds`: interpolation advances by
additions; host slot14 has no known first claim; later release rounds recover
s(1). E=D(N-1)+N/2 with unknown initial claim, or D(N-1) with known claim.
The registered padded schedule retains D5, unpadded D4. No degree change is
proposed. Debug still evaluates s(1). `result.json` deliberately retains an
earlier conservative extra5-scalar-product/E interpolation charge; use the
separate source-refined cost file for the native step schedule.

At N2/D4/generic, native none-claim scalar counts605->587; known-claim484->547
**loses63**. Earlier conservative none-claim count605->612 loses7. At counted
N2^19/D4/unknown initial claim/four limbs:285,474,332->183,500,687 generic,
or131,596,175 with base construction. Extra8MiB table; at2^21 extra32MiB.
Rust Fp2 products are modeled as5 scalar products, mul_base as2; this is
not CUDA's Karatsuba/PTX instruction count, a speed factor or whole-slot cost.

The full D phase in the inherited 1.1B T128 default run was26.691/174.052s.
Even deleting **all** D gives only1.18113x, or0.868615 diagnostic positions/s.
This candidate changes only its clause subset; 8B phase ceiling is unknown.
Latest owner round4 gates pass, but raw and materialized warm resident F
bodies are comparable, and host-upload ladders pay large H2D costs. See
`owner-metrics.json`; no new enclosing round4 stack result was captured.

Native handoff: `../../handoffs/20261018-dzc-affine-aggregate.md`. Required
next work: bind real shaped indices/catalogs, retain original finals and
extension rounds, then owner correctness/byte/privacy gates and enclosing
timings. No private masks, opening reuse, protocol or model change authorized.

Base-constructor fixture guards explicitly scan every participating imaginary
word. Counted construction bytes model a native implementation supplied with
complete typed provenance; a new standalone scan would add another source
pass and must be charged. The Python guard scan is not timed as a GPU benefit.
