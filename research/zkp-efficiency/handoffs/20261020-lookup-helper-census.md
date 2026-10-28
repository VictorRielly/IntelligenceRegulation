# R9 recurring U8-helper census — owner review handoff, unapplied

Run `20261020T111854Z-3f58f916`, cycle0103. **No proving speedup, native patch or privacy acceptance.**
[Experiment](../experiments/lookup-helper-census-20261020/README.md).

Question tested: can a new fractional protocol remove enough recurring H data
to matter after DD, and what tree schedule would avoid increasing memory?
R9 w32/fE9 public fixture: 8B T128 U8 helper data420.25MiB non-DD or390.25MiB
DD, 88.707%/85.911% of H input and46.727%/45.135% of A+H input. This is gross
helper data, not removable net bytes, proof size, traffic or time. D/F carry
136/160MiB in both; DD changes the S/Dd side. At COUNTED ONLY T512,
2480.5->1760.5MiB; no T512 trained R9 profile or proof established.

Public U8 values/index metadata may persist. Its256 reciprocal entries depend
on fresh per-attempt alpha/gamma and cannot be reused across proofs. No extra
query-value commitment exists to delete. Private helper data recurs every
block/pass. One native global multiplicity histogram must enter once; a
per-domain-table split requires newly bound local histograms, not copies of
the existing global histogram. Keep all83 original ordered U8 column links
atT128 and85atT512; these are not83/85 separately required PCS openings.

Storage negative: full global tree4GiB atT128, exact full column forest3.096/
2.885GiB nonDD/DD, all larger than removed U8 helper data. At countedT512,
global32/16GiB and exactforest18.254/13.098GiB, before scratch. Streaming one
column has smaller arithmetic storage (largest128MiB T128/512MiB T512), but
that does not price the whole masked GKR schedule. Original leaves/A binding,
retained reductions, fresh masks/claim sites and recomputation costs remain.
A literal internal fraction node has3Fp2 products/1addition; this is a
construction count, not mandatory optimized work or a native timing floor.

Actual Rust seam (frozen R9 read-only source under
`results/zk60_1b_native_20261017/r9/frozen-tree/`):

- `hashline/src/private_block/shape.rs`: `lookups_per_position`, `helpers`,
  `h_plane_doms`, `claim_sites`, `totals`.
- `layout.rs`: `lookups_at`, P-3 `domain_log_at`, `HIds` and H plane offsets.
- `argument.rs`: `helper_sum`, SC_TAB/SC_DD original constraints and sites.
- `protocol.rs`: `u8_denominator_inverses`, `write_h`, H construction/commit
  and `logup_sum_claim`.

Research interface: executable `probe.py` emits `census.json`, one row per
public fixture with domain size, original lookup/helper counts, H base words,
helper data bytes, ordered-column obligations and topology arithmetic/storage.
`reference.py::census` independently constructs symbolic ordered lookup lists
and the explicit H plane list. `reference.py::rational_tree` operates only on
tiny private synthetic fraction pairs. Nothing is a Rust/GKR/CFS replacement.
Patch location is research only; owner must design a new versioned protocol
before any native integration. Existing source pins in source-manifest.json.

Validation: 1098 checks/46 fixtures/13 controls; audit 1381 checks,
34 source-fragment mutation controls,624 altered-census controls,160 explicit
topology checks; five source pins unchanged. OneCPU thread/core0,nice19;
probe0.008066s/16248KiB, audit0.019911s/16336KiB;
59sCPU/alarm,60sparent,512MiBAS,estimated64MiB. Exact commands/hardware/seed/
source hashes retained. Initial erroneous join-node count and failure preserved,
corrected by explicit full-binary-tree accounting. No native proof/refusal tests.

Before promotion: new masked mixed-height reduction, ordered original A links,
one global histogram committed before challenges, all unused/table denominator
refusals, degenerate(0,0) exclusion, original exact integer relations,
complete claim/mask/PCS accounting, joint nonlinear/terminal privacy and current
soundness/fidelity review. Prior fractional-root singleton disclosure and
weak-leaf deletion controls remain binding. R9 N-r9-a/b and DD privacy gate
owed. No public unmasked roots, mask reuse or new reuse of private openings.

End-to-end ceiling: unknown exclusive affected fraction f; free deletion
<=1/(1-f), while this replacement adds work. No numeric GPU/full-model rate
follows from bytes. Falsify on any binding/refusal/parity/privacy failure,
or if new reductions/masks/openings/launches cost more than avoided work.

Next local: small mixed-height forest lifetime/recomputation cost ledger,
including every ordered column and one original table, differential tiny
root arithmetic and wrong-site/multiplicity controls. Owner: complete GPU
phase/capacity evidence, verified fixed-context1/2/4/8 resident passes and
higher-priority all-eleven FZC compiler A/B under shared locks. No merge here.
New independently verified full-stack proofs/passes/positions0/0/0; all new
full-stack clocks/startupfraction/steady-totalrates unmeasured; no actual
modelcontext/GPU,longprefill,residentpass ordecode. 8B>=50/s remainsunachieved.
