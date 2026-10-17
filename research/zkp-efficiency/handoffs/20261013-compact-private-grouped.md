# Handoff: compact private leading planes in grouped SC_SZC

Cycle0043, `20261013T002555Z-f0cb53eb`. Research-only, uncompiled/unapplied.
**Synthetic parity passes; no native speed or complete private8B proof.**

Artifact: `research/zkp-efficiency/experiments/compact-private-grouped-20261013/`.
Read README, result, constructor-result, cost-accounting, input-manifest and
commands/logs. The prior public grouped adapter is in
`experiments/heterogeneous-grouped-driver-20261012/`; neither is production.

## Interface and exact source seam

- `argument.rs:208` priv_table; `table_of/build_tables_at:300/338`;
  `run_slot:496/547/553`, total/census:407/500; SC_SZC:1719/1720.
- `zkp-core/src/sumcheck/grouped.rs` immutable row reads, round/fold/finals;
  `SumcheckRounds` masking/transcript boundary unchanged.
- SC_SZC's A_MX/A_SUM source: Cm::A, one unit slice at Layout-owned a_off,
  log(Dom::Ht), coords Rho(0..lht), extension round0. Native support_Ht is
  lifted over j and must remain distinct from support_S.

`leading_private.rs` defines `LeadingPrivate::try_from_priv/at/bind/terminal`.
It should be called only for the native-selected SC_SZC A_MX/A_SUM tables,
then installed as a Leading entry beside the prior mixed table variants.
Dense fallback for unsupported public coordinate/slice mappings; exact
immutable source pd.data supplies the compact plane. Do not accept external
lift flags or examine private values to select a representation.

Data rounds bind leading variables in-place and truncate; trailing binds
advance public schedule once. Reads map the logical cube to the remaining
compact source. Native Vec capacity remains H until the slot is dropped.
The Python algebra uses allocation-based folds, so no Rust peak inference.

**Keep original Tab::Priv metadata and full original ordered final vector.**
mask_eval, claim_point/build_claim, mask_row, ext_round, private terminal count
and commitment claims keep their existing sites/source. Arbitrary private
extension targets are not leading-axis tables and must not be compressed.
Generic total/census readers must preserve logical extent and exact order.
SC_SZC Host does not normally call generic total; total tests are compatibility.
Native small/parallel cutoffs and immutable read/reduce/bind barriers need review.

## Validation obtained

Main synthetic check:32fixtures,96 candidate/32baseline schedules,2520
independent original-cube subgroup samples,7560 sample/degree checks,18528
private reader checks,2688 original-order finals,1080 claims,216 terminal
identities,483 recoveries/381 explicit zero-factor fallbacks. Arbitrary
extensions:16128 table/576 expanded polynomial checks.21 edge fixtures/621
reader checks;24 negative controls.14.269063s/22220KiB RSS, one CPU0 nice19
Core Ultra9 thread, seed2026101343,59s/512MiB caps. No invocation failed.

Separate constructor definition:4590 cube/binding checks,270 finals,
93 compact/177 exact fallback cases, seed2026101344,0.296248s/17512KiB;
Base/full/zero, offsets, coefficients, A/H, Fixed/Flip/leading/trailing and
0/1/Fp2 challenges. Independent tuple MLE, not native builder execution.
192 additional accounting formula checks pass. Original14 native/report pins
still match. No masks/RNG/transcripts/native verifier/PCS/device proof executed.

## Cost, ceiling and risks

Conditional h_pad16/T512 two-table payload128MiB ->0.25MiB; folds8388606
->16382, removing8372224 Fp2 mul/sub/add calls each.6.65365% of all30dense
table folds;7.39294% of27dense folds in prior public-reader baseline.
Not that fraction of proving time. Source-model build writes255.75MiB and
broadcast reads127.75MiB removed; source reads unchanged.
Added16775168 reader shifts +dispatch/branch across grouped scans,18inactive
bind calls, metadata/constructor/parallel/census work. Endpoint reads,
row differences/sample advances and grouped brackets all remain.

Complete ceiling Nproved/(Ttotal-Cmxsum_build_fold+Creader_integration).
Numeric accepted8B ceiling unknown; affected native share not isolated.
Whole historical SZC7.794s is only a broad diagnostic envelope. This is a
memory candidate with modest arithmetic reach, not the principal throughput
lever. Larger context still increases attention work quadratically.

Falsify on source/cube/sample/degree/group-claim/order/final/extension/refusal/
mask/RNG/transcript/frozen-byte/independent-verifier/privacy mismatch or
reader/dispatch/peak/enclosing cost consuming savings. Forged lift attestations
underbind; dropping padded private data or extension targets changes outputs.

## Owner's next gate

Integrate one tiny reader behind the mixed table adapter, preserving original
polynomial and materialized oracle. Native original-cube/full-extension,
masked byte/challenge/final/RNG/frozen receipt, fresh independent verifier
and inconsistent-witness/shape refusal gates first. Then instrument
A_MX/A_SUM build/read/fold/census/extension, whole prove/peak and all complete
workload clocks. Guard all native builds/heavy/GPU A/B with shared locks.
No such job has been launched/queued by this lane, and no merge is authorized.

Next local: current mixed-grouped Eq0/1/2 dependency elision, extending prior
symbolic-Eq tests. Their source brackets do not read equality table slots;
retain generic total/census/original point finals/public-zero extensions,
arbitrary offset/short/zero points and source dependency provenance. Test
unused-row traps and unchanged original final order before pricing it.

Accepted independently verified complete private8B tokens0; proof contextnull,
passes0, CPU only. Rates/startup/fraction/witness/proof/serialization/
independent-verification/latency/lag/drain unmeasured. No prefill/resident/
decode proof. Full target and privacy requirements unchanged.
