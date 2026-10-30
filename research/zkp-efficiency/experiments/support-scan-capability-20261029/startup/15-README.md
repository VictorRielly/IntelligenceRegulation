# Same-call identity SHA reuse in the full trained loader — cycle 0132

Run `20261029T015649Z-e607e256`, 2026-10-29 UTC. No native proving gain
measured. One bounded synthetic experiment completed; production is untouched.

The current full loader checks each raw array's SHA-256, pads/copies the
arrays, then `LayerRecord::of_block` hashes nine padded weight byte sequences
again. A checked raw SHA can identify the record's bytes only when the
actual transformation is identity. At the inspected Llama-3-8B geometry,
that holds for wq/wk/wv/wo/gamma_a/gamma_m and the exp/act table encodings.
The three padded FFN arrays do not qualify. Head holes at other geometries
also exclude wq/wo. Exp/act constructors copy; RoPE's combined hash remains.

This is a new same-invocation reuse prerequisite, separate from cycle0027's
public BLAKE3 streaming/cache and the prior ownership/drop experiments.
There is no cross-request cache or changed file-refusal policy. Source
inspection rejects a larger proposed benefit: native reload already skips
per-array/per-word SHA and compares the actual rebuilt block BLAKE3 with
the sealed digest. The obsolete comment saying every reload checks raw
SHA is corrected by the code immediately below it; the code governs this
accounting. No upstream defect is alleged.

`run.py`: **5,150 checks**, **2,584 negative-control instances**, 32 synthetic
fixtures, seed202610290132. Eight small geometries vary width3..16,
hidden4..16, Qheads2..8, KVheads1..2, head dimension2, padded width4..16,
padded hidden4..16 and head holes; T3/4. Four data styles: random, signed
extrema, zero, asymmetric ramp. Chunk sizes1/7/64/257. Candidate scatter and
SHA reuse match a separate destination-indexed signed-word serializer,
all nine word hashes, three table hashes and complete canonical byte
preimages. The independent reference imports no candidate code.

Controls cover mutations to all13 arrays, changed-and-rehashed exports
against stale block identity, reload unverified manifest digests, wrong
layer/dtype/shape/extent/path, layer order/multiplicity, changed outer profile,
JSON key reorder, unconditional padded raw-hash reuse, same-extent
permutations, and invalid concatenation of finalized RoPE hashes. JSON key
reordering preserves block bytes but changes the raw manifest hash.

Scope is a byte/hash projection, not native loader equivalence. Arbitrary
table extrema are serialization stress inputs, not registered exp/SiLU/RoPE
members. Fixtures carry both exported RoPE tables; optional native generated
RoPE, native registry/range/refusal order, source-tensor metadata and complete
statement serialization are not executed. Block preimages are compared
exactly, but the digest surrogate is explicitly SHA-256; native BLAKE3 is
not executed. `full=False` recomputation is a diagnostic control only;
adding word hashes to native reload is not proposed.

Measured checking: **0.193040 s**, **20,280 KiB RSS**. Independent source/cost
audit: **97 checks**, **0.003939 s**, **18,920 KiB RSS**, six native pins
unchanged. One CPU0 nice19 Core Ultra9 185H worker, Python3.10.12, no GPU;
40 s CPU,45 s alarm,256 MiB address-space caps,64 MiB memory estimate.
These are checking durations, not an A/B loader or proof benchmark.

Allocation-free 8B census uses D4096/F14336/Fpad16384,32Q/8KV heads,
head dimension128,T128,L32. Eligible SHA input is **41,953,792 B/layer**,
**1,342,521,344 B/32-layer full load**,17.23575% of record SHA input.
This counts avoided hash input and matching cast lengths, not DRAM traffic,
seconds, RSS/VRAM, or proof work. Remaining FFN casts include three64MiB
tasks. Full loader peak saving is unknown. Reuse avoids no raw source reads,
initial raw hashes, padded constructors, support checks, block BLAKE3,
witness, commitments, masks, sumchecks, serialization or verification.

`scheduling-model.json` supplies a useful negative. With independent workers
at equal byte-processing rates and largest-first list scheduling, the word
SHA phase has unchanged makespan at2/4/8/16 workers: three64MiB FFN tasks
remain. At3workers the abstract schedule differs; at1worker total byte work
falls. These are countermodels, not measured Rayon scheduling or a memory
bandwidth model. Shared bandwidth can change the outcome. Source parallelism
prevents treating17.2% fewer record SHA bytes as17.2% less loader wall.

Baseline is the current full loader. Removed work is conditional record
hash/cast work only; new costs are internal provenance, identity predicates
and integration. Exclusive critical-path fraction f is unknown; even free
deletion is bounded by1/(1-f) before costs. The carried CPU8B all-load
deletion1.103104x is an overbroad diagnostic bound, not this candidate's
forecast. Falsify on any canonical byte/hash/binding/refusal/native gate
mismatch, unverified hash authority, absent exclusive incidence, enclosing
time regression or memory regression. Native code review and clocks precede
any owner build under current shared locks; no heavy job is queued here.

All48 prior hypotheses remain; rank7 refined, rank49 added. Top3 stay:
whole-prover high-endGPU with verified fixed-context resident1/2/4/8 workloads;
DD/fidelity context scaling; complete exclusive phase/capacity clocks.
Eight primary LIVE source records added,857→865. Newly assessed older
foreign-arithmetic/Tinybear and holography accumulation are architecture
filters, not native speedups. Pipelonk scheduling, current ICICLE release,
ZK-Flex synthesis and known sumcheck/quantization sources were screened.
Dates, license scope, exposed commit IDs and403/Cachemiss limits are in
`sources-cycle.json`; no author performance or external code was reproduced.

New independently verified full-stack proofs/passes/positions: **0/0/0**.
Actual model context/device: none. Witness/proof/serialization/verification,
startup/prefill, startup fraction, latency/bytes and steady/total rates are
unmeasured. No long-context prefill, resident proof series or decode ran.
Larger workloads remain allowed; attention can grow quadratically. Private8B
>=50 proved tokens/s on RTX5090 or another named high-endGPU is unachieved.

Commands: `python3 -B experiments/layer-stream-digest-20261029/run.py` and
`python3 -B experiments/layer-stream-digest-20261029/audit.py`. Exact source
hashes, dimensions and results are retained. No native build, GPU,
dependency installation, foreign code execution, production/Git mutation or
external message/write. Only this research directory outside runtime was
written. Main/Claude reviews and integrates; no merge. Saved reports are
not evidence of notification delivery or supervisor liveness.
