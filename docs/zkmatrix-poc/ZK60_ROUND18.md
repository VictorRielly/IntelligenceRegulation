# Round 18 — repaired FFN bound to private endpoints

**O6 follow-up implemented:** the `/2` profile reserves all eight CFS slots in
one FFN mask commitment, before the FFN challenges. Its single M opening and
all W/A/H openings follow both equality arguments. The superseded `/1` draft is rejected. The [O6 disposition](ZK60_ROUND18_O6_REVIEW.md)
preserves the reason for this change. Full joint privacy acceptance is still open.

The experimental `ffn-v3-mr1-fresh-io-poc/2` profile binds the FFN's X and
z16 planes to two independently prepared hiding commitments. It supports the
fixed T32/d16/f16 shape with public weights (P1) or fresh private weights (P3).
The verifier receives expected endpoints through caller policy, independently
of the candidate receipt. This completes the input/output binding implementation
for one repaired FFN. Combined CPU validation passes at `137b109`; details below.

This remains a synthetic FFN demonstration. It does not prove private attention,
a complete transformer block, or use of a registered private model. Whole
transcript zero knowledge, including the new joint seam observations, remains
under review. The round-17 linear analysis does not cover this new profile.

## Construction and lifecycle

Implementation: `hashline/src/zk_ffn_fresh_io.rs`, the private `PendingV3`
owner in `zk.rs`, and the bounded codec primitives in `zk_ffn_fresh_wire.rs`.

1. A trusted caller prepares two 512-word endpoint planes with
   `prepare_endpoints`. Each uses the existing private-seam hiding commitment:
   n=256, seven rows (two data, two terminal masks, three proximity masks),
   inverse rate 8, Q=256. Fresh OS randomness is required. Public expected
   roots, request context and declared scales are saved before FFN proving.
2. `prepare` binds that expected policy into a new transcript domain before
   the FFN's commitments/challenges. Its A layout reserves four additional
   independently sampled rows, two per seam. The base FFN computes its six
   masked sumchecks, retaining M/W/A/H inside a private owner. The two equality
   slots are already committed in M (eight slots, 20 base rows).
   There is no partial receipt, commitment getter, seed or arbitrary-opening API.
3. `PendingProof::finish` consumes that owner and both endpoint owners, including
   on error. It uses slots 6 and 7 of the precommitted M, without drawing more
   randomness or creating another commitment. Each degree-2 slot proves `sum eq(tau,x)*(A_slice(x)-Endpoint(x)) = 0`.
   Its added variable extends the equality table to zero and each private
   plane to its own pair of precommitted base-field mask rows. Only the masked
   terminals are sent. The two CFS slots use ten variables each.
4. Both left equality claims join the existing FFN A claims. One A opening
   handles all seven groups. Opening order is M, W, A, H, input endpoint,
   output endpoint, exactly once per commitment. For the synthetic fixture: A=702, H=1326, W=3 (P1)
   or 11 (P3). A's dedicated IO mask pairs occupy rows 698/699 and 700/701.
   Row coordinates and column tails are derived from the fixed layout.
5. Verification reconstructs that schedule from the public statement and
   trusted expected policy. All FFN arguments, both equalities, CFS openings,
   A/H/W openings and both endpoint openings must accept.

All new terminal pairs are independent of the base FFN pairs. The combined
A claim set and each endpoint pass the existing full-Fp2 mask-rank and
proximity guards. Zero mask/group coefficients and dependent proximity pairs
discard the attempt without redraw. The existing table-coordinate guard now
runs before the repaired table terminals are formed/used. Honest legacy
transcript order is preserved; all four frozen CPU proofs match their archived bytes.

The scales describe integer words (`word * 2^scale`); the equality proof
establishes field-word equality. Model/calibration authorization and the
meaning of those scales remain caller obligations. Accepting a policy file
from an arbitrary prover does not authorize its endpoints.

## Saved receipts and demo

`Receipt` is opaque. Its frame uses magic `HFFNIO\0\x02`, a 32-byte expected
statement binding, the canonical FFN payload with four extra A rows/two groups,
then the two equality arguments and two endpoint openings. The FFN payload's
single CFS opening has 20 column words instead of 16.
Lengths/counts are derived from the supported statement before allocation;
canonical field words, column bounds, exact groups/rounds and full consumption
are required. The frame is capped at 32 MiB. The envelope digest is a framing
check; changing it cannot make a relabelled proof verify.

The separate expected-policy file is exactly 112 bytes: `HFFNEXP1`, context,
two i32 scales and two roots. No endpoint secrets are serialized. The demo
uses public synthetic tensors, commits/saves policy before FFN proving, and
keeps its endpoint owners only in memory. Its verifier branch constructs no
witness, weights, oracle or private commitments.

```sh
cargo build --release --locked --offline --manifest-path hashline/Cargo.toml --example zk60_bound_ffn
hashline/target/release/examples/zk60_bound_ffn prepare
hashline/target/release/examples/zk60_bound_ffn prove p3 1818181818181818181818181818181818181818181818181818181818181818 /tmp/demo.expected /tmp/demo.receipt
hashline/target/release/examples/zk60_bound_ffn verify p3 fresh 1818181818181818181818181818181818181818181818181818181818181818 /tmp/demo.expected /tmp/demo.receipt
```

Use new artifact names and the default CPU build, with all `HL_*` variables
cleared. P1 verification takes the independently prepared public weight root
in place of `fresh`. The trusted caller retains the expected-policy file.

## Validation and continuation

Targeted tests pass for both privacy modes and for fully recommitted wrong
inputs/outputs: the latter decode correctly and fail the corresponding equality
sumcheck. Other tests cover owner/slot mismatch, altered roots/context/scales,
recomputed envelope bindings, malformed lengths/counts, noncanonical fields,
altered CFS/PCS messages, and separation from old profiles. A compile-fail
doctest checks consuming ownership. Existing repaired tests now exercise actual
H helper/table mask removal, every table row coordinate, zero group challenges
and dependent proximity pairs. IO receipts cannot publish archived FFN-only
observations, even when only the final endpoint fails.

Tests also inspect the actual reserved mask-row values across two attempts
in each mode, verify eight slots/20 M rows are present while every opening is
still empty, and require the final M columns to carry all 20 rows. The receipts
are 5,029,244 bytes (P1) and 5,066,204 bytes (P3), 149,536 bytes smaller than the
superseded draft.

Opus O5 (`e793fef`) and O6 (`d130de6`) are integrated in `ea3d886`, with original
source pins and attribution retained. O5's length model covers the old standalone
profile, not IO. Codex fixes O5 F1's public-W parse mismatch, F2's missing slot
count guard/derived mask width, and F4's context-domain mismatch, while preserving
honest wire bytes. A parsed `Proof` remains an unverified candidate. F3's leftover
artifact on failed demo proving and F5's second-shift proving coverage remain
bounded follow-ups; no verifier acceptance vulnerability was reported in O5.
The O4 archive test now hashes its recorded source revision rather than the live
checkout; its historical evidence is unchanged.

The combined run at `137b109` passes:

- 227 storage-enabled Rust tests, including ten doctests; zero failures/ignored.
- 227 affected Python tests: 83 Opus, 57 legacy joint-analysis and 87 gate tests.
- 31 bound-IO and 21 standalone FFN process cases; two retained round-17 saved
  proofs accept, and both superseded IO `/1` receipts refuse under `/2`.
- All four frozen CPU proofs (`v2`, `v3`, `zk`, `zkv3`) match full SHA-256 and
  byte length. Native `freeze-check` passes.

[Validation record](../../results/zk60_round18_validation.json) and
[retained logs/index](../../results/zk60_round18_evidence/index.json) bind these
results to the implementation and tools. Workers ran detached under the shared
heavy lock, with two build/Rayon/test threads and all `HL_*` variables cleared.
Full receipts/proofs remain in `/tmp/zk60-round18-final`; their digests are in
that record. The earlier `/1` run remains separately under `/tmp/zk60-round18`.
Suite v9 pins 227 storage-enabled tests; v1–v8 retain their archived definitions.
No new GPU or full Python validation is claimed.

Next: review the complete joint IO observation schedule, then repair the
attention inventory's remaining private channels and connect a tiny complete
block. Registered private model identity and the priority-3 minimal core
extraction remain separate open tasks. Opus owns bounded review work; Codex
owns protocol changes and final security acceptance.
