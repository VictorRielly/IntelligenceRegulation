# Cycle0091 — observed Vec allocation scopes

Run `20261019T231854Z-28e6b36b` — cycle0091 — 2026-10-19 UTC.

**No speed improvement measured.** This cycle closes one local evidence gap:
the previous statement-scope finding also holds for observed original Vec
allocations in a scalar analogue, without a custom decoded Drop wrapper.
It does not establish production/Rayon behavior or an elapsed improvement.

Rust1.90.0,edition2021,no dependencies,optimization levels0 and3,one codegen
unit. Eight synthetic shapes (identity/scattered head slots,odd FFN widths,
padding and both inner-map branches),five variants each,80 observed regions.
Original `Array::i8s() -> Vec<i8>` body is copied exactly from pinned R8;
the destination-row pad analogue replaces Rayon iteration with serial rows.
The wrapper forwards allocations to System and records pointer/size/phase
events into a fixed32768B atomic log. Raw inputs and spec maps are prepared
outside regions;outputs/logs are serialized after tracking stops. No
black_box,custom decoded Drop,per-region timing or target-size allocation.
The log itself does not heap-allocate. Compiler elision/merging is permitted
by Rust;these results describe these binaries only,not a language guarantee.

Largest proxy:qh32,kvh8,head_dim4,d128,f448,dp128,fp512,seed2026101991.
This reduces target widths by32;it is NOT a128-token proof or8B allocation.

| Variant | Peak live requested B | Peak decode B | Allocations | Total requested B |
|---|---:|---:|---:|---:|
| Grouped aw/fw statements |419200|172160|36|482848|
| Separate result statements |304384|57344|36|482848|
| Reference-binding negative |460288|213248|36|482848|
| Direct-byte control |247040|0|27|269600|
| Separate results plus clone negative |475648|57344|45|720672|

Opt0 and opt3 match all rows and all output bytes. Local scope saving114816B;
neither allocation count nor aggregate volume changes. All8 fixtures show a
strictly lower region peak. Retained output237824B in the largest proxy is
unchanged. Nine decode allocations remain;the direct-byte control removes
them but still carries the previous unmeasured cast-loop/native cost risks.
The reference-binding and extra-copy variants are value-equivalent and are
correctly rejected when presented as the intended scope implementation.

Independent audit uses a destination-indexed inverse-head-map byte oracle,
pointer-owned allocation replay and separate closed-form phase envelopes.
**1389 checks**,720 vector comparisons,720 one-byte corruptions,240 event
mutations (wrong size,missing allocation,missing free),32 reference/clone
masquerades pass. This is an authored single-agent differential audit,not an
external review. Original source/refusal/record/receipt gates remain owner work.
All byte fixtures and output SHA256s are retained. Audit0.856544s internal,
0.897139s process,18316KiB own HWM (runner child accounting18492KiB).
Compile opt0/3 processes0.568761/0.781899s,HWM136832/138848KiB;
probe processes0.026704/0.005584s,HWM8744/8556KiB. These process clocks include
synthetic output writing and instrumentation,not timed padding improvements.
One nice19 CPU0 affinity on CoreUltra9 185H/WSL2. Probe reports1 thread;
compiler helper-thread count unobserved,one CPU affinity/codegen unit.
Every leaf59s CPU/wall alarm and512MiB AS;no production/native build or GPU.

Baseline/eliminated work/added costs:grouped native5+4 argument temporaries
versus one owned padded result per statement. No decode,copy,pad,IO,hash,
constructor,witness or proof operation removed;only shorter requested-allocation
overlap,with the same frees earlier. Native optimizer,allocator bookkeeping,
threadpool and enclosing critical-path changes are unmeasured.

[MODEL,carried]8B T128 pad envelope638116864->520672256B (112.003906MiB).
Standalone original borrowed full/reload loader peak saving remains **0B**,
because constructor/hash phases dominate. With prior checked moves+post raw
release,current+next+four distinct pinned public blocks1.727765560->
1.618386745GiB. Direct-byte+move+release remains the prior lower1.586862GiB.
These are public payload models,not actual allocator/RSS/VRAM or complete
model fit. No additive peak savings;exclude page cache,allocator slack,JSON,
thread stacks,private witness/proof/serialization/device and extra live leases.
This cycle strengthens only the scalar allocation premise,not these full-loader
or target-size measurements. Falsify promotion on native bytes/first-refusal/
record/receipt/CS/H-1 divergence,already-elided native overlap,no lower actual
whole-loader peak,or enclosing elapsed regression.

Carried owner R8 diagnostic only:8B T128,32 blocks,one16-thread CPU pass,
GPU off,n=1,total478.737s=>0.267370 positions/s diagnostic. Prove_run393.785s
contains witness98.348s,including17.595s block-load tasks. Sealing84.824s
contains overlapping load/witness27.151/80.897s. Commit121.32s/31.0% of
summed391.9s block walls is a larger priority. Receipt922711264B;fresh
verification42.709s+13.681s initial load,recheck34.395s+10.739s load;
guard165.982s includes controls. Do not add nested/overlapping clocks or call
sealing pure startup. Researcher did not reverify this receipt. Even deleting
ALL load tasks leaves433.991s:at most1.103104x and0.294937 positions/s on that
CPU diagnostic,an overbroad bound for this candidate;no high-end GPU forecast.

New independently verified full-stack proofs/passes/positions **0/0/0**;
device/context none. New witness/proof/serialization/verification clocks,
steady-state and total-workload proved rates,startup fraction **unmeasured**.
No long-context prefill,resident complete-proof series or decode ran. Larger
workloads remain allowed;attention can grow quadratically with context.
Complete private8B >=50 proved positions/s on RTX5090 or another named
high-end GPU remains unchanged and unachieved. No private mask/commitment/
opening reuse or privacy weakening. D33 covers only the accepted TinyLlama
T32 pg_rot1 CPU R7 artifact;8B,R8,GPU and next-token stages need their own
scope/re-pin. D27 whole-run security,D32 fidelity and D30 unbuilt status stand.

Integration seam:TrainedExport::load_layer_mode aw/fw statements in frozen
R8 hashline/src/private_block/trained_block.rs (~1037). The prior
review-only-statement-scopes.patch is copied and remains UNBUILT/UNAPPLIED;
no new production diff. Native owner must review/rebase with checked
ownership/raw-release changes,then run full/reload malformed/paired-first-
refusal/record/receipt/CS/H-1 gates and exclusive allocation,HWM and enclosing
clocks under shared build/heavy locks. No merge here.

Queue:hypotheses.json retains prior negatives.1 owner whole-prover GPU and
verified fixed-context resident1/2/4/8;2 NEW device-pool live-capacity audit;
3 checked public constructor transfer;4 tested scopes;remaining raw releases,
direct bytes and public-owner guards are capacity candidates awaiting native
evidence. New pool question follows source facts:exact take plus best-fit
take_min already exist,64 cached buffers bound count rather than bytes,
and cumulative counters are not simultaneous live+idle capacity. Next local:
pin take/take_min/put and extract a public request trace;compare a bounded
event model to an independent live-capacity oracle under mixed-size/tail/
allocation-failure controls. Do not reimplement existing reuse,execute GPU
work,or infer time from hit counts. Owner actual-device clocks remain first.

LIVE sources and exact access/date/license/commit limits are in source-records
and search-log. Recent Chimera Oct16 retains whole-prover residency priority;
GPU NTT older sources distinguish L2 batches from whole memory traffic.
Newly assessed older Huerta2025 register-file/cache and software-dependency
scheduling is a possible future CUDA source-order lead,not a5090 speed claim;
the abstract and HTML differ on simulator error numbers,so none is imported.
No downloaded code executed or author performance reproduced. Current web
release/cache misses and unavailable PDF/license/history reads are recorded.
Rotation next:lookup/softmax and memory/batching;retain NTT/commitments,
sumcheck/GKR,quantization/arithmetic and composition in the queue.

Only research changed;runtime/,production,Git,receipts,calibration,safety,
instructions and reviewer files untouched. No installs,GPU jobs,external
writes/messages,purchases,privilege escalation or foreign code execution.
Saved reports do not establish user-message delivery. Checkpoint 2026-10-19T23:27:05.586443+00:00.

Freshness checkpoint 2026-10-19T23:29:44.252978+00:00: first final gate failed because owner MVP_STATUS
changed at23:25UTC. Updated text was read and preserved separately in
final-MVP_STATUS.md/direction-update.diff;initial startup snapshot remains.
Owner reports next-token-stage gate evidence,not a new privacy acceptance;
22-layer R8 re-pin pending. No new8B/GPU throughput evidence. Research result,
target and narrow D33 scope unchanged. Failed05-validate log retained;final
validator checks the reviewed new document pins. LIVE source ledger507->517
(10primary records);all inspected implementation commit IDs null because no
commit diff opened. No external author result reproduced.

Final checkpoint 2026-10-19T23:30:19.251633+00:00:provenance/consistency gate PASS,230 checks,
10 unchanged source/evidence pins,9 current direction pins (one owner status
update reviewed). Initial failed freshness gate retained;second failed gate
was an overly narrow report-wording assertion (handoff said "Limits:"),now
corrected. Neither failure was an experiment failure. Event/byte audit and
Rust opt0/3 observations remain passing. Static atomic log32768B;report size
corrected before closing. No native integration or new full-stack proof.
