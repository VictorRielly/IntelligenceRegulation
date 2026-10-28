# Unapplied R8 public setup/residency handoff — 2026-10-19

**Conditional candidate, no measured speed gain.** Experiment:
[experiments/public-setup-lifetimes-20261019](../experiments/public-setup-lifetimes-20261019/README.md),run`20261019T161854Z-4bc2599e`. No Rust/CUDA patch or merge.

Interface: an immutable public layer-owner shared by seal_and_record and
BlockCache::get, with a fixed public pinned subset and streaming fallback.
Bind model approval identity, manifest SHA, actual block digest, layer,
geometry, per-layer exp/SiLU keys, RoPE mode and reviewed source format.
Authenticate cold contents and preserve every CS1/3/4/6/8/9 check and H-1
refusal ordering. Never carry witness/input-derived state through this owner.
Main/Claude reviews implementation in owned production lane under locks.

The source's ordered32-layer trace thrashes every partial LRU tested;
pinned4 gives60/512 request hits over8 scan pairs at0.906778GiB public payload.
All32 public padded blocks need7.254227GiB before proof buffers. These are
synthetic request/count results, not native load savings or GPU fit.

Smaller seam: pass one canonical immutable NttTables owner through
prepare_endpoints and prove_run_with. T128 payload524560B,ideal2R->1 CPU
constructors; device twiddles already cached,0extra uploads removed. Public
field/representation/domain/capacity key suffices for this object. Preserve
frozen-seam exact-domain refusal as well as generalized-endpoint capacity rules.

Do not cache a whole stage Layout by Shape: internal incoming/outgoing IO
rows differ. Split full checked Shape/source keyed public base from per-use
RunStatement-derived IO overlay; preserve CS8 fresh rebuild/tamper checks.
Layout-only full Shape key cannot identify public layer tables. API is not
implemented and clone/overlay/layout bytes are unmeasured.

Validation:66129 checks/13 controls; separate1400-check audit/
5 controls. Exact small-field outputs and public source/payload/site evidence,
not native Shape/admission/fold/final/transcript/receipt/privacy equivalence.
No masks,RNG,challenge denominators,A/H/M,prepared endpoints/boundaries or
private openings reused. Freshness and joint privacy gates remain required.

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

Exclusive public construction and CS recheck clocks are missing. Candidate
ceiling unknown. Zero-cost removal of all reported load tasks gives only
1.103104x on this CPU diagnostic and overstates
wall saving where tasks overlap. Reject if saved construction <=key/ownership/
retention/transfer cost, peak fails, or any identity/refusal/privacy/proof
gate differs. Whole-prover GPU and independently verified resident1/2/4/8
workloads outrank NTT/layout micro-optimization.

Next local: build a public-only immutable-layer-owner trace with
synthetic contents and full model/manifest/layer/table identity, then test
fixed pinned admission against stale exports, layer-range/base changes,
cross-model swaps and peak lifetime overlap. Retain every native CS/H-1 check;
compare a streaming no-cache oracle. First derive where a retained Arc can
replace reconstruction at seal_and_record and BlockCache::get. Do not launch
a model build/proof or repeat the disproven partial-LRU policy. Owner request:
isolate public construction, CS rechecks, witness and serialization clocks,
then independently verify fixed-context resident1/2/4/8 workloads under locks.
