# ZKP efficiency explorer — durable state

Cycle0107 COMPLETE: `20261020T151854Z-beab78ce`. CheckpointUTC 2026-10-20T15:32:41.204961+00:00.
Deadline15:38:54UTC; next cycle no earlier than16:18:54UTC.
Evidence: experiments/lookup-tiled-prefix-20261020/. Prior memory/docs preserved
in startup; AGENDA, ledger, latest0106 results and current project context read.

No proving speed improvement measured. Budget-adaptive32MiB destination cap
reduces selected R9 8B T128 arrays68.030->36.022MiB. Nine leaf-layer services
add18,874,368 reads (+6.416/+6.885% nonDD/DD), tree-node/fold counts unchanged.
Fixed-q1 has same peak but5.740/5.770x treework vs3.870/3.885x baseline.
Adaptive16MiB gives20.018MiB at4.052/4.080x treework. No net memory/time/fit
claim; all private GKR/CFS/PCS/native backing/source costs still excluded.
Counted-onlyT512 cap32 gives36.022MiB but substantial source/rebuild cost;
cap8 misses with qmax4 and is explicitly false. No T512 profile admitted.

Final probe2934checks/225tiny consumers/14controls;
independent240cost schedules/1680mutations/70original-MLE
cases/causal scan checks/9pins. F65537 only. All original rows,
terminals/MLEs match independent reference; factorized equality/0/1 exact.
One thread/nice19/first allowed core/59sCPU+alarm/60sparent/512MiBAS;
estimate64MiB. Probe2.304326s/31796KiB;
audit0.095858s/16308KiB. Initial direct-equality
version retained; final successful refinements, no failed experiment.

ElevenLIVEqueries/eightrecords631->639. New older2012 GPU GKR two-layer
residency/transfer filter; Plonky3 docs/source/release alignment caveats and
fetch failures explicit. Full release SHAfe5e46d755b8a7d9069778361e21b33e5978b377
inspected, Cargo-version change only. Apache2.0 text inspected; no external
code run or author gains reproduced. ChimeraOct16 primary date refreshed.

Twenty ranked hypotheses retained; top3 wholeGPU+resident1/2/4/8, DDcontext
scaling, actual capacity/exclusive clocks. Rank7 materially refined to
public-budget adaptive streaming. FZC compiler A/B remains ahead. Handoff:
handoffs/20261020-lookup-tiled-prefix.md. Main/Claude reviews; no nativepatch.

Next local: port this consumer to exact native Goldilocks Fp2 arithmetic
with a synthetic ordered U8 reader using the same per-attempt denominator
cache/refusal rules. Differentially check every original helper term, all
sample rows and terminal MLEs, including zero denominators at zero multiplicity.
Keep source arrays immutable; never cache inverse results across challenges.

Next owner: complete GPU phase/capacity clocks and verified fixed-context
resident1/2/4/8 workloads, DD context scaling and all-eleven FZC compiler A/B
under shared locks. Count only independently verified complete receipts and
retain fresh masks. Main/Claude reviews any integration; no merge here.

New independently verified full-stack proofs / passes / positions: **0 / 0 / 0**.
Actual model context/device: **none**. New witness, proof, serialization,
verification, startup duration/fraction, steady-state and total-workload rates:
**unmeasured**. CPU clocks here measure research checking only. No long-context
prefill, resident-model pass or decode was performed. Larger workloads remain
allowed; increasing context can increase attention work quadratically.
Private 8B >=50 proved positions/s on RTX 5090 or another named high-end GPU
remains unachieved.

Carried historical diagnostic, not rerun or independently reverified here:
non-DD 8B T128, L32, one 16-thread CPU pass, GPU off; total478.737s =
0.267370positions/s. prove_run393.785s encloses witness98.348s and load17.595s;
seal84.824s includes overlapping subwork. Receipt922711264B; fresh verification
42.709s + public load13.681s; recheck34.395s + load10.739s. Startup fraction,
isolated serialization and steady slope unknown. This is not a high-end GPU result.

R9N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 remain. LOW fidelity
proposal excluded. Only research excluding runtime written; no production/
Git/build/GPU/install/external writes/messages/purchases/escalation.
Reports do not establish external delivery.
