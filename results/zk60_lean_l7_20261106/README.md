# D63 step L7, Fiat–Shamir soundness of the executable sumcheck verifier: evidence (2026-11-06)

The report is §9 of `docs/zkmatrix-poc/ZK60_LEAN_ASSEMBLY_20261106.md`. Every job below ran through the zk60 resource
guard (class `cpu`) with `run_guarded.py`, detached with `start_new_session`. Peak RSS of the final check: 3.81 GiB.
No Rust was added: the L5 and L6 corpora already pin the encodings this step uses (the transcript's items, the
`sc-round` absorb, `challenge_fp2`), and both are re-checked here as regressions.

## What was written

| File | What |
|---|---|
| `formal/ZK60Formal/ExecSumcheckFS.lean` | the protocol's state function on the CODE's transcript chain (`codeSt`, `codeSt_round`, `cDecode_rounds`, `fs_code_chain_sound`), the code's chain on the finite oracle domain `QB L` (`chainEncB`, `chainFrom_liftH`, `opTrace_chainFrom`), the challenge's fibers (`card_chal_fiber_le`), and the end-to-end theorem `exec_sumcheck_fs_sound` with its Goldilocks and slot-shape corollaries |
| `formal/ZK60Formal.lean` | imports the new file (one line) |

`Statements.lean`, every existing Lean file and every production source are unchanged.

## Scripts

| File | What |
|---|---|
| `run_guarded.py` | the guarded, detached runner (a copy of L6's) |
| `stage.sh` | elaborate one file with `lake env lean` (the first attempt, `file1.log`) |
| `bisect.py`, `variants.py` | elaborate truncated (`#exit`) or proof-stubbed copies of the file, kept in the session scratchpad, never in the library, each under its own RSS watchdog, to find the proof that ran away (below) |
| `gen_axioms.py` | writes `axioms_l7.lean`: a `#print axioms` line for every theorem of `ExecSumcheckFS.lean` |
| `check_l7.sh` | the final check, ONE guarded job: the full `lake -d formal build` (`full.log`), the axiom audit (`axioms_l7.lean` → `axioms.log`), the source scan, the root import, and the regressions `L6Check` on `results/zk60_lean_l6_20261106/corpus.txt` (`l6check_regression.log`) and `L5Check` on `results/zk60_lean_l5_20261106/corpus.txt` (`l5check_regression.log`) |

## How the file was written (the runaway and its fix)

- `file1.log`: the first draft was killed by the guard at its 24 GiB cap after 75 s (`file1.log.guard`: peak RSS
  24.58 GiB). Lean prints nothing before the kill.
- `bisect1.log`: truncations of the file at eight declaration boundaries, each capped at 10 GiB. Every prefix up to the
  end-to-end theorem elaborated in about 3 s at about 3.5 GiB; the prefix with the fiber lemma raised
  "maximum recursion depth" (in the `constructorNameAsVariable` linter).
- `bisect2.log`, `var1.log`, `var2.log`: proof-stubbed variants. The runaway was the one-line proof of `|K| = p²`
  (`rw [← Fintype.card_congr ι, Fintype.card_prod, ZMod.card, sq]`) with the LITERAL `p = gP` (killed at 8 GiB in
  15 s); the same proof with a variable `p` (`FSChainRbr.lean`'s) is instant. The recursion was a membership proof in a
  `Finset.univ` of a concrete huge type (`Fin (2^128) × Fin (2^128)`, `Dig`).
- `var3.log`, `var4.log`, `var5.log`: the fix. `card_of_pairs`, `dig_bound_le` and `slot_bound_le` are stated for a
  variable `p`, and `card_filter_le_of_injective` for abstract finite types, then instantiated. The whole file then
  elaborates in 4 s at 3.65 GiB with no error and no warning (`var5.log`).

## Results (`check.log`)

- Full build: 3,453 jobs (the library plus the new file), rc 0, 0 warnings, 0 errors, no `sorry`.
- Axiom audit: 39 theorems; 24 on `[propext, Classical.choice, Quot.sound]`, 8 on `[propext, Quot.sound]`, 4 on
  `[propext]`, 3 on none; no `sorryAx`, no `Lean.ofReduceBool`.
- Source scan of `ExecSumcheckFS.lean` for `sorry`, `axiom`, `native_decide`, `admit`, `maxRecDepth`, `maxHeartbeats`,
  `implemented_by`, `extern`, `bv_decide`, `ofReduceBool`: none.
- Regressions: `L6Check: 1206 checks, 0 failed`; `L5Check: 5553 checks, 0 failed`.
