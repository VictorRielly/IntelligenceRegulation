# Evidence for `ZK60_GENERIC_RANK_LEMMA_SHAPED_CHECK.md`

An INDEPENDENT adversarial check of
`docs/zkmatrix-poc/ZK60_GENERIC_RANK_LEMMA_SHAPED.md`, written by a second
delegated Opus agent on 2026-09-20 (`date` 22:56–23:2x PDT). Read-only
against `/home/victor/wt-zk60-block125m` (working tree; `git --no-pager diff
--stat e6b612f` shows only `shape.rs` has moved since the memo's pin, by the
60 lines that add `Shape::rung_k4`). Nothing was built, no prover was run,
no capture was read, no file outside this directory was written.

Exact integer arithmetic over Goldilocks `p = 2^64 − 2^32 + 1`,
`Fp2 = Fp[U]/(U² − 7)`. `f2.py` is written from scratch rather than imported
from the memo's `fieldlib.py`, so a shared bug cannot hide. Every instance
uses GENERIC random field elements at several seeds.

| file | what it establishes |
|---|---|
| `f2.py` | Fp / Fp2, `Norm`, the `wedge` the code calls `determinant` (`protocol.rs:276-278`), exact rank and determinant over Fp, realification, `eq_table_msb`, a seeded generic-element stream. Also checks that `U² − 7` is irreducible, which is what makes `Norm(a) = 0 ⟺ a = 0`. |
| `keys_bilinear.py` / `.txt` | the column keys of the four repaired bilinear claims, symbolically and numerically, at the toy, rung-G, **rung-K4** (built after the memo) and 125M; the memo's 6/10, 10/10, 8/14, 14/14 reproduced; the SC_GMM/SC_UMM pair the memo does not count; and the shape condition (`head_dim ≥ row width`) under which the two SC_SCORE keys collide BY CONSTRUCTION. |
| `nondata_rank.py` / `.txt` | the non-data block of `A`, `H`, the endpoint and the boundary at the REAL group-size distribution derived from `claim_sites`, with `H`'s zero-sum rows modelled as built; every refusal switched off in turn; the exact determinant identity; and the reachability analysis that refutes Finding N-2. Uses the memo's own `k0 = rank(all) − rank(non-data)`, not `#gens − rank(non-data)` — the two differ exactly on the zero-λ draws. |
| `refusal_recount.py` / `.txt` | every refusal term recounted from the code; Finding N-3 re-derived (768 confirmed); the table-helper raw count corrected from `3 × row width` to `3 × 256`; the backstop degrees. |
| `brute_view.py` / `.txt` | the WHOLE linear view with no reduction, on generic data: claim values, group vectors, the proximity vector, opened columns and the zero-sum constraints. `A`-like at group sizes **5 and 3** (the memo's brute force reached 2) → disclosed 0, control fires at 16. `H`-like → disclosed **2**, and the disclosed span is computed EQUAL to the public LogUp identity's span. |

Reproduce: `python3 <file>.py` from this directory; each writes its own
`.txt`. Under a minute apiece.

**Nothing here is a privacy claim.** It is exact linear algebra on a model,
plus code reading.
