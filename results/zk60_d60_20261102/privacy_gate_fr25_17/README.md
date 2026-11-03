# FR25-17: NL-1 S1–S5 on all 23 slots at the D55 base shapes (2026-11-03)

The round-27 v25 freeze review (`results/zk60_gate_tinyllama_20261017/round27/FREEZE_REVIEW_V25.md`, FR25-17 and
§3 Q5) found that v25's NL-1 (`zk60_native_rg_d55nl.d55_nl1`) computes S1–S5 only on seven slots: SC_LZC 3 and
the six R13-redefined slots 14–19. S1, S4 and S5 for the other 16 slots had been computed by D33 only, at T32
TinyLlama. S1 depends on each slot's (main, extension) split, and that split differs at the D55 base shapes. This
directory holds the closing run the review prescribed.

**Result: the gap is closed for the three named bundles.**
- On fork 1 of each bundle, all 23 slots pass S1, S4, T-0/E-0 and F-0 in all four challenge modes (the run's
  re-derived challenges and three random seeds).
- S3 holds at every (N, d) pair, and every control fires as predicted.
- The 7 slots NL-1 already covered reproduce v25's rows exactly.
- No legacy slot fails S1, S4 or S5.

Not a privacy statement and not an acceptance; `D55_REAL_CONTENT_PRIVACY_GATE_PASSED` is untouched.

## Results (fork 1)

| bundle | G | slots S1 / S4 (4 modes) | S3 (fork's pairs; all 23 slots of every fork) | control (a) | wall | peak RSS |
|---|---:|---|---|---|---:|---:|
| `d55-r13_8b_t128_h24-s0` | 19 | 23/23, 23/23 | 55/55; 55/55, budget ok | v25 in-process + merged record `d55-mg-r13-8b-s0`: identical | 159 s | 1,468 MiB |
| `d55-r13_shield_t256_h24-s0` | 19 | 23/23, 23/23 | 75/75; 75/75, budget ok | v25 in-process: identical; merged record `d55-mg-shield-t256-s0`: identical (checked after the fact, see below) | 371 s | 2,597 MiB |
| `d55-r13_tiny_t128_low-s0` | 19 | 23/23, 23/23 | 75/75; 75/75, budget ok | v25 in-process + merged record `d55-mg-tiny-t128-s0`: identical | 97 s | 891 MiB |
| rung `d55-r13_rung_h24-s0` (development) | 21 | 23/23, 23/23 | 55/55; 55/55 | both: identical | 22 s | 239 MiB |

How the run went:
- The three closing runs were one guarded cpu job (`chain_fast.sh` → `three.sh`, need 6 GiB): 628 s in total,
  guard peak 2.50 GiB.
- The job waited 19,894 s for the heavy lock behind the merged-gate queue.
- On each fork, R13-3 recovers G (19 everywhere) and closes 23/23 slots before NL-1 runs.
- Shieldstral T256's control (a) against the merged record was done after the fact (coordinator, 2026-11-03),
  once the merged queue had written `d55-mg-shield-t256-s0.json` (sha256 e1efaa05…). `control_a_after.py`
  runs the tool's own `compare_seven` on the two saved records, with the same G check and the same
  self-test (one reference S1 row's L + 1). Result: the seven slots are identical in all four modes
  (7 S1 and 7 S4 rows per mode, 7 T-0 rows, 7 IR entries), G 19 = 19, and the self-test fires.
  The output is in `records/fr25_17-shield-t256-s0.control_a_record_file.txt`. The closing record itself
  (sha256 ae37367c…) is unchanged.

The legacy slots on fork 1 are 0, 1, 2, 4, 5–13 and 20–22. For each the table gives main / extension / declared
degree d / mask length L. On every one of them the walked maximum product degree equals the per-variable bound
equals d (slack 0), and L + 256 ≤ 512.

| slot | 8B T128 | Shieldstral T256 | TinyLlama T128 |
|---|---|---|---|
| 0, 1 SC_SS / SC_SSM | 19/1/3, 62 | 20/1/4, 86 | 18/1/3, 59 |
| 2 SC_TZC | 7/1/3, 26 | 8/1/3, 29 | 7/1/3, 26 |
| 4 SC_RS | 19/1/3, 62 | 21/1/3, 68 | 19/1/3, 62 |
| 5, 6, 7, 10, 11, 12 (matmuls) | 12/1/2, 28 | 12/1/2, 28 | 11/1/2, 26 |
| 8 SC_SCORE | 10/2/3, 38 | 10/2/3, 38 | 8/2/3, 32 |
| 9 SC_PV | 10/2/3, 38 | 11/2/3, 41 | 9/2/3, 35 |
| 13 SC_DMM | 14/1/2, 32 | 14/1/2, 32 | 13/1/2, 30 |
| 20 SC_ZS | 14/1/2, 32 | 15/1/2, 34 | 14/1/2, 32 |
| 21, 22 SC_IO_IN / SC_IO_OUT | 19/1/2, 42 | 20/1/2, 44 | 18/1/2, 40 |

The full per-slot tables come from `python3 summarize.py records/*.json`. The per-slot verdicts for every mode are
under `"NL-1 all 23 slots".per_slot` in each record.

## Controls (each acted on something; a control with nothing to act on is not counted)

**(a) The 7 slots NL-1 already covers.**
- On the fork, every per-instance row equals the corresponding row from v25's `d55_nl1` run unchanged in the same
  process (given only that fork's G). Rows for 8B and TinyLlama also equal the merged 18-part record's rows.
- Compared row for row in all four modes: S1, S4, T-0/E-0, the S5 per-slot rows and the slot IR itself.
- The record's G is the same as this run's.
- The comparison's own self-test (one reference S1 row's L + 1) is detected.

**(b) Negative controls: S1 made false on one legacy slot.** Every bundle shows exactly the predicted single
failing slot:
- NC-DEG: the first zero-slack legacy slot (slot 0) gets its declared degree lowered by one, so degree_fits fails.
- NC-SPLIT: slot 8 loses its group eq factor and has both private factors put in extension round 0, so the premise
  fails (S1 false) and the miniature chain rejects. This is nl_check's own S5 control C3, run at the real shape.
- NC-EXTREC: slot 8's recorded extension round of its second factor goes from 1 to 0, so the split cross-check (D6)
  refuses that instance.

**Also, as predicted:**
- nl_check's C1 (eq kept, both factors in round 0) and C2 (eq dropped, rounds 0/1) do not fire.
- v25's NL-TAB-GC, NL-TAB-ACT and NL-G controls, run over 23-slot contexts, fail exactly slot 18, 19 and 18.
- F-1 fires 23/23. N5-2 fires on every slot where it applies. N5-3 and N5-4 fire.

**Finding (control design, not a leak).** tokennl's N5-1 (strip a public factor, so the premise must fail) fires
on 21 of 23 slots, and its raw `ok` is false on the widened set.
- It cannot fire on SC_SCORE (slot 8) and SC_PV (slot 9). Their premise has a second mechanism: the two private
  factors are masked in different extension rounds, so the premise holds even with the group eq stripped.
- nl_check's own S5 records this as C2, "must NOT fire".
- The record therefore adjudicates N5-1 per slot against that prediction (23/23 as predicted) and runs C1/C2/C3 at
  the real shape. C3 fires.
- S5 on these two slots therefore rests on C3, not on N5-1.

## How `fr25_17_nl1_all23.py` differs from v25 `d55_nl1` / `fork_contexts`

Nothing under `ops/zkp-mvp/gate-tinyllama/` is edited. The v25 modules are imported from `staging_v25/scripts`;
their sha256 values are in each record and equal the merged record's `tool_sha256`. Everything not listed below is
the v25 function, called rather than copied.

- **D1. Slot order.** All 23 slots run, the seven NL-1 slots first, so they draw v25's random challenges and their
  rows can be compared byte for byte.
- **D2. Bilinear group point.** The bilinear slots' derived group point is set as `r13blocks.check_stage:237-242`
  does it, inside the slot's refusal `try`. A slot that needs a group table but has no derived point is refused
  (fail-closed), not left to crash.
- **D3. Run-mode values.** The run-mode `gate.vals` call is inside the same `try`.
- **D4. Labels.** The 16 legacy slots are labelled "(legacy body)". Slot 3 keeps v25's label, because labels seed
  nl_check's per-slot randomness.
- **D5. Extension-round order.** `nl_check.Slot` gets the extension-round order of slots 8 and 9, which is
  `{8: [0, 1], 9: [0, 1]}`.
  - Source: nl_check's own `parse_sources`, run on the argument.rs / layout.rs whose digests equal the bundle
    manifest's pins (86c9941d…, 171656f8…, `ops/zkp-mvp/gpu-metal/hashline/src/private_block/`).
  - Mechanism: `nl_check.Slot` is replaced, in scope only, by a subclass whose one change is to use that order when
    a caller passes `{}`. It is restored afterwards and the restoration is checked.
  - Every v25 and tokennl call site passes `{}`, because none of their slots has two extension rounds.
- **D6. Split cross-check (new, fail-closed).** For each instance, the split nl_check uses (main, extension, each
  private table's round) must equal the bundle's own record.
- **D7. Forks.** Only the requested fork is evaluated; 23 instances are expected.
- **D8. S5 adjudication.** As described in the finding above.
- **D9. D55 controls.** v25's `d55_nl_controls` runs unchanged, with `d55nl.fork_contexts` rebound in scope to the
  23-slot version.
- **D10. S1 negative controls.** The control (b) set above.

## Files

- `fr25_17_nl1_all23.py` is the experiment.
- `three.sh` runs the three closing runs in sequence.
- `chain.sh` and `chain_fast.sh` are its two guarded launchers. The second polls admission every 0.5 s, so it could
  take the lock between the merged queue's runs. Whichever launcher starts first does the pass; the other finds
  `logs/three.complete` and exits.
- `run.sh` is the guarded single run used for development.
- `detach.py` is the Mac detach runner.
- `summarize.py` prints the per-slot tables.
- `records/` holds the three closing records.
- `dev/` holds the rung development records.
- `logs/` holds the guard logs, the progress file and the exit codes.
