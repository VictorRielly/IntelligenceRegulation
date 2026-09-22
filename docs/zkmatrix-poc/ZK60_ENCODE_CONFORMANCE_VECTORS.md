# ZK60 — conformance vectors for the row encode (the seed of the device harness)

**Status: SKELETON (2026-09-22 13:52 PDT).** The sections below are the plan;
each is filled from a third implementation of `encode_row_zk` written against
the code, not from memory. Nothing here is a measurement.

**Why this exists.** Stage 0.5 measured (DC-G(1), 2026-09-22) that the hiding
commitment's CPU time is the row ENCODE, not the column hashing — 3.7 : 1 at
125M and at rung-W14. The device target inside the commitment is therefore the
NTT, and the byte trap both the design memo and its check named is the
transform's ORDERING. A device encode is byte-identical iff it reproduces the
CPU's exact output vector; the verifier sees 256 of 65,536 columns, so a
conformance harness is the only total check.

## 0. What this is, in one paragraph

_pending_

## 1. The constants, with file:line

_pending — the field, the two-adic generator, the root per size, the twiddle
indexing, the bit-reversal side, the inverse scaling, the coset powers, and
`encode_row_zk`'s composition._

## 2. The third implementation, and how it is validated

_pending — validation against the DEFINITION (direct O(n²) evaluation) at
small sizes, not against a transcription of the Rust._

## 3. The vectors

_pending — widths, rates, pad counts, message kinds, what is stored._

## 4. The cross-check against the Rust

_pending — what is possible from committed evidence and what is not._

## 5. The negative controls

_pending — the four wrong implementations and their digests._

## 6. The Rust test the lane drops in

_pending — exact code listing._

## 7. How the device team uses the harness

_pending._

## 8. What this does NOT cover

_pending — the pad draw order, the salts, the column hashing, the tree._

## 9. What this is not

_pending._
