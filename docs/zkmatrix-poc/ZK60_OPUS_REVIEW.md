# O1 / O2 — the repaired fresh-PoC captures, checked and analysed jointly

**Reviewer:** Opus 5, independent reviewer, 2026-09-08 session.
**Dispatch:** `docs/zkmatrix-poc/ZK60_OPUS_QUEUE.md`, items O1 and O2 (reassigned from
Fable, whose usage is exhausted; **Fable's completed FA1–FA7 analyses keep their own
attribution — nothing of Fable's was edited, re-pointed or relabelled**).
**Implementation pin:** `b41d036c4c1eb1ed9272494815d742d0ccf29934` ("Implement fresh
paired-mask FFN proof of concept"). **Review worktree:** `a8a1bc7` (branch
`zk60-fable-review`). Python 3.10.12, stdlib only, exact integers, no cargo, no GPU.

**Headline.** The four round-16 captures are exactly what the record says they are
(O1: 167 checks, 0 failed), and under Fable's FA7 joint linear observation model —
imported unchanged — **A discloses 0 base-field dimensions and P3 W discloses 0, in
both privacy modes, in all four captures; H discloses 2, and those 2 are exactly its
public LogUp identity (0 without the zero-sum constraint).** The legacy attack still
works on the legacy captures (A = 2n + 4 = 516, P3 W = 2n + 2 = 514, H = 2, the T32
`Wd` plane fully recovered), and this adapter refuses every legacy capture. That is the
expected review target, met exactly. **It is a linear-model result on four fresh-PoC
captures; it is not whole-protocol zero knowledge** (section 8).

---

## 0. Binding: the published validation record, and the one difference

This review started against the interim worker record `/tmp/zk60-round16/summary.json`
(`"status": "running"` at the time). **Codex published
`results/zk60_round16_validation.json` while the work was in flight, so the delivered
results were rebound to it and re-run**, per the dispatch.

- Published record: `/home/victor/IntelligenceRegulation/results/zk60_round16_validation.json`
  (Codex's integration checkout — it reaches this review worktree only at the next merge),
  sha256 `19e2ecb8b66c08d43eba624775d3258c239b82f23bcc16516f3882c673127a94`,
  `"status": "complete"`, `exit_code: 0`, `pending_review_model: "Opus 5"`.
- Interim record: `/tmp/zk60-round16/summary.json`, sha256
  `0d50f86528dd46de2696324271e1abbc2fa984ef6008200da78e3754bb104200`, now
  `"status": "failed"` (it read `"running"` when this review began).

**The one difference that matters, and how it is handled.** The published record's own
`source_commit` is `046e9654ab8b769be196bef5b63dbf6485982f7d` — the head the validation
ran at, which is *later* than the implementation the captures came from. The field that
carries the captures' pin is `capture_source_commit`
(`b41d036c4c1eb1ed9272494815d742d0ccf29934`, matching `initial_run.source_commit`), so
the tool binds to `capture_source_commit` and reports the record head separately.
Reading the head commit as the captures' pin would have been wrong.

**Everything else agrees exactly.** The two records were cross-checked entry by entry
(`manifest_cross_check` in both delivered result files): same four proof digests, and
identical `sha256`, `bytes`, `privacy`, `layout_digest` and `path` for every one; same
`capture_source_commit`. Nothing in this review's numbers changed when it was rebound.

Also recorded in the published file, and consistent with what the interim record showed:
the first full Python run at `b41d036…` had one failure —
`test_oracle_count_is_tied_to_the_suite_version (test_hashline_cl_gpu_gates.SuiteDefinition)`
of 660 tests (`initial_run.failures`; that is why the interim summary ended `"failed"`) —
and the validation was completed at head `046e9654…` with `affected_python_tests` and
`floors` both exit 0, `floor_verdict.ok: true`, suite version 7 and 218 storage tests.
That is Codex's item; it is reported here, not acted on.

---

## 1. O1 — the four capture files

Result file: `results/zk60_opus_capture_preflight.json`.
**167 checks, 0 failed, 4 files parsed, 0 refused** (45 per P3 file, 35 per P1 file, and
7 over the set: file count, manifest count, capture source commit, the published-vs-interim
cross-check, two-P1-two-P3, one shared layout digest, none refused).
**This is a capture-integrity check, not a privacy verdict:** nothing about disclosure,
soundness or zero knowledge follows from any line of this section.

### 1.1 The set, and its binding to the published manifest

| proof digest (file name) | privacy | bytes | capture sha256 | manifest match |
|---|---|---:|---|---|
| `48b82a830ec9d388…d456cfd884` | P3 | 13,162,013 | `c1d0a36768b2857d…` | sha256, bytes, privacy, layout digest, path: all ✔ |
| `6c98bcb2cd64f848…5be8b84d` | P1 | 12,559,433 | `c58235d9f49e0d82…` | ✔ |
| `73728df07d903ae3…4919fce4b08d` | P1 | 12,561,665 | `7630d2003e764934…` | ✔ |
| `bfae2421d14736fa…1703a74cb1aa` | P3 | 13,163,009 | `e34f07aa43ebed21…` | ✔ |

Exactly four files; exactly two P1 and two P3; every file name is its own `proof_sha256`;
every sha256, byte length, proof digest, privacy mode and layout digest equals the
published record's entry, the record's `capture_source_commit` is the pin, and the
interim record agrees on every one of those fields (§0).

### 1.2 Header, layout and structure (identical in all four files)

| check | actual | expected | pass |
|---|---|---|:--:|
| `schema` | `2` | `2` | ✔ |
| `kind` | `zk60-verifier-observations` | same | ✔ |
| `coverage` | `ffn-v3-mr1-fresh-poc-function-1` | same (exact) | ✔ |
| `profile` / `transcript_domain` | `ffn-v3-mr1-fresh-poc/1` / `hashline-zk-mr1/ffn-v3-mr1-fresh-poc/1` | same | ✔ |
| `source_commit` | `b41d036c4c1eb1ed9272494815d742d0ccf29934` | same | ✔ |
| `fully_verified` / `weight_policy` / `slot` / `k` | `true` / `fresh-per-proof` / `null` / `null` | same | ✔ |
| field modulus / non-residue | `18446744069414584321` / `7` | Goldilocks / u²=7 | ✔ |
| `shape` | `{t: 32, d: 16, f: 16}` | T32/d16/f16 | ✔ |
| `shifts` | `[7, 0, 14, 6]` | `[7, 0, 14, 6]` | ✔ |
| PCS params (every role) | `log_cols 8`, `inv_rate 8`, `num_col_checks 256` | 8 / 8 / 256 | ✔ |
| `q_pad` (every role) | `256` | `Q = 256` | ✔ |
| SHA-256 of UTF-8 `layout_description` | `e98e3189fe3d2b7eac1639cbf82d1e2aa71c3330ae7ba0e9e9607c8f52e76fa4` | declared `layout_digest`, same in all four | ✔ |
| the same digest, recomputed from the source rules | `e98e3189…76fa4` | see 1.3 | ✔ |
| role order, P1 | `[A, H]` | `[A, H]` | ✔ |
| role order, P3 | `[W, A, H]` | `[W, A, H]` | ✔ |
| transcript endpoints chain | W→A→H (state and next challenge) | chained | ✔ |

Per role:

| check | A | H | W (P3) |
|---|---:|---:|---:|
| commitment rows | **698** | **1326** | **11** |
| row-role entries (exactly one per row 0…rows−1) | 698 | 1326 | 11 |
| data / mask / prox rows | 344 / 352 / **2** | 664 / 660 / **2** | 3 / 6 / **2** |
| proximity rows | `44, 45` (`a_prox.re/.im`) | `28, 29` (`h_prox.re/.im`) | `9, 10` (`w_prox.re/.im`) |
| group member counts | **`[7, 3, 1, 1, 6]`** | **`[3, 1, 1, 6, 1]`** | **`[2, 1]`** |
| every group / proximity vector | 512 = n + Q = 256 + 256 | 512 | 512 |
| claims / parts | 18 claims, `[3×13, 2, 3, 3, 2, 3]` | 12 claims, `[4×11, 22]` | 3 claims, `[3, 3, 3]` |
| every part carries a `coefficient_tag` | ✔ (52 parts) | ✔ (66 parts) | ✔ (9 parts) |
| `public_linear_constraints` | `[]` | `[{rows: [24, 25], relation: "sum over the n message columns = 0", source: "zsum sumcheck"}]` | `[]` |
| sampled columns | 256 of a 2048-point domain, 11-node paths, 32-byte salts, 698 values each | same, 1326 values | same, 11 values |

The two 2-part A claims are claims 13 and 16 — the 2^16 `INT16` and 2^14 remainder table
**blocks**, which keep their block masks; the four singleton multiplicity tables are
3-part pair claims. Column indices are sampled with replacement, so 238–248 distinct of
256 is expected, not a defect.

### 1.3 The layout is recomputed, not trusted

The strongest check in O1: the tool rebuilds the whole allocation from the source rules
(`zkp-core/src/ffn_v3/statement.rs::Layout::new`, `tag_rem_v3`, `rem_rows`;
`hashline/src/zk.rs::ZkLayoutV3::with_masks` with `mr1 = true`), renders
`ZkLayoutV3::describe()` **byte for byte** in Python, and compares. The reproduction is
exact, so the recomputed SHA-256 is `e98e3189…76fa4` — the prover's own digest — and the
comparison is a string identity, not a digest coincidence:

```
ffn-v3-mr1-fresh-poc/1: n=256 wn=256 pred=false
A rows=698 masks=[20, 21, …, 696, 697] prox pair=44..46
H rows=1326 masks=[16, …, 1324, 1325] prox pair=28..30 zero-sum pair=(24, 25)
fresh P3 W rows=11 masks=[3, 4, 5, 6, 7, 8] prox pair=9..11
table tag=3  size=256   rows=1   data=46  mask=47  kind=pair
table tag=4  size=65536 rows=256 data=49  mask=305 kind=block
table tag=79 size=128   rows=1   data=561 mask=562 kind=pair
table tag=72 size=1     rows=1   data=564 mask=565 kind=pair
table tag=86 size=16384 rows=64  data=567 mask=631 kind=block
table tag=78 size=64    rows=1   data=695 mask=696 kind=pair
```

The same code with the legacy (unpaired) schedule reproduces the round-11 legacy
allocations too — 681 / 1325 / 7 rows at T32 and 5173 / 10321 / 28 at T2 (those runs
recorded `log_cols = 5`) — which is the control that the rule set, not a fitted
constant, is what is being applied (`LayoutRecomputation.test_the_same_rules_reproduce_the_legacy_allocation`).

---

## 2. O2 — the adapter

New, **separate** files (Fable's parser and its digest-bound results are untouched):

- `scripts/zk60_opus_repaired_capture.py` — the schema-2 parser, the recomputed layout,
  the O1 preflight driver and the O2 analysis driver.
- `tests/test_zk60_opus_repaired_capture.py` — 35 tests.

It imports `scripts/zk60_fable_joint_capture.py` **by path, read-only**, and reuses:
`zk60_fable_joint_rank.py`'s exact Fp2 / rref / null-space routines, and the joint model
class `RoleModel` itself — the same mathematics, the same site compression, the same
included and excluded observation classes, the same `h_identity_extra` residual test.
Only the parser and the recomputed layout are new, because the repaired profile has a
different claim shape. Neither Fable file changed: their digests are still
`9dd9b6bafaedeb19…` and `ad5e4e483c6dd8c5…`, as recorded in FA7 §11.

### 2.1 What the adapter accepts, and what it refuses

It accepts **only** `ffn-v3-mr1-fresh-poc/1` at T32/d16/f16, shifts `[7,0,14,6]`,
log_cols 8, inverse rate 8, Q = 256, function 1, schema 2, at commit `b41d036…`. Every
expected row index, claim part slice, row role, site name and coefficient tag is
recomputed from the source rules and compared; the capture's own declared layout is
never used as the expectation. Refusals (all covered by tests, **written and run before
the analysis**):

| refusal | test |
|---|---|
| changed `schema`, `kind`, `coverage`, `profile`, `transcript_domain`, `weight_policy`, `proof_digest_encoding`, `fully_verified`, `privacy`, field modulus, a non-null `slot`/`k` | `test_refuses_a_changed_header_label` |
| changed `source_commit` (full or abbreviated) | `test_refuses_a_changed_source_commit` |
| changed `shape` (t, d or f) or `shifts`, or missing shifts | `test_refuses_a_changed_shape_or_shift_set` |
| changed `log_cols` / `inv_rate` / `num_col_checks` | `test_refuses_changed_pcs_parameters` |
| dropped, duplicated, reordered or wrong-row-count roles | `test_refuses_a_changed_role_set_or_order` |
| **a missing pair row** — any A / W / H claim that lost its second mask part (the legacy single-mask form), and the table pair claims | `test_refuses_a_missing_pair_row` |
| a pair part whose coefficient is not `k·u`, or whose slice is not the next one; H's `(k, k u)` re/im form; the sum claim's fixed ±1, ±u | `test_refuses_a_broken_pair_coefficient_or_slice` |
| a missing, empty or altered `coefficient_tag` (including a P3 tag on a P1 capture) | `test_refuses_altered_or_missing_coefficient_tags` |
| altered, missing, duplicated `row_roles`, or a kind/site that is not the recomputed one | `test_refuses_altered_row_roles` |
| a missing or altered H zero-sum constraint, or a constraint on A / W | `test_refuses_a_missing_or_altered_public_constraint` |
| a `layout_description` that is not the recomputed one, or a `layout_digest` that is not its SHA-256 | `test_refuses_a_layout_description_that_is_not_the_recomputed_one` |
| a vector that is not n + Q long, a wrong `q_pad`, a missing column, a short Merkle path, an out-of-domain index, a short value list, short `proximity_rhos` | `test_refuses_broken_pad_and_column_structure` |
| a group whose clear vector does not reproduce its members' terminals, a tampered λ, a duplicated member | `test_refuses_a_group_whose_vector_does_not_reproduce_its_terminals` |
| a file name that is not the proof digest; a file sha256 that differs from the manifest | `test_refuses_a_digest_or_name_mismatch` |
| truncated JSON; a non-integer, boolean, float or out-of-range field coordinate | `test_refuses_malformed_json_and_non_integer_field_values` |
| **a legacy schema-1 capture carrying a repaired label** | `LegacySchema1Refused` (below) |

**The legacy relabelling case.** With only `schema` and `coverage` forged, the refusal is
`profile None is not 'ffn-v3-mr1-fresh-poc/1'`. With **every** header field forged —
schema, kind, coverage, profile, transcript domain, source commit, shifts, weight policy,
slot, k, proof-digest encoding, *and the genuine `layout_description` with its genuine
`e98e3189…` digest copied in* — it is still refused, and refused by the recomputation
rather than by the label:

```
role W: commitment has 7 rows; the recomputed ffn-v3-mr1-fresh-poc/1 layout has 11 (fixed expectation 11)
```

All 12 legacy round-11 captures are refused (`test_every_legacy_capture_in_the_round11_set_is_refused`,
and again in the delivered result file as `legacy_positive_control.adapter_refusals`).

---

## 3. O2 — the joint analysis

Result file: `results/zk60_opus_repaired_capture_analysis.json` (10 cases: 4 A, 4 H,
2 W; 0 refused). The model is FA7's, unchanged: one base-field unknown per (row, column),
so aliased rows are the same unknowns; the observations are **all** group message
coordinates `v_g[j]` for `j < n`, **all** proximity coordinates, **all** terminals
(claim values, including the H sum claim's public 0), and H's public zero-sum constraint.
Row aliases are retained (A: `X[0]` rows 14–15 in claims 7 and 10, `h16[0]` rows 10–11 in
claims 5 and 11; H: every helper and table plane in its own claim and in the sum claim,
and the `u` pair in both claim 4 and claim 11).

### 3.1 The numbers, beside Fable's legacy numbers

Identical across all four captures and both privacy modes. `n = 256`.

| role | observation base rows | unknowns | per-column mask rank | per-column disclosed | joint rank | **joint disclosed** | legacy (FA7 §6, T32) |
|---|---:|---:|---:|---:|---:|---:|---:|
| **A** | 3108 (2560 group + 512 prox + 36 terminal) | 178,688 | **12 of 12** | **0** | 3098 | **0** | 2n + 4 = **516** |
| **H** | 3098 (2560 + 512 + 24 + 2 extra) | 339,456 | **12 of 12** | **0** | 3088 | **2** | **2** |
| **W** (P3) | 1542 (1024 + 512 + 6) | 2,816 | **6 of 6** | **0** | 1538 | **0** | 2n + 2 = **514** |

Per data plane, every capture:

| role | planes | projected | isolated | fully recovered |
|---|---|---:|---:|---|
| A | `g8, rg, a16, u16, ru, h16, rh, X, z16, rd` (2 rows each), `tab[0..5]` (1, 256, 1, 1, 64, 1 rows) | **0** | **0** | none |
| W | `Wg[0][0]`, `Wu[0][0]`, `Wd[0][0]` (1 row each) | **0** | **0** | none |
| H | `hg, hu, hh, hz` (4 rows each), `h_t[0..5]` (2, 512, 2, 2, 128, 2 rows) | 2 | **0** | none |

H's `projected = 2` on every plane is the public identity touching every plane with its
±1 / ±u row, exactly as in FA7 §6; `isolated = 0` everywhere means no functional is
supported on any single plane. Compare the legacy T32 numbers this replaces: A `X[0]`
and `h16[0]` had `projected 258 / isolated 256`, and P3 `Wd[0][0]` had
`projected = isolated = 256` — **the whole plane recovered**.

### 3.2 H's residual is the public LogUp identity, and nothing else

For all four H cases:

- `disclosed_without_zero_sum_constraint`: **0**
- `disclosed_with_zero_sum_constraint`: **2** (`cross_column_increment` 2; per-column 0)
- adding the LogUp identity restricted to the data rows as an extra observation does not
  raise the rank (`identity_rows_in_observation_row_space: true`), and the surviving space
  has dimension 2, so it **is** the span of that identity's two base rows:
  `residual_equals_public_logup_identity: true`.

That is the functional whose value the proof itself fixes to 0 — a known public constant,
not a witness functional. It re-verifies FA2 §14.5 and FA7 §8 on the repaired
coefficients. **It is not a claim of H privacy in either direction**; it is a rank
statement under fixed coefficients.

### 3.3 The legacy positive control still fires

Re-run in this same result file (`legacy_positive_control`), with Fable's archived tool
on `/tmp/zk60-round11/final-observations`:

| legacy capture | role | per column | joint | plane |
|---|---|---:|---:|---|
| `ac560dde…`, `224abfdd…` (P3, T32) | W | 2 | **514** | `Wd[0][0]` **fully recovered** in both, isolated 256 |
| `ac560dde…`, `224abfdd…` (P3, T32) | A | 2 | **516** | — |
| `7cf29500…`, `882ffeb5…` (P1, T32) | A | 2 | **516** | — |
| all four | H | 0 | **2** | — |

and `singleton_functionals` still recovers the whole legacy `Wd[0][0]` row
(`recovered_entries: 256`). So the model, the tool and the attack are all still live;
the repaired captures give 0 because the captures changed, not because the attack was
retired.

### 3.4 Why the numbers moved (the mechanism, read off the model)

The per-column block space has `2·groups + 2` base rows (12 for A and H, 6 for W). In the
legacy layout the two singleton A groups (`X` at p2 under `a_mgu[0]`, `h16` at p5 under
`a_mdd[0]`) and the singleton W group (`Wd` under `w_mdd[0]`) each had **one** base mask
row, so each contributed one dimension to a two-dimensional group slot: mask rank 10 of
12 for A, 4 of 6 for W, hence 2 disclosed per column and `2n` in total, plus the 4 / 2
terminal functionals of the all-base groups. In the repaired layout each of those sites
is an independent pair with coefficients `k` and `k·u`, which span Fp₂ over the base
field, so the masks reach full block rank (12 / 12, 6 / 6) and the per-column term is 0;
the proximity pair (checked non-degenerate by the verifier's
`check_masks`) does the same for the proximity slot, and the cross-column kernel then
adds nothing for A and W (`cross_column_increment` 0). H was already 0 per column and is
unchanged; its 2 come only from the zero-sum constraint.

Directly visible in the delivered file: FA7 §7's `L_b` elimination — the projection that
recovered `X`, `h16` and the T32 `Wd` plane — **no longer has a mask-free form**. The tool
attempts it on every singleton group and records the refusal
(`legacy_singleton_attack[*].applicable = false`, reason `claim k: not (one data slice +
one single-row mask)`, `mask_parts` 2 for A's claims 10 and 11, 2 for W's claim 2, 2 and 4
for H's claims 3 and 4).

Codex's round-11 per-column subset script is legacy-only and now refuses these captures
(`codex: not exactly one unreferenced row` — the repaired layout has a proximity *pair*).
The same quantity is reported as `analysis.per_column.disclosed_per_column`, which FA7 §6
established equals that subset. No new mathematics was introduced to cover the gap.

---

## 4. Included, excluded, structure-only

**Included** (unchanged from FA7): group-vector message coordinates, proximity vector
coordinates, all terminals, the row aliasing, and H's public zero-sum constraint.

**Excluded, stated and not costed** — each needs its own argument, and **nothing here
bounds them**:

| class | why it is out |
|---|---|
| `pads` | the Q pad coordinates `v[n .. n+Q)` are linear in the Q fresh pad unknowns of each row, not in the message unknowns (FA2 §14.6) |
| `sampled_columns` | the Q opened encoded columns (values, salts, paths): hidden by the pads (Vandermonde) and the salted leaves (hash assumption) |
| `cfs` | the CFS mask commitment and the masked sumcheck round messages: nonlinear in the data (FA6 / O4) |
| `repeats` | repeated proofs of the same witness with fresh challenges (FA8); every capture is analysed alone |
| `unopened_columns` | the Merkle root over unopened columns: a computational hiding assumption |

**Structure validated, values still excluded:** every clear vector is exactly n + Q = 512
long with `q_pad = 256 = num_col_checks`; there are exactly 256 sampled columns per role,
each with an in-range index over the 2048-point domain, an 11-node Merkle path, a 32-byte
salt and one value per commitment row. Those are shape checks only; no pad or column
value enters the linear model.

**No new mathematical assumption was needed** to run FA7's model on these captures, and
none was added. The model was not expanded, its mathematics was not redesigned, and the
joint analysis was not replaced by per-group rank checks. The only adaptations are
parsing-side: the paired mask parts, the proximity *pair* (two unreferenced rows instead
of one), and the plane naming. There is therefore **no unresolved-assumption item** to
hand back on O2.

---

## 5. Commands, exit codes, resources

All on the WSL box, Python 3.10.12, stdlib only, single-threaded. The full analysis
(command 4, including the legacy positive control) measured under `/usr/bin/time -v` at
**38.8 s wall, 95.1 MB peak RSS** — captures are streamed and released one at a time,
nothing near the 2 GiB budget. Per case: A ≈ 4.6 s, H ≈ 1.5 s, W ≈ 0.03 s.

`<published>` = `/home/victor/IntelligenceRegulation/results/zk60_round16_validation.json`
(§0; it becomes `results/zk60_round16_validation.json` in this worktree at the next merge).

| # | command | exit | result |
|---|---|---:|---|
| 1 | `python3 scripts/zk60_opus_repaired_capture.py preflight --captures-dir /tmp/zk60-round16/captures --manifest <published> --cross-manifest /tmp/zk60-round16/summary.json -o results/zk60_opus_capture_preflight.json` | 0 | 4 parsed, 0 refused, **167 checks, 0 failed** |
| 2 | `python3 -m unittest discover -s tests -p 'test_zk60_opus_repaired_capture.py' -v` | 0 | **35 tests OK**, 0 skipped, 50 s |
| 3 | `python3 -m unittest discover -s tests -p 'test_zk60_fable_joint*.py' -v` | 0 | **57 tests OK**, 0 skipped, 29 s — Fable's suites do not regress |
| 4 | `python3 scripts/zk60_opus_repaired_capture.py analyze --captures-dir /tmp/zk60-round16/captures --manifest <published> --cross-manifest /tmp/zk60-round16/summary.json --legacy-dir /tmp/zk60-round11/final-observations --runs-file <runs.json> -o results/zk60_opus_repaired_capture_analysis.json` | 0 | 10 cases, 0 refused, `all_roles_meet_the_expected_target: true`; legacy control reproduced |

Command 2 was first run with the negative tests in place **before** any analysis, as the
dispatch requires, and re-run after every tool change; the row above is its final state.
Commands 1–4 are recorded inside the analysis result file under `commands`. The earlier
interim-bound runs of commands 1 and 4 gave identical per-role numbers (166 checks then,
one fewer because the cross-check did not yet exist).

## 6. Files and digests

| file | sha256 | note |
|---|---|---|
| `scripts/zk60_opus_repaired_capture.py` | `9bc226dce00fd8d1ede28cf49220eab52cf60a019c92fd2b556f1d0e10c516a1` | new (Opus 5) |
| `tests/test_zk60_opus_repaired_capture.py` | `e4de350e027b4122d24ae94319de767ca054d5cf06a4c258ac27ceb20b91cce9` | new (Opus 5), 35 tests |
| `results/zk60_opus_capture_preflight.json` | `10baf88fb01f042f999c35ebff9671cd0540bf3fb0e0801fdd2aeafcd13244df` | O1 |
| `results/zk60_opus_repaired_capture_analysis.json` | `2290978d4d674db6319e523e306e03c895fd94c72bf9a037642ce9f0ec2a5b0f` | O2 |
| `docs/zkmatrix-poc/ZK60_OPUS_REVIEW.md` | this document | |
| `scripts/zk60_fable_joint_capture.py` | `9dd9b6bafaedeb19c8e2ca008cc255bcede84502dd1f58d3091223e7f6bdf8b2` | **unchanged** (Fable, FA7) |
| `scripts/zk60_fable_joint_rank.py` | `ad5e4e483c6dd8c5f73a87ddb0af1d06c3084576e82428e9c2ada6a764ffbb5b` | **unchanged** (Fable, FA2/FA3) |

Both result files record the three tool digests, every capture's file digest, the
manifest digest and the source pin; `ResultsBinding` in the test file re-hashes them and
fails if a tool changes without a re-run. Nothing under `hashline/`, `zkp-core/`,
`codex-audit-*` or any Fable-owned file was touched.

## 7. What this establishes

Under the FA7 linear observation model, with the captured (fixed) public coefficients,
one proof at a time, on the four round-16 captures of the experimental
`ffn-v3-mr1-fresh-poc/1` profile at T32/d16/f16, function 1:

- the four captures are internally consistent, digest-bound, and structurally exactly the
  repaired layout recomputed from the source (O1);
- **A discloses 0 base-field dimensions and P3 W discloses 0**, per column and jointly,
  in both privacy modes, on every plane (projected and isolated both 0, nothing
  recovered);
- **H discloses 2, identified explicitly as the span of its public LogUp identity's two
  base rows, and 0 without the zero-sum constraint**;
- the legacy attack remains live and reproduces FA7's numbers on the legacy captures, and
  the repaired adapter refuses those captures.

## 8. What this does NOT establish — limits

- **Not whole-protocol zero knowledge.** It is a rank statement about a linear model with
  fixed public coefficients. It is not a simulator, not a conditioning or challenge-
  distribution argument (FA3 B2), and **not an upper bound on disclosure**.
- **Four excluded observation classes** (§4) are outside the model entirely: pads, the
  sampled encoded columns, the CFS channel and its masked sumcheck round messages, and
  repeated proofs of one witness. A zero here says nothing about them.
- **Only this profile.** No registered/seamed block profile, no stable private model
  identity or slot binding, no function 2, no attention, no wire decoder, no transport
  envelope, no proof-from-bytes verification. `weight_policy` is `fresh-per-proof`: P3
  proves the FFN relation under a fresh W commitment and **authenticates no previously
  named model**.
- **One shape, one function, four proofs.** T32/d16/f16, log_cols 8, function 1. No T2
  repaired capture exists; no repeated-witness set exists.
- The captures hold **no witness values**; nothing here is compared to a ground truth.
  Truth comparison lives only in the in-process Rust harness, which this review does not
  run.
- The binding is to a published record that lives in Codex's integration checkout, not
  yet in this worktree (§0); the capture files themselves live under `/tmp`, so the
  digests recorded here are the durable part.
- No private-block, deployment or throughput acceptance follows.

## 9. What Codex must do next

1. **Merge `results/zk60_round16_validation.json` into this review branch** and re-run
   commands 1, 2 and 4 with `--manifest results/zk60_round16_validation.json`: the tests
   already accept either location, and
   `test_published_validation_record_agrees_with_the_interim_one` re-checks every digest,
   byte length, privacy mode and layout digest. Note that a consumer must bind to
   `capture_source_commit`, not the record's own `source_commit` (§0) — worth making
   explicit in the record's own documentation, since the two differ.
2. Review these conclusions before any privacy acceptance. The O1/O2 result is a bounded
   linear-model input to FA8, not a privacy verdict; the excluded classes of §4 and the
   scope limits of §8 remain open and are Codex's judgment.
3. O3 (the implemented mask schedule audit) and O4 (the attention inventory) are still
   open in `ZK60_OPUS_QUEUE.md`; the CFS-challenge and attention rows named there are
   precisely the channels this analysis excludes.
4. If a repaired T2 capture, a repeated-witness set, a function-2 capture or a
   registered/seamed capture is produced, the adapter must be extended deliberately — it
   refuses all of them today by design, and that refusal is the safe default.
