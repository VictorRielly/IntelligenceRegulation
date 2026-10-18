# B6 report: Llama-3-8B calibration, layer-1 weak spot, T=512 outlook

Calibration lane, 2026-10-17. Calibration data only: this is not a proof and
not a privacy claim. Labels: [MEASURED] = a run happened (shared box, n=1);
[COUNTED] = exact arithmetic; [MODEL] = fitted or assumed. Ledger with every
step and UTC time: `PROGRESS.md` (B6 resume section).

## In plain words

* **Both exports are done and checked.** The 8B profile is exported at
  T=128 and T=64 (one calibration, identical weight words), and an
  independent reader recomputed all 32 layers of two held-out sequences from
  the exported bytes alone, bit for bit, for both.
* **Layer 1's weak spot is not mainly the attention sink.** 80% of layer 1's
  attention does go to the first token, but those scores are small. What
  sets layer 1's score scale is a set of strongly *negative* scores (down to
  -230 raw), which the softmax ignores anyway, while the symmetric int8
  score class still has to hold them. That forces a coarse score scale
  (e_s 2). Because the score scale and the run-wide score shift (SH_S 6) are
  tied to the Q and K scales, layer 1's int8 Q and K numbers end up one bit
  coarser than they need to be. Most of layer 1's error comes from that, not
  from the score grid itself.
* **Any fix of that coupling gives the same gain.** Three different routes
  (int16 scores, no margin on the score exponent, a per-layer score shift)
  land on the same layer-1 numbers; per-head score scales get part of the
  way. They give: layer-1 isolated cosine 0.72 -> 0.82, and whole-model next-token
  agreement with the float model 62% -> 67-68% on held-out FineWeb, with
  the KL divergence to float down about a quarter (0.71 -> 0.52).
* **Recommendation: let layer 1 use its own score shift (SH_S 7 instead of
  the run-wide 6).** This is the cheapest route that holds at every context
  length. Measured at T=128 against the T=128 export: top-1 agreement
  65.1% -> 67.3% (FineWeb) and 63.3% -> 66.3% (licence), KL down 18% / 9%,
  no refusal. It needs no new table, no layout change and no new committed
  planes. The native prover would have to accept SH_S as a per-layer
  constant; today it is one value for the whole run. At T=32 only, a route
  with zero native change exists (e_s 1 chosen without the score margin), but
  it is infeasible at T=128, where layer-1 scores reach 279 > 254. int16
  scores and per-head scales buy nothing more and cost far more natively.
* **Layer 1 is improved, not closed**: 0.82 against 0.95+ for the other
  layers. The next candidate is a one-sided (saturating) score class, so that
  the irrelevant negative scores stop setting the scale (untested; a native
  gadget change). The int16 attention-output screen was invalid (a wiring
  artifact), so the o class remains untested.
* **T=512**: on this laptop an 8B T=512 calibration fits as one ~2 h light
  job only with smaller processing chunks (~5.5 GiB). On the Mac M3 Ultra
  (256 GB), memory stops mattering and several runs with 5x larger held-out
  sets can run side by side. The Mac's per-run speed is unmeasured.

## 1. Exports (B6-1)

One calibration (B5's T=128 statistics and profile decisions: 18 licence +
12 FineWeb sequences of 128 tokens), exported at two context lengths. The
weight and table words are byte-identical between the two (352 files hard
linked); only the RoPE tables (t_max), manifests and sequences differ.

| export | profile.json sha256 | held-out fidelity [MEASURED] | independent verifier [MEASURED] |
|---|---|---|---|
| `export/llama3_8b_pg_rot1_b6_T128` | `eedbcff1201f631c2d5aaa46bbd2cee6a1b1290ec08078415a9ed31567ee23df` | FineWeb 6 seqs: top-1 0.651, ppl 9.72 -> 17.97, KL 0.607; licence 9 seqs: 0.633, 3.71 -> 9.59, KL 0.968; 0 refused | 32 layers bit-exact on seq_ho00 and seq_ho09, 0 errors (396 s, 2.00 GiB) |
| `export/llama3_8b_pg_rot1_b6_T64` | `ea84a6b74bbbbc8c3145e3fb746b87c536004b9165ab2337baaa9dc1289d25be` | FineWeb 6 seqs: top-1 0.630, ppl 12.59 -> 23.21, KL 0.581; licence 9 seqs: 0.628, 5.84 -> 13.46, KL 0.911; 0 refused | 32 layers bit-exact on seq_ho00 and seq_ho09, 0 errors (197 s, 1.69 GiB) |

(The earlier B5 export `export/llama3_8b_pg_rot1_T32`, profile 2507fbde...,
is a different calibration at T=32.) The T=64 export killed by the
14:59:58 UTC shutdown was removed before the redo: its files were hard links
into T128 and the writer writes in place, so the driver now refuses to export
into a non-empty directory. The verifier reads only the exported bytes (no
checkpoint, no solver state) and recomputes every layer of both sequences
with the native integer relations. The T64 verifier also hashes T128's
weight files (same inodes), so it re-confirms them after the linking run.

## 2. Layer 1 (B6-2)

### 2.1 What the weak spot is, measured

Layer 1 of Llama-3-8B writes the "massive activation" on the first token
(BOS). In B5 its integer block was the outlier: isolated cosine ~0.72-0.73
against 0.95-0.996 for every other layer. The native score class is int8 at
scale 2^e_s; e_s is the smallest power of two for which the largest |score|
times a 1.25 margin fits 127. In the solver the Q and K int8 scales are
coupled to it: s_q * s_k * 2^SH_S = 2^e_s, with SH_S one run-level value (6).

Float diagnostic of layer 1 (`b6_sink.py`, `runs/b6_sink_layer1.json`; 54
calibration and 36 held-out FineWeb sequences, T=32) [MEASURED]:

| quantity | calibration | held-out FineWeb |
|---|---|---|
| most negative raw score (causal region) | -223.4 (-223.4) | -229.9 (-227.6) |
| largest positive raw score | 61.7 | 57.4 |
| largest positive score at the BOS key | 43.9 | 43.2 |
| max abs score without the BOS key column / row | 223.4 (unchanged) | 229.9 (unchanged) |
| softmax mass on BOS (mean over heads, queries t >= 1) | 0.80 | 0.81 |
| K per-(head, RoPE pair) range: all positions / without position 0 | 1.00 (all pairs) | 1.00 |

So the sink takes most of the probability but has small scores, and it does
not set any K range. The range is set by negative scores (down to -230 raw =
-20 logits at head_dim 128). They contribute exp ~ 0 to the softmax unless
the row's own maximum is that low (row maxima were not recorded). A
positive-side range alone would allow e_s 0 instead of 2 [COUNTED: 61.7 x
1.25 / 127 < 1].

Layer-1 site errors (relative, isolated) show the mechanism [MEASURED]:
`s16` (score step 2^-4) and `s0m` (step 2) have the same score error,
0.297, and the same Q/K errors, 0.095 / 0.072. The native setting has 0.648
with Q/K errors 0.193 / 0.139: the score grid is not the bottleneck; the Q/K
words are, through the coupling (Q/K slack 2.84 bits native vs 1.84).

### 2.2 Options measured

All on the same 36 held-out FineWeb sequences, T=32, B5's T=32 calibration
and profile; every layer other than 1 has byte-identical words to the B5
export (checked for every run). Layer-1 isolated metrics use the first 12
sequences; whole-model head metrics are over accepted sequences (float ppl
19.59 on the 35 the baseline accepts).

| option | layer-1 change | native today? |
|---|---|---|
| `none` (baseline) | e_s 2, SH_S 6 | yes |
| `s0m` | e_s chosen with no margin on the SCORE exponent only -> e_s 1 | yes (a per-layer table key) |
| `sh7` | SH_S 7 at layer 1 (e_s 2, all margins kept) | no: SH_S is run-level |
| `s16` | int16 score, SH_S 1, e_s -4, 65,536-row exp table | no |
| `perhead` | one e_s per query head (0..2), 32 tables | no |
| `m2zero` | no margin on ALL power-of-two exponents (score, gate, act) | yes, but refuses (below) |
| `o16`, `sh7o16` | o in int16 (B4-3 knob) | screen invalid (below) |

Layer 1 [MEASURED, shared box n=1]:

| option | e_s | iso cos | iso delta-cos | chain cos after L1 | site err q / k / score / prob / o | refused at L1 |
|---|---|---|---|---|---|---|
| none | 2 | 0.720 | 0.608 | 0.712 | 0.193 / 0.139 / 0.648 / 0.803 / 2.42 | 0 |
| s0m | 1 | 0.824 | 0.731 | 0.801 | 0.095 / 0.072 / 0.297 / 0.487 / 1.45 | 0 |
| sh7 (2-layer screen) | 2 | 0.824 | 0.731 | 0.801 | 0.095 / 0.072 / 0.298 / 0.488 / 1.45 | 0 |
| s16 | -4 | 0.824 | 0.732 | 0.801 | 0.095 / 0.072 / 0.297 / 0.487 / 1.44 | 0 |
| perhead | 0..2 | 0.790 | 0.686 | 0.772 | 0.143 / 0.074 / 0.426 / 0.558 / 1.72 | 0 |
| m2zero | 1 (+ SiLU member -3,-11) | 0.834 | 0.745 | 0.812 | as s0m | **36 of 36** (FFN gate 133 > 127) |

Whole model, held-out FineWeb [MEASURED]:

| option | refused | top-1 vs float | ppl int (float 19.59) | KL(float \|\| int) | chain cos at L31 |
|---|---|---|---|---|---|
| none (= B5 T=32 FineWeb: same words, same sequences) | 1 | 0.623 | 37.88 | 0.713 | n/a on FineWeb alone |
| s0m | 1 | 0.669 | 30.17 | 0.521 | 0.849 |
| s16 | 1 | 0.679 | 29.97 | 0.517 | 0.852 |
| perhead | 2 | 0.656 | 30.00 (float 19.26) | 0.547 | 0.840 |
| m2zero (DIAGNOSTIC: all refused, values clamped) | 36 | 0.685 | 29.87 (float 18.85) | 0.549 | 0.854 |
| sh7 | not run at T=32 whole-model; layer 1 equals s0m to 3 decimals, so expected ~ s0m [MODEL] | | | | |

**sh7 at the export length, T=128** (`runs/llama3_8b_pg_rot1_b6l1sh7_T128`;
B5's T=128 statistics and profile; the same held-out sequences as the T=128
export; every layer other than 1 byte-identical to
`export/llama3_8b_pg_rot1_b6_T128`) [MEASURED, 2403 s, peak RSS 3.32 GiB,
shared box n=1]:

| T=128 | layer-1 iso cos / delta-cos / chain | FineWeb 6 seqs: top-1, ppl (float 9.72), KL | licence 9 seqs: top-1, ppl (float 3.71), KL | refused |
|---|---|---|---|---|
| native (the T=128 export) | 0.768 / 0.670 / 0.733 | 0.651, 17.97, 0.607 | 0.633, 9.59, 0.968 | 0 |
| sh7 (layer 1 SH_S 7) | 0.841 / 0.753 / 0.800 | 0.673, 15.48, 0.496 | 0.663, 8.94, 0.879 | 0 |

So the per-layer SH_S fix carries over to T=128, where `s0m` is
infeasible: +2-3 points of top-1 agreement and 9-18% less KL on both
domains, with no refusal.

Notes:
* The baseline's one refused sequence (FineWeb #10, layer 24 V) refuses in
  every option. perhead adds one refusal at layer 2's FFN gate (sequence
  #21), downstream of its changed layer-1 output.
* `m2zero` shows that the 25% margin on layer 1's gate exponent is
  load-bearing. The gate maximum is reached at the input-independent BOS
  position (the integer chain gives 133 against the float-quantized 127), so
  every sequence refuses.
* `o16` / `sh7o16`: the layer-1 AO output is all zero (AO rel err exactly
  1.000), because the run-level SH_AO 3 was not re-solved for SH_O 1. These
  screens say nothing about the o class. Their internal site errors (o 0.69
  vs 1.45) hint that it matters.
* Timings, shared box: whole-model T=32 runs 1948-2398 s, 2-layer screens
  ~240-300 s, peak RSS 3.0-3.1 GiB.

### 2.3 What each option would cost the native prover

Facts read from the native 8B prover (`ops/zkp-mvp/trained-1b/hashline/src/private_block/`,
read-only; the ledger's 18:38 entry has the details):

* one public exp table per layer, exactly 256 rows. `exp` shape [256] is the
  only shape the importer accepts, and it must equal `exp_member(e_s, 128,
  f_e)` (`trained_block.rs` ~905-913). `exp_e_s` is a per-layer table key in
  -8..8 (`shape.rs` ~140). `sh_s` and `f_e` are RUN-LEVEL: one value for
  all 32 layers (`RUN_LEVEL_KEYS`, `trained_block.rs` ~432). `sh_s` must lie
  in the one-limb window 1..8 (`shape.rs` ~117/196);
* the score s8 is range-checked by two lookups into the shared 256-entry
  byte table; the SH_S remainder is one byte limb checked with a per-shift
  scale. Per score element the 8B T32 block commits 11 planes plus 8 Fp2
  helper planes (27 rows' worth; 31 at T >= 256 per the speed plan);
* the exp lookup is LogUp over the fused pair (delta, E). Its table is
  public (built by the verifier) and its multiplicity column is committed
  over the table domain. Ruling S-1 pins the table domain to exactly the row
  width: 2^13 = 8,192 at 8B, with the 256-row table lifted onto it. A 2^16
  row width is refused at 8B (R4-1 counted layouts).

| option | layout change | exp table | new committed planes (score domain) | statement / importer | review |
|---|---|---|---|---|---|
| `s0m` | none | one 256-row member at e_s 1 (a per-layer key the importer already accepts) | 0 | none | usual export checks. Infeasible at T=128 (raw 279 > 254) |
| `sh7` (per-layer SH_S) | none: SH_S 7 is inside the 1..8 one-limb window; the remainder check and the requant relation take it as a per-block constant | unchanged (e_s 2) | 0 | `sh_s` moves from the run-level keys to the per-block keys (like `exp_e_s` / `silu`); statement records it per layer | small: same relation, a per-block constant. Whether lifting a run-level key needs a ruling is the native lane's call |
| `perhead` | the exp lookup tuple gains a public head term (delta + 256 x head; the head is the high bits of the score index) | 32 members x 256 = 8,192 rows: exactly the 2^13 table domain the 8B shape already pads onto, so no extra committed table rows [inference from shape.rs, to be confirmed by the native lane] | 0 (SH_S stays shared; per-head scales live in the public Q weights) | layer-1 `exp_e_s` becomes a 32-vector; importer accepts exp [32, 256] and checks 32 members; per-head table and multiplicities | moderate: a new public selector in the lookup |
| `s16` | int16 score class: byte-limb range check instead of two U8 lookups, new mask value, d in [0, 65534]; SH_S 1 against the run-level 6 | one 65,536-row member: table domain 2^16 > the 2^13 row width, which breaks ruling S-1 at 8B; needs a multi-row table (what S-1 forbids) or a two-stage exp | ~ +2 planes + 1 Fp2 helper per score element (~ +4 of 27 rows, ~ +15% of that layer's score block) [estimate from the layout] | new exp-table family member (input width 16: generator, digest, registry row); importer and shapes change | large: S-1 and the exp-table premise need a new ruling |

Scale of the score block, for context [COUNTED, speed plan 2026-10-17, per
token per block ~763,904 + 992 x T committed elements]: ~4% of an 8B
block's committed elements at T=32, 40% at T=512, 57% at T=1024. A change
confined to layer 1 is 1/32 of that.

## 3. Recommendation

1. **Adopt a per-layer SH_S for layer 1 (SH_S 7; e_s 2 and all margins
   unchanged).** It reaches the best measured layer-1 fidelity (the same as
   int16 scores) and is feasible at T=32 and T=128 (layer 1's Q/K need
   2^-5.73 / 2^-5.64 <= 2^-5). Measured at T=128 (section 2.2): top-1
   +2.2 / +3.0 points, KL -18% / -9% (FineWeb / licence), 0 refused. Layer 1's own free-shift choice was 7 in both
   pre-passes; only the run-level median imposed 6. Native work: make `sh_s`
   a per-block key. No new table, no layout change, no new planes. Next
   concrete step: the native lane says whether `sh_s` can move to the
   per-block keys. If yes, this lane re-exports T=32/T=64/T=128 with layer 1
   at SH_S 7 (one T=128 calibration, two linked exports, ~1 h with
   verifiers). A fully native alternative is a run-level SH_S 7 for all
   layers. It changes every layer (layers preferring 5-6 would need a
   coarser e_s) and needs a fresh calibration (~1.5 h per T); untested.
2. **T=32-only stopgap with zero native change: `s0m`** (layer-1 e_s 1, no
   margin on the score exponent). Measured whole-model gain as above, but
   only 10% headroom on held-out scores (230 vs 254), and infeasible at T=128.
3. **Not recommended:** `s16` (no fidelity beyond sh7/s0m; breaks S-1 and
   needs a new exp-table family); `perhead` (worse than sh7/s0m, one extra
   refusal, moderate native change); `m2zero` (refuses everything: the gate
   margin is load-bearing).
4. **To close layer 1 further (untested candidates):** (a) a one-sided
   (saturating) score class, s8 = max(floor(Sacc / 2^SH_S), -127). It is
   exact for the softmax whenever a row's max sits >= 78 raw units above the
   clamp (exp then rounds to 0 at f_e 9), which can itself be asserted. It
   would let layer 1 run at e_s 0 with SH_S 5 (Q/K need 2^-5.73 <= 2^-5):
   a score step 4x finer than native or sh7 and 2x finer than s0m (positive
   maxima measured at T=32 only). Native cost: a saturation gadget
   (selector + range fact) on the score domain. Check first whether other layers share the
   negative-score asymmetry (a one-command extension of `b6_sink.py`).
   (b) The o class, re-screened with SH_AO re-solved for SH_O 1.

## 4. An 8B T=512 calibration: laptop vs Mac M3 Ultra (arithmetic only)

No T=512 run was made. `b6_t512_estimate.py` (output
`runs/b6_t512_estimate.json`) turns the measured T=32 / T=128 runs into a
[MODEL]. Back-test on the three measured runs: memory model 0.15-0.5 GiB
ABOVE the measured peaks (conservative), wall time within ~10%.

What the measurements say about where time and memory go [MEASURED]:

* wall time is dominated by per-layer weight work that does not grow with T.
  Pass 1 (float statistics) took 865 s at T=32 and 907 s at T=128; the
  profile pre-pass 2,483 s and 2,244 s; pass 2 51-54 s per layer at T=32, at
  T=128 and in the T=128 export alike;
* peak RSS is one layer's weight working set: 3.45 GiB (T=32), 3.63 GiB
  (T=128), 3.32 GiB (T=128 export), 2.00 GiB (T=128 verifier).

What grows at T=512 [COUNTED]: the score volume is 16x T=128's per sequence.
One int64 copy of it for a chunk of 8 sequences is 8 x 32 x 512^2 x 8 B =
512 MiB, and the integer softmax keeps ~8-10 such copies alive. The
un-chunked site-error trace on 3 sequences is ~2.3 GiB. A forward pass costs
436 MFLOP per token per layer (14 GFLOP per token for 32 layers).

| case [MODEL] | peak RSS | full calibration (pass 1 + pre-pass + pass 2 + head) | export only, reusing the T=128 profile |
|---|---|---|---|
| laptop, chunk 2, site 1, 30 calib + 15 held-out seqs | 5.2-5.5 GiB (declare need 6 / cap 7) | 1.8-2.1 h | 0.8-1.0 h |
| laptop, B5 defaults (chunk 8, site 3) | 8.2-9.2 GiB: does not fit beside the GPU lanes in the 11.9 GiB budget | 1.8-2.2 h | 0.8-1.1 h |
| Mac M3 Ultra 256 GB, chunk 8, site 3, 72 held-out seqs | 10.9-11.9 GiB (4% of 256 GB) | 3.2-4.4 h at laptop per-thread speed | 2.2-3.3 h |

Reading:

* On the laptop a T=512 calibration is feasible as ONE guarded light job of
  ~2 h if the driver's chunk drops to 2 and site-seqs to 1. Memory, not time,
  is the constraint. Disk: ~1.9 GiB chain spill + 6.6 GB export. This
  evening's experience (37 min in budget admission for a 4 GiB job) says a
  6 GiB declaration needs a quiet slot or an agreed window.
* On the Mac, memory stops mattering. A 4-5x larger held-out set (72
  sequences, better fidelity statistics) and several runs in parallel (one
  per layer-1 option or per T) fit easily. Per-run speed on the M3 Ultra is
  UNMEASURED: the Mac is not yet reachable, and numpy there would use
  Accelerate. The table assumes the laptop's per-thread speed. One 2-layer
  T=32 smoke (~5 min) on the Mac would settle it. Needed there: the 16 GB
  checkpoint with its sha256 pins, tokenizer.json, the FineWeb parquet,
  numpy/tokenizers/pyarrow/threadpoolctl, and a memory guard (the lane's
  guard is Linux cgroup based).
* Export-only reuse of the T=128 profile skips pass 1 and the pre-pass, but
  its ranges were never observed at positions 128-511, and softmax
  denominators and score extremes grow with T: layer 1's max |score| went
  223 -> 279 from T=32 to T=128. Refusals would have to be checked on the
  held-out set.
* The native prover has no 8B T=512 shape registered yet; an export at
  T=512 is calibration data for that future shape.

## Files

Driver `b5_8b.py` (B6 options: `--l1-mode {s16, perhead, m2zero, s0m, sh7,
o16, sh7o16, fe13}`, `--profile-from`, `--link-from`, `--check-against`,
fresh-export guard); `b6_sink.py` (float layer-1 range diagnostic);
`b6_summarize.py` -> `runs/b6_l1_summary.json`; `b6_t512_estimate.py` ->
`runs/b6_t512_estimate.json`; run directories `runs/llama3_8b_pg_rot1_b6l1*`;
logs `logs/b5-b6_l1_*`, `logs/b6r-verify-*`, `logs/b6-sink*`; queue scripts
`logs/b6r_serial.sh`, `logs/b5_run.sh`, hold check `logs/b6_hold2.py`.
