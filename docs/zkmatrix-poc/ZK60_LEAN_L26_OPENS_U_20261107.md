# D63 lane L26: the input opening at the unique-decoding radius (L24-1's fix), built beside the existing instance (2026-11-07, finished 2026-11-09)

Lean lane L26 (Claude), on its own worktree at perf `2ba55340` (lanes L9 to L24 merged). Started 2026-11-07, cut off
by a usage limit the same day, resumed and finished 2026-11-09. Lean 4.34.1, Mathlib v4.34.1, no new dependency. Five
new library files under `formal/ZK60Formal/`, imported by the library root: `BindingU.lean`, `BindingUTest.lean`,
`BindingUDecode.lean`, `ProtocolClassifyU.lean`, `ProtocolClassifyUEp.lean`. No Rust and no production source changed.
`Statements.lean`, L18's `classifyProtocol` and every existing Lean file are unchanged (checked, §7). Evidence:
`results/zk60_lean_l26_20261107/`.

Labels: **PROVED** (a Lean theorem, axioms at most `propext`, `Classical.choice`, `Quot.sound`), **CODE** (read off the
sources), **ESTIMATE** (arithmetic on proved bounds or on code counts, not proved in Lean), **HYPOTHESIS** (a named
premise of a proved theorem).

## 1. In plain words, for Victor

**The decision you need to make (finding L24-1).** A classify proof starts from a commitment to the hidden input: a
hash tree over `N` columns of encoded data (`N = 65,536` in the app's profile, R13). The approved statements speak of
that commitment "opening to an input `x`". The Lean instance of the classify run defines this as: EVERY one of the `N`
columns can be shown to sit in the tree. The verifier looks at only `Q = 256` columns, chosen at random. So a cheating
prover can build a tree with one broken column and is still accepted about 99.6 % of the time, and for that tree no
input "opens" in the all-columns sense. With that definition the soundness statement (`KnowledgeSound`: from an
accepted receipt one can recover an input that the commitment opens to) is false at this instance, and the production
gate (D63) can never be proved for the classify run. This is a mismatch in the Lean definition, not a weakness of the
protocol.

The fix L24 proposed changes what "opens" means in the INSTANCE (not in `Statements.lean`): the commitment opens to
`x` when `x` is admissible and **all but at most `e` columns** sit in the tree and carry `x`'s encoding. The number `e`
is the code's unique-decoding radius: small enough that two different inputs can never both pass. This lane built that
instance (`classifyProtocolU`) beside the existing one, and proved its binding, the extraction of the input, and the
production gate through it. Both instances are in the tree; nothing is switched until you rule.

**Choice A: adopt the opening at the unique-decoding radius** (`classifyProtocolU`; `e = 24,448` at R13, `e = 8,052` at
W16R2). What it means:
- `Binding` becomes STRONGER, not weaker: nobody can open one commitment to two different inputs, even when each
  opening may miss `e` columns. Proved at your target for every number of queries (`classifyU_binding_r13`,
  `classifyU_binding_w16r2`).
- `KnowledgeSound` asks the extractor for an opening that misses at most `e` columns, instead of none. Because of
  `Binding`, that opening still pins down ONE input. So "the receipt attests the model's output on the committed input"
  keeps its meaning: the committed input is the one the commitment decodes to (§4).
- `Complete` and `ZeroKnowledge` carry over with the same error bounds (`completeU_of_complete`, `zkU_of_zk`). The
  honest prover still opens every column; that stronger fact stays proved for the same prover and verifier.
- The verifier, the honest prover, the statement and the receipt are the same terms. No code changes.
- One practical consequence (finding L26-1, Low): an accepted receipt guarantees that the input commitment can be
  opened on all but `e` columns, not necessarily on all of them. A later procedure that re-opens the input commitment
  (an audit, a dispute) should accept an opening at radius `e`. Honest users open every column, so nothing changes for
  them; only a prover who deliberately broke columns of its own commitment is affected.

**Choice B: keep the all-columns opening** (L18's `classifyProtocol`). Then the extraction premise O11d stays false
and the classify run cannot be proved production-ready at this instance. Making it true would need the verifier to
open all `65,536` columns, which is not an option: the commitment hides the input only against `Q` opened columns, so
opening all of them reveals the input.

**My recommendation: A, at the largest radius** (`e = 24,448` at R13, `8,052` at W16R2). It is the standard meaning of
an opening for this kind of commitment, and it is exactly what the verifier's spot check can enforce. A smaller radius
makes "opens" a little stricter but the spot check then catches less: at W16R2, `e = 5,000` gives about `2^-67` per
query instead of `2^-113.9` [ESTIMATE]. At R13 any radius from about `18,950` up to `24,448` keeps the spot check's
error below one unit of the count [ESTIMATE]; the largest is the simplest choice and costs nothing.

**What I need from you:** A or B; and if A, the radius (recommended: the largest, as above). After A, the coordinator
uses `classifyProtocolU` where the assembly now uses `classifyProtocol`.

**What is proved here** (the brief's four deliverables).
1. **Binding at the radius, reduced to the hash tree's binding** (`bindingU`, `binding_classifierU_target`): two
   openings of one root to different inputs at radius `e` give two different openings of one tree position, a hash
   collision. The reduction cannot tell which position without hashing, so it pays a factor `N`: at most
   `N · collBound(q + 2(h + 2))`, still inside your target `q·2^-100 + 2^-100` for every `q` (`N ≤ 2^20`).
2. **The fixed instance** `classifyProtocolU`: L18's instance with only `opensIn` changed; `Binding` at the target;
   `Complete` and `ZeroKnowledge` carried over; L24's joint gate at it (`classifyU_productionReady_joint_target`).
3. **The extraction of the input (O11d) at the fixed instance.** The extractor reads the input from the columns that
   sit in the tree, by decoding; the decoding is unique (`decodeIn_eq`). One new fact was needed (finding L26-2): the
   existing analysis of the opening decodes a matrix in which a broken column is read as zeros, and zeros may agree
   with the decoded codeword by accident. But the verifier demands that every sampled column sits in the tree AND is
   consistent. Counting "broken or inconsistent" as ONE kind of bad column, the spot check misses more than `e` bad
   columns with probability at most `((N − e − 1)/N)^Q` per query: `2^-172.4` at R13, `2^-113.9` at W16R2
   (`closeIn_column`, `xB_eps_r13`, `xB_eps_w16r2`). The step before it (the random weights `ρ`) costs at most
   `N/|F|`: `2^-110` at R13, `2^-111` at W16R2 (`closeIn_comb_prob`, `xA_eps_r13`, `xA_eps_w16r2`). These are two new
   kinds in L24's count.
4. **The gate re-assembled** (`classifyU_productionReady_ep_target`): the production gate at the fixed instance, at
   your targets, with the endpoint's part of the cover reduced to those two kinds and the decoding. **The numbers with
   the two new kinds: R13 `57,589,594` of the `67,108,864` units the target allows (86 %); W16R2 `31,480,689 ≤ 2^25`,
   inside half the target** (`jointU_r13_target`, `jointU_w16r2_target`).

**What is NOT proved here** (named premises of the gate, §5). Everything L24 left open for stage IN-C, the blocks and
stage OUT-C is still open, unchanged. For the endpoint, O11d is reduced to four deterministic links, each a named
hypothesis: the extractor's tree openings verify and are canonical; the run's extractor reads the endpoint by
decoding; the spot check's place on the run's transcript (with the step from the extension field to the base field,
finding L26-3); and the "zero outside the token positions" half of SIC_IO on the decoded data (finding L26-4).

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
| `closeIn_base` | the embedded matrix close inside `X` over an extension field gives the base-field matrix close inside `X`, from ONE code fact (a codeword with base-field values on all but `e` columns agrees there with a base-field codeword): finding L26-3's link, reduced |
| `colOf`, `SaltMk`, `column_mk`, `exSalt`, `exPath` | the column of decoded rows; opening data built from the decoded rows and the extracted salts and paths |
| **`opensU_of_decoded`** | on all but `e` columns the extracted opening verifies and is the decoded rows' column, the decoded data rows are `v`'s plane, `v` admissible ⇒ `OpensU` at radius `e` with the built opening data |
| **`agree_of_closeIn`** | the extracted (canonical) matrix close inside the columns that open ⇒ decoded rows and such a set |
| `decodeIn`, `decodeIn_spec`, **`opensU_of_closeIn`** | the decoded rows as a function of the extraction; the link in one step |
| `word_eq_of_colOf_eq`, `rows_eq_of_colOf_agree`, **`decodeIn_eq`** | for `2e + n + Q ≤ N` the decoding is unique: ANY decoded rows that agree with the opened columns on all but `e` columns are `decodeIn`'s, so the extracted value does not depend on a choice |
| `posPlane_eq_of_zero` | for the token-words plane: the decoded data rows ARE the plane of the words at the token positions read canonically, when they vanish elsewhere |
| `w16r2TokenCommit_plane`, `r13TokenCommit_plane` | the two token-words endpoints have the token-words plane (the gate's premise `hplane`, by definition) |

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
| `ChainU`, `ChainU.chain`, `StabU`, **`FirstKind.singleU`**, `FirstKind.singleU_ev` | a kind of ONE sub-protocol, its soundness fields from the sub-protocol's own bound |
| `XTest`, `XTest.εA`, `XTest.εB`, `XTest.cA`, `XTest.cB`, **`xKindA`**, **`xKindB`** | the column test's two halves as two kinds |
| **`xKinds_cover`**, `cover_of_xKinds` | the test's chain event lies in one of the two kinds; the gate's column-test premise `hX` from them and the chain link |
| **`epCoverU`** | accepted, the endpoint's conclusion at `classifyProtocolU` fails ⇒ the extraction failure, or the matrix not close inside the columns that open, or the decoded plane not zero off the token positions |
| **`classifyU_O11d`** | O11d in `ClassifyOpen`'s form at `classifyProtocolU`: `≤ εKinds Ks εx q` |
| **`classifyU_productionReady_ep_target`** | THE GATE at `classifyProtocolU` at the approved targets with the endpoint's cover discharged |
| `partConst_eleven`, `jointU_budget_w16r2`, `jointU_budget_r13`, `jointU_totals`, **`jointU_w16r2_target`**, **`jointU_r13_target`**, `xKind_lin_le` | the numbers (§3) |
| `xKindA_lin`, `xKindB_lin`, `XTest.εA_w16r2`, `XTest.εA_r13`, `XTest.εB_w16r2`, `XTest.εB_r13` | the two kinds at their constants: the premises `hxA`, `hxB` of the two targets from the test's parameters (`N`, `|F| = p²`, `e`, `Q`) |

## 3. The numbers

Units: `u126 q c = (q + 1)·c/2^126`; target `εsTarget q = u126 q 2^26`, half target `u126 q 2^25`. PROVED unless
marked; the decimal exponents (`2^-172.4`, `2^-113.9`) are ESTIMATES of the proved bounds `≤ 2^-172`, `≤ 2^-113`.

| | W16R2 | R13 (the app) |
|---|---|---|
| columns `N`, message and pad `n + Q`, sampled `Q` | `2^15 = 32,768`, `16,664`, `280` | `2^16 = 65,536`, `16,640`, `256` |
| radius `e` (largest: `2e + n + Q = N` exactly) | `8,052` | `24,448` |
| columns that must open, `N − e` | `24,716` (75 %) | `41,088` (63 %) |
| column test, round 1 `((N − e − 1)/N)^Q` | `2^-113.9` (`≤ 2^-113`) | `2^-172.4` (`≤ 2^-172`) |
| column test, round 0 `N/p²·(1 + p/2^128)^(2w0)` | `≤ 2^-111` | `≤ 2^-110` |
| the two kinds' linear constants | `2^15`, `2^13` | `2^16`, `1` |
| the two kinds with collision terms | `+303,104` | `+327,681` |
| L24's joint total (nine kinds) | `31,177,585` | `57,261,913` |
| **joint total (eleven kinds)** | **`31,480,689 ≤ 2^25` (94 % of the half)** | **`57,589,594 ≤ 2^26` (86 %)** |
| Binding (`N·collBound`, any `q ≤ 2^120`; above it the target exceeds 1) | `≤ q·2^-100 + 2^-100` | `≤ q·2^-100 + 2^-100` |

The binding bound in absolute terms [ESTIMATE]: at R13, `q = 2^64`, about `2^16·(2^64)^2/2^257 = 2^-113`; at
`q = 2^100` about `2^-41`. The acceptance of a commitment with ONE broken column, the reason for L24-1 [ESTIMATE]:
`(1 − 1/N)^Q = 99.61 %` at R13, `99.15 %` at W16R2.

## 4. Why `OpensU` does not weaken the approved meaning of `Binding` and `KnowledgeSound`

`Statements.lean` is unchanged; only the instance's `opensIn` changes. Write `Opens` for L10's full opening and `OpensU`
for the opening at radius `e`.

1. **`Opens` implies `OpensU`** (`opensU_of_opens`). So the event "two different values both open" is LARGER with
   `OpensU`, and `Binding` with `OpensU` bounds a larger event: it implies `Binding` with `Opens`. Binding is
   strengthened.
2. **The committed input is still unique.** For a statement `s`, call `x` "committed by `s`" when some opening data
   opens `s`'s input root to `x` at radius `e`. Two different committed inputs would give, at a position where both
   open with different columns (`opensU_diff`, which needs `2e + n + Q ≤ N`), two different openings of one tree
   position: a hash collision (`bindingU`). So, except with the binding probability, every party that can produce an
   opening produces the SAME input, and that includes any later FULL opening by an honest user (a full opening is one
   at radius `e`). That is the sense in which the commitment determines the input, by decoding. At the level of the
   extractor it holds with no probability at all: the opened columns determine the decoded rows (`decodeIn_eq`).
3. **`KnowledgeSound`'s promise keeps its meaning.** Its conclusion is: the extractor outputs an admissible `x`, the
   commitment opens to `x`, and the statement's public output is the model's on `x`. With `OpensU`, "opens to `x`"
   says that `x` is THE committed input (2.), so the receipt attests the model's output on the committed input, which
   is Statement 1's approved wording. What is literally weaker is only the opening certificate (all but `e` columns
   instead of all); a full opening cannot be extracted at all (L24-1), so no definition can ask for it.
4. **`Complete`** asks the honest prover's commitment to open. At the fixed instance that is literally the weaker
   request (open at radius `e`), and it holds because the honest prover opens every column (`completeU_of_complete`).
   The stronger fact, that the honest prover's commitment opens on ALL columns, is L18's `Complete` at
   `classifyProtocol`; it stays in the tree for the same prover and verifier (`proveU_eq`, `verifyU_iff`), so nothing
   about the honest side is lost.
5. **Nothing else reads `opensIn`** (`ZeroKnowledge`, `SemanticHiding`, `CircuitIff`).

I found no property that the change weakens beyond the opening certificate itself; that consequence is finding L26-1.

## 5. The remaining premises

Every one is a named hypothesis of a PROVED theorem (`classifyU_productionReady_ep_target`).

1. **Everything L24 left for stage IN-C, the blocks and stage OUT-C** (`h3`, the kinds' fields and constants `hℓ`,
   `hlin`, `hbud`, the Merkle extraction failure `Ex` with its bound `hEx`, `hx`), unchanged; and `ClassifyOpen`'s O1
   to O10 and O12 as L18 left them. `ClassifyOpen` also carries O11's four extraction bounds at the OLD instance; the
   gate does not use them, and they hold with the trivial bound `1`, so they cost nothing (they cannot hold with a
   small bound: that is L24-1).
2. **The radius**: `2e + n + Q ≤ N` and `N ≤ 2^20` (`w16r2PlaneCommit_radiusU`, `r13PlaneCommit_radiusU`: proved for
   the two registered geometries).
3. **The endpoint** (new, deterministic):
   - `hops`, `hcan`: the extractor's openings (`ops`) verify against the statement's root, with canonical columns
     (true of an extractor that checks the openings it reads against the log and keeps only canonical columns; an
     accepted opened column is canonical when the segment decoder refuses every word `≥ p`, as L9's block decoder does,
     `CoreCanon`; for stage IN-C's segment, whose decoder is the `StageInV` parameter, that is part of the chain link
     below);
   - `hE`: the run's extractor reads the endpoint by decoding (`decodeIn`) and builds the opening data with `mk`;
   - `mk : SaltMk`: the instance's opening-data type can hold the non-data rows' messages, the pads, the salts and the
     paths (the honest half is L18's `HonestIn.withPaths`);
   - `pos`, `hplane`: the input commitment's plane is the token-words plane (proved, by definition, for
     `w16r2TokenCommit` and `r13TokenCommit`);
   - `hX` (from `cover_of_xKinds`): the column test's chain link: accepted, no extraction failure and the base-field
     matrix not close inside the columns that open ⇒ the test's chain event (its windows at steps' ends, its second
     half alive at the end, the matrix and the openable set read at its windows, and the identification of the
     extension-field closeness of the embedded matrix with the base-field closeness, finding L26-3); the two kinds'
     membership in the list, their `ℓ ≤ 2^21` and their stability premises `StabU` (L24-2's weak form);
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
`e₂`, `e₁ + e₂ ≤ e`) lose the exponent: at R13 the even split costs about `2^-76` per query each [ESTIMATE]. The
verifier's check is ONE test of both (every sampled column must open AND be consistent); counting it as one
(`closeIn_column`) keeps the full radius: `2^-172.4` (R13), `2^-113.9` (W16R2), with round 0 at `N/|F|`
(`closeIn_comb_prob`). Two new kinds; the budget stays inside the target (§3).

**L26-3 (Medium; a premise): the column test's code lives over the extension field.** The weights `ρ` are drawn in
`F_p²`, so the test (like L20's openings) is analysed over `F_p²` with the commitment's base-field columns embedded,
while `OpensU` is a base-field statement. The link "the embedded matrix close inside the openable set over `F_p²` ⇒ the
base-field matrix close over `F_p`" is reduced here to ONE code fact (`closeIn_base`): an `F_p²` codeword whose values
on all but `e` columns are base-field values agrees there with a base-field codeword. For the Reed–Solomon encoder that
is the base-field interpolant (the codeword has degree `< n + Q` and at least `N − e ≥ n + Q` such points). That fact
is not proved here; it sits inside `hX` (as the analogous identification sits in L20/L22's `hsem` for the blocks).

**L26-4 (Low; a premise, also true of the full opening): the decoded endpoint plane must vanish off the token
positions.** L10's plane commitment (`posPlane`) puts zeros at every position that is not a token word, so ANY opening
of it (full or at the radius) needs the decoded data rows to be zero there. L18's `InOk` carries only SIC_IO's
support half (`epW = tokW`); the "others zero" half of `in_endpoint_words` on the decoded data is the premise `hzero`,
to be covered by IN-C's SIC_IO zero-check and the endpoint opening's claims.

**L26-5 (Info): the binding reduction pays a factor `N`.** It takes the union over the `N` positions instead of finding
the colliding position by hashing; `N ≤ 2^20` keeps it inside the target for every `q` (`bindingU_le_target`).

**L26-6 (Info): at the largest radius only about two thirds of the columns need to open.** At R13 `N − e = 41,088` of
`65,536` (63 %); at W16R2 `24,716` of `32,768` (75 %). That is what "unique-decoding radius" means at rate `1/4` and
`1/2`: the remaining columns still determine every row. It is not a loss of binding (`bindingU` holds at these radii).

## 7. Checks

One guarded job (`results/zk60_lean_l26_20261107/check_l26.sh`, run through `run_guarded.py`, the zk60 resource guard,
class cpu; iteration 6, 2026-11-09; the guard's record: exit 0, 101 s, peak 11.95 GiB). Its log is `check.log`; the
whole iteration is `iter6.log`. The script exits 0 only when every line below holds.

| Check | Result |
|---|---|
| the five L26 modules, one at a time | each `rc 0`, no warning |
| full `lake build` of the library on the lane's tree | green, `3559` jobs, `0` warnings, `0` errors, `0` `sorry` |
| axiom audit (`axioms_l26.lean`, generated from the five files) | `103` declarations audited of `103` generated: `73` theorems, `26` definitions, `3` structures, `1` abbreviation |
| their axioms | `99` on `[propext, Classical.choice, Quot.sound]`, `1` on `[propext, Quot.sound]` (`HdrXU`), `1` on `[propext]` (`jointU_totals`), `2` on none (`ChainU`, `ChainU.chain`); `sorryAx` `0`, `Lean.ofReduceBool` `0`, any other axiom `0` |
| source scan of the five files for the forbidden words | none |
| the library root imports the five files | all five |
| `Statements.lean` and L18's `ProtocolClassify.lean` against the base `2ba55340` | unchanged |
| existing files under `formal/` modified, deleted or renamed (the root's five added import lines apart) | `0` |
| regression: `L6Check` on the committed L6 corpus | `1,206` checks, `0` failed |
| regression: `L5Check` on the committed L5 corpus | `5,553` checks, `0` failed |
| regression: `L11Check` on L11's committed W16R2 rung corpus | `404` checks, `0` failed |
| regression: the fixture L1 check | `101,956` checks, `0` failed |

By file: `BindingU.lean` 12 theorems, `BindingUTest.lean` 15, `BindingUDecode.lean` 15, `ProtocolClassifyU.lean` 12,
`ProtocolClassifyUEp.lean` 19; 2,005 lines in all.

Notes on the evidence.
- The audit covers the definitions too (the instance `classifyProtocolU` is one), not only the theorems.
- Lean prints the report of a long name over several lines. An earlier run of the check (iteration 4, `iter4.log`)
  therefore counted "other axioms: 1" for `classifyU_productionReady_joint_target`, which is on the usual three. The
  script now joins such lines (`axioms_flat.log`) before counting.
- The iterations: `iter1.log` and `iter2.log` are the first session's (2026-11-07; iteration 2 ran just after it was
  cut off and shows the two compile errors fixed on resuming); `iter3.log` the five modules green; `iter4.log` and
  `iter6.log` the check. Iteration 5 was the same plan queued with the guard's default five-second admission poll;
  later jobs of other lanes took the lock ahead of it for 37 minutes (the guard's first-come queue is off), so the plan
  was queued again as iteration 6 with a one-second poll (`ZK60_GUARD_POLL_SECS=1`, this job only) and iteration 5's
  plan file was emptied, so that it does nothing when admitted.
- Not checked here: the tree after merging perf (`f71f611b` on 2026-11-09: L22, L23, L25 and later lanes). Since this
  lane's base, perf changed no existing file under `formal/` except the root's import lines, and none of this lane's
  103 names is declared there or in the running lanes' files (compared by name). The merged-tree build is the
  coordinator's check.
