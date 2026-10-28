# Optional host-backed slot18 staging reuse; all-resident opportunity is zero

Run `20261020T011854Z-224b9b69`,2026-10-20T01:31:06.037153+00:00.

**No proving speed improvement measured.** The tested staging reuse saves
**zero work when A/H are already device-resident**, which is the source path
after successful GPU commitments. A fallback-only capacity option is preserved.

Seam: active GPU candidate hashline/src/gpu/cuda.rs,DevFzcRounds::new,
host-backed FzcSrc::Base/Pair None branches (~4351/4381 before patch).
review-only-host-stage-reuse.patch and candidate-cuda.rs are UNBUILT/UNAPPLIED.
Lazy local raw buffers replace only temporary uploads and drop after the
existing build synchronize. Reuse storage,never private values or randomness.
Fully resident sources allocate nothing on this branch. H2D volume,kernel
arguments,table order and st.bytes_h2d stay the same. Constructor allocation
failure order/site changes and Rust borrow/type correctness remain untested.

Owner must first establish nonresident sources in the intended workload.
If useful,review/rebase under existing lane ownership; shared build/heavy
locks govern all native builds/device work. Run host/mixed/resident differential
tables,shadow masked rounds+next challenge,full receipt bytes+independent
verify,refusal/failure/strict GPU,CS/H-1 and current privacy gates. Measure
actual allocation capacity/HWM and enclosing prove/witness/serialization/verify.
Do not build this just to claim a speed gain on an all-resident path. No merge.

The pinned local cudarc0.13.9 Cargo.lock checksum and .cargo_vcs_info
match release e12b2d96877d0bae7266c01df14f257e95bb0020. Its htod_sync_copy
allocates then calls htod_sync_copy_into; the latter uses the device stream
and synchronizes. Same-stream storage reuse can retain existing synchronization
counts. Native CudaDevice::new,mutex and source consumers were inspected.
The full release commit changes only the version; allocation semantics are
from the inspected package/tag. MIT/Apache texts pinned; no dependency executed.

144 synthetic fixtures,seed2026102093,n in1/2/3/4/6/8,
all four A/H residency combinations,both support flags,three seeds.
The independent destination-byte/event oracle passes **27301 checks**,
292 ordering/lifetime/alias/lexical controls and
1299 corrupted hash/capacity/completion/site records.
These are authored single-agent checks,not an external review or native proof.
36 all-resident cases allocate0 staging buffers before and after.

Largest synthetic fixture has256 entries/table: original host staging47656B
with23 allocations versus4144B with2; the+3u64 tail per buffer is deliberate.
H2D47104B,23 copy syncs+1 final explicit sync are unchanged by ordered reuse.
The conservative variant adds17 extra explicit syncs and is retained under
before-copy-order-refinement/. The unsafe no-order and aliased-pair controls
fail,as does use after release. These model hazards are not native failures.

[MODEL] At l=2^20,all-host source staging184->16MiB (168MiB less),
split/support tables368MiB unchanged. n20 is a cube dimension,not a token
context. This excludes other tables,eq scratch,live commitments,caches,
driver/module allocations,granularity and host/pinned memory. No model-size
or actual-device-fit claim. No inference of speed from allocated bytes.

Baseline/eliminated work/added costs/ceiling: 23->2 all-host raw source allocations,184*l->16*l requested staging bytes,unchanged H2D and23 copy+1 explicit synchronizations. No entire table/proof work removed; no benefit for device-resident A/H. At most the exclusive allocation/staging/fallback time can be removed on mixed/host sources,which is unmeasured. Falsify promotion on always-resident sources or native byte/refusal/time regression.

Selected allocation API census independently agrees on298 sites:
R8 94 (52 raw/39 pooled requests/2 backing/1 host-pinned),
activeGPU113 (67/41/2/3),root91 (49/39/2/1). It includes probes/tests and
branches; it is not a runtime trace or complete CUDA-driver allocation count.
All source pins and exact line/function/arguments are in census.json.
The scanner's initial char-literal and array-signature bugs are fixed;
failed runs remain in commands/logs. No Rust parser/compiler was run.

10 direct drain/reservation call sites outside cuda.rs are indexed. Production
sites occur in legacy layer.rs/zk.rs; the private GPU test helper adds one
drain. No direct production call occurs in inspected private_block files.
This is a source census,not proof of whole-program reachability through macros.
The prior synthetic layer-drain schedule is therefore not an actual trained
private-stack trace. dev_pool_drain clears only idle POOL storage; it does not
clear monotonic twiddles,FZC_PUB,live commitments or raw scratch.

Twiddle growth retains old plus newly uploaded forward/inverse pairs until
assignment:16*((2^old-1)+(2^new-1)) symbolic bytes. FZC public-cache insertion
uploads before evicting,so a four-entry cache can transiently coexist with a
fifth table (80MiB for five equal2^20-entry Fp2 tables). These are partial
source-derived envelopes,not simultaneous full-proof peaks or new bugs.
New FZC raw allocations are outside commitment/opening RAW_ALLOC_SCOPE by
its documented design; counters were never claimed as whole-prover capacity.

New independently verified complete proofs/passes/positions **0/0/0**;
GPU device/token context none; CPU-only synthetic experiment,0 proof passes.
New witness/proof/serialization/verification clocks, steady-state and
total-workload proved rates and startup fraction **unmeasured**. No long-context
prefill,resident complete-proof series or decode ran. Larger workloads remain
allowed; attention may grow quadratically. Complete private8B >=50 proved
tokens/s on RTX5090/another named high-end GPU remains unchanged and unachieved.
No mask/opening reuse or privacy weakening.

Next local experiment: derive the PRIVATE stage's actual commitment/opening
lifetimes from run.rs/protocol.rs (A,M,H,previous/current boundary and endpoints)
and combine symbolic requested capacity with raw/cache categories. Independently
check early-release and prior-boundary controls. Identify an actual peak phase;
do not replay the synthetic legacy four-commit schedule or infer device fit.
Highest-priority owner action remains whole-prover high-endGPU clocks and
independently verified fixed-context resident1/2/4/8 complete workloads.

Full [experiment](../experiments/device-allocation-coverage-20261020/README.md),source/patch hashes,commands,resource caps and failure logs retained. Owner reviews/integrates; no merge by explorer.
