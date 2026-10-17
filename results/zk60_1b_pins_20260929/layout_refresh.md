# TinyLlama-1.1B layout ladder, refreshed against the pinned checkpoint

Lane A, 2026-09-30T00:15Z UTC (2026-09-29 PDT). Command:
`python3 results/zk60_1b_pins_20260929/layout_refresh.py`, exit 0
(`layout_refresh.log`, `layout_refresh.json`, `layout_refresh.csv`).

## What was refreshed

The Sol model lane's ladder (`results/zk60_1b_model_20260927/`) was made on
2026-09-26 from `config.json` alone, before the checkpoint was fetched. This
pass checks it against the **tensor header** of the pinned file (rev
fe8a4ea1, sha256 6e6001da…). All 11 checks pass:

- Header shapes give d = 2,048, f = 5,632, K/V width 256 = 4 KV heads x 64;
  with the config's 32 query heads, dh = 64; 22 blocks. Every one of the 14
  probe lines used exactly this geometry.
- The counter's constants equal the header: full BF16 payload
  2,200,096,768 B, one block 88,088,576 B (44,044,288 parameters).
- Re-running the counter on the retained probe log reproduces the stored
  `layout_ladder.json` exactly, including the one refused shape.

So the earlier numbers stand for the real checkpoint. Nothing changed; the
table below regroups them by route and adds the whole-stack receipt count.

## Per-block payload floors (GiB unless marked)

Host RAM on this box 15.39 GiB (MemTotal); VRAM 8.00 GiB (8,188 MiB).

| T | log cols | A / H rows | receipt per block / x22 blocks (MiB) | CPU route host | GPU route host, H build | GPU route host, retained A+H | GPU route device | of which witness+lookups |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| T32 | 12 | 1,801 / 1,934 | 11.5 / 253 | 0.59 | 0.29 | 0.12 | 0.17 | 0.10 |
| T32 | 13 | 1,031 / 1,026 | 11.4 / 251 | 0.65 | 0.31 | 0.14 | 0.22 | 0.10 |
| T64 | 12 | 3,517 / 4,006 | 19.0 / 417 | 1.18 | 0.52 | 0.25 | 0.29 | 0.21 |
| T64 | 13 | 1,889 / 2,062 | 15.1 / 333 | 1.24 | 0.53 | 0.25 | 0.34 | 0.21 |
| T64 | 14 | 1,075 / 1,090 | 18.0 / 397 | 1.37 | 0.55 | 0.28 | 0.46 | 0.21 |
| T128 | 12 | 7,477 / 8,918 | 36.4 / 801 | 2.56 | 1.05 | 0.53 | 0.58 | 0.46 |
| T128 | 13 | 3,869 / 4,518 | 23.9 / 525 | 2.61 | 1.06 | 0.53 | 0.62 | 0.46 |
| T128 | 14 | 2,065 / 2,318 | 22.4 / 493 | 2.74 | 1.08 | 0.56 | 0.73 | 0.46 |
| T256 | 12 | 18,539 / 22,840 | 85.5 / 1,880 | 6.44 | 2.53 | 1.34 | 1.39 | 1.18 |
| T256 | 13 | 9,401 / 11,480 | 48.4 / 1,065 | 6.47 | 2.54 | 1.32 | 1.41 | 1.18 |
| T256 | 14 | 4,833 / 5,800 | 34.7 / 762 | 6.58 | 2.57 | 1.33 | 1.51 | 1.19 |
| T512 | 12 | 50,129 / 63,994 | 228.0 / 5,015 | **17.72** | 6.84 | 3.70 | 3.75 | 3.28 |
| T512 | 13 | 25,195 / 32,056 | 119.7 / 2,633 | **17.68** | 6.85 | 3.61 | 3.70 | 3.28 |
| T512 | 14 | 12,729 / 16,088 | 70.3 / 1,547 | **17.75** | 6.88 | 3.58 | 3.76 | 3.28 |

T32 at 14 log columns is refused by the probe (the grouped-KV attention
domain cannot be lifted to that row width); use 12 or 13 there.

Column meanings (all are computed payload bytes, *length x element size*):

- **CPU route host**: everything on the host, full rate-4 codewords
  materialized. The larger of two phases: (a) building H while committed A,
  M, two boundaries, the witness, lookup columns and one BF16 layer are
  live; (b) the sumcheck slots with A and H fully committed, M and two
  boundaries. (b) is larger in every row. **Bold = above this box's RAM**:
  T512 cannot run on the CPU-only materialized route here.
- **GPU route host, H build**: the chunked-GPU route's host floor while H
  is built: A and H raw rows, witness, lookups, exponent deltas/activation
  indices and one BF16 layer (layer streaming).
- **GPU route host, retained A+H**: what the host keeps after the witness is
  dropped: raw rows, pads, salts and Merkle nodes (no codewords).
- **GPU route device**: A and H raw rows, pads and coset powers on the
  device plus one 128-row commit scratch set (full-width pads). The compact
  pad option saves 0.01-0.05 GiB.
- **witness+lookups**: the A-plane witness, looked-up byte columns and
  deltas/indices. This is the witness overlap inside the H-build column.

Weights: one block is 0.082 GiB BF16; the 22-block proved stack is
1.80 GiB (1,937,948,672 B); the full checkpoint is 2.05 GiB. Only the
H-build phases include one block's weights. Keeping the whole stack
resident adds up to 1.72 GiB more on whichever tier holds it. The Sol GPU
audit (`results/zk60_sol_model_20260927/gpu-chunked-memory-audit.md`) reads
the current route as building the witness on the host, so the device floors
carry no weights; a device-side witness would add them.

## What these numbers do not say

- They are floors, not peaks. They leave out CUDA context and pool slack,
  NTT/hash temporaries, matmul/attention temporaries, opening buffers,
  allocator overhead, M's masks/tree and the serialized segment.
- The probe calls the private-block layout constructors under an
  **unregistered** shape. No TinyLlama profile, integer calibration or
  witness exists yet. A shape that fits is not a working proof.
- The host and device columns of the GPU route are separate memories with
  duplicated raw rows; do not add them together as one capacity.
- The receipt byte counts come from the layout formula (`Shape::receipt_bytes`)
  for one block. The x22 column assumes one receipt per block with no
  whole-stack aggregation.
- No speed or tokens/s forecast follows. Each pass proves T positions once,
  however many layers it covers.

## Unresolved

The Rust probe harness that produced `layout_probe.log`
(`private_block::shape::sol_tinyllama_layout_probe`) lived only in
`/tmp/zk60-sol-1b-model-20260927/`, which is gone. Only its output log was
kept (the Mistral probe's patch is saved, this one's is not). The counts
cannot be regenerated from source until the harness is re-created against
the current private-block tree. That is the second checkmark's work (it also
needs measured peaks), not part of this pin.
