# SC_TAB masked-model conformance handoff — 2026-10-28

Cycle0129, run `20261028T225649Z-6db80b72`. No native speedup measured.

The [experiment](../experiments/sc-tab-mask-conformance-20261028/README.md)
adds source-derived CFS/full-cube and keyed/unkeyed BLAKE3 framing checks to
[cycle0128's periodic public descriptor](20261028-periodic-sc-tab.md).
817checks/60rounds/36reserved-pairclaims/57controlinstances pass; independent
original-cube/Boolean-suffix oracles agree. Source audit83checks passes;
nine native pins unchanged. CPU model6.526771s/21588KiB; no native build/GPU.

Patch/interface: prior `experiments/periodic-sc-tab-20261028/candidate-periodic.rs`
is an uncompiled/unapplied sketch. New `masking.py`, `mask_reference.py` and
`probe.py` supply a synthetic regression recipe, not a Rust replacement.
Native seams are `private_block/argument.rs` Tab/build/run_slot/verifier and
`zkp-core/src/sumcheck/rounds.rs`; preserve full n/degree, six private terminal
positions, mask coefficient layout, initial standalone None claim, public
zero extension, reserved pairs, both mask functionals and absorption order.
Full native pins and exact test commands are in the experiment.

Do not truncate the mask because public rows repeat: at R12T128 the slot
still needs the same47coefficients on15variables; four lifted-fixture controls
change the scalar under truncation. Public-only payload/lerp counts remain
786432->12288B and49149->765; not measured peak/time and not additive with
prior tiling. All private/full-cube/witness/commitment/PCS work remains.

Owner next: exclusive constructor/public-fold/SC_TAB/enclosing clocks first.
If material, implement native adapter and run golden/freeze/transcript/next-RNG/
refusal/capture/privacy and independent complete receipt verification under
shared heavy/build locks. No heavy job queued here. The model's domain/key/
prelude and width8 row pairs are synthetic; RNG, native HashTag, committed
openings, actual profile/receipt/privacy and real device behavior remain owed.
Main/Claude reviews/integrates. This lane does not merge.
