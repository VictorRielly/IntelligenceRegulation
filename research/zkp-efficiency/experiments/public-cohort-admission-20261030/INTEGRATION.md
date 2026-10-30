# Research admission interface — not a production patch

`admission.py::Arena.admit(owner,persistent,round_bytes)` reserves requested
capacity atomically or refuses. Required descriptor adds public profile/source
pins,backend/device,site,round,generation,known reserve and live owner handles.
`use/complete` represents every backend last use; `finish_slot/retire` makes a
table idle only after completion; idle bytes still count. Reassignment increments
generation and never preserves private contents. `open_complete` requires the
trusted driver to certify all later consumers; this one-slot model cannot
derive that fact. Unknown reserve refuses even if toy payload fits.

Actual seam: R13 `argument.rs::build_tables_at/run_slot`, `zk.rs::masked_prove_rounds`,
`SumcheckRounds::{round,fold,finals}`. Both evaluators truncate without shrinking.
`protocol.rs::prove_core` retains A/H/M through all slots, opens M/A/H, then
drops each. Endpoint and later-block lifetimes need the run/boundary owner.
Legacy GPU zerocheck functions are not the actual inspected R13 slot route.

Patch/prototype location: admission.py and probe.rs/metadata.rs in this directory.
Validation: result.json,events.json,counterexample.json and reference.py;
216 metadata cases/2160 numbers,20 small Vec probes,159 budget boundaries,
55 controls. Single-author independently expressed oracle, not external review.
No field/transcript/PCS/GPU test or native merge. Native pins in native-pins.json.

Do not turn CPU encoding payload into a VRAM estimate. Need actual independent
host/device counters for all live/idle/quarantined allocations,PCS/witness and
constructor/open peaks,model and pools. Need actual backend failure/completion
semantics and source/profile/calibration/security/privacy review. Tokens count
only after complete-stack independent verification; fresh masks/pads/openings
remain mandatory. Preserve every per-proof original transcript and refusal.

Owner-first experiment: fixed admitted context, resident1/2/4/8 passes, named
high-end GPU,source/build pins,public setup versus per-proof fresh work,exclusive
witness/proof/serialization clocks,separate verification,startup/drain,actual
capacity,all attempts. Use existing shared heavy/GPU locks. No native promotion
until measured exclusive dispatch savings exceed added costs. Ceiling unknown
N/(T-C_dispatch_critical+A_admit); no native batch or fit claim follows here.
