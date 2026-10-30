# Finite-field range transfer and cumulative evidence — cycle 0134

Run `20261029T035649Z-8ea509dd`, 2026-10-29 UTC. **No native proving
improvement found.** This is a bounded prerequisite/negative experiment for
the September semantic-debloater lead. No author implementation or theorem
was reproduced. No native check, relation, transcript or privacy rule changed.

The concrete question is whether a range check can be inferred from other
checks before removing its proof work. Baseline: retain every constraint C.
Candidate: remove R only if C\R entails R, with independently valid modular
transfer rules and cumulative, acyclic evidence. The current source has no
R1CS/PLONKish adapter for the external tool, and no removable native check
has been identified. Expected native impact is therefore unknown.

`candidate.py` implements a deliberately weak negative-control rule, a
conservative guarded rule, and path-local acyclic proof search. `reference.py`
independently enumerates field solutions and complete accepted-witness sets,
and computes graph provability by a least fixed point. It imports no candidate
code. All values are synthetic; no trained weights, activations or tokens.

For `a*b+c=0 mod p`, a sign-known nonzero divisor and an inferred interval
inside the signed window do not suffice to justify integer division. At
Goldilocks p=18,446,744,069,414,584,321, choose
`a=9,223,372,034,707,292,160`, `b=2`, `c=1`, with the premise `c in [1, 2]`.
The field equation holds since `2a+1=p`. Integer interval division infers
the nonempty interval `a in [-1,-1]`, excluding that valid field solution.
This refutes the weak interpretation used by the negative control. The
paper states a stronger uniqueness obligation; this is **not a demonstrated
bug in its implementation**, whose artifact could not be fetched.

The conservative rule requires an independently established A for a and
checks that the full product interval A*B stays in the signed window W.
Then both a*b and -c lie in the same p-wide representative window, so
congruence implies integer equality. If the guard fails, retain A unchanged.
In particular, an unknown a represented by all of W cannot be narrowed
from b=2 and c in [1, 2]. Using the proposed conclusion as its own A would
be circular. This guard is sufficient, deliberately incomplete, and tested
only on scalar base-field relations; Fp2 helpers/challenges have no such
ordered interval interpretation.

The provenance control uses x=y with separate range checks on x and y.
Each range check is individually redundant. Removing both using separate
original-system proofs enlarges the accepted set; cumulative rechecking
keeps one. Exhaustive field assignments include coordinated changes to both
variables, which an equality-sensitive single-cell mutation can miss.
A separate domain-dominance control shows that retaining a wider range
instead of a narrower range on the same variable changes the relation.
This is our synthetic control, not an allegation about the current CLAP tool.

Final command: `python3 experiments/finite-field-provenance-20261029/run.py`.
Result: **135,613 checks**, 0.231862 s, 16,308 KiB maximum RSS. Seed
202610290134. All 25,327 interval triples over F5/F7 were exhausted;
1,354 singleton divisor/c pairs and 640 random interval cases covered
F7/F11/F17/F31; zero-divisor and positive-refinement controls also ran.
There are 972 counterexamples to the weak singleton rule, 15,845 solutions
checked in the random interval cases, 24 complete relation comparisons,
180 fact graphs / 3,600 graph queries, and 6,056 nested range pairs.
These are checking counts, not native tests or proof positions. The 348
extra-witness instances repeat across distinct fields, bounds and orderings.

One CPU 0 worker, nice 19, Intel Core Ultra9 185H / Python 3.10.12 / WSL2.
CPU cap40 s, alarm45 s, address-space cap256 MiB, estimated memory64 MiB.
No GPU or native build. `audit.py` passes 186 source/provenance checks in
0.008393 s / 20,844 KiB. Four current native pins and all eight prior pins
match. Its initial wrong SC_SZC_DD label assumption and correction are
retained in `audit-initial-failure.json`; it was an audit error.

Actual seam for a future offline audit: `private_block/argument.rs::define`,
SC_DZC's c0/c1 and c6/c7, `lk_tables`, SC_LZC, SC_SZC and SC_DD; alongside
`witness.rs::rms_norm`, `Shape` windows and canonical `zkp-core::field`.
The scalar counterexample is not a forgery of this complete native relation:
the native range/lookups and all other constraints remain. Host refusal
order, pad support, table keys, grouped claim hosting, helper multiplicity,
base/extension provenance and all profile bindings must be preserved.
Independent native receipt verification and security/privacy review remain
necessary even after a relation-equivalence argument. No patch is proposed.

Potential eliminated work is only genuinely entailed range/bit/lookup work.
Added costs include static analysis, checked certificates, a native relation
IR, possible new layout/profile/transcript and full review. Let T be measured
complete workload time, C removable exclusive critical-path time and A added
overhead. Ceiling: N/(T-C+A); free-deletion bound N/(T-C). C and A are unknown,
and logical check counts do not estimate either. Falsify on one added or lost
witness/refusal, a modular/circular/unsupported rule, missing native redundant
work, changed privacy/binding, or no enclosing gain after added costs.

Nine primary LIVE records were appended to `sources.jsonl`, 873 to 882.
The exact Figshare download failed with Cache miss; CLAP license/history
and ICICLE metadata requests also have qualified blockers. See
`sources-cycle.json` for dates, URLs, license scope and the inspected ICICLE
commit. No external code executed or author performance reproduced.

Top priorities remain whole-prover GPU/resident complete workloads, DD/fidelity
context scaling, and complete exclusive phase/capacity clocks. Hypothesis51
is refined by this result; all 51 prior hypotheses are preserved. Next local
rotation: GPU NTT/commitments. First inspect native coset/ordering/batch strides
and hiding-pad lifetime before a tiny exact-field layout oracle; reuse prior
NTT-gather findings and do not rerun their existing census unchanged.

New verified full-stack proofs/passes/positions: 0 / 0 / 0; model context and
accelerator: none. Witness/proof/serialization/verification/startup/prefill,
startup fraction, steady-state/total rates and proof latency/bytes are all
unmeasured. No long prefill, resident-model pass series or decode. Larger
workloads remain allowed, with quadratic attention costs disclosed. The
complete private 8B >=50 proved-token/s target remains unachieved.
