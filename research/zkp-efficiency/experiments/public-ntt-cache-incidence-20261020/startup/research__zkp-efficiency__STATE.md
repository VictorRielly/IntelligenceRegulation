# ZKP efficiency explorer — durable state

Cycle0114 COMPLETE: `20261020T221854Z-d390b45f`. Checkpoint UTC `2026-10-20T22:28:41.218430+00:00`.
Started22:18:54UTC; deadline22:38:54UTC. Next cycle no earlier than23:18:54UTC.
Evidence: `experiments/dyadic-dd-shards-20261020/`; early checkpoint and prior state retained. Source ledger702->709;28ranked hypotheses preserve earlier negatives.

**No proving improvement measured.** A public DD union128+32 at synthetic HIGH/S12/f_e9/F_P12/e_s2 counts803,176,448->766,607,360 A+Hwords atT512 (-4.553058% versus cap256,-8.337578% versus direct). Exact156 slots require4shards and cost more. T128128+32 still+4.928441% versus direct. Splitting248 values loses; raw55-value tiny shards violate no-lift. Minimum per-shard cap4/2 atT128/T512. These are conditional layout/arithmetic results, not a native profile or speed measurement.

Every extra T512 shard has11A+7H claim sites,36row-width fresh mask words (9MiB),3PCSgroups,1slot,+2Mrows. Use one S tuple helper over a public union, separate committed histogram/table helper per shard, every table helper negative in one value0 sum. All slots constrained/inverted, unused included. Preserve row-Sum/slot17/Ht and M_dd-inA before challenges. New layout/metadata, whole-run security and joint privacy remain unvalidated.

Existing b7 exponent schedule is HIGH sensitivity only:32-layer T512 per-layer singles25,575,817,216->sharded24,466,554,880 words (-4.337153%; -8.580006% versus direct); selected dictionary payload peak768->480MiB. T128 stillregresses4.649333%; public direct/DD selection unchanged. These partial payload peaks exclude other owners, masks, PCS,witness,histogram,pool,driver and transfer. Conditional body deltas exclude new schema metadata. Actual HIGH/D32 tables and whole GPU clocks missing; end-to-end affected fractionf unknown, even free removal ceiling1/(1-f) before new costs.

Probe53,680checks/60synthetic rows/19,200positions/16controls PASS; independent8,128checks/20,480public entries/3,360positions/13pins PASS. Probe0.146128s/17,640KiB; audit0.035228s/18,480KiB. OneCPUworker,nice19,firstallowedcore;59sCPU/alarm,60sparent,512MiBAS,64MiBestimate. Initial audit failure retained: count moved between identical0entries was no mutation; corrected distinct-value control rejects. No native proof or external code ran.

11native LIVE queries/7source records; known TaSSLE/LogUp-GKR, current OpenVM/GKR and October16 Chimera refreshed. New older Jolt lookup-semantics verification source screened. MIT body and exact OpenVM release commit inspected; full release date unknown. TaSSLE PDF403 and initial LICENSE404 recorded; correct LICENSE-MIT path succeeded. No author speed reproduced.

Top3 remain whole GPU/resident1/2/4/8, DD fidelity/context scaling and complete phase/capacity clocks; all-elevenFZC A/B4; tested shard union5. Prior cap/mode schedule and all negative results preserved. Next local: Read the current native CUDA PCS/NTT setup and public-cache call sites alongside prior pool/lifetime negatives. Count once-per-process versus per-proof root/twiddle/index preparation and retained capacity for fixed-context resident1/2/4/8 passes. Use an independent event oracle with cache-off, shape-change and eviction controls, charging fresh masks on every proof. If already cached or negligible, preserve the negative and rerank; launch no GPU/build work.

Owner priorities remain complete high-end GPU exclusive/enclosing phase and capacity clocks, independently verified fixed-context resident1/2/4/8 workloads, actual HIGH/D32 fidelity tables and DD context scaling, and the all-eleven FZC compiler A/B under shared build/heavy locks. No such job was launched here.

Review handoff `handoffs/20261020-dyadic-dd-shards.md`; research interfaces in probe.py/audit.py. Main/Claude reviews/integrates; no merge.

New completed independently verified full-stack proofs / passes / positions: **0 / 0 / 0**. Actual model context and accelerator: **none**. Research device: **Intel Core Ultra9 185H CPU, no GPU**. Witness, proof, serialization and verification clocks: **unmeasured**. Startup duration/fraction, steady-state and total-workload proved rates: **unmeasured**. No long-context prefill, repeated resident-model pass or decode ran. Synthetic row lengths32/128/512 and counted T128/T512,32heads,head_dim128,32-layer layouts are diagnostics, not proved positions. Larger workloads remain permitted; dense attention can grow quadratically with context. The complete private8B >=50 proved positions/s target on RTX5090 or another named high-end GPU remains unachieved.

Historical CPU diagnostic carried without rerun/reverification: non-DD8B T128,32layers,one16-thread CPU pass,GPUoff; total478.737s=0.267370positions/s. prove_run393.785s includes witness98.348s and load17.595s; seal84.824s has overlapping subwork. Receipt922,711,264B; fresh verify42.709s+public load13.681s; recheck34.395s+load10.739s. Isolated serialization,startup fraction and steady slope unknown. This is not a high-end GPU baseline.

No production, reviewer, calibration, instruction, receipt, Git or runtime edits; no native build, GPU, installation, downloaded-script execution, external write/message, purchase or escalation. D30 N-r9-a/b, DD privacy gate, D32 and narrow D33/D34/D35 scopes remain binding. Every per-shard/per-proof mask and opening stays fresh; no security/profile acceptance is inferred. Main/Claude reviews and integrates; no merge. Saved reports are durable files, not evidence of external delivery or supervisor liveness.

Final evidence-integrity audit:443checks PASS; original702 source records and prior findings prefix preserved; agenda/project pins unchanged and sensitivity counts independently reaggregated. Finished UTC 2026-10-20T22:30:00.866956+00:00.
