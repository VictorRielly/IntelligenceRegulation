# Trained 8B-class model handoff: metadata and layout audit (2026-09-27)

This is a read-only inventory of model metadata and source definitions. No
checkpoint tensor, exported witness tensor, secret input or proof was read or
generated. The local proof device is an RTX 4070 Laptop GPU with 8 GiB VRAM,
not the target RTX 5090. All byte totals below are **counts**, not measured
device traffic, allocation peaks or throughput.

## Available model and what actually survived locally

* `/home/victor/models/Mistral-7B-v0.1/config.json` and the two BF16
  safetensors shards are present. Reading only their small headers counts
  **7,241,732,096 parameters** (all BF16); the index declares
  14,483,464,192 payload bytes. This is the project's historical **8B-class
  Mistral proxy**, not a literal >=8.0B parameter checkpoint or fulfillment
  of Victor's current complete private 8B target. Config:
  `d=4096`, `f=14336`, 32 layers, 32 query heads, 8 key/value heads,
  head dimension 128, 32,000 vocabulary, sliding window 4096.
* `results/m8b_int8_calibration_wsl.json` is the older **failed static**
  calibration (`calibrates_formally=false`). The adopted widened result uses
  `results/m8b_margins_mistral_wsl.json` and the v3 exporter
  `scripts/m8b_export_ffn.py --profile v3`; the source of the exact integer
  walk and sidecar is `scripts/m8b_margins.py`. The real export sidecars are
  `results/m8b_mistral_v3_export/{manifest.json,digests.txt}`. The manifest
  records 32 layers × 512 positions, `v3-widened`, round requantization,
  zero export-window range violations, zero activation-table clamp hits,
  per-layer digests and the checkpoint shard digests. This is **FFN-only**
  calibration/witness coverage, not complete-block calibration or a C4
  held-out qualification verdict.
* **All 256 referenced `layerNN_*.bin` files are absent in this checkout.**
  They were intentionally gitignored. The preflight below refuses tensor
  loading for this reason; it does not recompute multi-GB hashes. The
  checkpoint could be re-exported later, but that is a heavy separate run.

The metadata-only gate is `preflight.py`. Run it with the checkpoint config,
export manifest and sidecar, and safetensors index; it validates profile,
shape, layer order, sidecar identity, safe relative filenames and file sizes.
Its exit status is 2 on the current export. Three small fixture tests pass:
`python3 -m unittest discover -s results/zk60_sol_model_20260927`.
Passing this gate would establish only that the FFN files are present and
shaped consistently. It does not verify their digest bytes, calibration
quality or proof relation.

## Exact FFN byte obligations and geometric lower bounds

The v3 manifest requires, per layer, 176,160,768 int8 weight bytes
(`WgT`, `WuT`, `WdT`), 2,097,152 int8 `X` bytes, 44,040,192 bytes for
three int16 `T×f` planes (`a16`, `u16`, `h16`), and 4,194,304 bytes for
int16 `T×d` `z16`. Total: **226,492,416 bytes per layer** and
**7,247,757,312 bytes for all 32 layers**. These are source-file payloads,
not proof committed/codeword bytes. At least those bytes must be read from
the export files in a straightforward importer; actual host-to-device
traffic depends on residency and caching and has not been measured.

At `T=512`, a full Mistral block's unpadded logical planes include
`T×d=2,097,152` elements, `T×f=7,340,032` elements, K or V
`T×(8×128)=524,288` elements, and attention scores
`32×T×T=8,388,608` elements. The candidate `Shape` uses power-of-two
domains: `F` pads to `512×16384=8,388,608`, while `D/Q` are 2,097,152
and `S` is 8,388,608. These element counts alone do not determine the
number of committed A/H rows or the GPU peak; no Mistral profile exists
from which to quote those counts. Prior project planning counts roughly
72 GB peak for the older 8B range-only pass (`START_HERE.md`), which is
**not** a measurement of the present private candidate.

## Proof interface, lifetimes and missing relation

Main `hashline/src/private_block/layout.rs` and `private-block-kernel/src/lib.rs`
still pin the real proof to `T32/d16/f16`, two query heads and one KV head,
with one frozen calibration. `hashline/examples/zk60_private_block.rs`
proves and fresh-process verifies only that synthetic toy fixture. The
isolated `/tmp/zk60-groups-20260926` candidate has a **generic counted
Shape**, including `Shape::m125` at `T512/d768/f2048`, and a runnable
`RunShape::m125` complete-block path tested on synthetic weights. It has
no `T512/d4096/f14336` registered profile and no trained-checkpoint loader.
The earlier layout-only comment at the top of its `shape.rs` is stale; the
later `run.rs` and tests show the 125M path. A 125M synthetic run is a
functional development rung, not trained 8B proof evidence.

`run.rs::prove_run` creates one NTT table, one masking commitment and one
LogUp challenge triple per run. For stage `k`, it prepares the next hidden
boundary before the current proof, so the previous/current boundary and
the block witness can overlap. It then completes the previous boundary's
opening, encodes one segment, and passes owned bytes to a sink before stage
`k+1`. `DirSink` retains only each segment's length and digest, whereas
`MemorySink` retains bytes. The source notes 423 MiB for eleven unflushed
125M segments. Peak obligations at 8B therefore include a current block's
A/H/mask/codeword working sets, current witness, adjacent boundary
commitments/opening state and one serialized segment. The lifetime design
reduces whole-stack residency but does not imply a 5090-fit peak. It also
does not yet connect GPU FFN proving to the private whole block; form (S)
re-derives FFN on the host. An 8B profile needs measured peak host/VRAM,
PCIe bytes and transfer intervals, and a device path under the accepted
whole-block relation.

The next *runnable trained-block* step is a new, independently versioned
profile and importer for **one Mistral block** after the absent v3 files are
restored, with trusted checkpoint/calibration/table identity. The FFN
`X` plane is the layer's MLP input, **not** the transformer block input;
the existing export does not supply Q/K/V, RoPE, score/softmax, attention
output, either RMS norm, int24 residual, or the exact adjacent-block seam.
Those must be calibrated and exported under a complete integer reference.
The private relation also needs Mistral grouped-query heads, distinct `F`
domain, int24 residual limbs and range-pinned norm witnesses, variable
per-layer calibration as a public statement field, endpoint binding across
the full `T×d` plane, and accepted privacy/soundness review. Reusing toy
proof bytes or silently widening its frozen profile would be invalid.

## What a throughput receipt must eventually cover

For `N` positions, every one of 32 blocks must be bound in one complete
stack relation (or an accepted composition) and independently verified from
bytes. The 50 proved-token/s clock is `N / total wall`, including startup,
witness, commitments, all recurring transfers, serialization and pipeline
drain; verification is reported separately. Count each position once across
the stack. Record separate startup and steady intervals, proof latency,
proof bytes, peak host RAM/VRAM, transfer bytes, actual GPU and repeated
same-`N` runs. At 512 positions the arithmetic budget is 10.24 s; longer
workloads are allowed. No such trained full-stack receipt or clock exists.
The public-IO FFN-only Mistral proof and the synthetic 125M block do not
meet this scope. D13 places embedding, final norm, head and token choice in
the subsequent milestone; P1 still requires hidden input, output and all
intermediate activations, while P3 later hides weights too.

An allocation-free source probe now counts A/H/M/codeword and boundary
payloads at T512 and T1024, with hardware capacity qualifications in
[`layout-readiness.md`](layout-readiness.md).
The [PCS recomputation roadmap](pcs-recompute-roadmap.md) traces the encoded
matrix's post-root read site and records test-only streaming root plus
recomputed opening parity against the materialized CPU oracle for both
legacy and tagged commitments. The prototype does not expose a production
compact store or establish an 8B memory peak.
