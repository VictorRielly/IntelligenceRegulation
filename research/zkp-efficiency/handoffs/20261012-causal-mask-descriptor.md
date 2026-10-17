# Owner handoff — compact public causal mask (cycle0037)

Run `20261012T182555Z-4bc569b3`. Candidate passed synthetic differential gates;
no native speed or private8B result. [Evidence](../experiments/causal-mask-descriptor-20261012/README.md),
[tested Python interface](../experiments/causal-mask-descriptor-20261012/descriptor.py),
[unapplied/uncompiled Rust sketch](../experiments/causal-mask-descriptor-20261012/causal_mask.rs).
No production changes/merge/heavy job.

Native read-only target `ops/zkp-mvp/candidate/`: argument.rs Tab:66,
builder:716,causal_mask_at:1013,SC_RS:1270,SC_SZC:1709;
grouped.rs row readers:99,bind:149,finals:175. All snapshots and SHA256 pins
are in native-pins.json. Replace the public mask at construction with an
explicitly typed descriptor at the same table index. Its interface is
`new(n,t_pad)`, `at(residual_boolean_row)`, `bind(Fp2)`, `terminal()`, and
verifier `eval_causal_mask(n,t_pad,rho)`.

Descriptor ignores ALL leading axes, including padded/lifted heads. Mask is
`j<=t` on padded T×T, irrespective of true token bounds. supp_S/supp_Ht retain
separate padding obligations. No rectangular decode/Tk relation is proved here.
Two prefix states grow to O(T); after t bind one T-entry vector folds over j.
T512/32-leading-slot arithmetic:128MiB explicit payload vs24KiB temporary
bound/8KiB t-end payload;8,388,607 dense interpolations vs1,022 compact.
This removes ONE table per slot, not private tables, all witness/attention work
or PCS. The two mask slots' peak savings cannot be added.

Proposed added cost2N-2T integer predicate readers, O(T) preparation and driver
dispatch;common row samples remain. Implement the reader in the round adapter
because GroupPoly Fn+Send+Sync lacks index and cannot own mutating row state.
Descriptor is immutable during scans and updated once after reduction. Keep
explicit cube length and original indices even when the first table is symbolic.
SC_RS's generic total() also needs exact reading;SC_SZC skips it as Host.
Both generic ClosureRounds and GroupedEqRounds,diagnostic census,finals and
small dense test oracle must be adapted. Dense placeholders alone are wrong.

Verifier public terminal still equals recurrence(rho)*product(1-e), as
argument.rs:613 does for current Pub tables. Extension targets remain zero.
Future-score SH_S=6 host stays ungated by causal mask;pad/refusal conditions,
round degree,masked values,opening layout,RNG draw order and transcript stay.
Do not reuse masks or private openings.

Final CPU pass0.960794s/19,804KiB,seed2026101237,one nice19 pinned CoreUltra9
thread,59s/512MiB caps.36 fixtures,48,720 sample values,224 full tail sums of
mask-sensitive contributions,7,952 direct-MLE checks,144 public extension
terminals and19 controls. This is not complete native SC_SZC,honest witness,
private-source/support/P3/grouped-head port,masked transcript or receipt gate.
Rust is uncompiled;capacity/allocator/compiler/reader/peak costs unmeasured.

First integrate the verifier descriptor with native/frozen/terminal/refusal
byte gates,then round+total adapters. Measure mask construction,reader/fold and
parent clocks,then guarded complete-slot/block A/B and fresh independent
verification. Reject parity/privacy failure or enclosing/peak regression.
Accepted8B affected/total clocks absent:ceiling is
Npositions/(Ttotal-Caffected+Cnew),not a numeric model rate.

Current owner priorities stillGPU_SC_SZC+witness andexact full-K down;this
candidate is rank4. Next local experiment tests symbolic supports with exact
grouped-head/P3 mapping and negative separate-MLE-product controls. No new
complete private8B proof or countable token;all required proof rates/clocks
unmeasured. Saved handoff does not establish external delivery.
