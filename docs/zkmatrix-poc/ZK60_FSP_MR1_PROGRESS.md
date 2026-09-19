# FSP lane 5 — the public-endpoint repaired-mask timing probe (`mr1`)

**Worktree** `/home/victor/wt-fsp-mr1`, branch `fsp-mr1`, on top of the
finished lane `fsp-zkhost` (tip `fb850b8`).
**Sole writer.** Files owned by this lane: `hashline/src/zk.rs`, the new
`hashline/src/zk_mr1_probe_tests.rs` and its one registration line,
`hashline/examples/zk60_repaired_mask_probe.rs`, `results/fsp5_*`, and this
ledger. Everything else in this repository and every other worktree is
READ-ONLY for this lane. In particular `hashline/src/layer.rs`, `pcs.rs`,
`wcache.rs`, `ntt.rs` and `hashline/src/gpu/*` belong to the other speed
lane; `zk_ffn_fresh_*.rs`, `private_*.rs`, `bin/hashline.rs`, `scripts/`,
`tests/` and every design document but this one are read-only here.
`/home/victor/IntelligenceRegulation` (Codex works live there) and
`/home/victor/wt-fsp-zkhost` (detached jobs still queued against its
sources) are never written by this lane.

**What the lane is.** Every PRIVATE timing in this repository was measured
on the legacy privacy profile, which the 2026-09-08 finding showed
DISCLOSES private values. A repaired mask schedule exists in code — `mr1`:
paired mask rows, refusal instead of resampling, a rank check before every
opening — and `ZK60_PRIVATE_FFN_COST_PROBE.md` establishes by reading the
constructors that it is already shape-general. But NOTHING CAN CALL IT
above the tiny T32/d16/f16 shape: `prove_layer_zk_v3` hard-codes
`mr1 = false` and the two inner functions are private. So nobody knows what
the repaired profile COSTS at a real shape. By row count it should be the
legacy cost plus about 2% at T = 512 — that is a COUNT. This lane produces
the first MEASUREMENT, at the 125M-class shape (12 layers, width 768,
hidden 2048, 512 tokens) and at nothing wider.

**THIS IS A COST PROBE, NOT A PRIVACY CLAIM.** The entry pair this lane
adds runs the repaired mask schedule with **PUBLIC endpoints**. The
hiding-endpoint half (`zk_ffn_fresh_io.rs`, `private_seam.rs`, their size
pins) is OUT OF SCOPE and is not touched or unpinned. Running this probe
establishes NO privacy property whatsoever — not P1, not anything. It
measures what the repaired mask schedule costs in seconds, bytes and
committed rows.

**The lane is strictly byte-preserving for every existing path.** The
legacy default stays `mr1 = false`; the tiny private-IO entry points stay
pinned to their tiny shape; no transcript label, mask schedule, endpoint or
privacy-policy change is made to any existing path. If the repaired profile
at a larger shape REQUIRED such a change, the instruction is to stop and
report rather than make it. A moved frozen digest is a BUG in the change:
revert, record, move on. Never adjust a gate, never re-freeze a digest.

Every number carries its shape, conditions, box load and label:
[MEASURED], [COUNTED], [MODEL].

---

## Stages

| # | stage | status |
|---|---|---|
| 0 | Ledger, ownership, the scoping memo and the previous lane's ledger read | DONE |
| 1 | FLOOR on the untouched tip: suite + the four frozen digests on CPU, GPU, GPU forced-chunked | IN FLIGHT |
| 2 | The entry pair in `zk.rs` (one commit) + its cfg(test) file; then the whole floor again | TODO |
| 3 | The driver: `hashline/examples/zk60_repaired_mask_probe.rs`, three arms | TODO |
| 4 | The first measurement at 12 x 512, CPU and GPU binaries, >= 5 repeats/arm, alternating order | TODO |

**Not in scope and not run, by instruction:** anything at Mistral width
(4096 / 14336) on either processor; any model-width GPU run; the
hiding-endpoint (`io`) half at any shape above the tiny one.

---

## The frozen floor (from lane `fsp-zkhost`, stage 2)

`pass 12 512 --threads 2` against
`/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export` (v3 profiles)
and the built-in fixture (v2 / zk):

| profile | digest | bytes |
|---|---|---:|
| v2 | `50cf7bdf..` | 66,844,928 |
| v3 | `5f368db6..` | 70,758,084 |
| zk | `021485e4..` | 87,228,528 |
| zk-v3 | `40eb5479..` | 87,697,008 |

Build notes inherited from that lane: the GPU build needs `CUDA_ROOT` set
or `cudarc v0.13.9`'s build script exits 101; the GPU binary lives in a
separate target directory, `hashline/target-gpu/release/hashline`.

---

## Log

### 2026-09-19 — stage 0, ledger opened

Read in full: `docs/zkmatrix-poc/ZK60_PRIVATE_FFN_COST_PROBE.md` (1,077
lines, read from the main tree — it is not yet on this branch's history)
and `docs/zkmatrix-poc/ZK60_FSP_ZKHOST_PROGRESS.md` (478 lines). Read in
part: `hashline/src/zk.rs` (the layout constructors, the two entry pairs,
the pending lifecycle, every `mr1` site), `hashline/src/zk_ffn_fresh_poc.rs`
(all 342 lines), the previous lane's gate script.

**Line numbers verified against this branch's `zk.rs`** (the memo's were
written before lane `fsp-zkhost` landed and several have moved):

| what | memo says | this branch |
|---|---|---|
| `ZkLayoutV3::with_masks` | 2002-2054 | **2002-2055** (unmoved) |
| the masking-commitment specs | 2149-2174 | **moved: `mask_specs_v3` is now at 2245** |
| `prove_layer_zk_v3` hard-codes `mr1 = false` | 2280 | **2429-2431** |
| `prove_layer_zk_v3_inner` (private) | 2283 | **2433** |
| `prepare_layer_zk_v3_inner` (private) | 2337 | **2494** |
| `verify_layer_zk_v3` (public, `mr1 = false`) | — | **3697-3699** |
| `verify_layer_zk_v3_inner` (private) | 3467/3471 | **3701** |
| `verify_layer_zk_v3_with_seams` (private) | — | **3705** |
| the `mr1` refusals | `zk_ffn_fresh_poc.rs:221-341` | **unmoved: 221-341** |

So the memo's central claim holds on this branch: `with_masks` takes the
shape as a parameter, every refusal in `zk_ffn_fresh_poc.rs` is written
against `rows` / `log_n` / `mask_rows` / `prox`, and the only thing missing
is a caller.
</content>
</invoke>
