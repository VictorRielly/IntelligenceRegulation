# Mixed FZC arena — research candidate, cycle0095

No measured proving improvement. **No native patch/build/device validation.**
Evidence: `experiments/private-transient-capacity-20261020/`.

The existing raw-source path still reserves `kd*l` Fp2 entries. A storage
candidate keeps17 raw A/H tables3..19 at half length and every other table at
full length. Full Eq/public tables are constructor inputs; derived tables are
written at full length by raw round0; first fused fold writes half length.
At illustrativeT128,F2^21,support,kd23:736->464MiB requested (-272MiB).
A global half stride and quarter-sized raw tables are invalid.

30 toy two-lane mod101/base-challenge fixtures match a direct multilinear
reference, with121 negative controls. This is layout/fold evidence only,not
native Goldilocks Fp2,actual fzc polynomial,masked rounds or proof verification.
72 partial allocation schedules plus independent interval auditing project
272MiB less backing in selected chunked cases, **zero** in all-resident cases
because existing pooled slabs remain owned. Actual device peak/fit/time unknown.
R8 public geometry and active GPU allocator are distinct pinned revisions.

Interface proposal (not implemented): `TabArena { offsets[kd], capacities[kd],
raw_layout }` beside `DevFzcRounds.tabs`. Only unchanged raw eligibility selects
mixed storage. `tabs_requested = (2*kd -17)*l*8` bytes; metadata is public shape
information,never private values. All unsupported/unfused paths stay dense.

Research patch locations are `layout_probe.py::widths/run_fixture` and
`model.py::fzc(packed=True)`. Native owner seam:

- `hashline/src/gpu/cuda.rs::DevFzcRounds::new`, source line4327 allocation,
  constructor per-table views and all later `self.stride` uses, including
  generic fold,finals and host-tail pack;
- `hashline/src/gpu/fzc_kernels.cu::fzs_ld/fzs_impl` (raw source descriptor
  reads,full raw-round0 derived writes,first fusedfold half writes), and
  every later dense addressing helper. Source manifests hash exact snapshots.

Do not apply only the smaller take or global half stride: current constructor
views and kernel accesses assume uniform stride and would overrun it. Do not
free A/H owners; their original rows and sole openings remain necessary. No
private pads/masks/openings/cross-proof state can be reused. This proposal is
an internal representation change; masking schedule/field/transcript/refusal
and statement relations must remain identical.

Owner sequence: first measure actual raw eligibility and fresh versus reused
capacity at H/slot18 on the intended complete workload. If there is headroom
value, enumerate all consumers,then independently implement dense/mixed native
oracles under lane ownership/shared locks. Require randomized Goldilocks Fp2
and actual descriptor polynomial equality,shadow masked rounds+next challenge,
host tail/finals,raw-disabled and failure/refusal/strictGPU controls,exact full
receipt bytes and fresh independent verification. Preserve CS/H-1 and current
privacy gates. Account for offsets/upload,register/indirection costs and delayed
frees. Measure enclosing witness/proof/serialization/verification,startup,
steady/drain and complete peakcapacity. No50/s prediction from this table cut.

Falsify on any missing consumer,uninitialized/full-domain overrun,alias,round/
final/receipt/refusal mismatch,changed privacy,raw unavailable,no actual peak
capacity reduction or enclosing elapsed regression. D33's R7 TinyLlamaT32
acceptance does not accept R8/GPU/8B/next-token; D27/D30/D32/D34 scopes remain.

Next local: native-field/actual-polynomial toy oracle and complete read/write
address census,not a GPU launch. Main/Claude reviews and integrates; researcher
never merges. No external message has been sent by saving this handoff.
