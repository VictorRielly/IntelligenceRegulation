# Public mask-row incidence bound for the existing conditional kernel

Run `20261029T175649Z-b41890ba`, cycle0148. Main/Claude reviews/integrates;
no native patch applied, build or GPU job queued. No native proving gain.

The frozen R13 mask audit provides some genuine zero incidence independent
of private data: an ordinary group cannot touch another group's reserved
terminal rows or the proximity pair. H's all-ones sum touches no terminal
mask row. The prior both-limb zero-skip kernel would therefore skip at least
4.1805%/4.3946% of baseline logical A/H matrix reads on the inspected R13
8B/T128 noDD/DD geometry. Symbolic source ordering makes DD4.4470%.
This is an algebra/source operation bound, not physical bytes or time.
R14 split geometry needs its own census. Full actual native rho support
and exclusive phase materiality are still missing.

Interface/seam: `zkp-core/src/pcs.rs::fold_rows_multi_zk` supplies ordered
public Fp2 rho vectors to `EncodedStore::fold_rows` in chunks4; device
adapter `hashline/src/gpu/cuda.rs::dev_fold_rows` calls `k_fold_rows`.
Retain max4, every vector/pad, original logical order, fresh mask/challenge
schedule, source identity, refusals, FS and verifier. Prior unapplied patch:
`experiments/multi-rho-rowfold-20261029/native-public-rho-skip.patch`.
This cycle adds only research incidence evidence and a scheduling negative.

Before more scheduling code, collect verifier-reconstructible public
`rows, cols, group count, rho nonzero counts, chunk union counts` after the
accepted audit/challenge checks, without exporting private matrices or a
private-value support summary. Retain dense proximity and H sum. Bind
counts to current immutable source/profile/geometry. Fix the prior local
rho-H2D accounting omission and separate upload/allocation/kernel/download/
host pad/open/enclosing clocks. Planner time and memory belong in that
enclosing interval. No current native instrumentation patch is supplied.

Reject mask-count-only dispatch. A deterministic public synthetic support
counterexample improves its dense-data envelope3298→3218 but raises actual
row visits2274→2706(+18.997%). Full public rho support and data locality
matter. Reordering must restore every original vector before transcript
absorption; the research harness checks inverse scatter and kills omission.

Validation:81Rust fixtures plus3H-sum fixtures use unchanged extracted
native audit/group/rho helpers;405216independent complete-cube coefficients,
5049message+pad values and5049restored-order values agree. Seven audit
mutations refuse;4controlclasses repeated164times;38accounting checks pass.
Scripted synthetic challenges are not native FS; no complete proof or
external review. Probe0.0334s/7792KiB on one pinned CPU; all stages bounded.
Read `experiments/public-row-support-20261029/README.md` and pinned artifacts.

Outstanding: exact actual native support, current R14 incidence, CUDA build/
device arithmetic/ABI/races, compiled registers/spills/occupancy, physical
traffic and independently verified complete-workload A/B. Prior candidate
source temporaries double accumulator+weight payload64→128B/thread; benefit
can disappear. Use current shared heavy/build locks for later owner work
only if material. A mask/refusal/RNG/FS/order/PCS/privacy mismatch or no
enclosing verified gain falsifies promotion. No privacy acceptance implied.

Next local: exact source-derived public `build_claim` part-offset/domain
support, compared with this conservative mask-only envelope. No private data,
mask reuse, commitment reuse or weaker proof relation authorized.
