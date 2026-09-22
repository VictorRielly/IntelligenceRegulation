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

*(CORRECTED 2026-09-22 14:21 (round 9g): three of those five are no longer
true of the gate as a whole, and this paragraph is round 2's scope
statement. "Nothing about the 125M shape" — closed by round 9 (the whole
gate at 125M, 179 s) and round 9c (the full channel table there, **28 at 10
/ 5 / 4 / 9**). "The hash layer is argued, not computed" — the HIDING is
still argued (M-2, M-3) but the hash RULE is derived and every opened column
re-authenticated since round 3. "The per-slot terminal identity is not
checked at this shape" — checked since round 3, and at seven shapes now.
Unchanged and still true: the joint-law composition for a run is unwritten
(O-R2 / G-R4), and **nothing on this lane is a privacy acceptance**.)*

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
| U0 | this skeleton; the tagged bundles read; the keys pinned in the tool's own source | done |
| U1 | `scripts/zk60_native_rg_hashrule.py`: the rule, the four keys, a keyed transcript, keyed column / leaf / node, the bundle comparison | done |
| U2 | the loader and the replay under the rule, selected per bundle | done |
| U3 | the HASH LAYER computed, not argued: every opened column's leaf and Merkle path under the rule | done (stage 9, `zk60_native_rg_hashlayer.py`) |
| U4 | the eleven slots closed from the captured public tables' values | done (23 of 23) |
| U5 | controls: a perturbed key set / context / profile / rule; a perturbed table value; a perturbed terminal in a newly checked slot | done (CT-6..CT-8, CH-1..CH-6) |
| U6 | the whole gate on both tagged bundles; the old four re-run and shown unchanged | done |
| U7 | tests; the whole native suite re-counted | done |
| U8 | evidence `results/zk60_native_run_gate_tagged/` and a dated section 7 of the report | done |

## R3.1 Rules kept

Round 2's, unchanged: the toy gates' modules are pinned by
`tests/test_zk60_native_gate_record.py` against their committed records and
**none of their bytes are touched** — in particular `zk60_native_jv_field`'s
`Transcript` hard-codes the unkeyed call, so the keyed transcript is a NEW
subclass in a new `zk60_native_rg_*.py` module, never an edit. NEVER mark a
slot checked unless the identity was evaluated and compared. A key is never
taken from a bundle.

## R3.2 What the round covers (measured 2026-09-20 17:16 PDT, both tagged bundles)

**The rule.** The four context strings and the two LEGACY profile strings
are pinned in `zk60_native_rg_hashrule.py`'s own source; the key set is
DERIVED from the profile the bundle's SHAPE names (the Python port of
`Shape::hash_tag`, a denylist of two, so an unknown profile is TAGGED) and
then compared with the bundle's declared `hash_tag`: rule name, profile,
4 contexts, 4 keys. Re-derive, never consume. The keyed transcript is a
SUBCLASS of the toy module's `Transcript` — `zk60_native_jv_field.py` is
pinned byte for byte and was not touched.

**One path does not compare, and it is named**: a bundle with no `hash_tag`
member predates stage 17, is read under the legacy rule and marked
SUPERSEDED. Control CH-5 shows the path cannot be abused — delete the
member from a tagged bundle and the replay fails on the bytes.

**The hash layer is computed** (stage 9, new): every opened column
re-hashed (`H_column`), salted (`H_leaf`) and folded up its path
(`H_node`) to the committed root, with the path LENGTH checked against the
tree depth. This is where the column, leaf and node keys are exercised
against real bytes; a transcript-only replay would have used one key of
four and taken three on the bundle's word.

**All 23 slots** of the terminal identity are evaluated. `argument.rs` is
byte-identical at the stage-15 and stage-18 commits; `layout.rs`,
`protocol.rs` and (new) `shape.rs` moved and each diff was read — the
hash-tag plumbing and the T-3 / T-4 path-length checks, nothing this port
reads. A captured public table passes three checks before a polynomial
reads it: the capture's own `len` and SHA-256 (93 of 93 per bundle), the
rebuild where the shape allows it (16 per stage), and the STRUCTURE its
builder gives it (45 per bundle). What is NOT established: that a weight
fold is the fold of the statement's matrix — no bundle carries a weight.

## R3.1b The one thing the structure check caught

`SC_WO`'s fold is NOT zero above the width: the output projection is
indexed by the PADDED HEAD SLOTS, so it is nonzero exactly on
`[0,48) ∪ [64,112)` — head slots {0,1,2,4,5,6} of 8. The first form of the
check (zero above `width`) refused it, which is the check working; it now
knows the three supports (width, heads, hidden) and records which it used.

**An observation for the Rust lane, not a gate failure:** `SC_DMM`'s fold
of the DOWN matrix is nonzero only on `[0,96)`, though the hidden dimension
is 192 and the table is 256 long. A zero fold at a random point means a
zero row, so the lane's fixture appears to give the down projection 96 live
input rows rather than 192. Public data, no effect on any identity (all 69
checks pass), but worth a look.

## R3.3 Commands and logs (round 3)

| what | command | log |
|---|---|---|
| the gate, the two TAGGED bundles | `python3 scripts/zk60_native_run_gate.py --bundle <B>/run-e-tame-tagged --other <B>/run-f-zero-tagged --old <B>/run-a-tame --evidence results/zk60_native_run_gate_tagged` (and swapped) | `results/zk60_native_run_gate_tagged/run-{e,f}-*.log`, records beside them — **14.1 s / 14.0 s** |
| the four SUPERSEDED bundles, re-run for the diff | the same into `results/zk60_native_run_gate_tagged/old` | `…/old/run-{a,b,c,d}-*.log` |
| each diffed against its round-2 record | `python3 scripts/zk60_native_rg_recdiff.py <round-2 record> <new> --out …` then `zk60_native_rg_recclass.py` | `…/old/*.diff.json`, `…/old/old_bundles_unchanged.json` — **0 unclassified leaves** |
| rounds 1 and 2's evidence refreshed in place | the round-1 / round-2 command lines, unchanged | `results/zk60_native_run_gate/`, `results/zk60_native_run_gate_planeindex/` |
| the three RUN-gate test files | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate*.py' -v` | `results/zk60_native_run_gate_tagged/tests_run_gate_all.log` — **94 tests, OK, 19.8 s** |
| the WHOLE native suite | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native*.py' -v` | `results/zk60_native_run_gate_tagged/tests_native_all.log` — **261 tests, OK, 234.1 s**, one skip and one recorded expected failure, against **232** before this round: the 29 new ones are `tests/test_zk60_native_run_gate_tagged.py` |

## R3.4 Results (MEASURED 2026-09-20, both tagged bundles, shared laptop, CPU only)

| what | figure |
|---|---|
| the rule | `blake3-keyed/1`, derived here; **4 of 4** keys and **4 of 4** contexts compared with the bundle's; no refusals |
| the replay under the tag | run binding reproduced, **375** positions, **6,086** challenges, counter **6,918**, **6 of 6** segment position tags — round 1's counts exactly |
| the segment byte lengths | 4,066,824 / 4,089,352 / 4,257,256 — the same as rounds 1 and 2: the tag moves values, not sizes |
| the hash layer | **13** openings, **3,328 of 3,328** columns re-hashed and authenticated, 3,328 path-depth checks, 7.75 MB hashed; the cross-rule probe tries 4 wrong rules and none reaches the root |
| the terminal identity | **23 of 23** slots, **69 of 69** checks equal and matching the stored `terminal_polynomial`, **0** open |
| public tables | **93 of 93** checked against the capture's own len and SHA-256; **16 per stage** rebuilt and digest-matched; **15 per stage** taken and structure-checked (**45** checks) |
| disclosure, unchanged from rounds 1-2 | `A` 0, `H` 2, boundaries 0, endpoints 0; each boundary rank **6 of 6** disclosed **0**; three-role joint **0** = sum; whole run 308 × 3,761, joint **6** = sum 6 |
| controls | **fourteen, all fire** (CT-1 … CT-8, CH-1 … CH-6) |
| channels | **25**: 2 constructed, **5** derived, 4 argued, **14** open (one entry added, one closed; old bundles: 16 open for a/b, 15 for c/d) |
| the four superseded bundles | **0** unclassified differing leaves; 2,222 / 2,223 / 2,831 / 2,831 identical |

## R3.5 NEXT after round 3

1. **The masked sumcheck / CFS channel** is now the largest open one that a
   port could close: `zk60_native_jv_cfs` and `zk60_native_mask_commit` are
   written at the toy's row layout and would have to be re-derived from the
   shape, as the terminal port was.
2. `zk60_native_pg_pcs` at `MSG != PAD`, which would move `A`, `H` and the
   pad halves from OPEN to CONSTRUCTED.
3. The run-wide preimage as ONE joint object.
4. Nothing in this round moves D8/D11, ruling M-8's decision, or the run's
   joint-law composition.

---

# Round 4 — the REPAIRED bilinear slots, and the first NON-DEGENERATE witness

**Opened 2026-09-20 20:59 PDT** on the same lane, same sole writer.
Python only. Nothing here is a privacy acceptance and no statement here
establishes a privacy property.

## R4.0 Why there is a round 4

Two things, and only the second is about this gate's own arithmetic.

1. **Finding S19-F1** (`ZK60_BLOCK125M_S19F1_DISPOSITION.md`, the security
   owner, 2026-09-20 19:57): under grouped-query attention the two bilinear
   attention slots — **08 `SC_SCORE`** and **09 `SC_PV`** — fixed the
   key-value GROUP bits of the head challenge as coordinates of BOTH private
   factors. A product of two multilinear extensions that share a variable is
   quadratic in it, so the honest prover and the honest verifier disagreed
   the moment two key-value groups carried different data: a COMPLETENESS
   failure. Soundness was not weakened (argued by the owner, confirmed
   independently). Repair (lane stage 20): the group bits become SUMCHECK
   VARIABLES `rho(0..lkv)` shared by both factors, with a PUBLIC factor
   `eq(r_g, ·)` where `r_g` is the leading `lkv = log2(kv_heads)` entries of
   the slot's own head challenge; degree 3 and `lkv` more main rounds.
2. **Every bundle this gate has ever read used a DEGENERATE witness.**
   `run-a` … `run-f` used the lane fixture, whose normalised hidden state is
   identical in every head, or the all-zero input. The repair is exactly the
   thing those inputs could not see, and no disclosure or rank figure this
   gate has ever reported was taken on a witness that varies across heads.

So round 4 has two jobs: port the repaired definition, and re-establish
EVERY figure of rounds 1–3 on a bundle whose witness is generic.

## R4.1 Input (READ-ONLY, not copied here)

`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`

| bundle | witness | argument |
|---|---|---|
| `run-g-dense-s20` | **fully dense public weights, a non-constant hidden input, the two key-value groups carrying different data in every block** — the first non-degenerate witness this gate has seen | repaired (stage 20) |
| `run-h-zero-s20` | the all-zero hidden input | repaired (stage 20) |
| `run-a` … `run-f` | the lane fixture / all-zero | PRE-REPAIR, superseded |

## R4.2 Status

| # | item | state |
|---|---|---|
| V0 | ledger skeleton, round 4 opened | done |
| V1 | the group factor: derived from the transcript, compared, never consumed | done |
| V2 | slots 08 / 09 ported under the repaired definition, selected by the bundle's own source pin | done |
| V3 | the replay and the 23-slot terminal identity on both new bundles | done |
| V4 | rounds 1–3's figures re-established on the dense bundle; dense vs degenerate | done |
| V5 | the controls, including the OLD definition on each bundle | done |
| V6 | the R-3 correction notes on rounds 1–3 | done |
| V7 | evidence, report §8, the channel table recounted | done |
| V8 | the whole native suite; the toy record guard | done |

## R4.3 Commands and logs (round 4)

| what | command | log |
|---|---|---|
| the gate, the two REPAIRED bundles | `python3 scripts/zk60_native_run_gate.py --bundle <B>/run-g-dense-s20 --other <B>/run-h-zero-s20 --old <B>/run-a-tame --evidence results/zk60_native_run_gate_s20` (and swapped, with `--old run-b-zero`) | `results/zk60_native_run_gate_s20/run-{g,h}-*.log` — **16.5 s each** |
| rounds 1–3's evidence refreshed IN PLACE (the tool bytes moved) | the round-1 / 2 / 3 command lines, unchanged | `…/zk60_native_run_gate_s20/refresh.log` — six records, 9.2–16.0 s |
| each older record diffed leaf by leaf against its committed one | `zk60_native_rg_recdiff.py <…/old/prev/n.json> <the refreshed> --out …/old/n.diff.json`, then `zk60_native_rg_recclass.py` | `…/old/*.diff.json`, `…/old/old_bundles_unchanged.json` — **0 unclassified leaves on all six** |
| the witness comparison, dense against zero | `python3 scripts/zk60_native_rg_witcmp.py --record … --label … --witness … --out …` | `…/witness_comparison_dense_vs_zero.json` — **173 figures, 153 identical** |
| the same four ways, against round 3's `e`/`f` | the same tool, four records | `…/witness_comparison_round4_vs_round3.json` — 173 figures, 138 identical |
| this round's test file | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate_s20.py' -v` | `…/tests_s20.log` — **29 tests, OK**, 9.1 s |
| the four RUN-gate test files | `… -p 'test_zk60_native_run_gate*.py' -v` | `…/tests_run_gate_all.log` — **123 tests, OK**, 30.0 s (round 3: 94) |
| the WHOLE native suite | `… -p 'test_zk60_native*.py' -v` | `…/tests_native_all.log`, `.done` — **290 tests, OK**, 240.6 s, one skip and one recorded expected failure, against **261** before this round |

`--old` names a bundle written BEFORE the plane index table; it is control
CT-4's input, and on the first attempt round 4 passed a stage-18 bundle
there, which made CT-4 report itself SKIPPED and stage 8 fail. That is the
control working: a control with no input is not a passed control.

## R4.4 Results (MEASURED 2026-09-20 21:23–21:27 PDT, shared laptop, CPU only)

| what | figure |
|---|---|
| the definition in force | **`repaired`**, selected by each bundle's own `argument.rs` pin `dd8469cb`; the six older bundles select `pre-repair` (`909670c9`) and are marked SUPERSEDED |
| the geometry, derived from the shape alone | `lt = 5`, `lh = 3`, `ldh = 4`, **`lkv = clog2(kv_heads) = 1`** |
| slot dimensions derived and compared twice (the slot's own declaration, and the shape's `slots` array) | **6 of 6** — slot 08 `(5, 2, 3)`, slot 09 `(6, 2, 3)` |
| the group point `r_g = r_h[..lkv]`, derived from the REPLAY and compared with the bundle's `Tab::Eq` | **6 of 6**, 6 entries; never consumed |
| both private factors' coordinate lists, re-derived | **12 of 12**, **135** entries, **69** fixed coordinates against a re-derived challenge |
| the replay | run binding reproduced, **375** positions, **6,092** challenges (round 3: 6,086 — exactly `lkv` per bilinear slot per stage), counter **6,924**, **6 of 6** tags, nothing un-re-derived |
| the segments | 4,067,160 / 4,089,688 / 4,257,592 — **+336 B per stage**, the disposition's own figure |
| the terminal identity | **23 of 23** slots, **69 of 69** equal and matching the stored `terminal_polynomial`, **0** open, both bundles |
| **dense against zero** | **173 figures compared, 153 identical.** Every one of the 20 that differ is a count of DISTINCT sampled columns, the pad margin (256 minus it) or the pad block's rank (equal to it) — drawn from the transcript, so they move with the randomness, not the witness |
| disclosure, unchanged from rounds 1–3 | `A` 0, `H` 2, boundaries 0, endpoints 0, `M` 0; `rank_P1` `A` 74, `H` 20; each boundary 10 rows / 6 generators / rank 6 / disclosed **0**; three-role joint **0** = sum; whole run 308 × 3,761, joint **6** = sum 6; preimage 4 commitments, 0 free `Fp` per position |
| round 4's controls | **six, all fire** on both new bundles (four on a pre-repair one) |
| the older rounds' controls on the new bundles | CT-1…CT-8, CH-1…CH-6, C1…C6 — all fire |
| channels | **25**, 2 constructed, 5 derived, 4 argued, **14 open** — unmoved; round 4 added no channel and closed none |
| the six superseded bundles | **0** unclassified differing leaves; 2,512 / 2,512 / 3,159 / 3,159 / 3,480 / 3,480 identical |

### R4.4b The one question this round could not answer

Control GQ-6 evaluates the PRE-REPAIR polynomial `X·Y` beside the repaired
`eq(r_g,ρ_g)·X·Y` on each bundle's own terminals. On BOTH new bundles the
repaired one holds 6 of 6 and the pre-repair one 0 of 6, with no group
factor equal to 1 and no terminal product zero. **Dense and zero give the
same answer.**

That is the honest limit, and it is worth stating plainly: finding S19-F1
is a disagreement between the prover's CLAIM and the true sum over
key-value groups, and both sides of that need a witness. No capture
carries one. So from the gate's side the defect is invisible on EVERY
witness, not only a degenerate one, and the mechanism that hid it — prover
and verifier sharing one wrong definition function — is exactly what a
round-trip reader cannot see. What round 4 DOES establish is that the
claim point and the whole schedule of both bilinear slots are the repaired
construction's, derived here and compared, at this run's real challenges.

### R4.4c Ruling R-3, recorded

`joint == sum of the parts` is a consistency check of the model's
coordinate classes, NOT evidence of independent blinding: two distinct
blinding rows whose values coincide score like an honest run while
disclosing 1,024 field elements at this shape. Dated correction blocks
added in the report's §2.4 and above §7 (rounds 1–3's numbers are
untouched), and the sentence now travels with every joint figure the gate
reports, as `ruling_R3` in the records.

## R4.5 NEXT after round 4

1. **A shape with `lkv > 1`.** Every group figure here was taken at
   `kv_heads = 2`. The port is shape-driven, but one group bit is one group
   bit; the 125M shape's `lkv` is the first thing that would exercise more.
2. The masked sumcheck / CFS channel, still the largest open one a port
   could close (R3.5 item 1), and `zk60_native_pg_pcs` at `MSG != PAD`.
3. The run-wide preimage as ONE joint object.
4. Ruling R-3's machine assertion — accounting for every draw of a run by
   role and showing the roles' stream positions pairwise disjoint — is
   asked of the Rust lane (gap G-R4), not of this gate.
5. Nothing in this round moves D8/D11 or ruling M-8's decision.

---

# Round 5 — TWO key-value group bits (rung-K4), and the toy gates' path pins

**Opened 2026-09-20 23:07 PDT** on the same lane, same sole writer.
Python only. Nothing here is a privacy acceptance and no statement here
establishes a privacy property.

## R5.0 Why there is a round 5

Two items, unrelated to each other except that both close a gap the
previous night's work named in its own NEXT list.

1. **Item A — a shape with `lkv > 1`.** R4.5 item 1: every group figure
   this gate has ever reported was taken at `kv_heads = 2`, i.e. ONE
   key-value group bit, where the public factor `eq(r_g, ·)` carries a
   one-element point and the sum over groups has two terms. The Rust lane
   has now written a development shape **rung-K4** — 24 tokens, width 96,
   hidden 192, **12 query heads of 8 over 4 key-value heads**, padded head
   slots {3, 7, 11, 15}, which is the 125M model's own head geometry — and
   two tagged three-block bundles at it. The port claims to be
   shape-driven. Round 5 is the first time that claim is tested against a
   shape it was not written at.
2. **Item B — the toy gates' source pins widened to the whole path.**
   `ZK60_NATIVE_D22_REPIN_4751B93.md` §7 item 1 found that
   `hashline/src/pcs.rs`, `hashline/src/private_block.rs` and the
   hashline-side `merkle`, `transcript`, `field`, `ntt` files are on the
   toy profile's path and pinned by NOTHING, so condition 7 of the
   accepted statement ("a change to any pinned Rust file suspends step 3")
   was narrower in practice than in words. The security owner ruled at
   22:06 that the pin set is extended to every file on the path.

## R5.1 Input (READ-ONLY, not copied here)

| bundle / tree | what |
|---|---|
| `…/wt-zk60-block125m/results/zk60_run_captures_20260920/run-i-dense-k4` | rung-K4, fully dense weights, generic hidden input, all four key-value groups carrying different data |
| `…/run-j-zero-k4` | rung-K4, the all-zero hidden input |
| the main repository at commit `4751b93` | Item B's Rust blobs, read with `git show 4751b93:<path>`, never the working tree |

## R5.2 Status

| # | item | state |
|---|---|---|
| X0 | ledger skeleton, round 5 opened | done |
| X1 | Item A — the K4 geometry and the two-group factor derived; any one-group-bit assumption in the tools found and named | done — commit `a516bac` |
| X2 | Item A — the whole-run replay and the keyed hash layer under the K4 profile's own keys, with the cross-profile key controls | done — `a516bac` |
| X3 | Item A — the 23-slot terminal identity on both bundles | done — `a516bac` |
| X4 | Item A — every per-commitment figure, next to rung-G's, in one table | done — `488c79c`, §R5.4 |
| X5 | Item A — round 4's controls re-aimed at the third and fourth group | done — `a516bac`, `7ef86d6` |
| X6 | Item A — evidence, report section, channel count recounted | done — report §9 |
| X7 | Item B — the path list established from `4751b93`'s blobs, file by file | done — §R5.5 |
| X8 | Item B — pins added, the path-pin table, the gate's refusal by name | done — `7ef86d6` |
| X9 | Item B — the toy records refreshed deliberately, every figure of record shown unchanged, the guard updated | done — §R5.6 |
| X10 | the whole native suite | done — §R5.7 |

## R5.3 Commands and logs (round 5)

| what | command | log |
|---|---|---|
| the gate, both rung-K4 bundles | `python3 scripts/zk60_native_run_gate.py --bundle <B>/run-i-dense-k4 --other <B>/run-j-zero-k4 --old <B>/run-a-tame --cross-profile <B>/run-g-dense-s20 --evidence results/zk60_native_run_gate_k4` (and swapped) | `…/zk60_native_run_gate_k4/run-{i,j}-*.log` — **25.0 / 25.5 s** |
| the FIRST probe, before the two findings were repaired | the same, without `--cross-profile` | `…/probe-i.log` — **`KeyError: 'slot_checks_expected'`**, finding K4-F1 |
| the eight older records refreshed IN PLACE (the tool bytes moved) | `bash results/zk60_native_run_gate_k4/refresh.sh` | `…/refresh.log`, `.done` — eight records, 9.6–18.8 s |
| each older record diffed leaf by leaf, then classified | `zk60_native_rg_recdiff.py`, then `zk60_native_rg_recclass.py` | `…/old/*.diff.json`, `…/old/old_bundles_unchanged.json` — **0 unclassified leaves on all eight** |
| dense against zero, at two group bits | `zk60_native_rg_witcmp.py` (two records) | `…/witness_comparison_k4_dense_vs_zero.json` — **173 compared, 153 identical** |
| rung-K4 against rung-G | the same tool, four records | `…/shape_comparison_k4_vs_rungg.json` — **173 compared, 134 identical** |
| **Item B**: the three toy gates re-run on the four 2026-09-19 captures | `bash results/zk60_native_pathpins/gates.sh` | `…/zk60_native_pathpins/gates.log`, `.done` |
| this round's test file | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate_k4.py' -v` | `…/zk60_native_run_gate_k4/tests_k4.log` — **36 tests, OK**, 11.9 s |
| the WHOLE native suite | `… -p 'test_zk60_native*.py' -v` | `…/zk60_native_run_gate_k4/tests_native_all.log`, `.done` — see §R5.7 |

## R5.4 Results — Item A (MEASURED 2026-09-20 23:08–23:15 PDT, shared laptop, CPU only)

| what | figure |
|---|---|
| the shape | rung-K4: 24 tokens, width 96, hidden 192, **12 query heads of 8 over 4 key-value heads**, `h_pad = 16`, padded head slots **{3, 7, 11, 15}** — 125M's own head geometry |
| the geometry, derived from the shape alone | `lt = 5`, **`lh = 4`**, **`ldh = 3`**, **`lkv = clog2(4) = 2`**.  Three axes move, not one: a tool that had assumed six heads or a sixteen-wide head would fail here too |
| the definition in force | **`repaired`**, selected by each bundle's own `argument.rs` pin `dd8469cb` |
| the pins the shape moves | `shape.rs` `8f734422` → **`07a0547f`** (60 added lines, 0 removed: a doc comment and `Shape::rung_k4` calling the UNCHANGED `Shape::new`) and `run.rs` `65d55d25` → **`73f68221`** (12 added lines, 0 removed).  The first is accepted as a read second digest; the second is **pinned by nothing** — finding K4-F2.  *(CORRECTED 2026-09-21, round 6: `run.rs` is **9** added lines, 0 removed — `git diff --numstat 0426ad2 3247a89` — not 12; and it is pinned as of tonight, see §R6.5.)* |
| slot dimensions derived and compared twice | **6 of 6** — slot 08 `(5, 2, 3)`, slot 09 `(7, 2, 3)` |
| **the group point** | **6 of 6** derived from the REPLAY and compared with the bundle's `Tab::Eq`, **12 entries** against 6 at `lkv = 1`; never consumed |
| both factors' coordinate lists | **12 of 12**, **138** entries, **66** fixed against a re-derived challenge (135 and 69 at rung-G) — both PREDICTED from the two geometries in a pure test before they were read off a record |
| the replay | run binding reproduced, **375** positions, **6,854** challenges, counter **7,686**, **6 of 6** tags, **nothing un-re-derived** |
| `+762` challenges, decomposed | exactly `3 × (3 definition draws + 3 sumcheck rounds + 104 A proximity rows + 144 H proximity rows)`; `Dom::S` doubles to `2^14` because sixteen head slots replace eight |
| the segments | 4,575,304 / 4,597,832 / 4,765,736 — **+508,144 B in each of the three stages**, the same figure three times |
| the terminal identity | **23 of 23** slots, **69 of 69** equal and matching the stored `terminal_polynomial`, **0** open, both bundles; 16 tables rebuilt and digest-matched, 15 carried, 45 structure checks |
| the hash layer, under the K4 profile's OWN derived keys | **3,328 of 3,328** columns authenticated, 13 openings, 9,275,392 bytes |
| **disclosure, UNMOVED from rung-G** | `A` 0, `H` 2, boundaries 0, endpoints 0, `M` 0; `rank_P1` `A` **74**, `H` **20**; NON-DATA rows **246** and **108** at both shapes; each boundary 10 rows / 6 generators / rank 6 / disclosed 0; three-role joint **0** over 154 generators; whole run **308 × 4,505**, joint **6** = sum 6; preimage 4 commitments, 0 free `Fp` |
| **dense against zero** | **173 compared, 153 identical**; every one of the 20 that differ is a distinct-column count, a pad margin or the pad block's exact rank — **the same twenty classes, and the same reading, round 4 found at one group bit** |
| **rung-K4 against rung-G** | **173 compared, 134 identical**; every one of the 39 is a size the shape must change, a transcript-drawn column count, or a group figure that scales with `lkv` |
| controls | **13 of 13** group controls fire, none skipped (rung-G: 8 of 8, GQ-7 named and skipped); **7 of 7** hash-rule including the new CH-7; **8 of 8** terminal; **6 of 6** run |
| channels | **25**, 2 constructed, 5 derived, 4 argued, **14 open** — unmoved.  Round 5 added no channel and closed none |
| the eight older records | **0** unclassified differing leaves; **0** bundles whose figures of record moved |

### R5.4b THE HEADLINE: nothing failed to scale, and two things about the gate did

The brief asked for "any figure that does not scale as the shape predicts"
as the headline. **There is none.** Every figure either stayed exactly
where it was or moved by exactly the amount the shape derives, including
the `+762` challenges, which decompose to the unit. The port really is
shape-driven.

What round 5 actually found is two things about the GATE, both of which a
second shape was needed to see:

* **K4-F1 — the refusal path crashed.** The first probe died with
  `KeyError: 'slot_checks_expected'`. The port had CORRECTLY refused the
  bundle, because its `shape.rs` pin had moved; but `check_terminals`'s
  moved-pin arm returned a dict without the keys stage 8 and the terminal
  controls read. **No bundle had ever moved a pin, so that path had never
  run end to end.** A refusal path that crashes is not a refusal path.
  Repaired: the early return now carries every key a caller reads, plus a
  sentence saying the zeros are the absence of a check and not a passing
  one. `probe-i.log` is the crash; a live test now exercises it.
* **K4-F2 — three of the eight files a bundle pins are pinned by nothing,
  and the tool said otherwise.** `zk60_native_rg_terminals`'s comment read
  "the other three (`run_capture.rs`, `run.rs`, `boundary.rs`) … are
  checked by `zk60_native_rg_bundle`". They are not; no run-gate tool
  hashes them. The K4 bundles' `run.rs` moved and nothing noticed. The
  comment is corrected and the three named with their digests and what was
  read; **the gap is recorded, not closed**, because closing it means
  reading three files at five capture commits and a pin added without a
  reading is what this discipline forbids.
  *(CLOSED 2026-09-21, round 6: the three files read at all five capture
  commits — nine (file, digest) pairs — and pinned by the new
  `zk60_native_rg_runpins`. See §R6.4–§R6.6. Two of this round's own
  figures are corrected there: `run.rs` is 9 added lines not 12, and
  `boundary.rs` is NOT byte-identical at every capture commit.)*

### R5.4c The one-group-bit assumption that was there

`GroupFactors.perturb_derived_point` perturbed `r_g[0]` and had no way to
name another coordinate — a TEST-surface assumption, not a gate one (no
measured figure came from it), but it meant round 4's controls could not
have reached a second group bit even on a bundle that had one. It now
takes `perturb_derived_entry` and refuses an out-of-range coordinate by
name. Everything else — `Geometry`, `dims`, `n_definition_challenges`,
`coordinate_schedule`, `has_group_table`, `PadGeometry.head_slot`, every
domain size — reads the shape. `plane_index.rs` is byte-identical at both
shapes, so the "rung-G plane index digest" was never a shape-dependent pin.

### R5.4d Two controls that needed the shape

* **GQ-7** (new): the declared point's two group coordinates SWAPPED, every
  value kept. Group 1 and group 2 exchange places; a comparison that
  treated the point as a SET would pass it. **Fires** at `lkv = 2`, refused
  by name with both entries differing; **named and skipped** at `lkv = 1`,
  where a one-entry point cannot be reordered.
* **CH-7** (new): each bundle's real captured columns re-hashed under the
  OTHER tagged profile's derived key set. Nothing is perturbed — both key
  sets are complete, internally consistent and derived here from profile
  strings that really exist, and only the profile is wrong. **Two-sided**:
  3,328 of 3,328 under its own keys and **0 of 3,328** under the other's,
  in both directions, with all four role keys differing. It could not be
  run before round 5, because until rung-K4 there was only one tagged
  profile to read.

## R5.5 Results — Item B: the path, file by file

The security owner's ruling of **22:06**. Read from the COMMITTED BLOBS at
`4751b93` (`git show 4751b93:<path>`), never the working tree, by following
`use` and call out of `hashline/src/private_block.rs` and
`private_block/{argument,layout,protocol,wire,witness}.rs`. Main's
`private_block` module is the TOY-ONLY one, older than the lane's shaped
module: no `shape.rs`, no `run.rs`, no `plane_index.rs`.

**29 files on the path. 9 were already pinned; TWENTY were pinned by
nothing.** Each of the twenty was READ before it was pinned; the reading is
the last column.

| file | kind | pinned before? | the reading, and why it is consistent with the ports |
|---|---|---|---|
| `hashline/src/zk.rs` | real logic | **yes**, `mask_commit` (two digests) | the mask commitment; re-read item by item in the D22 report §2.1 |
| `hashline/src/private_block/argument.rs` | real logic | **yes**, both tools | the declared functional order |
| `hashline/src/private_block/layout.rs` | real logic | yes, `terminal_polys` only | the plane table and the calibration constants. **Now pinned by `mask_commit` too**, at the same digest, so the P10 gate covers it |
| `hashline/src/private_block/protocol.rs` | real logic | yes, `terminal_polys` only | the transcript, ownership and openings. **Now pinned by `mask_commit` too** |
| `hashline/src/native_capture.rs` | real logic | yes, `terminal_polys` only | the writer of the four captures. **Now pinned by `mask_commit` too** |
| `zkp-core/src/mle.rs` | real logic | yes, `terminal_polys` only | `eq_point`, `eq_table_msb`. **Now pinned by `mask_commit` too** |
| `zkp-core/src/ntt.rs`, `pcs.rs`, `sumcheck.rs` | real logic | **yes**, `mask_commit` | the NTT convention, `coset_powers`, `CfsMask` |
| **`zkp-core/src/field.rs`** | real logic | **NO** → `SOURCE_PINS` | `P = 0xFFFF_FFFF_0000_0001` and `NONRESIDUE = 7`, which are exactly the two constants `zk60_native_jv_field` carries; `from_u128`'s 128-bit reduction and the `to_bytes` encodings every absorb uses |
| **`zkp-core/src/transcript.rs`** | real logic | **NO** → `SOURCE_PINS` | `Transcript::new(b"hashline-v1/" ‖ domain)`, `absorb` (length-prefixed label then data), `squeeze_bytes` (state ‖ `"squeeze"` ‖ counter, folding back), `challenge_fp2` (two 128-bit halves), `challenge_indices` — the Fiat-Shamir the replay ports, line for line |
| **`zkp-core/src/merkle.rs`** | real logic | **NO** → `SOURCE_PINS` | `hash_pair = blake3(left ‖ right)`, `build` over a power-of-two leaf count, `path` taking `lvl[i ^ 1]`, `verify_path` folding left/right by the index bit — the fold the hash layer and the M opening's twelve-level paths are checked against |
| **`zkp-core/src/rng.rs`** | real logic | **NO** → `SOURCE_PINS` | `ZkRng::from_os` (a keyed blake3 over 32 bytes of `/dev/urandom`, failing closed off Unix), the 8,192-byte refill, and `fp` / `fp_vec` / `bytes32`. This is **the draw order** `REPIN_HISTORY` already claimed to have checked — "per mask row `CfsMask::random`, then `MASK_Q` pads, then `b_re, b_im, u_re, u_im`, then one 32-byte salt per column" — a sentence about a file nothing pinned |
| **`hashline/src/private_block.rs`** | real logic | **NO** → `PATH_PINS` (two digests) | `PROFILE`, the public statement (`AttentionPublic` / `FeedForwardPublic` / `BlockPublic`, their structure refusals and the ONE digest domain `b"hashline/private-block-public/1"`), `ENDPOINT_SCALES = (0, 0)` and `IoSpec::new`'s refusal pinning them, `prepare_endpoints`, the by-value `Endpoints` that makes a second proof not type-check, `prove` / `verify` / `verify_bytes`, and the `#[cfg(test)] mod capture` that `include!`s `native_capture.rs`. Consistent: the capture the gates read is written from inside this module |
| **`hashline/src/private_block/wire.rs`** | real logic, no arithmetic | **NO** → `PATH_PINS` | the bounded codec and its typed shape check. Its constants ARE the ports': `CHECKS = 256` (`MASK_Q`), `VEC = 512` (`MSG_N`), `MASK_VEC = 1024`, `MASK_DOM = 4096` (`DOM_N`), `MASK_PATH = 12` (`MASK_LOG_DOM`). Nothing read from a frame controls an allocation or a loop bound |
| **`hashline/src/private_block/witness.rs`** | real logic, PROVER ONLY | **NO** → `PATH_PINS` | the exact-integer witness: `isqrt`, `requant`, both RMSNorms, QKV, RoPE, the integer softmax, PV, O, both residuals, the SiLU feed-forward. No port transcribes it and nothing in it can contradict one, because no capture carries a witness. Pinned because the prover reaches it and its refusals are input-dependent |
| **`hashline/src/private_seam.rs`** | real logic | **NO** → `PATH_PINS` | the two external endpoint commitments. `MASK_ROWS = 5` and `commitment_rows = data_rows + MASK_ROWS` are exactly the endpoint geometry the gates report — 4 data rows, 5 non-data, 9 rows, rank 4 |
| **`hashline/src/pcs.rs`** | ADAPTER | **NO** → `PATH_PINS` (two digests) | `pub use zkp_core::pcs::*` plus dispatch: `commit`, `open`, `commit_zk`, `commit_zk_owned` all call the core through `backend()`, and the two GPU-only entries are `#[cfg(feature = "gpu-cuda")]`. On this path it adds NO arithmetic, so the port's subject stays zkp-core's |
| **`hashline/src/gpu/mod.rs`** | ADAPTER | **NO** → `PATH_PINS` (two digests) | reached only through `pcs::backend()`. Without `gpu-cuda`, `backend()` is `zkp_core::pcs::Cpu` and `enabled()` is a const `false`, so no device arm is reachable in the build the captures were made in |
| **`zkp-core/src/pcs/backend.rs`** | ADAPTER | **NO** → `PATH_PINS` | the `Backend` / `EncodedStore` seam. `Cpu`'s store type `NoExternal` is an EMPTY ENUM and both hooks default to `None`, so in a CPU build the external arms are unreachable and the CPU body — the one the ports transcribe — is the only path |
| **`hashline/src/tables_attn.rs`** | three constants | **NO** → `PATH_PINS` | `protocol.rs` imports `TAG_EXP`, `TAG_U8`, `TAG_ACT` from it, and they are **129, 133, 134** — the same three literals `zk60_native_rg_terminals` and the toy ports carry. The rest of the file is the public FFN attention half's generators, which this profile does not call |
| **`hashline/src/{merkle,transcript,field,ntt,mle,sumcheck}.rs`** | PURE RE-EXPORTS, 97–229 bytes | **NO** → `PATH_PINS` (six) | each is one `//!` line and one `pub use zkp_core::<mod>::*`; `field.rs` adds a `#[cfg(test)]` module declaration. Nothing to be inconsistent with |
| **`hashline/src/lib.rs`**, **`zkp-core/src/lib.rs`** | crate roots | **NO** → `PATH_PINS` (two) | the module trees: which files exist and which are feature-gated |

### R5.5b Three files carry TWO digests

This lane's worktree still carries `4751b93^`'s bytes for
`private_block.rs`, `pcs.rs` and `gpu/mod.rs` while main carries
`4751b93`'s, so both are accepted and the lane tree's is the pin of record
— the form §4.1 of the re-pin report used for `zk.rs`. Every diff was read
in full (`results/zk60_native_pathpins/{pb_pcs,gpu_mod}.diff.txt`):

* `private_block.rs`: **2 added lines, 0 removed** — `#[cfg(test)] mod norm_alias;`
* `pcs.rs`: **47 added lines, 0 removed** — the two arms of `commit_planes`,
  one feature-gated and one returning `None`; nothing on this path calls it
* `gpu/mod.rs`: **426 added lines in two hunks, 0 removed or modified** —
  three re-exports and the host buffer pool; `backend()` and `enabled()` are
  untouched and both hunks are above them

### R5.5c NOT pinned, and why — no file was refused

**No file on the path was refused.** Every one of the twenty was found
consistent with the ports and pinned. Three groups are deliberately OUT of
the list, each named in the tool rather than merely absent:

1. `private_block/{norm_alias,parity,refusals,tamper,tests}.rs` are
   `#[cfg(test)]` modules the prover and verifier do not reach.
   `native_capture.rs` is the one `#[cfg(test)]` file that IS pinned,
   because it wrote the four captures.
2. `causal_oracle.rs`, `tables_v3.rs` and `zkp-core/src/tables.rs` are
   reached only by `*::synthetic_fixture`, which makes the PUBLIC test
   data — the fixture's path, not the prover's or the verifier's, and the
   ruling's words are "prover and verifier reach". Recorded with their
   reasons in `zk60_native_mask_commit.FIXTURE_PATH_NOT_PINNED`, and a test
   asserts they are named and not pinned.
3. **A RESIDUAL, named:** `private_attention.rs`,
   `private_attention/wire.rs` and `private_attention/witness.rs` are on the
   ATTENTION profile's path. Two of the four toy captures are attention
   receipts, so the same widening is owed there. The ruling names the block
   profile, so it is not done here.
   *(STILL OPEN, re-checked 2026-09-22 14:21 (round 9g) — this is the one
   item of round 9g's sweep that nothing has closed. The three files are in
   NO pin table this lane owns: not `zk60_native_mask_commit.PATH_PINS` (20
   entries) or `SOURCE_PINS` (10), not
   `zk60_native_terminal_polys.SOURCE_PINS` (8 — which DOES pin the
   attention profile's `argument.rs`, `layout.rs` and `protocol.rs`, so the
   residual is exactly these three and no more), not
   `zk60_native_manifest_pins`, and not in the capture writer's 38-file list
   (15 `private_block` + 23 shared, none under `private_attention/`). The
   two attention captures therefore still reach three files nothing
   compares. Carried forward at R9f.10 item 3 and re-stated in §R9g.8.)*

## R5.6 Results — Item B: the toy gates re-run, and why each tool hash moved

Run AFTER the pins were added and BEFORE anything was claimed, with the
commands the records' own READMEs give, on the same four toy captures
(`results/zk60_native_captures_20260919`, source commit `2b5c65c3`). The
committed bytes were taken with `git show HEAD:…` into
`results/zk60_native_pathpins/before_{p10,channels,jointview}.json` before
any run, and compared at every leaf with
`results/zk60_native_gate_record_refresh/jsondiff.py`. Heavy runs were
launched detached under `flock /tmp/zk-heavy.lock` with a `.done` marker.

| record | seconds | differing leaves | diff |
|---|---:|---:|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | 226.7 (was 221.8) | **122** | `…/zk60_native_pathpins/p10.diff.txt` |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | 227.9 (was 222.9) | **122** | `…/channels.diff.txt` |
| `results/zk60_native_joint_view/joint_view.json` | 25.2 (was 21.6) | **5** | `…/jointview.diff.txt` |

The 122 on each P10 record decompose exactly: `/seconds`;
`/tool_sha256/zk60_native_mask_commit.py`; and, on each of the four
captures, the **20 new files** and the **10 new `pin_kind` keys** under
`/per_capture/N/masking_commitment_M_opening/source_pins/` —
`2 + 4 × 30 = 122`. **Nothing else differs.** The five on the joint-view
record are `/seconds`, three per-stage wall clocks and the same tool hash;
that record gains no pin keys because it takes its pins from
`zk60_native_terminal_polys`, whose table did not move.

### R5.6b Every figure of record, unchanged

Both P10 records, on all four captures: `ok` true, **28 channels**,
**11 constructed / 2 derived / 8 argued / 7 open** on every capture, the
same **10 control entries** all firing with the honest run passing before
and after each, receipts **2,816,472** bytes (block ×2) and **2,245,800**
bytes (attention ×2), `is_a_privacy_acceptance` false,
`privacy_property_established` false, `privacy_review_complete` false. The
joint-view record: stages 1–7 all `ok`.

### R5.6c Why each tool hash moved

**Exactly one tool moved**, `scripts/zk60_native_mask_commit.py`
(`a42639a6…` → `fae15b49…`), and only because the pin tables were written
into it: four entries added to `SOURCE_PINS`, the new `PATH_PINS` table of
16, `FIXTURE_PATH_NOT_PINNED`, three second digests in `ALSO_ACCEPTED`, and
the `pin_kind` field and path-specific refusal message in
`check_source_pins`. **No arithmetic in that file changed**, and the
leaf-by-leaf diffs are the proof of it: not one rank, dimension, channel
label, control figure or receipt size moved.

The record GUARD (`tests/test_zk60_native_gate_record.py`) needed no change
to its existing assertions — it re-derives the channel counts from each
record's own array and compares them with
`results/zk60_native_gate_record_refresh/channel_counts_of_record.json`
(28 channels, 11 / 2 / 8 / 7) and with §14.1 of `ZK60_NATIVE_JOINT_VIEW.md`
— and **the pin file was not touched, because no count moved.** Six tests
were ADDED to it for the ruling:

1. the pin table covers **exactly** the established path list (both
   directions: a file added to the path without a pin fails, and a pin for
   a file not on the list fails);
2. the whole widened table passes on the tree as it stands, with 20
   entries marked `on-the-path`;
3. **a byte flipped in EVERY path-pinned file, one at a time**, in a
   throwaway tree with every other pinned file unchanged: each must raise
   and each message must name its own file and say
   `ON THE TOY BLOCK PROFILE'S PATH`;
4. the control for (3): the same throwaway tree with nothing flipped
   passes, so the refusals are the perturbation's and not the copying's;
5. the two pin tables agree at every digest they share;
6. the three fixture-path files are named with a reason and NOT pinned.

## R5.7 The suite

`python3 -m unittest discover -s tests -p 'test_zk60_native_run_gate_k4.py'`:
**36 tests, OK**, 11.9 s.
`-p 'test_zk60_native_gate_record.py'`: **12 tests, OK** (was 6).
`-p 'test_zk60_native_run_gate*.py'`: **159 tests, OK**, 42.5 s (round 4: 123).
`-p 'test_zk60_native*.py'`: **335 tests, OK**, 281.5 s, one skip and one
recorded expected failure, against **293** before this round. The 42 new
ones are round 5's 36 and the record guard's 6.

### R5.7b Six earlier assertions moved DELIBERATELY, and why each one did

The first whole-suite pass after the tool changes was **335 tests, 5
failures and 1 error**, and every one of the six was an earlier round
asserting an exact set that round 5 widened on purpose. They are listed
here rather than merely fixed, because "the suite went green" is not a
reading:

| test | was | is | why |
|---|---|---|---|
| `test_zk60_native_mask_commit.test_every_source_pin_is_present_and_unchanged` | `len(pins) == len(SOURCE_PINS)` | the SUM of both tables, with `pin_kind` asserted on each, and the pre-round-5 behaviour (`path_pins=()`) still checked | the path pins |
| `…test_a_tree_at_4751b93_passes_and_the_record_names_it` | materialised a tree of the 6 ported files | materialises all 30, and asserts that **four** files come back at an accepted second digest (`zk.rs`, `private_block.rs`, `pcs.rs`, `gpu/mod.rs`) and every other at its pin of record | three more files differ between this lane's tree and main |
| `…test_a_third_digest_is_still_refused` | the same tree of 6 | of 30 | the same |
| `test_…_run_gate_s20.test_round_fours_six_controls_all_fire` | `controls_total == 6`, names `GQ-1 … GQ-6` | **9 total, 8 live, 8 fire, `GQ-7` skipped**, names `GQ-3.08.0 / .09.0` and `GQ-4.08.0 / .09.0` | `GQ-3` and `GQ-4` became families, one per slot per group coordinate, and `GQ-7` does not exist at `lkv = 1` |
| `test_…_run_gate_s20.test_the_controls_run_live_on_both_bundles` | 6 fire | **8** fire, `GQ-7` skipped by name | the same |
| `test_…_run_gate_tagged.test_the_six_hash_rule_controls_all_fire` | `CH-1 … CH-6` | `CH-1 … CH-7`, with CH-7's two-sided figures asserted | CH-7 |
| `test_…_run_gate_tagged.test_a_pre_tag_bundle_is_legacy_and_marked_superseded` | skipped `["CH-1..CH-5"]` | `["CH-1..CH-5", "CH-7"]` | a pre-tag bundle has no second tagged profile to cross, so CH-7 is named and skipped there |

**Not one of the six was a measured figure.** Every rank, disclosed
dimension, challenge count, slot check and channel count asserted by rounds
1–4 is asserted unchanged.

## R5.8 NEXT after round 5

1. **Close finding K4-F2**: read `run_capture.rs`, `run.rs` and
   `boundary.rs` at each capture commit and pin them, so the run gate's
   claim about its own pin coverage becomes true.
   *(DONE 2026-09-21, round 6 — §R6.4–§R6.6.)*
2. **The attention profile's path** (R5.5c item 3): the same widening for
   `private_attention.rs`, `wire.rs` and `witness.rs`, which two of the
   four toy captures reach.
   *(STILL OPEN as of 2026-09-22 14:21 (round 9g), checked against the
   current pin tables — see R5.5c item 3 above and §R9g.8.)*
3. **A shape with `lkv > 2`.** 125M's `lkv` is 2, so rung-K4 exercises the
   case that shape needs; eight or more key-value groups are still unread.
   *(STILL OPEN as of 2026-09-22 14:21 (round 9g), checked: every shape this
   gate has run has `lkv ≤ 2` — rung-G 2 key-value heads, rung-K4 and
   rung-P2 4 (`lkv = 2`), 125M 4 (`lkv = 2`), and rung-C6 / rung-W14 /
   rung-E32 add row width and endpoint rows, not head groups.)*
4. The masked sumcheck / CFS channel, still the largest open one a port
   could close, and `zk60_native_pg_pcs` at `MSG != PAD`.
5. The run-wide preimage as ONE joint object; ruling R-3's machine
   assertion (gap G-R4), asked of the Rust lane.
6. Nothing in this round moves D8/D11 or ruling M-8's decision.

---

# Round 6 — the RUN LAYER's own pins (closing finding K4-F2)

**Opened 2026-09-21 00:10 PDT** on lane `zk60-native-jointview`, same sole
writer, Python only. Nothing here is a privacy acceptance and no statement
here establishes a privacy property.

## R6.0 Why there is a round 6

R5.8 item 1. Round 5's finding **K4-F2**: three of the eight files a run
bundle pins in its own manifest — `run_capture.rs`, `run.rs`,
`boundary.rs` — are pinned by **no run-gate tool**, and
`zk60_native_rg_terminals`'s comment said they were "checked by
`zk60_native_rg_bundle`". They are not. The rung-K4 bundles' `run.rs`
moved from `65d55d25` to `73f68221` and nothing noticed.

Everything the run gate says about the RUN layer — the run header and its
binding, the stage order, the boundary geometry and its reserved rows, the
segment position tags, what a capture records and in which order — rests
today on the replay reproducing every challenge and every tag. That is
strong evidence, and it is not a pin: a change to the CAPTURE WRITER that
alters what is recorded WITHOUT moving a challenge would be invisible.

Round 6 closes the gap the way this lane closes gaps: **read first, pin
second.** A pin added without a reading is what the discipline forbids.

## R6.1 Input (READ-ONLY, never written)

| tree / bundle | what |
|---|---|
| `…/wt-zk60-block125m` at `cb27845d`, `aff891d`, `facc057`, `0426ad2`, `3247a89` | the five capture commits' committed blobs, read with `git show <commit>:<path>` |
| `…/wt-zk60-block125m/results/zk60_run_captures_20260920/run-{a..j}` | the ten bundles and their `manifest.json` `source_pins` |

## R6.2 Status

| # | item | state |
|---|---|---|
| Y0 | ledger skeleton, round 6 opened | done |
| Y1 | the dependency list: what every run-gate module relies on in the run layer, with the port's own references | done — §R6.4, `zk60_native_rg_runpins.DEPENDS` |
| Y2 | the (file, commit) matrix: every in-scope bundle's run-layer digests, verified against the committed blobs | done — §R6.5, 9 pairs over 5 commits, 15 (file, commit) combinations recomputed |
| Y3 | read: every consecutive-commit diff classified hunk by hunk | done — §R6.5b; no file refused, no port stale (§R6.5c) |
| Y4 | the run-layer pin table, in the existing mechanism's style, with the bundle's `source_pins` cross-checked | done — commit `87ef89c` |
| Y5 | the record corrected wherever it says or implies the run layer was pinned before tonight | done — §R6.6, six places plus finding R6-F1 |
| Y6 | tests: refusal by name, unknown digest leaves stages NOT CHECKED without crashing, the table covers exactly the list | done — commit `e75a8b2`, **25 tests, OK** |
| Y7 | every in-scope bundle re-run, leaf diff against the committed records, every differing leaf classified | done — §R6.7, **0 unclassified leaves on all ten** |
| Y8 | the whole native suite | done — §R6.7 |

## R6.3 Commands and logs (round 6)

| what | command | log |
|---|---|---|
| the run-layer digests at the five capture commits, verified against the committed blobs | `git --no-pager -C …/wt-zk60-block125m show <commit>:<path>`, SHA-256 recomputed in `python3` | §R6.5's table; a test recomputes all fifteen (file, commit) combinations |
| each consecutive-commit diff, and the production / `#[cfg(test)]` split | `git --no-pager -C …/wt-zk60-block125m diff <a> <b> -- <path>` and `--numstat`, with the hunk headers walked in `python3` to count which side of `mod tests` each line falls | §R6.5b |
| the ten in-scope bundles re-run under the new tools, in place | `bash results/zk60_native_run_gate_runpins/refresh.sh`, detached under `flock /tmp/zk-heavy.lock` with a `.done` marker | `…/zk60_native_run_gate_runpins/refresh.log` — 9.2–25 s each.  The first launch died at `run-d-zero` with exit 2 and no traceback; the bundle was re-run alone (14.4 s, clean) and the remaining six enqueued on the same lock |
| the committed bytes, BEFORE any run | `git show HEAD:results/<dir>/<bundle>.json` into `…/runpins/before/` | ten files, 98–148 kB |
| each record diffed leaf by leaf, then classified | `bash results/zk60_native_run_gate_runpins/diff.sh` (`zk60_native_rg_recdiff.py`, then `zk60_native_rg_recclass.py`) | `…/runpins/diffs/*.diff.json`, `…/runpins/all_ten_bundles_unchanged.json` — **0 unclassified leaves on all ten** |
| this round's test file | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate_runpins.py' -v` | `…/runpins/tests_runpins.log` — **25 tests, OK**, 28.5 s |
| the run-gate suite | `… -p 'test_zk60_native_run_gate*.py' -v` | `…/runpins/tests_run_gate_all.log` — **184 tests, OK**, 71.6 s (round 5: 159) |
| the WHOLE native suite | `… -p 'test_zk60_native*.py' -v`, detached under the lock | `…/runpins/tests_native_all.log`, `.done` — see §R6.7 |

## R6.4 Results — the dependency list (established 2026-09-21)

Every run-gate module was read against the Rust at the capture commits. The
question asked of each was narrow: **what does this port transcribe or rely
on in the run layer, and where is its own reference?** The answer is
`zk60_native_rg_runpins.DEPENDS`, and a test asserts the pin table covers it
exactly, in both directions.

**Eight run-layer files were considered. FOUR are depended on; of those,
THREE were pinned by nothing.**
*(Historical, as of 2026-09-21 (round 6) — the past tense is accurate: they
were pinned by nothing until this round pinned them. The four in the second
table below, which round 6 could not pin at all, are pinned by the WRITER
from lane stage 27; the correction is under "The residual, named" at the end
of this section.)*

| file | depended on by | pinned before tonight? |
|---|---|---|
| `run.rs` | `rg_replay` (the run header's six absorbs and their order; the stage loop `pb-run-stage` / `pb-run-block` / `B` before `A`; `position_tag`, two Fp2 from a DISCARDED clone), `rg_bundle` (`run_shape_words` order, the opening order `M, A, H, Input(, Output)`), `rg_joint` (`BOUNDARY_SITES = 2`, `in_site` / `out_site` = slot 21 / slot 22) | **NO** |
| `boundary.rs` | `rg_bundle` (the whole boundary-table block: `data + 2*sites + 2`, `site_rows`, `prox_row`, pair adjacency and distinctness), `rg_joint` (the reserved block, `2 sites + 2 = 6` columns over `2(G+1) = 6` generators), `rg_pcs` (`mask_rows` / `prox_mask_row` as the capture's `row_roles`), `rg_controls` (C1 and C2 perturb exactly this geometry) | **NO** |
| `run_capture.rs` | `rg_bundle` (the WRITER: schema, three kinds, coverage, every field name and order, `TRANSCRIPT_LABELS` = `EXPECTED_LABELS`, the manifest), `rg_planes` (the stage-15 `plane_index` member), `rg_hashrule` (the stage-17 `hash_tag` member), `rg_terminals` (the Fp2 encoding, `terminal_polynomial`, `public_tables`, `row_roles`), `rg_hashlayer` (the opened columns as recorded) | **NO** |
| `plane_index.rs` | `rg_planes`, `rg_terminals` | **yes** — `rg_terminals.PORTED_FROM`, one digest `9de8320a`; a moved pin already makes every slot of every stage NOT CHECKED |

**Four are NOT depended on, and are named rather than merely absent**
(`zk60_native_rg_runpins.NOT_PINNABLE_FROM_A_BUNDLE`). Each carries two
reasons, because either alone would be weaker than it looks: (a) no port
transcribes it, and (b) the WRITER does not pin it, so no bundle carries a
digest to compare — and this gate reads a bundle, never the Rust tree.

| file | (a) why no port depends on it | (b) |
|---|---|---|
| `wire.rs` | no port decodes a segment; `segment_bytes` / `segment_sha256` are REPORTED sizes, and the start/end tags the frame binds are re-derived from the transcript and compared against `run::position_tag`, not against the frame | not in `SOURCE_FILES` |
| `run_sink.rs` | no port reads a segment file; `HL_RUN_CAPTURE_SEGMENTS` is off in every committed bundle | not in `SOURCE_FILES` |
| `endpoint_g.rs` | the endpoint's rows come from `run.json["shape"]["endpoint_rows"]` and its non-data rows from the capture's `row_roles`; `endpoint_g::MASK_ROWS` is transcribed nowhere in the run gate (the TOY analogue `private_seam.rs` IS pinned, by `zk60_native_mask_commit.PATH_PINS`) | not in `SOURCE_FILES` |
| `hash_domain.rs` | the one guard the gate computes is the path-length check, ported from `pcs::verify_zk_tagged` (pcs.rs:1188) against the commitment's own encoded width; no other guard has a Python counterpart | not in `SOURCE_FILES` |

Fact (b) is read from the Rust rather than asserted: a test greps
`run_capture.rs::SOURCE_FILES` at `3247a89` and requires the four to be
absent from it and the four pinned ones to be present.

**The residual, named:** closing (b) would mean the Rust lane adding those
four to `SOURCE_FILES`. That is a Rust-lane ask, recorded in R6.8, not a
gap this lane can close from a bundle.

*(CORRECTED 2026-09-22 14:21 (round 9g): **the ask was granted.** At lane
stage 27 (`f4697f9`) `SOURCE_FILES` (8) became `OWN_SOURCE_FILES` (15) +
`SHARED_SOURCE_FILES` (23) = **38 files**, and all four of `wire.rs`,
`run_sink.rs`, `endpoint_g.rs` and `hash_domain.rs` are in a `/5-run`
bundle's `source_pins`. So column (b) of the table above — "not in
`SOURCE_FILES`" — and the sentence "the WRITER does not pin it, so no
bundle carries a digest to compare" are **true of every bundle up to
`3247a89` and false of one written at `f4697f9` or later**. Column (a), that
no port transcribes them, is unchanged and is what still keeps them out of
`DEPENDS`. See round 9 §R9.3 / report §13.5, and
`zk60_native_rg_runpins.WRITER_SIDE_ASK_GRANTED`, which records the grant
with its commit. The test that reads fact (b) out of the Rust reads it at
`3247a89`, which is why it still passes.)*

## R6.5 Results — read, then pinned

**Nine (file, digest) pairs over five capture commits, all read, none
refused.** Every digest was verified against the committed blob
(`git show <commit>:<path>`, SHA-256 recomputed) and equals what the
bundles' manifests declare; a test recomputes all fifteen (file, commit)
combinations.

| file | digest | git blob | lane commits | bundles |
|---|---|---|---|---|
| `run_capture.rs` | `51f26bc1` | `8477446f` | `cb27845d` | a, b |
| | `975364b9` | `6cdc85fb` | `aff891d` | c, d |
| | `0cb54ae3` | `18fb8817` | `facc057`, `0426ad2`, `3247a89` | e–j |
| `run.rs` | `02f7ee7e` | `4e79342a` | `cb27845d`, `aff891d` | a–d |
| | `87b3f0c4` | `c38c30e8` | `facc057` | e, f |
| | `65d55d25` | `cc41cd8b` | `0426ad2` | g, h |
| | `73f68221` | `0d86be90` | `3247a89` | i, j |
| `boundary.rs` | `9860c35d` | `18f951e7` | `cb27845d`, `aff891d` | a–d |
| | `3786a300` | `c6f060c6` | `facc057`, `0426ad2`, `3247a89` | e–j |

### R6.5b The readings, one line per pair

The full text is in `zk60_native_rg_runpins.READINGS`; this is the one-line
form. Every diff was classified hunk by hunk, and the production /
`#[cfg(test)]` split was **counted**, not eyeballed.

| pair | what changed, and why the port still describes it |
|---|---|
| `run_capture.rs` `51f26bc1` | **BASE.** Read whole: `SCHEMA`, the three kinds, `coverage`, the run- and stage-file field orders, `TRANSCRIPT_LABELS` (19, equal entry for entry to `EXPECTED_LABELS`), `ALLOWED_KEYS`, `SOURCE_FILES` (6), and `write_bundle`'s manifest |
| → `975364b9` | `git diff cb27845d aff891d`: **84 added, 3 removed, 9 hunks, none in a test module.** Stage 15's plane index (`SOURCE_FILES` 6 → 7, the per-stage rebuild-and-compare, the per-slot push-order check, `take` refusing a bundle without a table, the new member, 13 new allowed keys). The three removals are the same lines re-emitted with the new field. **Nothing the loader already read moved.** `rg_planes` was written FOR the new member in round 2 |
| → `0cb54ae3` | `git diff aff891d facc057`: **65 added, 7 removed, 9 hunks, none in a test module.** Stage 17/18 (D19): the recorder rebuilds the header under `tagged_transcript`, `mask_verify_tagged` / `verify_zk_tagged`, the `hash_tag` member with 9 new allowed keys, `SOURCE_FILES` 7 → 8. `TRANSCRIPT_PROGRAM` grows 9 → 10 — **no port reads it** (`grep -rn transcript_program scripts/ tests/` is empty) — and `transcript_labels`, which every port reads, is **unchanged at 19**. `rg_hashrule` was written for `hash_tag` in round 3 |
| `run.rs` `02f7ee7e` | **BASE.** Read whole: `RunStatement::transcript`'s six absorbs and the shape-word order; the stage loop; `position_tag`; `BOUNDARY_SITES`; `in_site` / `out_site`. Each is a line of `RunReplay.run` / `._stage` |
| → `87b3f0c4` | `git diff aff891d facc057`: **48 added, 9 removed, 12 hunks** (no test module in this file). Stage 16/17/18: T-3's run-level length guard, `boundary_spec` → `new_with_tag`, `transcript` → `tagged_transcript`, T-4's `segment_paths_are_the_tree_depth`, the verifier's own `tag` (T-7), three `verify_zk` → `verify_zk_tagged`. **The header, `position_tag`, the stage loop, the boundary-before-A rule and the opening order are untouched.** The one thing a port depends on that moved is the transcript constructor — which is exactly what the D19 rule the loader DERIVES selects (`RunReplay.run` opens with `rule.transcript(...)`, round 3) |
| → `65d55d25` | `git diff facc057 0426ad2`: **30 added, 0 removed, 1 hunk.** Ruling R-5: a run refuses any block scale pair but the approved calibration's. **No absorb added, no proof byte moved**; the Rust's own `the_run_header_the_approved_scales_bind_is_byte_identical_under_ruling_r5` pins the rung-G `L = 3` binding, both boundary digests and the parameter line as pre-refusal literals. No port reads a block scale |
| → `73f68221` | `git diff 0426ad2 3247a89`: **9 added, 0 removed, 2 hunks** — `RUN_PROFILE_RUNG_K4` and `RunShape::rung_k4` calling the UNCHANGED `RunShape::new`. (Round 5 recorded 12; `--numstat` says 9 — corrected tonight, see R6.6) |
| `boundary.rs` `9860c35d` | **BASE.** Read whole: `commitment_rows() = data_rows + 2*sites + 2`, `site_rows()`, `prox_row()`, `mask_row(s)`, `MAX_SITES = 4`, ruling M-1's declared-row refusal, and `prepare` setting `mask_rows` / `prox_mask_row`. Exactly `integrity`'s boundary-table checks and `boundary_reserved_figure`'s reserved block |
| → `3786a300` | `git diff aff891d facc057`: **42 added, 13 removed, 13 hunks** — and the split is the point: **production +27 / −3**, `#[cfg(test)] mod tests` **+15 / −10**. Stage 17/18: `new` keeps its signature and delegates to `new_with_tag` under `HashTag::legacy()`; the C-H4 guard becomes `..._under(..., tag)`; `prepare` takes the run's tag and calls `commit_zk_owned_tagged`. **Not one geometry accessor moved**, and the ports read only those |

### R6.5c Nothing was refused, and no port turned out stale

Every hunk was classified as additive, or as touching a ported function, or
as touching what the capture records. **Three hunks touch something a port
depends on, and the port was already updated for all three**: the tagged
transcript constructor (round 3), the `hash_tag` member (round 3) and the
`plane_index` member (round 2). `TRANSCRIPT_PROGRAM` growing 9 → 10 is the
one change to what a capture RECORDS that no port noticed — and no port
reads it, which was checked rather than assumed. **No file was refused, and
no (file, commit) pair was left unpinned.**

### R6.5d What the refusal does, and why it is not a crash

A digest outside the table leaves the AFFECTED STAGES not checked, by name,
with a sentence saying the zeros are the absence of a check. The
affected-stage table is explicit (`AFFECTED_STAGES`):

| file | stages suspended | why not the others |
|---|---|---|
| `run_capture.rs` | all ten | the writer decides which fields a bundle has and what each one means |
| `run.rs` | all ten | the header, stage order, absorb rule, tags and opening order are the replay, and every rank downstream is taken at challenges the replay re-derived; `integrity` also transcribes the shape-word and opening orders |
| `boundary.rs` | **six**: 1, 3, 4, 5, 6, 7 | the replay absorbs the boundary ROOT with the rows and width the capture states, so stage 2 does not depend on it; nor do the plane index (8), the hash layer (9) or the group factor (10) — and a live test shows those four really run under a refused `boundary.rs` |

`stage7_channels` is in every list on purpose: it is a summary of the
others, so `channels()` is never handed a partial record. That is finding
**K4-F1**'s lesson kept rather than repeated.

## R6.6 The record corrected

Nothing is rewritten. Each correction is dated in place, beside what it
corrects.

| where | said | says now |
|---|---|---|
| `ZK60_NATIVE_RUN_GATE.md` §1 | "The bundle pins its own Rust sources … `run_capture.rs 51f26bc1`, `run.rs 02f7ee7e`, `boundary.rs 9860c35d` …", which reads as though the gate checked them | a dated correction: a bundle PINNING and a gate CHECKING are two different things; until tonight only `argument.rs`, `layout.rs`, `protocol.rs`, `plane_index.rs` and `shape.rs` were compared with a digest any tool had read |
| `ZK60_NATIVE_RUN_GATE.md` §6.3 | the four digests the terminal port pins, with "a pin that moved makes every slot NOT CHECKED" | plus a dated note: those four plus `shape.rs` are what THAT port pins; the other three are the run layer, pinned by `zk60_native_rg_runpins` since 2026-09-21 and by nothing before |
| `ZK60_NATIVE_RUN_GATE.md` §9.2 table, and §R5.4 of this ledger | `run.rs` `0426ad2 → 3247a89`: **12** added lines, 0 removed | **9** added, 0 removed (`git diff --numstat`); the §9.2 row is corrected in place with the date, and this line is the ledger's correction of its own §R5.4 row |
| `ZK60_NATIVE_RUN_GATE.md` §9.2 | "`layout.rs`, `protocol.rs`, `plane_index.rs`, `run_capture.rs` and `boundary.rs` are byte-identical" | true BETWEEN `0426ad2` and `3247a89`, which is what that sentence was about; across all five capture commits it is not, and the sentence now says so and points at §10 |
| `zk60_native_rg_terminals.NOT_PINNED_BY_ANY_RUN_GATE_TOOL` | "`boundary.rs`: … byte-identical at every capture commit so far (`3786a300`)" | **WRONG.** Bundles a–d pin `9860c35d`. Corrected, and the dict renamed `WAS_NOT_PINNED_BY_ANY_RUN_GATE_TOOL_UNTIL_20260921` — kept, with the old name as an alias, as the dated record of what was true until tonight |
| `zk60_native_rg_terminals`'s module docstring | "the bundle's own `source_pins` names `argument.rs`, `layout.rs`, `protocol.rs` and `plane_index.rs` … A pin that moved makes every slot NOT CHECKED" | plus the parenthesis naming where the other four are pinned, and that three of them were pinned by nothing before 2026-09-21 |
| `ZK60_NATIVE_RUN_GATE.md` §9.11 | "Finding K4-F2 is recorded, not repaired" | plus "*(CLOSED 2026-09-21 in §10)*" |

### R6.6b Finding R6-F1 (new tonight, small and real)

K4-F1's repair made `check_terminals`'s moved-pin arm return **every key a
caller reads** — but `stage8` builds the record's `terminal_identity` block
by naming keys one at a time, and it did not name
`refused_before_any_slot_was_evaluated`. So the JSON a reader gets on an
argument-layer refusal showed `slot_checks_attempted: 0` with **no sentence
saying the zero is the absence of a check**. The whole point of K4-F1's
repair was that a refusal reaches the caller intact; here it reached the
caller and not the record. Copied through now, and only when it is present,
so no healthy record gains a leaf. Found by writing the test that asserts
the sentence is in the record.

## R6.7 The leaf diff, and the suite

All ten in-scope bundles were re-run under the current tools, into the same
evidence directory each record of record lives in, and diffed **leaf by
leaf** against the committed bytes — taken with `git show HEAD:…` into
`results/zk60_native_run_gate_runpins/before/` **before any run**, so the
comparison is against the repository and not against a file the refresh
overwrote.

| bundle | identical leaves | changed | only in the NEW record | only in the OLD | UNCLASSIFIED |
|---|---:|---:|---:|---:|---:|
| `run-a-tame` | 2,749 | 4 | 47 | 0 | **0** |
| `run-b-zero` | 2,748 | 5 | 47 | 0 | **0** |
| `run-c-tame` | 3,528 | 5 | 47 | 0 | **0** |
| `run-d-zero` | 3,528 | 5 | 47 | 0 | **0** |
| `run-e-tame-tagged` | 3,861 | 4 | 53 | 0 | **0** |
| `run-f-zero-tagged` | 3,861 | 4 | 53 | 0 | **0** |
| `run-g-dense-s20` | 3,944 | 4 | 53 | 0 | **0** |
| `run-h-zero-s20` | 3,944 | 4 | 53 | 0 | **0** |
| `run-i-dense-k4` | 4,027 | 5 | 53 | 0 | **0** |
| `run-j-zero-k4` | 4,029 | 3 | 53 | 0 | **0** |

Every differing leaf decomposes the same way on every bundle:

* **46** (a–d) or **52** (e–j) new leaves, all under the new
  `run_layer_source_pins` block — the count differs only because the
  `bundles_written_at_them` arrays are longer for the digests three capture
  commits share;
* **+1** new leaf `tool_sha256/zk60_native_rg_runpins.py`;
* **2** changed tool hashes, `zk60_native_run_gate.py` and
  `zk60_native_rg_terminals.py`;
* **1–3** wall clocks (`/seconds` and two per-stage timers).

**Not one rank, disclosed dimension, challenge count, slot check, control
figure, channel count or receipt size differs on any of the ten.** The
channel table is still **25** entries, 2 constructed / 5 derived / 4
argued / **14 open** — round 6 added no channel and closed none.

### R6.7b The suite

| pattern | result |
|---|---|
| `test_zk60_native_run_gate_runpins.py` | **25 tests, OK**, 28.5 s |
| `test_zk60_native_run_gate*.py` | **184 tests, OK**, 71.6 s (round 5: 159) |
| `test_zk60_native*.py` | **360 tests, OK**, 285.1 s, one skip and one recorded expected failure (round 5: 335) |

**No earlier assertion had to move.** Round 5 had to widen six tests that
asserted exact sets the round deliberately changed; round 6 changed no
figure and no set, so every assertion of rounds 1–5 passes as written.

## R6.8 NEXT after round 6

1. **A Rust-lane ask, the writer side of the same discipline.** Four
   run-layer files are reached by a run and are in no bundle's
   `source_pins`, so they cannot be pinned from a bundle at all:
   `wire.rs`, `run_sink.rs`, `endpoint_g.rs`, `hash_domain.rs`. No run-gate
   port depends on any of them today (R6.4 gives the reason for each), which
   is exactly the fact that would stop being true if a port grew. Adding
   them to `run_capture.rs::SOURCE_FILES` is a two-line change on the Rust
   lane and would let this gate pin them the same way.
   *(GRANTED, and CORRECTED 2026-09-22 14:21 (round 9g): the Rust lane made
   that change at stage 27 (`f4697f9`) — `source_pins` 8 → **38** — so all
   four ARE pinned from a `/5-run` bundle, and the sentence "they cannot be
   pinned from a bundle at all" is false from that stage onward. Round 9
   §R9.3 / report §13.5 read the new pins;
   `zk60_native_rg_runpins.WRITER_SIDE_ASK_GRANTED` names this item as one
   of the two asks it answers.)*
2. **The attention profile's path** (R5.8 item 2, still open): the same
   widening for `private_attention.rs`, `wire.rs` and `witness.rs`, which
   two of the four toy captures reach.
   *(STILL OPEN as of 2026-09-22 14:21 (round 9g), checked rather than
   assumed: none of the three appears in `zk60_native_mask_commit.PATH_PINS`
   (20 entries) or `SOURCE_PINS` (10), in
   `zk60_native_terminal_polys.SOURCE_PINS` (8, which pins the attention
   profile's `argument.rs`, `layout.rs` and `protocol.rs` but not these), in
   any `zk60_native_rg_runpins` table, or in the writer's 38 — see §R9g.8.)*
3. **A shape with `lkv > 2`** (R5.8 item 3, still open).
4. The masked sumcheck / CFS channel, still the largest open one a port
   could close, and `zk60_native_pg_pcs` at `MSG != PAD`.
5. The run-wide preimage as ONE joint object; ruling R-3's machine
   assertion (gap G-R4), asked of the Rust lane.
6. Nothing in this round moves D8/D11 or ruling M-8's decision, and no
   channel was added or closed: the count stays **25**, with 14 open.

---

# Round 7 — the PREIMAGE construction for `A` and `H` (R6.8 item 4)

**Opened 2026-09-21 04:45 PDT** on lane `zk60-native-jointview`, same sole
writer, Python only. Nothing here is a privacy acceptance and no statement
here establishes a privacy property.

## R7.0 Why there is a round 7

Every earlier round recorded the same omission, in the same words. §2.5 of
the report: "`A` and `H` are **skipped, not faked**: their opening groups
have several members, so each claim's own published value is an extra
constraint, and the correction step that handles it lives in
`zk60_native_pg_pcs`, whose `MSG == PAD == 256` does not hold here." Round 1
skipped them for cost and for that assumption; rounds 2–6 did not come back
to them. R6.8 item 4 is the entry.

The two big commitments are the whole hidden state of a block: `A` holds the
activations (377 data rows of 1,024 `Fp` at rung-G, 481 at rung-K4), `H` the
LogUp side (468 / 612). Four of the thirteen commitments of a run have a
constructed preimage today, and they are the four SMALL ones. Round 7 asks
what the construction really costs on the two big ones, and does it.

**What the construction is** (the toy gate's P10, §1–2 of
`ZK60_NATIVE_PRIVACY_GATE.md`): fix the hidden data rows to the ALL-ZERO
hidden input — public, and no witness is read anywhere — and SOLVE exactly
over `Fp` for blinding (reserved mask-pair rows, proximity rows, the pads of
every row) that reproduces every published field value of that commitment's
view. Then RECOMPUTE the view from the solved blinding and compare it with
the capture entry by entry. A view captured from a DENSE generic hidden
input having a preimage at the all-zero input is the concrete content of
"this view does not depend on the input", for these challenges and these
linear channels.

## R7.1 Input (READ-ONLY, never written)

| bundle | witness | rung | source |
|---|---|---|---|
| `run-g-dense-s20` | fully dense generic | G | `…/wt-zk60-block125m/results/zk60_run_captures_20260920/` |
| `run-h-zero-s20` | all zero | G | the same |
| `run-i-dense-k4` | fully dense generic | K4 | the same |
| `run-j-zero-k4` | all zero | K4 | the same |

The two ZERO bundles are the sanity anchor: there the constructed preimage
should be consistent with what the prover itself committed.

## R7.2 Status

| # | item | state |
|---|---|---|
| Z0 | ledger skeleton, round 7 opened | done |
| Z1 | the linear system restated for `A` and for `H`: unknowns, equations, dimensions at both rungs, and the order it decomposes in | done — §R7.4, report §11.2–11.3 |
| Z2 | the tool: `zk60_native_pg_pcs`'s solve at `MSG != PAD`, with every primitive imported and the equivalence to the toy module asserted | done — commit `3d01f54`, §R7.5 |
| Z3 | built on all four bundles, every stage, every PCS commitment; time and peak memory measured | done — §R7.6 |
| Z4 | verified: the view recomputed entry by entry, plus the opened columns' digests re-derived and authenticated | done — §R7.6, **4,763,302 entries, 0 differing, 10,240 salted leaves** |
| Z5 | controls | done — §R7.6c, six, all fire |
| Z6 | the channel table recounted; what it does and does not establish | done — report §11.7–11.8, **25: 5 / 5 / 4 / 11** |
| Z7 | tests, evidence, report section, whole native suite | done — §R7.7, §R7.8 |

## R7.3 Commands and logs (round 7)

| what | command | log |
|---|---|---|
| the first pass, while the tool was still being edited | `bash results/zk60_native_run_gate_preimage/run.sh`, detached under `flock /tmp/zk-heavy.lock` with a `.done` marker | `…/preimage/run.log`, `run.done` (exit 0) — superseded by the run of record |
| **the run of record**: the four bundles under `--full-preimage`, each wrapped in `/usr/bin/time -v` so the peak resident set is measured; then the refresh and the leaf diff | `bash results/zk60_native_run_gate_preimage/run2.sh`, detached under the lock | `…/preimage/run2.log`, `run2.done`; `…/preimage/time-<bundle>.log` |
| the ten committed records, taken BEFORE any refresh run | `bash results/zk60_native_run_gate_preimage/before.sh` (`git show HEAD:results/<dir>/<bundle>.json`) | `…/preimage/before/` — ten files, 104–154 kB |
| the ten records of record re-run with the arm OFF | `bash results/zk60_native_run_gate_preimage/refresh.sh` (round 6's command lines, unchanged) | inside `run2.log` |
| each record diffed leaf by leaf, then classified | `bash results/zk60_native_run_gate_preimage/diff.sh` (`zk60_native_rg_recdiff.py`, then `zk60_native_rg_recclass.py`) | `…/preimage/diffs/*.diff.json`, `…/preimage/all_ten_bundles_unchanged.json` |
| the arm's own peak memory, isolated from the gate's four loaded bundles | `/usr/bin/time -v python3 results/zk60_native_run_gate_preimage/mem_probe.py <bundle>`, enqueued on the same lock | `…/preimage/mem_probe.log`, `.done` |
| this round's test file | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate_ahpreimage.py' -v` | `…/preimage/tests_ahpreimage.log` |
| the run-gate suite | `… -p 'test_zk60_native_run_gate*.py' -v` | `…/preimage/tests_run_gate_all.log` |
| the WHOLE native suite | `… -p 'test_zk60_native*.py' -v`, detached under the lock | `…/preimage/tests_native_all.log`, `.done` |

## R7.4 Results — the system, and the order it decomposes in

Report §11.2 has the dimensions table and §11.3 the solve. The two facts
worth repeating in the ledger, because they are what made round 1's cost
estimate wrong:

1. **The system is never assembled.** Per group, the message half is 1,024
   independent 2×2 `Fp` systems on one anchor pair, plus a correction of at
   most `3·(pair rows − 2)` unknowns; the pads are one `d × d` Lagrange
   basis built once per commitment and one `d`-length dot product per row.
   The largest object the solve touches is the commitment's own
   `rows × (n+Q)` matrix — 623 × 1,280 for `A` at rung-G.
2. **With the data block at zero every data row drops out of the
   accumulations**, exactly (a zero row contributes zero). That is what
   turns `A`'s 36 groups × 1,024 positions × 377 data rows from 14 million
   term-by-term operations into a few thousand.

**The order is computed, not assumed.** `H`'s zero-sum slot READS the `u`
pair that another group OWNS, so the gate builds the dependency graph and
reports it: on `H`, `groups_reading_another_groups_rows = {7: [8]}` and the
solve order is `0..6, 8, 7`. A test asserts every dependency comes earlier
in the order than the group that reads it.

## R7.5 Results — the module is the toy gate's solve, not a second one

`zk60_native_pg_pcs.py` is hash-pinned evidence of the TOY gate and this
lane does not edit it, so the two classes had to be re-derived at
`MSG != PAD`. Three mechanisms keep that from being a fork, and the third
is the real one:

| mechanism | what it is | asserted by |
|---|---|---|
| import, never copy | `solve_pair`, `kernel_basis`, `poly_div_exact`, `Lagrange`, `poly_eval` are the toy module's OBJECTS | `assertIs` per name, plus a source scan requiring no `def`/`class` of those names in the new module |
| a complete map | `DERIVED_FROM` (10 entries) and `NEW_HERE` (5) name every method | a test requires every method with a toy counterpart to be in the first and every other to be in the second |
| **the equivalence run** | the NEW classes at `msg_width == pad_width == 256`, on the tracked toy capture `40083e7a…` (roles `H` and `Input`), beside `zk60_native_pg_pcs`'s own | equal matrix digest, anchors, solve order, `d`, step records, failure list, **the whole solved matrix `X`**, exhibited-randomness digest, fibre dimension and every verification count |

A fourth, on the run side: round 1's singleton-group construction and round
7's general one must agree on **every** message entry of `B0` — two routes,
one object.

## R7.6 Results — what was constructed, verified and measured

**All ten PCS commitments of all four bundles, every stage.** Report §11.5
has the per-commitment table; the totals:

| bundle | witness | exhibited | view entries compared | differing | salted leaves | stage-11 s | whole gate s | peak RSS |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| `run-g-dense-s20` | fully dense generic | 10 / 10 | 1,097,847 | **0** | 2,560 | 70.8 | 170.3 | 677,368 kB |
| `run-h-zero-s20` | all zero | 10 / 10 | 1,103,569 | **0** | 2,560 | 71.2 | 170.6 | 677,316 kB |
| `run-i-dense-k4` | fully dense generic | 10 / 10 | 1,282,025 | **0** | 2,560 | 76.2 | 191.5 | 712,952 kB |
| `run-j-zero-k4` | all zero | 10 / 10 | 1,279,861 | **0** | 2,560 | 75.3 | 192.5 | 707,088 kB |
| **total** | | **40 / 40** | **4,763,302** | **0** | **10,240** | | | |

The peak resident set is the WHOLE GATE PROCESS, which holds four bundles
at once (`--other`, `--old`, `--cross-profile`); §R7.6b isolates the arm's
own cost. An `Fp2` entry counts once.

### R7.6b The arm's own memory

`mem_probe.py` loads ONE bundle and runs the arm over all ten commitments:

| figure | `run-i-dense-k4` (the largest of the four) |
|---|---:|
| peak after one bundle, its replay and its ten views | **214.6 MB** |
| peak after the arm | **317.2 MB** |
| **the arm's own peak** | **102.6 MB** |
| the arm's wall clock | 78.8 s |
| `/usr/bin/time -v` maximum resident set, whole process | 324,860 kB |

So the construction costs about **0.1 GB** and the gate's 0.7 GB is the
four bundles a control-bearing run holds, not the solve. Nothing here
approaches the box's limits, and nothing had to be streamed.

### R7.6c The controls

Six, each shown to pass on the honest capture first, each firing by name.
Report §11.6 has the refusal strings verbatim. In the record:
`controls_that_fire == controls_applicable == 6` on every one of the four
bundles, and a test re-digests the bundle directory to show no captured
file was written.

The two that matter most:

* **P-2** tests the gate's OWN criterion. The anchor pair still absorbs a
  moved group-vector entry, so the vector is reproduced — and then the
  verifier's own group identity fails, and nothing inside the kernel of the
  vector constraint can repair it, because the combination the identity
  reads is invariant on that kernel. A refusal that is a property of the
  channel, not of the search.
* **P-5** exhibits a case where both per-commitment preimages exist and no
  JOINT one does: one reserved mask row of `A@0` and one of `H@0`, each
  FORCED by its own commitment (each is the anchor of a group whose only
  non-data support is that pair, with an empty correction kernel), take
  different values at all 1,024 message positions. This is the concrete
  form of ruling **R-3** and the reason "a preimage for a RUN" is not a
  formality away.

## R7.7 The leaf diff, and what a default record gained

The arm is OFF unless `--full-preimage` is passed, so the ten records of
record keep every figure. They were nevertheless re-run and diffed leaf by
leaf against the committed bytes (`before/`, taken with `git show HEAD:…`
before any run):

| bundle | identical leaves | changed | only in the NEW record | only in the OLD | UNCLASSIFIED |
|---|---:|---:|---:|---:|---:|
| `run-a-tame` | 2,795 | 5 | 16 | 0 | **0** |
| `run-b-zero` | 2,794 | 6 | 16 | 0 | **0** |
| `run-c-tame` | 3,573 | 7 | 16 | 0 | **0** |
| `run-d-zero` | 3,573 | 7 | 16 | 0 | **0** |
| `run-e-tame-tagged` | 3,912 | 6 | 16 | 0 | **0** |
| `run-f-zero-tagged` | 3,912 | 6 | 16 | 0 | **0** |
| `run-g-dense-s20` | 3,994 | 7 | 16 | 0 | **0** |
| `run-h-zero-s20` | 3,994 | 7 | 16 | 0 | **0** |
| `run-i-dense-k4` | 4,078 | 7 | 16 | 0 | **0** |
| `run-j-zero-k4` | 4,078 | 7 | 16 | 0 | **0** |

Every differing leaf decomposes the same way on every bundle: **5** new
leaves under `stage11_full_preimage` (the arm was not requested, and the
sentence saying which three channels therefore stay OPEN), **11** new
leaves under the channel array (round 7's `how`, `excluded`,
`unopened_leaves`, `commitments` and `per_commitment_not_joint` keys on
the three channels it touched), **4** changed tool hashes (the gate,
`rg_ahpreimage`, `rg_ahcontrols` and the toy `pg_pcs`, now pinned by the
gate because the arm imports it), and **1–3** wall clocks.

**Not one rank, disclosed dimension, challenge count, slot check, control
figure, channel count or receipt size differs on any of the ten**, and the
classifier reports **0 unclassified leaves** on all ten. The ten records
still read **25** channels, 2 constructed / 5 derived / 4 argued / **14
open** — a default run is exactly what it was.

## R7.8 The suite

| pattern | result |
|---|---|
| `test_zk60_native_run_gate_ahpreimage.py` | **30 tests, OK**, 134.2 s |
| `test_zk60_native_run_gate*.py` | **214 tests, OK**, 216.4 s (round 6: 184) |
| `test_zk60_native*.py` | **390 tests, OK**, 457.6 s, one skip and one recorded expected failure (round 6: 360) |

**Two assertions of this round's own test file had to move, and no earlier
one did.** Both were mine and both were wrong about the record rather than
about the gate: the evidence directory's glob picked up
`all_ten_bundles_unchanged.json` as if it were a bundle record, and a live
assertion compared a Python dict with `int` keys against the JSON form with
string keys. Every assertion of rounds 1–6 passes as written, which is what
the leaf diff of §R7.7 predicted.

The 30 tests of this round split four ways: 5 that the module is not a fork
(the primitives are the toy gate's objects, no `def` of those names here,
the two maps are complete, the stage is off by default), 2 equivalence runs
against `zk60_native_pg_pcs` on a tracked toy capture, 12 on the record,
and 11 live on the bundles (including all six controls and the assertion
that no captured file was written).

## R7.9 NEXT after round 7

1. **The run-wide preimage as ONE joint object** — the largest thing round
   7 did not do, and control P-5 is the proof that it does not follow from
   what round 7 did. It needs the boundary planes shared between three
   commitments to take one value, which is a single system over the run's
   thirteen commitments rather than ten independent ones.
2. **The masked sumcheck / CFS channel**, now the largest open channel a
   port could close: `zk60_native_jv_cfs` and `zk60_native_mask_commit` are
   written at the toy's row layout and slot specs and would have to be
   re-derived from the shape, exactly as the PCS solve was here.
3. **Ruling R-3's machine assertion** (gap G-R4), still a Rust-lane ask.
4. **The 125M shape**: the solve is `O(rows · d²)` in the pads and
   `O(G · n · rows)` in the verification, and nobody has measured either
   there. Round 7 makes the measurement cheap to take.
   *(MEASURED, 2026-09-22 14:21 (round 9g) noting round 9 §13.8: `A@0` at
   125M is **365.1 s** against an `O(G·n·rows)` extrapolation of 1,400 s —
   the arithmetic bound bounds the VERIFICATION pass, not the solve, which
   still decomposes at 5,681 rows. The three singleton-group commitments
   cost **16×** the rung's, the message-width ratio and not the row ratio.
   The whole full arm is 1,292.7 s dense / 1,293.8 s zero.)*
5. R6.8 items 1–3 (the writer-side pin ask, the attention profile's path, a
   shape with `lkv > 2`) are untouched and still open.
6. Nothing in this round moves D8/D11 or ruling M-8's decision.

---

# Round 8 — the masking commitment `M` and the masked-sumcheck (CFS) channel at the SHAPED layouts (R7.9 item 2)

**Opened 2026-09-21 06:08 PDT** on lane `zk60-native-jointview`, same sole
writer, Python only. Nothing here is a privacy acceptance and no statement
here establishes a privacy property.

## R8.0 Why there is a round 8

R7.9 item 2, and the report's own §11.7: after round 7 the masked sumcheck /
CFS channel is **the largest open channel a port could close**. The run
gate's channel 7 — "the masked sumcheck round messages and the published
scalars" — has carried the same reason since round 1:

> the CFS analysis (`zk60_native_jv_cfs`) and the mask-row port
> (`zk60_native_mask_commit`) are written at the toy's row layout and slot
> specs; at the rung they would have to be re-derived from the shape.

The TOY gate closed three channels for `M` (`ZK60_NATIVE_JOINT_VIEW.md` §14:
`M`'s `q`, `M`'s proximity vector, `M`'s own 256 opened columns, 10 OPEN →
7) and a fourth for the masked rounds (`zk60_native_pg_cfs`). At the shaped
layouts all four are open. Round 8 is the port.

## R8.1 Input (READ-ONLY, never written)

| bundle | witness | rung | source |
|---|---|---|---|
| `run-g-dense-s20` | fully dense generic | G | `…/wt-zk60-block125m/results/zk60_run_captures_20260920/` |
| `run-h-zero-s20` | all zero | G | the same |
| `run-i-dense-k4` | fully dense generic | K4 | the same |
| `run-j-zero-k4` | all zero | K4 | the same |

Plus one tracked TOY capture for the equivalence run:
`results/zk60_native_captures_20260919/captures/40083e7a….json`.

## R8.2 Status

| # | item | state |
|---|---|---|
| M0 | ledger skeleton, round 8 opened | done |
| M1 | the `M` system restated at the shaped layouts from the Rust at the bundles' pinned commits; what in the toy port is layout-specific | done — §R8.4, report §12.2–12.3 |
| M2 | the shape-driven port, proved equal to the toy module at the toy's widths | done — commit `a4c0b83`, §R8.5, **19 of 19 figures** |
| M3 | run on all four bundles, every stage: rank, preimage, hash layer, pad budget | done — §R8.6 |
| M4 | controls | done — §R8.7, six, all fire |
| M5 | stretch: a JOINT run-wide preimage | done — report §12.7, `stage13_joint_run_preimage` |
| M6 | channel table, evidence, report section, tests, whole native suite | done — §R8.8, **28: 10 / 5 / 4 / 9** |

## R8.3 Commands and logs (round 8)

| what | command | log |
|---|---|---|
| the first pass, while the tools were still being edited (stage 13 did not exist yet) | `bash results/zk60_native_run_gate_mask/run.sh`, detached under `flock /tmp/zk-heavy.lock` with a `.done` marker | `…/mask/run.log`, `run.done` — **superseded by the run of record** |
| the ten committed records, taken BEFORE any refresh run | `bash results/zk60_native_run_gate_mask/before.sh` | `…/mask/before/` — ten files |
| **the run of record**: the four current bundles under BOTH arms, each wrapped in `/usr/bin/time -v` | `bash results/zk60_native_run_gate_mask/run2.sh`, ENQUEUED on the same lock while the first pass still held it | `…/mask/run2.log`, `run2.done`; `…/mask/time-<bundle>.log` |
| the equivalence run at the toy's widths | `python3 scripts/zk60_native_rg_mask.py --toy results/zk60_native_captures_20260919/captures --evidence results/zk60_native_run_gate_mask` | `…/mask/toy_equivalence.json` (inside `run2.log`) |
| the ten records of record re-run with both arms OFF | `bash results/zk60_native_run_gate_preimage/refresh.sh` (round 6's command lines, unchanged) | inside `run2.log` |
| each record diffed leaf by leaf, then classified | `bash results/zk60_native_run_gate_mask/diff.sh` | `…/mask/diffs/*.diff.json`, `…/mask/all_ten_bundles_unchanged.json` |
| this round's test file | `python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests -p 'test_zk60_native_run_gate_mask.py' -v` | `…/mask/tests_mask.log` |
| the run-gate suite | `… -p 'test_zk60_native_run_gate*.py' -v` | `…/mask/tests_run_gate_all.log` |
| the WHOLE native suite | `… -p 'test_zk60_native*.py' -v`, detached under the lock | `…/mask/tests_native_all.log`, `.done` |

## R8.4 Results — the `M` system at the shaped layouts

Report §12.3 has the table. The three facts worth repeating here, because
each was READ out of the Rust at the bundles' own pinned commits and not
carried over from the toy:

1. **`M` is fifty rows and thirty-four functionals at every shape of this
   schedule.** `layout.rs:895-896` sets `N_FUNCTIONALS = 34` and
   `M_ROWS = 2 * N_SLOTS + 4`, and asserts `M_ROWS == 50` (:1284) and
   `N_SLOTS + #Standalone + HOSTS.len() == N_FUNCTIONALS` (:1290). Neither
   is a function of the shape. What the rung moves is every `L_s`, through
   `Shape::slots`.
2. **The two slots whose `L` the repair moved are 08 and 09**, the two
   BILINEAR ones: `shape.rs:634-684` gives them `ext = 2` where every other
   slot has 1, and adds one to their degree exactly when `lkv > 0`. At
   rung-G they are `L = 23` and `26`; at rung-K4 `23` and `29`. The largest
   `L` is 72 at rung-G (slots 17, 18) and 77 at rung-K4 (slot 17).
3. **The declared order is the code's, and the code moved only in how it
   reads the slot triple.** `argument.rs` at the capture commits differs
   from the toy port's pinned bytes in the M-functional block by exactly
   `sum_weights(s)` → `sum_weights(&sh, s)`, and that function is
   `CfsMask::sum_weights(n + e, d)` over `sh.slots()[slot]`. The port
   therefore CHECKS `mask["specs"] == (main + ext, degree)` against the
   bundle's own shape, which is the check the toy could not make.

**The pad margin is thin and is worth a number.** `Q = 256` pads per a-row
against `D` distinct opened columns: `D` runs 246–254 over the twelve
stages of the four bundles, so the margin runs **2 to 10**. Control M-6
takes it away and the construction refuses; at the real budget the Cauchy
block is square and nonsingular. Nothing in the layout keeps `D` below
`Q` — it is the sampler drawing 256 indices with replacement out of 4,096 —
so the margin is a fact about these runs' challenges, not a guarantee.

## R8.5 Results — the port is the toy module's construction

`zk60_native_mask_commit.py` and `zk60_native_pg_cfs.py` are hash-pinned
records this lane does not edit. Round 8 does not edit them: a test asserts
`fae15b49…` and `4ee92422…` unchanged.

* **Fifteen objects imported, none re-implemented.** `IMPORTED_OBJECTS`
  lists them; one test asserts each name in the new module IS the toy
  module's object, another that the new module's source defines no
  `def`/`class` of those names.
* **Four maps, and tests that keep them complete.** `LAYOUT_SPECIFIC` must
  have exactly the five keys of report §12.2 and each must say what
  replaces it; `NEW_HERE` together with `DERIVED_FROM` must cover every
  definition in the file.
* **The equivalence run**: **19 of 19 figures equal** to the toy gate's
  committed record for capture `40083e7a…`, including both
  exhibited-randomness digests (`e0513e22…`, `f943d3a0…`).
* A fourth thing the toy gate never asked: at the toy's widths the
  CFS-solved coefficients also reproduce the toy capture's `M` opening
  entry by entry, which is the JOIN, tested where the figures are known.

## R8.6 Results — what was constructed and verified

Report §12.5 has the tables. Two things belong in the ledger rather than in
the report.

**Finding R8-F1 — a refusal in round 8's own stage would have been a
crash.** Found by reading my own code while the second pass was in flight:
`mask_cfs_stage` returned early when the CFS side did not solve, WITHOUT
the `entries_recomputed` block, and both summaries that add those counts up
— `mask_cfs_run` and the gate's `channels()` — indexed it directly. A
`KeyError` on exactly the case the gate exists to report. That is round 5's
finding K4-F1 one layer up, and the lane's own rule ("a refusal is never a
crash") forbids it. Fixed at commit `2c18a87`: a refusing stage now carries
zeroed counts, an `these_zeros_are_an_absence` note and a `why` naming the
refusal, both summaries use `.get`, and a test FORCES the refusal and
asserts every key a caller reads is present. **The fix moved two tool
files, so the run of record was taken a third time on frozen bytes**
(`run3.sh`), which is why three run scripts are in the evidence directory
and only the third is of record.

**Three passes, and what each was.** `run.sh` — the first, taken while
stage 13 was still being written; superseded. `run2.sh` — the second, taken
before R8-F1 was found; superseded. `run3.sh` — **of record**, on frozen
bytes, and it ends by running the three suites inside the SAME lock hold so
that nothing can interleave between the records and the tests that read
them. Every pass was detached under `flock /tmp/zk-heavy.lock` with a
`.done` marker, and the later ones were ENQUEUED on the lock while the
earlier still held it, so the box kept working without a session.

## R8.7 The controls

Six, all fire, on every bundle; report §12.6 has the two that say more than
was asked. The mechanics worth recording here:

* **Nothing is written.** Each perturbation builds a `_Shadow` of the stage
  — a shallow copy of `arguments` and `mask` with exactly one field
  replaced — and a test re-reads the bundle directory afterwards and
  compares `run.json`'s and every stage file's sha256 with the ones the
  loaded bundle carries.
* **M-1 names the ROUND by arithmetic, not by knowledge.** The solver's own
  refusal names the slot ("slot 0: no solution"). The round is found by
  re-solving the slot's system with each round's `degree + 1` equations
  dropped in turn and reporting which removals restore feasibility: exactly
  one does, and it is the round the control moved. A control that named the
  round from its own perturbation would be measuring nothing.
* **M-4 refuses three ways at each of slots 08 and 09**, and all three are
  worth having: the shape check `weights_vanish_above_L` goes false (and
  that check is the whole of the argument that the pads drop out of `V(a)`);
  `b` becomes inadmissible because a coefficient moved into the pad region
  changes `V(a)`; and a spec one VARIABLE short trips `combined_weights`'s
  own length assert, which is the Rust's own — "functional 9: 23 weights for
  a mask of 20 coefficients" at rung-G.
* **M-5's two coordinates are computed.** The free one and the forced one
  are found from the two slots' kernels; at rung-G and at rung-K4 the forced
  index is 3.

## R8.8 The channel table, the evidence and the suite

**The table grows, and that is the one thing round 8 does that rounds 2–7
did not.** Every earlier round moved statuses inside a fixed array (or
added one entry, in round 3). Round 8 adds THREE: `M`'s `q`, `M`'s
proximity vector and `M`'s own opened columns. The run gate never graded
them separately — channel 3 excluded `M`'s opening in one word and channel
7 carried the whole masking layer — while the TOY gate has graded them
separately since its §14. So the array goes **25 → 28**, and with both arms
off the three new entries are OPEN.

| record set | with both arms OFF | with both arms ON |
|---|---|---|
| the ten records of record | **28: 2 / 5 / 4 / 17** (planeindex: 2 / 4 / 4 / 18) | not taken |
| round 8's four | not taken | **28: 10 / 5 / 4 / 9** |

**Four assertions of earlier test files had to move**, and they are the only
ones: the channel-count assertions in
`test_zk60_native_run_gate_{s20,planeindex,tagged,k4}.py`. Each is about
the record's SHAPE — three entries added, all OPEN with the arms off — and
not about any figure. Round 7 could say "no assertion of rounds 1–6 had to
move"; round 8 cannot say that, and says so instead.

**The leaf diff.** The ten records of record were re-run with both arms off
and diffed leaf by leaf against the committed bytes taken into `before/`
first. The classifier gains two classes: the new `stage12_mask_and_cfs`
block and the new `stage13_joint_run_preimage` block; the three added
channel entries and the moved counts fall under the channel classes round 3
established. **0 unclassified leaves on all ten**, with 2,326 leaves in the
channel array, 110 in the counts, 50 in each new stage block, 60 tool
hashes and 23 wall clocks.

**Round 7's OWN evidence had to be re-taken.** Its four records pinned tool
digests round 8 moved, and round 7's own
`test_the_evidence_came_from_the_tool_bytes_now_in_the_tree` is the test
that said so. Re-run under `--full-preimage` with the masking arm off:
every stage-11 figure identical (1,097,847 / 1,103,569 / 1,282,025 /
1,279,861 entries, 0 differing, 2,560 salted leaves each), the table
25 → 28 at 5 / 5 / 4 / 14, and a dated note added above §11.7 of the report
saying so while leaving §11.7 as written.

**The suite.** `test_zk60_native_run_gate_mask.py` **42, OK**;
`-p 'test_zk60_native_run_gate*.py'` **256, OK** (round 7: 214);
`-p 'test_zk60_native*.py'` **432, OK**, 437.8 s, one skip and one recorded
expected failure (round 7: 390). Logs: `…/mask/tests_*.final.log`, taken
inside the run of record's own lock hold so that nothing could interleave
between the records and the tests that read them.

**Five assertions of earlier test files moved**, all channel counts, all
about the record's SHAPE: `s20`, `planeindex`, `tagged`, `k4` and
`ahpreimage`.

## R8.9 NEXT after round 8

1. **The joint LAW** — obligation O-R2 / gap G-R4, and now the single
   largest thing between this gate and a privacy argument. Rounds 7 and 8
   between them exhibit a preimage for the whole run's linear view; what no
   gate can supply is that the honest prover's draws are UNIFORM on that
   fibre. It is a Rust-lane and lemma question, not a Python one.
2. **The hash layer's HIDING** (M-2, M-3), still ARGUED, and now the second
   largest. Every OPENED column of every commitment including `M` is
   re-hashed and re-authenticated; an unopened leaf is a salted digest of
   data nothing publishes and no preimage reaches it.
3. **The honest unmasked rounds of one slot on a synthetic public
   fixture**, the writer-side ask of `ZK60_PRIVACY_CASE_FIRST_MVP.md` §4.3.
   Without it the masking layer's fixed data stays a NAMED element of the
   channel's data space rather than the zero witness's own transcript, and
   that is the one honest gap in §12.5.
4. **A writer-side pin for `zk.rs` and the seven `zkp-core` files.**
   `run_capture.rs::SOURCE_FILES` pins eight `private_block` files and no
   others, so the mask port's dependence on `zk.rs`, `sumcheck.rs`,
   `ntt.rs`, `field.rs`, `rng.rs`, `pcs.rs`, `merkle.rs` and
   `transcript.rs` cannot be checked from a bundle at all. Three of those
   are checked by computation instead; five are not. This is R6.8 item 1
   with a longer list.
5. **The 125M shape.** `M` keeps fifty rows there, but every `L_s` grows
   and `mask_commit` itself asserts `L_s + MASK_Q <= 512`. Whether that
   survives at 125M is a Rust-lane question; `derive_mask_domain` refuses
   rather than assumes, so a bundle at a shape that moved it would leave
   the stage NOT CHECKED by name instead of quietly wrong.
6. **The attention profile's 18-slot masking layer** is untouched here, as
   is R6.8 item 2 (the attention profile's path pins).
7. Nothing in this round moves D8/D11 or ruling M-8's decision, and nothing
   in it is a privacy acceptance.

---

# Round 9 — the gate at the **125M shape**, the first time anything is measured there (R8.9 item 5)

**Opened 2026-09-21 09:00 PDT** on lane `zk60-native-jointview`, same sole
writer, Python only. Nothing here is a privacy acceptance and no statement
here establishes a privacy property.

## R9.0 Why there is a round 9

Every round so far ends with the same line, in the report's own words:
**"Nothing at the 125M shape."** §5 says "It says nothing about the 125M
shape"; §9.11 says the exact-rank computation over thousands of rows per
commitment "is still untried, and a 484 MB run is still more than this gate
ingests"; §11.8 says "anything at the 125M shape, where `A` has thousands of
rows"; §12.8 says "Nothing here was measured there". R8.9 item 5 is the ask.

Two things the Rust lane shipped make the round possible: stage 27's binary
array store (schema `hashline-native-capture/5-run`), which turns a ~653 MB
text bundle into ~280 MB with one memory-mappable `arrays.bin`, and two
two-block captures at the 125M shape.

## R9.1 Input (READ-ONLY, never copied into this repository)

| bundle | witness | bytes | source commit |
|---|---|---|---|
| `m125-capture-dense-l2` | fully dense public weights, generic hidden input | 281,106,431 | `f4697f9` |
| `m125-capture-zero-l2` | the all-zero hidden input | 272,660,458 | the same |

Both at `/home/victor/zk60-artifacts/`, OUTSIDE the repository. Only records,
logs, manifest hashes and small evidence are committed.

## R9.2 Status

| # | item | state |
|---|---|---|
| N0 | ledger skeleton, round 9 opened | done |
| N1 | a `/5-run` loader: lazy array resolution with length, digest and element-type checks; refuse by name, never crash; equivalence proved against a `/4-run` development bundle re-encoded by this lane's own encoder | done — commit `adfd9c4`, §R9.4, report §13.2 |
| N2 | the source pins at `f4697f9` read and the pin tables extended; the newly pinned shared files classified | done — commit `00cf269`, §R9.5, report §13.5 |
| N3 | the gate at 125M, stage by stage, with time and peak RSS: (a) replay, (b) hash layer, (c) terminals, (d) disclosure and ranks, (e) the preimages | (a)-(d) done, (e) PARTIAL and said so — §R9.6, report §13.4 and §13.8 |
| N4 | the comparison table against the development shapes, predicted BEFORE the record is read | done — §R9.7, report §13.6 |
| N5 | controls at 125M | done — §R9.8, report §13.7 |
| N6 | records, report section, dated corrections to every "nothing at 125M" sentence, tests, whole native suite | done — §R9.9, report §13 and its seven dated corrections |

## R9.3 Commands and logs (round 9)

Every heavy run is DETACHED under `flock /tmp/zk-heavy.lock` inside
`systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0`, with a
`.done` marker holding the exit code — the orchestrator's amendment of
2026-09-21, because a Rust 125M proof of about 10 GiB may be queued on the
same lock and the two do not fit in 15 GB together.

| what | command | log / marker |
|---|---|---|
| the loader's equivalence, both ways | `TMP5RUN=<scratch> bash results/zk60_native_run_gate_m125/loader_equivalence.sh` | `…/m125/loader_equivalence*.json` |
| the load probe (time, memory, pins) | `python3 scripts/…` under the lock | `…/m125/probe_load.log`, `.done` |
| the prediction, validated on both development shapes | `python3 scripts/zk60_native_rg_predict.py --bundle <dense> --validate <dev>:<record> --validate <dev>:<record>` | `…/m125/predict.log`, `prediction_m125.json` |
| the dense bundle, (a)-(d) + channels | `python3 scripts/zk60_native_rg_m125.py --bundle <dense> --other <zero> --stages load,replay,hash,terminals,commitments,boundary,preimage,channels` | `…/m125/dense-c.log`, `m125-dense.json` |
| the zero bundle, the same | the same with the bundles swapped | `…/m125/zero-a.log`, `m125-zero.json` |
| the masking arm | `--stages load,replay,mask` | `…/m125/dense-mask.log`, `m125-dense-maskprobe.json` |
| the full preimage, the three singleton-group commitments | `--stages load,replay,commitments,fullpreimage --only E-Input,E-Output,B0` | `…/m125/dense-pre-small.log` |
| the full preimage, `A@0` alone (the measurement §13.8 rests on) | `--only A@0` | `…/m125/dense-pre-a0.log` |
| the whole control set | `--stages …,mask,runcontrols,channels --controls --cross-profile <run-i-dense-k4>` | `…/m125/dense-controls.log` |
| the comparisons | `zk60_native_rg_witcmp.py`, `zk60_native_rg_m125table.py` | `…/m125/{witness,shape}_comparison_*.json`, `comparison_table_m125.json` |

## R9.4 Results — N1, the `/5-run` loader

Report §13.2 has the table. Three things belong here.

1. **The decoder is a SEQUENCE, not a converter.** `FpArray` and `Fp2Array`
   wrap a `numpy` view into the memory-mapped `arrays.bin` and implement
   `__len__`, `__getitem__` (including slices), `__iter__` and `__eq__`
   against a list, so a resolved member reads exactly like the JSON list
   `/4-run` writes in its place. **Not one module downstream of the loader
   changed**, which is why the whole-gate equivalence run is a leaf diff
   with nothing measured moving.
2. **Thirteen refusal cases, each asserted to be the NAMED refusal.** A
   missing reference key, an undefined one, an unknown `elem`,
   `bytes != len * width`, a negative or non-integer field, a malformed
   digest, a range past the end, the wrong digest for the right bytes, an
   unreduced `u64`, an absent store, a store whose length is not the
   manifest's, a reference under a member the schema never externalises,
   and a reference as a list element. Rounds 5 and 8 each found a refusal
   path in this lane that raised instead of reporting; this is the
   discipline written as tests rather than as a comment.
3. **The equivalence is the READER's test and says so in its own record.**
   The lane's rehearsal wrote no `/5-run` bundle at a development shape into
   any repository, so it is built the other way round — re-encode, load
   both, compare. The writer has its own byte-for-byte test and this does
   not stand in for it.

## R9.5 Results — N2, the pins

Report §13.5 has the table of the six moved files. Two things belong here.

**The generator-domain change is the one that needed the most care, and it
is invisible to the gate by construction.** Lane stage 26 (the ruling on
finding B-1) moved four OS-seeded generators onto domains that name what
they are for: the single-block prover (`protocol.rs`), the run prover
(`run.rs`), the two external endpoints (`endpoint_g.rs`) and — written but
deliberately not called — a boundary (`boundary.rs`). Every one of those is
the BLINDING stream, not the transcript. No absorb, no squeeze, no label and
no published byte moves, and the round-9 replay reproducing all 27,828
challenges of a bundle written under the new domains is the machine
statement of that.

**The writer-side ask is granted and the correction is dated.** R6.8 item 1
and R8.9 item 4 asked for `zk.rs` and the `zkp-core` files to be pinned by
the writer. Stage 27 did it: 15 own files and 23 shared, 38 in all. All 23
shared files are byte-identical to `3247a89` and the eight a port depends on
are at exactly the digests round 8 recorded, so §10.2's reason (b) — "the
writer does not pin it" — is now false for the four run-layer files it names
and carries a dated correction. Reason (a), that no port transcribes them,
is unchanged.

## R9.6 Results — N3, the gate at 125M

Report §13.4 has the stage table and §13.8 the preimage. Three things belong
here.

**FINDING M-F1 is the round's result and its full reading is report §13.3.**
In one line: every zero-check port hardcoded `n_pad = 1`, three domains at
125M do not pad, and their three host slots draw two fewer definition
challenges each. Repaired by deriving `pad_on` the way `argument.rs` does,
with a named refusal in place of the `IndexError`. Both development shapes
are unchanged at 69 of 69.

**What (e) cost, and the estimate that was wrong.** The three
singleton-group commitments are constructed and verified at 125M in 133.0 s
(44 s each, 16× the rung's, which is the message-width ratio and not the row
ratio), 145,118 entries with none differing and 768 salted leaves. `A` and
`H` were ESTIMATED at 1,400 s and 1,330 s apiece from round 7's measured
figures and the verification's `(G+1)·rows·(n+Q)` term. Then `A@0` was run
alone as the measurement the estimate is checked against: **365.1 s at
2,539 MB, 2,070,138 entries recomputed and compared with none differing,
256 salted leaves, a fibre of 2,817,876 Fp over 5,484,800 blinding
unknowns, and the solve only 73.2 s of the 365.** The estimate was 3.8×
pessimistic, and the reason is that the `(G+1)·rows·(n+Q)` term bounds the
VERIFICATION pass and not the solve, which still decomposes at 5,681 rows
exactly as report §11.3 says. Round 1 skipped `A` and `H` for cost and
round 7 found the cost was never the obstacle; round 9 estimated
twenty-three minutes and measured six. **Twice now the cost estimate for
this construction has been the thing that was wrong.**

**Then the whole arm was run and it closed.** `m125-dense-full`, detached
under the lock inside the 8 GB ceiling: **5,819.4 s total, peak RSS
5,484 MB**, of which the arm itself is **1,292.7 s (21.5 min)** — `A@0`
315.3, `A@1` 317.1, `H@0` 249.6, `H@1` 267.0, the three small ones 43.7 /
50.1 / 49.9 — and round 7's six controls **P-1 … P-6, all six firing**, the
remaining ~74 minutes. All seven PCS commitments have a constructed and
verified zero-data preimage: **8,263,736 entries recomputed and compared,
NONE differing, `first_mismatch` null, 1,792 salted leaves
re-authenticated**; fibres 2,817,876 `Fp` per `A`, 1,376,172 per `H`, 32
for the boundary, 0 per endpoint.

**And stage 13 holds at 125M** — the joint run-wide preimage §12.7 built at
the development shapes: **8,296,654 entries, 0 differing, 2,304 salted
leaves**, the four couplings enumerated and each checked, and C1's **128
identified row pairs over three planes, all 128 DATA rows on both sides and
none touching a blinding row**.

**A bookkeeping distinction kept rather than smoothed over.** The full-arm
pass reads 28 channels at **10 / 3 / 4 / 11** and the (a)–(d) records of
record read **28 at 2 / 5 / 4 / 17**; neither is round 8's 10 / 5 / 4 / 9,
because the full-arm pass did not run stage 8 (so the two channels stage 8
grades DERIVED stay OPEN in it) and the (a)–(d) pass ran no arm. A single
pass carrying every stage would read 10 / 5 / 4 / 9 and is enqueued as
`m125-dense-everything`; until it lands **no 125M record carries the whole
table and nothing here claims one does**.

*(CORRECTED 2026-09-22 14:21 (round 9g): **it landed, in round 9c** — twice
(`dense-everything.done` and `dense-everything2.done`, both exit 1, 2:17:40
and 2:09:58, identical figures), every one of its thirteen stages RAN, and a
125M record now reads the full **28 at 10 / 5 / 4 / 9**. The exit 1 is
control bookkeeping and is decomposed leaf by leaf in
`results/zk60_native_run_gate_9c/dense_everything_exit1_decomposition.json`.
So "no 125M record carries the whole table" is false from 2026-09-21/22
onward. The two figures above — 10 / 3 / 4 / 11 and 2 / 5 / 4 / 17 — are
unchanged and still describe the passes that produced them. See R9c.4 and
report §15.1 item 5 / §15.2.)*

Also enqueued and named rather than guessed at: the zero bundle's full-arm
run, the fixed control run, the two default records re-taken on frozen
bytes, the ten-record refresh and both suites — each with its own log and
`.done` marker under `results/zk60_native_run_gate_m125/`. Any later
session reads the markers and integrates.

### R9.6b The order the queue was run in, and why

Every heavy run took `/tmp/zk-heavy.lock`, so they serialise; follow-ups
were ENQUEUED on the same lock while an earlier one still held it, and each
self-starts when the lock frees, session or no session. The tool bytes were
frozen before the last batch (`dense-final`, `zero-final`, `refresh2`,
`tests_final`) was enqueued, so those are the passes of record for anything
whose record pins a tool digest — round 8's three-pass discipline, kept.

**The masking arm is cheap at 125M and that was not obvious.** `M` keeps 50
rows and 34 functionals because `layout.rs` sets both as constants of the
slot table; what grows is every `L_s`, and the mask domain (`log_dom` 12,
`MASK_Q` 256, `MASK_MSG` 512) does not move at all. So the arm costs 9.4 s a
stage at 125M against 6 s at the rung, and R8.9 item 5's question is
answered with 139 of headroom.

## R9.7 Results — N4, the comparison

`comparison_table_m125.json`: **180 figures — 55 INVARIANT and all 55
identical at all three shapes, 61 a matter of `L = 2` against `L = 3`, 64
SCALING with 5 predicted by name and 5 of 5 holding, and ZERO
UNEXPLAINED and ZERO BROKEN INVARIANTS.**

The prediction came first and was validated first: `zk60_native_rg_predict`
reproduces the committed rung-G and rung-K4 records to the unit on every
figure it names, and only then was it run at 125M. One term is honestly not
derived — a slot's definition-draw count is a property of its composition,
not of the shape — and the record says so rather than letting a number that
happened to come out right stand for a derivation.

Dense against zero at 125M: **128 compared, 124 identical**, the four that
differ being two distinct-sampled-column counts and the two pad margins that
derive from them. The same classes rounds 4 and 5 found.

## R9.8 Results — N5, the controls

**FINDING M-F2: control M9-1 found a hole in round 9's own loader.** The
first form of `ArrayStore.resolve` cached a verified array by its DIGEST, so
the writer's dedup would not be paid for twice here. M9-1 moves a
reference's byte range by eight bytes and keeps everything else — including
the digest string — and it did not fire: the digest was already in the set,
the re-hash was skipped, and a reference naming a seen digest at a different
OFFSET was accepted. That is precisely the check the digest is in the
reference for. The cache is now keyed on `(offset, bytes, digest)`; the
distinct-array counters are unchanged, so the dedup still costs one hash,
and a moved range is re-hashed and refused. Written down because the shape
of the mistake — a cache key that is a proper subset of what the check is
about — is reusable.


**FINDING M-F3: three controls written at `L = 3` crashed at `L = 2`.**
CT-8 (round 2) and GQ-2 (round 4) name stage 2 as a literal — the last
stage of a three-block run — and C5 (round 1) builds a `Stage` directly,
which defaults to schema `/4-run`. All three raised at 125M, and CT-8's
`IndexError` took the whole terminal stage with it, CT-1..CT-7 included.
All three now derive what they were naming: `blocks - 1` for the stage and
the other bundle's own schema and store for the swapped stage. A control
that crashes is not a control (K4-F1), and nothing before this round had
ever run these three at an `L` other than 3.

**M-F3's first repair was PARTIAL.** `GQ-2` names stage 2 in two places —
the `GQ-3`/`GQ-4` aim list and its own `("GQ-2", 2, 9, 1)` tuple — and the
first pass fixed only the aim list; the next control run raised
`IndexError` again, 806 s in, taking the whole stage-10 arm with it. A
partial repair of "a control that crashes" is not a repair, and what caught
it was RUNNING the controls again rather than reasoning about the diff.
Both sites derive the stage from `blocks` now. Round 9's own `M9-2` had the
same shape of bug — a shadow bundle built by copying `__dict__`, while
`RunBundle.name` is a property — and it was found the same way. Both
repaired; M9-2 now shows 2,303 of 2,304 columns authenticating against the
honest 2,304.

Report §13.7. Three new ones, and the third could not exist before:
**M9-3** makes each unpadded domain look padded to the port and requires its
host slot to refuse BY NAME with both numbers in the message. At every
development shape every domain pads, so the control has nothing to perturb
there and is skipped by name — which is exactly why finding M-F1 waited for
this round.

*(CORRECTED 2026-09-21 (round 9b, finding P-F2) and re-stated 2026-09-22
14:21 (round 9g): **when this was written M9-3 had never fired.** It read
`index.geom`, which a `PlaneIndex` does not have, so it reported itself
inapplicable rather than perturbing anything, and in both 125M passes the
run-control stage raised before reaching it — so there was no record in
which it fired, at any shape, and the refusal message report §13.7
attributed to it is **CT-9's**. Round 9b repaired it and verified it at
rung-P2 (§R9b.7); round 9c fired it at 125M in all three directions inside
`dense-everything` (R9c.4). Its `ok` is still false because its own
criterion asks for a draw-count message it cannot produce — see R9c's open
item 2. Also stale in the sentence above: report §13.7's "Every control of
rounds 1–8 that the shape admits is fired at 125M unchanged" was true only
of the families a pass carried through, which is finding M-F3's story; the
terminal and run-control families did not land at 125M until round 9c.)*

## R9.9 Results — N6, the records and the report

Seven sentences of the report that said nothing can be or has been measured
at 125M now carry a dated correction in place (§5, §9.11, §11.8, §11.10,
§12.8, §12.10 and §2.3's `n = 1,024`). Nothing is rewritten.

*(EXTENDED 2026-09-22 14:21 (round 9g): that sweep missed four sentences of
the same kind — report §6.7, §7.9, §8.11 and §13.8's own "until it lands no
125M record carries the whole table" — and two of the corrections it wrote
(at §11.8 and §11.10) went stale inside round 9 itself when the full-arm
pass landed. All six now carry their own dated block, and §13.9's table
carries a pointer to them. R9g.4 lists every occurrence with its
decision.)*

## R9.10 IN FLIGHT at the close — read the markers, then integrate

Round 9 closed with eight runs enqueued on `/tmp/zk-heavy.lock`, each
detached with its own log and `.done` marker under
`results/zk60_native_run_gate_m125/`. **None of them can change a claim
this round makes**: every figure in report §13 comes from a record already
committed. What they add is coverage, and the first thing a later session
should do is `ls *.done`, read the exit codes, and integrate.

| marker | what it adds | what to do with it |
|---|---|---|
| `zero-full` | **LANDED**: the arm in 1,293.8 s (dense: 1,292.7), all seven exhibited, 8,256,579 entries / 0 differing / 1,792 leaves; masking 32,918 / 0 / 512; stage 13 **8,289,497 / 0 differing / 2,304 leaves**, four couplings respected, C1 128 pairs all data rows. Every figure differs from the dense bundle's by exactly **7,157**, the sampled-column difference | integrated in report §13.8, with **finding M-F4** beside it |
| `dense-everything` | ONE 125M record carrying every stage | the only record that can read **28 at 10 / 5 / 4 / 9**; report §13.8 says explicitly that no record does until it lands |
| `dense-controls2` | the CT / GQ / C1–C6 / CH families after the M-F3 repair | the count of controls that fire at 125M, which §13.7 currently gives only for M9-1..3 and round 8's M1–M6 — *(CORRECTED 2026-09-22 14:21, round 9g: `dense-controls2` CRASHED, exit 1, and delivered no control set; the families landed instead in `dense-everything`, round 9c)* |
| `dense-final`, `zero-final` | the two (a)–(d) records re-taken on FROZEN bytes | these supersede the committed `m125-dense.json` / `m125-zero.json` for their tool pins; every figure must be identical |
| `refresh` + `diff.sh` | **LANDED**: the ten development records re-run and leaf-diffed — **0 UNCLASSIFIED on all ten**, 2,855–4,140 identical leaves each, every difference one of nine tool hashes, one to three wall clocks, the seven `array_store` leaves or the five `shared_files` leaves. Not one rank, disclosed dimension, challenge count, slot check, control figure or channel count moved | integrated in report §13.8b. `refresh2` is a redundant second pass on the same frozen bytes |
| `tests_native_all` | **LANDED**: **474 tests** (round 8: 432), one skip, one expected failure; five failures and one error, every one an earlier round's exact-set assertion that round 9 widened on purpose (report §13.8c) — all six now updated with the reason beside each | integrated; `tests_final` and `tests_run_gate_all` re-run them after the repairs |
| `retake78` | rounds 7 and 8's OWN evidence re-taken on frozen bytes | their `test_the_evidence_came_from_the_tool_bytes_now_in_the_tree` is what demanded it; NO stage-11 or stage-12 figure may move |

The ledger names them rather than predicting their outcomes, which is the
marker protocol's whole point: the box kept working, and a figure nobody
has read is not a figure.

*(CORRECTED 2026-09-22 14:21 (round 9g): **all of them have since landed
and been read**, so the four rows still marked as pending above are the
state at round 9's close and not the state now. `dense-everything` exit 1
(twice) — the whole table, **28 at 10 / 5 / 4 / 9**, integrated in round 9c
(R9c.4, report §15.2). `dense-controls2` exit 1 — it CRASHED and delivered
no control set, which round 9b recorded (report §14.9) and round 9c then
answered from `dense-everything`, where **M9-3 fires at 125M in all three
directions**. `dense-final` / `zero-final` exit 0, integrated. `retake78`
exit 0 at 15:37 on 2026-09-21. The marker files are in
`results/zk60_native_run_gate_m125/`, which is where any later session
should still start.)*

## R9.11 NEXT after round 9

0. **FINDING M-F4 — repair `zk60_native_rg_mjoint`'s message.** On a pass
   run without `--controls`, stage 12's `ok` is false purely because its
   controls were not requested, and stage 13 then says *"round 8's arm is
   off or did not close, so there is nothing to join on the masking
   side"* — when the arm closed and only its controls were not asked for.
   Every figure in `m125-zero-full` is computed and correct; the sentence
   about them is not. It is K4-F1 and R8-F1 one level further out: a
   message that does not distinguish "did not run" from "did not close".
   Deliberately not repaired inside round 9, because
   `m125-dense-everything` is running against these bytes and a record must
   pin bytes still in the tree.
1. **A single all-stage record** — enqueued above. Both bundles' full arms
   are done: all seven PCS commitments constructed and verified (dense
   8,263,736 entries, zero 8,256,579, none differing either way) and
   §12.7's JOINT run-wide preimage holding at 125M on both (8,296,654 and
   8,289,497 entries, 0 differing, C1's 128 pairs all data rows).
2. **More than two blocks at 125M.** `L = 2` has one internal boundary; the
   model has twelve blocks and eleven. Nothing in the gate depends on `L`,
   but nothing has exercised it at this shape either.
3. **The joint LAW** (O-R2 / G-R4) and **the hash layer's HIDING** (M-2,
   M-3) are exactly where round 8 left them, and they remain the two
   largest things between this gate and a privacy argument.
4. **The honest unmasked rounds of one slot on a synthetic public fixture**
   (R8.9 item 3) is unchanged.
5. Nothing in this round moves D8/D11 or ruling M-8's decision, and nothing
   in it is a privacy acceptance.

## R9b.0 Why there is a round 9b

Round 9's finding **M-F1** — three zero-check slots whose hosted domain is
an exact power of two draw two definition challenges fewer, and every port
hardcoded `n_pad = 1` — could only be found at 125M, and its control
**M9-3** exists only there. A finding whose regression costs three minutes
and 281 MB of bundle is a finding that will be re-broken. Lane stage 30
(`baea9b2` … `b923d07`) built the shape that fixes that: **`rung-P2`**, 32
tokens / width 96 / hidden 256, 12 query heads of 8 over 4 key-value heads,
in which `T`, `Kv` and `F` sit exactly on their pads and `Ht`, `L`, `D`,
`Q`, `S`, `Tab` pad — the same split as 125M, at a shape the ordinary test
suite can run in seconds.

The second half of the round is bookkeeping with a deadline: round 9 closed
with eight detached jobs on `/tmp/zk-heavy.lock` (R9.10), and the ones that
have landed have to be read, leaf-diffed and integrated before the next
round writes over them.

## R9b.1 Input (READ-ONLY, never copied into this repository)

| bundle | witness | bytes | source commit |
|---|---|---|---|
| `run-k-dense-p2` | dense generic input at `rung-P2` | 16,001,981 (`arrays.bin` 9,097,448) | `4ccbad1` |
| `run-l-zero-p2` | the all-zero input at `rung-P2` | 15,912,181 (`arrays.bin` 9,014,520) | `4ccbad1` |

Both in the LANE's worktree at
`/home/victor/wt-zk60-block125m/results/zk60_run_captures_20260920/`, the
same directory every development bundle of rounds 1–8 is read from and the
same way the tests reach them. Schema `hashline-native-capture/5-run`,
two blocks, public tables' values included, `privacy_review_complete:
false`.

## R9b.2 Status

| # | item | state |
|---|---|---|
| P0 | ledger skeleton, round 9b opened | done — `46be333` |
| P1 | the pins between `f4697f9` and `4ccbad1`, hunk by hunk, with a verdict on the lane's "nothing sent, absorbed or drawn changed" | done — `dfecca3`, §R9b.4, report §14.2; **finding P-F1** |
| P2 | `rung-P2` added to the prediction module and the figures written BEFORE the gate is run there | done — `dfecca3` (committed before the run), §R9b.5, report §14.3 |
| P3 | the whole gate on both bundles, every arm, against rung-K4 | done — `3ae2569`, §R9b.6, report §14.4–14.5 |
| P4 | M9-3's development-shape twin, in the ordinary suite | done — `3ae2569`, §R9b.7, report §14.6; **finding P-F2** |
| P5 | the landed 125M jobs of R9.10 read and verified | done — §R9b.8, report §14.9 |
| P6 | report section "Round 9b", the records re-taken, the suite | done — §R9b.9, report §14 and its four dated corrections; suite 507, exit 0 |

## R9b.3 Commands and logs (round 9b)

Development-shape work is light and was run directly, detached with a log
and a `.done` marker, inside `systemd-run --user --scope -p MemoryMax=4G
-p MemorySwapMax=0`. **No new 125M computation was started for task A**;
the two 125M records of record are re-taken once each under
`flock /tmp/zk-heavy.lock` at 8G, enqueued and named below.
*(As of 2026-09-21 (round 9b), noted 2026-09-22 14:21 (round 9g): 4G for
light work and 8G for a heavy run is right and is what this round did.
Round 9c then found the WHOLE `test_zk60_native*.py` suite had outgrown 4
GiB in one process, so **8G is the standing cap for a suite run** from that
round on — see R9c.8 and R9c.9 item 4.)*

| what | command | log / marker |
|---|---|---|
| the prediction, validated on three committed records | `python3 scripts/zk60_native_rg_predict.py --bundle <run-k> --validate <run-g>:<rec> --validate <run-i>:<rec> --validate <m125-dense>:<rec>` | `…/p2/predict.log`, `.done`, `prediction_p2.json` |
| the whole gate, both bundles, both arms | `results/zk60_native_run_gate_p2/run.sh` (`--full-preimage --mask-cfs --old run-a-tame --cross-profile run-i-dense-k4`) | `…/p2/run.log`, `.done`, `run-{k,l}-*.json`, `time-*.log` |
| dense against zero | `zk60_native_rg_witcmp.py` | `…/p2/witness_comparison_p2_dense_vs_zero.json` |
| rung-P2 against both development shapes, classified | `zk60_native_rg_m125table.py` | `…/p2/comparison_table_p2.json` |
| the eighteen records of record re-taken under this round's tools | `…/p2/before.sh`, `refresh.sh`, `diff.sh` | `…/p2/refresh.log`, `.done`, `diffs/`, `all_eighteen_records_unchanged.json` |
| the two 125M records of record, ONCE each | `zk60_native_rg_m125.py --stages load,replay,hash,terminals,commitments,boundary,preimage,channels`, under the heavy lock | `…/p2/m125-{dense,zero}-9b.log`, `.done` |
| the suite | `python3 -m unittest discover -s tests -p 'test_zk60_native*.py'` | `…/p2/tests_native_all.log`, `.done` |

## R9b.4 Results — P1, the pins at `4ccbad1`

Report §14.2 has the table. Three things belong here.

1. **All 38 pins recomputed from the committed blobs**; 33 byte-identical
   to what the 125M bundles pin. The five that moved are `argument.rs`,
   `protocol.rs`, `shape.rs`, `run.rs` and `private_block.rs`, and the
   verdict on the lane's claim — nothing sent, absorbed or drawn changed —
   is UPHELD for everything these ports model. The gate's own confirmation
   is that the replay re-derives all 4,560 challenges of a bundle written
   under a profile string it had never seen.
2. **`argument.rs` is the one to read twice**, because it is the file that
   decides what a slot's polynomial IS. Five hunks, all table BUILD:
   `priv_table`'s two bit-permutation maps with a plain store when nothing
   can collide, `eq_cube`, `table_of_taking`, `build_tables_at` and the
   chunked claimed sum. The slot closures, the push order, `pad_on`, the
   `mu`/`nu`/`zeta` draws at `argument.rs:936` and the single
   `absorb_fp2(b"pb-scalar")` are byte-identical, so the pin selects stage
   20's repaired bilinear definition, unchanged.
3. **FINDING P-F1.** `pad.rs` — where the pad rule is transcribed from —
   was one recorded digest under a header saying no bundle pins it. False
   since stage 27, and it had moved twice. Now checked at all three
   digests, with the reading that **not one production line of `pad.rs`
   has moved since round 1**: both moves are inside `#[cfg(test)] mod
   tests` apart from one `pub(super)` on a test-only function.

## R9b.5 Results — P2, the prediction

Report §14.3 has the table. The module now DERIVES the pad rule and the
definition draw count of all eight zero-check slots instead of reading
them, and it is validated on **three** committed records — rung-G,
rung-K4 and **the 125M record**, the shape where three domains do not pad
— reproducing every figure it names on each. It was committed in
`dfecca3`, before the gate had been run at rung-P2.

The one figure worth naming twice: the predicted receipt. Slots 16 and 18
lose one degree each with the pad factor, their 11 + 14 = 25 sumcheck
rounds each send one `Fp2` less, so a stage is exactly **400 bytes**
shorter than the rung-K4 stage of the same role. The capture declares
4,574,904 and 4,765,336 against rung-K4's 4,575,304 and 4,765,736. The
same 25 rounds show up a second time on the masking side: **25 fewer
entries recomputed per stage** (15,950 against 15,975).

## R9b.6 Results — P3, the gate at `rung-P2`

Report §14.4 has the comparison and §14.5 the headline. In one line: **46
of 46 slot checks on both bundles**, every stage `ok`, every control family
firing, the channel table the full **28 at 10 / 5 / 4 / 9**, 253 s and 540
MB a bundle, and **0 unexplained figures** out of 180 classified.

What the round was for, in the port's own terms: `Ctx.pad_on` is **false**
at slots 02, 16 and 18 and true at the other five zero-check slots, derived
from `Shape::pads`; `Ctx.pad_draws` consumes 13, 19 and 24 draws where the
capture declares 13, 19 and 24; `Ctx.zero_planes` returns `[]` on those
three domains and `B::supp` gives them no public table, which is why slot
18 carries **0** public tables here and 1 at rung-K4.

## R9b.7 Results — P4, the controls and M9-3's twin

Report §14.6. **FINDING P-F2: M9-3 had never fired.** `index.geom` does
not exist on a `PlaneIndex` at any shape, the bare `except` turned the pad
state into `None`, and the control reported itself inapplicable with
`ok: true`; and both 125M control passes raised before reaching it anyway.

Repaired, and given a twin that runs everywhere: **CT-9** flips
`SlotCtx.pad_on` for one hosted domain at a time — the draw arithmetic
alone — and demands a refusal naming both counts. Two facts came out of
building it that are worth keeping:

* flipping the whole pad STATE is caught one step earlier, by the
  public-table count (`slot 18: the port declares 1 public tables, the
  capture has 0`), so the message round 9's report attributed to M9-3
  would not have appeared even with the object bug fixed. CT-9 flips the
  arithmetic alone, which is exactly what M-F1 was about;
* the mirror direction — a PADDED domain made to consume the unpadded
  arithmetic — exists at **every** shape, so the regression is not
  conditional on having a rung-P2 bundle on the box.

## R9b.8 Results — P5, the 125M jobs that landed

Report §14.9 has the table. Six of round 9's eight landed and were
integrated by the round-9 agent before it was stopped; this round
re-verified every figure against the committed records rather than the
report's word. Three things the verification added:

1. **The per-commitment entry counts sum to the arm's total** on both
   bundles (dense 2,070,138 + 1,989,171 + 42,753 + 2,070,138 + 1,989,171 +
   59,612 + 42,753 = 8,263,736; zero 8,256,579), 0 differing, 1,792 salted
   leaves each, P-1 … P-6 all firing on the dense pass.
2. **Dense minus zero is 7,157 and it is exactly two commitments**: `H@0`
   7,120 (one distinct opened column of a 7,120-row commitment) and
   `E-Input` 37.
3. **The `joint` stage builds nothing** — which is why it takes 0.0 s. It
   checks the four couplings and ADDS THE TWO ARMS UP: 8,296,654 is
   8,263,736 + 32,918 and 2,304 leaves is 1,792 + 512. The joint statement
   stands on C1 (128 identified row pairs, all data rows, none touching a
   blinding row), and the entry count must not be read as a third
   verification. Report §13.8 is corrected in place.

`zero-full`'s exit 1 is finding M-F4 and nothing else: the pass was run
without `--controls`, so stage 12's `ok` is false although all 32,918 of
its entries match. Still not landed when this was written:
`dense-everything` (`results/zk60_native_run_gate_m125/dense-everything.done`)
and `retake78` (`…/retake78.done`), plus two re-runs a second session
enqueued at 12:31 (`dense-controls3`, `dense-everything2`) whose output is
scratch, not a record of record.

## R9b.9 The suite, and the records re-taken

`python3 -m unittest discover -s tests -p 'test_zk60_native*.py'`: **507
tests, exit 0**, one skip and one recorded expected failure (round 9:
474). Report §14.11 has the table of the five exact-set assertions this
round widened on purpose and the six evidence-digest tests the refresh
re-took; **not one measured figure moved.**

The eighteen records of record were re-run under this round's tool bytes
and diffed leaf by leaf against the committed ones: **0 UNCLASSIFIED on
all eighteen**, 520 new leaves (384 of them CT-9's own) and 586 changed
(132 tool hashes, the rest wall clocks), and not one rank, disclosed
dimension, challenge count, slot check, preimage figure, mask figure,
control figure or channel count differs at any shape.

One operational note worth keeping, because it cost an hour of confusion:
round 9's own detached jobs were still running when this round began
editing tools, so four of the ten development records the `refresh2` job
wrote at 12:35-12:38 straddle two tool versions. They were never
committed; the refresh above took its baseline from `git show HEAD:`
rather than from the working tree, which is the only reason the leaf diff
means anything. **A detached job that runs a tool from the worktree pins
the bytes it finds when it STARTS, not when it was enqueued.**

## R9b.10 NEXT after round 9b

0. **The two 125M records of record are ENQUEUED, not landed.** Round 9b
   moved seven tool files, so `m125-dense.json` and `m125-zero.json` pin
   tool digests that have moved; both are re-taken by the jobs named in
   §R9b.3 (`…/p2/m125-{dense,zero}-9b.done`), queued behind
   `dense-everything` and three other heavy jobs. Until they land, those
   two records carry the pre-9b tool bytes and **no figure in them is in
   question** — what moved is the pin tables, CT-9 and one accepted digest.
   Read the markers first.
1. **Fire M9-3 and CT-9 at 125M.** The repair is verified at rung-P2,
   where the same three domains are unpadded; it has not been re-run at
   125M because this round started no new 125M computation for task A. The
   next 125M control pass will carry both.
2. **`dense-everything` and `retake78`** are still the two round-9 jobs
   that have not landed. `dense-everything` is the only pass that can read
   **28 at 10 / 5 / 4 / 9** at the 125M shape.
3. **A second session's re-runs.** `dense-controls3` and
   `dense-everything2` were enqueued at 12:31 by the round-9 agent before
   it was stopped. Their output is scratch: they straddle this round's tool
   edits and are not records of record. Do not commit them; re-take
   anything they claim.
4. **More than two blocks, at either shape.** `L = 2` exercises one
   internal boundary; rung-P2 could carry three as cheaply as two.
5. **The joint LAW** (O-R2 / G-R4) and **the hash layer's HIDING** (M-2,
   M-3) are exactly where rounds 7-9 left them, and they remain the two
   largest things between this gate and a privacy argument.
6. Nothing in this round moves D8/D11 or ruling M-8's decision, and
   nothing in it is a privacy acceptance.

# ROUND 9c (2026-09-21 18:45 PDT) — three new shapes, the 125M records integrated, and the lane's slot IR as a cross-check

## R9c.0 Why there is a round 9c

Round 9b closed with two 125M records of record ENQUEUED and with
`dense-everything` — the one 125M pass that can carry the whole channel
table — still on the heavy lock. All three have landed. Separately, lane
stages 31-33 added three profiles beside `rung-P2`, each with a two-block
capture pair, and lane stage 34 exported every registered shape's 23 slot
polynomials as canonical JSON. This round integrates the landed 125M
records, puts the three new shapes through the whole gate with the
prediction written first, and uses the lane's export as an independent
cross-check of the hand port.

## R9c.1 Input (READ-ONLY, never copied into this repository)

| bundle | shape | witness | source commit | where |
|---|---|---|---|---|
| `run-m-dense-c6` | `rung-C6` | dense generic | `3e106e1` | lane repo |
| `run-n-zero-c6` | `rung-C6` | all-zero | `3e106e1` | lane repo |
| `run-o-dense-w14` | `rung-W14` | dense generic | `11703c9` | `/home/victor/zk60-artifacts` |
| `run-p-zero-w14` | `rung-W14` | all-zero | `11703c9` | `/home/victor/zk60-artifacts` |
| `run-q-dense-e32` | `rung-E32` | dense generic | (read from the bundle) | lane repo |
| `run-r-zero-e32` | `rung-E32` | all-zero | (read from the bundle) | lane repo |

## R9c.2 Status

| # | item | state |
|---|---|---|
| Q0 | ledger skeleton, round 9c opened | done — `93c4d1d` |
| Q1 | Task A — the two 125M records of record and `dense-everything`, leaf-diffed and integrated | done — `9992652`, §R9c.4, report §15.2 |
| Q2 | Task B — pins at the three new shapes, hunk by hunk, incl. stage 35's claim | done — `f2eb4a6`, §R9c.5, report §15.3; **finding E32-F1** |
| Q3 | Task B — the prediction at the three shapes, written and committed BEFORE the gate is run | done — `f2eb4a6` (committed before any run), §R9c.5, report §15.4 |
| Q4 | Task B — the whole gate on all six bundles, both arms | done — `3e28d91`, §R9c.6, report §15.5–15.9 |
| Q5 | Task C — the lane's slot-IR export read and compared with the hand port | done — `9cd5397`, `bfa9038`, §R9c.7, report §15.10 |
| Q6 | report section "Round 9c", the records re-taken, the suite | done — `e3bc0ad`, `465d6fb`, §R9c.8, report §15 and §15.11 |

## R9c.3 Commands and logs (round 9c)

Every command below is in `results/zk60_native_run_gate_9c/` as a script,
with its log and its `.done` marker. The three whole-gate passes ran
DETACHED under `flock /tmp/zk-heavy.lock` inside `systemd-run --user
--scope -p MemoryMax=8G -p MemorySwapMax=0`; the light work ran at 4G.
**No new 125M computation was started in this round.**

| what | script | log / marker |
|---|---|---|
| the pins of all six bundles, against the lane's blobs | (one-off, recorded) | `pins_at_the_three_new_shapes.json` |
| the prediction at the three new shapes, and the three new derivations checked where C-6 is OFF | `predict.sh` | `predict.log`, `.done`, `prediction_{c6,w14,e32}_{dense,zero}.json`, `prediction_check_{k4,p2,m125}.json` |
| the whole gate at rung-C6, both bundles, both arms | `run_c6.sh` | `run_c6.log` / `run_c6b.log`, `.done`, `run-{m,n}-*.json`, `time-*.log` |
| the whole gate at rung-E32 | `run_e32.sh` | `run_e32.log`, `.done` |
| the whole gate at rung-W14 | `run_w14.sh` | `run_w14.log`, `.done` |
| one comparison table per shape, and dense against zero | `tables.sh` | `tables.log`, `comparison_table_*.json`, `witness_comparison_*.json` |
| the lane's slot-IR export as a cross-check | `slotir.sh` | `slotir.log`, `slot_ir_crosscheck.json` |
| the eighteen records of record re-taken under this round's tools | `before.sh`, `refresh.sh`, `diff.sh` | `refresh.log`, `.done`, `diffs/`, `all_twenty_records_unchanged.json` |
| the suite | `python3 -m unittest discover -s tests -p 'test_zk60_native*.py'` | `tests_native_all.log`, `.done` |

## R9c.4 Results — Q1, Task A

Report §15.1 and §15.2. Three 125M passes landed after round 9b closed
and all three are integrated: the two records of record (exit 0 each,
174.0 s / 1,460 MB and 161.9 s / 1,452 MB, **0 unclassified leaves**
against the committed bytes after round 9c's six new classes) and
`dense-everything`, which is the pass round 9b said did not exist — **the
whole channel table at 125M, 28 at 10 / 5 / 4 / 9**. Its exit 1 is taken
apart leaf by leaf in
`results/zk60_native_run_gate_9c/dense_everything_exit1_decomposition.json`:
nothing raised, every stage ran, CT-4 was skipped for want of an `--old`
bundle, CH-3 is the identity at the one shape it names, and **M9-3 fires
at 125M for the first time since its repair, in all three directions**,
with the `ok: false` that report §14.7 predicted in writing.

## R9c.5 Results — Q2 and Q3, the pins and the prediction

Report §15.3 and §15.4. 38 pins per bundle, all recomputed from the
lane's committed blobs; 35 of 38 byte-identical to `4ccbad1` and the
three that moved ADDITIONS ONLY, read hunk by hunk. **Finding E32-F1**:
the rung-E32 bundles name a source commit at which the shape they capture
does not exist. Stage 35's "nothing sent, absorbed or drawn changed" is
UPHELD for everything these ports model, read hunk by hunk. The
prediction gained a `corrections_and_geometry` block that derives
correction C-6, the `Dom::Tab` lift and the endpoint's row count from the
shape's own numbers; it was committed in `f2eb4a6`, before the gate had
been run on any of the six bundles.

## R9c.7 Results — Q5, Task C

Report §15.10. `zk60_native_rg_slotir` reads lane stage 34's export,
checks each file against the lane's own pinned length and digest, and
makes **eight structural comparisons per slot at seven shapes — 1,288
comparisons, 0 disagreements**. The first run reported eleven and every
one was in the new reader's own label map; none was in the port and none
in the export. Seven controls show the comparison refuses a wrong export
by name. Ruling I-8 is kept: nothing here is evaluated and no figure the
gate reports comes from the export.

## R9c.6 Results — Q4, the whole gate at the three new shapes

Report §15.5–15.9. **Six bundles, both arms, 46 of 46 slot checks on
every one**, every stage `ok`, the channel table the full 28 at
10 / 5 / 4 / 9, all nine terminal controls firing and CT-9 in four
directions at each shape. 283.6 / 284.5 s at 513 / 526 MB (rung-C6),
1,410.2 / 1,416.5 s at ~1,256 MB (rung-W14), 417.0 / 450.4 s at ~626 MB
(rung-E32). The comparison tables: **180 figures a shape, 55 invariant
and all 55 identical, 61 block count, 64 scaling, 5 of 5 predictions
held, 0 UNEXPLAINED** at each. Dense against zero: 136 figures,
122 / 130 / 120 identical, every difference a distinct-sampled-column
count or the pad margin or pad-block rank that derives from it.

Two things worth keeping.

1. **The gate refused all six bundles three times before computing a
   figure** — the run-layer pin table on `run.rs`, the terminal port's on
   `shape.rs`, and the mask port's OWN table on `shape.rs` again. Each
   refusal was cleared only by reading the hunks and writing the reading
   down, which is finding K4-F2's machinery working on three shapes at
   once.
2. **rung-W14's full-preimage arm is 508 s of its 1,410 s**, against 74 s
   at rung-C6 and 107 s at rung-E32 — and rung-W14 has FEWER rows than
   either. The cost is the row WIDTH: 2^16 encoded columns instead of
   2^12. It is the first development shape whose cost profile looks like
   125M's.

## R9c.8 Results — Q6, the records re-taken and the suite

Report §15.11. Three pin tables moved, all three in the gate's hashed
tool list, so every record of record was re-run and diffed: **twenty
diffs, 106,285 identical leaves, 692 changed, 561 new, 0 only in the old
record, 0 UNCLASSIFIED**, and the eighteen development and round-7/8
records gain no new leaf at all.

**The three 125M records deliberately pin the pre-9c bytes.** What moved
in the three tool files is three (file, digest) readings each, for
shapes those bundles are not at; no figure in them is in question, and
**no new 125M computation was started in this round**.

**TWENTY-SIX records, not eighteen.** The first refresh copied round
9b's list forward, and that list does not contain the records round 9b
itself produced (the rung-P2 pair) or this round's own six; then the
pin-table edit that puts finding E32-F1 under a machine assertion moved
`rg_runpins` again. The second refresh enumerates all twenty-six:
**153,930 identical leaves, 986 changed, 144 new, 0 only in the old
record, 0 UNCLASSIFIED**. A refresh list copied forward from the previous
round is always one round behind; round 9d should build its list from
what is on disk.

**The suite: 530 tests, OK** (round 9b: 507), one skip and one expected
failure — **at `MemoryMax=8G`**.
*(AS OF 2026-09-21, round 9c — dated here 2026-09-22 14:21 (round 9g).
**530 is the last measurement of the WHOLE `test_zk60_native*.py` suite**
and rounds 9d–9f have added tests to modules inside that pattern without
re-running it: round 9e added 11 and round 9f 17. The figures that ARE
current are the seven-module toy subset, **204 tests OK in 210.0 s**, and
the record guard alone, **29 tests OK** — both round 9f, R9f.8. Anyone
quoting a suite size should say which suite and as of when.)*
At 4G it is killed, and the measurement
says why: the suite minus this round's slot-IR module passes at 4G with a
peak of 5,054 MB, because most of that is the RECLAIMABLE file-backed
array stores; the module adds a few hundred MB of ANONYMOUS allocation
late in the same process, and that cannot be reclaimed. The module alone
is 22 tests, 3.3 s, 366 MB, and every module passes alone in a
per-module sweep. The suite is not leaking — it has outgrown a 4 GiB
single-process cap, and that is recorded rather than papered over
(`the_suite_and_its_memory_ceiling.json`).

**The closing sequence ran detached** (`finish.sh`, then `finish2.sh`)
and survived the session's death to an authentication outage at ~20:10 on
2026-09-21, landing its heavy steps exit 0 at 21:14 — the no-hangup
protocol doing its job.

## R9c.9 NEXT after round 9c

0. **Re-take the three 125M records** (`m125-dense`, `m125-zero`,
   `m125-dense-everything`): they pin the pre-9c bytes of
   `rg_terminals`, `rg_runpins` and `rg_mask`. Two are three minutes
   each; `dense-everything` is two and a quarter hours and is the only
   pass that carries the whole channel table at 125M.
1. **Report finding E32-F1 to the lane.** The rung-E32 bundles' manifest
   names `4505ddf`, one commit before `Shape::rung_e32` exists. The fix
   is in the writer's `HL_TEST_SOURCE_COMMIT`, not here.
2. **M9-3's ok-criterion.** It demands a refusal naming two DRAW counts
   and its own mechanism cannot produce one, because the public-table
   count catches the perturbation first. Either weaken the criterion to
   what the mechanism tests, or retire M9-3 in favour of CT-9, which
   does produce that message. Recorded, not decided.
3. **CH-3 at 125M.** It substitutes the 125M profile, so at the 125M
   shape it is the identity and cannot refuse. It should report itself
   inapplicable rather than `fires: false` — P-F2's shape of defect,
   without the consequences.
4. **The suite's 4 GiB cap.** It now needs 8G in one process. Raise the
   cap, split the suite, or make the bundle-reading tests share one
   loader — but decide it, and do not let a kill be read as a failure
   again.
   *(DECIDED — the cap was raised; noted in place 2026-09-22 14:21 (round
   9g). Every suite run since has used
   `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0`: round
   9f's seven-module toy suite ran there (R9f.8), as did round 9e's. Round
   9d's run is the one exception and it says so — it used 4G deliberately,
   because the toy subset peaks at 553 MB. **8G is the standing cap for the
   whole `test_zk60_native*.py` suite; 4G is enough for the toy subset
   alone.** The suite was not split and the loader was not shared.)*
5. **More than two blocks**, at any of the four development shapes that
   now carry 125M's padded-domain set.
6. **The joint LAW** (O-R2 / G-R4) and **the hash layer's HIDING**
   (M-2, M-3) are exactly where rounds 7–9b left them, and they remain
   the two largest things between this gate and a privacy argument.
7. Nothing in this round moves D8/D11 or ruling M-8's decision, and
   nothing in it is a privacy acceptance.

# ROUND 9d (2026-09-22 10:05 PDT) — the TOY joint gate replayed on the integrator's new-tree capture

## R9d.0 Why there is a round 9d

This round is about the **toy** gate, not the run gate. The D22 re-read of
`4751b93` (`ZK60_NATIVE_D22_REPIN_4751B93.md`) closed with one thing it
could not do (§7): it re-ran the gates on the **four captures of
2026-09-19**, which were made by the `c5b54753…` bytes of `zk.rs`, because
**no capture bundle in the schema the gate reads existed from the new
tree**. At 07:25 on 2026-09-22 the integrator delivered exactly that
bundle and asked for the joint gate to be replayed on it. This round is
that replay.

## R9d.1 Input (READ-ONLY, never modified, not committed here)

`/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922/`
in the MAIN tree, **uncommitted, the integrator's**. Read here, never
written, never renamed, never staged; the three capture files were copied
into this lane's evidence directory and that copy is deliberately left
untracked. Digests, so a later session can tell whether the files changed:

| file | bytes | sha256 |
|---|---|---|
| `captures/10b9d4be….json` | 9,251,420 | `e8d3c55bb16e4784e4873fb2683841096b813ff1264e2e23fdde6f71f43dd527` |
| `captures/10b9d4be….receipt` | 2,816,472 | `10b9d4be3c0af4a44c21789a30fddd716e0d8c63948e4056c6154d3d852ce64b` |
| `captures/10b9d4be….expected` | 112 | `b491fb948141cc8df7cc11bb3f75466810d39f26e2c3a127fa5b4a7965ca73a3` |
| `capture-validation.json` | 16,239 | `ff415259047756c1634f73fe10cb8c68d2d7e908f90745ba77384cd4f5722fc4` |

The request is the integrator's note of 2026-09-22 07:25 in
`docs/zkmatrix-poc/ZK60_CODEX_FABLE_COORDINATION.md` (also uncommitted in the
main tree): "Please replay your joint gate on this bundle; D22 remains
CPU-only."

## R9d.2 Status

| # | item | state |
|---|---|---|
| T1 | what the bundle is (schema, profile, pins, digests) | DONE — R9d.4, report §8.1/§8.2 |
| T2 | the pins, file by file, against `4751b93` and the D22 record | DONE — R9d.5, `pins_check.txt`, report §8.3 |
| T3 | the replay: the toy joint gate, and the leaf diff | DONE — R9d.6, `leafdiff_*.txt`, report §8.4 |
| T4 | the controls | DONE — R9d.7, report §8.5 |
| T5 | the report and this ledger | DONE — §8 of `ZK60_NATIVE_D22_REPIN_4751B93.md` and this section |
| T6 | the toy gate's tests and the record guard | DONE — R9d.8 |

**Headline: zero figures of record moved.** The bundle is from the tree
`4751b93` names (132 of 132 source hashes equal to the blobs), every one of
the 32 pinned files is at a digest the gate already accepts, **no gate script
had to change to read it**, and every number the statement and the D22 record
quote reproduces on a receipt the new code made.

## R9d.3 Commands and logs (round 9d)

Evidence: `results/zk60_native_d22_replay_20260922/` (`README.md` there
tabulates it). All four gate runs detached under `flock /tmp/zk-heavy.lock`
inside a `systemd-run --user --scope -p MemoryMax=4G -p MemorySwapMax=0`
scope, 10:07:23 → 10:09:49, markers `0`.
*(As of 2026-09-22 10:09, noted 14:21 (round 9g): 4G is this round's own
choice and is correct for it — the toy work peaks at 553 MB. The standing
cap for a whole-suite run has been **8G** since round 9c, and rounds 9e and
9f used it.)*

| step | command | log / marker |
|---|---|---|
| T2 | `python3 results/zk60_native_d22_replay_20260922/pins_check.py` | `pins_check.txt`, exit 0 |
| staging | `python3 .../stage_bundle.py` | `staged.json` |
| T3/T4 | `bash .../replay.sh` — the P10 gate `--columns full --controls-on all` and the joint-view gate, each once on the staged copy and once straight at the integrator's directory | `replay.log`, `replay.done` = 0 |
| T3 | `python3 .../leafdiff.py <new p10 record>` | `leafdiff_p10.txt`, `leafdiff_p10_as_delivered.txt`, exit 0 |
| T3 | `PYTHONPATH=... python3 .../leafdiff_jv.py <new jv record>` | `leafdiff_jointview.txt`, exit 0 |
| T3 | `jsondiff.py` staged vs as-delivered | `shim_control_p10.txt`, `shim_control_jointview.txt` |
| T6 | `python3 -m unittest -v tests.test_zk60_native_{capture,gate_record,joint_view,mask_commit,privacy_gate,terminal_polys,small_model_groups}` | `suite.log`, `suite.done` = 0 |

The gate commands are the ones the records of record give in their own
READMEs, with only `--captures` and `--evidence` moved. **No gate script was
edited**, and the nine P10 tool hashes and ten joint-view tool hashes in this
round's records are identical to the record of record's.

## R9d.4 Results — T1, what the bundle is

Schema **3** (the schema the toy gate reads), kind
`zk60-verifier-observations`, coverage `native-all-slots-v1`, profile and
transcript domain `hashline-zk-mr1/private-block-t32-poc/1`, privacy `P1`,
weight policy `public-statement`, `fully_verified` true,
`privacy_review_complete` false, `source_commit`
`4751b93ff4566e16fe07c61bd23d4cc2352f9f0b`, 23 slots, 34 mask functionals,
rows 455 / 384 / 7 / 7, groups 35 / 9 / 1 / 1, opening order
`M, A, H, Input, Output`. The **hash rule is legacy** (unkeyed BLAKE3): this
profile is one of the two `Shape::hashes_under_the_legacy_rule` names, so it
carries no D19 separating tag, which is what the gate's replay assumes.

`zk60_native_capture.screen_bundle` was run on it here, independently of the
gate: **it passes**, which is where the `.expected` question is answered — the
112-byte file must equal `expected_policy` element by element and hash to
`expected_policy_sha256`, and the receipt must hash to its own file name and
match `proof_bytes` and the captured header state.

**The receipt.** `10b9d4be…`, 2,816,472 bytes — byte-identical to
`results/zk60_host_private_20260920/main-gate/native-block/block_receipt.bin`,
the receipt §7 of the D22 re-pin record pointed at when it said the
integrator had proved this profile on the new tree but no bundle existed in
the gate's schema. **This is that bundle.** It is a re-capture of a saved
receipt, not a new proof: `capture.py` re-runs the ignored capture test with
`HL_TEST_NATIVE_RECEIPT` pointing at the saved file, using the `4751b93`
GPU-feature binary `hashline-75d0767c271c429f` (`cbc1864c…`, still on disk at
that digest) with every `HL_*` variable stripped, so the CPU body is taken.

**One gap recorded (report §8.2).** `10b9d4be…` is not one of the four
captures D22's evidence rests on, and it cannot be: it is a different proof.
The question "is this the accepted receipt?" **cannot be answered against the
statement**, because neither the statement nor the D22 re-pin record records
a digest for "the accepted receipt" — D22 accepts a PROFILE, and its evidence
is four captures named by digest. The statement should say so in one line so
the phrase cannot be read as naming a pinned artifact.

## R9d.5 Results — T2, the pins

`pins_check.py`, two independent questions (`pins_check.txt`).

* **The tree.** All **132** entries of `capture-validation.json[source_hashes]`
  compared with the SHA-256 of `git show 4751b93:<path>` from the main
  repository: **132 of 132 equal, 0 mismatches.** The bundle is from the tree
  D22 pins.
* **The pin set.** The union of `zk60_native_mask_commit.SOURCE_PINS` (10) and
  `PATH_PINS` (20) — the 29 files on this profile's path plus
  `private_attention/argument.rs` — with `zk60_native_terminal_polys.SOURCE_PINS`
  (8, six already in the first set): **32 distinct paths, all 32 present in
  the bundle and all 32 accepted.** 28 at the pin of record; **4 at the second
  accepted digest** — `hashline/src/zk.rs` `ce8cc516…`, `hashline/src/pcs.rs`
  `9537915b…`, `hashline/src/private_block.rs` `412a43f4…`,
  `hashline/src/gpu/mod.rs` `706ca7fa…` — which are exactly the four
  `ALSO_ACCEPTED` entries this lane wrote for `4751b93` after reading each
  change. **0 not accepted, 0 absent.**
* The three artifacts and the verifier binary were re-hashed on disk: all four
  match the manifest.

**No pin had to move and no tool had to change to read this bundle.**

## R9d.6 Results — T3, the replay and the leaf diff

Four runs, all exit 0: P10 `--columns full --controls-on all` at 62.5 s
(staged) and 61.5 s (as delivered); the eight-stage joint view at 10.9 s
each.

The bundle is a DIFFERENT receipt, so its challenges and every
challenge-derived value are supposed to differ. The diff is therefore an
A/B/N comparison: with A = `40083e7a…` and B = `7d334e06…` the two block
captures of record, the leaves A and B already disagree on are
receipt-specific, and **the leaves A and B agree on and N differs on are
figures of record moving**.

| record | A vs B | A vs N | B vs N | **MOVED** |
|---|---|---|---|---|
| P10 per-capture subtree | 99 | 99 | 67 | **0** |
| joint view, stages 1 / 2 / 3 / 4 / 5 / 7 | 0/16/2/0/0/1 | 0/16/2/0/0/1 | 0/10/2/0/0/1 | **0 at every stage** |

Outside `per_capture` the P10 record differs in one leaf only (no attention
entry in `receipt_length_is_the_same_within_a_profile`, because this run read
one block capture), plus `seconds`, `manifest` and `captures_dir`. Reproduced
on the new capture: 2,816,472 bytes; 28 channels, 11 constructed / 2 derived /
8 argued / 7 open, 0 failures; the per-role ranks 72 / 20 / 4 / 4; `q_pad`,
`pad_count` and `sampled_columns` 256; `rank_F` 34 and `rank_F_mod_rounds` 0;
stage 4's `joint_fp` 4 against `sum_of_parts_fp` 4, `pcs_sum_fp` 2,
`cfs_opening_only_fp` 2, `joint_opening_only_fp` 4; the M opening's disclosed
2 (predicted 2) with fibre 1164; the stage-2 disclosed dimensions 0 / 2 / 0 /
0; and all 28 channels with the same name and the same status.

**The staging shim adds no fact.** The two staged runs exist only because
`manifest_check` reads a file called `validation.json` whose `accepted` is a
list; the integrator's is `capture-validation.json` with a single record. The
staged copy is byte-identical and its `validation.json` is that manifest with
one key reshaped. `shim_control_p10.txt` / `shim_control_jointview.txt`: the
staged and as-delivered runs differ in `captures_dir`, the `manifest` block
and `seconds` **and in nothing else**.

## R9d.7 Results — T4, the controls

`--controls-on all`, so every control ran on the new capture: `all_fire`
true, `ok` true, `honest_again` true, ten control names, M's three with
`mask_commitment_M/all_fire` true, and the honest run passing before and
after each. Name by name, `fires` is true on A, on B and on N for all ten
(`leafdiff_p10.txt` §6). The joint-view gate's stage-6 set — altered capture
bytes, the pad-budget boundary, the four stage-4 joint controls, the
derived-mask-evaluation controls, the small model, the brute-force agreement
— is `ok` as a whole, and every other stage is `ok`, with
`privacy_property_established` false in both records.

**One observation, not a defect.** On the new capture the masking commitment
opens 252 distinct columns against its 256 pads, a margin of **4**; the two
block captures of record have margins 10 and 9. Condition 2 of §5 of the
statement holds and the exact-rank cross-check gives 252 on 252. The margin
is a per-receipt draw, not a property of the code; it is recorded so that a
future margin of 0 is recognised as the boundary
`one_pad_fewer_than_the_distinct_opened_columns` exists to police.

## R9d.8 Results — T6, the suite

`tests.test_zk60_native_{capture,gate_record,joint_view,mask_commit,privacy_gate,terminal_polys,small_model_groups}`:
**Ran 176 tests in 211.5 s, OK (skipped=1, expected failures=1)**, marker
`suite.done` = 0, inside the 4 GiB scope. The record guard alone
(`tests.test_zk60_native_gate_record`): **12 tests, 0.066 s, OK** — the three
committed records still agree with their own grades, carry the counts of
record, name the records they pin, and **were produced by the tools now in
the tree**, and the whole widened path-pin table still passes with a changed
byte in any pinned file refused by name.

Round 9c's 4 GiB single-process ceiling is untouched by this round: the toy
subset peaks well under it (553 MB RSS observed), and no 125M work was run.

*(CORRECTED 2026-09-22 14:21 (round 9g): "Round 9c's 4 GiB ceiling" reads
backwards. Round 9c is the round that **found the whole suite had outgrown
4 GiB** and ran it at `MemoryMax=8G`; 4 GiB is the cap this round chose for
the toy subset, which is enough for it. From round 9e onward the toy subset
is run at 8G too, so **8G is the standing cap** and the 4G here is round
9d's own choice, correctly justified by the 553 MB peak. The 176-test
figure is likewise as of 2026-09-22 10:09; it is 187 after round 9e and
**204** after round 9f, with the record guard at **29**.)*

## R9d.9 What this round is NOT

1. **It does not extend D22 to any other profile, tree or device path.** One
   bundle, one toy profile, CPU only — every `HL_*` variable was stripped when
   it was made, and the integrator states D22 remains CPU-only. The GPU
   configuration stays uncovered (statement note of 2026-09-21 03:23).
2. **It is not a privacy acceptance and establishes no privacy property.**
   Both records carry `privacy_property_established: false`; the P10 record
   carries `is_a_privacy_acceptance: false`. Seven channels stay OPEN, the
   joint LAW and the hash layer's hiding are where rounds 7–9c left them, and
   nothing here moves D8/D11.
3. **It does not replay a proof made today.** The receipt was produced by the
   new tree's binary on 2026-09-20 and saved; this run re-verified and
   re-captured it. What is established is stronger than §7's "the ports still
   describe the code" and weaker than "the ports reproduce a proof made
   today".
4. **The integrator's own verification is its evidence, not this.** Its
   fresh-process verification, canonical recapture and 23 slot/alias checks
   were not taken as an input to anything above; the two readings agree.
5. **It says nothing about the integration branch** `fee1a8d` or the lane's
   stage-36 observers, which move six pinned files and owe their own read
   under condition 7.
6. **The bundle is not committed here** — it is the integrator's, uncommitted
   in the main tree; only its digests are recorded.

## R9d.10 NEXT after round 9d

0. **Round 9c's NEXT list is untouched** by this round and still stands, item
   for item.
1. **To the integrator, one line of agreement on bundle shape.** A capture
   directory delivered as `capture-validation.json` with a single `accepted`
   record has the gate's manifest cross-check **skipped without saying so**
   (`manifest_check` returns `validation_json: absent` and the gate passes).
   Name it `validation.json`, make `accepted` a list, and lift
   `privacy_review_complete` and `verifier_binary_sha256` to the top level, as
   `results/zk60_native_captures_20260919/validation.json` does. No tool
   changes on either side.

   *(**WITHDRAWN 2026-09-22 (round 9e), noted here in place 2026-09-22
   14:21 (round 9g).** The ask should never have gone to the other side: the
   defect was this gate's, and round 9e fixed it here. `manifest_check` now
   **REFUSES BY NAME** instead of skipping itself when it cannot find a
   validation manifest, it reads a `capture-validation.json` with a single
   `accepted` record as delivered, and the round-9d replay was re-run with
   **no shim** — the check fires on its own and **zero figures of record
   moved** (R9e.7, `vs9d.txt`). So **the integrator need not rename its
   manifest or reshape `accepted`.** What is left of this item is a
   preference and not a requirement: `privacy_review_complete` and
   `verifier_binary_sha256` at the top level would be read, while inside
   `accepted` they come back `null`. See R9e.5, R9e.7 and §8.7 of the D22
   record.)*
2. **To the security owner, the gap of R9d.4.** The statement should say in
   one line that D22 accepts a profile and that its evidence is the four
   captures of 2026-09-19 by digest, so "the accepted receipt" cannot be read
   as naming a pinned artifact.
3. **A fresh proof under the new code** would turn "the ports reproduce the
   captured view of a receipt the new code made" into "the ports reproduce a
   proof made today". It is a Rust run, not this lane's work, and it is still
   worth asking for.
4. **The `fee1a8d` snapshot and the stage-36 observers** will need the
   condition-7 re-read of their six pinned files, and the pin set updated,
   before step 3 covers that tree.

# ROUND 9e (2026-09-22 10:26 PDT) — the TOY gate's manifest cross-check: the silent skip, fixed

## R9e.0 Why there is a round 9e

Round 9d found the defect and filed it as a request to the OTHER side:
R9d.10 item 1 asked the integrator to rename its manifest and reshape one
key, "no tool changes on either side". The security owner ruled the other
way round, and the ruling is the right one: a gate whose manifest
cross-check **skips itself without saying so** is the defect, wherever the
bundle came from. A tool that cannot cross-check a delivered bundle must
**refuse by name**; passing quietly is the one behaviour it may not have.

This round is that one fix, inside the hash-pinned toy gate, and nothing
else.

## R9e.1 Status

| # | item | state |
|---|---|---|
| S1 | the defect, reproduced against the pinned bytes (failing first) | DONE — R9e.4, `failing_first_before.log` |
| S2 | the fix in `manifest_check`, and the two callers' handling of the refusal | DONE — R9e.5, commit `92d0f82` |
| S3 | the tests: a single record, a list, absent / unreadable / neither, a manifest that disagrees | DONE — R9e.5, eleven tests |
| S4 | the re-pin of the records of record, reason in the guard's own record | DONE — R9e.6, `repin_diff.txt`, 0 unexpected |
| S5 | the round-9d replay once more with the fixed tool, **no shim** | DONE — R9e.7, `vs9d.txt`, `leafdiff_*.txt`, 0 moved |
| S6 | the toy gate's seven modules and the record guard | DONE — R9e.8, **187 OK**, guard 12 OK |
| S7 | report §8.7 of the D22 record, and this ledger | DONE — §8.7 (§8.6 was taken; nothing renumbered) and this section |

**Headline: the check now fires on the delivered bundle on its own, and zero
figures moved.** The three guarded records differ from their committed bytes
in the three tool digests and the clocks and in nothing else; the replay
without the shim reproduces the shim's answer leaf for leaf and round 9d's
A/B/N verdict figure for figure.

## R9e.2 Scope (hard, from the ruling)

1. **One change**: `manifest_check` in `scripts/zk60_native_jv_capture.py`
   and the two gates' handling of the new refusal. Nothing else in any tool,
   proved by the diff against `d837d50`.
2. **The records of record must keep passing.** They were produced from a
   directory that HAS a `validation.json` with a list `accepted`
   (`results/zk60_native_captures_20260919/`), so the fix must leave their
   manifest block exactly as it is.
3. **The re-pin is expected**: the tool's bytes change, so every record that
   names them has to be re-taken with the documented command, and the reason
   recorded in the guard's own record, as every re-pin before this one was.
4. Nothing in this round is a privacy acceptance, and no figure of record may
   move.

## R9e.3 Commands, logs and evidence

Evidence: `results/zk60_native_manifest_check_20260922/` (`README.md` there
tabulates it). The five gate runs were detached under
`flock /tmp/zk-heavy.lock` inside a
`systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope, with
the suite queued on the same lock so that it self-started when they were
done; markers `run.done` / `suite.done`.

| # | what | command | log |
|---|---|---|---|
| 1 | the defect, against the pre-fix bytes | `python3 results/zk60_native_manifest_check_20260922/failing_first.py` | `failing_first_before.log` (taken before the edit), `failing_first_after.log` |
| 2 | re-pin, P10 record 1 | `zk60_native_privacy_gate.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_privacy_gate --columns full --controls-on all` | `run.log` |
| 3 | re-pin, P10 record 2 | the same, `--evidence results/zk60_native_privacy_gate_channels` | `run.log` |
| 4 | re-pin, the joint-view record | `zk60_native_joint_view.py --captures results/zk60_native_captures_20260919 --evidence results/zk60_native_joint_view` | `run.log` |
| 5 | the replay, no shim | `zk60_native_privacy_gate.py --captures <the integrator's directory> --evidence …/p10_as_delivered_fixed --columns full --controls-on all` | `run.log` |
| 6 | the replay, no shim | `zk60_native_joint_view.py --captures <the integrator's directory> --evidence …/jointview_as_delivered_fixed` | `run.log` |
| 7 | what the re-pin moved | `python3 …/repin_diff.py` | `repin_diff.txt` |
| 8 | the replay against round 9d | `python3 …/vs9d.py` | `vs9d.txt` |
| 9 | the A/B/N leaf diff, round 9d's own tool | `python3 results/zk60_native_d22_replay_20260922/leafdiff.py …` and `leafdiff_jv.py …` | `leafdiff_p10.txt`, `leafdiff_jointview.txt` |
| 10 | the seven modules and the record guard | `suite.sh` | `suite.log` |

The integrator's directory
(`/home/victor/IntelligenceRegulation/results/zk60_security_probe_repin_20260922/`,
uncommitted in the main tree) was read-only throughout. Round 9d had to copy
it to make the check fire; this round needed **no copy at all**, and the
round-9d copy under `results/zk60_native_d22_replay_20260922/bundle/` stays
untracked and untouched.

## R9e.4 Results — S1, the defect, reproduced against the pinned bytes

`failing_first.py` loads `scripts/zk60_native_jv_capture.py` **as it stood at
`d837d50`, straight out of git**, so the pre-fix column keeps printing after
the fix has landed; `failing_first_before.log` was taken before a byte was
touched, and its two columns are identical, as they must be.

| case | before | after |
|---|---|---|
| 1. the integrator's directory as delivered (`capture-validation.json`, `accepted` one record) | `{"validation_json": "absent"}` — **and the gate passes** | `checked` 1, `mismatch` `[]`, `source_commit` `4751b93…` |
| 2. `validation.json`, `accepted` one record | `TypeError: string indices must be integers` | read, cross-checked |
| 3. `validation.json`, unparsable | `JSONDecodeError`, naming neither file nor directory | `ManifestRefusal`, naming the file |
| 4. `accepted` neither shape | `TypeError` | `ManifestRefusal`, naming the file and what it found |
| 5. **control**: the four captures of record | `checked` 4, `mismatch` `[]` | **character for character the same** |
| 6. a manifest that disagrees with the bundle | a `mismatch` list **neither gate folds into `ok`** | `ManifestRefusal`, naming the artifact |
| 7. no validation file at all | `{"validation_json": "absent"}` | `ManifestRefusal`, naming the directory and both names it looked for |

The silent skip in case 1 is caused by the **file name**, not by the single
record: `manifest_check` knew one name. The single record is a second defect
on the same function, and it is case 2. Round 9d's §8.5 saw the first; the
ruling names the second; both are fixed.

## R9e.5 Results — S2/S3, the fix, and what it deliberately does not change

`manifest_check` reads the manifest under either name (`validation.json`,
then `capture-validation.json`), reads `accepted` as a list **or** a single
record, and raises `ManifestRefusal` — naming directory, file and reason —
for absent, unreadable, not an object, `accepted` of neither shape, a record
without `proof_sha256`, or any disagreement with the bundle. The one way past
a missing manifest is `--no-validation-file`, whose declaration is written
into the record; declaring absence when a manifest is present is itself a
refusal. Both gates call the check **before** any analysis and exit **3** on
a refusal, writing no record.

Line counts against `d837d50`: `zk60_native_jv_capture.py` +112 / −11,
`zk60_native_privacy_gate.py` +18 / −2, `zk60_native_joint_view.py` +18 / −2,
`tests/test_zk60_native_joint_view.py` +241 / −1. The scripts' diff touches
the manifest-check function, the two callers' imports, their one new flag and
their refusal path, and nothing else.

**Deliberately unchanged**: the shape of the returned record. A passing
record still says `validation_json: "present"` without naming which of the
two files was read, so that every record of record's manifest block stays
byte-identical across this fix — which is what makes the re-pin provably a
re-pin and nothing more. The name is in every refusal message and in the
evidence. **One malformed shape is still refused without a name**: a manifest
whose `artifacts` key is present but is not an object raises `AttributeError`
— loud, no record written, so it cannot pass silently — and closing it would
change the tool's bytes again and cost another re-take of three records, so
it is left for the next re-take.

Eleven tests, in `tests/test_zk60_native_joint_view.py` (the module that
already owns this reader and one of the seven the toy suite runs): a single
record read and cross-checked, synthetically and on the integrator's real
bundle read-only; a list read, synthetically and on the four captures of
record; absent, unreadable and neither-shape refused by name; three kinds of
disagreement refused by name; the declaration recorded and a false
declaration refused; and both gates returning 3 and writing no record. One
of them is the load-bearing compatibility claim, machine-checked: the fixed
function's answer on `results/zk60_native_captures_20260919/` equals
`d837d50`'s answer on it, key for key.

## R9e.6 Results — S4, the re-pin

Three tool digests moved, so every record naming them was re-taken with the
command in its own README:

| tool | `d837d50` | now | why |
|---|---|---|---|
| `zk60_native_jv_capture.py` | `191f8bc9…` | `11f598d1…` | the fix |
| `zk60_native_privacy_gate.py` | `c33a27fb…` | `abaa316d…` | the flag and the refusal path |
| `zk60_native_joint_view.py` | `ca48c67a…` | `c66181aa…` | the same |

| record | before | after | what moved |
|---|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | 226.7 s | **224.9 s**, four captures `ok` | 2 tool hashes + `seconds` |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | 233.8 s | **222.1 s**, four captures `ok` | 2 tool hashes + `seconds` |
| `results/zk60_native_joint_view/joint_view.json` | 25.2 s | **20.7 s**, every stage `ok` | 2 tool hashes + `seconds` (including three per-stage clocks) |

`repin_diff.txt` compares each with its own committed bytes at `d837d50` leaf
by leaf: **0 unexpected differences**, and in particular each record's
`manifest` block is **identical**. The reason is written into the guard's own
record (`results/zk60_native_gate_record_refresh/README.md`), which now
carries the table of every re-pin with its cause, and into each record
directory's README.

## R9e.7 Results — S5, the replay with no shim

Both gates straight at the integrator's directory, nothing copied or staged:
the manifest check **fires on its own** — `present`, `checked` 1, `mismatch`
`[]`, `source_commit` `4751b93ff4566e16fe07c61bd23d4cc2352f9f0b` — P10 60.9 s,
joint view 10.8 s, both `ok`.

| comparison | differences | verdict |
|---|---|---|
| against 9d's **staged** runs (the shim) | `captures_dir`, `seconds`, the two tool hashes; **the manifest block identical** | the fix reproduces the shim's answer with no shim; the shim is retired |
| against 9d's **as-delivered** runs | the manifest block (6 leaves: `absent` → the cross-check), `seconds`, the tool hashes | the fix changed the check and no analysis |
| A/B/N against the records of record | P10 per-capture 99 / 99 / 67; joint view by stage 0 / 16 / 2 / 0 / 0 / 1 | **FIGURES MOVED: 0**, exactly round 9d's numbers |

So every figure of §8.4 of the D22 record stands, now taken through a
cross-check that actually ran.

**R9d.10 item 1 is withdrawn**: the integrator need not rename its manifest
or reshape `accepted`. The rest of that item is a preference, not a
requirement — `privacy_review_complete` and `verifier_binary_sha256` at the
top level would be read; inside `accepted` they come back `null`, here as in
9d's staged run.

## R9e.8 Results — S6, the suite

`tests.test_zk60_native_{capture,gate_record,joint_view,mask_commit,privacy_gate,terminal_polys,small_model_groups}`,
inside the 8 GiB scope: **Ran 187 tests in 208.5 s, OK (skipped=1, expected
failures=1)**, marker `suite.done` = 0 — 176 in round 9d, and the eleven new
ones are this round's. The one skip is the pre-existing one, not a new one:
the test that reads the integrator's uncommitted bundle **ran** and passed.
The record guard alone (`tests.test_zk60_native_gate_record`): **12 tests,
0.066 s, OK** — the three re-taken records agree with their own grades, carry
the counts of record, and were produced by the tools now in the tree.

## R9e.9 What this round is NOT

1. **It is not a privacy acceptance and establishes no privacy property.**
   Both gates still write `privacy_property_established: false`; the seven
   OPEN channels stay open; D8/D11, the joint LAW and the hash layer's hiding
   are untouched.
2. **No figure of record moved** — that is the point of the whole round, and
   it is machine-checked three ways (the re-pin diff, the 9d comparison, the
   A/B/N leaf diff).
3. **It does not re-open D22, the pins over the Rust tree, or §§8.1–8.6 of
   the D22 record.** It is one bookkeeping check in one Python tool.
4. **It does not extend the gate to any new bundle shape** beyond the second
   manifest name and the single `accepted` record. A bundle in a third shape
   is now a refusal, which is the intended behaviour.

# ROUND 9f (2026-09-22 11:58 PDT) — the two Cargo manifests join the pin set (finding P36-2)

## R9f.0 Why there is a round 9f

Round 9e closed a check that skipped itself. This round closes a check that
did not exist. Finding **P36-2** of the stage-36 pre-read
(`ZK60_D22_CONDITION7_PREREAD_STAGE36.md` §7, review branch, read-only):
after the observers delta the question *"can a release build compile
`ZkRng::consumed_bytes` and `Transcript::squeezes`?"* is answered by
`zkp-core/Cargo.toml` (the `test-observers` feature must stay out of
`default`) and by `hashline/Cargo.toml` (it must stay in
`[dev-dependencies]`) — and **by no Rust source at all**. A one-word edit in
either would put the accessors into the production library with every Rust
file, every `cfg` gate and every existing pin unchanged, and neither manifest
was pinned by anything: not by `zk60_native_mask_commit.SOURCE_PINS` /
`PATH_PINS`, not by `zk60_native_terminal_polys.SOURCE_PINS`, not by the Rust
capture writer's 38-file list.

The owner's ruling of 2026-09-20 22:06 — *the pin set is extended to every
file on the path* — was about Rust files. This delta makes two manifests
load-bearing for the first time. Round 9f is that one change and nothing
else.

## R9f.1 Status

| # | item | state |
|---|---|---|
| T1 | the two manifests pinned at `4751b93`, with the reason naming P36-2 | DONE — R9f.4 |
| T2 | the CONTENT assertion (not only a digest), with its cases | DONE — R9f.5, 17 tests |
| T3 | failing-first: the pre-change gate accepts `default = ["test-observers"]` | DONE — R9f.6, `failing_first_before.log` |
| T4 | the re-pin of the records of record, reason in the guard's own record | DONE — R9f.7, `repin_diff.txt`, 0 unexpected |
| T5 | the toy gate's seven modules and the record guard | DONE — R9f.8 |
| T6 | this section and §8.8 of the D22 record | DONE — §8.8 and this section |

**Headline: the two files that decide the production-identity claim are
pinned, by digest and by content, and zero figures moved.** The three
guarded records differ from their committed bytes in two tool digests — one
of them a new leaf — and the clocks, and in nothing else.

## R9f.2 Scope (hard)

1. **One change**: two pins and one content assertion, in a new tool the two
   toy gates call before any analysis. No Rust file is touched (this lane
   does not write Rust), no capture is re-made, no bundle is read.
2. **The Rust pin tables keep their bytes.** `zk60_native_mask_commit.py` is
   named by **122** committed records' `tool_sha256` maps and
   `zk60_native_terminal_polys.py` by 8 (plus its own `port_sha256`), each
   asserted equal to the tool in the tree by its own test. Changing either
   would stale the whole run-gate series. R9f.5 says what was done instead.
3. **Main's digests, not the lane's.** The pins are read from `4751b93`, the
   commit the rest of the D22 pin set is read at. The lane's stage-36
   manifests are recorded as *expected after integration* and deliberately
   not accepted.
4. Nothing in this round is a privacy acceptance, and no figure of record may
   move.

## R9f.3 Commands, logs and evidence

Evidence: `results/zk60_native_manifest_pins_20260922/` (`README.md` there
tabulates it). The three gate runs were detached under
`flock /tmp/zk-heavy.lock` inside a
`systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope, with
the suite queued on the same lock so that it self-started when they were
done; markers `run.done` / `suite.done`.

| # | what | command | log |
|---|---|---|---|
| 1 | the hole, against the pre-change bytes | `python3 results/zk60_native_manifest_pins_20260922/failing_first.py` | `failing_first_before.log` (taken before the gates were wired), `failing_first_after.log` |
| 2 | the guard before the re-pin | `python3 -m unittest tests.test_zk60_native_gate_record` | `guard_before.log` |
| 3-5 | the three re-takes | `run.sh` (the command in each record directory's README, unchanged) | `run.log`, `run.done` |
| 6 | what the re-pin moved | `python3 …/repin_diff.py` | `repin_diff.txt` |
| 7 | the seven modules and the record guard | `suite.sh` | `suite.log`, `suite.done` |

## R9f.4 Results — T1, the two pins

Read from main at `4751b93`
(`git --no-pager -C <main tree> show 4751b93:<path> | sha256sum`), which is
also what this lane's worktree carries for both files:

| path | sha256 | git blob | what it decides |
|---|---|---|---|
| `zkp-core/Cargo.toml` | `b9038a52f34e0ee8313aa93eec656ff62ea29571a04b3df7f3db349d623ba842` | `e3d46e4e…` | where a `test-observers`-style feature is declared, and whether `default` switches it on for every build. At `4751b93` there is no `[features]` table at all |
| `hashline/Cargo.toml` | `eaba50ecf1434ad8514feb83c6e610b0d662b8fd6d512f26bacdde69163b860a` | `8a670755…` | the only place that enables a zkp-core feature, and whether it does so from `[dev-dependencies]` or from `[dependencies]`. At `4751b93` it enables none |

**Expected after integration, recorded and NOT accepted.** The block lane's
tip `a8e4939` carries the stage-36 manifests: `0c746b9d…` (zkp-core, with
`[features] test-observers = []` and an explicit `resolver = "2"`) and
`10d99a63…` (hashline, the dev-dependency that enables it). They sit in
`EXPECTED_AFTER_INTEGRATION` with their commit and what they add; the pin
moves once, against the integrator's merged tree, after those bytes have
been read there. The content assertion already accepts them, so that re-pin
will be a digest move and nothing more. (The pre-read's §6 table quotes a
third pair, `90156d58…` / `5633d1e4…`: those are the REVIEW worktree's bytes,
taken before P36-3 added the resolver line. Neither pair is accepted here,
and the difference is worth knowing when the integrator's tree is hashed.)

## R9f.5 Results — T2, the content assertion, and where the pins live

**A digest alone would be silent** the day somebody re-pins it without
reading the file. So the same check parses both manifests, on every call,
after the digest and whatever the digest said, and refuses **by name**:

* `zkp-core/Cargo.toml`: `[features]`'s `default` must be **absent or
  empty** — no feature at all on by default — and the token `test-observers`
  may appear **only in a `[features]` table**, so in no `[dependencies]`, no
  `[build-dependencies]` and no `[target.*.dependencies]` section;
* `hashline/Cargo.toml`: the token may appear **only in a dev-dependency
  section** (`[dev-dependencies]`, `[target.*.dev-dependencies]`);
* a manifest the scanner cannot parse is **refused, not passed**.

Python 3.10 on this box has no `tomllib` (3.11+), no `tomli` and no `toml`,
so the manifests are read by a small quote-aware scanner written for the
purpose (`read_manifest`, `section_kind`, `_array_items`), whose own
behaviour is tested: a `#` inside a string, a trailing comment, a multi-line
array with a comment inside it, a quoted `target."cfg(…)"` header, and four
malformed inputs that must raise.

**Where the pins live, and why not in `PATH_PINS`.** In a new module,
`scripts/zk60_native_manifest_pins.py`, called by both gates before they read
anything (exit **3**, no record, on a refusal). `zk60_native_mask_commit.py`
— where the Rust path pins live — is named by 122 committed records'
`tool_sha256` maps, the whole run-gate series over the real 125M bundles,
each asserted equal to the tool bytes in the tree by its own test; one byte
changed there would stale ~115 of them. The new file confines the re-pin to
the three records of record, exactly round 9e's set. The record guard holds
the two tables together: it fails if either manifest is unpinned, if any Rust
pin table ever names one at a different digest, or if a gate stops calling
the check.

**17 tests**, in `tests/test_zk60_native_gate_record.py` (class
`TheCargoManifestsArePinnedAndAsserted`): the pins are main's digests, read
independently in the test; the check passes on this tree with no second
digest in play; no other pin table names them differently; a changed byte in
either manifest, and a missing manifest, are refused by name; the feature in
`default` is refused by name (and so is any OTHER feature in `default`); the
feature in a normal dependency section is refused; declared in `[features]`
and enabled only from `[dev-dependencies]` — the shape the integration will
bring — is accepted, as is a `[target."cfg(unix)".dev-dependencies]`; absent
entirely, as at `4751b93`, is accepted; four wrong sections in hashline are
each refused by name; an unparsable manifest is refused; both gates call the
check, list the tool, and return 3 writing no record.

## R9f.6 Results — T3, failing first

`failing_first.py` loads `zk60_native_mask_commit.py` and
`zk60_native_terminal_polys.py` **as they stood at `025e1ac`, straight out of
git**, so the pre-change column keeps printing after the change has landed.
The tree is synthetic: a copy of every file the toy gate pins, with
`zkp-core/Cargo.toml` replaced by the pinned bytes plus
`default = ["test-observers"]`.

| case | before (`025e1ac`) | after |
|---|---|---|
| 1. the tampered tree, both Rust pin tables | **30 and 8 pinned files checked, NO refusal**; neither gate's source mentions `Cargo.toml`, `manifest_pins` or `test-observers` | — |
| 2. the same tree, the manifest pins | — | refused, naming `zkp-core/Cargo.toml`, digest against digest |
| 3. the same tree, **digest force-accepted** | — | still refused, by the content assertion: `[features] default = ["test-observers"]`, line 9, naming the file and P36-2 |
| 4. hashline with the observers in `[dependencies]`, digest force-accepted | — | refused, naming the section and the line |
| 5. the LANE's real manifests at `a8e4939`, digests force-accepted | — | **accepted** — `default` absent, the token only in `[features]` and `[dev-dependencies]` |
| 6. CONTROL: the tree as it stands | — | accepted, both digests equal to their pins |
| 7. the two gates, check pointed at the tampered tree | **no such check** | `main()` → **3**, `REFUSED (Cargo manifest pins): …`, no record written |

Case 1 is the hole exactly as P36-2 describes it: the tampered manifest
passed every check the gate had. Case 3 is the reason the assertion is not
only a digest.

## R9f.7 Results — T4, the re-pin

Three tool digests move, so every record naming them was re-taken with the
command in its own README:

| tool | at `025e1ac` | now | why |
|---|---|---|---|
| `zk60_native_manifest_pins.py` | *(new)* | `1b08589a…` | the pins and the content assertion |
| `zk60_native_privacy_gate.py` | `abaa316d…` | `819079dd…` | the call before any analysis, and the exit-3 refusal |
| `zk60_native_joint_view.py` | `c66181aa…` | `97601b89…` | the same |

| record | before | after | what moved |
|---|---|---|---|
| `results/zk60_native_privacy_gate/privacy_gate.json` | 224.9 s | **224.8 s**, four captures `ok` | 3 leaves: 1 tool hash, 1 NEW tool hash, `seconds` |
| `results/zk60_native_privacy_gate_channels/privacy_gate.json` | 222.1 s | **221.3 s**, four captures `ok` | the same 3 leaves |
| `results/zk60_native_joint_view/joint_view.json` | 20.7 s | **20.9 s**, every stage `ok` | 4 leaves: 1 tool hash, 1 NEW tool hash, two `seconds` |

`repin_diff.txt` compares each with its own committed bytes at `025e1ac` leaf
by leaf: **0 unexpected differences** — no channel, rank, dimension, control
or count moved. The reason is written into the guard's own record
(`results/zk60_native_gate_record_refresh/README.md`, which now carries both
2026-09-22 rows) and into each record directory's README;
`results/zk60_native_joint_view/README.md` was created in this round, because
that directory had none.

## R9f.8 Results — T5, the suite

`tests.test_zk60_native_{capture,gate_record,joint_view,mask_commit,privacy_gate,terminal_polys,small_model_groups}`,
inside the 8 GiB scope: **Ran 204 tests in 210.0 s, OK (skipped=1, expected
failures=1)**, marker `suite.done` = 0 — 187 in round 9e, and the seventeen
new ones are this round's. The one skip is the pre-existing one. The record
guard alone (`tests.test_zk60_native_gate_record`): **29 tests, 0.073 s,
OK** — 12 in round 9e; the three re-taken records agree with their own
grades, carry the counts of record and were produced by the tools now in the
tree, and the two manifests are pinned, asserted and called by both gates.
Before the re-pin the same guard was **29 tests, FAILED (failures=1)**
(`guard_before.log`): the records named the old gate bytes, which is exactly
what the re-pin is for.

## R9f.9 What this round is NOT

1. **It is not a privacy acceptance and establishes no privacy property.**
   Both gates still write `privacy_property_established: false`; the seven
   OPEN channels stay open; D8/D11, the joint LAW and the hash layer's hiding
   are untouched.
2. **No figure of record moved**, and it is machine-checked (`repin_diff.txt`,
   0 unexpected on all three records).
3. **It does not re-open D22, the Rust pin tables, or §§8.1–8.7 of the D22
   record.** It adds two pins of a kind the pin set did not have before.
4. **It does not assert a resolver version** (pre-read finding P36-3). At
   `4751b93` there is no `resolver` key to assert, and refusing a manifest
   for not having one would refuse the tree as it stands. The digest pin
   covers it from here: a manifest that dropped or lowered the key the lane
   added would not match its pin.
5. **It does not pin the lane's manifests.** They are recorded; the move is
   the integrator's re-pin.

## R9f.10 NEXT after round 9f

1. **At the integration re-pin**: move these two pins to the merged tree's
   bytes (expected `0c746b9d…` / `10d99a63…`), beside the four Rust files the
   pre-read's §6 table lists, and re-read `norm_alias.rs`, which the pre-read
   flags as a real textual conflict.
2. **The capture writer still does not record the manifests.** P36-2's
   remedy is complete on the Python side only: a bundle carries digests for
   38 Rust files and for neither manifest, so a receipt cannot be checked
   against the manifests it was built with. That is a Rust-side change for
   the integrator (`hashline/src/native_capture.rs`), named here as a
   residual.
3. **The attention profile's path** is still not widened (round 5's
   residual), and one malformed manifest shape in `manifest_check` is still
   refused without a name (round 9e's residual). Both are cheapest at the
   next re-take of the three records.

# ROUND 9g (2026-09-22 14:21 PDT) — the documentation-consistency sweep: every stale sentence carries a dated correction IN PLACE

**Opened 2026-09-22 14:21 PDT** on the same lane, same sole writer
(`/home/victor/wt-zk60-jointview`, branch `zk60-native-jointview`, tip
`442634b`). **Documents and this ledger only** — no tool, no test and no
record is edited in this round, and the record guard is run at the end to
show that nothing pinned moved. Nothing here is a privacy acceptance and no
sentence here establishes a privacy property.

## R9g.0 Why there is a round 9g

Rounds 9 … 9f each closed something an earlier round had written down as
open, and each wrote the closure in its OWN section. The sentences the
closure falsifies are still standing where they were first written, and a
reader who opens §10 or §12 or an early ledger round has no way to know
that §13, §14.10 or R9e answered it. The security owner's instruction is
that **every such sentence carries a dated correction in place, with the
original text kept visible** — no silent rewrite, and a pointer to the round
that closed it.

The seven items this round sweeps, each named by the owner:

| # | the stale claim | the round that closed it |
|---|---|---|
| 1 | "not pinnable from a bundle" / "pinned by nothing" | stage 27 (round 9 §13.5, 38 files), round 9b (`pad.rs`, P-F1), round 9f (the two Cargo manifests) |
| 2 | nothing measured at 125M; the 125M channel table is 2/5/4/17 | round 9c (28 at 10/5/4/9, every control family firing) |
| 3 | §13.7's M9-3 row; "every control … fired at 125M unchanged" | round 9b §14.10 (P-F2), then round 9c |
| 4 | R9d.10 item 1, "the integrator should rename its manifest" | withdrawn by round 9e |
| 5 | the suite's 4 GiB cap; the suite is N tests | round 9c (8 GiB, 530), 9d/9e/9f (the running counts) |
| 6 | the private-attention profile's three unpinned files | **nothing** — checked against the current tables and still open |
| 7 | the P-rulings cited for the bilinear slots; gap GS-13 | the S19-F1 repair (lane stage 20, rounds 4–6); GS-13 **still open** |

## R9g.1 Status

| # | item | state |
|---|---|---|
| S1 | this ledger section | DONE — `48cf29f` |
| S2 | item 1 — the pin sentences, occurrence by occurrence | DONE — R9g.3, `363dd56`; 16 occurrences, 9 corrected in place |
| S3 | item 2 — the 125M sentences and the channel table | DONE — R9g.4, `5ee2f0f`; 16 occurrences, 8 corrected, §13.9 extended |
| S4 | item 3 — M9-3 and "every control … unchanged", everywhere it repeats | DONE — R9g.5, `c4e8eb3`; 7 places, 4 corrected in place |
| S5 | item 4 — R9d.10 item 1's withdrawal, visible at the original sentence | DONE — R9g.6, `c4e8eb3`; 2 corrected in place |
| S6 | item 5 — the memory cap and the suite counts | DONE — R9g.7, `c4e8eb3`; 8 places, 4 corrected, 4 marked as of their date |
| S7 | item 6 — the private-attention profile's present pin status | DONE — R9g.8, `fb52e52`; **STILL UNPINNED**, on the open list |
| S8 | item 7 — the P-rulings for slots 08/09, and where GS-13 stands | DONE — R9g.9, `fb52e52`; **GS-13 STILL OPEN**, and a namespace collision resolved |
| S9 | the final grep, and the sentences owed to the MAIN TREE | DONE — R9g.10 (110 lines swept, 0 bare) and R9g.11 (five sentences) |
| S10 | the record guard, showing nothing pinned moved | DONE — R9g.12 |

## R9g.2 Method (the owner's, followed literally)

For each item: grep the branch's documents, list **every** occurrence with
its line number below, decide per occurrence — **correct**,
**historical-leave-with-date**, or **already corrected** — apply it, and
record the decision here. A correction is always the original sentence kept
verbatim plus a block of the form

> *(CORRECTED &lt;date time&gt;: … — see round N / §…)*

Main-tree documents (`/home/victor/IntelligenceRegulation/docs/zkmatrix-poc/`)
are read-only for this lane. Where one of them carries the same stale
sentence, the exact proposed replacement is written into §R9g.11 below for
the security owner to apply.

## R9g.3 Item 1 — "not pinnable from a bundle", occurrence by occurrence

**The ground truth was read out of the tools first, not from any earlier
prose.** The pin tables as they stand on this branch at `442634b`:

| table | entries | what it covers |
|---|---:|---|
| `zk60_native_rg_runpins.DEPENDS` | 4 | `run.rs`, `boundary.rs`, `run_capture.rs`, `plane_index.rs` (the last pinned by `rg_terminals`) |
| `…runpins.NOT_PINNABLE_FROM_A_BUNDLE` | 4 | `wire.rs`, `run_sink.rs`, `endpoint_g.rs`, `hash_domain.rs` — **all four now pinned by the WRITER**, reason (a) alone keeps them out of `DEPENDS` |
| `…runpins.SHARED_LAYER_PINS` | 23 | the shared files stage 27 added, each computed on 2026-09-21 |
| `…rg_mask.NOT_PINNABLE_FROM_A_BUNDLE` | 8 | `hashline/src/zk.rs` + seven `zkp-core` files — **all eight now pinned by the writer**, at exactly the `at_the_capture_commits` digests round 8 read by hand |
| `…rg_terminals.ALSO_READ` / `ALSO_READ_NOW_PINNED` | 3 / 3 | `pad.rs` (checked since round 9b, P-F1), `shape.rs` (since round 3), `witness.rs` (pinned by the writer, transcribed by no port) |
| `zk60_native_mask_commit.PATH_PINS` / `SOURCE_PINS` | 20 / 10 | the toy profile's whole path, the owner's 22:06 ruling of 2026-09-20 |
| `zk60_native_terminal_polys.SOURCE_PINS` | 8 | including the attention profile's `argument.rs`, `layout.rs`, `protocol.rs` |
| `zk60_native_manifest_pins` | 2 | `zkp-core/Cargo.toml`, `hashline/Cargo.toml` (round 9f, P36-2) |

So the **only** files this lane reads that nothing pins are the attention
profile's three (§R9g.8) and `hashline/src/gpu/cuda.rs` (feature-gated, off
every profile's path). Every other "cannot be pinned" sentence is stale.

| # | where | the sentence | decision |
|---|---|---|---|
| 1 | report §10.2, after the `NOT_PINNABLE_FROM_A_BUNDLE` paragraph | "a file can be pinned here only if the writer pins it — and none of the four is in `run_capture.rs::SOURCE_FILES`" | **CORRECTED in place** — false since stage 27; reason (a) kept, the table's name read as historical |
| 2 | report §10.8, third bullet | "Four run-layer files … cannot be pinned from a bundle at all" | **CORRECTED in place** — the gap round 6 could not close was closed by the writer at stage 27 |
| 3 | report §12.2, "And what cannot be pinned at all" | "no bundle carries a digest for `zk.rs` or for any of the seven `zkp-core` files" | **CORRECTED in place** — the ask was granted; all eight are pinned at the digests round 8 read |
| 4 | report §1, the six-file `source_pins` list | "The bundle pins its own Rust sources: …" (six files) | **CORRECTED in place** — right for `run-a`/`run-b`, 38 for every bundle since stage 27; the two Cargo manifests are pinned by neither writer nor earlier table |
| 5 | report §6.3, the round-6 dated note | "before tonight they were pinned by nothing" | **historical, already dated** (inside a "DATED NOTE, 2026-09-21 (round 6)" block) — left alone |
| 6 | report §10.1 item 1, §10.2's "pinned before tonight" column, §10.5's table | "three of those were pinned by nothing" | **historical, already dated** — §10's own heading is "2026-09-21, sixth round" and every verb is past |
| 7 | report §13.5's dated correction, §14.10's row for `pad.rs` | — | **already corrected** (round 9, round 9b); this round adds the pointer AT the originals, which is what was missing |
| 8 | ledger R5.4b, finding K4-F2 | "three of the eight files a bundle pins are pinned by nothing" | **already corrected** — carries `*(CLOSED 2026-09-21, round 6 …)*` |
| 9 | ledger R6.4, "The residual, named" and column (b) of its table | "the WRITER does not pin it, so no bundle carries a digest to compare" | **CORRECTED in place** — the ask was granted at stage 27 |
| 10 | ledger R6.8 item 1 | "they cannot be pinned from a bundle at all" | **CORRECTED in place**, marked GRANTED |
| 11 | ledger R5.4a's `run.rs` "pinned by nothing" | — | **already corrected** in place, round 6 |
| 12 | ledger R9.x, R9b.x | — | **already the correction**, not a stale sentence |
| 13 | D22 record §1.3 items 1–2 | "`hashline/src/pcs.rs` … no gate tool pins it"; "a gap in the pin set" | **CORRECTED in place** — pinned since round 5 (`PATH_PINS`), with `9537915b…` as its second digest |
| 14 | D22 record §4, the per-file table | `pcs.rs` / `private_block.rs` "yes, not pinned" | **CORRECTED in place**, as a dated row under the table |
| 15 | D22 record §7, "Also recorded" item 1 | "Widening the pin set … is the security owner's call whether to ask for it" | **CORRECTED in place** — the call was made at 22:06 on 2026-09-20 and round 5 carried it out; all six files named are in `PATH_PINS` |
| 16 | D22 record §1.4, `gpu/cuda.rs` "not pinned by any gate tool" | — | **STILL TRUE**, and said so in the §7 correction rather than corrected |

## R9g.4 Item 2 — "nothing measured at 125M", and the channel table

Report §13.9 was round 9's own sweep of this and caught **six** sentences.
It missed four of exactly the same kind, and one of round 9's own closures
went stale inside round 9c. Every occurrence:

| # | where | the sentence | decision |
|---|---|---|---|
| 1 | report §5, §9.11, §11.8, §11.10, §12.8, §12.10 | the six of §13.9 | **already corrected** in place, dated 2026-09-21 |
| 2 | report §6.7 (round 2) | "Nothing about the 125M shape. The port is shape-driven … but it has been RUN at one shape" | **CORRECTED** — seven shapes now (rung-G, K4, P2, C6, W14, E32, 125M); 46 of 46 slot checks at 125M |
| 3 | report §7.9 (round 3) | "it has been RUN at one shape. The m125 profile's four keys … that is the only 125M fact here" | **CORRECTED** — the hash layer runs at 125M; only CH-3 cannot exist there, and round 9c records why |
| 4 | report §8.11 (round 4) | "it has been RUN at one shape, where `lkv = 1`" | **CORRECTED** — `lkv = 2` at rung-K4, rung-P2 and 125M; `lkv > 2` is the part still open |
| 5 | report §11.8's round-9 DATED NOTE | "`A` and `H` are estimated at 22–23 minutes apiece and are OPEN at that shape, so §12.7's JOINT preimage is not established there either" | **CORRECTED** — the full-arm pass landed inside round 9: all seven commitments constructed and verified (8,263,736 entries, 0 differing), the JOINT preimage holds at 125M (8,296,654, 0 differing), `A@0` 365.1 s |
| 6 | report §11.10's round-9 DATED NOTE | "§13.8 has the estimate for `A` and `H` and the reason it is an estimate" | **CORRECTED** — the estimate became a measurement in the same round |
| 7 | report §13.8, last paragraph | "until it lands no 125M record carries the whole table and this section does not claim one does" | **CORRECTED** — `dense-everything` landed twice in round 9c: **28 at 10 / 5 / 4 / 9** |
| 8 | report §14.9, the `dense-everything`, `dense-controls2` and `retake78` rows | "**not landed**" | **CORRECTED** as a dated block under the table, with each marker's exit code |
| 9 | report §13.9's own table | — | **EXTENDED** with a dated block naming the four it missed |
| 10 | ledger §5 of round 2 ("What this lane does NOT show") | "Nothing about the 125M shape. The hash layer is argued, not computed … the per-slot terminal identity is not checked at this shape" | **CORRECTED** — three of the five closed, and the two that stand (the joint law; not a privacy acceptance) named as standing |
| 11 | ledger R7.9 item 4 | "nobody has measured either there" | **CORRECTED** — measured in round 9 §13.8, with the figures |
| 12 | ledger R9.6 ("A bookkeeping distinction") | "until it lands no 125M record carries the whole table" | **CORRECTED** — landed in round 9c |
| 13 | ledger R9.10's marker table | four rows still reading as pending | **CORRECTED** as a dated block under the table |
| 14 | ledger R9.0 ("Every round so far ends with the same line") | — | **already the correction**: it quotes the stale sentences in order to close them |
| 15 | ledger R8.x line 1590, "the ten records of record — 28: 2 / 5 / 4 / 17" | — | **correct as written**: it is the DEVELOPMENT records' table, not a 125M claim. Left alone |
| 16 | report §12.7 / §13.8's "2 / 5 / 4 / 17" and "10 / 3 / 4 / 11" figures | — | **correct as written** for the passes that produced them; the corrections say so explicitly so nobody "fixes" them to 10 / 5 / 4 / 9 |

**The one figure that matters, stated once:** the 125M channel table read
from a record that carries every stage is **28 at 10 / 5 / 4 / 9** — ten
CONSTRUCTED, five DERIVED, four ARGUED, nine OPEN — the same table rung-K4
and rung-P2 read. Records that ran only some stages read 2 / 5 / 4 / 17 or
10 / 3 / 4 / 11, and that is bookkeeping about which stage ran, not a
disagreement about a channel.

## R9g.5 Item 3 — M9-3, and "every control … fired at 125M unchanged"

Round 9b corrected both in its OWN section (§14.10). The owner's point is
that the reader of §13.7 never sees §14.10. Both now carry the correction
where the claim is made, and round 9c's closure is carried with it.

| # | where | decision |
|---|---|---|
| 1 | report §13.7, the M9-3 row | **CORRECTED in place** — a WITHDRAWN block under the row: M9-3 had never fired (it read `index.geom`, absent from `PlaneIndex`), the quoted message is CT-9's, it was repaired in 9b and fired at 125M in 9c in all three directions, and its `ok` is still false because its own criterion is what is wrong |
| 2 | report §13.7, the opening sentence | **CORRECTED in place** — true only of the families a pass carried through; the terminal and run-control families did not land at 125M until round 9c's `dense-everything`. CT-4 and CH-3 still do not fire there and each says why |
| 3 | report §13.1, the round-9 headline | **checked, no correction owed** — its seven items make no claim about the control families; item 7's "P-1 … P-6 all firing" is true and was true in `m125-dense-full` |
| 4 | ledger R9.8, "Three new ones, and the third could not exist before: **M9-3** …" | **CORRECTED in place**, with the same two facts |
| 5 | ledger R9.10's `dense-controls2` row ("the count of controls that fire at 125M") | **CORRECTED in place** — that pass crashed and delivered no control set |
| 6 | report §14.6, §14.7, §14.10; ledger R9b.7, R9c.4 | **already the correction** |
| 7 | report §15.1 item 6, §15.2's decomposition table | **already current** — M9-3 fires, `ok: false`, with the reason |

**What is still open and is named as open:** M9-3's ok-criterion (R9c.9
item 2 — weaken it to what the mechanism tests, or retire M9-3 in favour of
CT-9) and CH-3's self-report at 125M (R9c.9 item 3 — it should call itself
inapplicable rather than `fires: false`). Round 9g decides neither.

## R9g.6 Item 4 — R9d.10 item 1, withdrawn where it was written

| # | where | decision |
|---|---|---|
| 1 | ledger R9d.10 item 1 ("Name it `validation.json`, make `accepted` a list …") | **CORRECTED in place** — a WITHDRAWN block at the item: the defect was this gate's, round 9e made `manifest_check` refuse by name, the delivered bundle replayed with no shim and zero figures moved, so the integrator need not rename anything. What is left is a preference |
| 2 | D22 record §8.5, observation 1 ("Nothing here is wrong and no tool needs changing on either side … that is worth one line of agreement with the integrator") | **CORRECTED in place** — the same withdrawal, at the sentence that first made the ask |
| 3 | ledger R9e.0 and R9e.7; D22 record §8.7 | **already the correction** |

## R9g.7 Item 5 — the memory cap and the suite counts

The rule applied: a figure stated as CURRENT is corrected; a figure stated
inside a dated round section as that round's measurement is left and marked
as of its date.

| # | where | the figure | decision |
|---|---|---|---|
| 1 | report §15.11 / ledger R9c.8, "The suite: 530 tests, OK … at `MemoryMax=8G`" | 530 | **MARKED as of 2026-09-21** — it is still the last measurement of the WHOLE `test_zk60_native*.py` suite, and rounds 9e and 9f added 11 and 17 tests inside that pattern without re-running it, so 530 is a floor and not the count today. The current measured figures — toy subset **204**, record guard **29** — are named beside it |
| 2 | ledger R9c.9 item 4, "The suite's 4 GiB cap … decide it" | — | **CORRECTED** — decided: the cap was raised, `MemoryMax=8G` is standing, the suite was not split and the loader not shared |
| 3 | ledger R9d.8, "Round 9c's 4 GiB single-process ceiling is untouched by this round" | 176 | **CORRECTED** — it reads backwards (9c is the round that raised the cap to 8G); the 4G here is round 9d's own choice for the toy subset and is correctly justified at 553 MB. 176 marked as of 2026-09-22 10:09, with 187 and 204 after |
| 4 | D22 record §5.3, "Ran 293 tests … OK" | 293 | **MARKED as of 2026-09-20**, with the current figures named |
| 5 | D22 record §8.4 / ledger R9d.3, the `MemoryMax=4G` scope of round 9d's replay | — | **historical and correct** — that run really used 4G and had reason to; left alone |
| 6 | report §6.6, §7.8, §8.10, §9.10, §10.7, §11.9, §12.9, §13.8c, §14.11 (232, 261, 290, 335, 184, 214/390, 256/432, 474, 507) | — | **historical, already dated** — each sits inside its own round's numbered section, each says which round it grew from, and none is stated as the count today. Left alone |
| 7 | report §15.11's 4G/8G table, ledger R9c.8's reading of it | — | **correct as written** — a measurement of that day's suite, not a claim about today's cap |
| 8 | D22 record §8.8 / ledger R9f.8, 204 + 29 | — | **current**, and now the figure the other entries point at |

## R9g.8 Item 6 — the private-attention profile: STILL UNPINNED, and that is the answer

The owner asked for the present status rather than a correction, and the
present status is that **nothing has closed this**. Three files are on the
attention profile's path and no table on this lane pins them:

| file | in `mask_commit.PATH_PINS` (20)? | in `mask_commit.SOURCE_PINS` (10)? | in `terminal_polys.SOURCE_PINS` (8)? | in any `rg_*` table? | in the writer's 38? |
|---|---|---|---|---|---|
| `hashline/src/private_attention.rs` | no | no | no | no | no |
| `hashline/src/private_attention/wire.rs` | no | no | no | no | no |
| `hashline/src/private_attention/witness.rs` | no | no | no | no | no |

Read out of the tools on 2026-09-22, not from prose. The writer's 38 are
`OWN_SOURCE_FILES` (15, all under `private_block/`) plus
`SHARED_SOURCE_FILES` (23, `hashline` roots and `zkp-core`); **no path under
`private_attention/` is in either list**. What IS pinned for that profile is
its `argument.rs`, `layout.rs` and `protocol.rs`, by
`zk60_native_terminal_polys.SOURCE_PINS` (and `argument.rs` again by
`mask_commit.SOURCE_PINS`) — so the residual is exactly these three files
and no more.

**Why it matters, plainly:** two of the four toy captures of record are
ATTENTION receipts, so the gates read artifacts whose prover and verifier
reach three files nothing compares. A change to any of them would not trip
a pin. Nothing today is known to be wrong; the point of a pin is that the
next change is not silent.

**It is on the open list, not the corrected list.** Recorded as a residual
at R5.5c item 3, carried at R5.8 item 2, R6.8 item 2 and R9f.10 item 3, and
all four of those now carry a dated "STILL OPEN as of 2026-09-22" marker
pointing here. Round 9g changes no tool, so it does not close it either.
The cheapest moment to close it is the next re-take of the three records of
record, which is what R9f.10 item 3 already says.

`hashline/src/gpu/cuda.rs` is the one other file on this lane that nothing
pins. It is feature-gated behind `gpu-cuda` and off every profile's path in
the build the captures were made in (`gpu/mod.rs`, which holds `backend()`,
IS pinned), and the D22 record's §1.4 and §7 say so.

## R9g.9 Item 7 — the P-rulings for slots 08/09, and where GS-13 stands

**First, a name collision this sweep had to resolve before it could answer.**
`P-1 … P-6` in the run-gate report are **round 7's preimage controls**.
`P-1 … P-8` in `ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md` are the
**layout memo's rulings**. Thirteen places in the report say `P-1 … P-6`
and mean the controls; two places (§7.4) say `ruling P-2` and `the P-3
lift` and mean the rulings. A namespace note is now at §11.6 and a dated
note at §7.4, so a reader cannot mistake one for the other.

| # | where | decision |
|---|---|---|
| 1 | report §7.4, "a weight fold vanishing off its own input support (ruling P-2)" and "periodic in the byte class after the P-3 lift" | **CORRECTED with a dated note** — these are the layout disposition's rulings; item 4 of the S19-F1 disposition's §7 supersedes P-1 … P-8 **for the two bilinear slots**, and neither of these two uses is one of the superseded ones (P-2 is about weight folds, P-3 about the lookup lift). The note says so and points at the repair |
| 2 | report §11.6 | **NAMESPACE NOTE added** — the two P-n sets named apart |
| 3 | report §8 (round 4's opening) and §12.3 | **already correct** — both name the repair: §8 gives finding S19-F1 in full with the disposition's own reference, §12.3 says the two bilinear slots "are the ones stage 20 repaired (finding S19-F1)" and carries its arithmetic (`ext = 2`, degree +1 when `lkv > 0`) |
| 4 | ledger R4.0 item 1 | **already correct** — the repair, the completeness failure, and the disposition cited by name |
| 5 | GS-13, anywhere on this branch | **no occurrence** — the gap is named only in main-tree documents, so there is nothing here to correct. Its status is stated at §7.4's note instead |

**Where GS-13 stands, checked rather than assumed:** **STILL OPEN.** It is
gap GS-13 of `ZK60_GENERIC_RANK_LEMMA_SHAPED.md` — "the non-linear channel
is worse at a shaped layout than at the toy: slot degrees reach 5 against
the toy's 4, the two bilinear closures now carry a public `eq` factor, and
eight slots carry a support indicator" — and three main-tree documents list
it as open today: the memo's §7 gap table (line 1379), the memo's own
still-open list (line 1408) and the shaped disposition's "Still open on the
whole path" line (line 134). `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md` line
405 puts it out of scope rather than closing it. Nothing on this lane
touches it: what the run gate covers of the non-linear side is C4's narrow
sense, and report §12.8 lists "anything nonlinear" as not established.
Note also **GS-14**, in the same table: a linear-view argument cannot see a
completeness defect of any kind — which is S19-F1's own lesson and the
reason the repair is a lane-side fact and not a gate-side one.

## R9g.10 The final sweep: no occurrence left bare

Re-grepped the three documents for all seven item patterns after the
corrections landed — 110 matching lines. Every one is either the stale
sentence WITH a dated correction beside it, or a sentence that is itself a
correction, or a figure marked as of its date. **Ten lines match a pattern
with no marker in their own window, and all ten are corrections or
quotations of the closed sentence rather than the sentence itself:**

| where | what it is |
|---|---|
| report §14.1 item 8, and the P-F1 finding block (§14.2) | **is** the correction — "A bundle has pinned it since stage 27", "that has been false since stage 27" |
| ledger R9b's P-F1 paragraph | the same correction on the ledger side |
| report §13.0, ledger R9.0 | round 9's opening, which **quotes** the stale 125M sentences in order to close them |
| report §14.1 item 2, "§13.7's M9-3 row is corrected in §14.10" | a pointer to the correction |
| report §15.11's reading of the 4G/8G measurement | round 9c's own finding, immediately under this round's AS-OF block |
| report §7.4's note, the GS-13 line | this round's own text |

The patterns swept: `not pinned by a bundle | no bundle pins | pinned by
nothing | cannot be pinned | not pinnable | no gate tool pins it`;
`nothing (about|at) the 125M shape | anything at the 125M shape | no 125M
record | nobody has measured`; `fired at 125M unchanged | M9-3 row`; ``Name
it `validation.json` ``; `MemoryMax=4G | 4 GiB`; `private_attention.rs`;
`ruling P-2 | P-3 lift | GS-13`.

## R9g.11 What the MAIN TREE still needs — exact sentences for the security owner

Main-tree documents are read-only for this lane. Five corrections are owed
there, each written out so it can be pasted as a dated block **beside** the
original, never over it.

---

**(1) `docs/zkmatrix-poc/ZK60_GENERIC_RANK_LEMMA_SHAPED_DISPOSITION.md`,
§3's shape table, the 125M row (line 130).**

Original, to keep:

> | 125M | The argument and every count carry over; **nothing has been
> measured there** (GS-1), and nothing can be with the present tools — a
> 125M capture is out of the Python gate's reach. A privacy statement at
> this shape would rest on the argument, the counts, and measurements at
> the two development shapes that share its head geometry. That is a limit
> to state, not to hide. |

Proposed block beneath it:

> *(CORRECTED 2026-09-22: both halves are false as of 2026-09-21. The
> Python run gate has been RUN at 125M — the whole default gate in 179.1 s
> at a peak of 1,459 MB on a two-block 512-token capture, 46 of 46 slot
> checks, and a 281 MB `/5-run` bundle ingested in 0.6 s, which is what
> lane stage 27's binary array store bought. The full preimage arm is
> measured there too (all seven PCS commitments, 8,263,736 entries
> recomputed with none differing, 1,792 salted leaves), as is the masking
> layer (32,918 entries, 9.4 s a stage) and the joint run-wide preimage
> (8,296,654 entries, 0 differing). A record carrying every stage reads the
> full channel table, **28 at 10 / 5 / 4 / 9**. So a privacy statement at
> this shape need no longer rest on the argument and counts alone.
> Evidence: `ZK60_NATIVE_RUN_GATE.md` §13 and §15, ledger R9 and R9c. What
> is NOT closed by this: gap GS-13, the non-linear channel at a shaped
> layout, which stays open; and none of it is a privacy acceptance.)*

**(2) `docs/zkmatrix-poc/ZK60_GENERIC_RANK_LEMMA_SHAPED.md`, the same
sentence in two places — gap **GS-1** in the §7 table (line 1367) and the
125M row of the §8 shape table (line 1403).** The same block as (1), with
GS-1's own wording addressed:

> *(CORRECTED 2026-09-22: "Nothing has ever been measured at 125M" and "the
> disposition records that nothing can be measured at 125M with the present
> tools (a 125M capture is out of the Python gate's reach)" are both false
> as of 2026-09-21. Two two-block 125M captures have been through the
> Python run gate: 179.1 s, 1,459 MB, 46 of 46 slot checks; ranks computed
> on the real matrices (`A` 5,681 rows, `H` 7,120, the largest ranked
> matrix 206 × 25,686 at 2.1 s); disclosure figures, the full preimage, the
> masking layer and the joint run preimage all constructed and verified
> there. **GS-1 is closed on its measurement half.** What remains of it, if
> anything, is a question about which shape a privacy statement should rest
> on, not about whether the shape can be measured.
> See `ZK60_NATIVE_RUN_GATE.md` §13, §15.)*

**(3) `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_125M_LAYOUT_DISPOSITION.md`,
§2 "Rulings", immediately before **P-1** (line 38).** This is the note that
item 4 of `ZK60_BLOCK125M_S19F1_DISPOSITION.md` §7 says is owed:

> *(NOTE ADDED 2026-09-22, owed by item 4 of the S19-F1 disposition's
> process rulings. **Rulings P-1 … P-8 below are SUPERSEDED for the two
> bilinear attention slots — 08 `SC_SCORE` and 09 `SC_PV` — by §4 of
> `ZK60_BLOCK125M_S19F1_DISPOSITION.md` (2026-09-20).** Under grouped-query
> attention those two slots fixed the key-value GROUP bits of the head
> challenge as coordinates of BOTH private factors; a product of two
> multilinear extensions sharing a variable is quadratic in it, so honest
> prover and honest verifier disagreed the moment two key-value groups
> carried different data — a COMPLETENESS failure, not a soundness one.
> The repair (lane stage 20) makes the group bits SUMCHECK VARIABLES
> `rho(0..lkv)` shared by both factors, with a public factor `eq(r_g, ·)`;
> degree 3 and `lkv` more main rounds, `+336` bytes a stage. Every ruling
> below is otherwise unchanged, and the independent Python gate ports the
> repaired definition (`ZK60_NATIVE_RUN_GATE.md` §8, §12.3).)*

**(4) `docs/zkmatrix-poc/ZK60_PRIVATE_BLOCK_125M_LAYOUT.md`, the
grouped-attention section, after the line "So: **grouped-query attention,
12 heads of 64 over 4 KV heads.**" (line 450).** The other half of the same
owed note:

> *(NOTE ADDED 2026-09-22: **this section's treatment of the two bilinear
> slots is superseded by §4 of `ZK60_BLOCK125M_S19F1_DISPOSITION.md`**
> (finding S19-F1, 2026-09-20). Fixing the key-value group bits as
> coordinates of both private factors makes slots 08 and 09 quadratic in
> those bits and breaks COMPLETENESS as soon as two key-value groups carry
> different data. The group bits are now sumcheck variables shared by both
> factors with a public `eq(r_g, ·)` factor. Read §4 of that disposition
> before using anything here about slots 08 and 09.)*

**(5) `docs/zkmatrix-poc/ZK60_PRIVACY_STATEMENT_TOY_PROFILE.md`, the note
block that reads "**The gap:** `hashline/src/pcs.rs`, `private_block.rs`,
and the hashline-side `merkle`, `transcript`, `field` and `ntt` files are
on this profile's path and pinned by nothing … **Ruling: the pin set is
extended to every file on the path**, re-exports included (owed on the
joint-view branch)."** The ruling has been carried out and the statement
does not say so:

> *(CLOSED 2026-09-22: the ruling was carried out on the joint-view branch
> in round 5 (2026-09-20, `7ef86d6`). `zk60_native_mask_commit` gained
> `PATH_PINS`, **20 entries**, covering every file on the profile's path
> including all six named here, each with its digest, its git blob and a
> written reading; with `SOURCE_PINS` (10) and
> `zk60_native_terminal_polys.SOURCE_PINS` (8) the gate now checks **32
> distinct paths**, and the integrator's new-tree bundle was read against
> all 32 with 0 refusals (`ZK60_NATIVE_D22_REPIN_4751B93.md` §8.3). Three
> residuals are named rather than dropped: the five `#[cfg(test)]`
> `private_block` modules; `causal_oracle.rs`, `tables_v3.rs` and
> `zkp-core/src/tables.rs`, which are on the FIXTURE's path
> (`FIXTURE_PATH_NOT_PINNED`); and `private_attention.rs`,
> `private_attention/wire.rs`, `private_attention/witness.rs`, the
> ATTENTION profile's path, **still unpinned** — two of the four captures
> of record are attention receipts, so that one is worth closing. Since
> 2026-09-22 the two Cargo manifests are pinned as well
> (`zk60_native_manifest_pins`, finding P36-2). The 21:28 note's
> `hashline/src/pcs.rs` / `zkp-core/src/pcs.rs` mix-up, flagged in §1.3 and
> §7 item 2 of the D22 record, is what the corrections block above already
> fixes.)*

---

**A sixth, once (3) and (4) are applied:** item 4 of
`ZK60_BLOCK125M_S19F1_DISPOSITION.md` §7 says "a note is owed against
them". It can then be closed with *(the note was added 2026-09-22 to both
the layout memo's grouped-attention section and §2 of its disposition)*.

None of these five changes any figure, and none is a privacy acceptance.

## R9g.12 The record guard, and what this round did NOT touch

`python3 -m unittest discover -s tests -p 'test_zk60_native_gate_record*.py'`
inside `systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0`:
**Ran 29 tests in 0.082 s, OK.** The three records of record still agree
with their own grades, carry the counts of record, name the records they
pin and **were produced by the tools now in the tree**; the widened path-pin
table and the two Cargo manifests still pass, and a changed byte in any
pinned file is still refused by name. So **nothing pinned moved**, which is
the whole claim this round makes about the machinery.

`git status` over `docs/`, `scripts/`, `tests/` and the three record
directories shows exactly three modified files, all of them documents:
`ZK60_NATIVE_RUN_GATE.md`, `ZK60_NATIVE_RUN_GATE_PROGRESS.md` and
`ZK60_NATIVE_D22_REPIN_4751B93.md`.

## R9g.13 What this round is NOT

1. **It is not a privacy acceptance and establishes no privacy property.**
   Not one sentence added here is a claim about privacy; both gates still
   write `privacy_property_established: false`.
2. **It measures nothing.** Every figure quoted in a correction is taken
   from a committed record of an earlier round and cited to its section.
   No gate was run, no bundle read, no control fired.
3. **It changes no tool, no test and no record** — three documents, and the
   record guard run once to show it.
4. **It deletes nothing.** Every stale sentence is still readable where it
   was written; the corrections sit beside them, dated, with the round that
   closed each one named.
5. **It closes nothing that was open.** The attention profile's three files
   are still unpinned (R9g.8), GS-13 is still open (R9g.9), `lkv > 2` is
   still unread, M9-3's ok-criterion and CH-3's self-report are still
   R9c.9's items 2 and 3, and the joint LAW (O-R2 / G-R4) and the hash
   layer's HIDING (M-2, M-3) are exactly where rounds 7–9f left them.
6. **Five corrections are owed in the MAIN TREE and are not made here**
   (R9g.11). Until the security owner applies them, two main-tree documents
   still say nothing can be measured at 125M and the layout memo still
   carries no note against its superseded bilinear rulings.

## R9g.14 NEXT after round 9g

1. **The security owner applies R9g.11's five blocks** — or rules that one
   of them is wrong, which is equally useful.
2. **The attention profile's path**, R5.5c item 3 / R9f.10 item 3: the one
   thing this sweep found still genuinely open on the pin side. Cheapest at
   the next re-take of the three records of record.
3. **A whole-suite figure.** 530 is from round 9c and rounds 9e and 9f have
   added 28 tests inside that pattern without re-running it; one 8G pass
   would replace a floor with a number.
4. Nothing here moves D8/D11, ruling M-8's decision, or D22's scope.

# ROUND 9h (2026-09-22 14:53 PDT) — the private-attention profile's three files join the pin set

## R9h.0 Why there is a round 9h

Round 9g found it and could not close it: three Rust files on the PRIVATE
ATTENTION profile's proving and verifying path —
`hashline/src/private_attention.rs`, `private_attention/wire.rs` and
`private_attention/witness.rs` — appear in no pin table on this lane
(§R9g.8, read out of the tools rather than from prose). **Two of the four
toy captures of record are attention-profile receipts**, so condition 7 of
the toy profile's accepted privacy statement — *every file on the path is
pinned, and a change to any of them suspends step 3 until it is re-read* —
is not met for those two captures: a change to any of the three would trip
no gate. The security owner ruled on 2026-09-22 that the three join the D22
pin set. **Round 9h is that one change and nothing else.**

Nothing in this round is a privacy acceptance, nothing here establishes a
privacy property, and no figure of record may move.

## R9h.1 Status

| # | item | state |
|---|---|---|
| U1 | are all three really ON the attention profile's path? | PENDING |
| U2 | the three pins at main's `4751b93`, and where the pin lives | PENDING |
| U3 | failing first: before, a tampered tree passes both toy gates | PENDING |
| U4 | the re-pin of the three records of record, with its reason | PENDING |
| U5 | the toy gate's modules and the record guard | PENDING |
| U6 | this section and §8.9 of the D22 record | PENDING |

## R9h.2 Scope (hard)

1. **One change**: three digest pins, in a module both toy gates call before
   any analysis. No Rust file is touched (this lane does not write Rust), no
   capture is re-made, no bundle is read.
2. **The Rust pin tables keep their bytes.** `zk60_native_mask_commit.py` is
   named by 122 committed records' `tool_sha256` maps and
   `zk60_native_terminal_polys.py` by 8; a byte there stales the whole
   run-gate series.
3. **Main's digests, not the lane's.**
4. Nothing here is a privacy acceptance and no figure of record may move.

## R9h.3 Commands, logs and evidence

Evidence: `results/zk60_native_profile_pins_20260922/` (`README.md` there
tabulates it). The three gate runs were detached under
`flock /tmp/zk-heavy.lock` inside a
`systemd-run --user --scope -p MemoryMax=8G -p MemorySwapMax=0` scope, with
the suite queued on the same lock so that it self-started when they were
done; markers `run.done` / `suite.done`.

| # | what | command | log |
|---|---|---|---|
| 1 | the three digests, against four independent readings | `python3 results/zk60_native_profile_pins_20260922/bundle_crosscheck.py` | `bundle_crosscheck.txt` |
| 2 | the hole, against the pre-change bytes | `python3 results/zk60_native_profile_pins_20260922/failing_first.py` | `failing_first_before.log` (taken before the gates were wired), `failing_first_after.log` |
| 3 | the guard before the re-pin | `python3 -m unittest tests.test_zk60_native_gate_record` | `guard_before.log` |
| 4-6 | the three re-takes | `run.sh` (the command in each record directory's README, unchanged) | `run.log`, `run.done` |
| 7 | what the re-pin moved | `python3 …/repin_diff.py` | `repin_diff.txt` |
| 8 | the seven modules and the record guard | `suite.sh` | `suite.log`, `suite.done` |

## R9h.4 Results — U1, the path: all three are on it

Read at `4751b93` from the committed blobs, by call site rather than by
belief. **All three are on the attention profile's proving or verifying
path; none is a test-only module, so none is pinned here that should not
be.**

| file | why it is on the path |
|---|---|
| `hashline/src/private_attention.rs` | the profile's ROOT. `hashline/src/lib.rs:49` declares `pub mod private_attention;` with no `cfg` and no feature gate. The file holds `AttentionPublic` and its refusals, `IoSpec` / `ExpectedIo` / `prepare_endpoints` and the by-value `Endpoints`, `compute_output` (236), `prove` / `prove_with_stats` (270 / 274), `verify` (285), `verify_bytes` (311), `Receipt::{to_bytes, from_bytes}` (298 / 303) and `encoded_len` (290). Every attention proof and every attention verification enters here |
| `private_attention/witness.rs` | the PROVER's integer witness: `witness::build` is called at `private_attention.rs:277` (inside `prove_with_stats`) and `:236` (inside `compute_output`), and the `Witness` it returns is the argument of `protocol::prove_inner` (`protocol.rs:12`, `:259`), read by `lookup_values` (203) and `exp_deltas` (211). It computes every hidden plane the proof commits to — `quantize` / `requant` / `matmul` / `rotate` / `isqrt` / `limbs` — and carries the fixed-oracle range refusals |
| `private_attention/wire.rs` | BOTH sides. `wire::validate` is the FIRST statement of `protocol::verify_inner` (`protocol.rs:419`) and decides the receipt's shape, hiding widths and group counts before anything else is read; `wire::encode` / `wire::decode` are `Receipt::to_bytes` / `from_bytes` (`private_attention.rs:298` / `:303`), so `verify_bytes` decodes through this file; `HEADER` and `encoded_len` fix the frame length the captures' `proof_bytes` are measured against |

**Not test-only, checked rather than assumed.** The root declares `mod wire;`
(line 45) and `mod witness;` (line 46) with no attribute above either, and the
line that IS gated — `#[cfg(test)] mod tests;` (48-49) — is the next one. That
is the distinction that kept `private_block/{norm_alias,parity,refusals,
tamper,tests}.rs` out of round 5's table, and a test now asserts it on the
file rather than on this paragraph.

**The profile's six files are now complete.** `argument.rs`, `layout.rs` and
`protocol.rs` were already pinned by `zk60_native_terminal_polys.SOURCE_PINS`
(and `argument.rs` again by `zk60_native_mask_commit.SOURCE_PINS`, at the same
digest); with these three there is no file of the attention profile that
nothing compares. A second test derives the rest of the coverage rather than
asserting it: every `use crate::<m>` in the profile's six files must resolve
to a hashline file some table pins. Ten modules do (`field`, `merkle`, `mle`,
`ntt`, `pcs`, `private_seam`, `sumcheck`, `tables_attn`, `transcript`, `zk`);
the ONE that does not is `hashline/src/causal_oracle.rs`, reached from the
root's `synthetic_fixture` (line 132) — the public-fixture path the owner's
own words put outside "prover and verifier reach", already recorded with its
reason in `zk60_native_mask_commit.FIXTURE_PATH_NOT_PINNED`. The test allows
exactly that one and would go red on any other.

## R9h.5 Results — U2, the three pins and where they live

Read from main at `4751b93`
(`git --no-pager -C <main tree> show 4751b93:<path> | sha256sum`):

| path | sha256 | git blob |
|---|---|---|
| `hashline/src/private_attention.rs` | `dfc02d91356974b0cf4c6c0c672ec14660aa4b90b808236de81486272f010923` | `1bc8f891…` |
| `hashline/src/private_attention/wire.rs` | `a35a468cf19eb672e5428c3286a3ece15f73e96e20291a220cf38dd4104dbdff` | `26e21669…` |
| `hashline/src/private_attention/witness.rs` | `795cf6292e366bc48d1c1987b9a3173f9a19e266de537f72a9e738bdb5133ee0` | `0c9f7b60…` |

**Four independent readings agree** (`bundle_crosscheck.txt`): main at
`4751b93`, the block lane at `a8e4939`, this worktree, and the delivered
new-tree bundle's 132-entry `source_hashes`
(`results/zk60_native_d22_replay_20260922/bundle/validation.json`, read-only,
not committed here). **The lane's digests are IDENTICAL to main's**, so
unlike round 9f's two Cargo manifests there is nothing here to record as
"expected after integration" and nothing for the integrator's re-pin to move;
`LANE_DIGESTS` says so as data and the guard asserts the equality.

**Where the pin lives: `scripts/zk60_native_profile_pins.py`**, a new sibling
of round 9f's module, called by both toy gates before they read anything
(exit **3**, no record, on a refusal).

* Not in `zk60_native_mask_commit.PATH_PINS`, the natural home: that file is
  named by **122** committed records' `tool_sha256` maps — the whole run-gate
  series over the real 125M bundles — each asserted equal to the tool bytes
  in the tree by its own test, so one byte there would stale ~115 records and
  demand their re-take on bundles this round has no business re-running
  (`terminal_polys.py`: 8 records plus its own `port_sha256`). Round 9f's
  reason, unchanged.
* **Not folded into `zk60_native_manifest_pins.py`**, although it has the
  same shape and the same two callers. That module is the two CARGO
  MANIFESTS and finding P36-2; its error type, its header and its refusal
  line all say "Cargo manifest pins", and a Rust source pin filed under a
  name that says "manifest" would mislead the reader at the moment the
  refusal fires. The cost of the separate file is one more tool leaf in the
  three records — which this round re-takes anyway.

**Unconditional, not gated on the capture's profile**, which is what the
ruling asked for and is also the only thing that makes sense here: a gate run
reads a capture DIRECTORY, and the directory of record holds all four
captures — two block receipts and two attention ones — so a per-profile
branch would never be taken differently in any run of record; and for a block
run these three are simply files that must not have moved either (the same
tree the manifest cross-check compares a bundle against; the bundle's
`source_hashes` carries all three). One rule, no branch. A test asserts the
call takes no profile argument and stands before `load_all` in both gates.

**Digest only, no content assertion, and that is deliberate.** Round 9f's
manifests carry one because a Cargo manifest can be re-pinned blind and still
ship a test-only feature — the property there is a fact about the file's
meaning. The property here is the one the pin set exists for, *these are the
bytes the four captures of record were produced and verified by*, and a
sha256 is exactly that property. The refusal message carries the rest: read
the diff, write the reading in the ledger, and only then add a digest.

**The pin set's new size.** Machine-counted over the tables themselves, the
union was **34 distinct paths** (32 Rust + the 2 Cargo manifests) and is now
**37** (35 Rust + 2). *The accepted statement says 31 and becomes 34 by its
own arithmetic* — and that arithmetic undercounts by three: its 31 is the 29
files of the BLOCK path plus the two manifests, and it omits
`private_attention/{argument,layout,protocol}.rs`, which the tables have
pinned since round 1 / round 5. Both numbers are given here so the next
reader is not surprised by either; the sentence the main tree needs is in
R9h.9 item 5.

## R9h.6 Results — U3, failing first

`failing_first.py` loads `zk60_native_mask_commit.py`,
`zk60_native_terminal_polys.py` and `zk60_native_manifest_pins.py` **as they
stood at `28853ac`, straight out of git**, so the pre-change column keeps
printing after the change has landed. Three synthetic trees, each a copy of
every file the toy gate pins with ONE of the three tampered with — one line
each, of the kind that matters rather than a stray byte:

| tampered file | the one-line change |
|---|---|
| `private_attention.rs` | `mod wire;` → `pub mod wire;` — the frame's internals become public API |
| `private_attention/wire.rs` | the `!hiding_ok(&r.h_open, …)` clause deleted from `validate`: the verifier stops checking H's opening shape |
| `private_attention/witness.rs` | `if !(lo..=hi).contains(&q)` → `if false && …`: the prover's fixed-oracle range refusal never fires |

| case | before (`28853ac`) | after |
|---|---|---|
| 1. each tampered tree, against every pin check the gate HAD | **30, 8 and 2 pinned files checked, NO refusal** — in all three trees; and neither gate's source mentions `private_attention.rs`, `private_attention/` or `profile_pins` | — |
| 2. the same three trees, the profile pins | — | `ProfilePinError` in each, **naming its own file**, digest against digest |
| 3. CONTROL: the tree exactly as it stands | — | accepted, three digests equal to their pins of record |
| 4. the LANE's bytes at `a8e4939` (read-only, from the main checkout) | — | accepted — byte-identical to main |
| 5. the two gates, check pointed at a tampered tree | **no such check** ("has NO attention-profile pin check (pre-change)") | `main()` → **3**, `REFUSED (attention profile pins): …`, **no record written** |

Case 1 is §R9g.8's finding exercised: a change that deletes a verifier's
shape check, or a prover's range refusal, passed every check the gate had.

## R9h.7 Results — U4, the re-pin

PENDING.

## R9h.8 Results — U5, the suite

PENDING.

## R9h.9 What this round is NOT

PENDING.
