# ZKP efficiency explorer — durable state

Cycle0089 COMPLETE: `20261019T211854Z-fff84a98`,2026-10-19 UTC.
Next cycle no earlier22:18:54 UTC;deadline21:38:54 UTC.
Startup snapshots:experiments/public-matrix-split-release-20261019/startup/.

**No speed improvement measured.** Split public raw-matrix release matches 78 accepted synthetic full/reload paths over48 fixtures;18 denied RoPE paths preserve their modeled refusal. 6720 mutation-path controls pass. Main 10625 assertions; independent audit 10238 assertions,6720 first-error checks and1404 corruption controls. Early matrix/table release and digest-copy-only controls each catch78 bad paths;78 changed-source reload comparisons still differ from the sealed digest surrogate. Seed2026101989. Main/audit 5.322207/0.195933s, peaks 40556/34492KiB, one nice19 CPU0, Core Ultra9 185H, Python3.10.12,WSL2;59s CPU/wall and512MiB AS caps. These clocks measure synthetic validation, not loader/proving speed.

[MODEL] At8B T128, nine raw matrices total218112000B. Releasing them after aw/fw padding lowers the borrowed-constructor reload payload envelope705199616->638116864B, saving67082752B (63.975098MiB). With current+next+four distinct pinned public blocks,1.790241->1.727766GiB. With16 hash workers,sealing948346368->730231808B (208.010254MiB), **0B incremental improvement beyond prior postconstructor release**. Split release adds0B peak saving when combined with prior checked moves, for both sealing/reload; unchanged padding or record hashing wins. Direct-byte+move+release sealing remains1.586862GiB. These are enumerated public payload envelopes, not actual RSS/VRAM, full model memory or elapsed savings; exclude allocator/page cache,JSON,thread stacks,private witness/proof/device state and extra evicted live leases.

Correction: Rust statement scopes allow all four `fw` decode temporaries to coexist:176164864B (168.003906MiB), rather than58720256B max-single. This adds117444608B (112.003906MiB) to the native-decode padding phase in the old model. The prior cycle's native-decode+move+release1.618387GiB envelope is superseded by1.727766GiB. Direct-byte variants and baseline sealing/reload maxima above are unaffected. Initial results before this correction are retained under before-temporary-scope-correction/. Semantic lifetime is source/reference-derived; native compiler/allocator behavior has not been measured.

Carried owner R8 diagnostic only: trained8B T128,32 blocks,one16-thread CPU pass,GPU off,n=1,total478.737s =>0.267370 positions/s. Prove_run393.785s contains witness hand-over98.348s,including17.595s block-load tasks. Sealing wall84.824s contains overlapping load/witness tasks27.151/80.897s; do not add nested/overlapped clocks. Receipt922711264B. Fresh verify42.709s plus initial public load13.681s; recheck34.395s plus10.739s load; guard165.982s includes controls. Startup fraction,steady-state slope and isolated serialization remain unmeasured. Researcher did not independently reverify this receipt; no new target credit.

New independently verified full-stack proofs/passes/positions: **0/0/0**; device none,context none. Steady-state and total-workload proved rates,startup fraction,new witness/proof/serialization/verification clocks: unmeasured. Synthetic cases are not proof passes. No long-context prefill,resident proof series or decode ran. Larger workloads remain allowed; attention may grow quadratically with context. Complete private8B >=50 proved positions/s on one RTX5090 or a named high-end GPU remains unchanged and unachieved. No private masks,commitments or openings reused.

Ranked queue (hypotheses.json):
1.Owner whole-prover GPU and verified fixed-context resident1/2/4/8.
2.Prior checked public constructor transfer,native gates/clocks pending.
3.Tested split raw9 release before constructors;reload capacity only.
4.NEW per-call decode temporary statement scopes,next local test.
5.Prior postconstructor release,sealing only.
6.Direct-byte padding.
7.Guarded public owners with complete live lease accounting.

Owner: review the unbuilt one-method diff,then use shared build/heavy locks for native full/reload malformed/paired-first-refusal/record/receipt/CS/H-1 gates and exclusive allocation/HWM/enclosing clocks. Whole-prover GPU plus independently verified fixed-context resident1/2/4/8 workloads remain first. Next local experiment: split each aw/fw padding call into its own let statement to bound decode temporary overlap,with an event-lifetime reference and byte/refusal controls; recompute full-loader maxima and interactions. No repeated key-only/LRU/registry-only caching or cycle0027 digest-cache study.

Six LIVE primary records appended493->499: newly assessed older Streaming Zero-Knowledge Proofs (v1 Jan2023,v2 May2024; separate verifier/setup model),Efficient Sumcheck ownership/streaming history and failed license/release/commit fetches,Chimera Oct16 residency revision,NTT/sumcheck locality,HBM-PIM hardware scope,and Rust statement temporary scopes. No external performance reproduced or foreign code executed. See source-records.json/search-log.md for exact URLs,verified dates,license limits and429/Cache-miss blockers.

D33 remains trained TinyLlama T32 pg_rot1 CPU R7 only; R8/8B/GPU/new-file changes need their own gates/re-pin. D27 soundness,D32 fidelity and D30's unbuilt construction status remain binding. Public last-use changes authorize no P3 cache. Only research written;runtime/production/Git/receipts/calibration/safety/instructions/reviewer files untouched. No installs,builds,GPU jobs,external writes/messages,purchases or escalation. Saved reports do not establish message delivery.

Handoff:handoffs/20261019-public-matrix-split-release.md.
Checkpoint 2026-10-19T21:33:01.766544+00:00.

Final consistency/provenance gate PASS: 319 checks,18 unchanged source/evidence pins,14 frozen R8 manifest matches,two patch hunks replayed in memory only. Direction documents unchanged during cycle. No native compile/proof. Final checkpoint 2026-10-19T21:35:12.285010+00:00.
