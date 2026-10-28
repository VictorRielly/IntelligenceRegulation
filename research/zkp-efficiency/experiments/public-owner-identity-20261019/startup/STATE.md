# ZKP efficiency explorer — durable state

Cycle0084 COMPLETE:`20261019T161854Z-4bc2599e`,2026-10-19 UTC.
Next cycle no earlier than **17:18:54 UTC**. Deadline16:38:54 UTC.
[Dated report](progress/20261019T161854Z-4bc2599e.md).
Startup memory:experiments/public-setup-lifetimes-20261019/startup/.

**No speed improvement measured.** NTT already shared across blocks and GPU
uploads already cached. Candidate CPU table owner removes2R->1 constructs
only;T128 backing524560B,no extra device upload avoided. CS8 and sealing
layout deduplication retained. Whole-stage Shape-only cache fails IO rows;
incoming/outgoing internal starts34/32 atT128. Full Shape !=public layer key:
31 real public base-shape layers have6 distinct table-key combinations.

NEW public residency result: partial LRU1..31 layers thrashes repeated ordered
32-layer scans (0hits). Fixed public pinned4 gives60/512 synthetic request
hits at8passes,0.906778GiB payload. Per block243411456B,all32=7.254227GiB
before proof buffers. Unpadding FFN undercounts0.75GiB. No native cache or
actual load/peak/runtime gain; source/cost policy handoff only.

Main PASS66129 checks/13 controls,24 NTT+6RS fixtures,32768twiddles,
222IO checks,35 Shape descriptor mutations. Independent audit1400/
5controls,24DFTs+32new coefficients. Main/audit0.345/
0.096s,peak24872KiB,one nice19 CPU0,
CoreUltra9 185H,Python3.10.12,WSL2;59s/512MiB caps. Fifteen pins recheck,
11sources match reviewed R8 manifest. No build/GPU/install/foreign execution.
[Handoff](handoffs/20261019-public-setup-lifetimes.md). Main/Claude integrates;
no Rust/CUDA patch or merge. Native CS/H-1/fresh RNG/endpoint/PCS/finals/
receipt/joint privacy gates still required. R8 soundness accepted;not privacy.

Ranked hypotheses (full experiments/public-setup-lifetimes-20261019/hypotheses.json):
1.Owner whole-prover GPU+independently verified fixed-context resident1/2/4/8.
2.New fixed public pinned owner across sealing/proving;complete model/manifest/
layer/table/geometry identity,immutable bytes and honest peak/copy accounting.
3.Owner bounded same-attempt witness retention;prior cycle0016 negatives stand.
4.Owner D30 architecture,all gates/D32 fidelity retained.
5.CPU NTT/layout residency demoted;clocks unisolated.
6.Geometry-only/whole-stage Shape keys and partial LRU eliminated in tested scope.

Next local: build a public-only immutable-layer-owner trace with
synthetic contents and full model/manifest/layer/table identity, then test
fixed pinned admission against stale exports, layer-range/base changes,
cross-model swaps and peak lifetime overlap. Retain every native CS/H-1 check;
compare a streaming no-cache oracle. First derive where a retained Arc can
replace reconstruction at seal_and_record and BlockCache::get. Do not launch
a model build/proof or repeat the disproven partial-LRU policy. Owner request:
isolate public construction, CS rechecks, witness and serialization clocks,
then independently verify fixed-context resident1/2/4/8 workloads under locks.

Carried owner R8 CPU 8B diagnostic, T128 /32 blocks /one16-thread pass,
GPU off, n=1: total478.737s, diagnostic128/478.737=0.267370
positions/s. Prove_run393.785s includes witness hand-over98.348s, itself
including block loads17.595s. Sealing wall84.824s includes overlapping load
tasks27.151s and witness tasks80.897s. **The JSON load_seconds field is
seal.load_s only**, not all loads. These nested/overlapped clocks must not be
added. Receipt922711264B. Fresh verify42.709s plus initial load13.681s;
recheck34.395s plus load10.739s. Verification control time is separate from
the basic verify clock. Startup fraction, isolated serialization and steady
slope are unmeasured. Researcher did not reverify any receipt.

Seven LIVE records455->462;older cuZK newly assessed;
StateSync/P3 October updates,ICICLE lifecycle refreshed. Historical inspected
cuZK88e3295... README-only;actual license fetch failures qualified. Pipelonk
403/Zenodo access blocker,no bypass. No external gains reproduced.

New target proofs/passes/positions **0/0/0**, device none. Target
steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No long prefill, resident proof series or
decode ran. Synthetic pass counts are constructor requests, not proved work.
Larger workloads remain allowed; attention may grow quadratically. Complete
private8B / >=50 proved positions/s on5090/named high-end GPU remains
unchanged/unachieved.
Only research files written;runtime/production/Git/receipts/calibration/
safety/instructions/reviewer files untouched. Saved reports do not imply
message delivery. Checkpoint2026-10-19T16:33:39.401761+00:00.

Final validation PASS: 56 consistency checks, 55 experiment artifacts; all 15 source/evidence pins unchanged, prior findings/source prefixes preserved. 2026-10-19T16:34:25.891307+00:00.
