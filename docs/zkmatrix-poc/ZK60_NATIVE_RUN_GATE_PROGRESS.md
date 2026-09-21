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
| the pins the shape moves | `shape.rs` `8f734422` → **`07a0547f`** (60 added lines, 0 removed: a doc comment and `Shape::rung_k4` calling the UNCHANGED `Shape::new`) and `run.rs` `65d55d25` → **`73f68221`** (12 added lines, 0 removed).  The first is accepted as a read second digest; the second is **pinned by nothing** — finding K4-F2 |
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
2. **The attention profile's path** (R5.5c item 3): the same widening for
   `private_attention.rs`, `wire.rs` and `witness.rs`, which two of the
   four toy captures reach.
3. **A shape with `lkv > 2`.** 125M's `lkv` is 2, so rung-K4 exercises the
   case that shape needs; eight or more key-value groups are still unread.
4. The masked sumcheck / CFS channel, still the largest open one a port
   could close, and `zk60_native_pg_pcs` at `MSG != PAD`.
5. The run-wide preimage as ONE joint object; ruling R-3's machine
   assertion (gap G-R4), asked of the Rust lane.
6. Nothing in this round moves D8/D11 or ruling M-8's decision.
