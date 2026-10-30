# Check-removal prerequisite — negative result for owner review

Cycle 0134, `20261029T035649Z-8ea509dd`. No production patch, native check
deletion, external-code execution, GPU or measured proving gain.

The research files are under
`experiments/finite-field-provenance-20261029/`: candidate/reference/run,
result, source pins and audit. Final harness: 135,613 checks, 0.231862 s,
16,308 KiB, seed 202610290134, one CPU worker. Independent audit: 186 checks.

Integration seam is an **offline relation audit** for native
`private_block/argument.rs::define` (SC_DZC c0/c1/c6/c7, SC_LZC, SC_SZC,
SC_DD, lk_tables), `witness.rs::rms_norm`, Shape windows and canonical field.
There is no native adapter or runtime API delivery. Retain all native checks.

Input to any future certificate interface must include exact field/profile,
expression/plane/encoding, support, and a set of independent retained premise
constraints. Output should name the candidate constraint, obligations and
finite acyclic derivation under the cumulative removal mask. Unsupported
shapes stay. Signed interval facts apply only to independently base-valued
operands, never arbitrary extension-valued helpers or masked evaluations.

Two decisive controls: (1) Goldilocks a=(p-1)/2, b=2, c=1 satisfies ab+c=0
while integer division under c in [1, 2] infers only a=-1; conclusion/divisor
guards alone are insufficient. Require full independent operand product
bounds or a separately justified exact modular preimage. (2) For x=y, two
separate equal range checks each entail the other; removing both using
noncumulative evidence admits new coordinated witnesses. Cumulative logic
keeps one. Also keep the strongest range when domains differ.

These controls do not establish a bug in the external paper/tool or in native
code. The author's uniqueness obligation is stronger; actual artifact
download failed with Cache miss, so implementation inspection is blocked.
Native accepted/refused sets, pad/lookup multiplicities, hosted claims,
soundness budget, transcript/profile and privacy remain untested.

Owner prerequisite: identify a genuinely redundant native group and measure
its exclusive witness/commitment/proof/enclosing cost before building an IR.
Count reduction has no measured throughput value. Added analysis/certificate,
new profile and security/privacy costs can dominate. No author percentage
or synthetic timing transfers to 8B/GPU. Any later native build uses current
shared heavy/build locks and the owner's lane; researcher does not launch it.

No masks, blinding, openings or private commitments may be reused. Main/Claude
reviews any subsequent candidate and integrates it; no merge is performed here.
