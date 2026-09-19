# ZK60 — Private block composition: gap inventory (native/hashline line)

**Status: COMPLETE** (scoping inventory; read-only; no fixes designed, no code
written, nothing built or run — see section 6)

Date opened: 2026-09-19. Worktree: `/home/victor/wt-zk60-attention-compile`
(branch `zk60-attention-compile`). Author: delegated analyst for the security
owner. This document *inventories* what is missing between the native private
attention component and the native private FFN component before a complete
private transformer block exists on the custom line. It proposes nothing as
settled and designs no fix.

---

## 1. Plain-words summary — what a complete private block needs, and what is in hand

### 1.1 What one block is

The normative arithmetic for one ZK60 block is the portable integer kernel
`private-block-kernel/src/lib.rs`, whose `run_block` (`:513-666`) is nine steps
in this order: RMSNorm with gain `gamma_a` (`norm_a`), the Q/K/V projections,
half-split RoPE, causal integer softmax, PV, the output projection, **residual 1**
(`xres1 = x_in + ao`), **a second RMSNorm with gain `gamma_m`** (`norm_m`, at
`:616-618`), the SiLU feed-forward (gate, up, product, down, producing `z16`),
and **residual 2** (`xres2 = xres1 + z16`, at `:647-651`). The calibration is
frozen (`private-block-kernel/src/lib.rs:60-90`); at these constants
`SH_X1 = SH_A1 = SH_R1 = 0` and `SH_X2 = SH_Z2 = SH_R2 = 0`, so both residuals
are plain integer additions followed by an int16 range refusal, not shifts.

Under P1 the block's *inputs, outputs and every intermediate activation* are
hidden; the weights and tables are public
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:30`, `ZK60_PRIVACY_REQUIREMENTS.md`). So the
only two values that may cross a public boundary are the block's input `x_in`
and its output `xres2`, each as a hiding commitment fixed by the caller.

### 1.2 What is in hand

Two hiding components exist on the native line, each complete in itself, each
with its own transcript, its own profile string and its own pair of
caller-fixed endpoint commitments.

**The attention half** — `hashline/src/private_attention.rs` plus
`hashline/src/private_attention/{layout,witness,argument,protocol,wire}.rs`,
profile `hashline-zk-mr1/private-attention-t32-poc/1`
(`private_attention.rs:59`). It proves `norm_a` through residual 1, that is
`x_in -> xres1`, and binds `x_in` and `xres1` to two caller-fixed endpoints by
two masked equality sumchecks, slots `SC_IO_IN = 16` and `SC_IO_OUT = 17`
(`private_attention/layout.rs:294-295`, `private_attention/argument.rs:754-760`).
It was accepted on 2026-09-18 as an **experimental component at the tiny
geometry** (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md:7`); whole-proof
privacy was explicitly *not* accepted (`:35`).

**The feed-forward half** — `hashline/src/zk_ffn_fresh_io.rs`, profile
`hashline-zk-mr1/ffn-v3-mr1-fresh-io-poc/2` (`:12`). It proves the SiLU FFN from
an *already normalised* input plane `x` to `z16`, and binds those two planes to
two caller-fixed endpoints (`:276-368`). Its input is `nm`, the output of
`norm_m` — not `xres1`.

**Everything that joins them is absent.** Between the two components the block
still needs `norm_m`, the two seams (attention side into the FFN, FFN side back
out), and residual 2. The attention component says so itself
(`private_attention.rs:30`, `ZK60_PRIVATE_ATTENTION_NATIVE.md:46`), and the
disposition repeats it (`ZK60_PRIVATE_ATTENTION_NATIVE_DISPOSITION.md:34`).

### 1.3 Why the join is the hard part, in one paragraph

A seam is a place where one component's hidden output is the next component's
hidden input, so both proofs must bind to the same hidden value without
revealing it. Today the only mechanism for binding a hidden value to a proof at
a component boundary is a `private_seam::PreparedPlane` — a hiding commitment of
512 field words in 7 rows of 256 columns (`private_seam.rs:106-111`, `:36`,
`:215-217`). That object is **one-shot by construction**: `prove` and
`into_ffn_endpoint` take it by value, and it has no `Clone` and no data getter
(`private_seam.rs:142-161`, `:335-340`). So the naive composition — commit
`xres1` once and let both the attention proof and the next proof open it — is
not merely unproven: it is the exact configuration Codex reproduced natively, in
which **two openings at this seven-row, 256-column geometry recover all 512 data
words** from the public group vectors alone
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md:5-9`). Section 4 works this
through seam by seam. The alternative the construction actually specifies —
reserved mask pairs on *both* components' `A` commitments, a seam CFS slot, one
joint transcript, and each commitment still opened exactly once
(`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:99`) — requires a pending/manifest
lifecycle that exists in neither component: each builds its own transcript
inside its prover and finishes it before returning
(`private_attention/protocol.rs:266`, `:364-381`; `zk_ffn_fresh_io.rs:163`,
`:356-362`).

### 1.4 The shape of the remaining work

Three of the missing pieces are ordinary arithmetic that the attention module
already knows how to prove: `norm_m` is the same `rms_norm` relation the
component proves for `norm_a`, with `gamma_m` in place of `gamma_a` and `xres1`
in place of `x_in`; residual 2 is the same linear-plus-int16-range shape as
residual 1; the schema-3 capture writer is a serialiser with an existing model
to copy. What is *not* ordinary is where the shared values live, how many times
each commitment is opened, and which transcript owns the challenges. Those are
construction decisions for the security owner, and at least one of them
(section 4) sits directly on the open D8/D11 obligation.

## 2. Gap table — one row per missing piece

Classification key:
**ENG** = engineering, Codex can build it against a design that already exists;
**CON** = construction decision, needs the security owner (new masks, slots,
openings, or a privacy argument);
**RUL** = ruling, needs Victor (product, spend, or an accepted deviation).

| # | Missing piece | What it must prove (exact arithmetic + source) | What exists in code (`file:line`) and in design docs | What is missing | Class | Depends on |
|---|---|---|---|---|---|---|
| G1 | **`norm_m`, the second RMSNorm** | Per row `t`: `ss = 1 + Σ_i xres1[t,i]²`; `D = isqrt(ss)` pinned by `Dsq = D·D`, `a1 = ss − Dsq ≥ 0`, `a2 = 2D − a1 ≥ 0`; per `i`, `2·1024·gamma_m[i]·xres1[t,i] + D·2^11 = nm[t,i]·D·2^12 + ρ` with `ρ, σ = D·2^12 − 1 − ρ ∈ [0, 2^29)` and `nm[t,i] ∈ [−127,127]`. Source: `private-block-kernel/src/lib.rs:616-618` calling `rms_norm` `:382-411`, constants `:61-64` | The identical relation is **already implemented for `norm_a`** in the attention component: slots `SC_SS`, `SC_TZC`, `SC_LZC`, `SC_DZC` (`private_attention/layout.rs:278-291`), planes `A_D, A_DSQ, A_LIMB, A_Y, A_NR0..A_NS0+3` (`layout.rs:90-101`), byte-limb range lookups `layout.rs:225-233`, integer premise `layout.rs:200-220`. Designs: `ZK60_PRIVATE_BLOCK.md:59`, `ATTENTION_INTEGER_SPEC.md:159`, `ZK60_BLOCK_CONTRACT.md:44` | A second copy of every norm plane, site and lookup on a commitment that also holds `xres1`; the extra mask pairs and the grown A/H row counts; `gamma_m` added to the public statement (`AttentionPublic` carries only `gamma_a`, `private_attention.rs:74`) | ENG, with a CON rider (G10) | G5 (which commitment holds `xres1`) |
| G2 | **Seam: attention → FFN** | `nm` as proved by `norm_m` **is** the plane the FFN consumes as its input `x`, as multilinear extensions over the 9-variable cube, at a point drawn after both target roots are public. Source relation: `ZK60_OPUS_SEAM_REVIEW.md:205-250`; S2 form `private_seam.rs:259-261`, `:464-469` | The S2 masked-equality relation exists standalone (`private_seam.rs:335-428` prove, `:432-505` verify; `ZK60_PRIVATE_SEAM.md`). The FFN's input endpoint slot exists (`zk_ffn_fresh_io.rs:258-271`, claim `:204-235`). Design: `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:99` (reserved pair roles on both A's, seam slots on the FFN M) | Everything that makes it a *seam* rather than two unrelated proofs: reserved pair rows on both A commitments before either root exists, a seam CFS slot, one shared transcript, and a rule that the claim is on `lay.x[c]` and nothing else (`ZK60_OPUS_SEAM_REVIEW.md:692-700`, U-9) | **CON** | G1, G7, G8, G11 |
| G3 | **Residual 2** | `xres2[i] = xres1[i] + z16[i]` exactly (at this calibration `SH_X2 = SH_Z2 = SH_R2 = 0`, so `requant` is the identity), with `xres2 ∈ [−32768, 32767]` refused otherwise. Source: `private-block-kernel/src/lib.rs:647-651` with `requant` `:298-308` and `calib` `:85-87`; general form `causal_oracle.rs:430-435` | The identical shape is implemented for residual 1 (`xres1 = x_in + ao`, int16 limbs `A_X1L0/A_X1L1`), hosted in the D zero-check: `ZK60_PRIVATE_ATTENTION_NATIVE.md:42`, planes `private_attention/layout.rs:106-108`, limb lookups `layout.rs:232`. Designs: `ATTENTION_INTEGER_SPEC.md:440-455`, `ZK60_PRIVATE_BLOCK.md:66` | A relation whose two addends live in **different components** (`xres1` in attention, `z16` in the FFN) and whose result is the block's public output endpoint. No code reads both | ENG arithmetic, **CON** placement | G4, G5 |
| G4 | **Seam: FFN → block output endpoint** | The FFN's output plane `z16` (already proved int16 by the FFN's LogUp helper on `lay.z[c]`, `layer.rs:1399`) is the `z16` that residual 2 adds; and the block's caller-fixed **output** endpoint commits `xres2`, not `xres1`. Source: `private-block-kernel/src/lib.rs:643-656` | The attention component today binds its output endpoint to `xres1` (`private_attention/argument.rs:757-758`, slot `SC_IO_OUT`). The FFN binds `z16` to *its* output endpoint (`zk_ffn_fresh_io.rs:284`, `:346`). Design: `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:100` (the `/2` IO mechanism, reserved pair rows for `x_in` and `xres2` on the attention A) | The block's `SC_IO_OUT` must move from `xres1` to `xres2`; `z16` must stop being an external endpoint and become an internal seam; nothing implements either | **CON** | G3, G7 |
| G5 | **Where `xres1` lives, and how many times it is opened** | `xres1` is read **three times** in a block: by residual 1 (produces it), by `norm_m` (consumes it), and by residual 2 (adds it to `z16`). Source: `private-block-kernel/src/lib.rs:610-651` | Today `xres1` exists as plane `A_X1` on the attention A (opened once inside the component) *and* as the caller-fixed output endpoint commitment (opened once, `private_attention/protocol.rs:378-380`) | A decision on whether all three uses stay inside one commitment opened once (the construction's intent) or whether any commitment is opened twice. The second option is the recovery configuration of section 4 | **CON** — the central one | — |
| G6 | **Schema-3 capture writer for the attention profile** | Nothing about the protocol; it must emit, for a real accepted receipt, the per-role observation record the round-2 joint tools parse: transcript states and next challenges, claim geometry, group and proximity vectors, 256 sampled columns, CFS/M openings | The model to copy is `hashline/src/zk_ffn_io_diagnostic.rs:337` (`"schema":3, "kind":"zk60-verifier-observations"`, `opening_order ["M","W","A","H","Input","Output"]`). Consumers: `scripts/zk60_io_capture_preflight.py:140`, `scripts/zk60_io_cfs_composition.py`, `scripts/zk60_endpoint_fibre.py`, `scripts/zk60_fable_joint_capture.py`, `scripts/zk60_opus_repaired_capture.py`. Requirement: `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135` (R15), disposition item 3 (`…_DISPOSITION.md:30`) | The writer itself; the capture-side profile/coverage constants; the attention-shaped `opening_order` (`M, A, H, Input, Output`, no `W` under P1) and the six-commitment role list | ENG | — |
| G7 | **One transcript / a composed profile and wire format** | No arithmetic. The composed statement must be one transcript with one domain string, one M per component, and a bounded frame that can name both components' roots | Each component owns its transcript end to end: `private_attention/protocol.rs:26-33` and `:266`; `zk_ffn_fresh_io.rs:138-146` and `:163`. Neither takes an outer `&mut Transcript`. Wire frames are fixed-shape per profile (`private_attention/wire.rs`, `zk_ffn_fresh_io.rs:513-591`). Designs: `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:105-109` (the intended single order), `ZK60_OPUS_SEAM_REVIEW.md:654-661` (U-4), `:337-357` (U-6, the old wire format is not extensible) | A block profile id, a composed transcript order, and a bounded composed decoder. Forbidden shortcuts are named: appending to a finished proof, forking a completed transcript (`ZK60_PENDING_FFN.md:11-12`, `:151`) | ENG against a written design, **CON** for the transcript order itself | G5 |
| G8 | **Reserve-before-commit lifecycle (pending objects + manifest)** | No arithmetic. Every mask row and CFS slot a seam needs must be drawn **before** the commitment that carries it is built, and each role consumed exactly once | The cuts are measured precisely in `ZK60_OPUS_SEAM_REVIEW.md:449-497`: after the A commit no A row can be written, after `mask_commit` no slot can be added. In the attention component the same cuts are `private_attention/protocol.rs:296` (commit A), `:304` (commit M), `:346` (commit H). Design: FA3 §12.1 role sets, summarised `ZK60_OPUS_SEAM_REVIEW.md:501-518` | Any `Pending`/manifest type at all, on either side; a `RoleSet`; a `finalize` that refuses a missing or duplicated seam role. `ZK60_OPUS_SEAM_REVIEW.md:531` states the verdict: "absent" | ENG against FA3 §12.1, **CON** for the role list | G7 |
| G9 | **Range obligation on the FFN's input plane** | The FFN's input `x` must be int8-class. The FFN **does not prove it**: its LogUp helper specs cover `g8/a16`, `u16`, `h16` and `z/rd` but not `lay.x` (`layer.rs:1394-1401`), and `check_witness` checks only lengths (`zk_ffn_fresh_poc.rs:117-144`). The class is a Rust type (`V3Witness.x: Vec<i8>`, `export_v3.rs:332`), not a verifier constraint | The attention component *does* prove its norm output in `[−127,127]` (`sym(A_Y)`, `private_attention/layout.rs:193-195`, `:227`) | In the composed block this obligation must be discharged by `norm_m`; if `norm_m` were placed on the FFN side instead, the FFN would need the range planes it does not have | ENG (follows G1), but a **CON** if `norm_m` is placed FFN-side | G1 |
| G10 | **Re-running the accepted R-1 / R-2 / CFS checks on the grown layout** | The acceptance of the attention component rests on rank and CFS checks run against *its* declared 75 A sites / 35 H sites and 18-slot table (`…_DISPOSITION.md:12`). Adding `norm_m`, residual 2 and two seams changes every one of those counts | Tools exist and are runnable: `scripts/zk60_attention_native_inventory.py`, `scripts/zk60_attention_pair_schedule.py`, `scripts/zk60_attention_cfs_slots.py`, with records under `results/zk60_private_attention_native_evidence/` | The re-run, and a decision on whether the accepted verdict transfers. It does not transfer automatically: the seam adds opening groups on rows already opened, which `ZK60_OPUS_SEAM_REVIEW.md:639-646` (U-2) records as uncovered by any joint analysis | ENG to run, **CON** to accept | G1, G2, G3, G4 |
| G11 | **Endpoint scale and class tags are unproven metadata, and the attention fixture's are wrong** | `SeamSpec` binds a declared `scale` into its digest but proves nothing about it: "Equality here is field-word equality: range/representation facts are owed by the enclosing arguments" (`private_seam.rs:41-42`). The approved calibration has `x_in`/`xres1` int16 at `e_r = e_r1 = 0` and the FFN input at `e_xm = e_x = −3` (`causal_oracle.rs:116`, `:118`, `:120`, `:174`) | The attention's own fixtures declare `IoSpec::new(ctx, -3, -3)` (`hashline/tests/zk60_private_attention.rs:17`, `hashline/examples/zk60_private_attention.rs:36`); the FFN's declare `(-3, 0)` (`zk_ffn_fresh_io_tests.rs:16`), which *do* match `e_x = −3`, `e_z16 = 0`. Contract-side checks exist but are metadata-only: `private_block_contract.rs:167-183` | Scales bound to the approved calibration rather than chosen per fixture, plus a seam rule that compares represented values, not tags. See finding C3 in section 3 | ENG to fix the fixtures; **RUL/CON** for whether the approved contract must gate the scale | G7 |
| G12 | **Endpoint slot-tag namespace across profiles** | `SeamSpec` distinguishes endpoints only by two `u64` slot ids folded into its digest (`private_seam.rs:115-133`). Attention uses 21/22 and 23/24 (`private_attention.rs:157`); the FFN uses 1/2 and 3/4 (`zk_ffn_fresh_io.rs:38-43`) | The disjointness is deliberate and load-bearing: it is why an FFN-IO endpoint cannot be presented to the attention prover (`private_attention.rs:155`) | A block-level allocation for the new internal-seam and block-output roles, and an owner for the namespace. Nothing enumerates the assigned slots anywhere | ENG, needs a **CON** on the allocation | G7 |
| G13 | **`private-block-kernel` parity for the composed block** | The composed proof's witness must equal `run_block` exactly, including *which* site refuses (`private-block-kernel/src/lib.rs:8-12`) | The attention component tests against `causal_oracle::FixedCausalOracle`, not the kernel, because the kernel is not a hashline dependency (`ZK60_PRIVATE_ATTENTION_NATIVE.md:108`, request P-3). Kernel-side parity harness exists: `private-block-kernel/tests/fixture_parity.rs:110-118` | A dev-dependency (a `Cargo.toml` change outside the attention lane) and a whole-block parity test | ENG; the `Cargo.toml` change is the integrator's call | — |
| G14 | **Interface requests P-1, P-2, P-3 from the delivery** | No arithmetic. P-1: share `zk::fresh_poc::check_opening_challenges` instead of the attention module's 12-line copy. P-2: a neutral alias for `PreparedPlane::into_ffn_endpoint`, which the attention module also calls. P-3: the kernel dev-dependency | The duplicate challenge check is `private_attention/protocol.rs:136-147`; the shared entry point is `private_seam.rs:156-161`; both components call it (`private_attention/protocol.rs:235-236`, `zk_ffn_fresh_io.rs:263-264`) | Codex's calls; none blocks a build (`…_DISPOSITION.md:28`) | ENG | — |
| G15 | **The composition-level privacy gate** | The construction's acceptance gate is, on captured real receipts, "a zero-witness preimage with the same free dimension as the real witness on every channel, and the component's zero-witness acceptance test" (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`) | Not run even for the attention component alone (`…_DISPOSITION.md:30`, `:35`). The joint tools' own exclusions are recorded in `ZK60_JOINT_VIEW_REVIEW_20260918.md:71-80` | The gate, at block scope, over two components, two M commitments (`ZK60_OPUS_SEAM_REVIEW.md:725-731`, U-14) and the seam groups | **CON**, and blocked on D8/D11 (section 4) | G6, G10 |

Two things that are **not** gaps and should not be re-opened as such:

- **`norm_a` belongs where it is.** The attention component includes the first
  RMSNorm and the FFN assumes a pre-normed input; that matches the kernel's
  order (`private-block-kernel/src/lib.rs:524-526`, `:616-618`). The asymmetry
  is that the block has *two* norms and only one is implemented — G1 — not that
  `norm_a` is misplaced.
- **The PCS parameters already agree.** `log_cols = 8`, `inv_rate = 8`,
  `num_col_checks = 256` on both sides and on the endpoints
  (`private_attention/protocol.rs:21-23`, `zk_ffn_fresh_poc.rs:51-57`,
  `private_seam.rs:99-105`), and the field and extension are the crate's single
  Goldilocks/`Fp2` pair. See section 3, finding C1.

## 3. Compatibility findings: attention output endpoint vs FFN input endpoint

The question this section answers is narrow and mechanical: as the code stands
today, could the plane the attention component hands out as its output endpoint
be the plane the FFN component takes as its input endpoint? Answer: **no**, for
four independent reasons, of which only one is cosmetic. Both sides are cited.

### C1 — Geometry, commitment format and mask layout are identical (compatible)

Both endpoints are built by the same constructor. `private_seam::prepare` lays
out `data_rows = 512/256 = 2` data rows, then `MASK_ROWS = 5`: rows 2 and 3 are
the Fp2 terminal-mask pair, rows 4, 5 and 6 feed the proximity combination only
(`private_seam.rs:106-111`, `:36`, `:200-223`; the three-row proximity split is
described at `ZK60_PRIVATE_SEAM.md:85-89`). So each endpoint is a 7-row,
256-column hiding commitment with `log_cols = 8`, `inv_rate = 8`, 256 column
checks (`private_seam.rs:99-105`).

Both consumers agree on that shape and on the claim shape:

- FFN: `ExpectedIo::from_roots` hard-codes `rows: 7, log_cols: 8`
  (`zk_ffn_fresh_io.rs:55-69`); the endpoint claim is `(offset 0, log_size 9)`
  with coefficient `1−e`, plus rows 2 and 3 at `e` and `e·U`
  (`zk_ffn_fresh_io.rs:204-235`, `:346`); the mask check is
  `check_masks(claims, 7, 8, &[2, 3], 4, …)` (`:360`, `:459`).
- Attention: `ENDPOINT_ROWS = 7`, `ENDPOINT_PROX = 4`
  (`private_attention/protocol.rs:179-180`); the endpoint table is
  `slices: [(0, ONE)], log: 9, mask_row: 2`
  (`private_attention/argument.rs:428-430`); the shape is checked explicitly
  because the 7-row geometry does not end in its proximity pair
  (`protocol.rs:182-198`), and the geometry is re-checked on intake
  (`protocol.rs:240-242`).

Both produce exactly **one opening group** per endpoint
(`protocol.rs:197` passes `&[1]`; the FFN's frame asserts
`group_vecs.len() == 1` at `zk_ffn_fresh_io.rs:537-538`). Word encoding agrees:
attention maps `i16 -> Fp::from_i64` (`private_attention.rs:226`), the FFN's
caller maps `i8`/`i32 -> Fp::from_i64` (`zk_ffn_fresh_io_tests.rs:18-23`), and
`prepare` rejects non-canonical words (`private_seam.rs:193`).

**Finding: compatible, and identical by construction.** This is the good news —
no re-plumbing of geometry is needed.

### C2 — The two endpoints are different objects and cannot be the same one (incompatible by design, and correctly so)

Three independent mechanisms stop it:

1. **The values differ.** The attention output endpoint commits `xres1`
   (`private_attention/argument.rs:757` opens plane `A_X1` against `Cm::Out`);
   the FFN input endpoint commits `nm = norm_m(xres1)`
   (`causal_oracle.rs:389-400` feeds `nm.y` into the FFN export;
   `zk_ffn_fresh_io.rs:284` binds `lay.x[0]`). Nothing in the repository
   computes `norm_m` inside either proof, so no plane satisfies both roles.
2. **The spec digests differ.** `SeamSpec::digest` folds the two slot ids into
   the hash (`private_seam.rs:115-133`). Attention uses slots 21/22 and 23/24
   (`private_attention.rs:157`); the FFN uses 1/2 and 3/4
   (`zk_ffn_fresh_io.rs:38-43`). `into_ffn_endpoint` refuses a digest mismatch
   (`private_seam.rs:156-161`), so an attention endpoint handed to the FFN is a
   typed refusal, not a silent mis-binding. The attention module documents this
   as intentional (`private_attention.rs:155`).
3. **`PreparedPlane` is moved, not borrowed.** `Endpoints` is consumed by value
   by both provers (`private_attention.rs:270`, `zk_ffn_fresh_io.rs:276`), and
   `PreparedPlane` has no `Clone`, no data getter and no repeated-opening
   method (`private_seam.rs:142-147`). One prepared plane can serve exactly one
   proof.

**Finding: incompatible, and this is a protective property, not a defect.**
Mechanism 3 is what keeps the repository out of the two-opening configuration of
section 4. Any composition proposal that needs one plane in two proofs is asking
for mechanism 3 to be removed, and must say so explicitly.

### C3 — The declared scales are unproven tags, and the attention fixtures' tags contradict the approved calibration

`SeamSpec` carries a `scale` (`private_seam.rs:44-52`) and binds it into the
digest and hence the transcript, but the module states plainly that it proves
nothing about it: "Equality here is field-word equality: range/representation
facts are owed by the enclosing arguments, even though their declared scale is
transcript-bound" (`private_seam.rs:41-42`). `ZK60_PRIVATE_BLOCK.md:143-144`
says the same: "Equality of integer words is not equality of represented values
if the scales differ."

The approved fixed calibration (`causal_oracle.rs:105-146`, `:174-181`) is:

| Quantity | Class | Declared exponent | Source |
|---|---|---|---|
| `x_in` | Int16 | `e_r = 0` | `causal_oracle.rs:115-116` |
| `norm_a` output | int8 subset | `e_xn = −3` | `:117` |
| `xres1` | Int16 | `e_r1 = 0` | `:118` |
| `norm_m` output (`nm`) | int8 subset | `e_xm = −3` | `:120` |
| FFN input `x` | int8 | `e_x = −3` | `:174` |
| FFN output `z16` | Int16 | `e_z16 = 0` | `:179` |
| `xres2` | Int16 | `e_r2 = 0` | `:146` |

Against that:

- the FFN's fixture declares `IoSpec::new([7; 32], -3, 0)`
  (`zk_ffn_fresh_io_tests.rs:16`) — correct: `−3` is `e_x`, `0` is `e_z16`;
- the attention's fixtures declare `IoSpec::new(ctx, -3, -3)`
  (`hashline/tests/zk60_private_attention.rs:17`,
  `hashline/examples/zk60_private_attention.rs:36`) — but `x_in` and `xres1`
  are both at exponent **0**, not `−3`.

The consequence for a seam is the uncomfortable one. A composed block that
checked "attention `output_scale` equals FFN `input_scale`" would compare `−3`
against `−3` and **pass**, while the two tags denote different quantities —
`xres1` at `e_r1 = 0` on one side and `nm` at `e_xm = −3` on the other, a factor
of `2^3` apart. `IoSpec::new` validates only the range `−31..=31` and slot
distinctness (`private_attention.rs:150-158`, `private_seam.rs:63-85`); nothing
compares a tag to the approved calibration. `private_block_contract.rs:167-183`
does check a scale/class boundary, but only between consecutive *blocks*
(`residual.e_r2` against the next block's `attention.e_r`) and only as metadata
preflight (`ZK60_BLOCK_CONTRACT.md:28-31`).

**Finding: the scale channel is currently decorative, and the attention side's
decoration is wrong.** Fixing the fixture is trivial; deciding that the seam
must bind represented values through the approved contract is not, and is G11.

### C4 — The class obligations do not meet: `xres1` is int16, the FFN's input must be int8, and neither side proves the crossing

The attention component proves `xres1 ∈ int16` by two byte limbs with offset
32768 (`private_attention/layout.rs:107-108`, lookups `:232`, premise `:203`).
The FFN needs its input in the int8 class — and proves no range on it at all:
the LogUp helper specs cover `g8/a16`, `u16`, `h16` and `z/rd`, never `lay.x`
(`layer.rs:1394-1401`; the non-GPU list at `:542-546` matches), and
`check_witness` checks only plane lengths (`zk_ffn_fresh_poc.rs:117-144`). The
int8 class of `x` is the Rust type `V3Witness.x: Vec<i8>`
(`export_v3.rs:332`) — a prover-side fact, not a verifier constraint.

**Finding: the missing `norm_m` is load-bearing for soundness, not only for
completeness.** It is the only place in the block that would force the FFN's
input into `[−127, 127]`. The attention component already proves exactly this
shape for `norm_a`'s output (`sym(A_Y)`, `private_attention/layout.rs:193-195`,
`:227`), which is why G1 is classified as engineering.

### C5 — Two transcripts, two domains, and no way to nest them

`private_attention::protocol::transcript` opens with
`Transcript::new(PROFILE)` where `PROFILE` is the attention profile string, then
absorbs the endpoint policy, the public-statement digest, a parameters label and
the schedule digest (`private_attention/protocol.rs:26-33`); it is created
inside `prove_inner` (`:266`) and finished by the four openings at `:364-381`.
`zk_ffn_fresh_io::transcript` does the same with the FFN profile
(`zk_ffn_fresh_io.rs:138-146`), created at `:163` and finished at `:356-362`.
Neither prover nor verifier accepts an outer transcript.

Domain separation between the two components is therefore complete and free —
but that is the opposite of what a seam needs. The construction specifies **one**
transcript order in which the seams run after both components' slots and the
seam CFS slots live on the FFN's M (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:99`,
`:105-109`). `ZK60_OPUS_SEAM_REVIEW.md:654-661` (U-4) records the same
conclusion for the FFN and names the two forbidden shortcuts.

**Finding: one transcript is intended; two exist; neither can be nested without
a new profile.** This is G7.

### C6 — One difference worth a check, not yet a finding: the NTT table the endpoint verifier uses

`private_seam::check_ntt` requires exactly `NttTables::new(12)` and verifies the
root values (`private_seam.rs:164-181`); `prepare_endpoints` uses `new(12)` on
both sides (`private_attention.rs:225`, `zk_ffn_fresh_io.rs:115`). The attention
verifier then verifies the endpoint openings with `new(12)`
(`private_attention/protocol.rs:263`, used at `:428`), while the FFN verifier
uses `new(16)` for the same endpoint commitments (`zk_ffn_fresh_io.rs:436`, used
at `:469`). I did **not** check whether `pcs::verify_zk`'s result depends on
`NttTables::max_log` beyond having enough roots, so I record this as a
difference to confirm, not as a defect.

### Summary of section 3

| Finding | Verdict |
|---|---|
| C1 geometry, PCS params, mask rows, claim shape, opening groups | compatible, identical by construction |
| C2 same plane in both roles | impossible today — values differ, digests differ, the plane is moved. Protective |
| C3 scale tags | unproven metadata; the attention fixtures' `(−3, −3)` contradicts `e_r = e_r1 = 0`; a naive tag-equality seam check would pass on a `2^3` mismatch |
| C4 integer class | `xres1` is int16, the FFN's input must be int8, and the FFN proves no range on it; only the missing `norm_m` closes this |
| C5 transcripts | two independent domains; a seam needs one, and neither module can be nested |
| C6 NTT table size at endpoint verification | 12 vs 16; unchecked, flagged |

## 4. D8 / D11 endpoint-reuse exposure, seam by seam

### 4.0 What D8 and D11 actually say, restated

**D8** (`ZK60_DECISIONS.md:227-250`) is a standing obligation: a proof on the
custom line must be simulatable for endpoint roots *the caller fixed*, with the
distinguisher allowed to keep prior public history. A round-2 memo claimed to
discharge it by programming one oracle point per root; Codex's review showed
that any previously published authentication path under that root reveals the
honest top pair, so the programmed point is detectable as a second preimage.
**The two-point closure is retracted for any root with a prior public opening.**
D8's own text then suggested the obligation reduces to unopened roots, since the
consuming API permits only one opening.

**D11** (`ZK60_DECISIONS.md:252-266`) retracts that reduction. An ordinary
authentication path or a root-child hash query can precede the sole accepted
`finish`; consuming the owner does not erase that history. D11 also records two
facts from the native reproduction
(`ZK60_ENDPOINT_REUSE_DISPOSITION_20260918.md`):

- **(R)** *recovery*: two native PCS openings at the actual seven-row,
  256-column endpoint geometry **recover all 512 data words**, using only the
  two public group vectors and their public challenge coefficients. Each opening
  publishes `v = a·x + b·y + c·m` over `Fp2`; two openings cancel the fixed
  terminal mask `m`, leaving two base-field equations in `x, y` with an
  invertible public coefficient matrix (`…_DISPOSITION.md:5-9`, `:16-21`). The
  fresh-owner control does not recover the plane.
- **(F)** *forced-challenge counterexample*: proposed argument A4 asserted that
  every non-refused challenge is safe for two uses of one commitment. It is
  false as written — two uses can pass their individual proximity-pair checks
  while sharing identical mask coefficients; subtracting the proximity vectors
  then reveals both data coordinates (`…_DISPOSITION.md:46-54`). This is not an
  efficient attack on random Fiat-Shamir challenges, and a repaired argument
  needs either a joint-rank refusal or a justified bound on the bad-challenge
  event.

Note the geometry in **(R)** is *exactly* the endpoint geometry both components
use: 7 rows, 256 columns, terminal mask pair at rows 2 and 3 (section 3, C1).
The reproduction's own note says "Claim geometry matches
`zk_ffn_fresh_io::claim(0, 2, …)`" (`…_DISPOSITION.md:31-32`), which is the same
claim shape the attention component builds at
`private_attention/argument.rs:428-430`.

### 4.1 Where the custom line stands today (no seams)

Each component opens each of its two endpoint commitments **exactly once**:

- Attention: `check_endpoint_opening` then one `pcs::open_zk` per endpoint, each
  owner dropped immediately (`private_attention/protocol.rs:375-380`); the
  verifier mirrors it (`:426-429`).
- FFN: one `pcs::open_zk` per endpoint inside `finish`
  (`zk_ffn_fresh_io.rs:357-362`); verifier at `:457-477`.

So neither component is in configuration **(R)** today, and the attention
module says exactly that: "this profile opens every commitment once, so it
neither triggers nor repairs that case: there is no joint-rank refusal across
uses because there is no second use"
(`ZK60_PRIVATE_ATTENTION_NATIVE.md:78`, restated at `private_attention.rs:22-27`).

What is *not* discharged today, even with one opening: D8's general
caller-fixed-root simulation with prior history, and D11's correction that
one-use does not reduce that to the empty-history case. Both components record
this as open (`private_attention.rs:17-21`,
`ZK60_PRIVATE_ATTENTION_NATIVE.md:77`).

### 4.2 Seam-by-seam inventory

For each seam I state: the value, the commitment root, the two proofs, what each
proof opens and at which challenge point, and how D8/D11 bears. I describe; I do
not claim any of these is solved or unsolvable.

---

#### Seam S1 — attention output `xres1` into `norm_m`

**The value.** `xres1`, 512 int16 words.

**Root(s) reused, if the obvious composition is taken.** The attention
component's **output endpoint root**, `ExpectedIo::output` — a *caller-fixed*
root, since `prepare_endpoints` is the endpoint owner's step and the policy is
fixed before proving (`private_attention.rs:161-168`, `:220-231`). D8's
experiment is stated for precisely this kind of root.

**Proof 1 — the attention proof.** Opens that root once, in slot `SC_IO_OUT`
(`private_attention/argument.rs:754-759`). The relation is
`eq(τ, x)·(A_X1(x) − E_out(x))` with `τ` a 9-coordinate challenge drawn inside
the attention transcript at `argument.rs:755`, after the A, M and H roots are
absorbed (`protocol.rs:300`, `:306`, `:350`). What is published about the
endpoint: one masked terminal at the extension point, and one PCS opening whose
claim has three parts — the 512 data words at `(offset 0, log_size 9)` with
coefficient `1−e`, and the terminal mask rows 2 and 3 with coefficients `e` and
`e·U` (`argument.rs:428-430`, shape enforced at `protocol.rs:186-192`). One
opening group; challenge refusals replayed from a cloned transcript
(`protocol.rs:196-197`).

**Proof 2 — the `norm_m` proof, if it is a separate proof.** It would need
`xres1` as *its* input. If it took the same root as a caller-fixed input
endpoint, it would open that root a second time, at its own independent point
`τ'` with its own extension challenge `e'`, drawn in a different transcript, and
it would publish a second group vector over the *same* terminal mask rows 2 and
3 — because those rows are fixed at `prepare` time and `PreparedPlane` has no
re-randomisation path (`private_seam.rs:200-223`).

**How D8/D11 bears.** This is configuration **(R)** verbatim: two openings, same
7×256 geometry, same fixed terminal mask, two public group vectors with public
coefficients. The reproduction says those two openings recover all 512 data
words. So S1-as-two-openings is not an open question to be argued; it is a
recovery configuration that the repository has already demonstrated natively.
Independently, **(F)** says the per-use refusals in
`check_opening_challenges` (`protocol.rs:136-147`) are not sufficient across two
uses, because they are per-opening and there is no joint-rank refusal.

**The composition that avoids it.** Keep `xres1` inside one commitment opened
once — that is, put `norm_m` in the *same* component as residual 1, so `xres1`
is plane `A_X1` on the attention A and never leaves it. Then S1's shared value
becomes `nm`, not `xres1`, and the seam moves to S2 below. This is what
`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:99` describes. It is a construction
decision (G5), and it is the reason G5 is marked the central one.

---

#### Seam S2 — `norm_m` output `nm` into the FFN input plane

**The value.** `nm`, 512 words in `[−127, 127]`.

**Root(s) reused.** Two possibilities, and they differ sharply.

*(a) Shared endpoint commitment.* One `PreparedPlane` of `nm`, used as the
attention side's extra output endpoint **and** as the FFN's input endpoint. Two
openings of one root: the attention proof at its own `τ`, the FFN at the point
`ρ` its own 10-round argument produces (`zk_ffn_fresh_io.rs:312-346`; the claim
is `claim(0, 2, &rho, e, terminals[1])` at `:346`, again rows 2 and 3). Same
geometry, same fixed mask rows. **Configuration (R) again**, plus **(F)** on the
refusals. It is also blocked mechanically today by section 3's C2 mechanisms
2 and 3.

*(b) The construction's form: two A-resident planes and one equality slot.* `nm`
is a plane on the attention A; the FFN's `x` is `lay.x[0]` on the FFN A; a seam
sumcheck proves the two multilinear extensions agree at a point drawn after
**both** A roots are absorbed, with a fresh reserved mask pair on each A and a
CFS slot on the FFN M (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:99`;
`ZK60_OPUS_SEAM_REVIEW.md:205-250` for the relation and the point rule;
`:251-275` for the pair costs; `:291-336` for the slot `(10, 2)`, `L = 22`).
Each commitment is still opened exactly once — the seam claim rides the single
opening. **D8 does not bear on the A roots**, because they are prover-generated,
not caller-fixed. D8 continues to bear on the block's two *external* endpoints
(`x_in`, `xres2`), with one opening each.

**What form (b) does not discharge.** Three things, all already on record:
the seam adds two opening groups on rows that other groups already open, and no
joint analysis covers that (`ZK60_OPUS_SEAM_REVIEW.md:639-646`, U-2); a shared
mask row across two opening groups leaves the *difference* of the two
evaluations in the clear, so the fresh pair is mandatory
(`ZK60_OPUS_SEAM_REVIEW.md:258-275`, citing `zk.rs:1971-1974`); and nothing
marks a seam role consumed exactly once on either side
(`ZK60_OPUS_SEAM_REVIEW.md:647-653`, U-3).

---

#### Seam S3 — FFN output `z16` into residual 2

**The value.** `z16`, 512 int16 words, already range-proved by the FFN
(`layer.rs:1399`, the `lay.z[c]`/`lay.rd[c]` helper).

**Root(s) reused.** Today `z16` is the FFN's **output endpoint**, a caller-fixed
root opened once by the FFN (`zk_ffn_fresh_io.rs:284`, `:346`, `:357-362`).
Residual 2 needs to read `z16` *and* `xres1`. If residual 2 is a third proof
that takes the FFN's output endpoint as its input endpoint, that root is opened
twice — **configuration (R)** a third time, with the same 7×256 geometry.

If residual 2 lives inside the FFN component (which owns `z16` on its A), it
needs `xres1`, which lives on the attention A: a second seam of form (b). If it
lives inside the attention component (which owns `xres1`), it needs `z16`: again
form (b), in the other direction. Either way the arithmetic is trivial
(`xres2 = xres1 + z16`, int16) and the *placement* is the decision.

**How D8/D11 bears.** In form (b) the reused object is again a prover-generated
A root carrying an extra claim inside one opening, so D8's caller-fixed-root
experiment does not apply to it. In the third-proof form it is (R).

---

#### Seam S4 — the block's external output endpoint

**The value.** `xres2`, the block output, the one intermediate value that P1
*permits* to be a public commitment handle.

**Root reused.** One caller-fixed root, opened once — by whichever component
carries residual 2. Today the attention component binds `xres1` to this slot
(`private_attention/argument.rs:757`), which is wrong for a block: a block's
output is `xres2`. This is a change of *which value* the endpoint carries, not a
reuse.

**How D8/D11 bears.** Directly and unchanged: this is a caller-fixed root, so
D8's simulation obligation applies, and D11 says one-use consumption does not
reduce it to the empty-history case. Nothing here makes that obligation worse or
better than it already is for the attention component's two endpoints.

---

#### Seam S5 — block-to-block, for completeness (out of scope for one block)

`xres2` of block `k` is `x_in` of block `k+1`. If the caller fixes one
commitment and both blocks open it, that is **(R)** across proofs. The
construction's A4 instead specifies a masked equality between the two blocks'
attention A commitments, with its own CFS slot on block `k+1`'s M and reserved
pairs on both A's, and block `k`'s A forbidden to finalise before block `k+1`
binds it (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:100`). The same document notes
the first tiny P1 block has no residual seam. Recorded here only so that a
single-block design does not accidentally foreclose it.

### 4.3 The one-line summary of section 4

Every "obvious" seam — share the endpoint commitment between two proofs — lands
on configuration **(R)**, in which the repository's own native test recovers all
512 hidden words from two openings at exactly this geometry. The construction's
alternative (reserved pairs on both `A` commitments, one seam slot, one
transcript, one opening per commitment) moves the reuse off the caller-fixed
endpoints and onto prover-generated roots, where D8's experiment does not apply
— but it does not discharge D8 for the block's two external endpoints, and
`ZK60_OPUS_SEAM_REVIEW.md:639-646` (U-2) records that the joint analysis for the
extra seam groups has never been done. I state this as the map of the terrain,
not as a verdict on either route.

## 5. Suggested order of work (a proposal for the security owner, not a decision)

This is a proposal. Steps 0 and 1 are decisions only the security owner can
make, and every later step's shape depends on them, so the ordering below
assumes the construction's own answer (`norm_m` and residual 2 inside the
attention-side component; seams as A-to-A equalities; one opening per
commitment). If the security owner rules differently, steps 3 onward change.

Smallest self-checking steps first. Each carries the acceptance check that would
show it is done — something that can fail, not a description.

| Step | Work | Acceptance check that would show it is done | Gap |
|---|---|---|---|
| **0** | **Rule on G5**: where `xres1` lives and whether any commitment is ever opened twice. Record the ruling in `ZK60_DECISIONS.md` the day it is made | A dated entry in `ZK60_DECISIONS.md` that states, for each of the block's commitments, its opening count; and a statement of whether section 4's configuration (R) is permitted anywhere. Nothing downstream is built before this exists | G5 |
| **1** | **Rule on the seam form** (shared endpoint vs A-to-A equality) and on the block profile id and transcript order | A written transcript order, label by label, in a block-profile note, in the style of `ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:105-109`; and a profile string reserved | G7, G2 |
| **2** | **Schema-3 capture writer for the attention profile** — the one item with no dependency on 0 or 1 | `scripts/zk60_io_capture_preflight.py` (or an attention sibling) parses a capture produced from a real accepted attention receipt and passes its digest, schema, claim-geometry and transcript-join checks; and the round-2 joint tools run on it without modification. A capture from a *tampered* receipt must be refused | G6 |
| **3** | **Fix the endpoint scale fixtures** and add a test that ties the declared scales to the approved calibration | A test that fails if `IoSpec` declares an exponent differing from `causal_oracle`'s `e_r`/`e_r1` (attention) or `e_x`/`e_z16` (FFN). Today's `(-3, -3)` must fail it | G11 |
| **4** | **`norm_m` planes and slots, on the attention side, against the kernel** | A witness-level test: for 1,000 random int16 inputs, the new `nm` planes equal `private-block-kernel`'s `rms_norm(&x1, &w.gamma_m, …)` element for element, *and* refuse at the same site with the same string when the kernel refuses. Plus: a tampered `nm`, `D`, `a1`, `a2`, `ρ` or `σ` reaches the verifier and is rejected there, not by a prover assertion | G1, G13 |
| **5** | **Residual 2 arithmetic, still inside one component** | `xres2 = xres1 + z16` verified against the kernel (`lib.rs:647-651`) including the int16 refusal at both endpoints of the class (−32768 and 32767); a tampered `xres2` limb is rejected by the verifier | G3 |
| **6** | **Re-run R-1, R-2 and the CFS check on the grown layout** | `scripts/zk60_attention_native_inventory.py`, `zk60_attention_pair_schedule.py` and `zk60_attention_cfs_slots.py` report disclosed dimension 0 on every group and every commitment, rank = ΣL − (k+1) on every host group, `L_s + 256 ≤ 512` on every slot, and **all** negative controls still fire — on the new site counts, not the accepted 75/35. Any control that stops firing is a stop | G10 |
| **7** | **The pending/manifest lifecycle on one side only** (whichever component will own the seam claim) | `finalize` refuses when a declared role is never consumed, and refuses when one is consumed twice; a late mask insertion after the A commit is a compile error or a typed refusal, not a silent success. Model: FA3 §12.1 as summarised at `ZK60_OPUS_SEAM_REVIEW.md:501-518` | G8 |
| **8** | **One seam, end to end, with its negative test first** | The headline acceptance check the task asks for: **a seam proof in which the two endpoint roots differ is rejected by the verifier.** Concretely: build the block honestly, then rebuild the FFN half on a different `nm`, re-run, and require the composed verifier to reject — and separately, present the correct values under a *different* root and require rejection. Both must fail at the verifier, not at a prover assertion (`ZK60_PRIVATE_BLOCK.md:242-243` states this rule) | G2 |
| **9** | **The second seam and the block output endpoint** | The block's `SC_IO_OUT` carries `xres2`; a receipt that binds `xres1` there is rejected; `z16` no longer appears as an external endpoint | G3, G4 |
| **10** | **Whole-block parity and framed byte verification** | A fresh process, given only the public statement, the endpoint policy and the receipt bytes, accepts the honest block and refuses a tampered copy; and the composed witness equals `private-block-kernel::run_block` on the public synthetic fixture, including the refusal site | G7, G13 |
| **11** | **The composition privacy gate** | The construction's gate at block scope: on captured real receipts, a zero-witness preimage with the same free dimension as the real witness on every channel (`ZK60_PRIVATE_ATTENTION_CONSTRUCTION.md:135`). This is where the D8/D11 obligation has to be confronted, not before | G15 |

Two notes on the ordering. Step 2 is deliberately first among the build items
because it is the only piece with no dependency on steps 0 and 1, and because
every later privacy check consumes its output. Step 8's negative test is listed
*before* its positive counterpart on purpose: a seam that cannot reject a wrong
endpoint is not a seam, and `ZK60_OPUS_SEAM_REVIEW.md:591-597` records that no
test in the repository today binds `private_seam` to a real FFN or attention
plane at all.

Steps that are **not** in this list because they are not this milestone: P3
weight privacy, the block-to-block residual seam (S5), embedding/head/token
selection, and any speed claim. The attention component's 0.09 s at the tiny
geometry says nothing about 8B (`…_DISPOSITION.md:36`).

## 6. What was NOT checked

This was a read-only scoping pass. Nothing below was done, and no claim in this
document should be read as covering it.

**Not run.** No `cargo` of any kind — no build, no `cargo check`, no test, no
example, no proof, no benchmark. Every statement about code is from reading the
source at the state of `/home/victor/wt-zk60-attention-compile` on 2026-09-19.
No Python tool was run either, so the rank, CFS and capture records cited from
`results/zk60_private_attention_native_evidence/` are taken from the disposition
and the R-2 review as written, not re-verified.

**Not read in full.** `hashline/src/zk.rs` (227 KB), `hashline/src/layer.rs`
(113 KB) and `hashline/src/attention.rs` (152 KB) were searched, not read. In
particular I did not audit `zk::prove_layer_zk_v3` / `verify_layer_zk_v3`, the
FFN's internal claim assembly, or `pcs::open_zk` / `verify_zk` themselves. The
claim in section 3 that the FFN proves no range on its input plane rests on the
helper-spec lists at `layer.rs:1394-1401` and `:542-546` and on
`zk_ffn_fresh_poc.rs:117-144`; I did not exhaustively prove the absence of an
`x` range constraint elsewhere in `layer.rs`.

**Not verified.** (a) Whether `pcs::verify_zk`'s behaviour depends on
`NttTables::max_log` — finding C6 is flagged, not resolved. (b) Whether
`LayerParams::pcs_for(8)` yields exactly `SeamSpec::params()`; I compared the
three literal parameter sets (`log_cols 8`, `inv_rate 8`, `256` checks) and they
agree, but I did not read `pcs_for`. (c) The byte counts and timings in
`ZK60_PRIVATE_ATTENTION_NATIVE.md:85-96` (2,245,800-byte receipt, 0.09 s) are
quoted from the disposition, not recomputed. (d) Whether the 18-slot schedule's
site counts would still admit the added `norm_m`/residual-2/seam sites within
`L_s + 256 ≤ 512` — that is step 6's job and I did no arithmetic on it.

**Not analysed.** No privacy analysis of any kind. I did not attempt a
simulator, did not evaluate whether any proposed seam form is zero knowledge,
and did not assess whether configuration (R) of section 4 is reachable by an
adversary who does not control the composition. Section 4 reports what the
retracted argument and the native reproduction say and matches their geometry to
the code; it does not extend either.

**Out of scope by instruction.** No fix was designed, no code was written, no
ruling was reopened (P1 scope, D3, D4, D5 stand as recorded), and nothing under
`/home/victor/IntelligenceRegulation` was touched. The zkVM route
(`ZK60_DECISIONS.md:215-225`, D7) is a separate profile and was not compared
against these gaps beyond noting that D11 clarifies its chaining description is
proposed, not implemented.

**Stale material I did not fully reconcile.** `ZK60_OPUS_SEAM_REVIEW.md` is
cited heavily, but it was written against the *old* combined attention path,
where the attention half was not hiding at all (its U-1 at `:628-636`). That
specific blocker is closed by the new native component; I did not re-audit the
other fourteen items (U-2 … U-15) one by one against the new code, and cite only
those whose mechanism I confirmed still applies.
