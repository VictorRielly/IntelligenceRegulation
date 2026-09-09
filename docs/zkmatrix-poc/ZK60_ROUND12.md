# Round 12 — typed attention checks and durable opening slots

Validated source: `972da4e`, completed 2026-09-08. The detached CPU runner
finished with exit marker 0 in `/tmp/zk60-round12/final`.

The user has Fable working on FA6–FA9, CL21 and the remaining CL20 work and
asked Codex to continue the implementation that needs its attention. This
round keeps those source/review boundaries: Codex owns attention verification
and the new stable-weight slot journal. It does not change Fable's PCS/GPU,
core extraction or independent privacy analysis.

## R32: reject ignored attention messages

`42471f0` closes the typed API's extra-message acceptance. The old verifier
consumed the expected attention sumchecks but did not require the supplied
vector to end there. The regression reproduces acceptance of an appended
sumcheck on an otherwise valid B3 proof before the fix. The retained baseline
test exits 101 because the expected refusal does not happen.

The shared attention argument now checks its consumed sumcheck count against
the supplied count. This uses the executed schedule rather than a hard-coded
tiny-profile count. The ordinary `verify_attn` entry point also rejects
non-empty `helper_sums`, matching the existing bounded B4/B5 rule; attention
helper sums are carried in `vals` instead. No new messages, domains, layouts
or prover arithmetic are added.

The regression checks appended full and empty sumchecks, and both zero and
nonzero unused helper values, through the typed attention and full B3 entry
points. The original proof still verifies after every refusal. This is
structural hardening; FA5 did not identify an arithmetic false acceptance
from those ignored fields. R09's norm alias and R31's registrar range premise
remain open and are still assigned to FA9 for independent proposals/review.

## FA4 H2: public slot journal

`72a884e` implements `hashline::stable_weight_slots`. FA4 §7 permits H2's
deterministic plumbing alongside the independent H1 privacy argument. This
increment is the public-state part of H2: policy binding, durable reservation
and process ownership. It does not store secret material or create a stable
commitment. [The implementation contract](ZK60_STABLE_WEIGHT_SLOTS.md) defines
the API, byte format, failure semantics, storage assumptions and remaining work.

A policy binds the manifest/layer/layout, commitment, PCS parameters, hiding
options and budget. It checks canonical coset and code geometry, including
checked `q_pad = budget * Q`. Those checks supply no repeated-proof privacy
argument or numerical soundness guarantee.

The journal uses one exclusively locked file. Creation never overwrites a
path; reopening never creates or resets one. Each reservation appends and
syncs its record before exposing a non-Clone token. Dropping a token, panic,
or process death burns its slot. Storage errors poison the live handle;
reopening conservatively burns a complete record and refuses a torn/corrupt
tail. Parsing is bounded by a trusted budget and streams fixed-size records.

Tests exercise mismatched policies, invalid parameters, drop/unwind/restart,
budget exhaustion, failed sync/torn tails, corruption, competing handles,
real process termination and eight unique slots across competing processes.
Two compile-fail checks pin exclusive borrowing and non-Clone tokens.
The policy fixture contains public synthetic identifiers, not an approved
private model. No secret weights, masks, pads or salts are written to disk.

The storage boundary assumes a trusted local filesystem and one canonical
journal per commitment. A checksum chain does not detect restoration of an
earlier valid file or protect against malicious rollback. An external
monotonic authority is required for that threat. Linux/WSL is exercised here;
other Unix storage is not qualified by this run.

## Completed validation

[Exact stage and source evidence](../../results/zk60_round12_validation.json)
and [retained logs](../../results/zk60_round12_evidence/README.md) record:

- **191 Rust tests:** 170 hashline unit/integration tests, two compile-fail
  ownership checks and 19 independently built core tests; zero failures or
  ignored tests. The slot process helper is included in the test count.
- The unchanged A01 prove/replay/shared fingerprints and public proof-byte
  parity pass. The source guard advances after explicit review of the two
  added refusal branches; all 45 recorder call lines are unchanged.
- All **four frozen CPU FFN artifacts** preserve their full SHA-256 hashes
  and byte lengths: v2 66,844,928; v3 70,758,084; ZK 87,228,528; ZK-v3
  87,697,008 bytes. Each pass verifies before its artifact is compared.
- B4 reproduces its original **2,144,946-byte** receipt exactly; the existing
  B5 two-block public receipt passes separate-process verification.

The first combined run stopped at two schedule tests: the launcher incorrectly
set `HL_GPU=0` instead of leaving it unset, and the source drift guard detected
the R32 edit. `972da4e` updates only the reviewed source guard and its ledger.
The corrected run preserves the old execution fingerprints; no candidate
trace was used to regenerate them. Both failure and successful-run records
are retained, alongside the expected failing regression on the old verifier.

The run uses two build/Rayon threads, an 8-GiB process address-space cap and
the shared heavy lock. Maximum reported stage RSS is **1,667,956 KiB**, with
zero swaps. Source hashes across hashline and zkp-core remain unchanged
through completion. The unchanged full Python/native suite retains its
round-11 result of 546 passing tests with zero skips and was not rerun here.
No GPU job was run; round-11's GPU evidence remains tied to its original pin.

## Continuation

Fable retains the current queue. FA9 should review the R32 implementation
and focus its patch proposals on the remaining arithmetic/registrar issues.
Codex's next work is to apply those reviewed fixes and finish H2's protected
secret-material/reconstruction boundary, then integrate a consuming slot API
with the reviewed versioned prover/verifier. The full masking/transcript
review still gates repaired FFN and private-block composition. One private
block precedes two connected private blocks.

This round does not complete H2, enable approved P3 weights, repair privacy,
implement a private block, or finish CL20. The existing experiments and
primitive-core boundary are preserved. No GPU benchmark or full-model run
was launched.
