# D affine aggregation: actual catalog and a memory negative

Cycle 0075, run `20261018T042105Z-c9fe8fca`, 2026-10-18 UTC.
No native proving speedup or complete proof was measured.

The cycle-74 affine aggregate reduces counted clause arithmetic. This cycle
asks whether its extra stream replaces original working-table traffic after
including D's real lookup, host, padding and original-final dependencies.

`prepare.py` extracts the owner's actual `Ids::new`, `B::a_range`,
`lookups_at`, `a_plane_doms`, helper/padding code and complete D closure into
a tiny Rust reference. Shape/Layout and allocation methods are substitutes:
this executes the returned-index/catalog logic, not full trained admission,
PCS offsets, mask sites or a native prover. The field implementation is an
exact u128 modular substitute for Goldilocks Fp2. Public T128 profile scalars
are whitelisted in `public-profile-scalars.json`. Every field value tested
is synthetic. No real inputs, tokens, activations or model arrays are retained.

`run.py::prep` is the parametrized candidate interface. It accepts returned
table IDs and accumulates coefficients by ID, including synthetic aliases.
`lin` builds the proof-local affine table; `fast` evaluates it plus four
bilinear terms. An independently specified Python catalog and eleven-clause
reference check the captured Rust, including full helpers, hosts and padding.
The table-order tests permute the entire full expression, including lookup,
helper, pad, equality and host indices. Aliases are generic algebra tests,
not an admitted native layout.

Commands from the research directory:

```bash
python3 experiments/dzc-affine-read-catalog-20261018/run.py
python3 experiments/dzc-affine-read-catalog-20261018/audit.py
```

Seed 2026101875. Each pins one CPU, nice19, 59-second wall/CPU limits and
512 MiB address space. No GPU, Cargo, installs or downloaded code execution.
Device: Intel Core Ultra 9 185H CPU0, WSL2. Main 1.182008 seconds / 18,924 KiB
RSS; tiny compiler 135,812 KiB. Separate audit 0.001340 seconds / 14,556 KiB.
These are test clocks, not witness/proof/verification timings.

PASS: 24 fixtures, N=2/8/32; actual four-limb T128 catalog descriptors plus
generic four/five-limb partial-top descriptors; padded/unpadded D branches.
2,028 captured full-polynomial values, 468 round sums, 1,488 direct-cube
original terminal values, 24 full-expression permutations, 24 alias cases
and 24 synthetic binding refusals. Ten controls fire. Count/schema refusals
are harness controls, not native verifier tests. Independent audit passes
83 catalog/count/source-contract checks. Five live source hashes still match.

The initial shared-window assertion failed because this harness wrongly used
32767 in the trained norm derivation. Its provisional 8B 31-bit catalog was
also wrong. Preserved initial artifacts show this error. Final code executes
the captured native `derive_at_width` arithmetic core with `INT16_ABS=32768`;
both profiles have a 32-bit window. The wrong positive-only formula is now a
negative control. This does not change calibration or any production source.

Both current T128 D catalog descriptors have 35 A columns, 34 lookups, 17
helpers, 59 original tables and 54 private terminal claims. Their actual
width/context axes do not pad D. An optimized online subset can omit only
`A_X2` (table34), then adds L: 58+1=59 streams. A padded generic D branch
reads `A_X2` in the pad term as well: 60+1=61 streams. The current generic
ClosureRounds reads and folds every original table regardless of closure
use, so adding L makes the unpadded path 60 tables and retains all54 claims.

**The proposed memory-traffic reduction is falsified for this adapter.**
The arithmetic benefit remains possible and unmeasured. No originals are
deleted and no smaller proof/final oracle follows from the linear identity.

| Counted T128 geometry | D entries | Added L capacity | Generic build logical bytes | Base build logical bytes |
|---|---:|---:|---:|---:|
| TinyLlama 1.1B |262,144|4 MiB|142,606,336|73,400,320|
| Llama-3-8B |524,288|8 MiB|285,212,672|146,800,640|

Charge extra fold bytes48(N-1), unique pair-endpoint bytes32(N-1), N-1 extra
Fp2 fold products and degree4's4(N-1) stepping additions. Source text mentions
the low endpoint twice; the audit reports this48(N-1) source-occurrence count
separately. None is a DRAM, timing, cache, GPU register or measured peak-RAM
result. Complete typed base provenance is required for the mixed build; a
new provenance scan costs another pass. Coefficients add constant storage.

Baseline/ceiling: retained 1.1B T128 one-pass diagnostic174.052s has all-D
26.691s. Deleting every D would give at most1.18113x/0.868615positions/s;
this candidate changes only a subset and adds work. Actual clause share and
8B ceiling are unknown. Falsify a runtime claim on any enclosing regression
after preparation/build/folds/transfers/verification/drain. Reject any
original-value, degree, final/refusal, transcript/RNG or privacy divergence.

Unapplied handoff: `../../handoffs/20261018-dzc-affine-read-catalog.md`.
Next local experiment: exact D row coefficients from original table pairs,
including actual helper relations, to test arithmetic savings without adding
L's full working table. Keep the existing sumcheck messages, degree and
original finals. Owner profiles D before any device implementation.

Target proof/pass/position count0/0/0; target device none; steady and total
rates, startup fraction, witness/proof/serialization/verification clocks
unmeasured. No prefill, resident-pass series or decode run occurred. Longer
contexts can grow attention quadratically. No mask or opening reuse is allowed.
