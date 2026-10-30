# ZKP efficiency explorer — durable state

Cycle 0128 COMPLETE: `20261028T215649Z-43c1f18d`.
Started 2026-10-28 21:56:49 UTC; checkpoint 2026-10-28T22:10:28.423971+00:00.
Deadline 22:16:49 UTC; next cycle no earlier than 22:56:49 UTC.
Prior memory, 821 sources and cycle0127 results/41 hypotheses are preserved
in `experiments/periodic-sc-tab-20261028/startup/`.

No proving gain measured. A periodic public SC_TAB descriptor passes 50,042
synthetic checks: six complete polynomial cases n8/9/10, 54 rounds,
216 coordinates, 64 original-cube terminals, 48 extension-polynomial checks,
every restricted public row and 24 controls. Descriptor-only n13/14 checks
include full Fp2 points and a zero leading challenge. The separate integer /
schoolbook expanded original-cube oracle is also locally authored. No native
CFS, transcript, PCS, receipt, refusal, privacy or GPU evidence was produced.
Native terminal e0/e1 refusals remain source-audited obligations.

Model: 3.977046 s /16,400 KiB RSS. Source audit: 64 checks, 0.011229 s /
15,840 KiB RSS. One nice19 Core Ultra9 185H worker; 45-second CPU/alarm,
50-second parent, 256 MiB AS, 96 MiB estimate. Checking clocks only.
Final evidence audit: 334 checks PASS, 63 immutable artifacts, nine native
pins unchanged; prior sources/findings/hypotheses preserved.

R12 T128 L16384: three public factors' logical payload 786432 ->12288 B;
public fold lerps 49149 ->765. Full cube, private/equality/support tables and
generic polynomial work remain. Metadata/dispatch/index/state costs added;
no native peak/capacity/time saving measured. Constructor arithmetic savings
overlap cycle0127 tiling and are not additive. The 32-block removed payload
24772608 B is cumulative, not peak. R12 T32/T64 use L8192. Selected R13
LOW+h24/per-group tables and unregistered T512 are excluded. Rust sketch is
uncompiled/unapplied, parked for owner timing and gates.

Nine source records appended (830 total), eleven LIVE batches retained.
All 41 prior hypotheses retained, ranks1/41 refined, rank42 added. Original
CMT2011 source newly inspected; modern sumcheck/SP1 references refreshed.
Commit429/license cache-miss/wrong-URL404 blockers and exact date/license/
inspected-versus-exposed commit qualifications retained. No author timing
reproduced. See experiment source-records.jsonl and research sources.jsonl.

Next LOCAL: inspect actual CFS/extension source and previous0039/0040 masked
coverage; if absent, test original mask basis, terminal/private claim order,
public zero extensions and refusals at SC_TAB. Preserve the exact cube,
private obligations, fresh challenges/masks and future-pair checks.
Next OWNER: exclusive constructors/public folds/SC_TAB/enclosing clocks;
if material, native golden/transcript/refusal/privacy gates, then verified
fixed-context resident1/2/4/8 workloads under shared locks. No heavy job queued.
Top3: whole-prover GPU/resident workloads; DD-context/fidelity scaling;
complete phase/capacity telemetry. Next source rotation: GPU NTT/commitments,
quantization/arithmetic and composition, guided by measured bottlenecks.
Handoff: `handoffs/20261028-periodic-sc-tab.md`.

New independently verified full-stack proofs/passes/positions: 0/0/0.
Model context/accelerator: none. Witness/proof/serialization/verification,
startup/prefill/startup fraction, proof latency/bytes, steady/total rates:
unmeasured. No long prefill, resident proof series or decode. Larger workloads
allowed; attention can grow quadratically. Private8B >=50 proved tokens/s
on RTX5090 or another named high-end GPU remains unachieved.

Historical diagnostic carried only, not rerun/reverified: nonDD8B T128/L32,
one16-thread CPU pass, GPU off; total478.737 s =0.267370 positions/s.
prove_run393.785 s includes witness98.348 s /load17.595 s; seal84.824 s
overlaps. Receipt922711264 B; fresh verify42.709 s +load13.681 s. Startup
fraction, isolated serialization and steady slope unknown.

Only research outside runtime written. No native build, GPU, installation,
Git, external write/message, production/reviewer/calibration/receipt/gate/
instruction mutation. Saved reports do not establish delivery or liveness.
