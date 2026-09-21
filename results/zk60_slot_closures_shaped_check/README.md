# Evidence for `ZK60_SLOT_CLOSURES_SHAPED_CHECK.md`

Independent adversarial check of `docs/zkmatrix-poc/ZK60_SLOT_CLOSURES_SHAPED.md`.
2026-09-21, 01:15 PDT (`date` on the WSL box). Read-only against lane commit
**`8c5922b`** (`/home/victor/wt-zk60-block125m`). Nothing was built, proved or
committed. Every script writes only into this directory.

All arithmetic is exact over `Fp2 = Fp[u]/(u^2 - 7)`, `p = 2^64 - 2^32 + 1`.
`fp2.py` is written from `zkp-core/src/field.rs` and NOT from the memo's own
`results/zk60_slot_closures_shaped/fp2.py`.

Rerun any of them with bare `python3 <file>`; each is a few seconds except
`rank_dof.py` (~60 s) and `premise_cover.py` (~2 s).

| script | what it decides | output |
|---|---|---|
| `fp2.py` | the field, an exact rank over `Fp2`, a reproducible RNG | — |
| `rank_dof.py` | clause C3: `rank R_s = N_s d_s + 1`, `dim ker R_s = 1`, at the shaped `(N, d)` of 23 slots x 4 shapes and at **12 or 14 challenge vectors each** (14 for the two bilinear slots), random AND degenerate (a main `rho_j = 0`, `= 1`, repeated coordinates, all-equal, all-zero, `e_0 = e_1`). 1,120 checks, 0 not tight. Controls: the mask at degree `d-1` covers only 27 of 40 dimensions; a wrong sum weight breaks the chain at round 0 | `rank_dof.json` |
| `degree_maxplus.py` | the DECLARED slot degree against the closure's actual total degree, in the max-plus degree semiring. Reproduces `BASE_DEGREE` at the toy 23/23 (the port's self-check). No slot under-declares; slots 14, 15, 16, 18 over-declare by one wherever their domain pads | `degree_maxplus.json` |
| `premise_cover.py` | clause C4 in the strong form: `poly(exts) = 0` at random `pi`, all 23 arms x 4 shapes x both extension rounds x 6 seeds = 600 evaluations, 92/92 arms. Negative control: the pad-zero term moved one bracket outwards makes it FALSE in 21/21 pad-zero arms | `premise_cover.json` |
| `flip_miniature.py` | the miniature the memo admits it did not build (§6.3 item 4): the SAME private plane read at two points differing in one FLIPPED coordinate (`argument.rs:1366-1368`). Full mechanism — `priv_table`, masked sumcheck, extension round, `mask_eval`, `build_claim`, the verifier's `vals`/`g_val`, `part_key_at`. 5 seeds x 7 values of `pi`; 18 properties, all hold | `flip_miniature.json` |
| `bundle_words.py` | clauses C6 and C2 on the committed capture `run-i-dense-k4` stage 0 (rung-K4, dense generic witness): the published word count per slot against `1 + N(d+1) + terms`, 23/23; the chain and the terminal identity re-run from the published fields alone, 23/23; 1,269 words = 20,304 B | `bundle_words.json` |
| `counts_and_cliffs.py` | the `zeta` / `mu_pad` draw count per proof (8 / 8 / 5), the degree-rise cost split into what the closure needs and what it does not, and two shape cliffs decided by scan | `counts_and_cliffs.json` |

## What is NOT here

No privacy statement, no soundness review, no measurement of a proof. Nothing
about (H1) / G-R1, the `M` opening, the PCS openings, the hash layer, the
pairless LogUp sum claim, or the 125M shape as a running artefact — every 125M
figure below is model-derived, exactly as the memo's are.
