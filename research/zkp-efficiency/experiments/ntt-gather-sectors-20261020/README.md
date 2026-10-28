# Native fused NTT gather: small-size opportunity, large-size sector limit

Cycle 0101, run `20261020T091854Z-d57182bc`, accessed 2026-10-20 UTC.
**No proving speed improvement measured.** The experiment tests public
addresses and synthetic tile values, with no CUDA/native execution.

`N` below is the NTT transform length, **not model context length or tokens**.
The inspected `k_ntt_p1` already fuses bit reversal with its first DIT stages.
There is no standalone reorder pass to delete. For a fixed 4096-word tile,

`r = reverse_lb(q) * 2^lt + reverse_lt(blk)`,

where `lb=min(logN,12)` and `lt=logN-lb`. Thus the tile's source-word stride
is `2^lt`. At logN>=14, every active 8-byte scalar load in that tile occupies
a different 32-byte sector. Changing only which lane loads which tile value
cannot reduce the sum of per-warp source sector requests. This is a request
count limit, not a lower bound on cache misses, physical traffic or time.

A one-bit rotation of load ownership halves source sector requests in the
sampled dense aligned logN8/10/11/12/13 cases. It preserves all logical shared
indices and values, the row stride, zero-extension bound and output order.
Costs include integer index work and possible shared-store serialization.

Counts per sampled dense aligned 4096-word tile, row0, 512 threads:

| NTT length | Literal sector requests | One-bit rotation | Unique source sectors, either | Fixed16-lane shared bank address demand, literal/rotation |
|---|---:|---:|---:|---:|
| 4096 | 4096 | 2048 | 1024 | 1 / 2 |
| 8192 | 4096 | 2048 | 2048 | 1 / 2 |
| 16384 | 4096 | 4096 | 4096 | 1 / 2 |
| 1048576 | 4096 | 4096 | 4096 | 1 / 2 |

The last column counts distinct 32-bit shared words per bank in a *fixed*
16-lane issue-group model. Actual compiled instruction decomposition and
wavefronts are unknown. Whole-warp peak bank demand is2 in both literal and
one-bit modes; that alone cannot establish conflict freedom. Full reversed
ownership increases sampled whole-warp demand to32, fixed16 demand to16.
Two-bit rotation at N4096 reaches1024 requests but fixed16 demand4.
These address metrics do not imply any elapsed speedup. Unique sectors can
be reused across warps/CTAs; aggregate requests must never be called DRAM bytes.

The compact hiding source uses `n_src=n+q` as both physical row stride and
load bound. Synthetic compact/full-width values agree, including q>n and
ragged/misaligned controls. No pad generation, hiding algebra, randomness,
transformer witness or actual profile admission is established by that check.
At public n1024/q256/N8192, sampled tile0 reads640 words:640->320 sector
requests; n4096/q256/N32768 reads544:544->544. Larger transform stride still
limits coalescing. Existing DIF_PB and padded DIT paths are separate; at rb2
the PAD_SKIP path has more lane loads but the same256 sector requests as
the literal padded load in the sampled tile, due to broadcasts. No redundant
reorder is inferred there either. DIF_PA's coalescing also varies with J;
the extreme logN24/J1 sample is not fully coalesced.

Validation uses native-style 32-bit bitwise reversal and an independent
scalar bit-string/byte-interval reference. Final: **6,239 checks,21 geometries,
936 tile schedules,3,326,208 logical words,560 stride-identity checks**.
Nine deliberately wrong controls reject; one expected large-size null is
recorded separately in the ten-control file. Public transforms range2^5..2^24;
large domains sample at most three blocks, rows0/1/2,32/512 threads. This is
not exhaustive execution over the largest arrays. All tile elements are
checked in each sampled schedule. Bank reference samples first/last warps.

Source/artifact audit: **188 assertions,15 rejected source mutations,12
unchanged pins**, plus12 exhaustive-within-tile distinct-sector cases at
large strides. P1 address formulas agree in active GPU, frozen R9 and main.
The audit initially assumed the newer additive pad producer in all lanes;
main has the older branched producer. The failed assertion and correction
are preserved in `before-main-lane-scope-correction/`. Do not extend active/R9
q>n producer semantics to main. The address experiment itself never certified
the producer algebra. Initial whole-warp bank-only results are preserved in
`initial-full-warp-bank-model/`; the refined16-lane metric changes no addresses.

One CPU thread/core0/nice19, Intel Core Ultra9 185H, Python3.10.12/WSL2:
final probe9.725s,22,752KiB RSS; audit0.048s,18,040KiB RSS. Both leaf commands
have59s CPU/alarm,60s parent and512MiB address-space caps; estimated memory
64MiB. These are **Python checking clocks**, not NTT or proof clocks.

Reproduce from the research directory, using the retained source pins:

```
python3 experiments/ntt-gather-sectors-20261020/run_bounded.py probe.py
python3 experiments/ntt-gather-sectors-20261020/run_bounded.py validate.py
```

`commands.json` preserves both successful refinements and the failed initial
source-audit command. No downloaded code, installs, compiler or GPU job ran.

The first-load-only sketch is `p1_load_rotation.proposed.cuh` (uncompiled).
Same kernel signature, shared storage, barriers, butterflies and stores;
candidate guards only tested logN8..13. Do not integrate based on these counts.
The owner first needs actual route/logN incidence, ptxas/SASS and shared/global
metrics; then NTT forward/inverse/compact/chunked/coset and full seeded masked
transcript/next-challenge/PCS/receipt/refusal parity, strict GPU behavior,
independent complete verification and enclosing clocks. No original owner,
opening, fresh pad/salt/mask or refusal schedule may be changed.

Eliminated work: zero logical source bytes, capacity, proof arithmetic,
transforms, passes, barriers, masking or commitments; only some requested
sectors for small transforms. Added costs above remain unmeasured. If f is
the unknown complete-workload time fraction of affected loads, even deleting
all that work gives at most1/(1-f); the sketch is narrower and adds costs.
The broad large-size *sector-request* hypothesis is falsified at unchanged
tile ownership. Any native parity/refusal discrepancy or enclosing regression
rejects the small-size candidate. No numeric full-stack GPU ceiling is known.

Six LIVE primary records in `source-records.json`: NVIDIA's
[coalescing/bank guide](https://docs.nvidia.com/cuda/cuda-c-best-practices-guide/index.html),
the author's dated [ICICLE issue](https://github.com/ingonyama-zk/icicle/issues/1046),
[SP1v6.9.0](https://github.com/succinctlabs/sp1/releases/tag/v6.9.0),
[GNTT](https://arxiv.org/abs/2502.11110),
[October14 placement study](https://arxiv.org/abs/2610.20354), and the prior
[NTT-TensorCore screen](https://github.com/MMRROOO/ntt-tensorcore).
Dates, commit/license scope and blocked fetches are recorded exactly; no
author performance was reproduced. The older GNTT4 float64 path fails a local
native-field cast control: legal p-2 rounds to p-1 before multiplication.
This rejects a direct unlimbed port; it does not reject every exact matrix
decomposition. No upstream implementation was executed.

New completed independently verified full-stack proofs/passes/positions:0/0/0.
Actual model context/device:none. Witness/proof/serialization/verification
clocks, startup duration/fraction, steady and total rates:unmeasured. No
long-context prefill, resident-model pass or decode ran. Carried CPU baseline
is not a new proof:8B T128/L32,one16-thread pass,GPU off,total478.737s =
0.267370positions/s; prove_run393.785s includes witness98.348/load17.595;
seal84.824 overlaps accounting; receipt922,711,264B; fresh verify42.709+
load13.681s, recheck34.395+load10.739s. Startup/steady slope/serialization
remain unknown. Complete private8B >=50/s on5090/another named high-end GPU
remains unachieved; longer contexts can add quadratic attention. No privacy
acceptance, P3 completion or reused masking follows from this experiment.

Next local: public shape-only census of the actual private-block PCS log_cols,
q_pad and expanded logN to decide which accepted source profiles can even use
the small-size sketch; preserve P-3's Tab/log_cols invariant. Next owner:
actual exclusive/enclosing phase measurements and verified resident1/2/4/8
complete passes; affine FZC compiler A/B remains ahead of this request model.
