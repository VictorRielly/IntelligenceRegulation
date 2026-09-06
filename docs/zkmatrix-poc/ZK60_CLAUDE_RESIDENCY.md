# CL7 — the hiding opening's re-encode: fused and output-pruned, byte-identical, 1.22x on the changed phase

Task: `zk60_claude_tasks.json` CL7 ("remove a measured transfer or scratch
bottleneck"). Files: `hashline/src/gpu/cuda.rs` (`encode_rows_view_zk_gather`,
`columns_chunked_zk`, the `HL_ZK_FUSE_GATHER` switch and two test overrides),
`hashline/src/gpu/mod.rs`, `hashline/tests/zk60_gpu_commit.rs`
(`fused_hiding_openings_match_the_cpu_in_every_form`). Measurement:
`results/cl7_reenc_ab.sh`, log `results/cl7_reenc_ab.log`, marker 0, per-run
logs `results/cl7_ab_{fused,reference}_r{1,2}.log`.

---

## 1. Which bottleneck, and why this one

CL5's profile at 125M put the three commitments at 47.6% of proof-ready and
said "the commitments are now the shape to attack, not the openings" — at
125M, where nothing chunks. CL6's sweep at Mistral width, where every hiding
commitment chunks by size, measured the split the 125M profile could not:

| phase (one Mistral layer, P3, chunk 128) | s | share of the 4.05 s prove |
|---|---:|---:|
| three chunked ZK commits (W/A/H) | 0.62 | 15% |
| three chunked ZK re-encode openings (W/A/H) | 0.57 | 14% |
| device NTT counter (`ntt`, the commits' encode) | 0.63 | — |
| h2d | 0.46-0.63 | 11-16% |

The openings were the bottleneck with a defect attached: `columns_chunked_zk`
(CL1) re-encoded every chunk in full — the expand NTT's last stage group
wrote the whole `rmax x nn` encoded chunk back to its buffer, and
`k_gather_cols_off` then read it again to keep 256 columns of 65,536. The
NON-hiding opening stopped doing that two rounds ago: lane AJ fused the
gather into the last stage group (the store and the re-read gone), and lane
AO pruned that group to the ~250 residues `col mod 4096` that can produce a
sampled column (4.38x on that kernel). The hiding opening had never received
either, because CL1 wrote it against `encode_rows_view_zk`, the commit's
encode, and the commit has to produce every column.

So the "measured bottleneck" here is a scratch-traffic one — the encoded
chunk stored and re-read for nothing — and the fix is porting the existing,
byte-gated form rather than inventing one.

---

## 2. What changed

`encode_rows_view_zk_gather`: the inverse NTT and `k_zk_pad_scale` exactly as
before; the expand NTT's first stage group as `ntt_rows` launches it
(`k_ntt_p1`, forward, scale 1, `n_src = nn`), so the fused last-stage kernels
read the layout `k_ntt_p2` would have read; then `k_ntt_p2_gather_sp` over
the compact residue list (or the dense `k_ntt_p2_gather` when the list is
not materially smaller, or when `HL_GPU_PRUNE_P2=0`). `columns_chunked_zk`
builds the distinct-index slot map, the residue list and the per-slot
output exactly as `columns_chunked` does, and expands repeated indices on
the host from the first occurrence. Same operands, same twiddles, same stage
order: the opened columns are bit-identical.

Switches: `HL_ZK_FUSE_GATHER=0` retains the CL1 form (the reference path);
`HL_GPU_FUSE_GATHER` still gates both openings; `HL_GPU_PRUNE_P2` still
selects pruned vs dense. Test overrides (`set_zk_fuse_gather_for_test`,
`set_prune_p2_for_test`) let one process exercise every form. No caller
changed: `dev_columns` is still the single opening entry point, `zk.rs`,
`attention.rs` and `layer.rs` were not touched.

**No memory ownership changed.** The opening takes the same three pooled
scratch buffers by `take_min`; its raw allocations are now the slot map
(`nn` x 4 B instead of `q_open` x 4 B), the residue list and a
`rows x distinct` output instead of `rows x q_open`. All are noted one by one
by the round-7 counters. No asynchronous work, no double buffering, no event
ownership — so the allocation-lifetime/cleanup tests CL7 asks for with an
ownership change are not owed, and none is claimed.

---

## 3. Correctness [MEASURED, RTX 4070, 49 executed oracle cases]

`fused_hiding_openings_match_the_cpu_in_every_form`, against the CPU's own
`encode_row_zk`: pruned AND dense at (log_cols, rate, rows, pads, chunk) =
(12, 4, 300, 16, 128), (14, 2, 200, 256, 128), (12, 8, 260, 64, 256);
REPEATED indices (`[5, 4099, 5, 16383, 4099, 0, 0, 8191, 5, 4095, 4096]`);
an out-of-range index refused; a shape where fusion is not eligible
(log_nn = 10) served by the reference form; and the reference form itself
under the switch. Every pre-existing oracle test (deferred openings across
shrinking tables, alternating rates, ragged rows, every chunk-row choice)
opens through `columns_chunked_zk` and therefore exercised the fused path
too: 19 tests, 0 failed. The negative control (opening a hiding commitment
with the NON-ZK re-encode) still fails loudly.

Frozen fixtures: the CL7 A/B produced the Mistral P3 proof `190e85a1..` /
40,251,860 B in all four runs, fused and reference alike. The 12-gate floors
on the final tree are recorded in `ZK60_CLAUDE_GPU.md`.

---

## 4. Measurement [MEASURED, WSL-BOX, RTX 4070, one Mistral layer, P3, ABAB x 2, single box, not quiesced]

| arm | W re-encode s | A | H | three re-encodes s | PROVE s | VRAM peak MB | proof |
|---|---:|---:|---:|---:|---:|---:|---|
| reference (`HL_ZK_FUSE_GATHER=0`) r1 | 0.3643 | 0.1175 | 0.0987 | 0.5805 | 4.10 | 5,182 | `190e85a1..` |
| fused, pruned 248/251/245 of 4096, r1 | 0.2878 | 0.0959 | 0.0817 | 0.4654 | 3.87 | 5,182 | identical |
| reference r2 | 0.3552 | 0.1160 | 0.0986 | 0.5698 | 3.94 | 5,182 | identical |
| fused r2 | 0.2971 | 0.0959 | 0.0808 | 0.4738 | 3.92 | 5,182 | identical |

**The changed phase: 0.575 -> 0.470 s, 1.22x** (W alone 0.360 -> 0.292,
1.23x). Attributed to the changed fraction, that is 0.105 s of a ~4.0 s
prove = **2.6%**, and the prove clock moved 4.02 -> 3.90 s (3.1%) — the same
number inside this box's ~3% run-to-run spread. **No pass-level gain is
claimed beyond that fraction**, and no 8B number is projected: at 8B the
same three re-encodes recur per layer, so the fraction is the same order, not
larger.

Why 1.22x and not AO's 1.48x: the non-hiding opening's chunked re-encode is
inverse NTT -> zero-padded expand NTT, and AO's levers took the last stage
group from a large share of it. The hiding re-encode carries two more full
passes over the `rmax x nn` chunk that the fusion cannot touch: `k_zk_pad_scale`
writes the whole padded/coset-scaled row and `k_ntt_p1` reads and writes it
again. The last stage group was ~30% of this opening's traffic, and ~30% is
what came off.

---

## 5. The next byte-preserving lever, named and not taken

`k_zk_pad_scale` writes `rmax x nn` values of which the last `nn - n - q`
per row are ZEROS (rate 4: three quarters of the row), and `k_ntt_p1` then
reads them back. `k_ntt_p1` already zero-extends any source column beyond
`n_src`; launching it with `n_src = n + q` over a `rmax x (n + q)` pad/scale
output would drop ~4 GB of the W opening's ~23 GB of traffic and the same
share of the COMMIT's encode, with identical values (a zero read is a zero
extended). It is the single largest remaining item in this phase, it needs
the pad/scale kernel's output stride changed, and it is deliberately not in
this commit: CL7 is one measured bottleneck, separately reviewable.

---

## 6. Limits

- Single box, two repeats, not a p95; the seconds are indicative, the bytes
  exact.
- Single Mistral layer; no 8B pass (the rule stands).
- The fused form needs `log_nn > 12` (a second stage group); below that the
  reference form serves the opening, tested.
- The prune's compact list is used only when the distinct residues are at
  most a quarter of the block, as in the non-hiding opening; with 256
  sampled columns that is always the case at these widths.
