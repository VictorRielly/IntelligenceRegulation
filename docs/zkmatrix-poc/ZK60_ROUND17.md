# Round 17: saved repaired FFN proofs and separate verification

Implementation: `29d34362f54a8539799a6f7a74211dd43aed15cc`.
Opus review delivery integrated through `2fb7e0a`.

The repaired T32/d16/f16 FFN now has a bounded byte format and explicit
`prepare`, `prove` and `verify` commands. The verifier consumes the saved proof,
fixed public fixture metadata, caller-selected weight policy and request
context. Its command path never constructs weights or a witness, executes the
oracle, or invokes the prover. This advances round 16's in-memory proof into a
portable FFN demonstration. It remains function 1, with no externally bound
input/output, attention, private block or registered private model identity.

## Format and trust boundary

`hashline::zk::fresh_poc::{Proof, encoded_len, verify_bytes}` implement the
experimental `ffn-v3-mr1-fresh-poc/1` format. The legacy proving engine,
Fiat–Shamir transcript and flat payload writer are unchanged.

The 41-byte envelope is `HFFNMR1` followed by version byte `01`, a one-byte
weight mode (1 or 3), and a 32-byte expectation digest. The digest uses a
separate `fresh-ffn-wire/1` transcript and includes the experimental profile,
public statement, actual table values, request context, weight policy and P1's
expected public W root. It is an early routing check, **not authentication**:
tests relabel an envelope with a different context/root and require the actual
cryptographic verifier to reject it.

The remaining bytes follow `LayerProofZk::to_bytes()` order: W/A/M/H
commitments, six arguments, the CFS opening, the selected W opening, A and H.
There are no vector-length fields. All loops and allocations use the checked
external statement and fixed profile rules:

- T32/d16/f16, log_cols 8, inverse rate 8, 256 column checks, function 1.
- Signed shifts remain supported throughout -8..=16. The verifier recomputes
  A/H row counts from those shifts; encoded commitment counts must agree.
- Six sumchecks have their expected round/degree widths and respectively
  3, 2, 10, 4, 1 and 12 terminals. W has two opening groups; A and H have five.
- Ordinary W vectors have 256 elements. Hiding vectors have 512 elements,
  including 256 pads. CFS vectors have 1024 elements. Each opening carries
  exactly 256 columns; ordinary/hiding PCS paths have depth 11, CFS depth 12.
- Each field limb must be strictly below the modulus. Indices must lie in
  their domains; truncated, trailing, wrong-mode and wrong-version files refuse.
- Global frame cap: 32 MiB. The largest allowed shape, with four shift-16
  remainder tables, has 2609 A rows and 5154 H rows. Its exact frame size is
  16,486,717 bytes in P1 or 16,523,677 in P3. Contexts are bounded to 4096 bytes
  and the public table-digest label to 256 bytes.

`Proof::from_bytes` only parses. `verify_bytes` parses **and verifies**. The
encoder validates typed shapes and canonicality but makes no acceptance claim.
Only public proof data survives the prover call or enters the file.

## Run it

Build with all `HL_*` switches cleared, two Cargo/Rayon threads and the shared
heavy lock. The executable is CPU-only. Run `prepare` before generating proofs
and retain its public weight root independently:

```sh
cargo build --release --locked --offline --manifest-path hashline/Cargo.toml --example zk60_fresh_ffn
hashline/target/release/examples/zk60_fresh_ffn prepare
hashline/target/release/examples/zk60_fresh_ffn prove p1 request-1 /tmp/ffn-p1.proof
hashline/target/release/examples/zk60_fresh_ffn verify p1 EXPECTED_PUBLIC_ROOT request-1 /tmp/ffn-p1.proof
hashline/target/release/examples/zk60_fresh_ffn prove p3 request-1 /tmp/ffn-p3.proof
hashline/target/release/examples/zk60_fresh_ffn verify p3 fresh request-1 /tmp/ffn-p3.proof
```

Replace `EXPECTED_PUBLIC_ROOT` with the root retained from `prepare`. P3's
explicit `fresh` policy accepts a newly committed hidden weight matrix; it
does not authorize a previously named model. Proof paths must not already
exist. All example tensors are public synthetic fixtures.

`scripts/zk60_fresh_ffn_process_check.py --binary PATH --output NEW_DIRECTORY`
automates the process boundary: every invocation gets a different empty working
directory, and each prover exits before verification starts. It exercises both
modes plus altered context/policy/mode, proof corruption, hostile row counts,
truncation, trailing bytes and overwrite refusal.

## Review integration and remaining privacy work

Opus's O1–O4 delivery is retained with its original attribution and source pins.
The O2 adapter imports Fable's existing `RoleModel` unchanged, independently
reconstructs allocation/claim roles, and checks pair coefficients and captured
group/terminal consistency. It keeps legacy captures as positive controls.
The reported four-capture linear result is A/W disclosure 0; H disclosure 2,
exactly its public LogUp identity. This model excludes pad/column leakage, CFS
messages, repeated proofs and the full nonlinear transcript. Integration does
not turn it into a whole-protocol privacy approval.

O3's late table-point check is a placement concern for future streaming or
pending-proof APIs. In the current fresh API the check returns `Err`, all proof
state is local, and no proof bytes escape. Moving it earlier and adding
direct H/table/proximity negative controls belong with the next ownership/seam
change. Its historical observation that `Proof` lacks serialization is
superseded by this round; the new `Debug`/wire surface contains public proof
data only. Zeroization is separate from transcript privacy.

O4 confirms attention is currently a public argument. Its six private claimed
sums, bilinear score/PV slots and nineteen helper-sum claims require explicit
private constructions. Merely replacing its PCS calls is insufficient.

Opus's small `eval_many` extraction (`2dec4a9`) is delivered in the core lane
and remains queued at priority 3. It is not merged in this round.

## Validation

Validation is complete. [Exact record](../../results/zk60_round17_validation.json)
and [retained logs/commands](../../results/zk60_round17_evidence/index.json).

- 220 storage-enabled Rust tests pass, including the two wire regressions and
  the existing repaired-proof/recovery controls.
- All 21 separate-process cases pass. Saved frames are 4,733,245 bytes (P1) and
  4,770,205 bytes (P3), each 41 bytes above its logical payload. Proof digests
  and independently prepared public policy are recorded in the evidence.
- All 213 affected Python tests pass: 87 gate tests, 69 Opus tests and 57 legacy
  joint-analysis tests. The review tests run with actual captures and no skips.
- All four CPU legacy proof digests and lengths remain exactly frozen. The
  native lattice `freeze-check` also passes.

The initial gate run failed two stale assertions naming default suite 7;
`53e831c` fixes them by using the configured default. Their corrected module
passes. Rust implementation/validation source is `29d3436`, review integration
is `2fb7e0a`, and completion source is `53e831c`. No Rust code changed between
those revisions. Initial failures remain in the retained evidence.

Suite v8 preserves versions 1–7 and changes the expected storage-enabled Rust
count from 218 to 220 for the two wire regressions. This round reruns the four
CPU frozen cases, not the full CPU/GPU floor suite or the full Python/native
suite. The unchanged GPU paths retain round-16 evidence; no new GPU or
performance qualification is claimed. All heavy runs used two threads, the
shared lock, an 8-GiB per-process address-space cap and detached completion markers.

## Next implementation milestone

Codex next gives the repaired FFN a consuming pending-proof lifecycle and
input/output seam claims. Acceptance requires the same committed X/z16 values
to match independently supplied endpoints, wrong endpoints and a second opening
attempt to refuse, and verification from bytes in a separate process. The
existing function-1 frame stays identifiable as its current narrower claim.

Then implement the private attention obligations from O4 and compose a tiny
private block. Registered P3 weight identity remains an explicit separate
requirement before claiming a proof about a named private model. Only after
that block verifies should work advance to two blocks and larger models.
