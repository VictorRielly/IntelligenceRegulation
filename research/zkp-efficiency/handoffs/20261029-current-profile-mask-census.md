# Current R13 public mask-site census — cycle0142

No measured native speedup;metadata reconciliation for existing mask-tail/
paired3 handoffs. Main/Claude owns native review and integration.

Integration seam: frozen R13 `hashline/src/private_block/argument.rs`
`mask_eval`,called from `run_slot`'s extension closure. Exact ordered public
tail is the cache key;private rows,c0,commitment width,addresses and terminal
order stay site-specific. Current R13 changed `argument_accuracy.rs`
zero-checks call the same builder/mask seam. No production patch provided
or applied in this cycle;existing candidate patch remains in
`experiments/mask-tail-incidence-20261029/mask-tail-weights.unapplied.patch`.
Rebase and review it against frozen R13;do not apply blindly.

Reviewable metadata adapter: `experiments/current-profile-mask-census-20261029/`
`prepare.py` extracts six exact Shape methods;`metadata.rs` is compiled with
stub Shape accessors/stack/Dom;`model.py` is independent allocation/count
logic;`legacy_catalog.py` retains prior coordinate/schedule logic;`probe.py`
compares all native census row/site/helper counts and synthetic mask values;
`audit.py` checks exact extraction,pins,registry geometry,count arithmetic.
Interface: `model.geometry(public_census_row)` then `model.census(g,capacity=1)`
returns ordered per-slot pair/tail groups and operation counts. `counts.json`
retains all36classes;`native-metadata.stdout.log` contains8compiledcases.
None of these executes native define or constructor/refusal checks.

| DD32 | f_E | Pairs | Eq builds | Eq products removed | Fresh private-word reads | Added public-sum access bytes |
|---|---:|---:|---:|---:|---:|---:|
| no | 9 | 201 | 33 | 4,764,848 | 5,756,928 | 34,928,640 |
| no | 12 | 204 | 33 | 4,863,146 | 5,855,232 | 35,321,856 |
| no | 16 | 204 | 33 | 4,863,146 | 5,855,232 | 35,321,856 |
| yes | 9 | 206 | 36 | 4,830,380 | 5,896,192 | 36,370,432 |
| yes | 12 | 209 | 36 | 4,928,678 | 5,994,496 | 36,763,648 |
| yes | 16 | 209 | 36 | 4,928,678 | 5,994,496 | 36,763,648 |


Old174-pair non-DD estimate must not be used for current R13. New counts
include two endpoint pairs outside A/H counts. Exact value equality may merge
additional symbolic point groups. Group counts/shifts within a limb class
do not change these pair counts;actual layer calibration/traffic unmeasured.

Validation:22,461checks,564fixtures,4,908independent mask values and4,908
extension terminals,ninecontrols;source/extraction/count audit7503checks,
sevenpins,six exactmethod+nineanchor mutations pass. Commands/seed/hardware/
limits/rawlogs/digests retained in experiment. One initial literal-anchor
failure retained and corrected. Algorithm independence by one researcher,
not external native review. No proving/RNG/PCS/receipt/privacy gate result.

Baseline is unchanged original mask evaluator. Conditional one-entry cache
removes repeated public Eq constructions,adds key comparisons/copies and
longer public-buffer lifetime;all fresh private pairs and reads remain.
Optional eager sums add33/36allocations,up to128KiB sums and35–37MB logical
accesses;prior low-reuse regressions remain. Paired3 is a separate candidate,
not an installed gain. No mask/private-result/opening reuse is authorized.
End-to-end ceiling unknown:N/(T-Cexclusive_removed+Aadded). First obtain
exclusive native Eq-build,dot,extension and enclosing clocks on current R13;
only proceed if material. Falsify on any value/support/width/offset/order/
refusal/RNG/transcript/PCS/privacy mismatch or no verified enclosing gain.

Then native gate:source-pinned baseline/candidate,golden bytes,all existing
malformed/refusal controls,RNG/transcript/PCS audits,captures and independent
fresh-process full receipts,peak/lifetime/serialization/verification clocks.
Native builds/proofs/GPU use owner's current shared locks/admission only.
No heavy job queued. Full8Bhigh-endGPU and resident1/2/4/8 measurements remain
above this small seam. 0new proofs/passes/positions;50/s remains unachieved.

Final owner-document recheck: MVP_STATUS changed concurrently at 12:09 UTC.
The new header was reread: it reports testnet integration, implementation-lane
continuation needs and ongoing classifier gate work. These are owner status
reports, not independently verified liveness or outcomes of this lane. They
change neither this private 8B target nor the frozen R13 source pins. Four
other direction documents remain unchanged. The initial final-audit failure
on the changed status hash is retained under initial-final-audit-owner-change;
the final audit now requires the explicitly reread document hashes. No job
was relaunched and no external action was taken.
