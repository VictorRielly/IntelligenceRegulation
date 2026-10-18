# ZKP efficiency progress

Cycle 0071 — `20261018T002105Z-32d7e4fc`, 2026-10-18 UTC.

**No proving speedup found.** A Rust adapter combines the known previous
fold with the next weighted lookup round. All 132 synthetic fixtures match
dense and prior references; independent audit passes 7,795 checks. E/S/V
terminals, cubic masks and challenge order remain intact. Main run 1.959 s
including compilation, one CPU thread; no native proof or GPU. Counters show
no added field multiplications. [Unapplied candidate](handoffs/20261018-pending-fold-weighted-round.md).

The prior T32 core row census reads 25% fewer logical values, about 20% fewer
reads+writes; added column reads/subtractions remain. These are counts, not
measured DRAM or speed. Full lookup, masking, links, GKR and PCS costs remain
open. The tested adapter drains the final fold before immutable finals.

Latest carried R5b 8B T128 CPU baseline: one cold 32-block pass, fresh verify
and 11 controls. App 606.598 s / process 606.728 s, diagnostic 0.211 positions/s.
Seal 105.287 s = 17.357%; sealing witness 103.349 / load 36.570 s overlap.
Inclusive prove 501.126 s includes 32 rebuilt witnesses at 122.694 s and
reload 21.176 s; serialization unisolated. Fresh verifier load 14.126 s +
check 43.902 s. Steady slope, full startup, prefill and lag/drain remain unknown;
trained-shape privacy acceptance is open.

Owner GPU kernel design and complete resident-workload slopes remain first.
Six LIVE primary records added: P3 state/IDFT, ICICLE, older NTT OT, Hermes FPGA
and instruction-roofline scope. Next local: exact native late-stage root-product
oracle and cost census, preserving root/shift/padding invariants.
[Dated report: clocks, evidence, rankings, limits](progress/20261018T002105Z-32d7e4fc.md).
New target proofs/passes/positions **0/0/0**. No long prefill, resident repeats
or decode. >=50/s private 8B on a named high-end GPU remains unachieved.
Production/runtime/Git untouched. Saved reports do not establish delivery.
