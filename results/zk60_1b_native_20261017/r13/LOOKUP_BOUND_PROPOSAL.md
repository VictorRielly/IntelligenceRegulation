# R13 ACT3 lookup term: conservative proposal for independent review

Development analysis only. This is not an accepted soundness ledger. The
normal-release position/slot census is retained in NATIVE_LAYOUT_CENSUS.json;
the independent D24 review remains due.
Do not copy R12's N+2303 term into the R13 freeze.

All witness words and table multiplicities are in A, committed before the
independent beta, gamma and alpha challenges. The helper equations and the
single signed LogUp sum refer to those committed values. In formal
variables, each denominator is alpha minus a tuple polynomial. Byte and EXP
tuples have total degree at most1; ACT3 and DD tuples have degree at most2.
ACT3's public group coordinate is beta^2*gid, with no new challenge.

Use the following PUBLIC counts from the actual padded native layout:

    Q_byte = sum_dom(size(dom) * lookups_per_position(dom))
    Q_exp  = size(S)
    Q_act  = size(F)
    Q_dd   = size(S) if DD, otherwise0
    T_byte =256
    T_exp  =256
    T_act  =4096 * ngroups
    T_dd   =size(Dd) if DD, otherwise0
    N      = Q_byte+Q_exp+Q_act+Q_dd+T_byte+T_exp+T_act+T_dd

These count positions, not distinct tuples; hence they conservatively bound
the number of poles after duplicates are combined. ACT support ends exactly
at T_act, independently of the 256-entry byte/EXP supports. The native TAB
pad terms force multiplicities and table helpers outside each support to0.
Every padded query position remains in its family's Q count. DD includes
every dictionary slot, including repeated E=0 slots; no private "used" gate.

A deliberately coarse joint polynomial bound is total degree <=2*(N-1)
after denominators are cleared. Before using it, D24 must check the formal
nonzero premise: distinct tuple coefficient vectors are separated by beta
and gamma/tag, and any unmatched query tuple has a nonzero positive integer
query count below the characteristic. Table multiplicities may be arbitrary
committed field values; positivity of those values must not be assumed.
The bound treats all denominator factors as degree2, even though most byte
and EXP factors have degree1. It introduces no claim of a sharper error
than the inherited analysis. Over Fp2, use q=p^2 and union this term across
layers with the actual sumcheck/PCS/CFS/hash terms, rather than adding a
standalone "security bits" assertion.

The proposed nonzero argument can be stated over the rational function
field Fp2(beta,gamma), taking partial fractions in alpha. Distinct formal
tuple coefficient vectors give distinct linear alpha poles in that field;
their pairwise differences are nonzero polynomials of degree at most2.
Combine duplicate formal poles first. If a query has no registered table
tuple with its coefficient vector, its residue is its positive query count,
which is nonzero because that public upper bound is below p. Hence the
rational function is nonzero even when the committed table multiplicities
are arbitrary field elements. Clearing the distinct linear alpha factors
produces a nonzero polynomial. Counting all positions instead of the
distinct factors only increases the proposed 2*(N-1) degree bound. D24 must
independently validate this argument and its native commitment/claim coupling.

Zero denominator attempts are refusals. Inverting every registered public
ACT entry and every DD slot before applying multiplicities preserves the
existing refusal rule; it does not establish any privacy acceptance. The
proof that the rational identity is the one opened by the native helper
claims, and the argument that adversarial A values stay fixed under these
challenges, are explicit review obligations.

Development evidence now includes the 144-row native census (12 profiles,
FE9/12/16,1..4 groups), four complete Low/H24 DD/nonDD receipts and18
receipt-emitting limb/dictionary/support-tail attacks rejected by verification.
All26 actual Shieldstral layers pass the full public loader and tied-table
regeneration. The independent actual-L00/T128 oracle also passes19 sites.
Normal-release receipt gates, two-stage boundaries, the stronger ACT3 group
attack, fresh verification and final native counts now pass. The full suite
passes816 tests/0 failures across29 targets. Both actual-L00/T128 DD and nonDD
receipts match the independent oracle, verify freshly and reject tampering.
Independent D24 acceptance remains pending. These are not full26-layer proofs.
