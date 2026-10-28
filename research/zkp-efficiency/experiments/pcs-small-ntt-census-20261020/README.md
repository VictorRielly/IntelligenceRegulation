# Private PCS census: small inverse opportunity, trained T128 null

Cycle0102, run `20261020T101854Z-5d2a545a`, accessed2026-10-20 UTC.
**No proving speed improvement measured.** This is a public source-geometry
and address-count study, with no Rust/CUDA execution. The source offers shown
below are conditional on device acceptance; they are not observed launches.

The hiding commitment invokes **two different transforms per encoded row**:
`n=2^log_cols` inverse, then `nn=n*inv_rate` forward after pad/coset scaling.
Using only expanded `logNN` misses eligible inverse work. The current private
path uses `k_ntt_p1` for both (including chunk/open-reencode forms), unlike the
separate non-hiding DIF/DIT encoding. M's `logN=12` coset encoder calls CPU
`NttTables::forward` and never the commitment backend. Its size does not
establish CUDA incidence. No route is changed here.

Source-backed geometries (NTT length is **not** context length):

| Lane/model | Context T | log_cols | Inverse length | Expanded length | Small inverse guard |
|---|---:|---:|---:|---:|---|
| GPU + R9 TinyLlama |32|12|4096|16384|yes, conditional offer|
| GPU + R9 TinyLlama |64|13|8192|32768|yes, conditional offer|
| GPU + R9 TinyLlama |128|14|16384|65536|no|
| GPU + R9 8B |32|13|8192|32768|yes, conditional offer|
| R9 8B |64|13|8192|32768|yes, conditional offer|
| R9 8B |128|14|16384|65536|no|
| R9 DD TinyLlama / 8B |128|14|16384|65536|no|

All trained rows here use inverse rate4 and `q_pad=opened_cols=256`.
Endpoint/boundary geometry follows the profile's own endpoint parameters;
trained endpoints share the above widths. Diagnostic toy/rung/rung-G/m125
are separately labelled in `census.json` (the frozen rung's endpoint width
and rate differ from A/H). No whole-model incidence or A/H row aggregation
is inferred from these per-row counts. This is 16 lane/profile entries,
not16 distinct trained production profiles or a census of every repository
profile. Active GPU has no8B T64/T128 constructors in the inspected lane;
those rows are frozenR9. These source geometries do not admit GPU privacy.

Summed 32-byte sector requests per **one row's P1 load pair**, 512 threads,
aligned base, same current producer and candidate guard8..13:

| log_cols | Inverse literal -> sketch | Full forward, either | Compact forward, either | Pair request reduction: full / compact |
|---:|---:|---:|---:|---:|
|12|4096 ->2048|16384|4352|10% /24.2424%|
|13|8192 ->4096|32768|8448|10% /24.6154%|
|14|16384 ->16384|65536|16640|0% /0%|

Full-width is `n_src=nn`; compact is `n_src=n+256`. They are existing
source forms, not a newly measured compression gain. These request totals
are **not physical traffic, cache misses or time**. Both forms read the same
logical values needed by their existing producers. Unique-sector reuse across
warps/tiles, shared-store wavefronts and compiled index costs remain unknown.
Prior cycle's fixed16-lane bank-address model worsens1->2 for rotation; no
actual SASS/wavefront or native timing has been measured.

The unchanged T128 source layout falsifies a claim that the guarded sketch
helps its A/H or endpoints by this mechanism. M has50 base rows on23-slot
profiles,52 on24-slotDD, but is CPU-only; the CUDA sketch removes none of it.
Do not shrink row width or change a profile to create eligibility. Preserve
Tab/log_cols S-1/P-3, bilinear and token-domain refusals, all original private
owners and every fresh pad/salt/mask, one opening and exact transcript order.
This study neither tests the full native refusal domain nor proves hiding.

Validation: **619 checks,16 lane/profile entries,160 role/phase rows,
13 distinct transform geometries,444 boundary cases,9 rejected wrong controls**.
An independent multiplication/doubling geometry oracle and bit-string/byte
sector reference match native-style shifts/brev32 request counts over every
tile of each tested row. Additional rows0/1 and an aligned8-bytebase offset
are checked. Dimensions come from public source, not private telemetry.
Seed270536706 (`0x10201002`). There is no tensor-value or polynomial evaluation
in this cycle; prior value checks remain prior evidence, not rerun claims.

Separate source/artifact audit: **933 assertions,64 source-fragment
checks,48 rejected fragment-deletion mutations,16 unchanged source pins**.
Fragment checks are not native behavioral tests. Both source copies and their
current originals match SHA-256. Constructor snippets independently bind the
trained table and endpoint defaults; audited Tab and route guards are retained.

One CPU thread/core0,nice19,IntelCoreUltra9 185H,Python3.10.12/WSL2:
probe3.850s,20,620KiB RSS; source audit0.284s,
23,424KiB RSS. These are Python checking clocks. Each leaf capped
at59sCPU/alarm,60sparent,512MiB addressspace; memory estimate64MiB.
Initial output and later added explicit message/expanded/endpoint fields are
retained in `before-expanded-census-fields/`; counters unchanged.

Reproduce from the research directory:

```
python3 experiments/pcs-small-ntt-census-20261020/run_bounded.py probe.py
python3 experiments/pcs-small-ntt-census-20261020/run_bounded.py validate.py
```

Source snapshots/hashes,commands,limits,hardware,seed and exact JSON outputs
are adjacent. Only self-contained local code executed; no installs or builds.

Baseline and ceiling: literal first load loop. Eliminated work is only some
requests; zero logical bytes/capacity/transforms/masks/commitments/proof work
removed. Added index/shared-bank/compiler costs unknown. If f is exclusive
whole-workload time of affected loads, even deleting all gives at most
`1/(1-f)`; this sketch removes less and adds work. f is unmeasured. At T128
there is no request reduction (no gain from this mechanism, possible added
cost). At T32/T64 a numeric end-to-end gain/50-token/s ceiling is unknown.
Reject on absent actual route incidence, any native parity/refusal mismatch,
no compiled saving, bank/register regression or slower enclosing proof.

Actual integration seam: `k_ntt_p1` first load loop, through
`ntt_rows`/`ntt_rows_view` and private resident/chunk/open reencoding.
Uncompiled sketch remains in the prior experiment's
`p1_load_rotation.proposed.cuh`; no new production patch or merge here.
Owner must first measure actual inverse/forward route incidence and exclusive
plus enclosing clocks, inspect SASS/shared/cache metrics, then under shared
heavy/build locks test forward/inverse/compact/chunk/coset parity, seeded
masked rounds/challenges/PCS/receipt bytes/refusals, independent complete
verification and current privacy/fidelity/soundness gates. All-eleven FZC
compiler A/B retains higher priority.

Seven LIVE primary source records plus one prior-assessment correction saved.
Recent [zkLLMPoT v2](https://arxiv.org/abs/2610.08258) remains covered-operator
author evidence. [DeepProve](https://github.com/Lagrange-Labs/deep-prove) and
[Expander](https://github.com/PolyhedraZK/Expander) release/history/license
metadata were checked; no upstream code ran. Older
[Caulk+](https://eprint.iacr.org/2022/957) is absent from the starting591-record
ledger; its table-independent subset argument is an architecture filter for
our already tiny256entrytable, not a measured saving. PDF403 blocked fulltext.
[LogUp-GKR](https://eprint.iacr.org/2023/1284),
[cq](https://eprint.iacr.org/2022/1763) and
[MLE lookup compatibility](https://eprint.iacr.org/2024/1058) were refreshed.
The latter already appeared incycles0046/0068; initial NEW label was caught
by exact-URL audit and corrected with original evidence preserved. Publisher
version-of-record date2025-01-09 now reconciled; paper abstract only, PDF
InternalError. Full exact URLs, verified dates, license/commit scopes and
fetch failures are in `source-records.json`; no author timing reproduced.

New independently verified full-stack proofs/passes/positions:**0/0/0**.
Actual model context/device:none; no accelerator invoked. Witness,proof,
serialization,verification,startupduration/fraction,steady and total-workload
rates:all unmeasured. No long-context prefill,resident-model pass or decode.
Carried baseline,not rerun/reverified:CPU8B T128/L32,one16-threadpass,GPUoff,
total478.737s =0.267370positions/s; prove_run393.785s includes witness98.348s
and load17.595s; seal84.824s overlaps phaseaccounting; receipt922,711,264B;
freshverify42.709+load13.681s,recheck34.395+load10.739s. Its startup fraction,
steady slope and isolated serialization remain unknown. Private8B>=50/s on
RTX5090/another namedhighendGPU remains unachieved. Larger workloads allowed;
longer contexts can add quadratic attention. R9 DD conditions N-r9-a/b bind;
DDprivacy owed; D33 frozenR7 CPU TinyLlamaT32 scope is not extended.

Next local: source-backed per-domain H helper-word/lookup-multiplicity census
at the same trainedR9 DD/nonDD shapes. Separate publictable256 work already
cached from recurring privatehelper commitments; cost potential LogUp-GKR
helper deletion against extra fractional-tree rounds/final openings before
any protocol prototype. Exact lookup/multiplicity/refusal/privacy obligations
stay explicit. Next owner: completeGPU clocks and independently verified
resident1/2/4/8 passes; FZC native compiler A/B ahead of conditional smallNTT.
