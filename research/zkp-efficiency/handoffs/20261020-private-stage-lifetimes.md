# Private-stage lifetime accounting for owner review

No optimization patch is proposed. Release-only saves no work in the pinned
schedule; output-only residency eviction is too small to justify a build
without a measured capacity cliff. This handoff is an accounting/telemetry
interface, not an integration request or security acceptance.

Research code: `experiments/private-stage-lifetimes-20261020/model.py` and
`audit.py`; source line anchors/hashes in source-facts.json/source-manifest.json.
R8 run.rs917..1031 and protocol.rs1018..1172; separate GPU candidate
run.rs684..791 and protocol.rs882..1039. R8 stage-specific shape is distinct
from the older GPU door. Never assume these trees have equal supported profiles.

Observed source order: OUT retained across the run; previous/current boundary
coexist in intermediate stages; A/H coexist until their openings; M is host
encoded, not a GPU PCS commitment. A/M/H already drop after their openings.
Boundary opens exactly once with both adjacent claims. Pool drops retain idle
backing. Chunked DevCommit additionally retains raw pads and powers.

Proposed LOCAL telemetry event (not public receipt data):
`stage,phase,role,public_geometry,store_mode,requested_data_bytes,
actual_pooled_active_capacity,pooled_idle_capacity,raw_active_bytes,
twiddle_capacity,public_cache_capacity,driver_free_delta,completion_epoch`.
Roles A,H,IN,OUT,B_previous,B_current,mask_host,constructor_scratch,
opening_scratch,FZC/DZC raw tables. M host bytes reported separately.
Use public stage/shape metadata and allocator capacity; no values,addresses,
prompt-dependent logs,randomness or challenge material. No caches of masks.

Phase points: before/after boundary prepare; A commit; M host commit;
H commit; raw sumcheck construction/finalization; mask opening; A/H opening
and drops; incoming boundary/endpoint opening; output opening; serialization
and sink. Record commit/open transients inside cuda.rs as well as phase ends;
sampling just phase ends misses scratch peaks. Completion must precede any
reuse/free. Keep actual device counts/VRAM and CPU/driver/build pins.

Current tests: independent declarative relation/dependency oracle and interval
capacity checker; toy storage checksums only. Run commands in README. Earlier
releases/double openings/wrong boundary sides/stale restores are negatives.
No native Rust/CUDA build,mask/NTT/PCS/receipt differential or GPU run occurred.

Owner validation: complete phase/backing counters on a supported workload,
strict device/fallback accounting,actual peak and transfer clocks; exact
native receipt bytes and independent fresh verifier; current refusal,H-1,
soundness/privacy pins. All native work uses shared build/heavy locks. Then
measure fixed-context resident1/2/4/8 complete passes,witness/proof/serialize/
verify,total/steady rates and startup fraction. Keep prefill/decode distinct.
Do not count one block as a model pass. No merge from this lane.

Next local extension is H-commit and FZC/DZC raw scratch intervals; actual
whole-prover peak remains unmeasured. See owner-dd-update.json for newly found
R9 count/test status; it does not establish a reviewed DD full-stack result.
