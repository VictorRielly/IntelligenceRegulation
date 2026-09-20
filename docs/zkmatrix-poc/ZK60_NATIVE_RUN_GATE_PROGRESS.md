# ZK60 — the RUN gate (Python privacy-consistency gate for a multi-block run)

**Lane** `zk60-native-jointview`, worktree `/home/victor/wt-zk60-jointview`.
**Opened** 2026-09-20 12:30 PDT. **Sole writer**: this lane's agent.
Python only — no cargo, no builds, no GPU. Nothing here is a privacy
acceptance, and no statement here establishes a privacy property.

## 0. What this lane is building

A NEW tool, `scripts/zk60_native_run_gate.py`, that reads a RUN CAPTURE
bundle (schema `hashline-native-capture/4-run`, written by the Rust lane
`zk60-private-block-125m`) and computes, for a whole multi-block run:

1. load + integrity (manifest hashes, schema, sizes against `run.json["shape"]`);
2. the Fiat-Shamir transcript replay of every stage, in run order;
3. per stage, per commitment: the disclosed dimension by exact rank, the
   certifying minor, distinct opened columns against the pad count;
4. **the boundary** (ruling M-8): per boundary, its figure RESTRICTED to its
   reserved rows; the three-role joint figure (A_k, B_k, A_{k+1}); the
   whole-run figure or the largest sub-system computed;
5. negative controls, each shown to pass honest and fail perturbed;
6. channel labels (CONSTRUCTED / DERIVED / ARGUED / OPEN) for a run;
7. evidence under `results/zk60_native_run_gate/` and the report
   `docs/zkmatrix-poc/ZK60_NATIVE_RUN_GATE.md`.

Inputs, READ-ONLY, from the lane worktree (never copied into this repo):
`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/run-a-tame/`
and `.../run-b-zero/` — two independent honest three-block runs at the
development rung (24 tokens, width 96, hidden 192, 6 q-heads over 2 kv-heads;
1024 columns, inverse rate 4, 256 opened columns).

Rule taken from the brief and kept: the four TOY bundles' gates
(`zk60_native_joint_view.py`, `zk60_native_privacy_gate.py`) and every module
they hash into their evidence are NOT edited. Shape-driven variants live in
new `zk60_native_rg_*.py` modules; shape-agnostic code
(`zk60_native_jv_field`, `JointSystem`) is imported.

## 1. Status

| # | item | state |
|---|---|---|
| S0 | ledger, skeleton, baseline test count | done |
| S1 | bundle loader + integrity (`zk60_native_rg_bundle.py`) | done |
| S2 | run transcript replay (`zk60_native_rg_replay.py`) | done |
| S3 | shape-driven per-commitment view (`zk60_native_rg_pcs.py`) | done |
| S4 | the boundary: reserved-row figure, three-role joint, run-wide | done |
| S5 | negative controls | done |
| S6 | channel labels for a run | done |
| S7 | both bundles run, evidence, report | done |
| S8 | tests green, toy gates unchanged | done |

## 2. Commands and logs

| what | command | log |
|---|---|---|
| baseline tests | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py' -v` | `results/zk60_native_run_gate/tests_baseline.log` — **161 tests, OK** (skipped 1, expected failures 1) |
| tests after | same | `results/zk60_native_run_gate/tests_after.log` — **187 tests** (161 + this lane's 26) |
| the gate, run A | `python3 scripts/zk60_native_run_gate.py --bundle <run-a-tame> --other <run-b-zero> --evidence results/zk60_native_run_gate` | `results/zk60_native_run_gate/run-a-tame.log` |
| the gate, run B | the same with the two bundles swapped | `results/zk60_native_run_gate/run-b-zero.log` |
| this lane's tests alone | `python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate.py' -v` | `results/zk60_native_run_gate/tests_run_gate.log` (26 tests, OK) |
| the two toy gates, re-run and diffed | `python3 scripts/zk60_native_joint_view.py` and `scripts/zk60_native_privacy_gate.py`, both `--captures results/zk60_native_captures_20260919`, into a scratch dir | `results/zk60_native_run_gate/toy_recheck.log`, diff in `toy_unchanged.json` |

## 3. Results (MEASURED 2026-09-20, both bundles, shared laptop, CPU only)

About 9 s per bundle. Largest exact rank: **308 x 3,761** over Goldilocks
(the whole run as one system), ~1.0 s. Slowest single step: the pad block,
247 x 256, 3.7 s. Nothing approached 4 GB or 20 minutes.

| what | figure |
|---|---|
| replay | run binding + 375 positions + **6,086** challenges re-derived; 6 segment position tags; **nothing left un-re-derived** |
| per commitment (3 stages) | `A` 0, `H` 2, endpoints 0, boundaries 0, `M` 0 — each equal to its expected value, every certifying minor nonsingular, 243..251 distinct opened columns inside 256 pads, 0 column-identity failures |
| boundary, reserved rows | rank **6 of 6**, disclosed **0**, both boundaries, both bundles |
| three roles of a boundary plane | joint **0** = sum of parts; non-data block diagonal; a theorem here, and computed anyway |
| whole run | 308 x 3,761: joint **6** = sum of parts (three copies of `H`'s public LogUp identity) |
| zero-data preimage | message half exhibited and verified for `B0`, `B1`, `E-Input`, `E-Output`; `A`/`H` skipped, not faked |
| controls | six, all fire: shared pair **rank 4, disclosed 2**; single proximity row **rank 5, disclosed 1**; shared blinding row joint 0 -> **1,024** with the marginals unmoved; swapped claim source refused; foreign stage file refused; one pad short refuses the reduction |
| channels | 23: 2 constructed, 2 derived, 4 argued, **15 open** |

## 4. Findings (all about a field's meaning; none is a privacy matter)

1. **`tables[i].claim` of an IO table is the index inside the STAGE's own
   claim pair, not the index in the commitment's claim list** as format §4a
   says: every IO table of both bundles carries `claim: 0`, including stage
   `k+1`'s slot 21 whose claim is index **1** of the boundary. The gate takes
   the index from `claim_sources`' accumulation and cross-checks it against
   the table's `mask_row`. Public data.
2. **`roles[i].data_rows` counts `H`'s two zero-sum rows; `row_roles` does
   not** (470 vs 468, difference `sum_rows`). The gate uses `row_roles` and
   records the check that the difference IS the zero-sum pair. Public data.
3. **An external endpoint has one SPARE mask row; a derived boundary has
   none** (ruling M-7). The gate reports `spare_mask_rows` rather than
   demanding `site_rows` exhaust the mask rows.
4. **MISSING, and public: the plane index table at the run's shape.**
   `run.json["shape"]` has every geometry axis but not the `A_*` / `H_*`
   plane index assignment of `layout.rs` nor the per-slot table push order.
   Without it the 23 terminal closures cannot be ported, so the per-slot
   terminal identity is OPEN for a run. It is a function of the public
   layout, so the lane can add it.
5. **Pre-existing, NOT this lane's doing: the committed
   `results/zk60_native_privacy_gate/privacy_gate.json` is stale.** It was
   produced by earlier bytes of `zk60_native_privacy_gate.py` and
   `zk60_native_jv_cfs.py`; commit d360466 ("M's three OPEN channels closed
   in the P10 gate") changed them without refreshing the record. Re-running
   the gate now differs from the committed record in exactly `tool_sha256`,
   `version`, and the three M channels that commit closed (q, the proximity
   vector, the M opening's own columns: `open` -> `constructed`), and is
   `ok: true`. This lane did not refresh another lane's evidence; the
   orchestrator should. The joint-view gate's record is identical field for
   field.

## 5. What this lane does NOT show

Linear channels of two captured three-block runs at ONE development shape.
Nothing about the 125M shape. The hash layer is argued, not computed. The
joint-law composition for a run is unwritten. The per-slot terminal identity
is not checked at this shape. NOT a privacy acceptance.

## R2.5 NEXT after round 2

1. **Close the other eleven slots.** Ask the Rust lane for a capture with
   `HL_RUN_CAPTURE_PUBLIC_TABLES=1` (or for the weight / gain / RoPE /
   table-value preimages), and the same port covers 23 of 23 without a line
   of new arithmetic: the ports are written, only the tables are absent.
   That is the one thing that would turn the split channel into a single
   DERIVED entry.
2. The three items of round 1's NEXT that stand: generalise
   `zk60_native_pg_pcs` to `MSG != PAD`; the run-wide preimage as one joint
   object; and the orchestrator's refresh of the stale committed
   `privacy_gate.json`.
3. Nothing here moves D8/D11, ruling M-8's decision, or the run's joint-law
   composition.

## 6. NEXT (round 1, kept as written)

The gate is built, green on both bundles, tested and reported. The three
things a next lane would take, in order: (1) ask the Rust lane for the plane
index table in `run.json["shape"]` (finding 4) and port the 23 terminal
closures at the rung, which closes the largest OPEN channel; (2) generalise
`zk60_native_pg_pcs` to `MSG != PAD` so `A`, `H` and the pad halves become
CONSTRUCTED rather than OPEN; (3) the run-wide preimage as one joint object.
Also for the orchestrator: refresh the stale committed `privacy_gate.json`
(finding 5).

---

# Round 2 — the PLANE INDEX TABLE and the per-slot terminal identity

**Opened 2026-09-20 14:10 PDT**, same lane, same sole writer. Stage 15 of
the Rust lane added `run.json["plane_index"]` (the one field finding 4 asked
for) and wrote two NEW bundles that carry it: `run-c-tame` and `run-d-zero`
in the same read-only directory. `run-a-tame` / `run-b-zero` predate it and
are four *different* runs, not the same run with a field added.

Goal of this round: take item (1) of NEXT — read and integrity-check the
table, then CLOSE, as far as it honestly goes, the per-slot terminal
identity at the run's shape. A partial, per-slot, honest closure is the
target; whatever cannot be ported faithfully stays OPEN *per slot* with a
precise reason.

## R2.0 Stages

| # | item | state |
|---|---|---|
| T0 | this skeleton; baseline recorded | done |
| T1 | plane-index loader + integrity (`zk60_native_rg_planes.py`); old bundle still loads, channel still OPEN, with a test | done |
| T2 | the per-slot terminal identity at the rung (`zk60_native_rg_terminals.py`): recompute each slot's terminal polynomial from the captured terminals and compare with the sumcheck's final claim | done |
| T3 | four controls: (a) perturbed terminal, (b) swapped plane list entries, (c) a slot re-pointed at a same-size plane, (d) an old bundle → OPEN not passed | done (five: a fifth on the rebuilt public tables' digests) |
| T4 | the whole gate on `run-c-tame` + `run-d-zero`, evidence in `results/zk60_native_run_gate_planeindex/`; old bundles re-run unchanged | done |
| T5 | tests for T1–T3; the whole native suite re-run and counted | done |
| T6 | a dated section in `ZK60_NATIVE_RUN_GATE.md`: what is checked per slot, what stays OPEN and why, the recounted channel table | done |

## R2.2 What T2 covers, and what it does not (measured 2026-09-20 14:25 PDT)

**12 of the 23 slots** are evaluated and compared, in every stage: 00 SC_SS,
01 SC_SSM, 02 SC_TZC, 03 SC_LZC, 04 SC_RS, 08 SC_SCORE, 09 SC_PV, 17 SC_SZC,
18 SC_FZC, 20 SC_ZS, 21 SC_IO_IN, 22 SC_IO_OUT — 36 slot checks per bundle,
all equal, all matching the capture's own `terminal_polynomial`.

**11 of the 23 stay OPEN for ONE reason**, and it is not the plane index:
`run.json["public_tables_included"]` is `false`, so a bundle carries a public
table's length and SHA-256 but not its values, and the missing tables of
those slots are folds of the public WEIGHTS (05, 06, 07, 10, 11, 12, 13), the
two norm GAINS (14), the RoPE `(cos, sin)` pair (15, 16) or the exp /
activation table values (19) — none of which a bundle carries. Nothing
HIDDEN is missing; all of it is public and could be re-captured.

**The public tables that ARE a function of the shape are rebuilt here and
checked against the capture's own SHA-256** before use: `supp(T)`, `supp(Ht)`,
`supp(L)`, `supp(D)`, `supp(S)`, `supp(F)`, the causal mask and `SC_ZS`'s
all-ones `Dom::Tab` vector — 11 table instances per stage, every digest
matching. That is a machine check of the pad-rule port itself.

Covered, and NEW at the rung: the pad-zero term
`mu_pad·(1−supp)·Σ ζ^j·plane_j` (slots 02, 03, 17, 18) and the `supp` gate
(00, 01, 04, 17, 18); the third `sigma_s` limb `A_SR2` / `A_SG2` (17); the
grouped-head (GQA) bilinear slots (08, 09); and the run's two boundary claim
sites (21 and 22, whose IO table is an internal BOUNDARY in every stage but
the first and the last).

## R2.1 Rules kept

Same as round 1, plus: the toy gates' modules are pinned by
`tests/test_zk60_native_gate_record.py` against their committed records —
none of their bytes are touched. Everything new is a `zk60_native_rg_*.py`
module. NEVER mark a slot checked unless the identity was actually
evaluated and compared for it.

## R2.3 Commands and logs (round 2)

| what | command | log |
|---|---|---|
| the gate, the two NEW bundles | `python3 scripts/zk60_native_run_gate.py --bundle <B>/run-c-tame --other <B>/run-d-zero --old <B>/run-a-tame --evidence results/zk60_native_run_gate_planeindex` (and swapped) | `results/zk60_native_run_gate_planeindex/run-{c,d}-*.log`, records beside them |
| the gate, the two OLD bundles, refreshed in place | the same with `run-a-tame` / `run-b-zero` | `results/zk60_native_run_gate/run-{a,b}-*.log` |
| the old records diffed leaf by leaf | `python3 scripts/zk60_native_rg_recdiff.py <old> <new> --out ...` | `results/zk60_native_run_gate_planeindex/old_bundle_*.diff.json`, `old_bundles_unchanged.json` |
| the two RUN-gate test files | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate*.py' -v` | `results/zk60_native_run_gate_planeindex/tests_planeindex.log` — **65 tests, OK, 15.0 s** (39 of them this round's) |
| the WHOLE native suite | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py' -v` | `results/zk60_native_run_gate_planeindex/tests_native_all.log` — **232 tests, OK, 227.8 s**, one skip and one recorded expected failure, against **193** before this round: the 39 new ones are `tests/test_zk60_native_run_gate_planeindex.py` |

## R2.4 Results (MEASURED 2026-09-20, both new bundles, shared laptop, CPU only)

| what | figure |
|---|---|
| plane index table | 83 `A` planes tiling 377 rows, 52 `H` planes whose halves tile 470; every plane read by a slot; 176 terminals against 176 planes per stage; 226 of 226 slice offsets inside the plane they name |
| the table in two independent bundles | byte-identical (it is a function of the public shape) |
| terminal identity | **12 of 23 slots**, **36 of 36 checks** equal and matching the stored `terminal_polynomial`, both bundles |
| public tables rebuilt and digest-matched | 11 per stage: seven `supp` indicators, the causal mask, the all-ones `Dom::Tab` vector |
| slots OPEN | **11**, one reason: `public_tables_included: false` and their tables are not functions of the shape (weights, norm gains, RoPE, exp / activation values) |
| controls | **five, all fire** (CT-1 … CT-5) |
| channels | **24**: 2 constructed, 3 derived, 4 argued, **15 open** (old bundles: 2 / 2 / 4 / **16**) |
| the gate, per bundle | 10.8 s / 11.2 s |

---

# Round 3 — the KEYED HASH RULE (D19) and the two TAGGED bundles

**Opened 2026-09-20 16:35 PDT on the same lane.** Stage 17 of the Rust lane
landed decision D19's separating hash tag and stage 18 re-took the bundles
under it, WITH the public tables' values: `run-e-tame-tagged` and
`run-f-zero-tagged` in the same read-only directory. Those two supersede
`run-a-tame` … `run-d-zero` for gate purposes — the older four were made
under the LEGACY (unkeyed) rule, which this profile's code no longer uses.

Two things move in this round, and they are independent:

1. **The rule.** On a tagged profile every BLAKE3 call is in KEYED mode
   under one of four public 32-byte keys, each
   `blake3.derive_key(<context>, <block profile>)`. The gate must DERIVE
   the four keys itself from the contexts pinned in its OWN source and the
   profile its shape names, and COMPARE with what the bundle declares —
   **re-derive, never consume** (ruling T-7). A bundle naming `legacy`, or
   carrying no `hash_tag`, replays exactly as in rounds 1 and 2.
2. **The public tables' values.** `public_tables_included: true`, so the
   eleven slots round 2 left OPEN — 05, 06, 07, 10, 11, 12, 13, 14, 15, 16,
   19 — can be evaluated for the first time.

## R3.0 Stages

| # | item | state |
|---|---|---|
| U0 | this skeleton; the tagged bundles read; the keys pinned in the tool's own source | open |
| U1 | `scripts/zk60_native_rg_hashrule.py`: the rule, the four keys, a keyed transcript, keyed column / leaf / node, the bundle comparison | open |
| U2 | the loader and the replay under the rule, selected per bundle | open |
| U3 | the HASH LAYER computed, not argued: every opened column's leaf and Merkle path under the rule | open |
| U4 | the eleven slots closed from the captured public tables' values | open |
| U5 | controls: a perturbed key set / context / profile / rule; a perturbed table value; a perturbed terminal in a newly checked slot | open |
| U6 | the whole gate on both tagged bundles; the old four re-run and shown unchanged | open |
| U7 | tests; the whole native suite re-counted | open |
| U8 | evidence `results/zk60_native_run_gate_tagged/` and a dated section 7 of the report | open |

## R3.1 Rules kept

Round 2's, unchanged: the toy gates' modules are pinned by
`tests/test_zk60_native_gate_record.py` against their committed records and
**none of their bytes are touched** — in particular `zk60_native_jv_field`'s
`Transcript` hard-codes the unkeyed call, so the keyed transcript is a NEW
subclass in a new `zk60_native_rg_*.py` module, never an edit. NEVER mark a
slot checked unless the identity was evaluated and compared. A key is never
taken from a bundle.
