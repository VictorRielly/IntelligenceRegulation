# ZKP efficiency explorer — durable state

Cycle 0127 COMPLETE: `20261026T192925Z-2a61ec3c`.
Checkpoint UTC: 2026-10-26T19:43:01.123699+00:00. Started 19:29:25 UTC; deadline 19:49:25 UTC.
Next cycle no earlier than 20:29:25 UTC. Prior memory, findings, 814 sources
and cycle 0126 result/hypotheses are in
`experiments/lookup-row-tiling-20261026/startup/`.
Seven source records appended (821 total); all 39 hypotheses retained,
1/14 refined, 40/41 added. Ten native LIVE batches retained. Findings appended.

No proving gain measured. Fresh per-call 256-row exp/act encoding followed
by output-prefix tiling passes 3,353 synthetic checks / 204 cases / 2,264,184
entries, 1,025 copy schedules, 48 malformed adapters, 256 zero-alpha cases,
30 base-point cube MLEs and 13 control types. Separate integer/direct-cube
oracle; both implementations authored locally. No native full-Fp2-point,
transcript, CFS, PCS, refusal, privacy or receipt evidence.
Model 9.169534 s / 56,076 KiB RSS. Audit 158 checks / 0.010463 s / 16,976 KiB
RSS; nine native pins unchanged. One nice-19 Core Ultra 9 185H worker,
30-second CPU/alarm, 35-second parent, 256 MiB AS, 96 MiB memory estimate.
Diagnostic clocks only.

R12 T128 L=16,384 pair: source Fp2 products 32,768 -> 512; additions and
signed conversions 65,536 -> 1,024. Same 524,288-byte output. Proposed Rust
has no separate prefix scratch or explicit zero fill. Adds 516,096 copy-read
bytes and removes 161,280 raw-table-load bytes: 354,816 more logical reads.
No peak reduction or hardware speed claim. H's 256-row wrappers save no work;
full-table inversions/zero checks stay. Existing public moves avoid cloning.
A 32-block argument removes 1,032,192 source products/adds 16,515,072 copy-read
bytes; prove and each verify are separate invocations. R12 T32/T64 L=8,192,
T128 L=16,384; no admitted T512 or selected R13 LOW+h24/per-group tables
inferred. Uncompiled/unapplied patch parked pending exclusive native clocks.

New older Celer paper/prototype screened: BN254/mcl Dory prototype explicitly
omits blinding, failing private compatibility. No adoption/import/execution.
Paper July16/revised July21,2026; code commit/license/update unknown.
Recent SP1 v6.10.0 release commit inspected; exact GPU crate rendering/source
inaccessible or inconsistent. TenseUp primary refresh blocked; no bypass.
Exact URLs/dates/claims/access issues in sources.jsonl. No timing reproduced.

Next LOCAL: actual SC_TAB periodic public descriptor, using prior 0039/0040
public-driver results. Read current Tab/run_slot public extensions, terminal,
full-cube and bit-ordering rules. Test full Fp2 points versus original cube,
zero leading challenges, wrong suffix axis, zero extension, malformed lengths
and pad-zero refusals. Charge descriptor/dispatch/fresh 256-row encoding;
no private skipping, future-pair weakening or mask reuse.
Next OWNER: exclusive exp/act constructor + SC_TAB + enclosing proof clocks,
compiler/golden/refusal/privacy gates if material, then independently verified
fixed-context resident 1/2/4/8 workloads under shared build/heavy locks.
Top three owner priorities unchanged; no heavy job queued.
Handoff: `handoffs/20261026-fresh-lookup-row-tiling.md`.

New independently verified full-stack proofs / passes / positions: 0 / 0 / 0.
Actual model context / accelerator: none. Witness/proof/serialization/
verification, startup/prefill/startup fraction, proof latency/bytes,
steady-state and total-workload rates: unmeasured. No long prefill, resident
proof series or decode. Larger workloads allowed; attention can grow
quadratically. Private 8B / >=50 proved tokens/s on RTX5090 or a named
high-end GPU remains unachieved.

Historical diagnostic, not rerun or reverified: nonDD 8B T128/L32, one
16-thread CPU pass, GPU off, total 478.737 s = 0.267370 positions/s.
prove_run 393.785 s includes witness 98.348 s / load 17.595 s; seal 84.824 s
overlaps. Receipt 922,711,264 B; fresh verify 42.709 s + load 13.681 s;
recheck 34.395 s + load 10.739 s. Startup fraction, isolated serialization and
steady slope unknown. No high-end GPU or 8B privacy acceptance follows.

Only research outside runtime written; no native build, GPU, installation,
Git, external message or production/reviewer/calibration/receipt/gate/
instruction mutation. Saved reports do not establish delivery or liveness.

Final evidence audit: 731 checks PASS; 50 immutable artifacts and 9 tested current native pins match. Two patch hunks apply in memory only. All 814 prior sources, 39 prior hypotheses and prior findings preserved. Final checkpoint UTC: 2026-10-26T19:44:02.280925+00:00.
