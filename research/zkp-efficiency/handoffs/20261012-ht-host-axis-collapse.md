# Leading Ht host multiplicity — owner review only

Cycle 0042, run `20261012T232555Z-fecd435a`. Synthetic parity passes;
**modest count saving, no native proving gain**.
[Experiment](../experiments/ht-host-axis-collapse-20261012/README.md),
[result](../experiments/ht-host-axis-collapse-20261012/result.json),
[count model](../experiments/ht-host-axis-collapse-20261012/cost-accounting.json).

Interface: a private, immutable source plan certifies SC_SZC group 1's Eq
leading extent L, A_SUM's Cm/log/coords/ext-round/site mapping, and builder
support Dom::Ht or Gate::None. Never accept a witness invariance claim, use
private-value admission scans or add new refusals to obtain this shortcut.
Unsupported public mappings retain the original grouped evaluator.
For j<L, evaluate the compact half-cube once and scale sums by `2^(n-L)`;
for j>=L, evaluate the constant bracket once and scale by remaining tail size.
Retain native bracket degree/sample count; recover sample 1 only from the
actual preceding unmasked group claim, with original explicit zero fallback.

Patch seam: candidate argument.rs priv_table:208 and SC_SZC A_SUM:1719,
support:1745, group descriptors:1783, host bracket:1791; grouped.rs round loop
and hs generation. Existing constructor broadcast certifies the leading lift;
there is no native Tab::lift method. argument.rs SlotDef needs the source plan
before dense lowering erases provenance. Pinned argument SHA
b3b02383a14a64a12194a465873b76f78406e5d3115b0c8157fde2882d22c865,
grouped SHA7777a19c8db97694c51e66c78d1a7688573158bddaa7fcb370345ebd14ab669b.
[Tested Python](../experiments/ht-host-axis-collapse-20261012/collapsed.py);
[Rust helper](../experiments/ht-host-axis-collapse-20261012/ht_host.rs) is
uncompiled/unapplied and serial. Native parallel scheduling is not decided.

Final check: 10.821527s / 22,528KiB RSS, one nice19 Core Ultra9 thread,
seed2026101242, 59s/512MiB caps. 32 fixtures, 2,520 independent group samples,
5,040 candidate sample/degree checks, 720 actual claims, 144 terminal group
identities, 3,584 ordered finals, 5,376 extension tables, 192 extension
polynomials; 316 recoveries / 260 zero fallbacks, 13 controls. Independent
tuple original-cube oracle. Synthetic inconsistent planes, not honest proof.
An initial test-design failure is preserved: sampled j=0 did not distinguish
S/Ht support; altered-full-cube control now detects it. False source plans
are demonstrably invalid, so provenance is a load-bearing integration gate.

Conditional h_pad16/T512/n22/L13/ls3/lp2: group1 calls10,485,758 ->20,487;
group0/2 calls unchanged. Including unchanged 30-table folds removes
35,581,934 (2.87086%) of selected Fp2 multiplication API calls, or2.53766%
under the five-base-multiply lowering model. No time inference. Added32782
host endpoint reads /524512B payload,16382 differences,32764 sample additions,
66 base scalings, dispatch/provenance/reduction costs. Whole cube scan/folds,
witness/PCS/masks/extensions and quadratic remaining attention stay.
No compact private table allocated; O(degree) scratch, allocator excluded.

Owner first isolates the host bracket/weight/read/reduce share, then tests a
port only if it warrants complexity. Complete generic/masked polynomial,
original dense Eq/private finals and arbitrary private extensions must match;
shape/refusal/degree/order/zero gates, RNG/transcript/frozen receipts and fresh
independent verifier checks required. Full privacy/soundness remains with
existing owners, no private mask reuse. Enclosing/peak regression rejects.
Ceiling N/(T-Cht_round+Cnew); no accepted 8B numeric ceiling. No production
change, build, GPU job, heavy queue or merge. Next complementary local work:
actual mixed-driver compact A_MX/A_SUM leading readers, with source provenance.
