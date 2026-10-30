# Conditional support-checked immutable borrow; clocks required

Cycle0133, `20261029T025649Z-b1039010`. Main/Claude reviews and integrates;
no native patch applied, compiled or merged. No proving speedup measured.

Baseline `ops/zkp-mvp/trained-1b/hashline/src/private_block.rs:460` already
scans off-support entries only; original row-major fallback preserves the
first refusal. Five attention and four FFN support calls exist. The inspected
8B geometry reads only24MiB/check, entirely FFN padding; attention reads0
weight bytes. One extra32-layer sweep is768MiB logical reads. This is not a
measured runtime or DRAM saving. Native static sites do not give call counts.

Candidate interface / code locations:

- [Design](../experiments/support-scan-capability-20261029/candidate-interface.rs.txt):
  private child-module `SupportChecked<'a>` borrows actual `BlockPublic`.
  Constructor performs original full check, fields are private, no detached
  certificate/deserializer/assume-valid API. Exact role/extent/D/Q/F support
  evidence stays attached to that borrow. No interior mutable weight storage.
- Existing Rust seam: `AttentionPublic::check_words`574,
  `FeedForwardPublic::check_words`720, `BlockPublic::check_for_shape`802;
  witness build643/644, protocol lookup-miss578 and core entry points,
  run `blocks_fit_the_shape`873. Full pins/site index in experiment.
- Propagate the checked view across actual repeated same-owner calls.
  Preserve lengths and original check order; key mismatch uses original
  validator. Recreating the view per existing call saves zero. Reload/new
  owner still pays first validation; never trust a cached file/manifest want.

All table checks stay live: tokens/RoPE, f_e/exp range/order, act[128] and DD
capacity; also profile, approved provenance, original block digests and outer
bindings. Equal padded Q lengths/cardinality do not bind interleaved heads.
No new transcript, masks, salts, pads, challenges, openings or private caches.
This P1 public-weight source analysis establishes no P3 cache authority.

Validation: independent dense oracle,32 synthetic fixtures,23,112 checks,
11,040 single-byte mutations,9,014 negative-control checks;6.332390s/18,228KiB.
Independent source/cost audit201 checks;8 pins unchanged. Model tests verdict
classes/order rather than native exact messages; source lifetime/type safety,
all native arithmetic/RNG/transcript/PCS/golden/independent receipt/privacy
checks remain owed. Python privacy is conventional. Controls demonstrate a
caller-supplied shape-only certificate with changed bytes is unsafe.

Savings ceiling: N/(T-C+A), C=exclusive removable same-owner support time,
A=added key/lifetime overhead; no native C/A measured. All-loader bounds are
inapplicable because validation also recurs outside loading. Owner next:
instrument call counts by public phase/role/shape (no values/addresses),
exclusive support/table/hash/witness/proof and enclosing clocks. Proceed to
implementation only if measured incidence and fraction justify API work.
Review CS1/CS4 per-entry semantics and first refusal/H1 before a port.

Falsification: changed refusal/order/data/binding/RNG/transcript/receipt/
privacy result, stale/mutable owner, missed support geometry, owner churn or
no enclosing gain. Resident passes require real retained ownership; long
prefill and decode are separate. Target>=50/s remains unachieved; zero new
proofs/passes/positions. No heavy job queued.
