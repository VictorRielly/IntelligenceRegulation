# Reusable caller-fixed endpoint roots: do repeated ordinary openings admit P1 privacy? — 2026-09-18

| | |
|---|---|
| Author | Claude Fable 5.1, isolated worktree `/tmp/wt-zk60-loop-fable-20260917`, baseline `5d6f101` with delivery `679ac26` copied in for review |
| Owns | this memo, `scripts/zk60_reusable_endpoint_probe.py`, `tests/test_zk60_reusable_endpoint_probe.py` |
| Does not | change production code, boards, P1, or any acceptance flag; run native Rust, heavy jobs, network or git mutations |
| Evidence kind | an independent linear model pinned to source (nine SHA-256 pins, 21 quoted anchors) plus ideal-oracle bookkeeping. **Model runs and checks, not a theorem, and not native coefficients** (§9 says what was blocked) |
| Scope guard | P1 hides inputs, outputs and intermediates. The caller-fixed endpoint obligation is kept. Nothing here says a fresh top-pair simulation closes arbitrary prior history; §6 shows the opposite with a control |

## 0. Bounded conclusion

1. **The actual endpoint is a one-opening object.** Two accepted ordinary
   openings of one fixed endpoint root, at independent challenges, publish
   the whole 512-word plane. The minimum observation set is **one
   `F_{p²}` word from each opening per coordinate pair**: entry `k` of the
   two group vectors, plus the public challenges `(λ, e, ρ₀)` of each. No
   column, salt, Merkle node or pad entry is needed. With the int16 range,
   three base-field words already pin a pair. Demonstrated on a synthetic
   endpoint at the real geometry: 512 of 512 words recovered (§3).
2. **For that protocol no simulator of a second opening exists, in any hash
   model.** The recovery map ignores the hash layer, so programming cannot
   help (§4). This is an impossibility for *this protocol under reuse*. The
   consuming owner (`into_ffn_endpoint(self)`, `finish(mut self, …)`) is
   therefore load-bearing for privacy, not only API hygiene.
3. **The defect is a budget, not the idea of a fixed root.** Per coordinate
   the owner holds 5 mask words; one opening publishes 4 base equations, two
   publish 8 against 7 unknowns. A layout with one terminal pair, one
   proximity pair and `checks` pads **per use** discloses 0 through use `k`
   and discloses at use `k + 1` (complete field system, small geometry, §5).
   So *bounded* reuse is algebraically available at cost linear in `k`;
   *unbounded* reuse is impossible for every fixed root opened by ordinary
   clear-vector/clear-column openings, because the published words eventually
   outnumber the owner's words (§4.3; the column half of this was already
   counted for cached weights in `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md:140-157`).
4. **Not impossible for all constructions.** An endpoint that is never opened
   (an opaque hiding commitment whose use is proved inside an established ZK
   argument) has no budget. That is the smallest redesign that keeps
   caller-fixed hidden endpoints *and* reuse (§7).
5. **A stateful simulator for the bounded case is supplied** (§6): it keeps
   every previously authenticated node and path, serves new positions only
   below the public frontier, samples its field state from the fibre of the
   prior field observations, mirrors the use budget by refusing, and never
   gives a public node a second observed preimage. Assumptions and the
   refusal bound are explicit. It is bookkeeping plus a sketch; the universal
   rank premise and the rest-of-proof composition stay open.
6. **Handoff** (§8): adopt the one-time-handle rule now; confirm the recovery
   natively with one test-only Rust case (T-REUSE-1); use opaque endpoints
   for anything that must be shared between separately verified receipts.

## 1. What the source does (traced, not assumed)

| Fact | Source |
|---|---|
| Statement carries two caller-supplied roots, `rows = 7`, `log_cols = 8`; the verifier never learns who made them | `hashline/src/zk_ffn_fresh_io.rs:55` `ExpectedIo::from_roots`, absorbed at `transcript()` before any challenge |
| An endpoint is 2 data rows (512 words) + `MASK_ROWS = 5` uniform rows; `mask_rows = [2, 3]`, `prox_mask_row = 4`; fresh OS entropy per call | `hashline/src/private_seam.rs:36`, `:196`, `:200-217` |
| Row encoding `f = f_data + (xⁿ − 1)·g_pad` evaluated on the coset `7·G_2048`; `Q = num_col_checks = 256` pads per row, drawn once at commit | `zkp-core/src/pcs.rs:542` `ZkOpts::standard`, `:618` `encode_row_zk`, `:673` |
| One 32-byte salt per encoded column, drawn once at commit; leaf `= BLAKE3(BLAKE3(column) ‖ salt)`; nodes `= BLAKE3(l ‖ r)`, same untagged 64-byte shape | `pcs.rs:674`, `:640` `salt_leaf`; `zkp-core/src/merkle.rs:14` |
| The endpoint claim is `(1−e)·data(ρ) + e·(row2 + U·row3)(tail)` | `zk_ffn_fresh_io.rs:204` `claim`, used at `:346` |
| An opening publishes `ρᵀ[M ‖ pads]` for the claim group (512 `F_{p²}` words), the same for a uniform proximity `ρ` over all 7 rows, and 256 positions **sampled with replacement**, each with all 7 column words, its salt and its 11-node path | `pcs.rs:915` `open_zk`, `fold_rows_multi_zk`; `zkp-core/src/transcript.rs:119` |
| Refusals: `λ = 0`, `e = 0`, dependent proximity coefficients on rows 4, 5 | `zk_ffn_fresh_io.rs:360`, `hashline/src/zk_ffn_fresh_poc.rs` `check_masks` / `check_opening_challenges` |
| Lifecycle: `PreparedPlane` has no `Clone`, getter or serializer; `into_ffn_endpoint(self)` moves it into the single `finish(mut self, endpoints)`, which consumes on success **and** failure; one `open_zk` per endpoint | `private_seam.rs:156`, `zk_ffn_fresh_io.rs:258-276`, `:361` |

Nothing in the masks, pads or salts is per-opening: all of it is fixed at
commit time. A second opening of the same root therefore reuses the same two
terminal rows, the same proximity rows, the same pads and the same tree. The
Rust API cannot produce that second opening; the *statement* `from_roots`
does not know whether a root was opened before. Prior work excluded "reused
commitment owners" from every rank model (`ZK60_OPUS_REPEATED_VIEW_REVIEW.md`
§5) and O9 F1 recorded that the API cannot reuse a root. Nobody had computed
what reuse would publish. This memo does.

## 2. The algebra, and the minimum observation set

The group vector's message half is coordinate-wise. With
`x = (x[k], x[256+k])` the two data words in column `k`, and
`m = row2[k] + U·row3[k]` the one `F_{p²}` terminal mask word there,

```
v[k] = λ·(1−e)·((1−ρ₀)·x[k] + ρ₀·x[256+k]) + λ·e·m          (one opening)
```

`m` is uniform and used once, so one opening hides `x` perfectly in this
channel. Two openings share `m`:

```
λ₂e₂·v₁[k] − λ₁e₁·v₂[k] = c₀·x[k] + c₁·x[256+k],   c₀, c₁ ∈ F_{p²} public
```

one `F_{p²}` equation, i.e. two base equations in two base unknowns, uniquely
solvable unless `c₀/c₁ ∈ F_p` (probability about `1/p` over the challenges).
Equivalently: 4 base equations in the 4 unknowns `(x[k], x[256+k], row2[k],
row3[k])`.

**Minimum public observation set for a fixed root** (linear): `{v₁[k], v₂[k]}`
and the two challenge triples. It is minimal in both directions: a single
opening discloses 0 (per coordinate here; for the complete view including
columns this is the retained joint-view result "Input 0, Output 0", and the
small-geometry complete system of §5); and with fewer than 4 base words the
linear system is underdetermined. With bounded data the linear count is not
the floor: `Re v₁[k], Im v₁[k], Re v₂[k]` leave one equation
`x[k] + β·x[256+k] = γ (mod p)`, and the int16 box has `2³²` points against
`p ≈ 2⁶⁴`, so the pair is unique with overwhelming probability.

Two further channels exhaust independently, so repairing the terminal mask
alone would not be enough:

- **Proximity vector**: 2 base equations per opening against 5 mask words per
  coordinate; alone it discloses 1 data functional per coordinate at three
  openings and both at four. Together with the group vector, two openings give
  8 equations in 7 unknowns.
- **Columns**: `n + Q = 512` unknowns per row; with-replacement sampling gives
  an expected `2048·(1 − e^{−256t/2048})` distinct positions, about 453 after
  two openings (already past the 256-pad budget; by the counting of
  `U_PERF3_ROUTE_B_WEIGHT_PRIVACY.md` about 197 functionals of every row, not
  separately measured here) and about 640 after three, when every row
  polynomial is interpolated outright.

## 3. Demonstration (model at the real geometry)

`scripts/zk60_reusable_endpoint_probe.py::full_geometry_demo`, seed 20260918:
a synthetic int16 endpoint at 7 × (256 + 256), encoded to 2048 positions
exactly as `encode_row_zk`; challenges uniform with the source refusals
mirrored; positions derived adaptively from the published vectors (SHA-256
stands in for the transcript); both openings pass the field half of
`verify_zk` (claim inner product and every column against both clear
vectors), and tampered vectors/columns are rejected.

| Attack | Public input used | Result |
|---|---|---|
| two group vectors | 2 × 256 `F_{p²}` words (message halves only) + challenges | **512 / 512 words recovered** |
| three base words + int16 range | 3 base words per pair | exactly 1 candidate, the true pair (checked at `k = 0, 17, 255`) |
| columns only | 3 openings, 639 distinct positions ≥ 512 | **512 / 512 recovered** by interpolation |
| per-coordinate clear-vector disclosure | challenges only | 0 after one opening, 2 (all) after two; group vector alone: 2 after two |

The model's encoder is checked against direct polynomial evaluation and
against `zk60_io_opening_translation.pcs_poly/coset_evals`, the round-20
translation that was validated on four native captures. That ties the model to
native values indirectly. It is still a model: **no native opening was produced
twice**, because the API forbids it and no Rust was run here. T-REUSE-1 (§8)
closes that gap in test-only code.

## 4. Scope of the impossibility

### 4.1 The actual endpoint, second opening: no simulator

Let `E` be the public recovery map of §2. In the real world
`E(view₁, view₂) = x` except with probability about `1/p`. A simulator for the
second proof receives the statement, the root and the public history `view₁`,
not `x`. `E(view₁, view₂′)` is then a function of values that are independent
of `x` up to the hiding of `(root, view₁)`. Either that hiding already fails
(then P1 is broken after one proof) or `E(view₁, view₂′) ≠ x` with probability
about 1/2 for `x` drawn from two candidates, and the distinguisher "does `E`
return the witness?" wins. `E` never reads a hash, so no random-oracle
programming, stateful or not, changes this. Executable form:
`SourceProtocolHasNoSecondUseSimulator` builds the best available forgery (an
owner sampled from the fibre of `view₁` with dummy data, whose second opening
verifies) and shows `E` returns the dummy, and that **no** owner holding the
real data explains the forged joint view.

Consequence for the external-root game on the actual endpoint: "arbitrary
prior public history" for a root is either empty or a spent root. For a spent
root the honest owner is gone and the only behaviour both worlds can share is
refusal. So the game needs the root's public history as an input (to know
which case it is in), and the fresh top-pair simulator is legitimate only in
the empty case. That is a statement about where it applies, not a closure of
prior history; §6's control shows it distinguished after one public path, in
agreement with the parent's three regression tests
(`tests/test_zk60_root_history_boundary.py`, re-run here: 3 pass).

### 4.2 What is *not* claimed impossible

- A fixed root with a **declared use budget `k`** and per-use masks/pads (§5).
- A fixed endpoint commitment that is **never opened**, used inside an
  established ZK argument (§7, R-A).
- Fresh roots over shared data (the fresh-owner game of
  `ZK60_ENDPOINT_SIMULATION_MODEL.md`), which the repeated-view work covers.

### 4.3 Unbounded reuse of an ordinarily opened fixed root: impossible by counting

An owner of `rows × (n + Q)` base words is fixed at commit time. Each accepted
ordinary opening publishes, at fresh challenges, `4(n + Q)` base equations
from the two clear vectors and up to `checks` new positions of every row.
Privacy of the data needs the mask rows to absorb the vector equations
(`≥ 4` mask words per coordinate per use) and the pads to cover every
distinct opened position (`Q ≥` total distinct positions). Both are finite,
so some `t` exhausts them for any parameters; the horizon `(n + Q)/Q`-style
count was already recorded for cached weights. "Reusable without a bound" and
"ordinary openings of one root" are incompatible. This is a counting argument
about this *class*, not about commit-and-prove in general.

## 5. The budget, measured

`budget_table` builds the **complete** field system (both clear vectors and
all opened columns, every owner word an unknown) on a small geometry
(`n = 4`, 4 checks, 32 positions) and reports
`rank(A) − rank(A without the data columns)`:

| Layout | rows | pads/row | after 1 | after 2 | after 3 |
|---|---|---|---|---|---|
| source shape (1 terminal pair, prox pair, spare) | 7 | 4 | **0** | **8 / 8** | 8 / 8 |
| budget 2 (2 terminal pairs, 2 prox pairs, no spare, pads = 2 × checks) | 10 | 8 | **0** | **0** | **8 / 8** |

Sharing one terminal pair between two uses inside the budget-2 layout still
discloses (control). So the requirement is per use: its own terminal pair, its
own proximity pair, and `checks` more pads per row. These are sampled-challenge
rank computations at one small geometry; they indicate the budget rule and do
not prove it for every non-refused challenge vector.

Cost at the real endpoint geometry (`cost_table`; bytes by the
`ENDPOINT_OPEN_BYTES` formula):

| uses | rows | pads/row | `n + Q` of 2048 | rate | bytes per opening | owner words |
|---|---|---|---|---|---|---|
| 1 (source) | 7 | 256 | 512 | 1/4 | 131,072 | 3,584 |
| 2 | 10 | 512 | 768 | 3/8 | 145,408 | 7,680 |
| 3 | 14 | 768 | 1024 | 1/2 | 161,792 | 14,336 |

Performance implications: commit work scales with `rows` (×10/7 at `k = 2`);
the rate rises from 1/4 to 3/8, so the proximity-test parameters of
`SOUNDNESS_REFERENCE.md` must be re-derived, or the code lengthened to 4096
positions (depth 12: +8,192 path bytes per opening, 2× encode). At production
row widths (`n ≥ 2¹⁴`) 256 extra pads per use are under 2% of a row, so the
budget is cheap at scale and expensive only at toy width. New hazards that the
move-consumed one-shot owner does not have: a **durable use counter** written
before anything is published (a crash-and-retry that reuses a pair is total
disclosure, per the control), a use index in the statement, and failed
attempts that burn a use.

## 6. Stateful frontier simulator for a k-use caller-fixed root

`FrontierSimulator(layout, oracle, root, history, dummy, rng)`; inputs are the
public statement, the root, and the root's **complete public history** (every
accepted opening already published for it). It never receives endpoint data,
masks, pads or unopened salts.

- **Hash layer.** Every node authenticated by a historic path (on-path nodes
  and siblings) is kept. A new position `j` is served under its lowest
  already-authenticated ancestor `N`. Because history consists of complete
  paths, nothing below `N` is public. The simulator builds its own subtree
  below `N` with ordinary oracle queries over its virtual owner's columns and
  fresh salts, and programs exactly one point, `children(N) ↦ N` (the salted
  leaf itself when `N` is a leaf known only as a sibling). Nodes whose
  children are public are never programmed. Subtrees are state: later uses are
  served from them with no new programming. A repeated position returns the
  identical column, salt and path.
- **Field layer, jointly with prior observations.** One virtual owner holding
  statement-valid dummy data is sampled uniformly from the fibre of *all prior
  field words* (both vectors and every opened column of every historic use),
  then answers exactly as the honest owner, adaptively. Prior and new vectors
  and columns are therefore jointly consistent by construction, and historic
  columns are reproduced exactly.
- **Refusals.** (i) no unspent use: the mirror of the consumed owner, a
  deterministic public function of the history, identical in both worlds;
  (ii) history that does not verify, or that no owner with dummy data explains
  (a root already outside its zero-disclosure budget); (iii) a programmed
  input that was already answered: at most one programmed point per new
  distinct position, so at most `checks·q / 2²⁵⁶` per endpoint use after `q`
  prior oracle answers (each programmed input contains a fresh 256-bit salt,
  or digests of inputs that do); (iv) the source's public challenge refusals
  (`λ = 0`, `e = 0`, dependent proximity pair), about `2⁻⁶⁴` per use,
  mirrored and identical in both worlds.

What the checks show (`FrontierSimulation`, small budget-2 geometry, one real
historic use then a simulated second use): the simulated opening verifies
under the caller's root including all paths; 3 new positions, 3 programmed
points; repeated positions are byte-identical; **every digest the observer has
seen has exactly one observed preimage**; the joint two-use field view has
disclosed dimension 0 and is explained by an owner holding the *real* data and
by one holding other data; a third use is refused in both worlds; empty
history degenerates to one programmed top pair and then pure state; and the
**control** (fresh tree, top pair programmed to the root after one public use)
verifies yet shows the root with two observed preimages.

Explicit assumptions, none discharged here:

- A1. Programmable random oracle, one table for all untagged 64-byte inputs
  (as in the source). Real BLAKE3 cannot be programmed; this is reduction
  bookkeeping and produces no real receipt.
- A2. **Complete public history is an input.** A missing historic opening
  reintroduces the parent's distinguisher. Operationally this is a
  root-indexed use ledger or a use index in the statement.
- A3. Unopened salts are uniform 256-bit and never published; the keyed-BLAKE3
  stream is a PRG. Then every hidden input below the frontier is unqueried
  except with probability at most about `q·2·nn / 2²⁵⁶` (sketch, union bound).
- A4. **Budget premise**: for every non-refused challenge vector of `≤ k`
  uses, the complete field system discloses 0. Checked at sampled challenges
  on one small geometry, and per coordinate for the clear vectors at the real
  geometry. The universal statement is the existing U-3 obligation extended to
  `k` uses; it is not established.
- A5. The rest of each proof (A/H/W/M, CFS rounds, terminals) is produced by
  the honest prover on the dummy witness. Every open item of
  `ZK60_JOINT_VIEW_REVIEW_20260918.md` (universal challenge premise, CFS
  terminal linkage, hash objects joint with field objects) is inherited
  unchanged.
- A6. Adaptive composition across uses needs the sequential-kernel hypothesis
  for the concatenated challenge vector of all uses, since endpoint randomness
  is shared across them.
- A7. Honest owner only: durable counter, no exported secrets, no second
  opening at a used index.

For the actual `k = 1` endpoint this simulator reduces to: empty history, one
programmed top pair per endpoint; any history, refuse.

## 7. Smallest redesigns that keep caller-fixed hidden endpoints

- **R-0, rule only, no protocol change (adopt now).** An endpoint root is a
  one-time handle: at most one accepted receipt may ever name it; the
  external-root game is defined with the root's public history as input and
  refuses a spent root. Components that share a plane do so inside one
  transcript through reserved pair rows and internal seams, as the private
  attention construction (A4) already plans. No reuse is offered.
- **R-A, opaque endpoint inside an established ZK argument (recommended
  whenever a hidden endpoint must be shared between separately verified
  receipts or reused without bound).** The caller-fixed object becomes a
  hiding commitment that no proof ever opens; the simulator receives the
  statement only; prior history is irrelevant because nothing about the
  commitment is ever published again. This is the statement already fixed in
  `ZK60_ZKVM_CONSTRUCTION_REVIEW.md` (§2, §8; chain step Z6). It is a new,
  separately versioned statement format and does not certify old PCS roots.
  Performance: that memo's [MODEL] figures stand (tiny block 2–6 M guest
  cycles; 8B infeasible by re-execution). A hybrid that keeps the custom
  prover and proves only "opaque handle and this fresh one-shot PCS root hold
  the same plane" in the general argument would cost, per 7-row endpoint,
  about 6.1 k BLAKE3 compressions (2 per leaf × 2048 + 2047 nodes) plus seven
  2048-point Goldilocks NTTs in 32-bit software: order 10⁷ cycles [MODEL,
  unmeasured], i.e. more than re-executing the tiny block, and it would still
  inherit every open custom-simulator obligation for the one-shot root. It
  only pays if the custom line's privacy argument closes and endpoints are
  small relative to the computation.
- **R-B, k-use budgeted PCS endpoint (research alternative).** §5 layout, §6
  simulator, a use index in the statement, a durable counter. Bounded reuse
  only, `k` fixed at commit time, all custom-line obligations inherited plus
  A2, A4, A6, A7. Two uses would cover a producer/consumer chain of separately
  verified receipts; it cannot cover a plane read by every later token.

## 8. Handoff

**Concrete next implementation task — T-REUSE-1 (Codex, test-only Rust, no
format or API change).** In the `#[cfg(test)]` module of
`hashline/src/zk_ffn_fresh_io_tests.rs` (crate-private access to
`prepare_endpoints`, `into_ffn_endpoint`, `claim`, `pcs::open_zk`): prepare one
endpoint over a fixed int16 plane; build two claims `claim(0, 2, ρ, e, value)`
at two independent transcripts, with `value` computed from the owner; call
`pcs::open_zk` twice on the *same* `CommittedZk`; assert both pass
`pcs::verify_zk` under the one root; solve the 4 × 4 base system of §2 per
column from `group_vecs[0][..256]` of the two openings; assert all 512 words
equal the plane. Expected: passes. It converts §3 from [MODEL] to [NATIVE] and
stays as the regression that explains why the owner must be consumed. Run it
under the project's usual focused `cargo test` invocation; not run here.

Then, in order:

1. Integration owner: record R-0 in `ZK60_ENDPOINT_SIMULATION_MODEL.md`
   (one-time handle; history is a simulator input; spent root refuses; the
   top-pair programming step applies to an empty history only) and retract the
   two-point closure wording of `ZK60_MVP_JOINT_VIEW.md` §1.1, as the joint
   view review already asks.
2. Any design that shares a hidden endpoint across receipts (block chain,
   prompt or KV planes across tokens) uses R-A; do not route it through
   `from_roots` twice.
3. Only if the custom line must chain receipts: specify R-B at `k = 2`,
   re-derive the proximity parameters at rate 3/8, and extend the joint-view
   tools to two uses before any Rust.

Obligations kept, unchanged: complete-view privacy including endpoint binding
and repeated-proof behaviour; the external-root obligation; every open item of
the joint-view review; P3 weight and model-identity work. Nothing here is
privacy acceptance (`privacy_accepted: false` in the probe record).

## 9. Commands, results, and what was blocked

```
python3 -m unittest discover -s tests -p "test_zk60_reusable_endpoint_probe.py" -v
python3 -m unittest discover -s tests -p "test_zk60_root_history_boundary.py" -v
```

- Probe tests: **25 run, 25 pass, 0 skipped**, about 2 s (includes the
  cross-check against the round-20 translation, which imported and ran).
  `ExecutionRecord` pins every number quoted in §3, §5 and §6.
- Parent's root-history regression: 3 run, 3 pass, none skipped.
- Blocked (automatic denial, no approval surface): running the probe script
  directly (`python3 scripts/zk60_reusable_endpoint_probe.py`), so no results
  file was written and the record is asserted in the test instead; one
  compound shell command. Not attempted by instruction: cargo builds/tests,
  heavy jobs, network, installs, git mutations, messaging hooks. No failure
  was otherwise observed.
- Limits of the evidence: model, not native openings; rank results at sampled
  challenges; the complete-system budget table is at one small geometry; the
  ~197-functional column figure after two openings is quoted by formula, not
  measured; oracle results are bookkeeping in an ideal table, not statements
  about BLAKE3.
