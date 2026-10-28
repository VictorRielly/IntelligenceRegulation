# Public per-layer dictionary caps and hybrid division — cycle 0113

Run `20261020T211854Z-71297104`; checkpoint 2026-10-20T21:30:19.165784+00:00. **No proving improvement measured.**

Question: does choosing DD capacity from each layer's entire public exponential table give a useful improvement over one uniform cap? The baseline is the owner's R11 HIGH/S12 layout with direct division. Compare uniform DD, per-layer DD and a public hybrid that picks the smaller counted A+H layout. The hybrid optimizes committed words only; it is not a runtime optimizer.

The existing b7 public exponent schedule is 30 layers at e_s2, one at3, one at4. It is a labeled sensitivity fixture: actual HIGH calibration can change every exponent. S12, f_e9, F_P12 require caps256/128/64 at those exponents, with156/94/55 distinct outputs including0. Current native cap32 cannot admit them. Three additional synthetic schedules vary exponent diversity; no weights, prompts or activations are read.

| Counted context | Public policy | A+H words, all 32 layers | Versus direct | Body receipt delta, B | Selected dictionary peak |
|---:|---|---:|---:|---:|---:|
| 128 | direct | 4,872,208,384 | +0.000000% | 0 | 0 MiB |
| 128 | uniform | 5,348,261,888 | +9.770795% | 85,254,144 | 160 MiB |
| 128 | layer | 5,322,047,488 | +9.232756% | 81,977,104 | 160 MiB |
| 128 | hybrid | 4,871,356,416 | -0.017486% | 697,952 | 40 MiB |
| 512 | direct | 26,762,805,248 | +0.000000% | 0 | 0 MiB |
| 512 | uniform | 25,701,646,336 | -3.965051% | -15,404,032 | 768 MiB |
| 512 | layer | 25,575,817,216 | -4.435215% | -23,268,592 | 768 MiB |
| 512 | hybrid | 25,575,817,216 | -4.435215% | -23,268,592 | 768 MiB |

At T512, per-layer caps save another125,829,120 words, **0.489576% versus uniform**, or0.470164 percentage points against direct. Projected fixed-skeleton body receipt bytes fall another7,864,560 B. At T128, per-layer DD still grows A+H by9.232756%; public hybrid uses DD only at the final cap64 layer, saves851,968 words (0.017486%), and grows the projected body receipt by697,952 B. Do not turn that tradeoff into a speed claim. With no exponent diversity, per-layer and uniform policies coincide.

For a balanced synthetic schedule [2,3,4,4] repeated8 times, per-layer T512 counts9.983152% fewer A+H words than direct; b7's much smaller diversity yields4.435215%. A broad synthetic schedule including e_s0 can regress8.071152% under a uniform cap512; public hybrid avoids those regressing layers and counts7.230733% fewer words. These scenarios do not establish model fidelity.

## Removed work, extra costs and ceiling

Hypothetically DD moves per-score quotient/remainder limbs and byte helpers to dictionary rows. Native work removed here: **none**. Smaller caps only remove surplus public dictionary positions; they do not remove fresh claim masks. Each HIGH DD layer adds3 A and3 H claim sites,12 times the row width in fresh A/H mask words,3 PCS groups and a dictionary slot. Across32 DD layers the additional A/H mask words are6,291,456 at T128 or12,582,912 at T512 (48/96 MiB), whatever the caps.

The M commitment adds2 encoded rows per DD layer:65,536 B of encoded matrix and8,192 B of a-coefficient payload. M also draws fresh CFS coefficients and512 additional base-field pads per DD slot. At T512, cap64/128/256 has20/21/22 main DD rounds, degree4, one extension, CFS lengths86/90/94. Compared with32cap256 layers, b7's smaller caps remove just24 fresh base-field CFS words, while all A/H mask rows remain. Independent resident1/2/4/8 pass accounting repeats these costs; no mask is reused.

Wire deltas include slot messages/terminals, M opening rows, A/H rows and the extra PCS groups, under the inherited R9 skeleton. The native non-DD/DD T128 difference235,008 B is reproduced. HIGH is unimplemented: these conditional body deltas exclude new schedule metadata and require review of degree/group/endpoint assumptions. A rows-only estimate gives the wrong answer, especially at T128.

Even deleting an unknown exclusive affected fraction f of complete proving gives at most1/(1-f), before added work. f and full GPU clocks are absent, so there is no numeric complete-proof ceiling or >=50-token/s forecast. Falsify the benefit if actual public tables increase caps, fidelity/binding/refusal/privacy fails, complete time regresses, or extra masking/PCS/lifetimes erase the saving.

## Lifetimes and limits

The source has A committed before H, with A alive while H is constructed; both owners are opened/dropped before the next prove_core. The selected dictionary payload model charges simultaneous A+H. At b7 T512, uniform/per-layer both peak768 MiB; cumulative requests fall24,576->23,616 MiB. Treating cumulative bytes or their mean as peak is wrong. A largest-cap pool retains768 MiB even on smaller-cap layers. T128 uniform/per-layer peak160 MiB; hybrid only uses40 MiB of selected dictionary payload. These numbers exclude every other A/H plane/mask, encoded owner, tree/pad, witness, looked/histogram, allocator/driver and transfer, so they establish no whole-prover fit or VRAM high-water mark.

## Reproduction and independent validation

`probe.py`: 53,836 checks,120 synthetic rows,10 negative controls; 1.777999 s / 18,720 KiB RSS. `audit.py`: 8,915 checks,20,480 public entries by90-digit Decimal recurrence,3,360 independent arithmetic positions,4,096 allocation events,15 source pins and9 mutation controls; 0.021773 s / 18,000 KiB. Every M coefficient row meets its512-position budget with256 pads. No experiment failed. An earlier successful audit, before adding the M-row budget check, remains saved.

Seed20261020113. Intel Core Ultra9 185H, Linux-6.18.54.1-microsoft-standard-WSL2-x86_64-with-glibc2.35; one worker on first allowed CPU, nice19,59s CPU/alarm and60s parent timeout,512MiB address-space cap,64MiB estimated memory per experiment. Commands and exit statuses are in `commands.json`. `source-pins.json` binds byte-identical inspected local owner scripts, frozen R9 sources and prior results. No downloaded source was run. Audit imports no producer code; it checks independent affine A/H, lookup, table-term, wire and allocation graphs against the owner replica.

## Sources and integration

Nine native LIVE queries /10 records are in `source-records.json` and the append-only ledger (692->702). Refreshed [Chimera](https://eprint.iacr.org/2026/1388) (October16 revision), ICICLE releases/commit and [concurrent NTT capacity](https://github.com/ingonyama-zk/icicle/blob/main/examples/c%2B%2B/best-practice-ntt/README.md), Qingming, GoldilocksNTT, cq and ring lookups. Newly assessed older [MARLUT](https://eprint.iacr.org/2025/2109) (received2025-11-17, revised2026-04-13) uses three-party MPC/distributed ZK rather than a compatible native proof. Its PDF403 and two MIT-license-body cache misses are recorded without bypass. ICICLE main MIT body and exact tag commit6c77775961b0e4dc2be359feec1ac11536c18043 inspected; tag date's year is unavailable. No author gain reproduced.

Rust review seams: Shape dd_cap/check_dd_geometry/slots/receipt_bytes; exact public E-column loader; trained statement and RunStatement stage_shape/stage_layout/schedule_digest. Existing with_layer_calibration refuses plane-list changes and cannot carry this new mode/cap schedule. Any new profile must bind cap/mode/table and stage order before challenges; every shard/site requires its own fresh masks and one opening. Research interfaces: `make_layout(T,cap)`, `slot_schedule`, `wire_parts`, `aggregate`, `lifetime`; no native patch.

26 ranked hypotheses retain prior negatives. Top3 remain whole-GPU/resident workloads, DD scaling/fidelity and phase/capacity clocks; all-eleven FZC A/B remains4; this public scheduling question is refined at5. MARLUT is a low-priority incompatibility screen; new public dyadic dictionary partition feasibility is queued. Rotation covered GPU NTT/commitments, sumcheck, memory, batching, lookup, arithmetic and composition; next emphasize dictionary input-consistency and proof composition.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra 9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic rows use lengths 32/128/512; counted layouts use T128/T512, 32 heads, head dimension 128 and 32 sequential layers. These are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private 8B >=50 proved positions/s target on an RTX 5090 or another named high-end GPU remains unachieved.

Next local: Test a public dyadic dictionary partition against the proposed cap256: 156 distinct public outputs could occupy 128+16+8+4 slots per attention row instead of 256. First use synthetic direct-versus-sharded tuple/divmod checks and count every additional slot, fresh mask pair, PCS group, histogram and row-Sum binding. Check the no-lift premise for every shard; small shards may erase the gain. This is an untested new-profile idea, not authorization to alter native D30 or its privacy requirements. Actual HIGH/S12 tables must come from the owner fidelity lane before promotion.

Owner priorities remain whole-prover high-end GPU phase/capacity clocks and independently verified fixed-context resident 1/2/4/8 workloads, DD context/fidelity scaling, and the all-eleven FZC compiler A/B under shared heavy/build locks. No such job was launched here.

Only research excluding runtime was written. No production, reviewer, instruction, calibration, Git, receipt or safety-gate edits; no GPU/build/install, external writes/messages, purchases or escalation. Fresh masks/openings and D30 N-r9-a (row Sum/slot17/Ht), N-r9-b (M_dd in A before lookup challenges), the DD privacy gate, D32 and narrow D33/D34/D35 scopes remain. Main/Claude reviews and integrates; no merge. Saved reports do not establish external delivery or supervisor liveness.
