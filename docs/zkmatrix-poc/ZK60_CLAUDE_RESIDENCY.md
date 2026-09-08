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

---

## 7. CL18 — the compact pad/scale output: DERIVED FIRST, then switched, then measured

Task: `ZK60_FABLE_QUEUE.md` CL18 ("evaluate compact pad/scale output as one
bounded GPU optimization"). Lane HEAD at the start: `c02d86c` (CL17 gate
GREEN on `4a0ce56`). This section was written BEFORE any kernel or launch
was touched; §7.7 onward record what was then built and run. A neutral or
negative measurement is a valid outcome; nothing here is a claimed speedup.

### 7.1 The data path and who reads the pad/scale output

The hiding encode is the same three steps on every route; per row chunk of
`rc <= rmax` rows on the chunked routes, over all `rows` on the resident one:

1. inverse NTT: `ntt_rows_view(data, coef, rc, n_src = n, log_n, inverse)`
   → `coef` (rc x n), natural-order coefficients.
2. `k_zk_pad_scale(coef, pads, pows, coef2, rc, n, q, nn)`: one thread per
   `(row, i)`, `i < nn`; writes `coef2[row*nn + i]` = `(c_i - pad_i) h^i`
   for `i < q`, `c_i h^i` for `q <= i < n`, `pad_{i-n} h^i` for
   `n <= i < n + q`, and `gl_mul(0, h^i)` for `n + q <= i < nn`. Its last
   argument `nn` is used ONLY as the output row stride and thread bound
   (`rows*nn` threads, `row = g / nn`, `i = g - row*nn`, `out[g]`). It is
   not an NTT size and is compared with nothing else.
3. forward NTT of size `nn`: `k_ntt_p1(src = coef2, dst = enc, tw, log_nn,
   n_src, scale 1)`, then for `log_nn > 12` either `k_ntt_p2` in place on
   `enc` (commit; reference opening) or `k_ntt_p2_gather_sp` /
   `k_ntt_p2_gather` reading `enc` and writing only the sampled columns
   (fused opening, pruned / dense).

`coef2` has exactly ONE reader on every route — `k_ntt_p1`:

| route | function | pad/scale launch today | reader of `coef2` | `n_src` today |
|---|---|---|---|---|
| chunked commit | `commit_zk_chunked` → `encode_rows_view_zk` | `rows*nn` threads, stride `nn` | `ntt_rows` → `k_ntt_p1` | `nn` |
| reference opening (`HL_ZK_FUSE_GATHER=0`, or `log_nn <= 12`) | `columns_chunked_zk` → `encode_rows_view_zk` | same | same | `nn` |
| fused opening, pruned or dense | `columns_chunked_zk` → `encode_rows_view_zk_gather` | same | a direct `k_ntt_p1` launch | `nn` |
| resident commit (`HL_ZK_CHUNK=0`, or small by size) | `dev_commit_zk_from` | `rows*nn`, stride `nn` | `ntt_rows` → `k_ntt_p1` | `nn` |

`k_ntt_p2*`, `k_hash_cols_stream` and `k_gather_cols_off` read `enc`,
never `coef2`. The `assert!(coef2.len() >= rows * nn && ...)` in
`encode_rows_view_zk_gather` is the only place the full width is assumed
outside the launches.

### 7.2 How `k_ntt_p1` handles a shorter source row

```
const u64* s = src + (size_t)row * (size_t)n_src;
...
int r = (int)(__brev((u32)x) >> (32 - log_n));
sh[q] = (r < n_src) ? s[r] : 0ULL;
```

`n_src` is BOTH the source row stride and the zero-extension bound. There
is no separate stride argument, no assumption that a source row is
`2^log_n` long, and nothing divides by or aligns to `n_src`, so it need
not be a power of two. Positions `r >= n_src` are never read — they are
synthesized as `0ULL`. This is exactly how the NON-hiding commit encode
has always expanded (`ntt_rows(coef, enc, rows, n_src = n, log_nn)`,
rung 1: "the RS zero padding without materializing it"). Requirements on
`n_src`: `1 <= n_src <= 2^log_n`, fits `int`, and the source buffer holds
`>= rows * n_src` elements.

The DIT decomposition: the transform size is `nn = 2^log_nn`, fixed by
`log_n`; the first 12 stages run on a 4096-position block of the OUTPUT
index space in shared memory, with the bit-reversed gather from the
natural-order source done on the load; `k_ntt_p2` then runs the remaining
stages on `enc`. The input LENGTH only decides which natural-order
coefficients are nonzero — nothing in the stage structure depends on it.
(Contrast `k_dit_p1_pad`, the non-hiding forward's first pass: it takes a
BIT-REVERSED source zero-interleaved by `R = 2^rb` and its `_s` skip needs
`R` a power of two. It is not on the hiding path, and `nn / (n + q)` is not
a power of two, so the hiding path could not use it; it does not need to.)

### 7.3 Is any read of the zero tail load-bearing? No.

The only reader is `k_ntt_p1`. With `n_src = n + q` it produces `0ULL` at
exactly the positions where the full buffer holds `gl_mul(0ULL, pows[i])`,
and `gl_mul(0, b) = gl_reduce(0, 0)`: `hi_lo = hi_hi = 0`, `t = 0`,
`t1 = 0`, `r = 0` → `0ULL` bit-exactly (kernels.cu, `gl_reduce`). The
shared-memory tile after the load is therefore bit-identical on both
routes, every later stage sees identical operands, and the leaves and the
opened columns cannot differ. The `pows[i]` reads for `i >= n + q` (which
only ever multiplied zero) disappear with the tail.

### 7.4 The compact stride and ownership

- Output row stride `pw = n + q` (the "pad width"); buffer `rmax x pw`.
- Written by the SAME `k_zk_pad_scale`, launched with its width argument
  `:= pw` and `rows * pw` threads: every `i < pw` is a data, data-minus-pad
  or pad coefficient times `h^i`; the zero branch is simply never reached.
- Read by the SAME `k_ntt_p1` with `n_src = pw`. **No kernel changes.** The
  lever is a launch-parameter and buffer-size change in cuda.rs.
- Ownership unchanged: `d_coef2` is still taken by `take_min` in
  `commit_zk_chunked` and `columns_chunked_zk` and returns to the pool on
  drop — `rmax * pw` elements instead of `rmax * nn`. `enc` stays
  `rmax x nn` (the transform output IS `nn` wide). The failure/cleanup
  paths are the same `?` returns with the same `Pooled` drops.
- The RESIDENT path is NOT changed: it is the `HL_ZK_CHUNK=0` reference,
  it takes with exact-match `Pooled::take`, and shrinking its `d_coef2`
  would alter the pool-reuse pattern the CL3 tests pin. Worth, if ever
  wanted: `rows * (nn - n - q) * 8` of `d_coef2` at the shapes that still
  run resident — i.e. only where it already fits.
- Visible requirement check: the compact route computes `pw` through one
  function that returns `Err` naming the shape when `n + q > nn` or
  `n + q` does not fit `int` (both already excluded upstream by
  `dev_commit_zk_from`'s `assert!(n + q <= nn)` and the CPU
  `encode_row_zk`'s assert; the re-check is what makes "no unsupported
  `n + q` path is silently used" a property of the route rather than of
  its callers). `rows * pw <= u32::MAX` is implied by `rows * nn` fitting
  today.

### 7.5 Capacities: LIVE and POOLED, before and after

`take_min` sizes that change — ONLY `d_coef2`, on the chunked commit AND
on the chunked opening (both routes take it again):

| shape (log_cols, rate, rows, q, chunk) | n | q | nn | rmax | `coef2` full = rmax·nn·8 | compact = rmax·(n+q)·8 | saved per buffer | of full |
|---|---|---|---|---|---|---|---|---|
| oracle (10,4,300,16,128) | 1024 | 16 | 4096 | 128 | 4,194,304 | 1,064,960 | 3,129,344 | 74.6% |
| oracle ELIGIBLE (12,4,300,16,128) | 4096 | 16 | 16384 | 128 | 16,777,216 | 4,210,688 | 12,566,528 | 74.9% |
| oracle (14,2,200,256,128) | 16384 | 256 | 32768 | 128 | 33,554,432 | 17,039,360 | 16,515,072 | 49.2% |
| oracle boundary (10,2,300,1024,128), n+q = nn | 1024 | 1024 | 2048 | 128 | 2,097,152 | 2,097,152 | 0 | 0% |
| oracle (14,8,130,64,128), log_nn 17 (last pruned width) | 16384 | 64 | 131072 | 128 | 134,217,728 | 16,842,752 | 117,374,976 | 87.5% |
| oracle (15,8,40,16,128), log_nn 18 (pruning declined) | 32768 | 16 | 262144 | 40 | 83,886,080 | 10,490,880 | 73,395,200 | 87.5% |
| 12x512 fixtures, A and H under P1 / P3 (q = 256, rate 4, log_n <= 14) | — | 256 | 4n | min(rows,128) | *filled in §7.9 from the diagnostic run* | | | |
| Mistral W (P3), rows 10,774 | 16384 | 256 | 65536 | 128 | 67,108,864 | 17,039,360 | 50,069,504 | 74.6% |
| Mistral A (3,601 rows), H (3,033 rows) | 16384 | 256 | 65536 | 128 | same | same | same | 74.6% |

LIVE peak of one chunked commit at the Mistral W shape, cold pool (the CL1
allocation-lifetime table's terms: data + pads + pows + coef + coef2 + enc
+ blake3 state + leaves + twiddles): **full 1,639,493,616 B = 1,563.5 MiB
→ compact 1,589,424,112 B = 1,515.8 MiB, −47.75 MiB (−3.1%)** (the CL1
table said 1,562.5 MiB for the same full path; the 1 MiB is the twiddles
it listed separately). The blake3 state is 50,593,792 B = 48.25 MiB. So
this is a TRAFFIC lever, not a capacity lever: the chunked peak is 86%
`d_data` and stays so.

POOLED, by `take_min`'s smallest-fit rule: after a commit the pool holds
coef (16 MiB), coef2 (64 → 16.25 MiB), enc (64 MiB), state (48.25 MiB).
The opening takes coef, coef2, enc in that order. Steady state (compact
after compact) every take is an exact-size reuse. In the TRANSITION from a
warm FULL pool ({16, 64, 64, 48.25} MiB) the compact `coef2` request
(16.25 MiB) is served by the smallest pooled buffer that fits — the 48.25
MiB STATE buffer, not a 64 MiB one — and the commit's own state take then
gets a 64 MiB buffer: oversize reuse, zero fresh allocation, unchanged
total capacity. On a COLD pool the compact route allocates 17,039,360 B
fresh for `coef2` instead of 67,108,864 B: that is the exact delta the
planner would report.

What `scripts/hashline_memory_plan.py` (read-only for this lane) would
need to model: one `compact_pad` flag (default off) that sets
`chunk_expanded = rmax * (n + q) * 8` for the `chunk_expanded` take on the
chunked and fallback modes; the resident rows unchanged; the opening's
re-take is already outside its component (stated in its assumptions). The
device counters are asserted against this formula in
`zk60_gpu_commit.rs` instead (§7.8).

### 7.6 Traffic — the HYPOTHESIS, per 128-row chunk at the Mistral shape (MiB moved)

| kernel | full | compact |
|---|---:|---:|
| inverse NTT (p1 + p2 on rc x n) | 64.0 | 64.0 |
| `k_zk_pad_scale` (read coef + pads + pows, write coef2) | 80.75 | 32.63 |
| `k_ntt_p1` (read coef2, write enc) | 128.0 | 80.25 |
| `k_ntt_p2` (commit, reference opening) | 128.0 | 128.0 |
| `k_hash_cols_stream` (commit) | 64.0 | 64.0 |
| `k_ntt_p2_gather_sp` (fused pruned opening, ~250/4096) | ~3.9 | ~3.9 |
| **commit chunk** | **464.8** | **368.9 (−20.6%)** |
| **fused pruned opening chunk** | **276.7** | **180.8 (−34.7%)** |

95.9 MiB saved per chunk: W's 85 chunks = 7.96 GiB per phase; W + A + H
(138 chunks) = 12.9 GiB per phase, commit and opening alike. (§5 above
said "~4 GB of the W opening's ~23 GB": that counted only the pad/scale
WRITE side; the `k_ntt_p1` READ side is the same again.) Whether bytes
become seconds depends on how bandwidth-bound these two kernels are:
`k_zk_pad_scale` is a streaming elementwise kernel; `k_ntt_p1`'s load is
a bit-reversed gather whose uncoalesced sectors are what the shorter
`n_src` removes. `k_ntt_p2` and the hash are untouched. So the phase gain
is bounded above by ~21% (commit) and ~35% (opening) and may be well
below; the whole-proof change is that fraction of ~1.2 s in a ~4 s prove.
**This stays a hypothesis until §7.10 measures it.**

### 7.7 Verdict

**SUPPORTS a compact path.** Both kernels already take the width as a
parameter (`k_zk_pad_scale`'s output stride; `k_ntt_p1`'s `n_src`, which
is stride and zero-extension bound at once), the tail is provably never
load-bearing (`gl_mul(0, x) == 0ULL`), and the change is confined to the
buffer size and two launch arguments on the three chunked routes. Build
it behind `HL_ZK_COMPACT_PAD=1` (default OFF; `set_zk_compact_pad_for_test`
for one-process A/B), leave the full-output form as the reference, bundle
no other kernel change.

### 7.8 Correctness [MEASURED, RTX 4070, 189 executed oracle cases; 8/8 frozen runs byte-identical]

Device oracle (`results/cl18_oracle.log`, marker 0, `HL_GPU_REQUIRED=1`):
**34 passed / 0 failed, `ZK60_CL4_SUMMARY executed_cases 189`** (CL15's
141 plus the compact cases: `compact_pad_width_is_n_plus_q_and_refuses_an_oversize_pad`
pins `zk_pad_width` — `nn` on the reference form, `n + q` on the compact
one, a refusal with the shape when `n + q > nn`; `compact_pad_scale_matches_the_cpu_on_and_off`
verifies leaves AND opened columns ON and OFF across the supported rates,
pad boundaries incl. `n + q = nn`, ragged chunks, duplicate queries, the
interleaved commitments and the fused/reference/pruned/dense routes;
`compact_pad_scale_takes_the_smaller_scratch_and_the_reference_route_the_full_one`
asserts the allocation probes: the compact route's `coef2` take is
`rmax * (n + q) * 8`, the reference route's `rmax * nn * 8`, exactly the
§7.5 formula). The plain-reencode negative control keeps detecting. This
count is suite version 3 of the floors manifest (v2 was 141).

Frozen gates (`results/cl18_frozen_gates.log`, marker 0; GPU binary
`9887a375f0a7dff4ecbae8c3852da147cdad09a451867ddd4702c60290a26856` /
5,333,616 B, built from `c02d86c` plus this task's working-tree diff — the
content committed as the CL18 commit — with `HL_ZK_CHUNK=1`, `--threads 2`,
each proof hashed and deleted, device idle-checked before every run):

| run | switch | sha256 | bytes | verdict |
|---|---|---|---:|---|
| v2 | OFF | `50cf7bdf..46a17d` | 66,844,928 | MATCH |
| v3 | OFF | `5f368db6..973c1d` | 70,758,084 | MATCH |
| zk | OFF | `021485e4..02282d` | 87,228,528 | MATCH |
| zkv3 | OFF | `40eb5479..4aac17` | 87,697,008 | MATCH |
| zk | **ON** | `021485e4..02282d` | 87,228,528 | MATCH — byte-preserving |
| zkv3 | **ON** | `40eb5479..4aac17` | 87,697,008 | MATCH — byte-preserving |
| zk diag | OFF / ON (`HL_GPU_VERBOSE=1`) | `021485e4..02282d` both | 87,228,528 | MATCH (diagnostics, not gates) |

### 7.9 The 12x512 hiding shapes, from the diagnostic run

Under `--zk --seed 1` with chunking forced the two hiding commitments per
layer are **rows 553 and 473, 2^14 -> 2^16, q 256** (5 and 4 chunks of
<= 128). The compact pad is **16,640 of 65,536** (n + q over nn: 25.4% of
the full width), so `coef2` per take is 128 x 16,640 x 8 = 17,039,360 B
instead of 128 x 65,536 x 8 = 67,108,864 B — the same 50,069,504 B saving
as the Mistral row of §7.5, because n, q and nn are identical (the fixture
and Mistral share log_cols 14, rate 4, q 256; only the row counts differ).
The diagnostic clocks at this tiny shape (commits 0.019-0.026 s ON vs
0.020-0.032 s OFF; re-encodes 0.011-0.013 s ON vs 0.013-0.016 s OFF) are
too short to rank and are recorded only for the shapes.

### 7.10 Measurement [MEASURED, WSL-BOX, RTX 4070, one Mistral layer, P3, ABAB x 2, two threads, single box, not quiesced]

`results/cl18_reenc_ab.sh` (the CL7 protocol with `--threads 2`; device
idle-checked before each run; `results/cl18_ab_{compact,reference}_r{1,2}.log`;
summary `results/cl18_ab_summary.{md,json}`), marker 0. The proof is
byte-identical ACROSS ARMS and equals CL7's frozen Mistral P3 digest
`190e85a1..` / 40,251,860 B in all four runs.

| arm | rep | commit W s | commit A s | commit H s | three commits s | re-enc W s | re-enc A s | re-enc H s | three re-encodes s | dev ntt s | PROVE s | proof_ready s | VRAM peak MB | proof |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| compact | 1 | 0.3278 | 0.1153 | 0.0962 | 0.5393 | 0.2361 | 0.0781 | 0.0661 | 0.3803 | 0.5390 | 4.1257 | 13.3014 | 5148 | `190e85a1..` / 40251860 B |
| compact | 2 | 0.3259 | 0.1138 | 0.0967 | 0.5364 | 0.2447 | 0.0783 | 0.0663 | 0.3893 | 0.5360 | 4.0517 | 12.7778 | 5148 | `190e85a1..` / 40251860 B |
| reference | 1 | 0.3871 | 0.1324 | 0.1097 | 0.6292 | 0.2891 | 0.0960 | 0.0809 | 0.4660 | 0.6290 | 4.3630 | 13.5495 | 5182 | `190e85a1..` / 40251860 B |
| reference | 2 | 0.3786 | 0.1303 | 0.1113 | 0.6202 | 0.2925 | 0.0916 | 0.0811 | 0.4652 | 0.6200 | 4.3295 | 12.9595 | 5182 | `190e85a1..` / 40251860 B |

byte-identical across arms: **True** (190e85a1d3be../40251860)

| quantity | reference | compact | change |
|---|---:|---:|---:|
| three chunked ZK commits (W/A/H) s | 0.6247 | 0.5378 | 1.162x |
| three chunked ZK re-encodes (W/A/H) s | 0.4656 | 0.3848 | 1.21x |
| changed phase total s | 1.0903 | 0.9226 | |
| PROVE s (HASHLINE_TIMING prove_s) | 4.3463 | 4.0887 | -0.2576 s |
| proof_ready_s | 13.2545 | 13.0396 | -0.2149 s |

Means over the reps per arm. The changed phase and the whole proof are reported separately; the traffic reduction remains a hypothesis until measured with a profiler; two-thread laptop diagnostic seconds, not a p95.


Read separately, as the contract asks: the CHANGED PHASE (the three chunked
commits + the three chunked re-encodes) goes 1.090 -> 0.923 s (**-0.168 s;
commits 1.16x, re-encodes 1.21x**), inside the §7.6 bound (<= 21% on the
commit chunk, <= 35% on the opening chunk, so the kernels are only partly
bandwidth-bound on this card); the WHOLE PROOF goes PROVE 4.346 -> 4.089 s
(**-0.258 s, 5.9%**) and proof_ready 13.25 -> 13.04 s (-0.21 s). VRAM peak
5,182 -> 5,148 MB (-34 MB: the smaller `coef2` on a cold pool, as §7.5
predicted — a traffic lever, not a capacity lever). Rep-to-rep spread is
0.03-0.07 s per arm, smaller than the arm difference, but n = 2 per arm on a
shared laptop is a diagnostic, not a p95. The traffic reduction itself
(§7.6's MiB) remains a hypothesis: it was not profiled, only its effect on
the clocks was measured.

### 7.11 What is and is not promoted

The switch stays **OFF by default**. This task authorizes a bounded
investigation, not a claimed speedup: the measured -0.258 s is one shape,
one card, two reps, two threads. Promotion (default ON) is the integrator's
decision after CL17-style gates at the new default; the reference form
stays behind `HL_ZK_COMPACT_PAD=0`. Nothing here changes security
parameters, repairs privacy, or runs a full model. The planner
(`scripts/hashline_memory_plan.py`, not this lane's file this round) does
not yet model the compact `chunk_expanded`; the device counters are pinned
in the oracle instead (§7.5, §7.8).
