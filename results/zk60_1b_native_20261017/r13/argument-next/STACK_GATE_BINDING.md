# R13 per-layer folded gate binding

The base calibration's sh_g is not the relation's common gate denominator.
Groups in one layer produce a verifier-derived common G in17..24. Different
layers with equal base calibration can have different G. Shape already has
accuracy_gate_shift and binds it in its reconstructed schedule. A full run
must not copy one layer's G into another layer's schedule.

Planned integration, preserving every legacy byte:

1. LayerRecord gets accuracy_gate_shift: Option<u32>. Legacy records require
   None and encode nothing extra. Every R13 record requires Some(G), even
   when G equals the base shape's scalar; one canonical encoding.
2. LayerRecord::of_block derives G from the bound AccuracyPublic. Its block
   digest already binds all arrays, registry and regenerated caches. The
   trained statement additionally encodes this shape scalar per layer.
3. The trained statement checks G through Shape::with_accuracy_gate_shift;
   it retains all own-calibration class checks. RunStatement::stage_shape
   applies the layer calibration and G. Its stage schedule and the actual
   prover/verifier therefore use the same G. Caches must compare/derive the
   whole stage shape rather than key only on NormCalibration.
4. Export v2 selects stack per model, not through a global CLI flag. The
   outer loader derives the base R13 geometry; the ten-array accuracy reader
   derives each layer's G, then full public validation matches that layer's
   stage shape. Reload checks the same bound block digest and scalar.
5. IntegerCalibration still names the BASE export shifts (needed for the
   per-layer calibration mechanism), with F_P12, effective norm range24 and
   up shift12 correctly described. Effective precision is determined by the
   registered R13 profile and recomputed AccuracyPublic; no arbitrary
   precision vector is accepted from an export.
6. New run identities and D9/input-length coverage include the optional
   R13-only layer field. Legacy goldens/identities must remain unchanged.

Required controls: changing/omitting G, attaching it to a legacy record,
same-calibration layers with different group sets/G, reloaded data with a
changed denominator, and fresh-process verification under the changed
record must all reach their proper refusal/identity checks. G adds no plane,
lookup, helper, private claim or polynomial degree.

This is a development integration map, not an implemented run capability.
The shared BlockPublic proof refusal remains in place.

## Development proof checks before production activation

After the loader and run paths compile, full native proof tests must exercise
the integrated construction before production availability is enabled. A
test-only scoped availability hook can permit those tests while the ordinary
release path still refuses R13. It must always run the full public-context
validator; it may change availability only, never a relation or a refusal
about input classes. Witness component construction needs no availability
hook: validate its complete public context independently of proof support.
This also keeps Rayon witness construction independent of thread-local test
scope. Run/core proof checks remain on the invoking test thread.

If used, retain the ordinary default refusal until dense DD/non-DD proofs,
mutations and the lookup/no-wrap census pass. Then activate the complete
candidate, remove temporary availability scaffolding, run normal release
CLI/fresh-process/legacy/full-suite gates, and freeze for independent D24.
No hook or development proof pass establishes acceptance.
