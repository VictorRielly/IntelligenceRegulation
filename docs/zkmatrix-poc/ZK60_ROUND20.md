# Round 20 — conditional PCS and mask-opening algebra

The new [opening tool](../../scripts/zk60_io_opening_translation.py) checks a
specific part of the repaired IO proof that O8 deliberately excludes: the
**pad coordinates and encoded columns, together with the full M opening**.
The algebra below shows these field-valued opening channels add no restrictions
to an already fixed message/functional view, under the stated one-opening,
fixed-challenge conditions. Executable checks exercise this on the four
round-19 captures. This is conditional progress toward the privacy argument,
not full IO zero-knowledge acceptance or a new private-block implementation.

The proving code, receipt format and production verifier are unchanged.
Source is `1f0ff3680c4cda88f1744343e24eb93cdddfcba4`, profile
`ffn-v3-mr1-fresh-io-poc/2`. The tool checks the ten Rust source digests in the
round-19 manifest, runs its capture preflight and checks all capture/receipt/
policy digests against that manifest. It reads only public observations.

## 1. PCS: preserve pads and sampled columns together

At fixed claim points, group lambdas and proximity challenges, write `B` for
the row-folding matrix over Fp: each Fp2 fold supplies two Fp rows. The same
`B` multiplies the message columns and the independent pad coefficients in
`zkp-core/src/pcs.rs::fold_rows_multi_zk`.

Let `D` and `D + delta_D` have the same message vectors, so
`B delta_D[:,j] = 0` for every message column `j`. Any additional conditions
on individual terminals, public rows, shared endpoint planes or H's zero-sum
pair must already be satisfied by this difference. This lemma does not supply
the message difference or prove those conditions satisfiable.

For row `r`, let `delta_f_r` interpolate its message difference on `G_n`.
The committed polynomial is `f_r(X) + (X^n - 1) g_r(X)`, with `deg g_r < Q`.
Let `S` be the set of distinct sampled points on `7 G_2048`. For each row,
interpolate a polynomial `delta_g_r`, degree below `|S|`, with values

```
delta_g_r(x) = -delta_f_r(x) / (x^n - 1),  x in S.
```

There are at most 256 distinct samples, `Q = 256`, and the sample coset is
disjoint from `G_256`; all denominators are nonzero. The construction uses the
same base-field interpolation map on every row. Consequently it commutes with
`B`: every pad coefficient of `B delta_g` is zero because `B delta_f` is zero.
Thus all full group/proximity vectors and every sampled encoded word remain
unchanged simultaneously. Adding these pad differences is a bijection on
the independent uniform pad space. Duplicate sampled indices cost no extra
pad freedom.

This also applies to a message difference shared across several commitments:
apply the construction separately to each owner's independent pads and sample
set. It does not alter their message planes, so aliases already respected by
the message difference remain respected. O8 must still establish the required
joint message result; independent role checks here do not establish it.

The executable check recomputes every captured claim row weight, group fold
and proximity fold, then independently evaluates every public vector against
all sampled columns. For each role it constructs a nonzero base-field row
direction preserving all individual claim row folds, proximity and H's pair
pointwise. A nonconstant message and its interpolated padding exercise the
translation on this direction. These are illustrative kernel directions, not
alternative valid FFN witnesses. In particular the separate A/endpoint examples
are not claimed to respect their cross-commitment aliases. A unit test uses
two independent directions and unrelated column patterns to check the general
construction without the single-tensor simplification.

## 2. M: one construction for all eight slots and both blinders

In `hashline/src/zk.rs::mask_commit`, each Fp2 slot has `L = N*d + 2`
coefficient values followed by `Q = 256` random pad values and fixed zeros on
`G_m`, `m = 512`. Their interpolating polynomial is `A_s`, degree below 512.
The two base rows of each slot are independent coordinates of this polynomial.
The other four rows encode Fp2 polynomials `b` and `u`, degree below 1024;
`b_512 = -b_0`, and `u` is unrestricted.

Fix the public functional weights, theta, proximity coefficients and sample
set. Let the slot-prefix difference `delta_a` preserve every public functional
(preserving just their theta-combination `V` suffices for this isolated M
lemma). Each slot prefix can be extended to a degree-below-512 polynomial
`delta_A_s` that is zero at every sampled point and at every fixed trailing
message position. An explicit construction is:

```
T_s(X) = product (X - y), y in G_512 at indices L_s+256 .. 511
S(X)   = product (X - x), x in the distinct sample set
delta_A_s(X) = T_s(X) S(X) h_s(X)
```

Choose `h_s`, degree below `L_s`, by interpolating the required prefix divided
by `T_s S` at the first `L_s` message nodes. These nodes are disjoint from
both root sets. The degree is at most
`512 - L_s - 256 + |S| + L_s - 1 <= 511`; only the allowed pad positions
change outside the prefix.

Let `W_s` interpolate the theta-combined functional weights on `G_512`.
Those weights are zero outside the prefix. Set

```
delta_b = -sum_s delta_A_s W_s
delta_u = -sum_r proximity_rho_r * delta_base_row_r
```

The last sum includes all 16 base slot rows and both base `b` rows. These
choices preserve every coefficient of `q = sum A_s W_s + b` and of the
proximity polynomial. The degree bounds fit the original blinder spaces.
Also,

```
512 (delta_b_0 + delta_b_512) = -delta_V = 0.
```

This follows by summing the product over `G_512`, where the weights vanish
on the pads and fixed zeros. Thus `delta_b` respects the actual zero-sum
constraint; no forbidden constant freedom is assumed. At sampled points all
`delta_A_s` vanish, hence both `delta_b` and `delta_u` vanish too. All twenty
sampled base words therefore remain unchanged. Translating the pads and the
valid `b,u` spaces is a bijection. This addresses their shared use across
`q`, proximity and columns, rather than analyzing these observations separately.

On each real capture the tool constructs a joint difference in the kernel of
all fourteen functionals, with every slot nonzero. It checks each prefix and
fixed trailing position, the blinder constraint, the full polynomial equations
at all 4096 domain points, and every sampled row. The public captured `q`,
proximity and column equations are independently checked first. The functional
matrix has Fp2 rank 14; its coefficient kernel has dimension 211 in P1 and 215
in P3. These dimensions describe the functional map, not remaining witness
entropy after the whole proof. CFS round messages are outside this check.

## 3. Boundary of the result and the next implementation gate

These are algebraic translations at fixed public coefficients and samples.
They do **not** keep the salted Merkle roots or authentication paths fixed.
Nor do they show that witness-dependent Fiat–Shamir challenges can be treated
as independent fixed inputs. A translation of field observations is not a
forged receipt or a proof simulator.

The following obligations remain, in order:

1. Integrate O8's message/terminal/proximity result, including shared X/z16
   planes and H's public constraint. O8 has not been delivered at this round's
   review point. Its original task remains active.
2. Compose that result with the CFS round-message channel and this opening
   lemma under the actual adaptive transcript. Recheck the FA8 simulator
   hypotheses for `/2`, including refusal, randomness allocation and the
   single-opening owner lifecycle. In particular the new endpoint roots are
   **caller-fixed public inputs**: a simulator that freely substitutes dummy
   endpoint roots does not establish the required statement. Specify the
   endpoint preparation/auxiliary-input model and justify the corresponding
   commitment/transcript simulation. This is an unresolved argument boundary,
   not an executable disclosure finding.
3. Once the repaired IO construction is accepted, carry the reviewed masking
   and consuming-owner design into private attention and then a tiny complete
   block. Registered private-model authentication remains a separate feature;
   the maintained minimal core extraction stays priority 3.

Repeated openings are excluded. The owner API's refusal is essential, as the
negative tests demonstrate: one blinder translation generally cannot preserve
two different M weightings, and new sampled points can expose a difference
hidden at the first set. No new disclosure of repaired FFN weights is reported
by this round; it also does not certify their privacy against the full view.

## 4. Reproduction and validation

The [result](../../results/zk60_round20_opening_translation.json) records all
four artifact digests, the source manifest digest, tool/dependency hashes,
per-role checks and numerical corruption controls. The original captures
remain under `/tmp/zk60-round19/captures`; their regeneration instructions
are in [round 19](ZK60_ROUND19.md). Do not relabel captures from changed code.

```
python3 -m unittest discover -s tests -p test_zk60_io_opening_translation.py -v
python3 -m unittest discover -s tests -p test_zk60_fable_cfs_channel.py -v
python3 scripts/zk60_io_opening_translation.py --captures /tmp/zk60-round19/captures --out results/zk60_round20_opening_translation.json
```

Validation consists of fourteen new arithmetic/construction tests, the 21
archived FA6 regression tests, four full capture checks (18 private PCS owners
and four shared M openings), and eleven numerical corruption controls against
each of one real P1 and one real P3 capture. Controls alter M polynomial
coefficients, a/b/u sampled words, theta and functional weights, plus endpoint
pad coordinates, sampled words and group lambdas. Small-geometry tests also
compare against direct DFT, schoolbook multiplication, dense Lagrange rows and
the archived dense M leakage model; they detect insufficient pads, missing
blinders, nonzero functionals and commitment reuse. No test relies on skipped
access to `/tmp` fixtures.

The [validation record](../../results/zk60_round20_validation.json) retains
commands, exits and log hashes; logs and the runner are in
`results/zk60_round20_evidence/`. The run uses the shared heavy-job lock and
an 8 GiB address-space limit. No Rust/protocol code changed, so round 19's
227 Rust tests, six process verifications and freeze-check remain historical
evidence; they are not counted as rerun here.
