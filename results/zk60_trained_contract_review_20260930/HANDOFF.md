# Exact norm contract review for trained-profile lane C

Run `python3 results/zk60_trained_contract_review_20260930/check_contract.py`. It passed CPU-light exact integer assertions and generated `evidence.json`, including source hashes and all norm-constant use sites. This is arithmetic/constraint evidence, not a trained witness, native proof, or privacy acceptance. The trained 8B >=50 proved-token/s objective remains unchanged.

Two corrections to `trained-calibration-next.txt` matter for implementation:

* Signed int16 includes **-32768**. `Shape::new` currently uses 32767 squared. For width 4096, epsilon 1, the legal all--32768 row gives D=2,097,152, a 22-bit value: the stated derivation needs **wrho=34**, not 33. TinyLlama needs wrho=33. Both still need five byte limbs. This existing maximum formula also has inaccurate documentation for older profiles; preserve their frozen geometry/transcript while making the new profile's bound correct.
* Four limbs do **not** make every D>2^20 unprovable. TinyLlama all-32767, gain=0 has D=1,482,865, rho=3,036,907,520, sigma=3,036,907,519: both fit. Same row with gain=127 has rho=5,485,658,112 and fails despite an in-range output. The exact per-channel condition is max(rho,sigma)<2^32. D<=2^20 guarantees it for every remainder, but is only sufficient. No pair can fit if den>2*(2^32)-1; the all--32768 8B row reaches den=2^33 and is impossible with four limbs.

For a declared restricted range guaranteeing four-limb completeness, the exact sufficient row bound is **sum(x_i²)+Ceps < (2^20+1)²**, for both norms on every token. A bare L2 bound omitting epsilon is incomplete when Ceps changes. Counterexamples and exhaustive small-window residue enumerations are retained. These facts characterize obligations; they do not authorize a restricted profile, suppress failures, or alter P1.

The five-limb route needs top-byte tightening to wrho=33/34, not an unrestricted 40-bit remainder. The generated no-wrap bounds cover adversarial legal limbs and gains -128, plus input -32768, at CN<=65536 and positive CEPS<=2684. Isqrt constraints are bounded **before** using honest D_max; quotient clauses are then bounded after promoting D from those constraints. All reported absolute clause bounds are below Goldilocks p. This is pointwise integer lifting; random batching/sumcheck soundness and whole-proof privacy remain separate. An explicit i64-sized oversized CN produces a nonzero integer residual equal to p, demonstrating why arbitrary coefficient parameterization cannot inherit these bounds.

Parameterization must reach all live sites, not just the kernel and witness:

* `shape.rs`: CEPS and signed absolute endpoint in D_max; TN in norm window derivation. New profile fields and validation must keep old profile defaults frozen.
* `witness.rs`: sum epsilon and numerator for **both** norms; current `norm_limbs_are_the_pinned_count` rejects five limbs, and output-plane identity must follow the shifted Ids.
* `slot_ir.rs`: CEPS in SC_SS/SC_SSM host terms, CN/TN in both SC_DZC norm clauses.
* `argument.rs`: CEPS in both norm hosts, CN/TN in the optimized SC_DZC base-field coefficients. Changing only slot IR leaves this prover/verifier path mismatched.
* `layout.rs`: schedule's calibration description and exact top-limb range lookup. Update new-profile documentation and denominator/window bounds.
* `private-block-kernel-shaped/src/lib.rs`: Shape fields, validator and both norm executions. Preserve frozen-guest/toy parity defaults.
* `norm_alias.rs`: tests use global constants and assert wrho<=32 on their current registered profiles. They are **not** evidence for 33/34-bit new profiles; extend independent alias checks to the new profile without replacing old expected values.

Global `calibration_identity()` remains a fixed literal; a new trained calibration identity/policy must independently bind the changed coefficient values and source/model calibration. A schedule digest changing does not alone turn that literal into a trained calibration identity. No production files were changed by this lane.
