# hashline on the GPU — the SHAPE-GENERAL kernels (U-PERF3 lane AH, 2026-09-03)

Box: the WSL laptop (Core Ultra 9 185H, 8 prover threads, 15 GB) with an
RTX 4070 Laptop GPU (sm_89, 36 SMs, 8,188 MB), CUDA driver + NVRTC only.
Every wall below is `[WSL-BOX] [8T] [GPU|CPU] [MEASURED]`; the box was
quiet (load < 1.1 at the start of each run, no other lane on the device).
Labels: [MEASURED] a run happened here; [COUNTED] arithmetic on measured
pieces; [MODEL] an estimate with stated assumptions.

Companion records: `results/hashline_gpu_12x512.md` (lane XX, the GPU
port), `results/hashline_8b_gpu.md` (lane AC, the 8B GPU pass this lane
re-measures), `results/hashline_zk_v3_12x512.md` (lane AD, the ZK form).

---

## The one sentence

The device kernels were written for the small model's block shape, so at
the real model's shape the device path was **declined** and 44% of the 8B
GPU prove ran on the CPU (lane AC's measurement). This lane made the
zero-check and LogUp-helper kernels **loop over blocks**, which removed
that decline: **the 8B feed-forward proof of Mistral-7B (32 layers x 512
tokens) now proves on the laptop GPU in 95.5-104.4 s instead of 175.1 s,
and the proof is the same 1,234,936,956 bytes with the same sha256**.

## What was templated, and why it declined the real model

`LayoutV3` splits the two weight axes into blocks: the d axis into `nb_d`
blocks of `2^log_db` and the f axis into `nb_f` blocks of `2^log_fb`
(`log_* = min(v2(dim), 12)`).

| model | d | f | (nb_f, nb_d) | zero-check F tables | zero-check D tables |
|---|---:|---:|---|---:|---:|
| the 125M rig | 768 = 3 x 256 | 2048 = 1 x 2048 | (1, 3) | 3 + 10 x 1 = **13** | 3 + 4 x 3 = **15** |
| **Mistral-7B** | 4096 = 1 x 4096 | 14336 = 7 x 2048 | **(7, 1)** | 3 + 10 x 7 = **73** | 3 + 4 x 1 = **7** |

Three things were fixed to the first row:

1. `kernels.cu`'s `sc_round_impl<K, KIND>` holds `f2 cur[K], dif[K]` in
   REGISTERS, so K must be a compile-time constant; the only two
   instantiations were `k_sc_round_zc20 = <13, 0>` and
   `k_sc_round_zc17 = <15, 1>`.
2. The per-block coefficients (`mu`, `nu`) were read from a **32-u64**
   shared array — exactly enough for one f-block or three d-blocks.
3. `layer.rs`'s three device regions built their spec lists with the
   f-block index **hard-coded to `[0]`**.

Hence the gate `let dev_shape = nb_f == 1 && nb_d == 3;`, which at
Mistral's shape sent the LogUp helper columns and BOTH zero-checks back
to the host. AC measured the cost: **76 s of the 175 s 8B GPU prove
(44%)**.

## The fix (byte-preserving by construction)

Both zero-check polynomials have the form

    eq_t(x) * ZC(x) + eq_a(x) * F_a(x) + eq_b(x) * F_b(x)

where `ZC`, `F_a`, `F_b` are **sums over blocks** of terms that read only
that block's own tables (10 on the F side, 4 on the D side). So the round
kernel can loop over the blocks, holding ONE block's `cur`/`dif` in
registers, accumulating the three partial sums at the five evaluation
points, and joining with the three eq tables once per element. The
register footprint no longer depends on the block count — which is
exactly what the templated form could not do.

- **`k_sc_round_zcf_gen` / `k_sc_round_zcd_gen`** (`kernels.cu`),
  `__launch_bounds__(128, 1)`, block-indexed parameters in a 384-u64
  shared array (bounds `nb_f <= 26`, `nb_d <= 62`; Mistral needs 115
  u64 at `nb_f = 7`).
- **`dev_zerocheck_blocks(kind, nb, ..)`** (`cuda.rs`) beside the
  untouched templated `dev_zerocheck`, which the v2 prover and zk.rs
  still call.
- **`dev_reserve(&lens)`**: the two zero-check table buffers are taken
  through lane XX's device-buffer pool (which matches by exact length,
  so the reservation IS the later allocation) and given back, BEFORE the
  helper columns leave the host. This matters: once the helpers are on
  the device there are no host tables, and a later decline is a panic by
  design. Now the whole layer falls back or not at all.
- **`layer.rs`**, three `[UPERF3-AH]`-tagged edits inside the v3 FFN
  prover: the gate, the helper-spec list (`for b in 0..nb_f`), the two
  TabSpec lists + the block-indexed parameter layout.
- **Rung 3**: `k_sc_round_tab_gen` + `dev_tab_zerocheck` — the ZK table
  zero-check (degree 3, so 4 evaluation points per round, not 5) with
  `TabSpecPad` tables that are zero-extended to `2^log_S` exactly as the
  host's `resize(big, ZERO)`; one tagged edit in zk.rs's v3 prover.

WHY THE BYTES CANNOT MOVE: every value is a field expression identical to
the CPU closure's, term for term, and every accumulation is a field sum
(associative and commutative, exact — no rounding exists). The transcript
therefore absorbs identical round polynomials. The gates below are the
evidence, not the argument.

---

## THE 8B ROW: Mistral-7B, 32 layers x 512 tokens, `--profile v3`

`HL_GPU=1 hashline pass 32 512 --profile v3 --export <m8b_mistral_v3_export>
--wcache <fresh dir> --threads 8 --proof-out F`, under
`flock /tmp/zk-heavy.lock /usr/bin/time -v`, cold cache (32 misses) — the
same configuration as AC's 175.09 s row.

| | CPU (8T, the reference) | AC GPU (round 12) | **AH GPU run 1** | **AH GPU run 2** |
|---|---:|---:|---:|---:|
| witness load + chain | — | 130.75 s | 126.97 s | 130.30 s |
| **PROVE** | **510.38 s** | **175.09 s** | **95.48 s** | **104.42 s** |
| VERIFY | 1.21 s | 1.09 s | 1.16 s | 1.01 s |
| wall | — | 308.82 s | 225.35 s | 237.57 s |
| proof bytes | 1,234,936,956 | 1,234,936,956 | 1,234,936,956 | 1,234,936,956 |
| peak RSS | 13.99 GB | 5.33 GB | **3.80 GB** | 3.85 GB |
| VRAM peak | — | 4,175 MB | 5,651 MB | 5,651 MB |
| proven MAC/s | 5.66e9 | 1.65e10 | **3.02e10** | 2.76e10 |

**THE BYTE GATE: `sha256sum` over both written 1.23 GB files gives
`dc980e810085b2ddf4688eb4a6cf4dd931c209bf7c5a9a7692d57ec14bc4536c`** —
the merged CPU reference, AC's GPU proof, and both of this lane's. So the
8B proof is invariant under device vs host, chunked vs resident
commitment, cached vs fresh weights, AND 125M-templated vs block-looping
kernels.

The two runs differ by 8.9 s and the difference is entirely `commit W`
(41.94 vs 50.56 s): run 2 started with 2 GB free and 11 GB of page cache
left by run 1's 1.23 GB proof write and the 7 GB export re-read, so its
host-side plane conversion and pageable upload paid more. The phases this
lane changed reproduced to three digits across the two runs (zcF 4.645 /
4.649, zcD 0.792 / 0.789, helpers+H 5.361 / 5.408). **Quote 95.5-104.4 s
and treat 95.5 as the quiet-box figure.**

### Phases, summed over the 32 layers [MEASURED, s]

| phase | CPU 8T | AC GPU | **AH GPU (run 1)** | AH vs AC |
|---|---:|---:|---:|---:|
| commit W | 224.97 | 38.85 | 41.94 | 0.93 |
| commit A | 81.77 | 13.53 | 15.85 | 0.85 |
| **helpers + commit H** | 102.74 | 35.24 | **5.36** | **6.6x** |
| matmul g/u | 6.58 | 5.38 | 5.25 | 1.02 |
| matmul d | 3.52 | 2.86 | 2.88 | 0.99 |
| **zero-check F** | 50.82 | 46.64 | **4.65** | **10.0x** |
| **zero-check D** | 7.75 | 7.48 | **0.79** | **9.5x** |
| pcs openings | 31.68 | 24.61 | 18.48 | 1.33 |
| **total** | **510.38** | **175.09** | **95.48** | **1.83x** |

Device-side (run 1): h2d 13.05 s for **59,861 MB** (AC: 15.72 s for
72,209 MB — 12.3 GB less uploaded, because the H helper columns are no
longer built on the host and copied up), encode NTT 15.85 s, **sumcheck
5.44 s**, folds 2.89 s, **helpers 1.38 s**, opening re-encode 14.28 s, 96
chunked commits, 1,413 MB back.

**The host share AC measured at 44% is 0**: the three declined phases are
10.80 s of device work. What remains in the 95.5 s is the list XX and AC
already recorded, none of it a declined kernel —

| the residual, and its lever | s | label |
|---|---:|---|
| witness planes -> Fp conversion + pageable h2d (inside commit W / A) | ~13-20 | upload the raw i8/i32 planes and convert on the device; pinned staging [MODEL: halves it] |
| the encode NTT (commit W / A / H) | 15.8 | radix-4 / conflict-free NTT [MODEL: 2-4x] |
| the opening's chunked re-encode | 14.3 | persist the encoded rows, or serve columns without the matrix (AC's (a)/(b)) |
| the openings' Merkle levels + claim bookkeeping + serializing 1.23 GB | ~13 | device Merkle; streaming serialization |
| the matmul folds + the 2^8 / 2^11 sumchecks | 8.1 | the fold kernel class (XX rung 4) |

## ONE Mistral-7B LAYER at T = 512 (the same change, isolated)

`HL_GPU=1 hashline pass 1 512 --profile v3 --export <mistral v3> --threads 8`

| phase | before | after | factor |
|---|---:|---:|---:|
| commit W | 1.291 | 1.366 | 0.95 |
| commit A | 0.450 | 0.453 | 0.99 |
| helpers + commit H | 1.022 | **0.261** | 3.9x |
| matmul g/u + d | 0.263 | 0.250 | 1.05 |
| zero-check F | 1.454 | **0.144** | 10.1x |
| zero-check D | 0.236 | **0.024** | 9.8x |
| pcs openings | 0.785 | 0.584 | 1.34 |
| **PROVE** | **5.515 s** | **3.090 s** | **1.79x** |
| peak RSS | 4.17 GB | **2.48 GB** | 1.68x less |
| VRAM peak | 4,175 MB | 5,651 MB | +1,476 MB |
| proof | 38,688,700 B `179ec2fb..` | identical | — |

The extra 1.48 GB of VRAM is the two zero-check table buffers (73 x 2^20
and 7 x 2^21 f2 = 1.22 GB + 0.23 GB), which is why they are reserved
before the helpers move. The 1.7 GB of host RSS that went away is the
same tables, which the host used to build.

## NO REGRESSION AT THE 125M SHAPE (the A/B that had to be run)

Two runs each in one session, `pass 12 512` on the GPU: the block-looping
kernels on the v3 statement against XX's templated kernels on the v2
statement — the same 13 / 15 tables, the same work.

| | generic (v3) | templated (v2) |
|---|---:|---:|
| zero-check F / 20 | **0.327 / 0.323 s** | 0.338 / 0.340 s |
| zero-check D / 17 | **0.085 / 0.079 s** | 0.095 / 0.103 s |

Looping costs nothing measurable at the shape the templates were written
for. The templated kernels are kept beside the general ones only because
XX's and ZA's published rows were taken with them.

## THE ZK TABLE ZERO-CHECK (rung 3; lane AD's item)

At `--zk --profile v3` the table-side zero-check runs over
`log_S = max(log n, 16) = 16` variables and was the last host sumcheck of
the ZK prover. AD measured it at 1.14 s of a 5.63 s GPU ZK prove (20%)
on a loaded box; this tree's quiet before/after, 3 runs each:

| 12x512 v3 `--zk --seed 1`, GPU | before | after |
|---|---:|---:|
| table zero-check (zk) phase | 0.700 s | **0.322 s** (2.2x) |
| PROVE p50 | 4.56 s | **4.16 s** |
| proof | 87,697,008 B `40eb5479..` | identical |

The residual 0.322 s is no longer the sumcheck: it is the phase's host
tail (12 `eval_slice` mask evaluations, the extension round, the
absorbs). Tamper legs through the GPU ZK prover:
`layer 0 512 --zk --seed 1 --profile v3 --all-tampers` -> **8/8 REJECT,
GREEN**, with AD's exact split (the four lookup legs at
`H: pcs zk: group 4: <v, c> != combined claim`, the other four at
`sumcheck round 0: s(0) + s(1) != claim`).

## The four byte gates (re-run at every rung, on BOTH binaries)

`M125_EXPORT_DIR=/home/victor/IntelligenceRegulation/results/m125_ffn_export_wsl`;
the v3 export `/home/victor/wt-uperf3-aa/results/m8b_test/m125_v3_export`;
each `pass 12 512 --threads 8 --proof-out F` plus the gate's flags.

| gate | sha256 | bytes | CPU | GPU |
|---|---|---:|---:|---:|
| v2 | `50cf7bdfd6b5b182..` | 66,844,928 | 14.72 s | 2.52 s |
| v3 `--profile v3 --export` | `5f368db6240e0614..` | 70,758,084 | 15.17 s | 2.70 s |
| zk-v2 `--zk --seed 1` | `021485e4f80ec695..` | 87,228,528 | 16.94 s | 3.91 s |
| zk-v3 `--zk --seed 1 --profile v3` | `40eb54795e023c77..` | 87,697,008 | 19.25 s | 4.16 s |

(the walls are the final rung's; every digest equals the round-12
reference, from both binaries, checked by `sha256sum` as well as by the
binary's own print). Also `pass 3 16 --profile v3` CPU == GPU
(`5d49ab31..`), `pass 3 16 --zk --profile v3` CPU == GPU (`4d9f7632..` =
AD's), and `cargo test --release` **40/40**.

## Tokens per second at 8B, against lane YY's modelled band

`U_PERF3_ROUTE_B_THROUGHPUT.md` §6.2 models the laptop GPU at 5.2-16
tokens/s for an 8B prefill of T = 512 in mode P0, FFN-only, prover clock;
§6.5 models 2.9e10-8.8e10 proven MAC/s. AC measured 2.92 tok/s and
1.65e10 — **1.8x below the band**, and identified the reason: the band
assumed all of Route B's work is device-shaped, which was true at 125M
and false at Mistral width because of the declined kernels.

| cell | YY [MODEL] | AC [MEASURED] | **AH [MEASURED]** | verdict |
|---|---|---:|---:|---|
| laptop CPU 8T | 1.0 tok/s | 1.00 | 1.00 | inside — exact |
| laptop GPU, tokens/s | 5.2-16 | 2.92 | **4.90-5.36** | **the band's low end reached** |
| laptop GPU, proven MAC/s | 2.9e10-8.8e10 | 1.65e10 | **2.76e10-3.02e10** | **inside at the low end** |

**Where the fix lands: it closes the whole gap AC attributed to the
declined kernels (2.92 -> 5.36 tok/s, 1.83x, against the 1.5x AC's model
expected) and puts the measured row inside the modelled band's low end.**
The distance to the band's UPPER end is now entirely the host remainder
in the table above — conversion + pageable upload, the encode NTT, the
opening's re-encode, and the Merkle/serialization of a 1.23 GB proof —
none of which is a shape problem, and all of which have known
byte-preserving fixes. The caution AC attached to the desktop-board and
H100 columns can be narrowed accordingly: the premise "Route B's work is
device-shaped" now holds for the checks and the helpers at a real model
width; it still does not hold for the witness marshalling and the proof
serialization.

## Commands (exactly as run)

    # build (CPU binary)
    flock /tmp/zk-build.lock cargo build --release \
      --manifest-path /home/victor/wt-uperf3-ah/hashline/Cargo.toml
    # build (GPU binary)
    CUDA_ROOT=/home/victor/cuda-root \
    LD_LIBRARY_PATH=/home/victor/cuda-root/lib64:/home/victor/.local/lib/python3.10/site-packages/nvidia/cuda_nvrtc/lib:/usr/lib/wsl/lib \
    CARGO_TARGET_DIR=/home/victor/wt-uperf3-ah/hashline/target-gpu \
    flock /tmp/zk-build.lock cargo build --release --features gpu-cuda \
      --manifest-path /home/victor/wt-uperf3-ah/hashline/Cargo.toml

    # the 8B GPU pass
    HL_GPU=1 flock /tmp/zk-heavy.lock /usr/bin/time -v \
      hashline pass 32 512 --profile v3 \
      --export /home/victor/wt-uperf3-aa/results/m8b_mistral_v3_export \
      --wcache <dir> --threads 8 --proof-out <file>

    # one Mistral layer, and the 125M gates
    HL_GPU=1 hashline pass 1 512 --profile v3 --export <mistral v3> --threads 8
    hashline pass 12 512 --threads 8 --proof-out <file>
    hashline pass 12 512 --profile v3 --export <m125 v3> --threads 8 --proof-out <file>
    hashline pass 12 512 --zk --seed 1 --threads 8 --proof-out <file>
    hashline pass 12 512 --zk --seed 1 --profile v3 --export <m125 v3> --threads 8 --proof-out <file>
