# D63 lane L26: the input opening at the unique-decoding radius (L24-1's fix), built beside the existing instance (2026-11-07)

Lean lane L26 (Claude), on its own worktree, fast-forwarded to perf at `2ba55340` (lanes L9 to L24 merged). Lean 4.34.1,
Mathlib v4.34.1, no new dependency. Five new library files under `formal/ZK60Formal/`, imported by the library root:
`BindingU.lean`, `BindingUTest.lean`, `BindingUDecode.lean`, `ProtocolClassifyU.lean`, `ProtocolClassifyUEp.lean`. No
Rust and no production source changed. `Statements.lean`, L18's `classifyProtocol` and every existing Lean file are
unchanged. Evidence: `results/zk60_lean_l26_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources), **ESTIMATE** (arithmetic on proved bounds or on code counts, not proved in Lean), **HYPOTHESIS** (a named
premise of a proved theorem).

## 1. In plain words, for Victor

**The decision you need to make (finding L24-1).** In the classify instance as it stands, "the input commitment opens
to `x`" means that ALL `N` columns of the input commitment open (`N = 65,536` at R13, the app's profile). The verifier
checks only `Q = 256` of them. So a cheating prover can put one unusable leaf in the commitment and still be accepted
about 99.6 % of the time, and then no input opens the commitment in that sense. With that definition the extraction
half of `KnowledgeSound` (O11d) is false at this instance, and the production gate cannot be proved for the classify
run. The fix L24 proposed is to change what "opens" means in the INSTANCE (not in `Statements.lean`): the commitment
opens to `x` when `x` is admissible and **all but at most `e` columns** open to `x`'s encoding, with `e` the code's
unique-decoding radius. This lane built that fixed instance beside the existing one, proved its binding, the
endpoint's extraction and the gate through it, so it is ready for your ruling.

**Choice A: adopt the opening at the unique-decoding radius (`classifyProtocolU`, `e = 24,448` at R13, `e = 8,052` at
W16R2).** What it means:
- `Binding` becomes STRONGER, not weaker: nobody can open one commitment to two different inputs even when each opening
  is allowed to miss `e` columns. Proved at your target for every `q` (`classifyU_binding_r13`,
  `classifyU_binding_w16r2`).
- `Complete` is unchanged: the honest prover opens every column, so it opens at every radius (`completeU_of_complete`).
- `ZeroKnowledge` is unchanged: it never mentions the opening (`zkU_of_zk`).
- `KnowledgeSound` asks the extractor for an opening that misses at most `e` columns instead of none. Because of
  `Binding`, that opening still pins down ONE input: two different inputs cannot both open the same commitment at this
  radius. So "the receipt attests the model's output on the committed input" keeps its meaning; the committed input is
  the one the commitment decodes to. §4 gives the argument in full.
- The one practical consequence (finding L26-1): an accepted receipt guarantees that the input commitment can be opened
  with all but `e` columns, not necessarily with all of them. Any later procedure that re-opens the input commitment (an
  audit or a dispute) should check at radius `e`. For honest users nothing changes, since they open every column.

**Choice B: keep the full opening (L18's `classifyProtocol`).** Then O11d stays false and the classify run can never be
proved production-ready, unless the verifier opened all `65,536` columns (256 times the opening work and proof size),
or the protocol changed in another way.

**My recommendation: A**, at the tight radius (`e = 24,448` at R13, `8,052` at W16R2). It is the standard meaning of an
opening for a Reed–Solomon commitment under Merkle trees, and it is what the verifier's spot check can actually enforce.
A smaller radius would make the opening closer to "all columns", but the column test then catches less: at W16R2,
`e = 5,000` would give about `2^-67` per query instead of `2^-113.9`.

**What is proved here.**
1. **Binding at the radius, reduced to Merkle binding** (`bindingU`, `binding_classifierU_target`): two openings of one
   root to different inputs at radius `e` (`2e + n + Q ≤ N`) give a Merkle collision at some position. The reduction
   cannot see which position without hashing, so it pays a union over the `N` positions: at most
   `N · collBound(q + 2(h + 2))`, still far inside your target `q·2^-100 + 2^-100` for every `q` (`N ≤ 2^20`).
2. **The fixed instance** `classifyProtocolU`: L18's instance with only `opensIn` changed, and the gate through L24's
   joint extraction at it (`classifyU_productionReady_joint_target`).
3. **O11d, the endpoint's extraction, at the fixed instance.** The extractor reads the input from the columns that
   open, by unique decoding. A new fact was needed here (finding L26-2): the existing opening analysis (`GroupsGood`)
   decodes the extracted matrix, but a column that does not open is read as a default value, which may agree with the
   decoded codeword by accident. The verifier's spot check, however, demands that every sampled column OPENS and is
   consistent. So the bad columns are "does not open, or inconsistent", and the test catches more than `e` of them
   except with probability `((N − e − 1)/N)^Q` per query: `2^-172.4` at R13, `2^-113.9` at W16R2 (`closeIn_column`,
   `xB_eps_r13`, `xB_eps_w16r2`). Its first round (the `ρ` weights) costs at most `N/|F|`: `2^-110` at R13, `2^-111` at
   W16R2 (`closeIn_comb_prob`, `xA_eps_r13`, `xA_eps_w16r2`). These are two new kinds in L24's count.
4. **The gate re-assembled** (`classifyU_productionReady_ep_target`): with the endpoint's part of the cover DISCHARGED
   from those two kinds and the decoding link. **The numbers, with the two new kinds: R13 `57,589,594` of the
   `67,108,864` units the target allows (86 %); W16R2 `31,480,689 ≤ 2^25`, inside half the target**
   (`jointU_r13_target`, `jointU_w16r2_target`).

**What is left** (named premises, §5): L24's remaining premises for stage IN-C, the blocks and stage OUT-C, unchanged;
for the endpoint, five deterministic links: the extractor's openings verify and are canonical, the run's extractor
reads the endpoint by decoding, the opening data can hold the decoded rows, the column test's chain link (with the
identification of the extension-field closeness with the base-field one), and SIC_IO's "zero off the token positions"
on the decoded plane.

## 2. What is proved

PROVED in every row (axioms at most `propext`, `Classical.choice`, `Quot.sound`; the counts in §7).

### 2.1 `BindingU.lean`: binding at the radius

| Theorem / definition | Statement |
|---|---|
| `atCol`, `binding_at` | one fixed position: two openings with different columns that both verify cost at most `collBound (q + 2(h + 2))` (`merkle_binding`, no further query) |
| **`bindingU`** | two different values opening one root at radius `e`, `2e + n + Q ≤ N`: at most `N · collBound (q + 2(h + 2))` (L24's `opensU_diff` and the union over the `N` positions) |
| `opensU_mono` | a larger radius is a weaker opening |
| `bindingU_le_target`, **`bindingU_target`** | for `N ≤ 2^20`, depth `≤ 64`: within `εsTarget q` for EVERY `q` |
| **`binding_classifierU_target`** | `Binding M P εsTarget` for a protocol whose `opensIn` is `OpensU` and whose hidden output is a subsingleton |
| `w16r2_radiusU`, `w16r2_radiusU_max`, `r13_radiusU`, `r13_radiusU_max`, `w16r2PlaneCommit_radiusU`, `r13PlaneCommit_radiusU` | the radii `8052` (W16R2: `2e + n + Q = 2^15` exactly) and `24,448` (R13: `= 2^16` exactly), one more breaks each; every W16R2 / R13 plane commitment has them, `N ≤ 2^20`, depth `≤ 64` |

### 2.2 `BindingUTest.lean`: the endpoint's column test with the columns that do not open counted as bad

| Theorem / definition | Statement |
|---|---|
| `CloseIn`, `CloseIn.close` | close on a set of all but `e` columns INSIDE the set `X` of columns that open |
| **`closeIn_comb_prob`** | round 0: rows not close inside `X`, uniform `ρ` makes `Σ ρ_i U_i` close inside `X` with probability `≤ N/|E|` (`A ≤ N`; far: correlated agreement; close: a column of the agreement set with `U_j ≠ g_j` killed by `ρ`, `1/|E|` each) |
| **`closeIn_column`** | round 1: `Σ ρ_i U_i` not close inside `X`, then for any proximity codeword the bad set `{j ∉ X or inconsistent}` has `≥ e + 1` columns, and `Q` uniform indices avoid it with probability `≤ ((N − (e + 1))/N)^Q` |
| `xASt`, **`xA_rbrWide`**, `xBSt`, **`xB_rbrWide`** | the two rounds round-by-round sound on digests (errors `N/|F|·βLR`, `((N − (e + 1))/N)^Q·βJ`) |
| `HdrXU`, `xACSub`, `xBSt'`, `xBCSub`, **`xACSub_rbr`**, **`xBCSub_rbr`** | on the code's chain at the opening halves' windows (`opA`'s `(λ, ρ)`, `opB`'s indices; `ρ` read off the header by `opA`'s reader) |
| **`x_split`** | deterministic, as L20's `opening_split`: the first half alive at the end, or the second half entered doomed |
| `xACsAt`, `xBCsAt`, **`openX_chain_pos`** | the test's chain event (first half enters with the matrix not close inside the openable set, second half alive at the end) at most `(q·εA + εA + coll) + (q·εB + εB + coll)`, for any extraction of the matrix and the openable set from the prover's log |
| `w16r2_open_code_factsU`, `r13_open_code_factsU` | the code facts at the radii, `A = N` (R13: minimum distance `48,897`, correlated agreement at `e = 24,448`, BCIKS20 at the δ/2 radius, tight) |
| `xA_eps_w16r2`, `xA_eps_r13`, `xB_eps_w16r2`, `xB_eps_r13` | `≤ 2^-111`, `≤ 2^-110`, `≤ 2^-113`, `≤ 2^-172` |

### 2.3 `BindingUDecode.lean`: the decoding link (deterministic)

| Theorem / definition | Statement |
|---|---|
| `colGF`, `col_of_colGF` | a canonical column is the column of its own entries |
| `exX`, `exX_spec`, `exU`, `exU_spec` | the columns that open and the extracted matrix, read off the extractor's openings |
| `colOf`, `SaltMk`, `column_mk`, `exSalt`, `exPath` | the column of decoded rows; opening data built from the decoded rows and the extracted salts and paths |
| **`opensU_of_decoded`** | on all but `e` columns the extracted opening verifies and is the decoded rows' column, the decoded data rows are `v`'s plane, `v` admissible ⇒ `OpensU` at radius `e` with the built opening data |
| **`agree_of_closeIn`** | the extracted (canonical) matrix close inside the columns that open ⇒ decoded rows and such a set |
| `decodeIn`, `decodeIn_spec`, **`opensU_of_closeIn`** | the decoded rows as a function of the extraction; the link in one step |
| `posPlane_eq_of_zero` | for the token-words plane: the decoded data rows ARE the plane of the words at the token positions read canonically, when they vanish elsewhere |

### 2.4 `ProtocolClassifyU.lean`: the fixed instance

| Theorem / definition | Statement |
|---|---|
| **`classifyProtocolU`** | L18's `classifyProtocol` with `opensIn := Cin.OpensU … e`, every other field the same term |
| `opensInU_iff`, `opensIn_U_of`, `verifyU_iff`, `proveU_eq` | its parts: L18's opening is one at every radius; THE same verifier and honest prover |
| **`completeU_of_complete`**, **`zkU_of_zk`** | `Complete` and `ZeroKnowledge` transfer from L18's instance with the same errors (the same simulator) |
| **`classifyU_binding_target`**, `classifyU_binding_w16r2`, `classifyU_binding_r13` | `Binding` at the target for every `q`; at the W16R2 and R13 token-words endpoints |
| `jointCover_of_parts` | L24's joint cover from a cover of IN-C, the blocks and OUT-C, and a cover of the endpoint that may assume IN-C's conclusion |
| **`classifyU_productionReady_joint`**, **`classifyU_productionReady_joint_target`** | L24's joint gate at `classifyProtocolU` (every `ClassifyOpen` field but O11; its extraction bounds are unused, so the trivial bound `1` does) |

### 2.5 `ProtocolClassifyUEp.lean`: O11d and the gate

| Theorem / definition | Statement |
|---|---|
| `ChainU`, `StabU`, **`FirstKind.singleU`**, `FirstKind.singleU_ev` | a kind of ONE sub-protocol, its soundness fields from the sub-protocol's own bound |
| `XTest`, `XTest.εA`, `XTest.εB`, `XTest.cA`, `XTest.cB`, **`xKindA`**, **`xKindB`** | the column test's two halves as two kinds |
| **`xKinds_cover`**, `cover_of_xKinds` | the test's chain event lies in one of the two kinds; the column-test premise from them |
| **`epCoverU`** | accepted, the endpoint's conclusion at `classifyProtocolU` fails ⇒ the extraction failure, or the matrix not close inside the columns that open, or the decoded plane not zero off the token positions |
| **`classifyU_O11d`** | O11d in `ClassifyOpen`'s form at `classifyProtocolU`: `≤ εKinds Ks εx q` |
| **`classifyU_productionReady_ep_target`** | THE GATE at `classifyProtocolU` at the approved targets with the endpoint's cover discharged |
| `partConst_eleven`, `jointU_budget_w16r2`, `jointU_budget_r13`, `jointU_totals`, **`jointU_w16r2_target`**, **`jointU_r13_target`**, `xKind_lin_le` | the numbers (§3) |

## 3. The numbers

Units: `u126 q c = (q + 1)·c/2^126`; target `εsTarget q = u126 q 2^26`, half target `u126 q 2^25`.

| | W16R2 | R13 (the app) |
|---|---|---|
| `N`, `n + Q`, radius `e` (tight: `2e + n + Q = N`) | `2^15`, `16,664`, `8,052` | `2^16`, `16,640`, `24,448` |
| column test, round 1 `((N − e − 1)/N)^Q` | `2^-113.9` (`≤ 2^-113`) | `2^-172.4` (`≤ 2^-172`) |
| column test, round 0 `N/p²·(1 + p/2^128)^(2w0)` | `≤ 2^-111` | `≤ 2^-110` |
| the two kinds' linear constants | `2^15`, `2^13` | `2^16`, `1` |
| the two kinds with collision terms | `+303,104` | `+327,681` |
| L24's joint total (nine kinds) | `31,177,585` | `57,261,913` |
| **joint total (eleven kinds)** | **`31,480,689 ≤ 2^25` (94 % of the half)** | **`57,589,594 ≤ 2^26` (86 %)** |
| Binding (`N·collBound`, any `q ≤ 2^120`) | `≤ q·2^-100 + 2^-100` | `≤ q·2^-100 + 2^-100` |

The binding bound in absolute terms [ESTIMATE]: at `q = 2^64` it is about `2^16·(2^64)^2/2^257 = 2^-113`, at `q = 2^100`
about `2^-41`, below the target's `≈ 1` there.

## 4. Why `OpensU` does not weaken the approved meaning of `Binding` and `KnowledgeSound`

`Statements.lean` is unchanged; only the instance's `opensIn` changes. Write `Opens` for L10's full opening and `OpensU`
for the opening at radius `e`.

1. **`Opens` implies `OpensU`** (`opensU_of_opens`). So the event "two different values both open" is LARGER with
   `OpensU`, and `Binding` with `OpensU` bounds a larger event: it implies `Binding` with `Opens`. Binding is
   strengthened.
2. **The committed input is still unique.** For a statement `s`, call `x` "committed by `s`" when some opening data
   opens `s`'s input root to `x` at radius `e`. Two different committed inputs would give, at a position where both
   open with different columns (`opensU_diff`, which needs `2e + n + Q ≤ N`), two different openings of one tree
   position: a Merkle collision (`bindingU`). So, except with the binding probability, every party that can produce an
   opening produces the SAME input. That is the sense in which the commitment determines the input, by decoding.
3. **`KnowledgeSound`'s promise keeps its meaning.** Its conclusion is: the extractor outputs an admissible `x`, the
   commitment opens to `x`, and the statement's public output is the model's on `x`. With `OpensU`, "opens to `x`"
   says that `x` is THE committed input (2.), so the receipt attests the model's output on the committed input, which
   is Statement 1's approved wording. What is literally weaker is only the opening certificate (all but `e` columns
   instead of all); a full opening cannot be extracted at all (L24-1), so no definition can ask for it.
4. **`Complete`** asks the honest prover's commitment to open; it opens every column, hence at every radius
   (`completeU_of_complete`).
5. **Nothing else reads `opensIn`** (`ZeroKnowledge`, `SemanticHiding`, `CircuitIff`).

I found no property that the change weakens beyond the opening certificate itself; that consequence is finding L26-1.

## 5. The remaining premises

Every one is a named hypothesis of a PROVED theorem (`classifyU_productionReady_ep_target`).

1. **Everything L24 left for stage IN-C, the blocks and stage OUT-C** (`h3`, the kinds' fields and constants, the
   Merkle extraction failure), unchanged; and `ClassifyOpen`'s O1–O10, O12 as L18 left them.
2. **The endpoint** (new, deterministic):
   - `hops`, `hcan`: the extractor's openings (`ops`) verify against the statement's root, with canonical columns
     (true of an extractor that checks the openings it reads against the log and keeps only canonical columns; an
     accepted opened column is canonical when the segment decoder refuses every word `≥ p`, as L9's block decoder does,
     `CoreCanon`; for stage IN-C's segment, whose decoder is the `StageInV` parameter, that is part of this premise);
   - `hE`: the run's extractor reads the endpoint by decoding (`decodeIn`) and builds the opening data with `mk`;
   - `mk : SaltMk`: the instance's opening-data type can hold the non-data rows' messages, the pads, the salts and the
     paths (the honest half is L18's `HonestIn.withPaths`);
   - `pos`, `hplane`: the input commitment's plane is the token-words plane (`rfl` for `w16r2TokenCommit` and
     `r13TokenCommit`);
   - `hX` (from `cover_of_xKinds`): the column test's chain link: accepted, no extraction failure and the base-field
     matrix not close inside the columns that open ⇒ the test's chain event (its windows at steps' ends, its second
     half alive at the end, the matrix and the openable set read at its windows, and the identification of the
     extension-field closeness of the embedded matrix with the base-field closeness, finding L26-3); the kinds'
     stability premises `StabU` (L24-2's weak form);
   - `hzero`: accepted and no extraction failure ⇒ the decoded endpoint plane vanishes off the token positions, or some
     kind's event (SIC_IO's identity and the endpoint opening's claims; finding L26-4).

## 6. Findings

No statement or target is weakened; `Statements.lean`, L18's instance and every existing theorem are unchanged.

**L26-1 (Low; for Victor, a consequence of choice A): an accepted receipt guarantees a radius-`e` opening of the input
commitment, not a full one.** With `classifyProtocolU`, a cheating prover's input commitment may have up to `e` columns
that do not open. The input is still determined (Binding, §4), but any later procedure that re-opens the input
commitment (an audit, a dispute, a disclosure to a third party) must accept an opening that misses up to `e` columns, or
it may refuse a receipt the verifier accepted. Honest users open every column, so nothing changes for them.

**L26-2 (Medium; resolved here): `GroupsGood` does not give `OpensU`; the endpoint needs the column test with the
columns that do not open counted as bad.** The existing opening knowledge (L20's `opening_knowledge_chain_pos`) decodes
the extracted matrix, in which a column that does not open is a default value; it may agree with the decoded codeword,
so "close" does not mean "all but `e` columns open". Two separate tests (openability at radius `e₁`, `GroupsGood` at
`e₂`, `e₁ + e₂ ≤ e`) lose the exponent: at R13 the even split costs about `2^-76` per query each. The verifier's check is
ONE test of both (every sampled column must open AND be consistent); counting it as one (`closeIn_column`) keeps the full
radius: `2^-172.4` (R13), `2^-113.9` (W16R2), with round 0 at `N/|F|` (`closeIn_comb_prob`). Two new kinds; the budget
stays inside the target (§3).

**L26-3 (Medium; a premise): the column test's code lives over the extension field.** The weights `ρ` are drawn in
`F_p²`, so the test (like L20's openings) is analysed over `F_p²` with the commitment's base-field columns embedded,
while `OpensU` is a base-field statement. The link "the embedded matrix close inside the openable set over `F_p²` ⇒ the
base-field matrix close over `F_p`" is a coding fact for the Reed–Solomon encoder (an `F_p²` codeword of degree
`< n + Q` that agrees with base-field values on at least `n + Q` points is the image of the base-field interpolant), not
proved here; it sits inside `hX` (as the analogous identification sits in L20/L22's `hsem` for the blocks).

**L26-4 (Low; a premise, also true of the full opening): the decoded endpoint plane must vanish off the token
positions.** L10's plane commitment (`posPlane`) puts zeros at every position that is not a token word, so ANY opening
of it (full or at the radius) needs the decoded data rows to be zero there. L18's `InOk` carries only SIC_IO's
support half (`epW = tokW`); the "others zero" half of `in_endpoint_words` on the decoded data is the premise `hzero`,
to be covered by IN-C's SIC_IO zero-check and the endpoint opening's claims.

**L26-5 (Info): the binding reduction pays a factor `N`.** It takes the union over the `N` positions instead of finding
the colliding position by hashing; `N ≤ 2^20` keeps it inside the target for every `q` (`bindingU_le_target`).

## 7. Checks

(filled in after the checked run)
