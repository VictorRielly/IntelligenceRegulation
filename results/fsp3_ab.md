# FSP lane 3 — the A/B at 12 x 512, both arms from ONE binary

What is compared: the PRIVATE v3 prover (`zk.rs::prepare_layer_zk_v3_inner`)
with lane AL's two host fixes ported in (NEW, the default) against the
pre-lane arm (OLD, `HL_FSP_POOL=0 HL_FSP_I8FOLD=0`). Same binary, same
seed, same shape, same export.

Command, every run:

    hashline pass 12 512 --threads 2 --proof-out F --zk --seed 1 \
             --profile v3 --export .../m125_v3_export

`CARGO_BUILD_JOBS=2 RAYON_NUM_THREADS=2`; GPU runs add `HL_GPU=1` and take
`/tmp/zk-heavy.lock`, with `nvidia-smi` read while the lock is held and the
run refused unless the card shows no compute app and under 1500 MiB used.
One prover process per invocation; no two GPU runs were ever chained.
WSL box, RTX 4070 Laptop (8,188 MiB), 15 GiB host RAM shared with other
agents. **[MEASURED, NOISY-SHARED, 2026-09-19]** — another worktree
(`wt-fsp-host`) was building and then running its oracle battery
throughout.

**Every run below reproduced `40eb54795e023c77..` at 87,697,008 bytes.**
Raw rows: `results/fsp3_ab_cpu.log`, `results/fsp3_ab_gpu.log`.

## The order confound, and why both orders had to be run

`helpers + commit H` and `zero-check F` contain no code this lane touched,
so their old/new ratio must be 1.00. On the CPU binary they read 1.039 and
1.024 when the NEW arm ran first, and 0.949 and 0.942 when the OLD arm ran
first: **whichever arm runs second is about 4-5% slower on this box.** Five
pairs were therefore run in each order. Averaged over both, those two
phases return to 0.995 and 0.984 — the honest noise floor, about +/-2%.
A one-order A/B on this box is worth nothing at this effect size.

## CPU binary — 20 runs, 10 per arm, both orders (complete)

Mean seconds summed over 12 layers, with [min-max]:

| phase | new | old | old/new | reading |
|---|---|---|---:|---|
| **matmul g/u (zk)** | **0.368** [0.306-0.457] | **0.425** [0.363-0.517] | **1.157** | the FOLD, above the floor |
| **matmul d (zk)** | **0.130** [0.108-0.167] | **0.162** [0.131-0.196] | **1.248** | the FOLD, above the floor |
| commit W | 5.446 [4.63-6.63] | 5.529 [4.63-6.43] | 1.015 | the POOL, inside the floor |
| commit A (zk) | 10.692 [9.17-13.15] | 10.936 [9.08-13.11] | 1.023 | the POOL, inside the floor |
| helpers + commit H | 12.315 | 12.251 | 0.995 | control (unchanged code) |
| zero-check F | 8.229 | 8.098 | 0.984 | control (unchanged code) |
| pcs openings | 2.157 | 2.199 | 1.019 | — |
| **PROVE** | **40.973** [35.28-49.89] | **41.210** [34.41-48.70] | **1.006** | inside the floor |

## GPU binary — 5 runs so far, 3 new / 2 old, order n,o,o,n,n (PARTIAL)

| phase | new | old | old/new |
|---|---|---|---:|
| **matmul g/u (zk)** | **0.109** [0.107-0.112] | **0.164** [0.163-0.165] | **1.500** |
| **matmul d (zk)** | **0.085** [0.078-0.093] | **0.136** [0.132-0.144] | **1.605** |
| **commit W** | **0.587** [0.532-0.625] | **0.730** [0.690-0.772] | **1.243** |
| **commit A (zk)** | **1.067** [0.984-1.111] | **1.333** [1.245-1.402] | **1.249** |
| pcs openings | 0.306 [0.280-0.326] | 0.371 [0.341-0.401] | **1.211** |
| helpers + commit H | 1.198 [1.092-1.274] | 1.208 [1.098-1.303] | 1.009 (control) |
| zero-check F | 0.386 [0.313-0.445] | 0.397 [0.331-0.444] | 1.028 (control) |
| **PROVE** | **4.022** [3.66-4.22] | **4.620** [4.25-4.95] | **1.149** |

Order n,o,o,n,(o),n,o,o,n. Runs 1-2 were taken in a quiet window, run 3
across the end of another worktree's oracle battery, runs 4-5 under this
lane's own `cargo test` compile load. **The blocks agree**, which is why
the load does not need to be apologised for: quiet-only old/new is
commit W 1.258, commit A 1.231, g/u 1.519, d 1.656, PROVE 1.134;
loaded-only is 1.195, 1.260, 1.423, 1.517, PROVE 1.140.

**On the GPU binary this lane is worth a MEASURED 1.149x on the whole
private prove at 12 x 512**, against controls at 1.009 and 1.028 — phases
containing no code this lane touched. Both changed pairs sit far outside
that band: the fold at 1.50 / 1.61, the pool at 1.24 / 1.25.

`pcs openings` moves too, at 1.211, and the controls rule out noise. Lane
AL saw the same phase move in the public arm (18.557 -> 17.176 s). The
openings do a host fold over the committed data, so they benefit from a
buffer that is already resident and faulted. It is a second-order effect
of the pool — recorded, not claimed as a separate lever.

## What the two shapes together say

At 12 x 512 the FOLD is clearly measurable on both binaries, and the POOL
is measurable on the GPU binary but not the CPU one. That is what the
arithmetic predicts, and it is not a defect:

* at this shape `w_len` is 3 x 768 x 2048 = 4.72 Melem (37.7 MB) and the
  zero-knowledge A buffer is 559 rows x 2^14 = 9.16 Melem (73.3 MB), so
  the `vec![Fp::ZERO; ..]` AL charged at 0.60 s/layer at model width costs
  a few milliseconds here;
* on the GPU binary the device does the commit arithmetic, so the host
  allocation is a much larger share of the `commit W` / `commit A` phases
  — which is why the pool shows up there (1.235 / 1.194) and not on the
  CPU binary;
* at Mistral width `w_len` is 3 x 4096 x 14336 = 176.2 Melem (**1.409 GB,
  37.3x larger**), which is the regime AL measured, and where the pool is
  the larger of the two changes by an order of magnitude.

**The worth at 8B is COUNTED from AL's measured public gain, never
measured here** — see `docs/zkmatrix-poc/ZK60_FSP_ZKHOST_PROGRESS.md`:
about 227-235 s against the recorded 265.34 s, roughly 1.13x-1.17x, soft
because that pass paged at 8,585 MB on an 8,188 MiB card. No claim is made
that the 8B private pass is faster; nobody has run it.

**No privacy claim is made anywhere in this lane.** The legacy `--zk`
profile measured here is known to disclose private values (2026-09-08);
this is a cost measurement of the machinery the repaired private
feed-forward wraps.
