# Research handoff: can the seven weight-matmul slots be one batched sumcheck, given how their totals reach the hosts (2026-11-26, claude tick 65)

From Claude, the background researcher (D50). Queue item 108 (added by tick 63; hypothesis H170). Clock at writing 2026-11-26T11:51Z.

**Scope.** Local reading and arithmetic only: 0 searches, 0 fetches. No build, run or Git. Written: this file and `20261126-claude-tick65-batched-matmul-hosted.py` / `.out.txt`. Read (tree that runs, `ops/zkp-mvp/gpu-metal/hashline/src/private_block`): `slot_ir.rs:194-207, 1215-1333, 1334-1417` (hosted terms of the D, F, Q and KV slots); `argument.rs:1845-1895, 2019-2036, 2249-2320, 3218-3258, 3367-3400, 3401-3451` (the slot driver, the claimed sums, the matmul slot definitions, the D slot's `hosted`); `layout.rs:982-990, 1040-1115, 1625-1660` (slot numbers, kinds, `HOSTS`, the layout tests); `shape.rs:2597-2714` (claim sites, slot schedule); `zkp-core/src/sumcheck.rs:190-260` (`CfsMask`). **Triage material, not a work order:** any merge changes the schedule, the transcript, the verifier and the Lean statements; it needs the owner's ruling, a new profile and re-proving (D63). P3 stays at study level (D82). Labels: COUNTED (file:line), DERIVED (script), ASSUMED, NOT VERIFIED.

## 0. Headline

- **The hosted totals can be separated, so the "fail" line of the item does not fire.** Today a matmul slot is a `SlotKind::Private` slot that publishes ONE masked scalar `s + c G` ("its total appears only inside its host's Gamma", `layout.rs:1069-1070`). The host slot's claimed sum is that scalar times the host's own `nu`: verifier `claimed = sp.scalar + sum coef * acc.scalars[hs]` (`argument.rs:2255`); prover `scalar = c*mask.total - sum coef * acc.cs[hs] * masks[hs].total` (`argument.rs:2034`). Each hosted term reads its own scalar (`acc.scalars[hs]`) and sits at its own point (`pts.pq, pk, pv, p_a, p_g, p_u, p_z`, set at `argument.rs:3253-3257, 3394-3398`; the host reads them as `b.eq(&pts.p_a, 0)` etc., `argument.rs:3408-3409`, `slot_ir.rs:1275-1277, 1344-1345`). Nothing in that mechanism depends on the seven scalars coming from seven separate sumchecks. So a batched matmul slot must **publish seven scalars (one per hosted instance), not one batched total**.
- **But the batch weights cannot be the hosts' `nu`.** A host draws `nu` inside its own definition (`argument.rs:3405`, `slot_ir.rs:1272-1273`, `:1340-1341`), after the slots it hosts have run (every hosted private slot has a lower index than its host, asserted at `layout.rs:1642-1652`: QMM 5, SCORE 8, PV 9, WO 10, DMM 13, hosts 14 and up). So the batched slot needs its own `lambda`, drawn after the seven scalars are absorbed. This is the first transcript change.
- **The four pairs are NOT batched together today.** `HOSTS` (`layout.rs:1107-1114`) pairs (Wo, Dmm) in the D slot, (Qmm, PV) in the Q slot, (Kmm, Vmm) in the KV slot, (Gmm, Umm) in the F slot. The pairing is a batching of two CLAIMS inside the host's zero-check by `nu[0], nu[1]` (each with its own `eq(p)` wrapper, e.g. `slot_ir.rs:1263-1265`). The matmul sumchecks themselves are seven separate slots, each with its own `c`, mask and extension round. Note PV is not a weight matmul (it is the bilinear attention slot, no weight claim), so the Q and PV pair mixes a weight matmul with one that is not.
- **What stays per instance if the merge is built (the finding that sets the price):** the seven `c_k` and seven masks `g_k`. The host cross-term needs `acc.cs[hs]` and `masks[hs].total()` per hosted slot (`argument.rs:2034, 2304-2305`), and a test pins that every private slot is hosted exactly once (`layout.rs:1648-1652`). A merged slot that published only a combined masked total could not feed the hosts. So the M block (`M_ROWS = 2 * N_SLOTS + 4`, `layout.rs:1125`; 50 at the toy) does not shrink by merging; only the number of eval functionals does (section 2).

## 1. Counts (DERIVED, script)

8B padded axes: inner bits Q, K, V, G, U, Wo = 12, Wd = 14.

| | today (7 slots) | four groups {QKV}, {Wo}, {GU}, {Wd} | one batch |
|---|---:|---:|---:|
| round messages a block (main + 1 extension each) | 93 | 54 | 15 |
| upper bound on their bytes a block (ASSUMED 3 Fp2 of 16 B a round) | 4,464 B | 2,592 B | 720 B |
| A terminals a block (distinct plane and point) | 7 | 4 | 4 |

The round-byte saving is at most 3,744 B a block, 0.015% of a 25.59 MB block receipt. **The merge is not a size lever on the sumcheck; its value is the weight-opening bytes of tick 63 (209.7 MB at 8B for seven groups against one), and only under a P3 profile that does not exist.**

## 2. The named change lists

**A. Partial merge {QKV}, {Wo}, {GU}, {Wd} (four groups, 324.7 MB at 8B dense by tick 63).**
Only the three Q, K, V and the two G, U can merge without moving which planes are read together: Q, K, V all read `A_Y` at `(r_q, rho)` over the same 12-bit inner axis (`argument.rs:3231-3233`), G and U read `A_YM` at `(r_tf, rho)` (`:3375-3376`). Wo redraws `r_q` for itself (`argument.rs:3219-3221` draws it for Wo as well as Q) and reads `A_O8`; Wd draws its own `r_td` and reads `A_H16` over 14 bits. So Wo and Wd stay alone.
1. Schedule (`shape.rs:2660-2714`, `layout.rs:1041-1066`): replace slots QMM, KMM, VMM by one slot and GMM, UMM by one; `slots()`, `slot_terms()`, `claim_sites()` (`shape.rs:2607-2609`: 1 A site per matmul slot, would be 1 per merged slot, 3 fewer than 7 to 4; the effect on A rows of 3 reserved mask pairs was not computed), `SLOT_KINDS`, `HOSTS` (the lists `[QMM, PV]` and `[KMM, VMM]` become one merged slot hosted by two hosts; `HOSTS` and its test assume one host per private slot, so the test and the `hosted` vectors need a different shape), `N_SLOTS`, `N_FUNCTIONALS`.
2. Transcript: absorb the instance scalars, then draw `lambda`, then the batched rounds, one extension round. The `(kind == Host) == hosted.is_empty()` check (`argument.rs:1855`) and `run_slot_with`'s one scalar per slot (`:2036`, `:2254`) change to several scalars. The shared 12 inner challenges `rho` and one `es` serve the group.
3. Hosted terms: each host's `hosted` list still names one instance per term, each with its own scalar and `eq(p)` (no change in the zero-check polynomials of `slot_ir.rs`; the IR terms read the point, not the slot that produced it). The host's claimed sum formula stays the same with scalars indexed by instance, not slot.
4. M side: the eval functional `(s, eval_weights(rho_full))` (`argument.rs:2311`) becomes one multi-term functional `sum_k lambda_k c_k g_k(rho)` for the group, from the existing multi-term `MaskFunctional` (as used by hosts, `:2302-2307`); the host functionals stay per instance. `N_FUNCTIONALS` falls by 2 + 1 = 3 (QKV 3 to 1, GU 2 to 1); `M_ROWS` is unchanged because the masks stay per instance. Whether the verifier can still derive `g_val` for a combined functional is stated by `g_val = (fin - poly(vals)) / c` today (`:2275`); with a batch it is the combined `sum lambda_k c_k g_k(rho)`, which the final check gives. NOT verified that the M opening accepts it without a layout change.
5. The weight claims (P3 only) go to one tail `(r_lo, rho)` per group, as in tick 63 section 3.

**B. Full merge (one batched slot, 14 rounds, tick 63's 219.9 MB at 8B).** Everything in A, plus:
6. Heterogeneous instances: Wd has 14 inner bits, the six others 12. A shorter instance must take dummy rounds; with trailing dummy rounds its claimed total is scaled by 2^(14-12) = 4 (script), so each instance's published scalar and the host's use of it carry a power of two, a public constant that must enter `slot_ir.rs`'s hosted terms or the verifier's claimed sum.
7. Different row points: `A_Y` at `r_q` (Q, K, V), `A_O8` at Wo's own `r_q`, `A_YM` at `r_tf` (G, U), `A_H16` at `r_td` (Wd): four distinct (plane, point) pairs, so four A terminals (script), not one; the batch's terminal check is a sum of four products with different public tables.
8. Merged A sites: 7 sites to 4 (as above). The 14-round mask: `CfsMask` has `n_vars = n + ext` and degree per instance (`sumcheck.rs:194-260`); each instance keeps its own `(n_k + 1, 2)` mask, so the batched round message hides `sum lambda_k c_k g_k` with the shorter masks padded by the same dummy rounds (NOT verified: that padding does not change the mask's `sum_weights`, which uses `2^(n-1)` per coefficient, `sumcheck.rs:227-233`).
9. The common low 4-coordinate output point of tick 63 is not constrained by the hosts: a host's `eq(p)` wrapper takes any point (`slot_ir.rs:1275-1277`), and the smallest output axis is 10 bits (K, V), so four shared bits fit. Each `r_j` stays marginally uniform; a Lean statement for the union bound over seven correlated draws is still needed (tick 63).

**C. What both lists share (the profile-level changes):** new slot schedule and `SLOTS` constants (`layout.rs:1041`), new transcript order, new verifier driver, new `HOSTS` shape, a new profile version, re-proving, and the D63 Lean statements (T1a/T1b extractor claim list, T2 simulator). Under P1 (public weights) none of this applies, since the weight terms are verifier-folded public tables.

## 3. Effect

- **Committed words:** none changed. **Proved tokens per second:** none at P1. The sumcheck rounds saved (78 of 93 a block in the full merge) are host and table-build time of the nine matmul slots, which tick 24 counted at 63 ms of wall time (1.7% of a prove call) and tick 20 at 12 to 15 ms a block, so a merge is worth at most a fraction of that and is not a speed item; it was not timed.
- **Receipt bytes, P3 only:** the saving is tick 63's weight-group bytes: 324.7 MB (four groups) and 219.9 MB (one) against 429.6 MB (seven groups), dense layout at 8B.

## 4. Falsifiable tests (not run)

- **T-B1 (the hosted separation, Rust, no GPU).** At a toy shape, run the four-group schedule as a merged slot that publishes three scalars for {QKV}; keep the Q and KV hosts unchanged except that the `hosted` entries index instances. Pass: the honest prover verifies, a tampered scalar of any one instance is refused (probability 1 - 1/|F|), and the host's claimed sum equals the unmerged run's. Fail: the host's claimed sum or the M functionals need the instances' masks to be one polynomial, then the merge needs a mask redesign.
- **T-B2 (the dummy-round scale).** For Wd with 14 rounds beside 12-round instances, check by a field-level toy that the 2^2 factor reproduces each instance's total. Pass: all seven scalars recovered.
- **T-B3 (the M opening).** Verify that a combined `sum lambda_k c_k g_k(rho)` functional is accepted by the M message check at `L + 256 <= 512` (`layout.rs:1653-1660`). Pass: accepted without growing `M_ROWS`.

## 5. Risks and what was not verified

- Read, not run. The IR terms of `slot_ir.rs` were read for the D, F, Q and KV hosts only; the S and T hosts (RS, SCORE, SS, SSM) were not, and they are not weight matmuls.
- The wire bytes of a round message are ASSUMED; the sumcheck proof encoding was not read.
- `build_claim` and `claim_point` (`argument.rs:2292`) were not read; the claim that a merged slot's terminal for `A_Y` at a shared point is one claim, not three, rests on the plane and point being equal and was not run through `acc.claims` grouping. If the layout keeps one reserved site per instance regardless, the A terminals stay 7.
- No P3 weight claim exists in the code; the weight-side claims are inferred (as in tick 63).
- Soundness of the correlated `r_lo` draw and of `lambda` being drawn after the scalars is standard batching, not formalised here.

## 6. Status

Proofs / passes / positions: 0 / 0 / 0. Complete private 8B at the target: unachieved. Hypotheses: H170 refined (the hosted totals separate; the merge keeps seven `c_k` and masks; four-group list A is the smaller change; tests T-B1 to T-B3 not scheduled).

## Coordinator's check (2026-11-26)

The script was re-run by the co-coordinator with the heavy lock free: the output is identical. Read by me in the code that runs: `argument.rs:2034` and `:2255` (the host's claimed sum takes each hosted slot's own scalar), `:2300-2312` (the mask functionals), `:3218-3258` and `:3367-3400` (the seven matmul slots: planes, row points, published points), `:3401-3409` (a host draws `nu` inside its own definition); `layout.rs:982-999, 1067-1070, 1106-1125, 1638-1652`; `shape.rs:2683-2693, 2705`. Each line cited for the headline says what the handoff says. **Carried forward:** the reading that the seven totals reach their hosts as seven separate scalars, the three round counts, and the conclusion that a merge is not a size lever while weights are public. **Not carried:** the timing remark of section 3 (the figures of ticks 20 and 24 were not re-read); the percentages as more than an order of magnitude, because the message size is assumed and 25.59 MB is the 8B receipt divided by 32, a mean that includes the parts outside the blocks; and the inference that the mask block keeps its size, which is reasoned from `:2034` and `:2304-2305` and not checked by a build. The 8B padded axes are the script's inputs, taken from tick 63; the rule that maps them to rounds was read (`shape.rs:2683-2693`). Sections 2 and 4 are a paper change list and tests that were not run.
