# ZKP efficiency progress

Cycle0090 complete — `20261019T221854Z-a20c7a9f` —2026-10-19 UTC.

**No speed improvement measured.** Separate decode/pad statement scopes
pass48 synthetic fixtures,78 prior-path comparisons and480 new controls.
Independent audit:2411 checks,432 corruptions,432 first errors.
An authored Rust Drop probe confirms the lifetime rule and catches the
reference-binding negative. The production loader patch is unbuilt/unapplied.
Main/audit0.608/0.141s,39836/35980KiB,one low-priority CPU thread.

[MODEL]8B T128 padding envelope falls112.003906MiB. Standalone borrowed
loader saving is **0B**;with prior checked moves+raw release,the modeled
current+next+four-pin public envelope1.727766->1.618387GiB.
Actual Vec allocations,RSS/VRAM and elapsed savings remain unknown.

New verified full-stack proofs/passes/positions **0/0/0**;device/context none.
Steady-state/total proved rates,startup fraction,new witness/proof/
serialization/verification clocks unmeasured. Carried owner diagnostic only:
8B T128,32 blocks,one16-thread CPU pass,GPU off,total478.737s(0.267370
positions/s),prove_run393.785s includes witness98.348s;fresh verify42.709s
plus13.681s initial load. Researcher did not reverify it. No new target credit.
No long-context,resident proof series or decode ran;attention can grow
quadratically. Private8B >=50 proved positions/s remains unachieved.

Searched Rust lifetime rules,SP1 GKR composition,Chimera,HERMES,AG skip,
ICICLE release/license and Efficient Sumcheck;8 primary records saved.
Seam:load_layer_mode aw/fw initializers. Next:original Vec allocation probe;
owner owes native gates/clocks. Whole-prover GPU and verified fixed-context
resident1/2/4/8 remain first. No private masks/openings reused.

[Experiment](experiments/decode-statement-scopes-20261019/README.md),
[handoff](handoffs/20261019-decode-statement-scopes.md),
[dated report](progress/20261019T221854Z-a20c7a9f.md).
Only research changed. Saved reports do not establish delivery.
