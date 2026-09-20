# The block-scope privacy gate P10: a preimage exhibited, channel by channel

Lane `zk60-native-jointview`, 2026-09-20. Tool
`scripts/zk60_native_privacy_gate.py` with `scripts/zk60_native_pg_pcs.py`
and `scripts/zk60_native_pg_cfs.py`; tests
`tests/test_zk60_native_privacy_gate.py`; evidence
`results/zk60_native_privacy_gate/`.

Definition: `ZK60_PRIVACY_CASE_FIRST_MVP.md` §4 (the gate, rewritten under
ruling C-6) and §2 (the view, channel by channel), with
`ZK60_PRIVACY_CASE_FIRST_MVP_CHECK.md` §8 (why equal fibre dimension is not a
pass, and the two controls that test the gate's own criterion). This is step
3 of the five-step path in `ZK60_PRIVACY_CASE_FIRST_MVP_DISPOSITION.md` §3.

> **This is not a privacy acceptance and it establishes no privacy property.**
> It is a statement about the LINEAR channels of four captured receipts at
> two toy layouts. §7 says what it does not show, in plain words.

## 0. In one paragraph

The existing joint-view tool **measures** how much of the hidden data the
verifier's view determines. It never shows that the view could have come from
a different input. This gate does that: for each captured receipt it
**solves**, exactly over the Goldilocks field, for prover randomness — pads,
mask rows, reserved pairs, CFS mask coefficients — that reproduces the
captured view under a **fixed** hidden input, then **recomputes** the whole
view from that randomness and compares it with the capture **entry by
entry**. Two fixed inputs are used: the all-zero one (the same one the Rust
zero-witness test proves and verifies) and a pseudorandom in-range one
derived from a published seed. Across the four captures that is **805,596
entries** — 88,064 group-vector, 8,192 proximity, 574 claim values, 706,090
opened column values, 2,594 masked round entries and 82 masked scalars — and
**every one of them is reproduced exactly, at both fixed inputs, with zero
differing**.
Seven negative controls, each shown to pass on the honest capture, each fire
when perturbed — including the two that test this gate's own criterion.

## 1. What is solved: y, M_data, M_nondata

For one commitment (A, H, Input, Output) the committed matrix is `X` in
`Fp^{rows x 512}`: row `i` is `z_i = (msg_i, pad_i)` in `Fp^256 x Fp^256`.
Split its coordinates:

| block | what it is | size (A, block profile) |
|---|---|---|
| `d` — DATA | `msg_i[t]` on the data rows: the hidden input, output and activations | 213 x 256 = **54,528** Fp |
| `r` — BLINDING | `msg_i[t]` on the non-data rows (mask pairs, proximity rows) and `pad_i[k]` on EVERY row, subject to the layout's public linear constraints | **178,432** Fp |

The verifier's field-valued view is `y = M_data d + M_nondata r`, and every
entry of `y` is in the capture:

| part of `y` | formula | entries (A) |
|---|---|---|
| opening-group vectors | `v_g[t] = sum_i rho_g[i] X[i][t]`, 35 groups x 512 Fp2 | 17,920 Fp2 |
| proximity vector | `v_p[t] = sum_i rho_p[i] X[i][t]`, 512 Fp2 | 512 Fp2 |
| claimed evaluations | `val_c = sum_i rw_c[i] <msg_i, cw_c>`, one per claim | 120 Fp2 |
| opened column values | `col_j[i] = <E_j, z_i>`, distinct nodes x rows | 246 x 455 = 111,930 Fp |

`rho`, `rw`, `cw` and the sampled indices are functions of the public layout
and of the challenges stage 1 of the joint-view tool replays; `E_j` is the
coset-encoding functional of `pcs.rs::encode_row_zk`. **The capture contains
`y`. It contains neither `d` nor `r`, and the gate never invents one.**

Sizes on every capture and commitment:

| capture | role | rows | data rows | groups | claims | distinct columns d | `y` entries (Fp) | blinding unknowns |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| block 40083e7a | A | 455 | 213 | 35 | 120 | 246 | 130,482 | 178,432 |
| | H | 384 | 278 | 9 | 52 | 242 | 98,100 | 125,438 |
| | Input | 7 | 2 | 1 | 1 | 246 | 2,747 | 3,072 |
| | Output | 7 | 2 | 1 | 1 | 241 | 2,712 | 3,072 |
| block 7d334e06 | A | 455 | 213 | 35 | 120 | 243 | 129,117 | 178,432 |
| | H | 384 | 278 | 9 | 52 | 240 | 97,332 | 125,438 |
| attention 6c5e83fd | A | 306 | 154 | 30 | 75 | 234 | 87,551 | 117,248 |
| | H | 290 | 216 | 8 | 36 | 243 | 75,114 | 93,182 |
| attention c26d1f05 | A | 306 | 154 | 30 | 75 | 241 | 89,693 | 117,248 |
| | H | 290 | 216 | 8 | 36 | 239 | 73,954 | 93,182 |

For the masking commitment the data is the **honest sumcheck transcript** and
the blinding is the CFS mask coefficients: `masked_round_j = honest_round_j +
c_s g_s.round(j, rho_<j)` and `scalar_s = honest_scalar_s + c_s
<sum_weights, coef_s>`. The block profile has 23 slots, 583 Fp2
coefficients, 721 published round entries and 23 scalars; the attention
profile 18 slots, 576 round entries and 18 scalars.

## 2. How the preimage is built — and why it can fail

No 178,432-unknown Gaussian elimination appears anywhere. The solve is
triangular, and each step is small and exact:

1. **msg, per opening group.** Under H-pair every claim owns one reserved
   mask pair that no other claim touches, so a group's only non-data support
   is its own claims' pairs. The whole per-position residual goes on one
   anchor pair (a 2x2 system whose determinant the verifier itself refuses
   when zero); then a correction **inside the kernel of that constraint**
   meets (a) each claim's own published value and (b) the public zero-sum
   constraint on any u row. The correction space is parametrised exactly —
   the claim values and the row sums see a correction only through
   `<delta_i, cw>` and `sum_t delta_i[t]`, so three positions reach exactly
   what all 256 reach — which is why "no solution" is a statement about the
   channel and not about the search. Groups are solved in dependency order,
   because H's zsum claim reads the u pair another group owns.
2. **msg, the proximity rows**, last: no claim touches them.
3. **pads.** Writing the encoded row as `Enc_i = Msg_i + Z_n Pad_i`, the
   opened columns fix `Pad_i` at the `d` distinct sampled nodes; Lagrange
   interpolation gives one solution and the whole fibre is
   `I(p_i) + Z_S q_i`. The pad half of each group vector then fixes
   `sum_i rho_g[i] q_i`, which is a polynomial **only when the residual is
   divisible by `Z_S`** — exactly when the verifier's own column identity
   holds. That divisibility is a real feasibility test, and it fires.

**Two places can refuse, and both do** (§5): the claim-and-u-row correction
system, and the `Z_S` divisibility.

## 3. What the gate found — per capture, per channel

Every capture produces the same channel table. 28 channels, one per class of
the privacy case's §2.1 and §2.2 plus the two §4.2 adds:

| status | count | channels |
|---|---:|---|
| **CONSTRUCTED** | 8 | opening-group vectors; proximity vectors; claimed evaluations; opened column values (A, H, Input, Output); masked sumcheck rounds; published masked scalars and `Gamma`; published terminals; LogUp sums |
| **DERIVED** | 2 | column indices (`challenge_indices` over the public prefix, re-derived); mask evaluations (`(fin_s - terminal_polynomial_s) c_s^-1`, asserted per slot) |
| **ARGUED** | 8 | the three Merkle roots (**M-2**); the leaf salts (**M-3**); the authentication paths (**M-2**); counts and lengths, the wire envelope, the framing residue (**shape facts**); the public statement and the 112-byte policy (**O-1**); the receipt's length (**shape facts**) |
| **OPEN** | 10 | the M opening's `q`; the M proximity vector; the M opening's own 256 columns; whether a proof attempt produced a receipt; rejected-but-emitted receipts; retained captures; timing, memory and power; prior proofs by the same prover; the integer-range facts the statement implies; any nonlinear functional of the joint view |

Every ARGUED channel names its assumption in the record, so **the hash layer
is not silent**: the gate fails if any of the three hash channels is missing
or names no assumption, and its own tests check that it does fail.

**The preimages, both fixed inputs, all four captures** (`d = 0` and the
pseudorandom `d'`; "equal" means every entry of the recomputed view equals
the capture's):

| capture | role | preimage at `d = 0` | preimage at `d'` | view recomputed | entries compared | differing | fibre dimension (Fp) |
|---|---|---|---|---|---:|---:|---:|
| block 40083e7a | A | yes | yes | equal | 130,482 | 0 | 47,180 |
| | H | yes | yes (after projection) | equal | 98,100 | 0 | 27,026 |
| | Input | yes | yes | equal | 2,747 | 0 | 286 |
| | Output | yes | yes | equal | 2,712 | 0 | 301 |
| | masking | yes | yes | equal | 744 | 0 | 46 |
| block 7d334e06 | A | yes | yes | equal | 129,117 | 0 | 48,329 |
| | H | yes | yes (after projection) | equal | 97,332 | 0 | 27,754 |
| | Input / Output | yes | yes | equal | 2,642 / 2,698 | 0 | 331 / 307 |
| | masking | yes | yes | equal | 744 | 0 | 46 |
| attention 6c5e83fd | A | yes | yes | equal | 87,551 | 0 | 28,318 |
| | H | yes | yes (after projection) | equal | 75,114 | 0 | 17,816 |
| | Input / Output | yes | yes | equal | 2,726 / 2,670 | 0 | 295 / 319 |
| | masking | yes | yes | equal | 594 | 0 | 36 |
| attention c26d1f05 | A | yes | yes | equal | 89,693 | 0 | 26,610 |
| | H | yes | yes (after projection) | equal | 73,954 | 0 | 18,904 |
| | Input / Output | yes | yes | equal | 2,684 / 2,698 | 0 | 313 / 307 |
| | masking | yes | yes | equal | 594 | 0 | 36 |

**The fibre dimension is the same at both fixed inputs, by construction and
not by coincidence.** `M_nondata` is built from `rho`, `rw`, `cw` and the
sampled nodes alone; the fixed input enters the right-hand side only. The
gate hashes every matrix it solves (`RoleLayout.matrix_digest`) and requires
the digest to be unchanged between the two runs, and reports
`fibre_dimension_equal_across_fixed_inputs`. The number itself is assembled
from the triangular solve: per group, `(pair rows - 2) * 256` minus the
COMPUTED rank of the claim-value and u-row constraints on that kernel, plus
`(rows - 2(G+1)) * (256 - d)` for the pad block.

**The masking commitment's two accountings** (the same two stage 3 of the
joint-view tool reports, and the gate reproduces both figures exactly):

| accounting | what is required of the mask coefficients | conditions on the fixed transcript | stage 3's figure |
|---|---|---:|---:|
| conservative ("all") | every one of the 34 published functional values, as if each DERIVED mask evaluation were an independent observation | **68 Fp** | `disclosed_all_values_fp` = 68 |
| opening-only ("theta") | only the combination the M opening really pins, `512 (q[0] + q[512]) = sum_i theta^i value_i` | **2 Fp** | `disclosed_opening_only_fp` = 2 |

In both, the canonical zero transcript is **infeasible** and the projected
one is feasible: the disclosed dimension shows up as a refusal, not as a
number. (Attention profile: 56 Fp and 2 Fp.)

## 4. The one finding about perturbing `y`

The brief anticipated a possible non-result: if `M_nondata` had full row
rank, **every** view would have a preimage, every perturbation of `y` would
stay in the image, and the "unsatisfiable channel" control could not fire.
That is not what happens here, and the reason is worth stating.

**The channels are tied to each other by the verifier's own public
identities.** The column identity says that the group vector's encoding at a
sampled node equals the group combination of that column's opened values;
the group identity says that `<v_g[:n], cw_g>` equals the lambda-combination
of the claim values. So the image of `r -> view(0, r)` is a proper subspace
of the space of all possible views, and perturbing **one** channel while
leaving the others alone leaves that image. The gate detects it concretely:
a perturbation in a message position fails in the claim-and-u-row correction
system, and a perturbation in a pad coefficient fails the `Z_S` divisibility
test. Both were run and both fired on every capture.

Separately, the brief's fallback design is also implemented and also fires:
**remove blinding unknowns until the block loses rank.** With the pad count
set to `d - 1` against `d` distinct opened columns, the required interpolant
has degree `d - 1` and cannot be written with `d - 1` coefficients: no
preimage. At the receipt's real budget (`Q = 256 >= d`) the map IS onto in
that direction, and **that is the content of "nothing disclosed" on that
channel** — every value the columns could take is reachable from the pads
alone.

## 5. The negative controls — each passes honest, each fires perturbed

All seven run on all four captures; all seven fire on all four; the honest
preimages stand before and after each perturbation (the gate re-checks).

| # | control | what is perturbed | what happened |
|---|---|---|---|
| 1 | **unsatisfiable channel (message side)** — tests the gate's OWN criterion | one coordinate of a captured opening-group vector, at message position 0, opened columns left alone | **fires**: no preimage; the claim value can no longer be met inside the kernel of the group-vector constraint |
| 2 | **unsatisfiable channel (pad side)** | the same vector at pad coefficient 0 | **fires**: no preimage; the pad residual is not divisible by the sampled nodes' vanishing polynomial |
| 3 | **witness-bearing channel** — the check's §8 proposal | H's LogUp sum claim forced off `Fp2::ZERO` | **fires**: the fibre over the all-zero input is EMPTY. The u pair's message sums to zero by the layout's public constraint, so the zero input can only reach a zero published value |
| 4 | **rank loss** | the commitment modelled with `d - 1` pad symbols against `d` distinct opened columns | **fires**: no preimage, with the degree of the required interpolant named |
| 5 | **a blinding unknown shared between two commitments** | one reserved mask row of a singleton group in A and one in H declared the SAME unknown | **fires**: both per-commitment preimages exist, and they force **different** values on the shared unknown at all 256 message positions (first at position 0). Each is the unique solution of an invertible 2x2 system inside its own commitment, so no JOINT preimage exists — the case a per-commitment acceptance cannot see |
| 6 | **the second fixed input off the disclosed identity** | the pseudorandom `d'` on H, before projection | **fires**: no preimage at all before projection, a verified preimage after. The disclosed dimension 2 is a refusal, not a number |
| 7 | **the masking commitment's fixed transcript** | the canonical zero honest transcript against the published functional values | **fires**: infeasible before the projection, feasible and verified after |

Controls 1, 2, 4, 6 and 7 are new: they test **this** gate's criterion (a
preimage exists and is exhibited), which none of the ten controls inherited
from the disclosed-dimension tool did. Control 5 is the real-receipt form of
stage 4's shared-blinding control, now answered with two forced values rather
than with a rank.

## 6. The component's zero-witness acceptance test

The gate's definition (§4.5 of the privacy case) makes the Rust zero-witness
acceptance test the **first** item, because every channel analysis is
conditional on the honest prover being able to produce an accepting receipt
at the zero witness. That test now exists:
`hashline/src/private_block/zero_witness_tests.rs` on branch
`zk60-private-block-125m`, commit `ec84dac` — the all-zero input proves and
verifies, `NORM_CEPS == 1`, the exponential table's first entry is a
constructor refusal, the two range boundaries are pinned (16,383 of an
exclusive 16,384; 512 of an inclusive 512), and the zero-witness receipt is
2,816,472 bytes like the fixture's. **This gate cites it and does not run
it**: this lane is Python-only and builds no Rust. The citation is a field of
the record (`zero_witness_acceptance_test`), with `run_by_this_gate: false`.

## 7. What this does NOT show

Plainly, and none of it is hedging:

* **It is not a privacy acceptance and establishes no privacy property.** The
  record carries `privacy_property_established: false` and
  `is_a_privacy_acceptance: false`.
* **It is four captured receipts at two toy layouts**, at those receipts'
  own challenges. Nothing here is a statement about all challenges (that is
  the generic-rank lemma's job) or about the 125M profile, which owes the
  gate again from the start.
* **The hash layer is ARGUED, not computed.** The three Merkle roots, the 256
  leaf salts per opening and the 11- and 12-level authentication paths —
  499,712 bytes, 17.7 % of the receipt — rest on M-2 and M-3. No linear
  algebra touches them. The honest sentence is "a preimage was constructed on
  the linear channels; the hash channels rest on M-2 and M-3 and were not
  constructed", never "P10 passed".
* **The composition of the channels into one distribution is untouched**
  (open item U-3b). Exhibiting a preimage on each channel is not the same as
  showing the joint law is the same in both worlds.
* **Nothing nonlinear is covered.** The terminal identity links the
  commitment and masking channels with degree up to 4 in the terminals; a
  linear model cannot see that link (chain item 21).
* **Three channels of the M opening are OPEN, by this gate's own choice, not
  for want of a capture field**: `q`, the M proximity vector, and the M
  opening's own 256 columns. Closing them needs a port of
  `zk.rs::mask_commit`'s row layout and of `encode_coeffs_coset` into this
  tool. What IS constructed on that side is the mask coefficients those rows
  hold and the one functional identity `q` pins.
* **The fixed honest transcript of the masking channel is a named, publicly
  computable element of the channel's data space, not the zero witness's own
  transcript**, because the capture does not carry the unmasked honest round
  messages. The privacy case asks for exactly that input (§4.3, the security
  owner's answer 4(a) to Codex); it belongs to the capture writer.
* **The integer-range facts and the refusal, rejected-receipt and retained-
  capture channels are OPEN**, with their reasons in the record.
* **D8/D11, the caller-fixed endpoint-root obligation, is untouched.**

## 8. Reproduce

```
python3 /home/victor/wt-zk60-jointview/scripts/zk60_native_privacy_gate.py \
  --captures /home/victor/wt-zk60-jointview/results/zk60_native_captures_20260919 \
  --evidence /home/victor/wt-zk60-jointview/results/zk60_native_privacy_gate \
  --columns full --controls-on all
python3 -m unittest discover -s /home/victor/wt-zk60-jointview/tests \
  -p 'test_zk60_native*.py'
```

About 160 s for the gate, single core, no GPU and no build. The tests include
a tiny synthetic instance where the data and the blinding are both known, so
the forward map, the solver and the d-independence of the fibre are checked
against a brute-force dense rank — the only place in this lane where a
witness exists at all.
