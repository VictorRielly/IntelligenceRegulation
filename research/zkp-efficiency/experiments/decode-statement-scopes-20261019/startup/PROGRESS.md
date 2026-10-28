# ZKP efficiency progress

Cycle0089 complete — `20261019T211854Z-fff84a98` —2026-10-19 UTC.

**No speed improvement measured.** Releasing nine public raw matrices after
padding passes78 accepted synthetic paths,6720 mutation-path checks and an
independent byte/hash/metadata/first-error audit. Main/audit5.322/0.196s,
40556/34492KiB,one low-priority CPU thread. No native loader/proof ran;
the Rust patch is unbuilt/unapplied.

At8B T128,the modeled borrowed-constructor reload envelope falls
705199616->638116864B (**63.98MiB**). It adds0B sealing-peak saving beyond
the prior release proposal,and0B when composed with checked constructor
moves. Actual RSS/VRAM and elapsed improvement remain unknown. A corrected
Rust temporary-scope model raises the prior native-decode+move+release
current+next+four-pin envelope1.618387->1.727766GiB. These are public-payload
models,not full-model memory. The prior results are preserved and qualified.

New independently verified full-stack proofs/passes/positions: **0/0/0**;
device/context none. Steady-state and total-workload proved rates,startup
fraction,witness/proof/serialization/verification clocks: unmeasured.
Carried owner diagnostic only:8B T128,32 blocks,one16-thread CPU pass,GPU off,
478.737s (0.267370 positions/s); prove393.785s includes witness98.348s.
Fresh verify42.709s plus13.681s initial load; isolated serialization and
startup unknown. Researcher did not reverify it. No new target credit.
No long-context prefill,resident proof series or decode ran. Attention can
grow quadratically with context; larger workloads remain allowed. Private8B
>=50 proved positions/s on one RTX5090 or named high-end GPU remains unachieved.

Seam:load_layer_mode after aw/fw padding. Next local: separate each decode/pad
call's statement scope; owner owes native gates and exclusive allocation/clocks.
Whole-prover GPU and verified fixed-context resident1/2/4/8 remain first.
Six LIVE primary records cover older streaming-ZK setup,Efficient Sumcheck,
Chimera Oct16,hardware locality/PIM,and Rust lifetimes. Exact dates,license
limits and access failures are retained. No external performance reproduced.

[Experiment](experiments/public-matrix-split-release-20261019/README.md),
[handoff](handoffs/20261019-public-matrix-split-release.md),
[dated report](progress/20261019T211854Z-fff84a98.md).
Only research changed;no masks/private openings reused. Saved reports do not establish delivery.
