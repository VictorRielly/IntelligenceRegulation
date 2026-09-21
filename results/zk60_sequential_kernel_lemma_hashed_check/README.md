# Evidence for `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED_CHECK.md`

The **independent adversarial checker's** own machine checks of the memo
`docs/zkmatrix-poc/ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md`. Written by the
checker, not by the memo's author; nothing here was reused from the memo's
own evidence directory (`results/zk60_sequential_kernel_lemma_hashed/`).

Exact rational arithmetic (`fractions.Fraction`), standard library only,
fixed seeds. Nothing here touches the ZK60 prover, replays no receipt, and
establishes no privacy property of any artifact.

```
python3 /home/victor/IntelligenceRegulation/results/zk60_sequential_kernel_lemma_hashed_check/adversarial_kernel_check.py
```

Runtime about 80 s, single core, no heavy lock. Writes `checks.json` and
`checks.log` beside the script.

## Why these checks and not the memo's

**Every protocol in the memo's own evidence has exactly ONE challenge
round.** `rounds = len(rules) - 1 = 1` for C1, C2, C3, C4, C5, C6 and C7
(C8 has no rounds at all). For a page whose subject is the *sequential*
composition of a multi-round Fiat–Shamir protocol, the induction is never
exercised. These checks do the multi-round work, add early aborts, and
attack each hypothesis in turn rather than confirming the ones the memo
picked.

| check | what it attacks | result |
|---|---|---|
| **A1/A3** | the path identity (★) and Theorem S-H at **2 and 3** challenge rounds, 4,101 schedules each (exhaustive where possible, else sampled with fixed seed, plus named adversarial ones: constant, hash-part-only, field-bit, round-parity), every completion of a truncated `rho` | 0 mismatches; per-`rho` TV 0 ⟺ adaptive TV 0. **The lemma survives.** |
| **A2** | the identity with an early abort, Game-`perp` and Game-prefix views | 0 mismatches, both games inherit the conclusion |
| **B1** | is hypothesis **(i) causality** needed? A prover that reads the challenge following its own message (fixed-point semantics) | per-`rho` TV **0**, adaptive TV **1/2** — **(i) is NECESSARY** (the memo never tests it) |
| **B2** | is hypothesis **(ii) witness fixed before `m_0`** needed? Two ADAPTIVE witness sources (the stage-1 secret chosen after `r_0`) | per-`rho` TV 0 and adaptive TV **0** — **(ii) is NOT needed for the conclusion.** It is a well-posedness condition; GAP S-4 is a gap in (iv), not in (ii) |
| **B3** | is hypothesis **(iii)** all-or-nothing? The memo's C7 only tests a *total* coincidence of one query point | leaking **one bit** of `omega` into the challenge source already gives adaptive TV **1** at `\|C\|=4` while (iv) holds at every `rho`. (iii) cannot be "priced" like a bad event |
| **B4** | hypothesis (iv), marginals-only | fails, as project lore says |
| **B5** | the hypothesis the memo does **not** number: `chi` must read only the **public** prefix | per-`rho` TV 0, adaptive TV **1** when `chi` reads one unpublished absorbed word. **A hypothesis, not a convenience** |
| **C1/C2** | the naive approximate form at **two** rounds | blow-up **`\|C\|^2`** (×4, ×9, ×16), not `\|C\|`. The correct lossy form the memo never states — `d_adaptive <= sum over reachable rho of TV_rho` — falls out of the same identity and is tight in every row |
| **C3** | Theorem S-H′ with a **non-adapted** flag `B` (reads a challenge the run never draws) | (iv′) holds; 0 violations in 256 checks over every schedule × every completion — **no soundness hole** — but `Pr^xi[B]` is **1/2 under one completion and 1 under another** for the same schedule, so the memo's phrase "the probability of the flag in the adaptive run" is not well defined |
| **C4** | the memo's **pair-dependent** flag `B = B_w ∪ B_w'` (the source of its factor 2 on the LogUp term) | union flag: bound holds with slack 0. Single-world flag `B = B_w`: bound **VIOLATED by 3/8**. **The factor 2 is forced, not decorative** |
| **D1** | claim **S-6** (Game-`perp` vs Game-prefix), built explicitly; then the **abort probability itself** as a channel | same protocol: (iv′) holds at every `rho` under Game-`perp` and **fails** under Game-prefix, and the adaptive conclusion follows. Separately: a perfectly masked prefix with a witness-dependent refusal rate gives Game-`perp` TV **1/2** = the rate gap. **"Liveness, not distance" holds only because the challenge-driven class is a function of `rho` alone** |
| **D2** | Corollary S-H″ with **optimal adaptive** oracle queries (the memo's C8 is non-adaptive) | bound holds at `q = 0,1,2`, `\|S\| = 2,4`; it is also very loose (`q·N/\|S\|` exceeds 1 already at `q = 1`), so C8 is weak evidence either way |
| **E1** | every number in the memo's §5.3, recomputed | all reproduce to two decimals except one that is **not recomputable from the memo** (the B4 absorb collision: the memo never states the absorb count `A`). Totals: toy **2^-77.6808**, run **2^-69.2906** — the sampler term dominates by 37+ bits |

## Conventions

* Every `[COMPUTED]` figure in the check document comes from `checks.json`.
* Where the exhaustive family of challenge schedules exceeds 4,096 the sweep
  is a fixed-seed uniform sample of 4,096, **plus** the named adversarial
  schedules, which are added unconditionally so a sample can never miss them.
* `Game perp` here means: on a refusal the view is the single symbol `PERP`.
  `Game prefix` means: the view is everything interleaved up to the refusal.
  Both names are the memo's coinage; they appear in no other project document.
