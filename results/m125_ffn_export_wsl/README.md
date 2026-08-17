# m125_ffn_export_wsl — the WSL box's re-export of the SAME checkpoint + window

Made 2026-08-17 on the WSL box from the `125m-best-adamw-val3.0816`
tarball (= runs/125m-baseline/ckpt-00009536, sha256
84519a7b9f6aaf75461895a847f604bf1608b244f99058b67dd1577bbcc89b4c) and
`data/fineweb-edu-val/shard-00000.npy` (50,000,088 uint16 tokens) with
`scripts/m125_export_ffn.py --out results/m125_ffn_export_wsl` under
the frugal venv (mlx 0.31.2, Linux CPU).

- All 36 weight tensors are BYTE-IDENTICAL to the committed Mac export
  (`results/m125_ffn_export/manifest.json`).
- The 12 per-layer X tensors (and hence z) DIFFER from the Mac's by a few
  int8 elements: same window (layers 0-2 accumulator maxima identical),
  mlx CPU-vs-Metal rounding in the fp32 attention/norm path between FFN
  layers. Range-fact violations: 0 — a valid honest witness of the same
  statement class, NOT the frozen one: the statement digest differs from
  the pinned 76dbf2040409333e, so freeze-check's UAGB1-BF rows still
  need the Mac's `layerXX_X.bin` files (12 files, ~4.7 MB).
- Use: `M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl
  ring_matmul <rig>` (the Rust loader honours the variable; T = 512
  digest checks run against THIS directory's digests.txt).
- Numbers taken with it are labeled [WSL-BOX, wsl-export].
