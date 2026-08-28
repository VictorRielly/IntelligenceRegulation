# U-PERF3 lane II — the sqrt front end after the S4 verdict: what a redesign must count before any spike

Status 2026-08-28: design memo, no code. Companion to
U_PERF3_HEADLINE_ROUTES.md §4.2 (the S4 spec), the FF ledger status
(the spike's rungs), and results/bench2{2,3}_{1,7}t*.log in
wt-uperf3-ff (the measured verdict). Victor's ruling 2026-08-28: run
the Stage-A integration (lane GG) AND this redesign in parallel.

## 0. One paragraph

Spike S4 built the two-tier (sqrt/Greyhound-shape) front end and
proved the part that cannot be negotiated: the served claims equal
the built opening's BIT-FOR-BIT, and the 8B two-tier planner gate is
green. It then failed both speed criteria — 1.08-1.10x
prove-group-equivalent at 1T (required >= 5x), verifier 3.9-4.7 s
(required sub-second level-0). The measured anatomy says the failure
is CONCENTRATED, not diffuse: at 2^22/1T the core is 25.44 s of
which the v-passes are 20.01 s (79%) — and the spike's v-pass
computes general ring products in exactly the structural position
where the built pass's O5 kernel-pass factoring measured 42-51x.
The recursion input (the u-digit domination flagged at rung 1) turns
out to cost little wall directly (proxy recursion 1.73 s) but drives
the BYTES (14.9 MB clear u) and the verifier's u-rebind (1.65 s).
This memo lays out three redesign moves — R1 factor the v-pass, R2
recurse the u/v serving, R3 fold the u-digits into the lane-EE
aggregate — counts each against the measured baseline, and states
the paper bar a composed design must clear before any spike S5.

## 1. The measured anatomy (bench22_1t_v2, 2^22 synth, 6 tensors / 7 contribs, G_all 2626, [WSL-BOX 1T|NOISY-SHARED])

| phase | s | share of core | kills criterion |
|---|---|---|---|
| rows | 1.45 | 6% | — |
| v-passes (QR + per-contrib light half) | **20.01** | **79%** | 2 (prove) |
| fold | 2.25 | 9% | — |
| proxy recursion prove (+precommit) | 1.73 (+0.44) | 7% | — |
| tier1+tier2 commit (excluded from core) | 14.59 | — | 2 (with-commit) |
| baseline: bg_prove_group / bg_precommit | 27.91 / 7.10 | | |

Verifier 3.93 s total: replay+range 0.32, **u-rebind 1.65**, binding
0.19, **consistency 1.17**, claim 0.60 — criterion 3 dies on the
u-proportional terms. Bytes 45.3 MB spike-clear, of which u 14.9 MB
+ v 26.2 MB (the clear planes) vs built 179 KB.

The u-digit finding (rung 1): the memo's recursion-input model
counted ~19K w-only rings; the real tier-2 input is 1.65M rings at
the 8B weight sqrt (u-digit-dominated). At the spike shape this
costs recursion WALL very little — its damage is bytes + verifier.

## 2. The redesign moves

### R1 — factor the v-pass (the T5/O5 precedent)

The spike's `tt_qr_pass` computes QR[row][d] = sum_cb conjQ[cb][d]
(x) Fl[row nb + cb]: rows x nb x 16 GENERAL ring products per tensor
(NTT-batched via mul_modq_small_many; shared per (tensor, col
kernel) by Rc-cache, so the sharing that exists is coarse-grained).
This is the same structural position as the pre-T5 claim-kernel
passes — per value ring, a 16-wide family of ring products against a
kernel-derived operand — which the O5 factoring (hoist sr_c,
precompute G_c[cb][d1] per column kernel, reduce to scalar x ring
MACs with u128 lazy accumulation) took to **42.6x / 51.5x measured**
[WSL 1T, kpass-bench 512x2048; TASK_BOARD T5 record]. WHAT MUST
HOLD for the same move here: conjQ[cb][d] must carry the col-kernel
rank structure (it is built from the tier-1 column commitments over
the SAME kernel family the claim layer factors — the AggTensor's
kernels), so that the d-sum factors through a per-(kernel, cb)
precompute exactly as G_c did. THE CHECK IS A COUNTING RUNG, NOT A
SPIKE: enumerate conjQ's construction (two_tier.rs tt_conjq) against
the O5 derivation's preconditions (cols % 128, kernel product form)
and count the MACs after factoring. IF it holds [the O5 precedent
makes this likely but NOT automatic — the memo flags it as CHECK
C-R1]: v-passes 20.01 s -> ~0.5-1.5 s class [MODEL from the T5
ratios at comparable operand counts]. Core 25.44 -> ~7 s, ratio
~4x. R1 alone nearly clears criterion 2's bar and is useless for
criteria 3's u-terms — hence R2/R3.

### R2 — recurse the u/v serving (kill the clear planes)

The spike serves u (14.9 MB) and v (26.2 MB) CLEAR; the production
form was always meant to recurse them (the bench prints the
V-recursed planner row: at 2^20, 21596 rings -> 6 levels, floor 948
e7 — the recursion GROWS modestly vs V-clear 10010 rings, both
floors ~equal). Counted effects: bytes 45.3 MB -> the recursion
block class (~175 KB) + the tier commitments; the verifier's
u-rebind 1.65 s DIES (replaced by recursion verify, measured 0.36 s
at the spike shape); prove gains the second recursion's cost
(~2x the 1.73 s proxy [MODEL]). Net: criterion 3's biggest term
gone, bytes to built-class, prove roughly neutral.

### R3 — the u-digits into the lane-EE aggregate

The tier-2 u-digits are committed digit planes with range facts —
EXACTLY the object lane EE's aggregate zero-check batches (13.3x
rounds, MAC-neutral, O-4-masked, 136-leg battery). Folding the
u-digit range facts into the aggregate is free structure. The
FURTHER step — serving the u EVALUATION claims through the
aggregate's final claims instead of a separate recursion — would
remove the second recursion entirely, but requires the aggregate's
fold point to coincide with (or be soundly linkable to) the
opening's batched point: OPEN SOUNDNESS QUESTION O-R3, to be
answered on paper (the design memo §2.6 lemma set) before it is
counted as a win. The memo counts R3 conservatively as: range facts
ride the aggregate (small round savings), claim serving stays with
R2's recursion.

### R4 — tier geometry (rejected briefly)

Resizing tiers moves work between the commit and the recursion but
does not touch the v-pass structure (the dominant term) and cannot
fix criterion 3's u-terms better than R2 does. Not pursued.

## 3. The composed count vs the bar [MODEL where marked]

| variant | prove core (s, 2^22 1T) | ratio vs 27.91 | verifier | bytes |
|---|---|---|---|---|
| S4 as measured | 25.44 | 1.10x | 3.93 s | 45.3 MB |
| + R1 (IF C-R1 holds) | ~7 [MODEL] | ~4.0x | 3.93 s | 45.3 MB |
| + R1 + R2 | ~9 [MODEL, +recursion] | ~3.1x | ~1.0-1.5 s [MODEL] | ~0.4 MB |
| + R1 + R2 + R3(range) | ~8.5 [MODEL] | ~3.3x | ~0.9-1.3 s [MODEL] | ~0.4 MB |

Honest reading: even with every move landing, the COUNTED composed
ratio sits at ~3-4x, BELOW the 5x bar, and the verifier hovers at
~1 s rather than clearly under. The 5x bar was set for the
HEADLINE (5-15 s at 8B); a 3-4x front end with built-class bytes
and ~1 s verify is still a MATERIAL win over the built opening —
but it funds the ~20-40 s/board tier of the routes memo, not the
5-15 s tier, UNLESS C-R1 lands at the top of the T5 range AND O-R3
resolves favorably (both together: ~5-6x, verifier ~0.6-0.9 s
[MODEL]).

## 4. The bar, and spike S5 if it clears

Before ANY spike: (1) CHECK C-R1 — the conjQ factorability count
(a half-day counting rung against two_tier.rs + the O5 derivation;
its output is a MAC count, not an opinion); (2) O-R3 on paper.
IF the re-counted table shows >= 5x prove-equivalent AND < 1 s
verifier at 2^22: spike S5 = R1+R2(+R3) on the FF rig, same four
acceptance criteria as S4, same differential legs, 2-3 days.
IF NOT: the redesign is recorded as "3-4x class, funds route-3
tier", the headline stays with the fallback posture, and this memo
is the closing document of the 5-15 s question on this line.

## 5. Not counted here (honesty)

The 8T scaling of a factored v-pass (T5's factored passes threaded
at 3.5-11x — the 8T ratio should improve more than 1T); the commit
14.59 s under R2's changed commitment set (tier-2 commits shrink,
tier-1 unchanged — needs the planner's exact object list); the 8B
extrapolation (only the 2^22/2^23 spike shapes are measured; the 8B
group is 84x the rings of 2^22); interaction with lane GG's
integrated Stage A (the aggregate the u-digits would join is GG's
production instance, not EE's synthetic).
