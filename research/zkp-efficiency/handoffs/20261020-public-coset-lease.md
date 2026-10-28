# Immutable public coset owner — review candidate, no speed claim

Cycle 0115, run `20261020T231854Z-2da27679`. Research implementation:
`experiments/public-ntt-cache-incidence-20261020/probe.py`, `PublicPowers.get`.
Source/capacity census and independent audit are in that directory. No native
patch was applied and this remains a low-priority candidate pending clocks.

The baseline GPU already caches stage-major NTT twiddles across the process.
Do not reimplement that cache. The distinct repeated object is public powers
of the hiding coset: R9 `zkp-core/src/pcs.rs::coset_powers` and
`commit_zk_owned_with_tag`, `hashline/src/zk.rs::mask_commit_tagged`, and
`hashline/src/pcs.rs::commit_zk_device`. The active/R9 CUDA seam is
`dev_commit_zk_from`'s `d_pows` upload and `ZkReenc.pows`, retained for
`columns_chunked_zk` and its encode helpers. Active source and R9 reviewed
private source are distinct snapshots, not one accepted combined profile.

A proposed interface, not compiled Rust:

```text
PublicPowers::acquire(field, representation, h, nn, device, context_epoch,
                      format_version) -> immutable lease
lease.host_prefix(nn) -> exactly nn canonical Fp values
lease.device_prefix(nn) -> device view, ownership retained through completion
```

The public sequence is prefix-compatible in length. A host slice passed to
`dev_commit_zk_from` must still have exactly nn entries: its existing assertion
checks this. Device encode helpers currently take `&CudaSlice<u64>`; shared
owners/views require reviewed signature and lifetime changes, not merely
replacing a local Vec. `ZkReenc` retains the public owner for deferred opens.
Eviction drops the cache reference only. Growth publishes a new immutable owner
and charges old+new overlap. Device identity and context epoch must prevent
cross-context handle reuse. Asynchronous CUDA completion needs actual ownership
proof; the CPU event model does not validate CUDA stream lifetimes.

Preserve the helper's refusal `h^nn != 1` for the actual requested nn. A coset
can be valid at nn16 and invalid at nn32. Cache hits must not skip validation
on the basis of a different size; any sound validity memo must use the full
public identity and the applicable size premise. Preserve h=0 helper behavior
without admitting any new profile. Leave all shape, q-pad, range, P-3 and
PCS checks intact. Cache no pads, masks, salts, witnesses, encodings,
commitments, opening results or transcript-derived column-index plans. Preserve
all OS RNG stream separation, draw order, refusal and transcript bytes.

Conditional T128/L32 counts: 97 hiding offers plus 32 CPU M power builds per
pass. Public device uploads 48.5 -> 0.5 MiB for the first cached pass and
388 -> 0.5 MiB over eight traces; CPU power builds 129 -> 1. Selected deferred
public device capacity 2.5 -> 0.5 MiB, adding 0.5 MiB idle device and 0.5 MiB
host retention. Resident-mode selected peak does not fall. These exclude other
owners and do not establish actual GPU admission, traffic, fit or speed.

Validation passes 192 synthetic rows/7392 positions, 286 probe checks,
15 control families, 145 request schedules, 22 pinned source fragments, and
92,531 independent audit checks with 50,240 capacity events and 21 file pins.
The independent oracle imports neither implementation. No native leaf hashes,
mask/transcript gates or receipts were generated or verified.

Before implementation, measure exclusive public powers construction and upload
time/counts on the intended admitted complete GPU path. If negligible, keep
this negative and do not spend a build window. If worthwhile, owner uses shared
build/heavy locks, CPU/generic/device value and frozen-byte gates, decreasing
domain/growth/eviction/deferred-opening controls, full-stack receipts with
independent verification and resident fixed-context 1/2/4/8 clocks. Include
fresh randomness, transfer, serialization and pipeline drain in workload time;
verification separately. D30 N-r9-a/b, pending DD privacy gate, D32 fidelity,
and narrow D33/D34/D35 scopes still apply. No new soundness/privacy acceptance
is implied. Main/Claude reviews/integrates; no merge by the explorer.
