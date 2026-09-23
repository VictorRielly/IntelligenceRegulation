# Run captures at EIGHT key-value groups (`lkv = 3`), rung-K8 — lane stage 37, 2026-09-22

Two bundles, one shape, written by
`private_block::k8_tests::write_the_k8_gate_bundles` at source commit
**`99a8de8`** (the lane HEAD at capture time; `source_commit` in both
`manifest.json` and both `run.json` files says so). Log:
`results/zk60_block125m_lane/s37-k8-bundles.log` (exit 0).

| bundle | witness | `manifest["total_bytes"]` | on disk | `manifest.json` SHA-256 |
|---|---|---:|---:|---|
| `run-s-dense-k8` | FULLY DENSE run recipe (`dense_tests::dense_run_case`, band 48), generic hidden input, all eight key-value groups pairwise different in every block | 46,928,078 B | 46,933,075 B | `29815e93f9a983f6a507d6d9697eda098e3b4a2de61c297684af1153a8ac730b` |
| `run-t-zero-k8` | all-zero hidden input on the tame fixture — DEGENERATE (every group zero), the pair's control | 46,901,939 B | 46,906,936 B | `d322a49c5e70e962042a37f17409428ec84176a4ca7d49d043db321509d7fdc6` |

Both are three-block runs in the classic `hashline-native-capture/4-run`
encoding, under the D19 tag (`blake3-keyed/1`) with the public tables'
values, written exactly as stage 22 wrote `run-i-dense-k4` / `run-j-zero-k4`.

## The shape

rung-K8: 24 tokens, width 128, hidden 192, **16 query heads of 8 over 8
key-value heads** (two query heads per group, no padded head slot), padded
layout `t_pad 32 / d_pad 128 / h_pad 16 / f_pad 256` (rung-K4's), row width
2^10, rate 4, `F_E` 12, the generalised 9-row endpoint. Block profile
`hashline-zk-mr1/private-block-rung-k8-t24-dev/1`, run profile
`hashline-zk-mr1/private-run-rung-k8-t24-dev/1`.

**TEST-ONLY SHAPE.** It is built in `hashline/src/private_block/k8_tests.rs`
through the existing `Shape::new` / `RunShape::new` and is NOT registered in
`shape.rs` or `run.rs`: this build writes and reads no run STATEMENT file for
it, and the stage-24 profile registry does not list it. A reader takes the
shape from `run.json`'s `shape` block; the four hash-tag keys derive from the
block profile string alone (`run.json`'s `hash_tag.keys_hex` records them).

## What is new for a reader

* slots 08 (`10 score matmul`) and 09 (`11 PV matmul`) are `(6, 2, 3)` and
  `(8, 2, 3)` (main, extension, degree): `lkv + log2(head_dim) = 3 + 3` and
  `lkv + log2(t_pad) = 3 + 5`;
* each opens its `tables` with `{"kind":"eq","start":0,"point":[<THREE Fp2>]}`
  — the group factor `eq(r_g, .)` over three group bits, eight terms. The
  point is the leading three entries of that slot's head challenge: re-derive
  it from `definition_challenges` and COMPARE, never take a value from it
  (ruling T-7);
* the plane index is NOT rung-K4's (`Dom::Kv` doubles): 83 `A` planes over
  487 data rows, 52 `H` planes over 626, canonical SHA-256 prefix
  `914338bb`, identical across the pair. Do not compare it with rung-K4's
  `89cd8a46`.

## Sanity, on the files as written

`python3 results/zk60_block125m_lane/s37-bundle-sanity.py 99a8de8 3 <the two
bundles>` → `s37-k8-bundle-sanity.log`, **0 mismatches**: every manifest
entry's length and SHA-256; both `source_commit` labels equal `99a8de8`; 93
public tables per bundle, all with values, every SHA-256 recomputed over the
16-byte little-endian `Fp2` encodings; the group eq at start 0 with a
three-element point equal to `definition_challenges[:3]` at all 6 of 6
occurrences per bundle. The same script on the two rung-K4 bundles (lkv 2,
commit `3247a89`) reproduces stage 22's sanity figures exactly
(`s37-sanity-control-k4.log`).

Development grade (ruling P-7). **Not gate evidence and not a privacy
result**: no gate has read these bundles.
