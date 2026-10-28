# Exact exponential-table cardinality and larger division dictionaries

Cycle 0112 — `20261020T201854Z-91cdb36a` — 2026-10-20 UTC.

**No proving improvement measured.** Exact public table enumeration confirms that the current 32-slot division dictionary (DD) cannot accept the tested S12 tables. Larger, publicly fixed caps can retain some counted T512 savings, including on the owner's full HIGH precision block layout. Most tested T128 cases regress. This is a public arithmetic and layout study, with no native proof, profile registration or model-quality experiment.

The research question was: does S12 invalidate DD in principle, or does it exceed the current cap? The baseline is native R9's cap 32 and the owner's R11 non-DD S12/HIGH counting replica. R11 already identifies the cap problem; this study replaces its rough cardinality projection with actual table values and charges larger domains. It does not report an owner bug or a new current-profile speed win.

## Exact public inputs

The native table is `E[d] = floor(2^f_e exp(-d 2^e_s / sqrt(head_dim)) + 0.5)` for d in 0..255. DD counts the entire public table's distinct outputs **union {0}**, because masked positions use zero even when zero is absent from the table. It does not count a private trace's observed values. The native loader verifies the generator and digest, and the DD door refuses over-cap tables before any header.

S12 is the proposed 4096-entry input grid: the exponent changes from base `e_s` to `e_s - 4`, preserving the approximate physical input span while sampling 16 times more finely. Coarse entries match every sixteenth fine entry. This proposed table/width changes the integer relation and requires a new profile/digest; the native generator still returns 256 entries. It is not an admitted native configuration.

`F_P` is the quotient output precision; `f_e` is the exponential output precision; `e_s` controls exponential input spacing. They are different parameters. F_P 9 -> 12 or 15 leaves dictionary cardinality and the replica's plane/lookup counts unchanged. F_P 16 needs a third quotient limb. Changing f_e can independently increase distinct outputs and remainder widths.

All 410 public exponential arrays from the owner's 15-export R9 cardinality ledger match the reproduced generator and counts. Their distinct-column counts are 6, 8, 11, 14, 19, 24 or 32. No weights, activations, prompts or tokens were copied.

## Counted capacity cliff

For head_dim 128 and f_e 9, columns include zero. Caps are rounded up to powers of two as the existing unpadded-DD geometry rule requires. Last columns compare hypothetical **full R11 HIGH** blocks at F_P 12, with larger DD caps, against the same HIGH block without DD; other levers are identical.

| Base e_s | Native 8-bit n_col | S12 n_col | Proposed cap | T128 HIGH committed delta | T512 HIGH committed delta |
|---:|---:|---:|---:|---:|---:|
| 0 | 55 | 370 | 512 | +23.545% | +8.071% |
| 1 | 32 | 248 | 256 | +9.771% | -3.965% |
| 2 | 19 | 156 | 256 | +9.771% | -3.965% |
| 3 | 11 | 94 | 128 | +2.884% | -9.983% |
| 4 | 6 | 55 | 64 | -0.560% | -12.992% |

At T512, HIGH without DD counts 836,337,664 committed base-field words per block. Caps 256 / 128 / 64 give 803,176,448 / 752,844,800 / 727,678,976 words at base e_s 2 / 3 / 4. The first remains above R9 non-DD's 663,257,088 words. These are complete block **layout counts**, not full 32-layer runs, timings, proof-byte changes or achieved fidelity. The count benefit at cap 256 is about 4%, not R9's 20.8% DD reduction at a different precision configuration.

For S12 alone with F_P 12, the equivalent T512 committed savings are 4.875% / 12.275% / 15.975%; T128 is +12.502% / +3.690% / -0.716%. These narrower figures must not be substituted for the full HIGH counts.

## Removed work and added costs

A proposed DD removes quotient and remainder limbs plus their byte helpers from each score entry, then proves these values per dictionary slot. It retains the full score domain and adds tuple lookup helpers there. At T512, f_e 9 and F_P 12 imply two P limbs, three limbs per softmax remainder, 10 dictionary A planes, 7 H pairs and 11 byte lookups per dictionary position. The public dictionary extent is `32 * T * cap`; S remains `32 * T * T`.

At cap 256 / T512, dictionary A payload alone is 320 MiB, H data 448 MiB. The additional six net claim sites cost 393,216 base-field mask words (3 MiB) at row width 2^15. These are component payload counts, **not** additional whole-prover peak or VRAM fit: the removed S work, masks, original owners, histogram/lookup temporaries, codeword construction, allocator backing, driver and transfers must all be scheduled and measured. The public exp table grows from 2 KiB to 32 KiB; R11's already lifted table domain fits those rows, but new loader/digest/lookup semantics remain to implement.

An independent count identity, for T512 / f_e9 / F_P12 and these S12 layouts, is `delta committed = -16*S + 24*Dd + 12*row_width`. At T128 it is `-12*S + 20*Dd + 12*row_width`. Helper ceilings and fresh claim masks are included. The first local cost formula omitted removed score U8 helper pairs and understated claim sites; the second omitted the effect of S12's extra score lookup on helper-pair rounding. Both assertions failed and their code/logs are retained. The corrected counts agree with the owner replica, its four printed native phase anchors, R9 counts and the saved R11 HIGH rows.

No native work was actually eliminated. Let f be the unknown exclusive affected fraction of complete proving: even deleting it for free has ceiling 1/(1-f), before all added costs. No numerical full-GPU throughput forecast follows from these counts. The proposed benefit is falsified by a larger actual fidelity table/cap, a whole-workload memory or time regression, or any failed relation, binding, refusal or privacy check. Native cap32 feasibility is already falsified for the tested S12 cases.

## Validation and resource limits

- Probe: 486,630 checks, 1,080 synthetic rows, 7 negative controls; 0.308050 s, 15,928 KiB RSS.
- Independent audit: 1,927 checks, 265,728 entries by 90-digit multiplicative Decimal recurrence, critical tables repeated at 130 digits; 410 actual public arrays and 16 source pins; 0.444542 s, 16,004 KiB RSS. Minimum distance to a rounding half-integer is about 5.53e-5. New-table digests still need native platform checks before admission.
- Count study: 612 checks, 4 owner native phase-count anchors, 180 S12 parameter rows plus 15 full HIGH rows; 0.043956 s, 14,688 KiB RSS. No phase-time scaling model used.

Synthetic rows compare dictionary evaluation against independent direct divmod for F_P 9/12/15/16. Controls reject 33 outputs at cap32, S12 at cap32, omitted masked zero, zero Sum, rounded-down capacity, merging equal quotients with different remainders, and forgetting the S12 exponent change. These arithmetic rows are not complete attention witnesses or private proof tests.

One worker on the first allowed CPU, nice 19, 59-second CPU/alarm and 60-second parent wall limit per experiment, 512 MiB address-space cap, <=64 MiB estimated experiment memory. Hardware: Linux-6.18.54.1-microsoft-standard-WSL2-x86_64-with-glibc2.35, Intel Core Ultra 9 185H. Reproduce via the exact commands in `commands.json`; each script writes only here. The vendor directory holds byte-identical inspected local owner count scripts, imported without their main functions; external source code was not run. `source-pins.json` and `startup/manifest.json` retain source and durable-memory hashes.

## Integration and next action

Review seam: `tables_attn::exp_table_generate/exp_table_digest`, `private_block::dd_e_column_of`, `Shape::DD_CAP/natural_log/check_dd_geometry/limbs_p`, and `TrainedExport`'s checked table loader. Research interfaces are `table(hd,es,fe,bits)`, `dd_column(values,cap)`, `dd_row(values,col,fp)` and the copied R11 `build` count adapter. No native patch is prepared or merged; these results support a costed profile proposal only.

Next local experiment: aggregate a public 32-layer schedule with a uniform cap versus per-layer public power-of-two caps, including claim masks, slot-round/PCS receipt changes and actual payload lifetimes. Use synthetic tables plus the existing public exponent schedule only as a labeled sensitivity fixture; actual HIGH/S12 fidelity calibration may change every exponent. Reject any cap inferred from a private trace. Native owner/fidelity lane should freeze actual candidate tables first, then review any versioned profile; D32 quality, complete privacy and independently verified throughput remain separate requirements. Whole-GPU clocks, verified resident 1/2/4/8 and all-eleven FZC A/B retain priority.

24 ranked hypotheses preserve prior negatives. Nine LIVE queries yielded 10 source records: current precision/Chimera/DeepProve, older nonlinear/zkLLM/FLI/Locq, and newly screened older SIMD Spielman. The SIMD lead uses a different CPU encoder/PCS; PDF/code/release access blockers are recorded. No author performance reproduced.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode was run. Synthetic row lengths 32/128/512 and counted T128/T512 geometries are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

Only research excluding runtime was written. No production, reviewer, calibration, instruction, Git, GPU, build, install, external write/message, purchase or escalation action. Existing fresh masks, D30 N-r9-a/b, DD privacy gate and the narrow D33/D34/D35 scopes remain. Saved reports are not evidence of an external message or supervisor liveness.
