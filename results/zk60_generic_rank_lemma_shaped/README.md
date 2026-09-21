# Evidence for `ZK60_GENERIC_RANK_LEMMA_SHAPED.md`

Drafted by a delegated Opus agent for the security owner, 2026-09-20 (`date`
22:08–23:0x PDT). Read-only against the lane worktree
`/home/victor/wt-zk60-block125m` at commit **`e6b612f`**. Nothing was built,
no prover was run, no file outside this directory was written.

All arithmetic is exact Python integer arithmetic over Goldilocks
`p = 2^64 − 2^32 + 1` with `Fp2 = Fp[U]/(U² − 7)`
(`zkp-core/src/field.rs:15`). No capture bundle is read. No privacy property
is established by anything here.

| file | what it establishes |
|---|---|
| `fieldlib.py` | `Fp`, `Fp2`, `Norm`, the `wedge` form the code calls `determinant`, exact `Fp` rank / split-rank / determinant, and `eq_table_msb` (`mle.rs:13-51`) |
| `model/` | the lane's OWN shape-driven layout model, run read-only: `python3 /home/victor/wt-zk60-block125m/scripts/zk60_private_block_layout_model.py --all --out model`. Its toy reproduction is exact (23 of 23 Rust-asserted numbers), which is what earns it the right to be believed at `rung_g` and `m125`. |
| `shaped_counts.py` / `.txt` | the per-commitment table (`A`, `H`, endpoint, boundary, `M`) at the toy, rung-G and 125M: rows, data rows, reserved pairs, non-data rows, claims, opening groups, the `2(G+1)` generators and the **slack**. Also: the endpoint-row correction (the model still carries the memo's 29 at 125M; the Rust declares 37) and the receipt figure it produces; and blocking item B-1 of the toy check re-tested at both shaped layouts. |
| `bilinear_miniature.py` / `.txt` | a faithful miniature of the **repaired** `SC_SCORE` / `SC_PV` claim pattern with **two** key-value group bits: the coordinate lists axis by axis, `build_claim`, `zpart_weights`, first-occurrence grouping, `zk_rhos`, `k0`, the factorised determinant, a **brute-force** disclosed dimension over the whole linear view with no reduction, the grouped-head known-zero region, and seven control regimes including the PRE-REPAIR schedule |
| `boundary_endpoint.py` / `.txt` | the non-data block of every commitment KIND at the shaped counts, with each refusal switched off in turn — which is how "which refusals are necessary" becomes a measurement |
| `channels_shaped.py` / `.txt` | the pad block (H-pad / M-cols) at each shape's own `(n, nn, Q)` by exact Vandermonde determinant, and the CFS mask channel at every `(N_s, d_s)` of rung-G and 125M under five `rho` regimes, with the `d`-values negative control |
| `refusals_and_backstop.py` / `.txt` | the refusal inventory per shaped block and per twelve-block run in bits; the input-dependent LogUp term raw and with the **distinct-value refinement**; the Schwartz–Zippel backstop degrees |

Reproduce: `python3 <file>.py` from this directory (each writes its own
`.txt`). Total runtime under a minute apiece except `channels_shaped.py`,
which takes a few minutes.
