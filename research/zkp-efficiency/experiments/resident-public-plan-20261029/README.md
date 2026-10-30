# Resident public map plan: exact component, native gain unknown

Cycle0144 — run `20261029T135649Z-1526011b`, October29,2026 UTC. Checkpoint 2026-10-29T14:11:21.548673+00:00.

**No native proving improvement found.** A values-free public map plan is exact
in the bounded component. Shared-machine helper timings are mixed: final
21/36 medians faster, initial 27/36. Final ratios0.661..1.204 are native helper
time / planned helper time, not native-prover or GPU speedups. Three raw
samples per shape/arm are retained; no stable timing benefit or p95 is claimed.
The second run followed added Boolean/base/maximal fixed-value and changed
slice/coefficient coverage; both runs remain in the experiment.

The actual R13 CPU seam `argument.rs::priv_table` constructs two integer
coordinate-to-address maps on every invocation. `Layout` already holds slot
geometry, so this is narrower than a new full execution-plan cache. The
candidate owns public coordinate kinds/indices, integer maps and an identity;
it accepts fresh borrowed `Priv` and data. `Coord::Fixed` holds earlier
transcript challenges. Their values, their Eq table, every private slice read,
all reserved-mask evaluation and later extensions are rebuilt each time.
No field multiplication, witness, commitment, transcript or proof work is
eliminated by the map plan. The research identity is a stubu64; native adoption
requires the full public shape/profile/source identity and unchanged refusal
checks, not trusting the stub as a profile admission mechanism.

Validation:210 fixtures and3150 synthetic pass replays,9450 comparisons,
3,402,855output words and3150 fresh mask/reference checks;10 negative controls.
References are unchanged extracted native `priv_table`, `claim_point`,
`mask_eval`, and a same-researcher independent literal-coordinate walk /
schoolbook-u128 field model and MSB mask folding. Patterns include permutations,
flips,interleaved/all fixed coordinates,broadcast,duplicate-coordinate helper
controls,empty-log edge,slices/offsets/coefficients and fresh changed inputs.
Logs0..7,13,14 are correctness fixtures; diagnostic logs8,14,17.
No native define/constructor,whole sumcheck/transcript,PCS,refusal suite,
full receipt or privacy gate was run. This is not external independent review.

Probe1.571899s /12,504KiB RSS; last compile1.527949s /166,740KiB;
accounting16,972 checks /36literal-address traces /144registry rows /36classes,
0.107292s /16,096KiB. Provenance/count audit844 checks,nine pins,three exact
function bodies passes. Each command has oneCPU0 affinity,nice19,40sCPU,
45salarm/50sparent timeout and384MiBAS cap; probe estimate128MiB,compile320MiB.
Rust1.75.0 opt1/std-only,Python3.10.12,seed202610290144. Compiler auxiliary
threads are unmeasured; one codegen unit and one CPU affinity. No GPU/Cargo.
Initial failure was a negative control mutating unread data[0] when the slice
began at3; it correctly changed nothing. Corrected to mutate the read offset;
original harness/logs retained. No candidate arithmetic mismatch observed.

R13 source-derived 8BT128 map accounting per block (cumulative logical work,
not physical traffic,live HWM,model execution or measured time):

|DD|f_E|Sites|Unique maps|Map tuple payload bytes|Native coordinate visits|Unique-plan visits|
|:--:|--:|--:|--:|--:|--:|--:|
|no|9|201|15|277248|2722880|169136|
|no|12/16|204|15|277248|2767424|169136|
|yes|9|206|16|279296|2668352|169904|
|yes|12/16|209|16|279296|2688320|169904|

Conditional within/across-call sharing would build15/16signatures once per
full compatible public geometry. This is a count model, not an implemented
cache registry. Each later execution retains146,930,688..153,742,336private
base-word reads and108,870,400..113,720,064output words per block. All2366..2374
fixed-Eq entries per block are regenerated. Plan payload excludes signatures,
identity keys,Vec capacities and allocator/cache metadata. Current prototype
also allocates a signature Vec every execution and comparesO(log) indices.
No actual cache eviction/capacity/concurrent-caller implementation exists.

All60prior hypotheses remain unchanged;new61 records this question and its
limits. Global ranking:1whole-prover named high-endGPU plus verified resident
1/2/4/8 workloads;2admitted DD/context/fidelity scaling;3exclusive phase and
capacity clocks. Expected end-to-end impact of map reuse is unknown and likely
small absent a material exclusive phase share. CeilingN/(T-Cremoved+Aadded);
free deletion of fractionf gives at most1/(1-f). Any exactness/order/profile/
refusal/RNG/transcript/PCS/privacy mismatch,or added cache/validation costs
canceling enclosing gain,falsifies promotion.

LIVE primary search newly assessed [Foundry2026](https://arxiv.org/abs/2604.06664)
and the older [dynamic-node update technique](https://developer.nvidia.com/blog/constructing-cuda-graphs-with-dynamic-parameters/)
with its [implementation](https://github.com/hummingtree/cuda-graph-with-dynamic-parameters).
The latter's per-file MIT header and code were inspected; commitID/date could
not be obtained. Root LICENSE/history/release and several MegaZK fetches hit
exact Cache-miss/403 blockers saved in blockers.json. Foundry graph context
cannot be treated as cached private state. Current official graph/release
docs and known sumcheck/October-paper boundaries were refreshed;9source records
append955->964. All publication/update dates are verified from primary history
where available,otherwise null; crawl dates are not publication dates. No
foreign code executed or author speed claim reproduced.

Integration seam: `Plan::new(identity,&Priv,n_vars)` and
`execute(identity,&Priv,data,n_vars)` in candidate.rs, replacing only local
half-map construction in frozen R13 `argument.rs::priv_table` (line251),
via `build_tables_at`. Conditional handoff under
handoffs/20261029-resident-public-map-plan.md asks for exclusive map/Eq/table/
witness/enclosing clocks first. No production patch was applied,heavy job
queued or merge made; main/Claude owns review and integration.
Next local rotation:quantization/arithmetic incidence of fresh fixed Eq versus
map planning,unless new native phase evidence redirects it. Preserve all
fresh CFS/mask work and exact refusal domains.

New independently verified full-stack proofs / completed model passes / proved positions: **0 / 0 / 0**.
Actual model context / accelerator: **none**. This cycle used one pinned Intel
Core Ultra 9 185H CPU worker. Witness, proof, serialization, verification,
startup and initial-prefill clocks, startup fraction, proof latency/bytes,
steady-state and total-workload token rates: **unmeasured**. Synthetic
1/2/4/8-pass helper replays are not resident-model proofs. No long-context
prefill or decode ran. Dense attention can grow quadratically with context;
larger workloads remain allowed. Complete private 8B >=50 proved tokens/s
on an RTX 5090 or another named high-end GPU remains **unachieved**.

Carried older-profile CPU8B baseline:T128/L32,one16-thread pass,GPUoff;
478.737s total=0.267370positions/s;prove_run393.785s includes witness98.348s
and blockload17.595s. Sealing84.824s precedes it;seal load27.151s/witness80.897s
overlap. Receipt922,711,264B;verify42.709s plus load13.681s. Not rerun/reverified
or newly counted; isolated serialization,startup fraction and steady slope
unknown. Newer classifier/owner results do not transfer to this old paired
baseline or R13/high-endGPU throughput.

Only research outside runtime written. Production/Git/receipts/calibration/
instructions/safety/reviewer files untouched. No installation,external write
or message,purchase,Git action,GPU,large build,escalation or merge. Saved reports
are not delivery or supervisor-liveness evidence.

Reproduce sequentially from research root:

```text
python3 -B experiments/resident-public-plan-20261029/run_bounded.py compile
python3 -B experiments/resident-public-plan-20261029/run_bounded.py probe
python3 -B experiments/resident-public-plan-20261029/run_bounded.py account
python3 -B experiments/resident-public-plan-20261029/run_bounded.py audit
```

Native/source/extraction pins, seed, commands, hardware, raw sample arrays, caps
and initial failure remain here. No source or toolchain install needed.
