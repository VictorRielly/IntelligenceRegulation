# Cycle 0072: public NTT root decomposition

Run `20261018T012105Z-ac328993`, seed 2026101872. Research only.

Baseline: native generator 7, canonical Goldilocks, stage-major forward/inverse
root tables, one general product per radix-2 butterfly. Retain existing
first-six-stage shift candidate, pad-stage skips, inverse scale, coset,
pruned opening and swizzle invariants. No proof relation or mask changes.

Question: can late roots be compressed using their existing order-64 subgroup?
For stage s>6, d=s-6, k=l+2^d h, 0<=h<32. Then
w_s^k = w_s^l * (w_64)^h = w_s^l * 2^(39 h).
Apply the low-root general product followed by a canonical shift; never
change the native root to suit a representation. Both inverse factors invert.
Low table lengths 2^d have monotonic stage offsets 2^d-2.

Eliminated: 31/32 of late-stage stored root words; first-six tables implicit.
No extra general products versus the prior sparse-shift dispatch. Added:
nonidentity shifts on most otherwise-general late butterflies, integer index/
sign/reduction dependencies and dispatch. Logical root loads remain roughly
one per late butterfly; a smaller cache is not 32x less runtime traffic.
Generic two-table consecutive products are a comparator and add general
products. Charge CPU construction/upload, ownership/cache validation and any
register/occupancy effects. No startup or DRAM benefit assumed.

End-to-end ceiling: N/(T_total-C_affected+C_new). Unknown C_affected/C_new;
free removal of an entire NTT phase is only an optimistic phase-set bound.
The current complete 8B T128 CPU diagnostic (606.598s) is not a GPU ceiling.
Falsify on an exactness/refusal/order/scale mismatch, altered pad/pruned
behavior, non-monotonic immutable cache, or no enclosing gain after added cost.

Ranked queue before testing:
1. Owner whole-prover GPU arithmetic/continuous useful work. Highest measured
   bottleneck relevance. Existing gates and clock policy are prerequisites;
   integration owned elsewhere. Fresh masks and exact transcripts mandatory.
2. Owner immutable public residency + complete resident-pass slopes. Startup
   amortization plausible; full clocks/verification/drain and identity needed.
3. NEW native order-64 late-root compression. Low oracle/integration cost,
   unknown runtime gain; exact arithmetic/source provenance are obligations.
4. Pending factored lookup representation: lower logical reads proven, full
   new GKR/PCS/links/mask costs and joint privacy remain high integration risk.
5. Generic OT / new commitment backend: cache savings may lose to extra
   arithmetic; field/root/layout/proof composition require independent gates.

One CPU thread, <=59 seconds and 512MiB AS per experiment. Local-authored
host C++ compilation only, no native crate build, GPU, download execution,
installation, Git, production/runtime writes or external message.
