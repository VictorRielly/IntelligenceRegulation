# Evidence for `ZK60_SEQUENTIAL_KERNEL_LEMMA_HASHED.md`

Exact machine checks of the **inference** the memo proves — the sequential
composition of a multi-round Fiat–Shamir protocol whose messages are
`(field, hash)` pairs. Nothing here touches the ZK60 prover, and **nothing
here establishes a privacy property of any artifact.**

Run:

```
python3 /home/victor/IntelligenceRegulation/results/zk60_sequential_kernel_lemma_hashed/sequential_kernel_hashed.py
```

Deterministic (exact `fractions.Fraction`; every random instance carries a
fixed seed). Runtime **3.72 s** on the WSL box, single core, no heavy lock
needed (`timing.txt`). Outputs `checks.json` and `checks.log` beside the
script.

| check | what it tests | memo section | result |
|---|---|---|---|
| **C1** | the **path identity** `P_chi[m] = P_{rho(m)}[m]`, the engine of the proof, on six paired protocols (one modelled on a salted leaf, five random) | §3.1 | 0 mismatches of the exact rational laws, over every challenge function of each model |
| **C2** | the **exact lemma**: hypothesis (iv) at every `rho` ⟹ the adaptive view law is witness-free for every challenge function | §3.2 | max per-`rho` TV 0 and max adaptive TV 0 on all six |
| **C3** | a **hash part** that leaves every marginal witness-free and the joint law witness-dependent: `(H(mask), mask + w)` over all 256 public functions `H` on a 4-element domain | §2.3, §3.2 | marginals witness-free for all 256; the joint law witness-dependent for 252; a distinguishing challenge function exists for exactly those 252 |
| **C4** | the **naive approximate form is FALSE**: per-`rho` TV `1/\|C\|` at every `rho`, adaptive TV `1` under a steering challenge function | §3.4 | blow-up exactly `\|C\|`, at `\|C\| = 2, 4, 8, 16, 32` |
| **C5** | the **identical-until-bad form is TRUE**, with `Pr[BAD]` measured in the **adaptive** experiment | §3.3 | the bound holds in every row of C4, tight in each |
| **C6** | one **witness-dependent refusal** class is made certain by a *constant* challenge function | §3.4, §3.7 | worst-case adaptive TV `1` at every `\|C\|`; mean over 200 random challenge functions 0.658 / 0.321 / 0.163 at `\|C\| = 4 / 8 / 16` — halving with `\|C\|` |
| **C7** | **separation**: a challenge query point that coincides with a generator refill point | §3.7, §4 (iii-a) | shared point: TV 1 (the witness is recovered); separated: TV 0 over all 256 challenge functions |
| **C8** | the **augmentation** step: a `q`-query distinguisher against one hidden salted leaf | §3.5 | exact advantage `1/4` and `1/8` at `\|S\| = 2, 4`, always below the memo's `q·N/\|S\|` |

Two modelling conventions, stated because they are load-bearing:

1. In **C1, C2, C7** the oracle tables are part of the prover's randomness and
   are **not** in the view — the `q = 0` case. The cost of a distinguisher that
   can read the table is C8, and in the memo it is a separate step (§3.5), not
   part of the composition.
2. In **C3** the function `H` is **public** (quantified over), because there the
   hashed value is one the protocol goes on to publish. That is the honest
   model for that counterexample and it is what makes it bite.
