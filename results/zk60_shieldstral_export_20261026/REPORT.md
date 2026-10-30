# Shieldstral integer export and fidelity

**Status: full-data acceptance remains incomplete.**

The fixed integer model has completed all 26 calibration layers without refusals. Its public native export now matches every numerical candidate array, including the layer-25 correction. The held-out benchmark is still running; verdict agreement and final F1 are not yet available. Native proof, fidelity and privacy acceptance remain separate.

Updated 2026-10-30 UTC from the retained calibration audit, benchmark progress, native export and real app evidence. Runs are MEASURED, n=1 on a shared box. Timing is diagnostic, not a quiesced performance benchmark.

## Full-data coverage

| Replay | Input sequences | Complete layers / 26 | Refused sequences seen | Final scoring |
|---|---:|---:|---:|---|
| Calibration (all padded positions) | 192 | 26 | 0 | Complete |
| A1 benchmark (no truncation) | 4,872 | 6 (layers00–05) | 0 observed | Pending |

Layer05 attempt2 completed the remaining items on 2026-10-29T17:26:17Z:
all 4,872 items are durable, zero refusals, 488.69s, sampled RSS1.68GiB and
VRAM642MiB, cgroup+watchdog, successful GPU drain (n=1, shared box).
Layer06 attempt1 reached its normal ten-minute checkpoint on 2026-10-30T05:39:29.949877+00:00:
2864/4,872 durable items, zero diagnostic refusals, child604.73s, sampledRSS2.16GiB,
VRAM591MiB, cgroup+watchdog and successful GPU drain (n=1, shared box).
The worker is terminal3; next is Layer06 attempt2. This partial layer is not
counted among the six complete layers.

A zero count in an incomplete replay is only a progress observation. Acceptance additionally requires full residual hashes, every input diagnostic, and final-head checks. The calibrated final-norm alternative is reported separately; the current candidate uses the refusal-free norm.

The calibration metadata field `content_tokens` retains the original pre-padding **prompt** length; it is not a pure content length and is not used for benchmark length shares. All original calibration token IDs, including padding, are compared byte for byte by the coverage audit.

## Held-out verdict agreement

The complete 4,872-decision comparison is pending. The earlier eight-item strict-sexual ToxicChat smoke check had zero refusals and 8/8 agreement under both final-norm choices. That subset is not an acceptance result. Its retained evidence is `fidelity_smoke8_fix1/fidelity.json`.

## Artifact and integration status

- Original `dg_base_t256` and `s2_evaluation_t256` remain pinned and unchanged.
- `layer25_probe/integer/complete.json` records the original sequence-97 gate/up refusals; `layer25_fix_candidate/complete.json` records the tested numerical correction.
- `dg_r12b_t256/reference_crosscheck.json` records bit-identical full embedding, head, multiplier and reference margin digests.
- The active layer-25 candidate keeps `sh_u=0`, halves the up-weight scale and decrements `sh_h` by one. Its four groups are `(-3,-11), (-2,-11), (-1,-9), (0,-8)`. Frozen native R13 supports this coarse member in the pinned Shieldstral geometry; the independent D24 review accepted R13 on soundness. Privacy acceptance is separate.
- Benchmark prompts longer than T256 remain in the numerical comparison. Their inclusion does not register a native profile or establish a classifier proof at those lengths.
- Base Sepolia funding, deployment and the first three-receipt batch are complete. Contract `0x8432eba82b1a402f4da7680f6b8f9c9fae185cbe`, batch transaction `0x0f2dc9dd777d33a72a5930f169ea5ba49b485fc25010ebdaa0f536bd5a9ad01a`, block 52075726. All three publication checks pass; receipts remain in the local public store. Evidence: `../zk60_astra_20261026/real_app_demo_1/complete.json`.
- The public 17-token garden post passed prove, fresh verify, input-owner and native whole-post label checks for all three moderate categories through r16b. Each receipt has 28 segments, 848,412,096 bytes and a reported 96-bit floor. After a reboot erased the original temporary database and openings, all 84 public segments were hashed again and all three native public-store verifications passed. Recovery explicitly uses a new development manifest key and does not claim to recover the lost salt or owner openings. No proof was repeated.
- Author authentication and coarse author-only failure status are now applied. The integrated app passes 188 tests and five frontend behavior checks; ten additional ASGI checks pass on the recovered real post and confirmed anchor. These app tests do not replace the classifier privacy review or full benchmark fidelity evaluation.

## Native export handoff

`native_export_equivalence.json` independently checks Sol's full T256 export at
`../zk60_1b_native_20261017/r13/shieldstral-export-v2/`. All 572 layer arrays,
eight public token/head files, the rotation and base constants match the pinned
numerical candidate. The only constant normalization is explicit FP12; the
native loader derives the remaining LOW shifts once. The audit streamed and
hashed the payload bytes: 13.46s, peak RSS0.0865GiB, n=1 shared box.

The T256 profile digest is
`1d50078243f13d58afa814a55c47c2df797e494d7f045941ea82fa142740498a`.
Sol's frozen native R13 imported all26 layers and regenerated the tied tables;
its actual-weight proof evidence covers layer00/T128 on a public synthetic
input. It does not establish a full26-layer model proof or a T256 proof.

`native_low_h24_t128/` contains a separate full26-layer T128 public export.
Weights, multipliers, grouped activation tables, base shifts and tied arrays
are unchanged. Only context metadata and the exact first128 YaRN rows differ.
The profile digest is
`2ba468f98085caf1136f27cf66220f93d8e316acb8dbae7e98f9eb68347f05a0`.
The conversion completed under a guarded light job in19.39s, sampled RSS0.04GiB,
watchdog-only, n=1 shared box. The frozen native CLI proved actual layer00 from
this profile on the public synthetic oracle input; fresh verification passed and
a byte-tampered receipt was rejected. Prove42.42s/RSS7.58GiB, verify17.08s,
watchdog-only, n=1 shared box. Evidence is
`../zk60_astra_20261026/native_t128_check_1/complete.json`. This checks layer00;
full26 T128 import/proof and real classifier acceptance remain separate.

`native_integration_handoff.json` records both exports and the six A1 policy
candidates. Strict versus moderate remains a product ruling. The classifier
lane has integrated native R13, registered the real run/category profiles and
proved one35-token post in all three moderate categories atT128. Its prescribed
r16b CLI removes the leftover card policy; see token-lane `r16/real_runs.json`
and coordinator10:58Z. The per-item writer now matches the retained native
activations as described below. The r16b adapter is implemented and the coordinator authorized one new short
real post through all three moderate categories on Base Sepolia at17:16Z.
The post and its three-category testnet batch are complete; the full benchmark,
final product policy choice and real-classifier privacy acceptance remain pending.
The UI says "privacy statement pending".

`write_item_activations.py` writes all26 layer inputs/outputs as little-endian
int16 `[128,3072]` files under an owner-only directory. It uses the pinned
integer evaluator and category templates, preserves true short-item suffix/pad
positions, and refuses any diagnostic range failure before writing a completion
marker. Requests, content and activations remain private; only layer progress
and timing are logged. Seven request/permission/range tests pass.

The guarded real check in
`../zk60_astra_20261026/item_activations_check_2/complete.json` regenerated the
token lane's one35-token A1 item in all three moderate categories. All156 files
(122,683,392 bytes) match the native writer byte for byte, all75 layer joins
match, and the content matches the pinned saved A1 input. Zero refusals;
66.15s, sampled RSS0.71GiB, watchdog-only, n=1 shared box. This is activation
parity for those three prompts, not a new proof or full benchmark acceptance.

The fully hash-verified calibration evidence remains in `fidelity_audit.json`.
`benchmark_progress.json` separately records journal/input coverage; it is not
a new full residual-byte hash audit. Final benchmark scoring will follow all26
layers and the two final-norm checks.
