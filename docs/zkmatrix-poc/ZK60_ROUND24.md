# Round 24 — Opus review dispatch and conditional endpoint sampling

2026-09-09. P1 hides inputs, outputs and intermediate activations; P3 also
hides weights. These requirements remain unchanged. **Full privacy acceptance
remains open.** No production Rust, transcript or receipt format changed.

## Dispatch and interruption check

`5f30c9d` publishes three new [Claude Opus reviews](ZK60_OPUS_QUEUE.md):
O9 covers the endpoint security experiment, O10 the one-oracle bookkeeping,
and O11 the repeated joint model. All three are ready; this records a handoff,
not an assertion that an external agent has started. Their review baseline is
`c5eb2019353fdf56f1a115edb0c424bf86a9c195`. O8 is delivered and integrated;
its stale machine-readable `ready` status has been corrected.

Round 23's completion marker, all seven successful stages and all 28 recorded
source/tool/result/log hashes were rechecked. That round was complete and
pushed. The new validation records this audit before running its stages.

## The concrete new component

`scripts/zk60_endpoint_fibre.py` samples **auxiliary message-mask and pad
preimages conditional on an already supplied endpoint field view**, for chosen
dummy data. It is a step toward the joint field-view sampler. The public view
remains an input, and A/H/W/CFS are not sampled here.

For each seven-row endpoint it keeps all of the following exactly fixed:

- The full group and proximity vectors, including their 256 message and 256
  pad coordinates in Fp2.
- The individual masked terminal. There is one claim in the endpoint group;
  the tool checks its nonzero batching scalar and the terminal equation.
- All seven base-field values at every one of the 256 sampled column positions.
  Repeated positions are included; conflicting duplicates are refused.

The first two message rows are a chosen dummy plane. The remaining five rows
are sampled conditionally. Both proofs of a mode use the same chosen plane
for a given endpoint role, with independent draws of masks and pads. This
checks shared endpoint data across fresh owners. **It does not also sample A's
aliased X/z16 rows** or import a full FFN witness relation.

The experiment uses two choices, zero data and a fixed nonzero diagnostic
plane, for each of eight captured endpoint owners. These are simulator/test
data, not recovered real inputs or outputs. Only public capture/receipt/policy
artifacts and source-bound evidence are read.

## Conditional sampling argument

This is an algebraic argument under independent uniform base-field randomness,
with coefficients and sample positions fixed. It does not cover the actual
adaptive transcript or establish the production PRG distribution.

Split the group/proximity folds into base-field coordinates. Their matrix B
has four rows and seven columns. On the five random message rows, B has rank
four in every accepted case. At each message coordinate, fix the two chosen
data words and one free random-mask word; row reduction determines the four
pivot-mask words. Thus the message fibre has 256 free coordinates, sampled
through a bijection.

For pads, B has rank four on all seven rows. Choose its three free row
polynomials g_r(X); four pivot polynomials are then determined coefficient by
coefficient by the supplied pad-fold vectors. Each distinct sampled x requires

```
g_r(x) = (opened_column_r(x) - IDFT(message_r)(x)) / (x^256 - 1).
```

The sample coset misses the message subgroup, so the denominator is nonzero.
For q distinct positions, sample a degree-below-256 polynomial with those
evaluations as L(X) + V(X) h(X). Here L interpolates the prescribed values,
V is the product of (X-x) over those nodes, and h is uniform of degree below
256-q. This is a bijection, giving 3(256-q) free pad coordinates.

The public fold/column equations ensure that the four pivot rows' columns
also agree once the three free rows do. Each message choice therefore has the
same number of pad completions. Together the stages sample the uniform
conditional fibre in this ideal field model. After sampling, the tool checks
every full vector, individual terminal and complete row encoding independently
of the solver's pivots. Inconsistent observations or deficient rank refuse.

This executable component goes beyond a single kernel direction. It does not
generate public observations in their joint distribution with challenges,
commitments or the FFN witness relation.

## Connection to the ideal-oracle preparation candidate

Eight simulator-owned roots are created before field views enter the sampler.
The resulting encodings reproduce the supplied columns, which feed round 23's
unchanged `PreparedSimulation.open_once`. All 2,048 paths verify against those
earlier roots. Duplicates account for only 1,933 distinct programmed salted-leaf
inputs. Every oracle answer present after preparation remains unchanged.

These are **new hypothetical roots**. The captured roots and Fiat–Shamir
transcript are not reproduced; no native receipt is generated. Fixed captured
observations are not claimed to have the right distribution under the new
roots. The result explicitly marks public-field-view generation, full A/endpoint
alias sampling, external-root simulation, actual BLAKE3 programming and full
privacy acceptance as false.

## Validation and evidence

`results/zk60_round24_validation.json` records five successful stages, commands,
exits, log/tool/source/result hashes, an 8 GiB address limit and two-thread
settings. `results/zk60_round24_evidence/validation.done` is `0`.

- **47 Python tests, zero skips:** 31 IO regressions, eight existing oracle
  controls and eight new sampler tests. Independent small fixtures compute
  columns from IDFT plus the pad polynomial. Controls alter terminals, vectors,
  columns, claim weights, masks, pads, duplicates and field words.
- **51 preflight checks:** four unchanged round-22 capture triplets, two P1 and
  two P3, from producer `1f0ff3680c4cda88f1744343e24eb93cdddfcba4`.
- **16 conditional samples:** both data choices pass every field equation for
  eight endpoints. Distinct columns range from 236 to 248; message freedom is
  256 coordinates and pad freedom ranges from 24 to 60 per sample.
- **2,048 ideal-oracle paths** and **native freeze-check** pass. Full Rust and
  repository-wide Python suites were not rerun. Production hashes match the
  previously validated source. Stage durations are diagnostics, not benchmarks.

The first detached launch inside the isolated sandbox produced no validation
output. The bounded runner was rerun outside that sandbox and all stages
completed. The empty initial log/PID record is retained with a launch note;
the final report and `.done` marker identify the completed run.

Rerun the CLI using the retained capture directory/manifest and a **new** output
path; evidence cannot be overwritten. Draws and oracle roots are fresh on each
run. Result hashes identify in-memory diagnostic samples, whose auxiliary
coefficients are not archived; byte-identical regeneration is not promised.
No real witness randomness is exposed.

## Remaining work

Codex must generate the public field view jointly with A/H/W/CFS, preserve
cross-commitment aliases, and compose it with the adaptive challenge schedule.
Both [endpoint experiments](ZK60_ENDPOINT_SIMULATION_MODEL.md) remain to be
justified, especially arbitrary caller-fixed roots. Production randomness/field
reduction and arbitrary repeated requests remain outside this result.
O9–O11 independently review these boundaries; passing their checks alone cannot
close privacy. Private attention and a tiny complete P1 block follow the
privacy construction; P3 private identity and weight privacy remain required.
