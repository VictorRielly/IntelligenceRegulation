# The hash layer for a standalone tagged shaped block — disposition

By the interactive Claude session acting as security owner (Opus 5.5,
continuing the Fable 5.1 lane), 2026-09-23, 09:18 PDT. It rules on
`ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK.md` (a delegated agent's draft,
`f0a5695`) after `ZK60_HASH_LAYER_STANDALONE_TAGGED_BLOCK_CHECK.md` (an
independent agent told to break it; own recomputation
`results/zk60_hash_layer_standalone_block_check/`, `cb83a97`). Both read the
lane `zk60-private-block-125m` at `544fbaf` and the four standalone bundles of
lane stage 45 / gate round 9j.

**Not a privacy acceptance of anything.** D22 (the toy) is untouched. This
closes the paper half of obligation 3 of `ZK60_SHAPED_PRIVACY_PATH_STATUS.md`
(the gate half closed at round 9j).

## 1. What survived the attack

- **The claim holds as a specialisation of the run's accepted argument at
  L = 1.** Given Theorem B's per-block part (conditional on G-R1, G-R2,
  G-R4), in the D19 model under D19b's reading and the named generator
  assumption (M-3), with the OS entropy reads independent (E-1): an accepted
  standalone tagged receipt plus its 112-byte endpoint policy is within the
  sampler's bias of a view that does not depend on the hidden data.
- **Every figure re-derived independently:** draws per proof 9,212,588 (125M)
  / 701,876 (rung-G) [COUNTED; the checker's own model reproduces the six
  measured stage-36 shapes exactly]; sampler term 2^-72.86 / 2^-76.58; the
  largest hash-layer term 2^-109.98 / 2^-113.68 (a 37.1-bit gap);
  transcript squeezes 14,252 / 2,356 [MEASURED by the gate, equal to the
  checker's count from `argument.rs`]; absorbs 495 / 376 [COUNTED — not
  measured, erratum F-2]; 264,970 / 19,236 leaves hidden by their salts; 28
  tag keys pairwise distinct; the 40-byte envelope binding recomputed from
  public header words on all four bundles; 1,280 opened columns per bundle
  re-authenticated under the block's keys.
- **Both external endpoints in one proof do not correlate** — including the
  all-zero world, where Input and Output commit identical planes: each
  endpoint has its own `ZkRng::from_os`, its own domain (role byte and spec
  digest), its own salts, pads and reserved rows; on the four real receipts
  0 salts shared, 0 identical opened columns or reserved-row segments at
  indices both opened, Input root ≠ Output root. Conditional on E-1, M-3 and
  D19b, as the draft states.
- **765,388 vs 750,540 resolved:** both right — 750,540 is rung-K4's block
  stream (one generator, measured in situ at stage 36, claim A-5); 765,388
  adds 2 × 7,424 endpoint draws (measured on a replica, S36-F2), i.e. per
  proof over three generators. Label: a sum of measured parts (F-3).

## 2. Rulings

**HB-1 (F-1) — D21 for a standalone block is kept by "verify before
transmit", not by an in-prover precheck.** I read `protocol.rs:770-771`: the
block prover deliberately has no output-equality precheck ("an endpoint
committed to other values must fail the verifier's polynomial identity"),
and the soundness tests rely on it. So a mis-sealed Output endpoint yields an
assembled receipt the verifier rejects, whose slot-22 view depends on the
mismatch. That receipt must never leave the prover: the operating rule of the
toy statement §6 ("a receipt the prover's own final check rejected is never
transmitted") and of the run (M-9) applies to every shaped block — **the
production caller verifies the receipt before emitting it.** No production
caller exists yet (S-5); whoever writes it (the integrator's CLI) carries this
rule, and it is in the handoff. No code change on the lane.

**HB-2 — errata F-2…F-6, F-9, F-10 go on the draft** as a dated block at its
top (absorbs COUNTED; the rung-K4 cell as a sum of measured parts; H^blk's
two-world distance 2^-71.86; the constructor-input length separation; the
tag-key `m` convention and the stale "twelve keys" comment at
`s24_tests.rs:151`; the 47-byte test pinning 3 of 7 run profiles; the
pre-stage-26 backstop sentence for S-3).

**HB-3 (F-7) — timing is D20's.** The 125M dense / zero prove times (28.12 s
/ 20.10 s) differ by the input; timing is out of scope by D20. Recorded, no
action.

**HB-4 (F-8) — the gate gains a control** that shares one blinding row
between the Input and Output endpoints and must see the joint rank drop — the
next gate round, small.

## 3. What stays open for a standalone-block statement

D19b (Victor); Theorem B's conditions G-R1, G-R2, G-R4 (the LAW of the
blinding, not the count); the generator's draws measured at rung-G and 125M
(obligation 6a); a production caller that verifies before transmitting
(HB-1, S-5); the shaped pin set at the integrated tree; Route B is not needed.

## 4. What I checked myself

`protocol.rs:760-771` (the endpoint check and the deliberate absence of an
equality precheck). Delegated and not re-derived: every count and term, the
endpoint independence reading, the bundle measurements.
