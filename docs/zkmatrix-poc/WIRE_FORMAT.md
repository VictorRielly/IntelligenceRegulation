# WIRE_FORMAT.md — the canonical serialized wire format (ZKWF v1)

Status: LANE DELIVERABLE (2026-08-10, U-AG-B1 wave 3, Agent BI,
worktree wt-uagb1-bi). Closes audit finding M-05 (TARGET_CONTRACT.md
Section 4: "Current ~120-170 KB figures are modeled from field-element
counts, not a wire format — the budget binds once a canonical encoding
exists"). Companion code: `zkmatrix-rs/src/wire.rs` (the codec),
`[UAGB1-BI]` section of `src/bin/ring_matmul.rs` (drivers, round-trip
battery, serialized-vs-counted measurement, `uagb1-bi` subcommand).
The serialized-byte numbers this format produces are the numbers the
Amendment A1 budgets bind on at FINAL; the counted-byte convention
(64 B/K-el, 4 B/q31 coeff incl. a 4 B per-poly prefix, 8 B/i64
response, 12 B/reveal) remains the historical modeling convention and
is reported side by side.

## 0. Design rules

1. **Versioned.** Every artifact starts with a fixed magic + format
   version. Unknown version = reject. Format changes bump the version;
   v1 bytes stay decodable as v1 forever.
2. **Deterministic.** One in-memory artifact has exactly one encoding:
   fixed little-endian integer widths, fixed section order per
   artifact kind, no optional reordering, no padding freedom, and a
   canonical-minimal-width rule for signed-integer blocks (Section 2).
   `encode(decode(bytes)) == bytes` byte-for-byte, enforced by tests.
3. **Length-prefixed.** The envelope carries the total payload length;
   every section carries its own length; every repeated element sits
   under an explicit count. A decoder can skip a section it does not
   want and MUST reject trailing bytes, short sections, and counts
   that disagree with lengths.
4. **Reject, never panic.** Decoding returns a structured error on any
   malformed input (the release profile is panic=abort, so this is
   load-bearing, not cosmetic). Every value is range-checked at decode
   time (field-element canonicity, width canonicity, shape
   consistency) so decoded objects are structurally safe to hand to a
   verifier; a corrupted byte either fails decoding or produces a
   shape-valid artifact the verifier REJECTS.
5. **Digest neutrality.** The wire format WRAPS the manifest statement
   codec bytes (cv1/cv2) verbatim; it never re-encodes a statement.
   Statement digests (v3 `statement-125m` 7b913619.., the v4 pass
   statement 76dbf204.., the freeze-pinned reference digests) are
   computed by `manifest.rs` from its own bytes and CANNOT move under
   serialization. Asserted by the battery, not just claimed.

## 1. Envelope

All integers little-endian.

| offset | field | size | value |
|---|---|---|---|
| 0 | magic | 8 | ASCII `ZKMXWIRE` |
| 8 | format version | u32 | 1 |
| 12 | artifact kind | u16 | Section 3 table |
| 14 | field id | u8 | 1 = q8_31 = 2^31 - 399 (all value/tag/challenge material); other values reserved |
| 15 | reserved | u8 | 0 (nonzero = reject) |
| 16 | payload length | u64 | exact byte count of the section stream |
| 24 | sections | ... | fixed order per kind |

The byte stream MUST end exactly at 24 + payload length. Section
header: tag u16, reserved u16 = 0, length u64, then exactly `length`
payload bytes. For a given artifact kind the section sequence is FIXED
(Section 3); a missing, duplicated, reordered, or unknown-tag section
is a decode error — except inside the kind-4 RAW extension space,
which is explicitly tagged and preserved opaquely (Section 3.4).

Artifact kinds:

| kind | artifact |
|---|---|
| 1 | eval-proof artifact (BD stack: bare Tier-N or Tier-Z masked), single statement, W-C two groups |
| 2 | folded-family transcript (BE rigs: joint matmul / stacked zero-check, full commitment grounding) |
| 3 | statement wrap (manifest v3/cv1 or v4/cv2 bytes, digest-stable) |
| 4 | multi-group pass artifact (lane BG's composed object; layout reserved + writer API landed, Section 3.4) |

## 2. Primitive encodings

- **POLY** — one R_q ring element: 128 coefficients, u32 each,
  canonical range [0, q). A coefficient >= q is a decode error. 512 B.
  NOTE vs the counted convention: counted charges 4 + 512 B (a 4 B
  per-poly length prefix). The wire hoists the count into the block
  header, so every poly-dense line serializes ~0.8% under its counted
  figure. The eval-proof level message is the visible case: counted
  5,680 B (4 + 11 x 516) vs serialized 5,636 B (4 + 11 x 512).
- **POLYS** — u32 count, then count POLYs.
- **KELEM** — one K = GF(q^16) element: 16 coordinates, u32 each,
  range [0, q). 64 B — IDENTICAL to the counted 64 B/K-el convention.
  Decision, stated: coordinates are 31-bit values; bit-packing would
  give 62 B (-3.1%) at the cost of word alignment and shift-heavy
  codecs. Declined. Every K-element line in the historical tables
  binds at its counted value.
- **KVEC** — u32 count, then count KELEMs.
- **SINT** — signed-integer block: u32 count, u8 width w in
  {1, 2, 4, 8}, then count two's-complement little-endian values of w
  bytes. **Canonical-minimal-width rule:** w MUST be the smallest of
  {1, 2, 4, 8} that represents every value in the block (empty block:
  w = 1). The decoder re-derives the minimal width and rejects a
  non-minimal encoding ("non-canonical width"), so re-encoding is
  byte-identical by construction. Width is a pure function of block
  content — determinism holds.
- **STR** — u8 length, then that many ASCII bytes (names; length
  <= 32, printable ASCII only, else reject).

Where SINT lands against the counted convention (the load-bearing
divergences, pre-registered in the lane plan):

| line | counted | serialized | why |
|---|---|---|---|
| bare floor digits (e <= 7) | 1 B/coord | 1 B/coord (w = 1) | alphabet is [-64, 63] |
| Tier-Z masked response | 4 B/coord | 4 B/coord (w = 4) | corner bound ~2^27.8 |
| ct-round z responses | 8 B/coord | **4 B/coord (w = 4)** | honest responses are bounded by the wave's l2 bound (< 2^27 at cap-131 waves; typical magnitude ~2^21) — i64 is the in-memory type, not the value range. The fold transcript's dominant line (68.4% at the capstone) HALVES. |
| masked share reveals | 12 B/reveal | 8 B/reveal | (u32 wave, i32 centered value), value range-checked to (-q/2, q/2) |

Width stability: at every recorded shape the honest value ranges sit
decisively inside one width class (floor: 2^6 vs the 2^7 w=1 ceiling;
ct-z: ~2^21 vs the 2^15/2^31 w=4 window; Tier-Z: ~2^25-2^27.8 inside
w=4), so serialized sizes are run-independent in practice. A block
that legitimately shrinks a width class encodes smaller — determinism
is per-artifact, and the budget tables quote the recorded artifacts.

Excluded from the wire, by design: T_cap resample attempt counts and
sampler restart DIAGNOSTICS beyond the Tier-Z restart counter (the FS
counters are deterministic — a verifier re-derives every challenge;
the counted convention never charged them either). The Tier-Z
`restarts` u32 is carried as the F-Z3 logging obligation.

## 3. Artifact layouts

### 3.1 Kind 1 — the eval-proof artifact (bare + Tier-Z)

The BD aggregation-stack artifact at one matmul statement (the object
whose counted rows are UAGB1_AGG_STACK_REPORT.md Section 3/5:
344,318 B bare, 1,527,878 B Tier-Z at 512x768x2048). Section order:

| tag | section | payload |
|---|---|---|
| 0x0101 | META | rows u32, inner u32, cols u32, crs_seed u64, flags u8 (bit0 = Tier-Z; others 0), forced_levels u8 (0 = planner schedule; nonzero = battery-forced level count), reserved u16 = 0 |
| 0x0102 | STATEMENT | the manifest container bytes verbatim (cv1 here — the v3 agg statement) |
| 0x0103 | SUMCHECK | v_claim KELEM, u32 n_rounds, per round KVEC (the round evaluations), finals KVEC |
| 0x0104 | GROUP (exactly twice: weight, then act) | Section 3.1.1 |

GROUP record (0x0104):

    name       STR          ("weight" / "act" — order fixed)
    u0         POLYS        (kappa = 11 outer identity)
    ugh0       POLYS        (level-0 garbage commitment; count 0 at
                             degenerate schedules)
    b_rows     POLYS        (the 16 claim-row ring values)
    n_levels   u32          (levels >= 1 count; level_us entries)
    level_us   n_levels x POLYS (one combined outer commitment each)
    floor_e    u8           (floor digit base, <= 7)
    floor      SINT         (count = floor_rings x 128, ring-major
                             coefficient order; count % 128 == 0.
                             BARE mode: the floor digit rings, w = 1.
                             TIER-Z mode: this slot carries the MASKED
                             RESPONSE rings, w = 4 — the bare floor is
                             never sent under Tier-Z (protocol
                             semantics), so the response appears
                             exactly once on the wire)
    [flags.tier_z only:]
    tz_images  POLYS        (mask images, family order fixed by the
                             protocol: per binding kappa T5 rows,
                             kappa T4, T1, L1)
    tz_restarts u32         (F-Z3 abort log)

The verifier consumes ONLY this artifact plus public derivations
(schedules re-derived from the statement's group shapes by the public
planner; level CRS matrices expanded from crs_seed; all challenges
from the transcript). Diagnostics (tcap attempt lists) are not wire.

### 3.2 Kind 2 — the folded-family transcript

The BE rig artifact (UAGB1_FOLD_REPORT.md Section 5.4's capstone
decomposition). v1 scopes the record to what the two BE rigs emit:
plain standard commitments + linear ct-claims (no Ajtai, quadratic, or
digit-opening fields — those wave-record extensions are reserved for a
format version bump when an artifact carries them). Section order:

| tag | section | payload |
|---|---|---|
| 0x0201 | META | family u8 (1 = joint matmul, 2 = stacked zero-check), layers u32, rows u32, inner u32 (zero-check: 0), cols u32, kappa u8, msg_r u8, n_r u8, reserved u8 = 0, crs_seed u64 |
| 0x0202 | STATEMENT | manifest container bytes verbatim (cv1) |
| 0x0203 | TAGS | u32 n_commits, then per commitment kappa POLYs (t1) + msg_r POLYs (t2), shapes fixed by META (no inner counts) |
| 0x0204 | SUMCHECK | as 0x0103 (v_claim, scheduled rounds, finals) |
| 0x0205 | REVEALS | u32 n_claims, per claim: u32 count, count x (u32 wave, i32 value) |
| 0x0206 | WAVES | u32 n_waves, per wave a CTROUND record (below) |
| 0x0207 | CLOSING | u8 present (0/1), if 1 one CTROUND record |

CTROUND record:

    h        POLYS                   (one reveal per claim)
    n_cw     u32                     (commitments in the wave)
    w1       n_cw x kappa POLYs      (A1-side mask images)
    w_claim  POLYS                   (per-claim message-side images)
    z        SINT                    (count = n_cw x n_r x 128,
                                      commitment-major, ring-major)

The verifier consumes statement bytes + tags + sumcheck + reveals +
wave records + closing (it recomputes commitment digests from the
tags, rebuilds and digest-compares the statement, re-derives every
challenge). Witness data, rho randomness, pad tables never touch the
wire.

### 3.3 Kind 3 — the statement wrap

| tag | section | payload |
|---|---|---|
| 0x0301 | META | statement version u8 (3 or 4), reserved 3 x u8 = 0 |
| 0x0302 | STATEMENT | manifest container bytes verbatim |

Decode re-runs `manifest::Statement::decode`, requires validate() to
pass, requires the container/META version pairing (cv1<->3, cv2<->4),
and requires `encode()` of the decoded statement to reproduce the
embedded bytes exactly. Digest stability is therefore structural: the
wire never owns statement bytes, it carries them. The battery asserts
digest-before == digest-after through a full wire round trip for both
a v3 statement and the real 12-layer v4 pass statement.

### 3.4 Kind 4 — the multi-group pass artifact (reserved for lane BG)

The composition target: BF's pass statement + BE's folded claim
layers + BD's per-group eval proofs, mode-declared per Amendment A1.
Tag space allocated NOW so BG's artifact has a format to conform to;
BG may finish after this lane — deferred conformance at the
orchestrator's merge is expected. Section order:

| tag | section | payload |
|---|---|---|
| 0x0401 | META | mode u8 (0..3 = P0..P3), layers u32, reserved u8 x 3 = 0 |
| 0x0402 | STATEMENT | the pass statement bytes verbatim (v4/cv2 expected) |
| 0x0403 | GROUP-EVAL (repeated 0..255, in statement group order) | group flags u8 (bit0 = this group's floor is Tier-Z masked — the P2 selector: weight group masked, activation group bare), then a kind-1 GROUP record (Section 3.1.1; its own tier-z fields present iff bit0) |
| 0x0404 | FOLD-CLAIM (repeated 0..255) | family u8, SUMCHECK record (as 0x0103), pins KVEC (stacked pin values; count 0 allowed) |
| 0x04FE | RAW (repeated 0..255) | subtag u16, then opaque bytes — BG extension space; subtags 0x0001-0x00FF reserved for BG, 0x0100+ orchestrator. Preserved byte-exact through decode/re-encode. |

Writer API (landed in `wire.rs`, the deliverable-3 entry point):

    PassArtifactWriter::new(mode, layers, statement_bytes)
        .add_group_eval(flags, WireEvalGroup)   // kind-1 group form
        .add_fold_claim(family, WireSumcheck, pins)
        .add_raw(subtag, bytes)                 // forward-compat
        .finish() -> Vec<u8>                    // canonical bytes

    PassArtifact::decode(bytes) -> typed sections + raw sections

Canonicality: repeated sections encode in insertion order; the writer
is the canonical producer (two identical component sets in the same
order produce identical bytes). Per-group masked flags express
P1/P2/P3 without a second layout.

## 4. Error taxonomy (decode)

`WireError` (all decoders return `Result`): BadMagic, BadVersion,
BadKind, BadFieldId, ReservedNonzero, Truncated, TrailingBytes,
SectionOrder, SectionLength, BadCount, CoeffRange (field element out
of [0, q)), NonCanonicalWidth, ValueRange (reveal outside (-q/2,
q/2)), BadName, BadStatement (manifest decode/validate/re-encode
failure), ShapeMismatch (counts inconsistent with META), BadPairing
(kind-3 version/container mismatch). Corruption legs in the battery
exercise both classes: structural bytes -> decode REJECT with the
right error; in-range value bytes -> decode OK, verify REJECT.

## 5. What the A1 budgets bind on (measured, 2026-08-10)

The serialized-vs-counted table, measured by ACTUAL encoding of the
recorded wave-2 artifacts (reproduce: `uagb1-bi wire-battery`,
`uagb1-bi wire-bench eval [tierz] | fold | statement-m125`; full
per-component tables in the ledger BI verdict row). Every serialized
number is a real `encode()` length with the per-component arithmetic
cross-asserted against it; counted totals reproduce the recorded
wave-2 figures exactly.

| artifact (recorded shape) | counted B | serialized B | ratio |
|---|---:|---:|---:|
| eval proof bare, 512x768x2048 | 344,318 | **343,709** | 0.9982 |
| eval proof Tier-Z, 512x768x2048 | 1,527,878 | **1,527,085** | 0.9995 |
| eval proof Tier-Z, 256x768x2048 | 1,511,494 | 1,510,701 | 0.9995 |
| mm fold transcript, 12x(64x96x128) | 12,627,383 | 8,314,493 | 0.6584 |
| v4 pass statement (12-layer, real) | 26,116 | 26,168 | 1.0020 |

- **The A1-relevant rows move by less than 0.2%.** Serialized bare
  eval proof = 343,709 B = 1.311x the Tier N 262,144 B/layer gate
  (counted said 1.313x); serialized Tier-Z single-layer = 1,527,085 B
  (the pass-level Tier-Z number composes at wave 3). The historical
  counted comparisons carry over essentially unchanged, now on real
  bytes — M-05's "budget binds once a canonical encoding exists" is
  discharged with the budget arithmetic intact.
- Structure of the deltas: poly-prefix hoisting -4 B/poly (level
  messages 5,680 -> 5,636 B each); K-element lines +52-64 B per
  sumcheck (explicit counts on rounds/finals — K-elements themselves
  stay 64 B); SINT header +1 B per floor/response block; envelope +
  section headers + META = 121 B per kind-1 artifact, 52 B per
  statement wrap.
- The fold transcript serializes at ~0.66x counted — the ct-z
  response line halves (8 -> 4 B/coord, 68% of the artifact), and
  reveals drop 12 -> 8 B. Relevant to honesty about the wave-2
  artifacts, NOT to the A1 tiers: the composed pass artifact
  replaces the opening volume with kind-1 group records; its
  budget-binding lines are the eval-proof + claim-layer forms, which
  sit at ~counted.
- Digest neutrality measured on the real object: the 12-layer v4
  pass statement digest 76dbf2040409333e is byte-identical through
  the wire round trip (and the v3 reference digests are pinned
  unmoved by the freeze rows).

## 6. Freeze row

UAGB1-BI-1 (in `freeze-check`): the canonical encoding of a fixed
synthetic kind-1 artifact reproduces a pinned SHA-256 (format
stability both directions: the digest moves if ANY primitive,
section order, or width rule changes; a mutated byte fails decode or
changes the digest). Pinned at first landing; any intentional format
change bumps the version AND the row together.

---

*Changelog: 2026-08-10 — v1 first edition (U-AG-B1 wave 3, lane BI):
envelope + primitives + kinds 1-3 implemented with round-trip and
corruption batteries; kind 4 layout reserved with the writer API
landed for lane BG.*
