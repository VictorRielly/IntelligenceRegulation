# Public witness lifetime oracle — cycle 0018

Run `20261004T000146Z-b9833e6d`, completed 2026-10-04T00:20:58.279502+00:00. Synthetic source-derived CPU experiment; no native proof.

Baseline: production retains all i64 witness planes, materialized looked columns and exp/activation indices until H helpers finish. Cycle0017 lazy readers eliminate looked/index vectors but retain all source planes. Question tested: can a public last-read schedule release each plane earlier without changing A/H words, lookup order or denominator refusal?

Plan: copy A first, release A-only planes; retain each looked plane until its last domain in **L,D,F,Q,Kv,S** order. S8/MX/E remain until H_EXP; G8/A16 until H_ACT. Keep every public table denominator check, including zero-multiplicity entries. No mask/opening/RNG reuse, statement changes or value-dependent release schedule.

Result: 12 fixtures, 356 lookup specs, 91,076 A/H field words and 110,444 reads match a separate named-catalog materialization driver. Candidate conjugate/norm Fp2 inversion is checked against polynomial convolution plus Fermat inversion. Ten negative controls detect early drops, reordered columns, wrong indices and skipped unused zero denominators. Context/head pairs1/1,3/3,5/1, norm limbs4/5, score limbs2/3/4 include padding, i64 wrapping and late E/A16 reads. Synthetic exp/activation tables are public stand-ins, not production model tables.

The first attempt failed selecting an unused byte from a random fixture that covered all values. Preserved under initial-unused-selection-failure/. Corrected with a separate deterministic zeroed refusal fixture. intermediate-shared-driver-pass/ preserves the earlier pass before the separate reference driver and expanded ledger. Final exit0, 3.309s, RSS27164KiB, Python3.10.12, Intel(R) Core(TM) Ultra 9 185H, one pinned CPU thread. Estimated64MiB; RLIMIT_AS512MiB, CPU55s, alarm59s. Command/logs/seed/hash are retained; no GPU, build or dependencies.

Counted named host payload maxima, MiB (not actual process/GPU peaks):

| Shape | Materialized | Raw lazy | Raw lazy + release | Typed lazy | Typed + release | CPU retained codewords, all strategies |
|---|---:|---:|---:|---:|---:|---:|
| toy | 3.666 | 3.652 | 3.652 | 3.652 | 3.652 | 16.762 |
| m125 | 3215.861 | 2423.611 | 2203.283 | 1867.584 | 1784.228 | 8037.627 |
| llama3_8b_T512 | 10395.283 | 7803.033 | 7242.643 | 5891.701 | 5619.533 | 26134.002 |
| llama3_8b_T1024 | 28953.678 | 21721.428 | 19832.896 | 16570.982 | 15800.678 | 71917.881 |
| llama3_8b_T2048 | 90725.471 | 68068.971 | 61219.908 | 52456.080 | 50147.471 | 223194.146 |

Includes raw/typed witness, production lookup/index buffers, packing overlap, retained A/H raw rows, pads/salts/trees, one helper vector and exp/act batch-inversion prefix. CPU tier additionally retains A/H codewords; chunked GPU host tier excludes codewords. Excludes M, IO/boundaries, weights, runtime/pools, small table-helper buffers, other scratch, receipts and allocator overhead; device memory is separate. Counts generated from source-derived Ids/Lks and analytic shapes, not allocations. m125 raw release adds220.328MiB saving over raw lazy, typed release83.356MiB. Toy lazy/release maxima equal; CPU maxima equal for all strategies because H_COMMIT codewords dominate. No global peak or timing improvement established.

8B T512/1024/2048 rows use five normalization limbs, not prior four-limb proxies. These shapes are unregistered and the current native builder refuses ln!=4. T-dependent attention grows quadratically. All large ledger rows are integer accounting only, not allocated experiments.

Costs: public release metadata, moved/optional plane ownership, lazy affine loads, optional typed packing and raw+typed overlap. Rust borrow/Arc ownership may keep storage live; native RSS and phase measurements must decide actual benefit. End-to-end ceiling N/(T_removed-adjusted), equivalently N/(T-M+C), with removed phase time M and added time C unknown. No 50/s implication from byte counts. Falsify on value/trace/refusal/RNG/proof-byte mismatch, private-data-dependent scheduling, or unchanged actual peak/complete workload rate.

Integration: private_block/protocol.rs before A commit and H helper loop, Layout::Ids/lookups_at, separate optional owned plane slots. No production patch or native Rust compilation. Source snapshots/hashes retained in source-pins.json. Handoff identifies native validation gates.

Full-stack accounting: CPU only, model context null, passes0, countable tokens0; steady/total rates, startup fraction, witness/proof/serialization/independent verification clocks, proof lag and pipeline drain all null. These oracle clocks are not model witness clocks.
