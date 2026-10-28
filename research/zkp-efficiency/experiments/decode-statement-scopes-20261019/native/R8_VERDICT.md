# D24 review, round 8: verdict on the native R8 tree

Written 2026-10-19 (14:59 UTC) by the independent review lane. Not a privacy
review: only Victor rules on privacy.

## What I reviewed

- **Frozen copy.** `ops/zkp-mvp/trained-1b-review-r8/` is my copy of the R8
  freeze (2026-10-19T14:38:35Z, tree hash 7f64276a...).
  `ops/zkp-mvp/trained-1b-review-r8.sha256` has 220 entries and matches
  `r8/manifest_frozen.json` file for file. The tree hash recomputes, and the
  copy was unchanged after every run.
- **Diff.** I read every hunk of `r7-vs-r8.patch` (1,042 lines, 10 files,
  the same size as the author's).
- **Binary.** My own CLI, built from the untouched frozen copy, is
  `r8/zk60_trained_block.review-r8.release.bin` (sha256 d1d7d544...).
- **Log.** `PROGRESS.md`, section ROUND 8.

All measurements: shared box, one run each [MEASURED].

## Verdict

**R8 is ACCEPTED on soundness.**

R8 extends R6's per-layer mechanism from `sh_s` to all eleven export-chosen
calibration constants. It does this through one door,
`Shape::with_layer_calibration`, which:

- validates every value in its unchanged class;
- refuses any change to the plane list;
- is applied on both the prover and the verifier side.

Each layer's own constants are bound twice:

- in the trained identity, as distinct per-field labels;
- in that stage's schedule line, so they reach the run header.

The identity also covers each layer's manifest SHA-256. So two different
per-layer exports cannot collide on an identity, and swapping constants
between layers or between fields moves it. My tamper tests confirm both.

Supporting results:

- **No-wrap.** It holds over every class at all six trained profiles. My
  independent worst case is 2^43.32, against p/2 = 2^63.
- **Compatibility.** Run-wide and `sh_s`-only identities are unchanged. Under
  my R8 binary, each of the following verifies read-only and its published
  statement passes the byte-for-byte check:
  - the b7 T128 run (97c4acda...);
  - 8B T32 (259dad7c...);
  - TinyLlama T32 (9b71dfb0...);
  - my rung run (72098637...).

## 1. The door, on both sides

**What `with_layer_calibration(cal)` does, in order:**

1. Refuses any shape without a trained calibration.
2. Checks every class through `derive_at_width`:
   - tn 1..=16;
   - cn 1..=2^20;
   - ceps 1..=2^40;
   - norm window = tn + 1 + bits(D_max), at most 32 bits;
   - sh_ao at most 8;
   - the one-limb shifts 1..=8 and the two-limb shifts 9..=16.
3. Runs the CS-8 rebuild and the trained-class check.
4. Rebuilds `Ids` / `HIds` and compares them (`n_a`, the limb counts, `n_h`).
   Any difference is refused with "moves the plane list".

**Where it is called:**

- the loader, per layer;
- `TrainedModelStatement::check_self`;
- `RunStatement::new_bound_from_digests` (the prover and the verifier both
  build this);
- `stage_shape`;
- the sealing pass, whose witnesses are built at each layer's calibration
  (one layout per calibration).

The base and the per-layer values are applied through the same function on
both sides.

**Export format:**

- `profile_constants` nulls must equal `per_layer_constants_differ` (the R6
  rule).
- The per-layer fields are the listed keys of the eleven.
- `masked` compares every non-listed constant across layers.
- Manifests are pinned by profile.json, and their SHA-256s are in the
  identity.

**Tamper results** (`review_r8_inner::r8_1`, on the author's 4-layer rung
export where layer 1 owns all eleven constants and layer 2 owns seven;
`r8/r8-fast.log`):

| test | result |
|---|---|
| the honest export | proved; verified with 11 controls refused; published. statement.json lists layer 1's 11 own keys in canonical order (sh_s first), layer 2's 7, layer 0 none |
| T5: every field out of class at layer 1, re-pinned (23 values): tn 11 (moves the plane list: A 83 -> ...), tn 17 / 0, cn_a 0 / 2^20+1 / -5, cn_m 0 / 2^20+1, ceps 0 / 2^40+1, sh_ao 9, sh_qkv 0 / 9, sh_s 0 / 9, sh_o 8 / 17, sh_g 0 / 9, sh_h 8 / 17, sh_z 0 / 9 | all 23 refused by name on the verifier side AND by `stack-prove`, with no run directory created |
| T6: `f_e` (not a calibration field) listed per layer | all layers equal: loads (a different profile, so a different identity); one layer at another f_e: refused ("one calibration per run") |

## 2. Binding

**Encoding.**

- Each layer record carries a label and value only for its own fields, in
  canonical order. `sh_s` comes first with R6's labels, so an `sh_s`-only
  record encodes exactly as in R6.
- Labels and values are length-prefixed, which makes the encoding
  unambiguous.
- The record also binds `export-manifest-sha256`.
- `check_self` refuses an own value equal to the base, so there is one
  encoding per statement.
- The stage schedule line gets one clause per own field ("; {label} {v} (the
  layer's own; the run's is {b})"). The header absorbs it.
- statement.json renders the own keys in the same order.

**Tamper results:**

| test | result |
|---|---|
| T1: layers 1 and 2 swap their whole calibrations (re-pinned) | the identity moves; the honest run is refused under the swapped statement |
| T2: layer 1 swaps sh_o 11 <-> sh_h 14 (same window) | the identity moves; the run is refused |
| T3: layer 2 swaps cn_a 1250 <-> cn_m 2050 | the identity moves; the run is refused |
| the author's test: each of layer 1's eleven constants flattened to the base, own statement pinned | each refused by the run binding (passes in my run) |

**Base rule.** The base is the most common combination of the listed fields
over the run's layers. Ties go to the smallest key vector in canonical order
(sh_s first).

- T7: a 2:2 tie between the rung base (sh_s 5) and `r8_layer_cal(2)` (sh_s 4)
  gives run sh_s 4, as the rule says. It verifies and publishes. The mirrored
  layer order gives another identity.
- The base is a deterministic function of the export and the `--layers`
  range, and both sides compute it, so a prover cannot choose it.

**Collisions.** Two different per-layer exports would need equal per-layer
manifest SHA-256s and equal own-field encodings, which means a SHA-256
collision. A layer's constants cannot move without moving the identity.

## 3. No-wrap over every class (recomputed independently)

`reviewer_nowrap_r8.py` (`.json`) is written from argument.rs. It covers:

- `SC_DZC` c0 / c6, the norm quotient `g·x·2cn + D·2^tn − 2^(tn+1)·D·y − nr`
  (cn_a and cn_m);
- c1 / c7, the complement;
- the `SC_TZC` isqrt host, Σx² + ceps = D² + a1;
- the seven requant hosts.

The sweep takes every tn, a ceps grid over the whole class, and cn at both
ends. That is a superset of what the plane-list guard admits: 410 admitted
(tn, ceps) points at width 2048 and 369 at width 4096. All six trained
profiles are covered.

| profile | worst clause | other clauses |
|---|---|---|
| TinyLlama T32/T64/T128 | norm quotient 2^43.08 | isqrt host 2^42.59; down host 2^35 |
| 8B T32/T64/T128 | isqrt host 2^43.32 | norm quotient 2^43.05; down host 2^36 |

- My worst case adds the absolute values of both sides.
- The author's worst is 2^43.09 (the norm quotient), which agrees.
- p/2 = 2^63, so the margin is about 2^19.6 [COUNTED].
- Every relation is block-local: no clause mixes two layers' constants.

## 4. Compatibility (read only, my binary, my verifier copies of the original exports)

| run | identity | verify | statement |
|---|---|---|---|
| b7 T128, R6 per-layer `sh_s` | 97c4acda... | verified (46.2 s) | byte-checked |
| 8B T32, run-wide | 259dad7c... | verified (36.9 s) | byte-checked |
| TinyLlama T32, run-wide | 9b71dfb0... | verified (8.3 s) | byte-checked |
| my rung run | 72098637... | verified | byte-checked |

- The b7 T128 result shows an `sh_s`-only per-layer identity and its stage
  lines are unchanged.
- The two T32 verifier copies are hard links to the calibration lanes'
  original exports, with no `seq_*`.

## Notes

| id | what | severity |
|---|---|---|
| N-r8-a | the identity encoder writes `u64::try_from(v).unwrap_or(u64::MAX)` for an own value | very low (latent) |
| N-r8-b | at the trained profiles, per-layer `norm_tn` is effectively run-wide | export guidance |
| N-r8-c | the base depends on the `--layers` range | by design |
| N-r8-d | parity with the Python reference at per-layer constants on a REAL export is still owed | fidelity, not soundness |

- **N-r8-a.** Two different negative values would encode the same. This is
  unreachable today: every class is positive (cn, ceps ≥ 1), and the door
  runs before the encoder on every construction path. Encoding as `i64`, or
  refusing in the encoder, would make that independent of call order.
- **N-r8-b.** The trained profiles' norm window is exactly 32 bits, so a
  lower tn moves the plane list and a higher tn leaves the class. `ceps` is
  free only while bits(D_max) stays the same. The door refuses both by name.
- **N-r8-c.** As in R6, a sub-range can get a different base and so a
  different identity. The layer list is already in the context.
- **N-r8-d.** `stack-prove` refuses on any parity mismatch, so a wrong
  reference cannot be proved.

## Test runs

- My tamper test `r8_1`: 1 passed.
- The author's targeted tests on my binary: 53 passed, 0 failed, 3 ignored.
  This includes all four `r8_tests`, the fully per-layer stack test,
  `review_r5_3`, `review_n_r6_b`, `privacy_q2`, and the per-layer `sh_s`
  test.
- The author's full suite on this tree (`r8-suite`, not re-run here): 707
  passed, 0 failed.

## Evidence (this directory)

- `PROGRESS.md` (ROUND 8), `r7-vs-r8.patch`, `reviewer_nowrap_r8.py` /
  `.json`.
- `r8/`: `r8_queue.sh`, `binaries.sha256`, and every `r8-*` log, guard
  record and done marker.
- Scratch, `ops/zkp-mvp/trained-1b-review-r8-scratch/`:
  - `review_r8_inner` in `hashline/src/private_block/trained_block.rs`;
  - `verifier-8b-T32/` and `verifier-tl-T32/`, hard links into the original
    exports, read only.
