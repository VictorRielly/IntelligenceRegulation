# Census sub-lane (GN-1 / GS-14 at the trained constants, real weights) — ledger

Sub-lane of the PRIVACY GATE lane. Owed item: §3 step 4 OWED and §10b item 4 of
`results/zk60_gate_tinyllama_20261017/PRIVACY_STATEMENT_TRAINED_T32_DRAFT.md`.
**Nothing here is a privacy acceptance.** It is a completeness census of the
witness builder and the prover's refusal sites on the admissible class at the
trained pg_rot1 constants. Only the security review process can accept
anything; rulings are Victor's.

Write set (exclusive): `ops/zkp-mvp/trained-1b-gate-census/` (copy of the R5b
frozen tree + a test-only census module) and this directory.

## Entries (UTC from `date -u`)

- 2026-10-18 ~04:43: first start; read the lane rules, the census disposition,
  the 125M census module and its independent check, the R5b witness builder,
  prover core, pad rule, run layer, trained loader. Nothing written before the
  usage cut-off (~04:50).
- 2026-10-19T09:27Z: resumed on the coordinator's message (box rebooted
  2026-10-18 21:29 UTC; /tmp wiped; write set did not exist).
- 2026-10-19T09:29Z: created the write set; `rsync -a --exclude target
  --exclude target-gpu` of `results/zk60_1b_native_20261017/r5b/frozen-tree/`
  into `ops/zkp-mvp/trained-1b-gate-census/`: 218 files, every one equal to
  `r5b/manifest_frozen.json`, no extra file, tree sha256 recomputed from the
  copy = `440133975de99fe0...` = the manifest's (formula: sha256 over sorted
  lines `"<path> <sha256>\n"`). Record: `copy_verification.json`.
- 2026-10-19T09:29-09:35Z: design work (reading only, below).
- 2026-10-19T09:35Z: **STOPPED on the coordinator's instruction.** Privacy
  review round 2 (Q-7) found that R6 moves the CS-3 lookup-miss refusal into
  the sealing pass, so this census no longer bears on the privacy sentence.
  It becomes a completeness item and was dropped from the gate lane's
  ordering. **No build, test or guarded job was launched by this sub-lane.
  Nothing is pending.** No source file in the copy was edited, so there is no
  patch. `ops/zkp-mvp/trained-1b-gate-census/` is an UNEDITED, verified copy
  of R5b. On resume, re-copy from the R7 frozen tree instead of reusing it.

## What was read (R5b frozen tree, paths under `hashline/src/`)

- `private_block/witness.rs` (whole file): every builder refusal, in order:
  - norm denominator, `:477`, `:489`;
  - norm quotient/remainder, `:497`;
  - Q / K / V, `:594-596`;
  - QR / KR, `:599`, `:601`;
  - score, `:626`;
  - causal maximum attainment, `:644`;
  - exp difference: the loop `:652` and the `A_E` pad pass `:764`;
  - softmax denominator, `:660`;
  - softmax quotient/remainder, `:673`;
  - O, `:715`;
  - AO, `:719`;
  - residual 1, `:724`;
  - FFN gate, `:792` (and the index guards at `:803-804`);
  - FFN up, `:796`;
  - FFN product, `:808`;
  - FFN down, `:810`;
  - residual 2, `:832`;
  - output conversion, `:58`;
  - structural refusals: `Ids::new`, the pinned norm-limb count, CS-1 and
    CS-4 `check_for_shape` (`:547-548`), the input length.
- `private_block/protocol.rs` (whole file):
  - `prove_core`: CS-8 (`:895-896`), CS-1/4 (`:898`), the witness shape
    (`:902`);
  - the three histogram paths that file a miss in bucket 0 (`:925-942`);
  - CS-3 `refuse_lookup_misses` (`:948`, text per K-1/K-2 `:439-452`);
  - the S-4 zero-denominator refusals: `helper_one` `:622-634` (byte
    helpers), `inverses` `:547-550` (exp pairs `:1032`, activation pairs
    `:1034`, the three table helpers `:1064`);
  - `check_opening` (audit, the C-4 group count `:305`, challenge refusals
    `:286-297`), `check_endpoint_opening`, `endpoint_geometry`,
    `single_block_profile_allowed` (R2-4), `fits_the_ntt_tables`.
- `private_block/argument.rs`:
  - `run_slot`: schedule and table-shape refusals (public); zero CFS `c`
    `:482`; degenerate terminal `e` `:627`;
  - `nonzero` `:987-992` (`nu` `:1182`, `zeta` `:1183`, `:1253`);
  - `tile_rep` `:835`, `tab_group_is_declared` `:847`, the Dom::T / Ht group
    refusals `:1222`, `:1774`, the functional count `:1961` (all public).
- `private_block/pad.rs`: the pad rule, ZERO/EXEMPT table (`A_E` the only
  exempt A plane), `every_checkable_relation_holds`, `indicator_slots`.
- `private_block/layout.rs`:
  - `lookups_at` `:701-785`: every top-limb pin is the shape's `2^(8-sh)` or
    `2^(16-sh)`; C-6 drops the norm top pin at a 32-bit window;
  - `Layout::for_shape` door `:1104-1125`.
- `private_block/shape.rs`: `derive_at_width` `:237-277`, the trained door
  `:1388-1420`, `check_trained_class` `:1435-1449`, `check_softmax_window`,
  `check_f_e_class`, `check_constructed` (CS-8), `Shape::build` refusals,
  `slot_lengths`, `totals`, `a_groups`, `h_groups`.
- `private_block.rs`: `AttentionPublic::check_words` `:548-579`,
  `FeedForwardPublic::check_words` `:664-686` (P-2, S38-F1(a) at `:682`),
  `prepare_endpoints`.
- `private_block/run.rs`:
  - `prove_run_with` `:846-985`: CS-6, CS-1/4 for a block source,
    `policy_fits_the_shape`, `check_endpoints`, the OS entropy read, the
    boundary length `:910`, the boundary prepare;
  - `RunStatement::new_with_calibration` `:339-414` (public);
  - `RunShape::new` (CS-7).
- `private_block/boundary.rs`, `endpoint_g.rs`, `wire.rs`: every refusal is a
  function of the public geometry; the input words are int16 and therefore
  canonical.
- `private_block/trained_block.rs`:
  - the loader (`load_layer_mode` `:876-1008`, refusals all public);
  - `parity` `:1110`;
  - `seal_and_record` `:1973-2041` (builder + parity before the run header,
    H-1);
  - `StackSource::witness_of`'s determinism check `:1837`;
  - `BlockCache::get`'s digest check `:1752`;
  - `padded_plane`.
- 125M census `wt-zk60-block125m/.../census_shaped_tests.rs` (all 1,465
  lines). Its check is `wt-zk60-block125m-review/.../census_check_tests.rs`
  (the path in the brief is wrong: it lives on the review worktree). Also
  read: `ZK60_SHAPED_REFUSAL_CENSUS_DISPOSITION.md`. There is no
  `results/zk60_census_check/` directory.
- Kernel `private-block-kernel-shaped/src/lib.rs`: it takes the trained
  calibration and shifts (`with_norm_calibration`, `with_shifts`). The
  bridge is `parity::kernel_shape(sh)`.
- Evidence that R5b-code honest proofs already passed every prover site at
  real weights. These runs did not refuse, so they had 0 CS-3, 0 S-4 and 0
  challenge-only events:
  - the gate's R5b captures (prover + recorder), L = 22, on ho00 and on the
    all-zero input (gate PROGRESS ~00:10 UTC 10-18, draft §10a);
  - the native R2-3 stack, ho00, 22 layers, on the R2 tree (before CS-3).
  - **ho01 has never been proved through all 22 layers on R5b-code.** R2-2
    proved ho01 at layer 21 only, on the R2 tree.

## Refusal sites after the builder: decisions from READING (not tested)

Classes: PUBLIC means the site is a function of the shape and the public
statement only. CHALLENGE means a function of Fiat-Shamir draws only. S-4 is
the zero LogUp denominator. CS-3 is the lookup miss.

| Site | Class | Reachable for an admitted witness? | Bound / reason |
|---|---|---|---|
| CS-8 / CS-1 / CS-4 / CS-9 shape and statement re-checks; witness shape | PUBLIC | no (honest statement from the loader at the run's shape) | statement and shape only |
| U8 word at a TRUE position outside [0,256) (bucket 0, then CS-3) | CS-3 | no | each looked plane's builder class equals its lookup window. Int8 `sym`: [-127,127]. int16 limbs. Remainders biased into [0,2^sh), pinned by `2^(8-sh)` / `2^(16-sh)`. Norm 2^32 (C-6). Softmax 2^14. p < 2^10. isqrt 2^24. **To be TESTED** (`census_trained_lookup_windows`) |
| U8 word at a PADDED position (pads at T32: Dom::F, L, Tab) | CS-3 | no | every looked plane on a padded domain is ZERO-rule and the builder leaves its pad at 0, so the word is the lookup constant (0 or 127). To be read off `lookups_at` and `pad::a_rule`, not typed in (fixes C-3's "typed-in" premise) |
| exp pair not a table row | CS-3 | no | the builder writes `A_E = exp[delta]` on the whole S cube (`:655`, `:767`), delta in [0,255) (builder check) |
| activation pair, true position | CS-3 | no | `a16 = act[g8+128]` (`:804`); g8 in [-128,127] by the builder |
| activation pair, padded Dom::F position (2,560 of 8,192 per token) | statement refusal S38-F1(a) | no | the pair (128,0) is a row iff `act[128]=0`; refused at construction otherwise. Every frozen SiLU member has `act[128]=0` |
| LogUp multiplicity wraps the field | none | no | totals ~10^7 ≪ p |
| zero LogUp denominator (byte helpers, exp pairs, activation pairs, table helpers) | **S-4** | only by challenge coincidence | per block ≤ 1,536 / 2^128 = 2^-117.4, L = 22: 2^-113.0 [COUNTED] (equal to the draft's figures). Whether it fires depends on the input only through which values the witness carries |
| zero CFS `c`, terminal e in {0,1}, `nu`, `zeta`, opening coefficients, dependent proximity | CHALLENGE | only by challenge coincidence | none reads the witness |
| C-4 opening-group count | PUBLIC / CHALLENGE | no | the declared count is a function of the shape. A mismatch needs two claims' point tails to collide |
| mask budget `L + 256 <= 512` (zk.rs assert) | PUBLIC | no | slot lengths at the shape |
| pad indicators (`tile_rep`, Tab/T/Ht group checks) | PUBLIC | no | shape only |
| run layer: CS-6, CS-7, boundary length, endpoint root/geometry, wire sizes | PUBLIC | no | statement and geometry |
| OS entropy read, segment sink | environment | — | input-independent |
| CLI: parity (P-8 admission), sealed-witness determinism, block digest reload | admission / unreachable | no (determinism: exact integer sums) | — |

## The census design (to run on R7, for completeness)

**Trained constants (pg_rot1, export `results/zk60_1b_calibration_20260929/export/pg_rot1_export_T32`, read-only):**

- tn 10, Cn_a 3999, Cn_m 3122, Ceps 91255;
- shifts qkv 8 / s 6 / o 9 / ao 3 / g 8 / h 14 / z 5, rope 7, u 0;
- f_e 9, f_p 9.

The shape is `Shape::tinyllama_t32_trained(&trained_calib_tests::pg_calibration(), 9)`. The test must assert it equals `ex.shape_for(&ex.run_constants(&layers))`.

**Bounds at these constants [COUNTED]:**

- D_max = 1,482,910 (21 bits). The norm window is 32 bits, four limbs, with C-6's top pin dropped.
- den_max = 3,036,999,680 < 2^32, a margin of 0.50 bits. D_min = isqrt(Ceps) = 302.

What moves against the 125M census:

- **Norm quotient is now REACHABLE.** It reaches ±500 (norm_a) and ±390 (norm_m) against the class ±127, so the builder refuses first. At the frozen calibration it was unreachable.
- **AO is reachable.** It reaches 4,161,536 against int16.
- **Q/K/V and the gate** reach 130,048. QR/KR reach 254. The score reaches 16,129. FFN up reaches 33,292,288, the product 65,536, down 738,197,504. All of these are refused by the builder first.
- **O stays unreachable.** It stays at ±127.
- **Softmax** stays unreachable: wrho_s = 14 and T·2^f_e = 16,384.
- **Dom::F pads**, so the S38-F1 row becomes "covered by the statement refusal".
- **Duplicate lookups.** At sh 8 the one-limb pin has coefficient 1, a duplicate of the byte lookup (draft §3(e)).

**Module** (test only): `hashline/src/private_block/census_trained_tests.rs`.

- The only other edit is in `private_block.rs`: `#[cfg(test)] mod census_trained_tests;`.
- Every line follows K-2: it prints only counts, class names and booleans. It prints no hidden value and no digest of a hidden file.

Tests (ordinary filter unless marked):

1. `census_trained_classifies_every_data_dependent_site`
   - Port `census()` with every constant read from the shape (`sh.norm_*`, `sh.sh_*`). The admitted y bound is min(127, q_max) per norm.
   - Expectations:
     - norm quotient (a, m), AO, Q, K, V, QR, KR, score, residual 1, FFN gate/up/product/down and residual 2 are builder-first;
     - S38-F1 is statement-refused;
     - the rest are unreachable;
     - there are 0 FINDING rows.
2. `census_trained_lookup_windows`
   - Port the 125M window test with `sh.sh_*` replacing `SH_*`; SH_ROPE stays 7.
   - The windows must be: AO 2^3, O 2^9 (two limbs), product 2^14 (two limbs), down 2^5, score 2^6, qkv/gate 2^8, norm 2^32, softmax 2^14.
   - Every looked plane must be accounted for.
3. `census_trained_pad_words_are_the_lookup_constants`
   - For each padded lookup domain, every lookup's planes are ZERO-rule, so the word is its constant.
   - Assert the constants lie in [0,255].
4. `census_trained_unreachable_premises`
   - The norm remainder over a (D, x, g) sweep at Cn_a and Cn_m, tn 10, Ceps 91255.
   - The softmax row sums at f_e 9, T 32; O at sh_o 9; MASK = -127.
   - `kernel_shape(sh)` carries the shape's calibration.
   - The constructor refuses a broken exp table or RoPE table at the trained shape.
5. `census_trained_challenge_only_and_s4_counted`
   - Counts: c_s ×23, e × ext, nu ×12, zeta per padded host, groups a+h.
   - Compute the S-4 bound from the shape.
   - A helper test: `helper_inverses_u8` refuses iff the carried values include the one zero-denominator byte.
6. `census_trained_public_sites_hold`
   - `check_constructed`, `check_trained_class`, `fits_the_ntt_tables`, `Layout::for_shape`;
   - every slot within L + 256 <= 512;
   - `tile_rep` for each indicator/slot pair;
   - `endpoint_geometry`; `RunShape::tinyllama_trained(sh, 22)`;
   - the single-block path refuses (R2-4).
7. `census_trained_s38f1_members` (cheap)
   - Every SiLU member the export names has `act[128] = 0`. The members are (-5,-13), (-2,-11), (-4,-13), (-1,-10), (-4,-12), (-3,-11), (-1,-11).
   - At the trained shape, `act[128] = 1` is refused by S38-F1(a)'s name.
8. `#[ignore]` `census_trained_edge_families`
   - Synthetic words at the TinyLlama trained shape.
   - Sites:
     - norm quotient (new): pick gamma by the exact formula, so that y = 127 is inside and y = 128 is past;
     - Q (acc_top(8,127));
     - score (sh_s 6);
     - AO (sh_ao 3);
     - FFN gate (acc_bottom(8,-128));
     - FFN product (sh_h 14);
     - FFN down (sh_z 5).
   - Inside the edge, the case must be:
     - admitted, with its plane on the edge;
     - `every_checkable_relation_holds`;
     - LogUp-clean;
     - equal to the kernel's output.
   - Just past the edge, the builder and the kernel must both refuse by the site's name.
   - `gain_for_one` must be re-derived: at Cn 3999 and D 305, g = 78 gives y = 1.
9. `#[ignore]` `census_trained_real_weights`
   - Environment:
     - `ZK60_CENSUS_EXPORT` = the export dir;
     - `ZK60_CENSUS_SEQ` = ho00 | ho01 | zero;
     - `ZK60_CENSUS_LAYERS` = 0..22;
     - `ZK60_CENSUS_KERNEL` = 1;
     - `ZK60_CENSUS_PROVE` = 1;
     - `ZK60_CENSUS_OUT` = a JSON path.
   - Per layer:
     - `ex.load_layer(&sh, &c, l, false)`, with every SHA checked; record `act[128] == 0`;
     - x_in from `ex.load_seq`, or zeros; check chain continuity;
     - `witness::build_shaped`; record the refusal class name, if any;
     - parity against x_out (zero → zero);
     - the (u8, exp, act) miss counts via `lookup_values` / `exp_deltas` / `act_indices`;
     - `every_checkable_relation_holds`;
     - at layers 0 and 21, a determinism rebuild;
     - the kernel on unpadded words; it must agree;
     - with PROVE: `trained_calib_tests::prove_one_bound`, which goes through the production run prover with CS-3 live, then `verify_one_bound`. Classify the outcome as ACCEPTED / CS-3 / S-4 / CHALLENGE / other prover / verifier.
   - Expected: 66/66 admitted, parity true, misses 0, and every outcome ACCEPTED. That means 0 S-4 events.

**Commands** (`EV` = `results/zk60_gate_tinyllama_20261017/census`, `TREE` = the R7 copy):

```
# build (detached, heavy lock)
setsid nohup bash -c 'python3 /home/victor/IntelligenceRegulation/scripts/zk60_resource_guard.py run --class build --need-gib 3 --cap-gib 5 --label census-build --wait-secs 14400 --max-secs 3600 --log EV/census-build.log --done EV/census-build.guard.done --result-json EV/census-build.guard.json -- /home/victor/.cargo/bin/cargo test --release --lib --no-run --offline --locked -j2 --manifest-path TREE/hashline/Cargo.toml; echo $? > EV/census-build.done' >/dev/null 2>&1 &
# tests 1-7 (light, one at a time): <bin> = the hashline-* test binary the build prints
python3 .../zk60_resource_guard.py run --class light --need-gib 1 --cap-gib 2 --label census-static ... -- /usr/bin/env RAYON_NUM_THREADS=2 <bin> census_trained_ --test-threads 1 --nocapture
# test 8, then test 9 once per sequence (detached, light need 3 / cap 4.5 because of the proof)
... --class light --need-gib 3 --cap-gib 4.5 --label census-real-ho00 ... -- /usr/bin/env RAYON_NUM_THREADS=2 ZK60_CENSUS_EXPORT=.../pg_rot1_export_T32 ZK60_CENSUS_SEQ=ho00 ZK60_CENSUS_LAYERS=0..22 ZK60_CENSUS_KERNEL=1 ZK60_CENSUS_PROVE=1 ZK60_CENSUS_OUT=EV/real-ho00.json <bin> --exact private_block::census_trained_tests::census_trained_real_weights --ignored --nocapture --test-threads 1
```

Estimated cost per sequence: 22 × (witness ~5 s + kernel ~5-10 s + prove/verify ~15 s at 2 threads), about 11-15 min [MODEL; based on R2-2/R2-3: prove 2.5 s at 16 threads, VmHWM 880 MiB, witness 10 s single-thread before R3-1].

**For R7 specifically:**

- Re-read where R7 places CS-3. After Q-7 it sits in the sealing pass, so CS-3 rows become sealing-pass (admission) rows.
- The prover-after-builder list then reduces to S-4, CHALLENGE and PUBLIC. Re-check that list against R7's `prove_core` and `seal_and_record`.

**What this census would NOT cover, even when run:**

- The 23 slot relations for every admissible witness. These rest on honest proofs; test 9 adds 66 more at real weights.
- The soundness no-wrap premise.
- The hash layer and the PCS.
- The GPU path (G-6).
- Inputs beyond the two held-out sequences and the zero input. The admissible class is quantified by the bounds, not sampled.
- It is not a privacy acceptance.
