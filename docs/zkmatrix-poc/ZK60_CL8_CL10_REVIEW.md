# CL8/CL10 review — correct the counting models

Codex, 2026-09-06; source pin `39272d6`, no lane edits or GPU execution.
The pinned **13 pending-memory tests and nine artifact-profile tests pass**.
Additional count-only checks reproduce the issues below. Commands, log hashes
and observed outputs are recorded in
[`results/zk60_round7_claude_review.json`](../../results/zk60_round7_claude_review.json).

## CL10: P1 and P3 column costs differ

`mistral_v3_layer(mode)` selects the same W row count and salted-column formula
for both modes. The real layout has **10,752 ordinary W rows** under P1 and
**10,774 hiding W rows** under P3: 22 added mask/proximity rows. A Rust helper
confirmed these counts through `ZkLayoutV3::new`, constructing only metadata,
not full-width tensors. `Opening` writes no per-column salt; `OpeningZk`
writes 32 bytes per column. The FFN serializer selects the corresponding W
opening according to the privacy mode.

Keeping the handoff's declared A/H rows and 256 checks:

| Component | P1, corrected | P3, as declared | P3 minus P1 |
|---|---:|---:|---:|
| Opened column field data | 35,606,528 B | 35,651,584 B | 45,056 B |
| Column framing, including salts where present | 415,744 B | 423,936 B | 8,192 B |
| These two components together | 36,022,272 B | 36,075,520 B | **53,248 B** |

The observed artifact delta is 65,632 bytes, leaving **12,384 bytes**, not
65,632, for the residual delta. The report's assertion that all mode cost
lands outside columns is therefore false. This is a serializer/layout count
correction, not a new measured Mistral proof; A/H counts remain the declared
handoff inputs.

The residual is also mislabeled: the declared layouts leave group/proximity
vector lengths at zero, so their real serialized bytes are included in the
residual alongside sumchecks and terminals. It is not an exact measurement
of argument/claim/term bytes alone.

Required follow-ups:

1. Declare separate plain/hiding opening layouts and actual W row counts for
   each mode. Test against Rust layout/serializer counts rather than constants
   copied between the model and its tests.
2. Count group/proximity vectors explicitly when their actual shapes are
   available; otherwise label them as part of the unknown residual.
3. Replace the claimed independent P1/P3 cross-check. Subtracting the same
   derived constant from two artifacts preserves their difference by identity
   and cannot detect the incorrect mode-dependent allocation.
4. Keep byte accounting separate from serialization/transfer/allocation time.
   The corrected dominant column share is useful, but a size partition alone
   does not prove that serializer runtime has no optimization opportunity.

## CL8: validate dimensions, units and actual lifetimes

The symbolic-plan refusal (`peak=null` when unresolved terms remain) is useful
and should stay. The concrete component model still needs these corrections:

- **Chunk rounding:** `chunked_hiding_commit(300, 10, 4, 16, 1)` reports
  8,192 coefficient bytes. The device clamps to at least 128 rows, requiring
  1,048,576 bytes for that scratch buffer before any oversized pool reuse.
  Mirror the shared chunk plan, including nonmultiples of 128. The correction
  in the other memory planner did not reach this separate counting tool.
- **Invalid dimensions:** a buffer with `count=-1` is accepted as a complete
  plan with peak **-8 bytes**. Reject negative/nonintegral counts and invalid
  element sizes, empty/duplicate schedules and unsupported parameter shapes.
- **Release versus free:** the model treats every released buffer as pooled.
  Raw pads/powers/leaves are not pooled. Its resident plan retains pads,
  powers and leaves through return even though the resident result retains
  data/encoding and the callee has dropped device leaves. Add separate free
  and pool-transfer events with correct actual return lifetimes.
- **Concrete pending units:** `ffn_rows={"W":100}` becomes a buffer of 100
  elements (800 bytes), although the API/documentation describes row counts.
  Require explicit column width/retained representation, or rename the input
  to element/byte counts and define exactly what it includes. Missing layout
  information must remain symbolic.
- **Reuse:** a matching resident peak does not validate reuse or later
  lifetimes. Track allocation identity/capacity when `take_min` transfers a
  larger pooled allocation to a smaller request; do not count it twice.

These tools already report `safe_to_run=false`; keep that distinction. A
correct numeric subtotal still cannot authorize a pending private block whose
mask plan, attention relations and workspaces are not implemented.
