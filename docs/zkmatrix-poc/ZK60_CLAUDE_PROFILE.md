# CL5 — where the post-CL1 GPU time actually goes

Task: `zk60_claude_tasks.json` CL5. Tool: `scripts/hashline_cl_profile.py`
(10 tests). Matrix: `results/cl5_profile_matrix.sh`, log
`results/cl5_matrix.log`, marker 0.

**Diagnostic, not a headline.** Safe 125M shapes (12 x 512, d 768 / f 2048),
three repeats per configuration, under the shared heavy lock, on the 8 GB
laptop. The box is **not quiesced-certified**, so no p95 is produced and none
of these seconds may be published as a target number. `gpu: ON` and zero CPU
fallbacks were confirmed on every run.

The parser creates no new clock: it reads `HASHLINE_TIMING`, the
`prover phases` block and the `gpu device-side` counters that the prover
already emits, and refuses a log that lacks the machine-readable line.

---

## 1. The matrix [MEASURED, WSL-BOX, RTX 4070, n=3, median]

| config | mode | prove s | proof-ready s | proof bytes | VRAM | spread |
|---|---|---:|---:|---:|---:|---:|
| p0 | P0 | **2.235** | 3.950 | 70,758,084 | 2,430 MB | 0.9% |
| p1 no cache | P1 | 5.377 | 7.250 | 87,697,008 | 3,068 MB | 2.9% |
| p1 warm cache | P1 | 5.436 | 7.305 | 87,697,008 | 3,068 MB | 2.5% |
| p1 cold cache | P1 | 5.476 | 7.346 | 87,697,008 | 3,068 MB | 4.3% |
| p3 | P3 | **5.824** | 7.701 | 88,189,680 | 3,235 MB | **14.9%** |

**ZK is the expensive step, not privacy of the weights.** P0 -> P1 is
2.235 -> 5.476 s = **2.45x**. P1 -> P3 is 5.476 -> 5.824 = **+6.4%**, and P3's
own spread is 14.9%, so at this width that difference is barely outside noise.
Bytes: P1 -> P3 is +492,672 B = **+0.56%**.

**P3's spread is the outlier and is worth watching**: 14.9% against 0.9-4.3%
everywhere else. Three runs cannot say why; it is recorded as an observation,
not diagnosed.

---

## 2. THE PUBLIC WEIGHT CACHE IS NOT PAYING, AND THE REASON IS STRUCTURAL

Cold, warm and *absent* are indistinguishable above. That is not because the
cache misses — it hits. With `HL_WCACHE_VERBOSE=1`:

```
MISS -> wrote v3-l00-....wc (4.2 MB, commit 0.087 s, write 0.002 s)
HIT     v3-l00-....wc (rows 288, 4.2 MB, load+verify 0.008 s, re-encode 0.088 s)
```

**A HIT still RE-ENCODES.** `wcache::commit_w` stores the Merkle tree and, on a
hit, calls `reencode_store` to rebuild the encoded store from the data. So the
cache saves the *hashing*, never the *encoding* — and the encoding is the
expensive half. Per layer at this width: a miss costs ~0.031 s of commit, a
hit ~0.019 s of re-encode, so the saving is ~0.012 s x 12 layers = ~0.14 s of
a 5.4 s prove, i.e. **~2.6% at best, inside the run-to-run spread.**

This is a description of existing behaviour, not a regression: the cache was
built to avoid re-committing, and it does. It is simply worth far less than
its name suggests, and **a plan that assumes warm-cache proofs are materially
cheaper is assuming something these numbers do not support.**

Whether it pays better at Mistral width is not answered here; `commit W` is a
larger share there, but the re-encode scales with it too.

---

## 3. The top three exclusive costs [P1, the fast tier]

Against the proof-ready clock of 7.346 s:

| # | phase | exclusive s | share of proof-ready | bounded gain if removed ENTIRELY |
|---|---|---:|---:|---:|
| 1 | commit A (zk) | 1.390 | 18.9% | 1.23x |
| 2 | helpers + commit H (zk) | 1.312 | 17.9% | 1.22x |
| 3 | commit W | 0.795 | 10.8% | 1.12x |

**These bounds are independent and MUST NOT be multiplied.** Removing all
three entirely would be 7.346 -> 3.849 = 1.91x, not 1.23 x 1.22 x 1.12 = 1.68x
— and neither number is achievable, because "removed entirely" is not a thing
any change does. The tool emits this warning with every ranking.

The eleven named phases sum to within **0.589 ms** of the prove clock, so the
decomposition is exhaustive and there is no hidden pool of prove time to
attack. Outside the prove clock, witness load+chain is 1.74 s (23.7% of
proof-ready) and serialization 0.116 s (1.6%).

---

## 4. The optimisation order this profile actually supports

1. **The three commitments dominate: A, H and W together are 47.6% of
   proof-ready.** They share one mechanism — commit, encode, hash, open — so
   work there is the only thing with real leverage, and it is where CL6/CL7
   should look. AO's L9 work already improved the encode; this says the
   *commitments* are now the shape to attack, not the openings (`pcs openings`
   is 0.551 s, 7.5%).
2. **Witness load+chain at 23.7% is the second-largest single item** and is
   host work outside the prove clock entirely. It has never been owned by a
   lane.
3. **The weight cache is not an optimisation target — it is already spent.**
   Making it hit more often cannot buy more than the ~2.6% above; making a hit
   skip the re-encode would be a real change and belongs to whoever owns
   `wcache.rs` (not this lane).

**What this profile does NOT support:** any 8B projection. These are 125M
shapes; the phase mix at Mistral width is different (CL1 rung 5 measured
`commit W` at ~44% of the prove there, against 10.8% here). Old FFN-only or
lattice projections are not carried forward, per CL5's own instruction.
