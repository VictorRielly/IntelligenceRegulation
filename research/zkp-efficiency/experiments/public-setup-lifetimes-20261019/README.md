# Public setup lifetimes across reviewed R8 sealing/proving

Cycle0084 — `20261019T161854Z-4bc2599e` — 2026-10-19 UTC.

**No speed improvement measured.** Source inspection rejects a supposed
per-layer NTT cost: the run already shares one table. GPU twiddle uploads are
already monotonic/process resident. Partial LRU also fails the ordered public
layer trace. A fixed public pinned subset remains a conditional owner candidate.

The experiment pins11 source files against the reviewed R8 manifest and4
public evidence files. Frozen tree7f64276abeceff666ff1269754bec83e0b0867b5d2812ae469bf76324d92ffb9.
R8 is soundness accepted by the review; no privacy acceptance inferred. No
production/model/private data were changed, read as a witness, or copied.

## Reproduced scope and negatives

- Main PASS:66129 checks,24 NTT fixtures (random/boundary/zero,
  sizes1..128),6 RS fixtures,all32768 forward/inverse capacity16 twiddles,
  222 IO allocation checks,35 descriptor-field mutations and13 controls.
  A direct big-integer Vandermonde/Horner reference checks every small output.
- Separate audit PASS:1400 checks,5 controls,24 direct monomial DFT
  comparisons and32 fresh norm-coefficient counterexamples. It imports no
  candidate code. Source/public clock/payload/site checks are independent.
- A shape-only whole-stage Layout cache gives105 wrong stage maps over the
  synthetic1/2/4/32-block cases atT32/64/128. Internal incoming starts at
  data_rows+2; outgoing atdata_rows. AtT128 those are34 and32. Always rebuild
  the stage overlay from the validated RunStatement. No native attack/proof
  or accepted changed Shape was tested.
- Geometry alone omits calibration. Full Shape is a Layout key, not a public
  table key: the real public R8 report's31 base-shape layers have6 distinct
  exp/SiLU key combinations. No private contents were inspected.
- Across72 synthetic public request schedules, LRU capacities1/4/16/31
  yield0hits when scanning32 layers repeatedly. A fixed public pinned4 gives
  60hits/512 requests for8 complete sealing/proving scan pairs. It retains
  973645824B=0.906778GiB backing payload; all32 need7789166592B=7.254227GiB.
  A per-block243411456B count includes padded FFN width16384, two norm vectors,
  RoPE i64 and256-entry tables. Ignoring FFN padding undercounts0.75GiB/stack.
  Counts allocate no real weights and are not RAM/VRAM admission or timings.
- T128 CPU NTT table payload524560B. Ideal fixed-context process owner2R->1
  constructors (16->1 atR8), not32R->1. Both external endpoints already share
  one constructor; the body shares one across all stages/boundaries. Existing
  GPU tables use1048560B backing and persist; this saves0additional uploads.

## Baseline, savings, costs and ceiling

Baseline is current separate sealing/proving public ownership. Remove only
actually avoided public loads/reconstruction and CPU table construction.
Add authenticated immutable ownership, complete object-specific keys,
retention/capacity/eviction, native CS rechecks and layout copy/IO overlays.
No witness/refusal, sumcheck, commitments, masking, serialization or verification
work is removed by calling it setup. Existing sealing layout deduplication
and every CS8 reconstruction remain.

Candidate end-to-end ceiling is not numerically identifiable:
T/(T-s+a), exclusive saved public work s and all new costs a unmeasured.
For orientation only, deleting **all**27.151+17.595s reported load tasks at
zero cost bounds this CPU diagnostic at1.103104x;
overlap reduces the actual benefit. That is a generous load-only upper bound,
not the pinned4/NTT candidate's speed or a GPU forecast. The target needs
broad recurring-work improvement. Falsify on stale identity/site/calibration,
changed native refusals, private state in a public owner, failed receipt or
privacy gates, peak regression, or overhead >=exclusive saved wall time.

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

## Interface and owner gates

Read source-census.json and reuse-boundaries.json. Actual seams:
private_block.rs:prepare_endpoints; run.rs:prove_run_with/stage_layout;
trained_block.rs:seal_and_record/BlockCache::get; Layout::check_is_for_shape.
No Rust/CUDA patch emitted. Layout does not currently offer this immutable
base/overlay API; implementing it needs owner review. CS8 independently
rebuilds mutable public row fields; caching must not silently skip it.
Keep fresh OS streams, endpoint roles, one-use owners, transcripts, original
PCS/finals, H-1 early refusals and independently verified complete receipts.
P3 private-weight reuse needs its own review. Main/Claude owns integration;
no merge or heavy/GPU work launched.

## Reproduction and retained evidence

`python3 -B experiments/public-setup-lifetimes-20261019/experiment.py`
`python3 -B experiments/public-setup-lifetimes-20261019/audit.py`

Exact argv/exit/stdout/stderr are in commands.json and*.log. Seed2026101984;
audit fresh seed2026101985. Main0.345412s/24872KiB;
audit0.095730s/16204KiB. One nice19 CoreUltra9 185H
CPU0,Python3.10.12,WSL2; each59s CPU/wall and512MiB AS,64MiB estimate.
No build,GPU,dependency install,Git or downloaded-code execution. Source
snapshots, pins, fixtures, exact payload/schedule ledgers and public-only
clock-event extraction retained. Initial CPU-only census retained separately;
later GPU-source inspection narrowed the claim; no failing harness run.

Seven LIVE primary records455->462; see search-log.md.
Newly assessed older cuZK, refreshed October StateSync/P3 releases and ICICLE
domain lifecycle. Pipelonk DOI/ACM403 and inaccessible Zenodo remain an
unassessed lead. Licenses/date/commit scope and fetch failures are explicit;
no author performance reproduced. Ranked queue in hypotheses.json.

Next local: build a public-only immutable-layer-owner trace with
synthetic contents and full model/manifest/layer/table identity, then test
fixed pinned admission against stale exports, layer-range/base changes,
cross-model swaps and peak lifetime overlap. Retain every native CS/H-1 check;
compare a streaming no-cache oracle. First derive where a retained Arc can
replace reconstruction at seal_and_record and BlockCache::get. Do not launch
a model build/proof or repeat the disproven partial-LRU policy. Owner request:
isolate public construction, CS rechecks, witness and serialization clocks,
then independently verify fixed-context resident1/2/4/8 workloads under locks.

New target proofs/passes/positions **0/0/0**, device none. Target
steady/total rates, startup fraction and witness/proof/serialization/
verification clocks unmeasured. No long prefill, resident proof series or
decode ran. Synthetic pass counts are constructor requests, not proved work.
Larger workloads remain allowed; attention may grow quadratically. Complete
private8B / >=50 proved positions/s on5090/named high-end GPU remains
unchanged/unachieved.
