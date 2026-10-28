# Owner review note — affine U8 sharing / small exact-alias candidate

Cycle0122 `20261021T061854Z-553803c5`. **No measured proving gain or native patch.**
Dense original-source bitplanes lose on logical DATA (4.82–5.46x nativeU8H).
Preserve that negative. A narrower exact-expression alias is reviewable:
at frozenw_s16/T128, `scaled(sr:1,1)` and `scaled(sg:1,1)` duplicate already
present byte lookups. S13->11/nonDD; Dd9->7/DD. Other scaled checks and signed
pairs are not redundant. The condition is public window geometry, not private
value equality. T512 has no such aliases in this census.

Prospective interface in research: `candidate.py::dedup(expressions)` returns
first-occurrence expressions and `(removed_ordinal,kept_ordinal)` aliases;
all identifiers remain ordered original sources. No production patch exists.
`groups/check_bits/check_bundle` are semantic validators only, not private proof.

Pinned native seams (`experiments/affine-u8-source-sharing-20261021/source-anchors.json`):

- `private_block/layout.rs::lookups_at`: select exact aliases only in a new
  reviewed profile; legacy lists stay reproducible.
- `shape.rs::lookups_per_position/helpers/h_plane_doms/claim_sites`, plus
  HIds and layout offsets: coordinate all plane/site/count changes.
- `protocol.rs::lookup_values_at/byte_histogram_at` and H construction:
  use the same reduced descriptor list on both sides; retain whole-table
  denominator and every original refusal/nonU8 check.
- `argument.rs::helper_sum/SC_TAB`: paired-helper polynomial and global sum
  must use that same list; re-pairing moves coefficients/claims and transcript.

All inventories below count one transformer block at 8B dimensions.
Conditional unchanged-rowwidth/all-other-sites H savings: nonDD3790->3724rows,
8MiBdata+0.25MiBreservedmask; DD3634->3616rows,2MiB+0.25MiB. A+H payload
-0.9173%/-0.2602%. Remaining masks are fresh; one removed site means one fewer
required pair only after a reviewed new schedule, never pair reuse. Complete
M/receipt/functional/group costs unknown. Physical HWM/time gain unknown;
f-exclusive free-deletion ceiling1/(1-f), no numeric GPU rate justified.

Validation: 872684synthetic checks/838native descriptor instances/
608families/132564bit assignments/26control types;219independent source/cost
checks,6pins,2source-mutation controls. Original field-range intersections,
signed[-127,127], highbits, nonBoolean bits, wrong source/order, padded zeros,
stale histogram and absent-entry denominator cases retained. Same researcher
authored reference; not external review, native receipt, or privacy theorem.

Reproduce with `python3 experiments/affine-u8-source-sharing-20261021/run_bounded.py
probe.py`, then `audit.py` through the same wrapper. OneCPU/nice19,<7s measured
per checker,256MiBAS. Source hashes/commands/seed202610210122 retained.

Before integration: inspect owner's actual cheapest passing fidelity descriptors;
derive every M/receipt/group/functional delta; write native failing-first
refusal/round/nextchallenge/receipt tests; owner review/profile/privacy gates;
independent verify; enclosing phase+full-workload A/B under shared heavy/build
locks. Legacy byte equality applies only to untouched profiles; the candidate
needs a distinct pinned profile. Do not launch GPU work from this lane.

Priority: small capacity/count cleanup behind completeGPU and resident clocks,
DD/fidelity and all-elevenFZC. No merge by explorer. No change to private8B
>=50 provedtokens/s target. No mask/opening reuse or coverage weakening.
