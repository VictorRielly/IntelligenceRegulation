# R13 argument implementation map

Current working profiles/Ids are under the explicit shared BlockPublic R13
refusal. No accepted R13 proof exists. The latest profile build is queued.
This map records code dependencies before editing the running/queued tree.

## Reuse and dispatch

Keep the legacy define body and its S35 differential hooks unchanged. Add a
child argument_accuracy.rs, with an explicit public AccuracyPublic reference
in Ctx (None for all old callers; both protocol cores already receive BlockPublic, so use blk.accuracy() there). Dispatch changed LOW host slots there;
use existing SS/SSM/TZC/LZC/RS/SCORE/PV/IO/ZS definitions where unchanged.
All new private plane claims use Ids::domain_range + B::a_range on the whole
physical domain. Old A_RDL/A_RH1 are no longer the domain's last plane.
Use B::tab(AccuracyIds::limb(...)) for every added limb group.

The seven matmuls keep their existing private factors/points and polynomial
degree. Pass accuracy_fold::coefficients/fold for the public matrix fold:
Q/K/V/O rows, gate/up/down columns. Gate uses the FOLDED gate coefficients.
Scale at the Boolean output channels, before folding. Q coefficients use
the query head permutation. Input/output padded coefficients remain zero.

## Changed host slots

**DZC:**13 arithmetic clauses, plus helper weights and optional pad weight.
Norm_a/m use effective tn=base_tn-8, Cn unchanged,24-bit rho/sigma. Add full
int16 Y and YM decompositions to the existing eleven clauses. All X/AO/X1/
Z/X2 decompositions remain full int16. Host WO and DMM reconstruct the
three-byte AO remainder and LOW two-byte / H24 three-byte down remainder,
using their effective denominators/half biases. Two T denominators are
read at their own slices. Clauses and both host terms retain support gates;
all private D planes retain the pad-zero term. A sites40 LOW /41 H24.

**FZC:** retain4 + helpers + optional pad weights: product, up decomposition,
h decomposition, ACT helper. Product is already-scaled A times up, minus
h*2^R and full-byte remainder, plus half; R24 LOW /16 H24. h bias2^15 LOW /
2^23 H24, with two/three word limbs. Up host is now up*2^12 +RU(two bytes)
-half. Gate host uses Shape.accuracy_gate_shift and RGL(three bytes).
ACT query is G+2048 +beta*A_scaled +beta^2*public_group +tag. Its inverse
helper remains UNGATED, including padded F positions, whose query is the
valid gate0/A0/group0 row. No private gate-byte/group plane. A sites16.

**QZC/KVZC:** four arithmetic clauses each: RoPE plus three int16 word
decompositions (Q/QR/O or K/V/KR). Use4+helpers+pad weights. The flipped
RoPE source retains its own reserved claim. RoPE denominator/remainder
stay2^7/one byte. Hosts reconstruct two-byte Q/K/V/PV remainders, with
Q/K shift distinct from V. A sites15 on each domain. Full signed int16
endpoints are allowed, public weights/gamma remain symmetric int8.

**SZC (non-DD):** retain existing argmax, selector, exact division and p
decomposition clauses; use F_P12 and a three-byte score remainder in the
score host, with effective score shift. p has two limbs with its FP12 top
pin. rho/sigma use the existing ls window. Preserve future-score checks and
the ungated exp inverse helper. Keep Ht and S pad terms separate as before.
Do not run S35's legacy FP9/one-byte-score differential body on this branch.

**SZC (DD):** same argmax/exp/keyed tuple construction as R9, but score host
uses all three remainder bytes/effective score shift. Tuple is still
Sum +beta*maskE +beta^2*P +tagDD. P is constrained by the dictionary at FP12.

**DD:** the existing per-slot quotient/remainder clauses now use FP12. Every
slot, including repeated padded e=0 slots, is checked. Preserve Sum key,
public exp column, committed M_dd and all helper signs/own claims. The
witness assigner already fills FP12 dictionary slots and first-value counts.

**TAB:** keep three multiplicity/helper/value triples. Values ACT come from
accuracy_act::table, including public group coordinate and scaled outputs.
U8/exp zero padding uses first256 support. ACT histogram AND table helper
zero padding uses groups*4096 support, validated <=N. This is one extra
PUBLIC indicator, no committed plane/private claim. Keep all three hist /
helper role lists checked, adapt pad descriptions to the distinct ACT bound,
and ensure PadTerm batching uses independent zeta powers across its groups.
PadTerm::add was inspected: it explicitly continues zeta powers across all groups; reuse that behavior.

## Protocol and validation dependencies

protocol helper/histogram generation must count the three-coordinate ACT
queries, including padded gate0/A0/group0 queries, into the real table row
(group0,index2048). Invalid witnesses must reach actual relation/LogUp checks
in scoped tests; a builder range refusal alone is not a proof tamper gate.
ACT table-helper/multiplicity tails remain zero above groups*4096; U8/exp
tails above256. DD helper/zero-sum signs remain unchanged.

BlockPublic validation must recompute the exact registry/stack/base geometry
and require gate shift equality, plus symmetric weights/gains. Public group
columns/tables/supports are verifier-derived, not witness-supplied. Never
activate a profile with None accuracy data or attach LOW data to an old one.

No new transcript challenge is needed: ACT uses the existing beta and beta^2,
as DD already does. Its tuple-collision degree/cardinality bound must be
recounted; do not inherit R12's N+2303 term. Recompute native claims/helpers/
mask widths/degrees/element-term ledger after actual definitions. Current
Shape claims are an allocation/count scaffold, not proof acceptance.

Include the new child in source pins, S25 nested production scan and absorb
scan before long tests. CPU release proofs, fresh verification, mutations,
legacy seeded goldens/retained stacks, full suite/freeze and D24 remain.
